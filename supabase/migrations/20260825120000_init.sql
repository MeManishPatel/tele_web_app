-- Spin & Win core schema. Flutter uses the anon key + user JWT only.
-- Balance changes happen through SECURITY DEFINER functions / Edge Functions.

create extension if not exists pgcrypto;

create table if not exists public.users (
  id uuid primary key references auth.users (id) on delete cascade,
  telegram_id bigint unique not null,
  username text,
  first_name text not null default 'Player',
  last_name text,
  photo_url text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_active_at timestamptz not null default now()
);

create table if not exists public.admin_users (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.users (id) on delete cascade,
  role text not null default 'admin',
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.wallets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.users (id) on delete cascade,
  balance numeric(14, 2) not null default 0 check (balance >= 0),
  withdrawable_balance numeric(14, 2) not null default 0 check (withdrawable_balance >= 0),
  reserved_balance numeric(14, 2) not null default 0 check (reserved_balance >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.wallet_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  type text not null,
  amount numeric(14, 2) not null,
  balance_before numeric(14, 2) not null,
  balance_after numeric(14, 2) not null,
  withdrawable_before numeric(14, 2) not null,
  withdrawable_after numeric(14, 2) not null,
  reserved_before numeric(14, 2) not null,
  reserved_after numeric(14, 2) not null,
  reference_type text,
  reference_id uuid,
  status text not null default 'posted',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.wheel_multipliers (
  id uuid primary key default gen_random_uuid(),
  label text not null,
  multiplier numeric(8, 2) not null,
  probability_weight numeric(10, 2) not null default 1,
  is_active boolean not null default true,
  color text not null default '#334155',
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.spins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  multiplier_id uuid references public.wheel_multipliers (id),
  multiplier numeric(8, 2) not null,
  stake numeric(14, 2) not null,
  reward numeric(14, 2) not null,
  status text not null default 'completed',
  request_id uuid not null unique,
  created_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

create table if not exists public.payment_packages (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  coins numeric(14, 2) not null,
  price numeric(14, 2) not null,
  currency text not null default 'INR',
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.deposit_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  package_id uuid references public.payment_packages (id),
  amount numeric(14, 2) not null,
  coins numeric(14, 2) not null,
  utr_number text not null,
  screenshot_path text,
  status text not null default 'pending',
  admin_note text,
  submitted_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references public.users (id)
);

create table if not exists public.withdrawal_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  amount numeric(14, 2) not null,
  upi_id text not null,
  status text not null default 'pending',
  admin_note text,
  admin_reference text,
  requested_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references public.users (id),
  paid_at timestamptz
);

create table if not exists public.platform_settings (
  id integer primary key default 1 check (id = 1),
  upi_id text not null default 'spinwin@upi',
  upi_display_name text not null default 'Spin & Win',
  upi_qr_path text,
  payment_instructions text not null default 'Pay the amount to the UPI ID, then submit the 12-digit UTR.',
  withdrawal_enabled boolean not null default true,
  min_withdrawal numeric(14, 2) not null default 100,
  max_withdrawal numeric(14, 2) not null default 50000,
  updated_at timestamptz not null default now()
);

create index if not exists wallet_transactions_user_created_idx
  on public.wallet_transactions (user_id, created_at desc);
create index if not exists spins_user_created_idx
  on public.spins (user_id, created_at desc);
create index if not exists deposit_requests_user_idx
  on public.deposit_requests (user_id, submitted_at desc);
create index if not exists withdrawal_requests_user_idx
  on public.withdrawal_requests (user_id, requested_at desc);

insert into public.wheel_multipliers (label, multiplier, probability_weight, color, sort_order)
select * from (values
  ('0.5X', 0.50, 35, '#334155', 1),
  ('1.0X', 1.00, 30, '#1E293B', 2),
  ('1.5X', 1.50, 15, '#0F766E', 3),
  ('2.0X', 2.00, 10, '#D4AF37', 4),
  ('3.0X', 3.00, 6,  '#EAB308', 5),
  ('5.0X', 5.00, 3,  '#F97316', 6),
  ('10.0X', 10.00, 1, '#EF4444', 7)
) as seed(label, multiplier, probability_weight, color, sort_order)
where not exists (select 1 from public.wheel_multipliers);

insert into public.payment_packages (name, coins, price, sort_order)
select * from (values
  ('Starter', 100, 100, 1),
  ('Plus', 500, 450, 2),
  ('Pro', 1000, 800, 3)
) as seed(name, coins, price, sort_order)
where not exists (select 1 from public.payment_packages);

insert into public.platform_settings (id)
values (1)
on conflict (id) do nothing;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists users_updated_at on public.users;
create trigger users_updated_at before update on public.users
for each row execute procedure public.set_updated_at();

drop trigger if exists wallets_updated_at on public.wallets;
create trigger wallets_updated_at before update on public.wallets
for each row execute procedure public.set_updated_at();

create or replace function public.ensure_user_wallet()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.wallets (user_id) values (new.id)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists users_ensure_wallet on public.users;
create trigger users_ensure_wallet after insert on public.users
for each row execute procedure public.ensure_user_wallet();

create or replace function public.perform_spin(p_stake numeric, p_request_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  existing public.spins%rowtype;
  wallet public.wallets%rowtype;
  chosen public.wheel_multipliers%rowtype;
  reward numeric(14, 2);
  spin_row public.spins%rowtype;
  roll numeric;
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;
  if p_stake is null or p_stake < 10 then
    raise exception 'invalid stake';
  end if;

  select * into existing from public.spins where request_id = p_request_id;
  if found then
    select * into wallet from public.wallets where user_id = uid;
    return jsonb_build_object(
      'idempotent', true,
      'spin', to_jsonb(existing),
      'wallet', to_jsonb(wallet)
    );
  end if;

  select * into wallet from public.wallets where user_id = uid for update;
  if not found then
    raise exception 'wallet missing';
  end if;
  if wallet.balance < p_stake then
    raise exception 'insufficient balance';
  end if;

  select random() * coalesce(sum(probability_weight), 0)
    into roll
  from public.wheel_multipliers
  where is_active;
  if roll is null or roll = 0 then
    raise exception 'no active multipliers';
  end if;

  select id, label, multiplier, probability_weight, is_active, color, sort_order, created_at, updated_at
    into chosen
  from (
    select m.*,
           sum(m.probability_weight) over (order by m.sort_order, m.id) as running_weight
    from public.wheel_multipliers m
    where m.is_active
  ) weighted
  where running_weight >= roll
  order by running_weight
  limit 1;

  if chosen.id is null then
    raise exception 'no active multipliers';
  end if;

  reward := round(p_stake * chosen.multiplier, 2);

  insert into public.wallet_transactions (
    user_id, type, amount,
    balance_before, balance_after,
    withdrawable_before, withdrawable_after,
    reserved_before, reserved_after,
    reference_type, reference_id, metadata
  ) values (
    uid, 'spin_cost', p_stake,
    wallet.balance, wallet.balance - p_stake,
    wallet.withdrawable_balance, wallet.withdrawable_balance - p_stake,
    wallet.reserved_balance, wallet.reserved_balance,
    'spin', p_request_id, jsonb_build_object('label', chosen.label)
  );

  wallet.balance := wallet.balance - p_stake;
  wallet.withdrawable_balance := wallet.withdrawable_balance - p_stake;

  insert into public.wallet_transactions (
    user_id, type, amount,
    balance_before, balance_after,
    withdrawable_before, withdrawable_after,
    reserved_before, reserved_after,
    reference_type, reference_id, metadata
  ) values (
    uid, 'spin_reward', reward,
    wallet.balance, wallet.balance + reward,
    wallet.withdrawable_balance, wallet.withdrawable_balance + reward,
    wallet.reserved_balance, wallet.reserved_balance,
    'spin', p_request_id, jsonb_build_object('label', chosen.label, 'multiplier', chosen.multiplier)
  );

  wallet.balance := wallet.balance + reward;
  wallet.withdrawable_balance := wallet.withdrawable_balance + reward;

  update public.wallets
  set balance = wallet.balance,
      withdrawable_balance = wallet.withdrawable_balance
  where id = wallet.id;

  insert into public.spins (
    user_id, multiplier_id, multiplier, stake, reward, request_id, metadata
  ) values (
    uid, chosen.id, chosen.multiplier, p_stake, reward, p_request_id,
    jsonb_build_object('label', chosen.label)
  )
  returning * into spin_row;

  update public.users set last_active_at = now() where id = uid;

  return jsonb_build_object(
    'idempotent', false,
    'spin', to_jsonb(spin_row),
    'wallet', to_jsonb(wallet),
    'label', chosen.label
  );
end;
$$;

create or replace function public.submit_deposit(p_amount numeric, p_utr text, p_package_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  row public.deposit_requests%rowtype;
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;
  if p_amount is null or p_amount < 10 then
    raise exception 'invalid amount';
  end if;
  if p_utr is null or length(trim(p_utr)) < 12 then
    raise exception 'invalid utr';
  end if;

  if exists (
    select 1 from public.deposit_requests
    where user_id = uid and utr_number = trim(p_utr)
  ) then
    raise exception 'duplicate utr';
  end if;

  insert into public.deposit_requests (user_id, package_id, amount, coins, utr_number, status)
  values (uid, p_package_id, p_amount, p_amount, trim(p_utr), 'pending')
  returning * into row;

  return to_jsonb(row);
end;
$$;

create or replace function public.submit_withdrawal(p_amount numeric, p_upi_id text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  settings public.platform_settings%rowtype;
  wallet public.wallets%rowtype;
  row public.withdrawal_requests%rowtype;
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;

  select * into settings from public.platform_settings where id = 1;
  if not settings.withdrawal_enabled then
    raise exception 'withdrawals disabled';
  end if;
  if p_amount is null or p_amount < settings.min_withdrawal or p_amount > settings.max_withdrawal then
    raise exception 'invalid withdrawal amount';
  end if;
  if p_upi_id is null or position('@' in p_upi_id) = 0 then
    raise exception 'invalid upi id';
  end if;

  select * into wallet from public.wallets where user_id = uid for update;
  if wallet.withdrawable_balance < p_amount then
    raise exception 'insufficient balance';
  end if;

  insert into public.withdrawal_requests (user_id, amount, upi_id, status)
  values (uid, p_amount, lower(trim(p_upi_id)), 'pending')
  returning * into row;

  insert into public.wallet_transactions (
    user_id, type, amount,
    balance_before, balance_after,
    withdrawable_before, withdrawable_after,
    reserved_before, reserved_after,
    reference_type, reference_id
  ) values (
    uid, 'withdrawal_hold', p_amount,
    wallet.balance, wallet.balance - p_amount,
    wallet.withdrawable_balance, wallet.withdrawable_balance - p_amount,
    wallet.reserved_balance, wallet.reserved_balance + p_amount,
    'withdrawal', row.id
  );

  update public.wallets
  set balance = balance - p_amount,
      withdrawable_balance = withdrawable_balance - p_amount,
      reserved_balance = reserved_balance + p_amount
  where id = wallet.id
  returning * into wallet;

  return jsonb_build_object('withdrawal', to_jsonb(row), 'wallet', to_jsonb(wallet));
end;
$$;

alter table public.users enable row level security;
alter table public.admin_users enable row level security;
alter table public.wallets enable row level security;
alter table public.wallet_transactions enable row level security;
alter table public.wheel_multipliers enable row level security;
alter table public.spins enable row level security;
alter table public.payment_packages enable row level security;
alter table public.deposit_requests enable row level security;
alter table public.withdrawal_requests enable row level security;
alter table public.platform_settings enable row level security;

drop policy if exists users_select_own on public.users;
create policy users_select_own on public.users
  for select to authenticated using (id = auth.uid());

drop policy if exists wallets_select_own on public.wallets;
create policy wallets_select_own on public.wallets
  for select to authenticated using (user_id = auth.uid());

drop policy if exists wallet_tx_select_own on public.wallet_transactions;
create policy wallet_tx_select_own on public.wallet_transactions
  for select to authenticated using (user_id = auth.uid());

drop policy if exists spins_select_own on public.spins;
create policy spins_select_own on public.spins
  for select to authenticated using (user_id = auth.uid());

drop policy if exists deposits_select_own on public.deposit_requests;
create policy deposits_select_own on public.deposit_requests
  for select to authenticated using (user_id = auth.uid());

drop policy if exists withdrawals_select_own on public.withdrawal_requests;
create policy withdrawals_select_own on public.withdrawal_requests
  for select to authenticated using (user_id = auth.uid());

drop policy if exists multipliers_select_active on public.wheel_multipliers;
create policy multipliers_select_active on public.wheel_multipliers
  for select to authenticated using (is_active = true);

drop policy if exists packages_select_active on public.payment_packages;
create policy packages_select_active on public.payment_packages
  for select to authenticated using (is_active = true);

drop policy if exists settings_select_authenticated on public.platform_settings;
create policy settings_select_authenticated on public.platform_settings
  for select to authenticated using (true);

grant execute on function public.perform_spin(numeric, uuid) to authenticated;
grant execute on function public.submit_deposit(numeric, text, uuid) to authenticated;
grant execute on function public.submit_withdrawal(numeric, text) to authenticated;
