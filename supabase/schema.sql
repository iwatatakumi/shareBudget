-- シェアバジェット: Supabase（PostgreSQL）のテーブルと権限の設定
-- Supabaseの管理画面の「SQL Editor」にこのファイルの中身をすべて貼り付けて「Run」を押してください。
-- 何度実行しても同じ状態になるように書いてあります。

-- パスワードを安全に保存するための道具（pgcrypto）。Supabaseでは最初から入っています。
create extension if not exists pgcrypto with schema extensions;

-- ========== テーブル ==========

-- 家計簿（ルームメイトと共有する単位）
create table if not exists public.households (
  id uuid primary key default gen_random_uuid(),
  name text not null default '家計簿',
  invite_code text not null unique default upper(substr(md5(random()::text), 1, 6)),
  created_at timestamptz not null default now()
);

-- 家計簿を作った人（管理者）。参加用パスワードを変えられるのはこの人だけです。
alter table public.households
  add column if not exists owner_id uuid references auth.users(id) on delete set null;

-- 参加用パスワード（そのままではなく、元に戻せない形に変換して保存します）
-- 権限の設定で、アプリからは誰も直接読めないようにしています。
create table if not exists public.household_secrets (
  household_id uuid primary key references public.households(id) on delete cascade,
  password_hash text not null
);

-- 家計簿のメンバー（1人は1つの家計簿にだけ入れます）
create table if not exists public.members (
  household_id uuid not null references public.households(id) on delete cascade,
  user_id uuid not null unique references auth.users(id) on delete cascade,
  display_name text not null,
  joined_at timestamptz not null default now(),
  primary key (household_id, user_id)
);

-- 項目（食費など）
create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  name text not null,
  sort_order int not null default 0
);

-- 月に1回まとめて払う項目（家賃・光熱費など）かどうか。
-- オンの項目は日割りせず、払った日に「今日の支出」がオーバーにならないようにします。
alter table public.categories
  add column if not exists is_monthly boolean not null default false;

-- 人ごと・項目ごとの1か月の目標金額
create table if not exists public.member_targets (
  category_id uuid not null references public.categories(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  household_id uuid not null references public.households(id) on delete cascade,
  amount int not null default 0 check (amount >= 0),
  primary key (category_id, user_id)
);

-- 支出
create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  category_id uuid references public.categories(id) on delete set null,
  amount int not null check (amount > 0),
  spent_on date not null,
  memo text not null default '',
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now()
);

