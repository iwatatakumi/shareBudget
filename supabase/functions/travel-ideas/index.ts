// シェアバジェット: 旅行先の候補をAI（Claude）に探してもらう Supabase Edge Function です。
// アプリから呼ばれ、Claudeがウェブ検索で最新の情報を調べて、旅行先・ルート・費用の目安を返します。
// AnthropicのAPIキーはアプリに入れず、Supabaseの「Secrets」に ANTHROPIC_API_KEY として保存します。

import Anthropic from "npm:@anthropic-ai/sdk";
import { createClient } from "npm:@supabase/supabase-js@2";

// 同じ家計簿で続けて押されたときは、この時間内なら前回の結果を返します（費用を抑えるため）
const COOLDOWN_MS = 60 * 60 * 1000;

type TravelIdea = {
  city: string;
  country: string;
  route: string;
  days: number;
  cost_per_person: number;
  cost_note: string;
  highlights: string[];
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function buildPrompt(fund: number, people: number): string {
  return `あなたは日本に住む人向けの旅行プランナーです。
${people}人で一緒に行く旅行の候補を、世界中の魅力的な都市や旅行ルートから6つ提案してください。
いま貯まっている旅行資金は${people}人合わせて${fund}円です。

条件:
- 出発地は日本（東京）です。
- ウェブ検索で最近の航空券・ホテル・現地の物価を調べ、1人あたりの費用の目安（往復航空券・宿泊・食費・現地交通の合計、日本円）を見積もってください。
- 6つのうち、いまの旅行資金で行けるもの、もう少し貯めれば行けるもの、大きな目標にしたいものを混ぜてください。
- route は「都市A → 都市B → 都市C」のように、回る順番がわかる形にしてください。
- cost_note は費用の内訳を短く書いてください（例: 往復航空券 約4万円・ホテル3泊 約3万円・食費や交通 約3万円）。
- highlights は見どころを2〜3個、短い言葉で書いてください。

答えの最後に、次の形のJSONだけを \`\`\`json と \`\`\` で囲んで書いてください。
{"ideas": [{"city": "台北", "country": "台湾", "route": "台北 → 九份 → 台北", "days": 4, "cost_per_person": 100000, "cost_note": "往復航空券 約4万円・ホテル3泊 約3万円・食費や交通 約3万円", "highlights": ["九份の夜景", "士林夜市"]}]}`;
}

// Claudeの答えの文章から、最後のJSONを取り出して形を確かめます。
function parseIdeas(text: string): TravelIdea[] {
  const fenced = [...text.matchAll(/```json\s*([\s\S]*?)```/g)].pop()?.[1];
  const raw = fenced ?? text.slice(text.indexOf("{"), text.lastIndexOf("}") + 1);
  const parsed = JSON.parse(raw);
  const list: unknown[] = Array.isArray(parsed?.ideas) ? parsed.ideas : [];
  return list
    .map((item) => {
      const idea = item as Record<string, unknown>;
      return {
        city: String(idea.city ?? ""),
        country: String(idea.country ?? ""),
        route: String(idea.route ?? ""),
        days: Math.max(1, Math.round(Number(idea.days) || 1)),
        cost_per_person: Math.max(0, Math.round(Number(idea.cost_per_person) || 0)),
        cost_note: String(idea.cost_note ?? ""),
        highlights: Array.isArray(idea.highlights) ? idea.highlights.map(String).slice(0, 4) : [],
      };
    })
    .filter((idea) => idea.city && idea.cost_per_person > 0)
    .slice(0, 8);
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ error: "POSTで呼び出してください" }, 405);
  }

  // 呼び出した人のログイン情報で、データベースを読み書きします（権限の設定がそのまま効きます）
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY") ?? req.headers.get("apikey") ?? "",
    { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } },
  );

  const { data: userData } = await supabase.auth.getUser();
  const user = userData?.user;
  if (!user) {
    return json({ error: "アプリを開き直してください" }, 401);
  }

  const { data: member } = await supabase
    .from("members")
    .select("household_id")
    .eq("user_id", user.id)
    .maybeSingle();
  if (!member) {
    return json({ error: "家計簿に参加していません" }, 403);
  }
  const householdId: string = member.household_id;

  // 少し前に探したばかりなら、その結果を返します
  const { data: cached } = await supabase
    .from("travel_suggestions")
    .select("*")
    .eq("household_id", householdId)
    .maybeSingle();
  if (cached && Date.now() - Date.parse(cached.created_at) < COOLDOWN_MS) {
    return json(cached);
  }

  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) {
    return json({ error: "SupabaseのSecretsに ANTHROPIC_API_KEY が設定されていません" }, 500);
  }

  const body = await req.json().catch(() => ({}));
  const fund = Math.round(Number(body?.fund) || 0);
  const people = Math.min(10, Math.max(1, Math.round(Number(body?.people) || 1)));

  const anthropic = new Anthropic({ apiKey });
  const userMessage = { role: "user", content: buildPrompt(fund, people) };
  // ウェブ検索が長いと途中で一度止まる（pause_turn）ので、そのときは続きを頼みます
  let assistantContent: unknown[] = [];
  // deno-lint-ignore no-explicit-any
  let response: any;
  try {
    for (let i = 0; i < 4; i++) {
      // deno-lint-ignore no-explicit-any
      const params: any = {
        model: "claude-opus-5-5",
        max_tokens: 16000,
        // 安全のための判定で断られたときに、別のモデルで自動でやり直す設定です
        betas: ["server-side-fallback-2026-07-01"],
        fallbacks: "default",
        output_config: { effort: "medium" },
        tools: [{ type: "web_search_20260209", name: "web_search", max_uses: 5 }],
        messages: assistantContent.length > 0
          ? [userMessage, { role: "assistant", content: assistantContent }]
          : [userMessage],
      };
      response = await anthropic.beta.messages.create(params);
      assistantContent = [...assistantContent, ...response.content];
      if (response.stop_reason !== "pause_turn") break;
    }
  } catch (error) {
    console.error(error);
    return json({ error: "AIに問い合わせできませんでした（APIキーや残高を確かめてください）" }, 502);
  }

  if (response?.stop_reason === "refusal") {
    return json({ error: "AIが答えられませんでした。時間をおいてもう一度試してください" }, 502);
  }

  const text = assistantContent
    // deno-lint-ignore no-explicit-any
    .filter((block: any) => block.type === "text")
    // deno-lint-ignore no-explicit-any
    .map((block: any) => block.text)
    .join("\n");

  let ideas: TravelIdea[];
  try {
    ideas = parseIdeas(text);
  } catch (error) {
    console.error(error, text);
    ideas = [];
  }
  if (ideas.length === 0) {
    return json({ error: "AIの答えをうまく読み取れませんでした。もう一度試してください" }, 502);
  }

  const { data: saved, error: saveError } = await supabase
    .from("travel_suggestions")
    .upsert({ household_id: householdId, ideas, created_at: new Date().toISOString() })
    .select()
    .single();
  if (saveError || !saved) {
    console.error(saveError);
    return json({ error: "結果を保存できませんでした" }, 500);
  }
  return json(saved);
});