-- 支出の配分（その支出のうち、誰がいくら負担するか）
create table if not exists public.expense_shares (
  expense_id uuid not null references public.expenses(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  household_id uuid not null references public.households(id) on delete cascade,
  amount int not null check (amount >= 0),
  primary key (expense_id, user_id)
);

-- 臨時収入（ボーナスやお祝いなど。旅行資金に上乗せします）
create table if not exists public.incomes (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  amount int not null check (amount > 0),
  received_on date not null,
  memo text not null default '',
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now()
);

create index if not exists expenses_household_spent_on on public.expenses (household_id, spent_on);

-- ========== 自分の家計簿を調べる関数 ==========

create or replace function public.my_household_id()
returns uuid
language sql stable security definer set search_path = public
as $$
  select household_id from public.members where user_id = auth.uid()
$$;

-- ========== 権限（RLS: 自分の家計簿のデータだけ読み書きできる） ==========

alter table public.households enable row level security;
alter table public.members enable row level security;
alter table public.categories enable row level security;
alter table public.member_targets enable row level security;
alter table public.expenses enable row level security;
alter table public.expense_shares enable row level security;
-- household_secrets は「読み書きしてよい条件」を1つも作らないので、アプリからは見えません。
alter table public.household_secrets enable row level security;
alter table public.incomes enable row level security;

drop policy if exists "own household" on public.households;
create policy "own household" on public.households
  for select using (id = public.my_household_id());

drop policy if exists "members of own household" on public.members;
create policy "members of own household" on public.members
  for select using (household_id = public.my_household_id());

drop policy if exists "update own member" on public.members;
create policy "update own member" on public.members
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "own categories" on public.categories;
create policy "own categories" on public.categories
  for all using (household_id = public.my_household_id())
  with check (household_id = public.my_household_id());

drop policy if exists "own targets" on public.member_targets;
create policy "own targets" on public.member_targets
  for all using (household_id = public.my_household_id())
  with check (household_id = public.my_household_id());

drop policy if exists "own expenses" on public.expenses;
create policy "own expenses" on public.expenses
  for all using (household_id = public.my_household_id())
  with check (household_id = public.my_household_id());

drop policy if exists "own shares" on public.expense_shares;
create policy "own shares" on public.expense_shares
  for all using (household_id = public.my_household_id())
  with check (household_id = public.my_household_id());

drop policy if exists "own incomes" on public.incomes;
create policy "own incomes" on public.incomes
  for all using (household_id = public.my_household_id())
  with check (household_id = public.my_household_id());

-- ========== 家計簿を作る・参加する ==========

-- 古い形の関数（パスワードなし）を消します。
drop function if exists public.create_household(text);
drop function if exists public.join_household(text, text);

-- 参加用パスワードの長さを確かめます。
create or replace function public.check_household_password(p_password text)
returns void
language plpgsql immutable
as $$
begin
  if p_password is null or length(p_password) < 4 then
    raise exception 'パスワードは4文字以上にしてください';
  end if;
end;
$$;

-- 新しい家計簿を作り、最初の項目を用意します。作った人が管理者になります。
create or replace function public.create_household(p_display_name text, p_password text)
returns public.households
language plpgsql security definer set search_path = public
as $$
declare
  h public.households;
begin
  if auth.uid() is null then
    raise exception 'アプリを開き直してください';
  end if;
  if exists (select 1 from public.members where user_id = auth.uid()) then
    raise exception 'すでに家計簿に参加しています';
  end if;
  perform public.check_household_password(p_password);

  insert into public.households (owner_id) values (auth.uid()) returning * into h;
  insert into public.household_secrets (household_id, password_hash)
    values (h.id, extensions.crypt(p_password, extensions.gen_salt('bf')));
  insert into public.members (household_id, user_id, display_name)
    values (h.id, auth.uid(), p_display_name);
  insert into public.categories (household_id, name, sort_order, is_monthly)
    select h.id, name, ord - 1, name = '光熱費'
    from unnest(array['食費', '日用品', '光熱費', '交際費', 'その他']) with ordinality as t(name, ord);

  return h;
end;
$$;

-- 家計簿ID（招待コード）とパスワードで、ルームメイトの家計簿に参加します。
create or replace function public.join_household(p_invite_code text, p_password text, p_display_name text)
returns public.households
language plpgsql security definer set search_path = public
as $$
declare
  h public.households;
  saved_hash text;
begin
  if auth.uid() is null then
    raise exception 'アプリを開き直してください';
  end if;
  if exists (select 1 from public.members where user_id = auth.uid()) then
    raise exception 'すでに家計簿に参加しています';
  end if;

  select * into h from public.households where invite_code = upper(trim(p_invite_code));
  select password_hash into saved_hash from public.household_secrets where household_id = h.id;
  -- どちらが違うかは教えない（当てずっぽうで試されにくくするため）
  if h.id is null or saved_hash is null
     or extensions.crypt(coalesce(p_password, ''), saved_hash) <> saved_hash then
    raise exception '家計簿IDかパスワードが違います';
  end if;

  insert into public.members (household_id, user_id, display_name)
    values (h.id, auth.uid(), p_display_name);
  return h;
end;
$$;

-- 管理者が参加用パスワードを変えます。
-- 管理者が決まっていない古い家計簿では、最初に変えたメンバーが管理者になります。
create or replace function public.change_household_password(p_password text)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  hid uuid := public.my_household_id();
  owner uuid;
begin
  if hid is null then
    raise exception '家計簿に参加していません';
  end if;
  select owner_id into owner from public.households where id = hid;
  if owner is not null and owner <> auth.uid() then
    raise exception 'パスワードを変えられるのは、家計簿を作った人だけです';
  end if;
  perform public.check_household_password(p_password);

  update public.households set owner_id = auth.uid() where id = hid;
  insert into public.household_secrets (household_id, password_hash)
    values (hid, extensions.crypt(p_password, extensions.gen_salt('bf')))
    on conflict (household_id) do update set password_hash = excluded.password_hash;
end;
$$;

-- ========== 支出を配分ごと保存する ==========

-- 支出と配分をまとめて保存します。p_id が null なら新しく追加、あれば修正します。
-- p_shares は [{"user_id": "...", "amount": 600}, ...] の形で、合計が p_amount と同じである必要があります。
create or replace function public.save_expense(
  p_id uuid,
  p_category_id uuid,
  p_amount int,
  p_spent_on date,
  p_memo text,
  p_shares jsonb
)
returns uuid
language plpgsql security invoker set search_path = public
as $$
declare
  hid uuid := public.my_household_id();
  eid uuid;
  share_total int;
begin
  if hid is null then
    raise exception '家計簿に参加していません';
  end if;

  select coalesce(sum((s->>'amount')::int), 0) into share_total
    from jsonb_array_elements(p_shares) as s;
  if share_total <> p_amount then
    raise exception '配分の合計（%円）が金額（%円）と合いません', share_total, p_amount;
  end if;
  if exists (
    select 1 from jsonb_array_elements(p_shares) as s
    where not exists (
      select 1 from public.members m
      where m.household_id = hid and m.user_id = (s->>'user_id')::uuid
    )
  ) then
    raise exception '家計簿のメンバーではない人が配分に含まれています';
  end if;

  if p_id is null then
    insert into public.expenses (household_id, category_id, amount, spent_on, memo)
      values (hid, p_category_id, p_amount, p_spent_on, coalesce(p_memo, ''))
      returning id into eid;
  else
    update public.expenses
      set category_id = p_category_id, amount = p_amount, spent_on = p_spent_on, memo = coalesce(p_memo, '')
      where id = p_id and household_id = hid
      returning id into eid;
    if eid is null then
      raise exception '支出が見つかりません';
    end if;
    delete from public.expense_shares where expense_id = eid;
  end if;

  insert into public.expense_shares (expense_id, user_id, household_id, amount)
    select eid, (s->>'user_id')::uuid, hid, (s->>'amount')::int
    from jsonb_array_elements(p_shares) as s
    where (s->>'amount')::int > 0;

  return eid;
end;
$$;

-- ========== 月ごとの支出の合計（旅行資金の記録に使います） ==========

create or replace function public.monthly_spent()
returns table (month text, total bigint)
language sql stable security invoker set search_path = public
as $$
  select to_char(spent_on, 'YYYY-MM') as month, sum(amount) as total
  from public.expenses
  where household_id = public.my_household_id()
  group by 1
  order by 1
$$;

-- ========== アカウントとデータの削除 ==========

-- 自分のアカウントと、自分のデータを削除します（App Storeのルールで、アプリに必要な機能です）。
-- ・家計簿のメンバーが自分だけなら、家計簿ごと（支出・項目・臨時収入も）すべて削除します。
-- ・ほかのメンバーがいるなら、家計簿は残します。自分の目標金額と支出の配分は削除し、
--   自分が入力した支出・臨時収入は、ほかのメンバー（いちばん早く参加した人）が入力したものとして残します。
--   自分が管理者だった場合は、その人が新しい管理者になります。
create or replace function public.delete_my_account()
returns void
language plpgsql security definer set search_path = public
as $$
declare
  me uuid := auth.uid();
  hid uuid := public.my_household_id();
  heir uuid;
begin
  if me is null then
    raise exception 'アプリを開き直してください';
  end if;

  if hid is not null then
    select user_id into heir from public.members
      where household_id = hid and user_id <> me
      order by joined_at
      limit 1;

    if heir is null then
      delete from public.households where id = hid;
    else
      update public.expenses set created_by = heir where household_id = hid and created_by = me;
      update public.incomes set created_by = heir where household_id = hid and created_by = me;
      update public.households set owner_id = heir where id = hid and owner_id = me;
    end if;
  end if;

  -- ログイン情報を消すと、メンバー・目標金額・配分も自動で消えます（on delete cascade）
  delete from auth.users where id = me;
end;
$$;

grant execute on function public.delete_my_account() to authenticated;
grant execute on function public.create_household(text, text) to authenticated;
grant execute on function public.monthly_spent() to authenticated;
grant execute on function public.join_household(text, text, text) to authenticated;
grant execute on function public.change_household_password(text) to authenticated;
grant execute on function public.save_expense(uuid, uuid, int, date, text, jsonb) to authenticated;
