-- Withdrawal hold must move coins from withdrawable -> reserved without
-- decreasing balance. Live wallets enforce:
--   withdrawable_balance + reserved_balance <= balance
-- The previous hold deducted balance AND increased reserved, so every
-- payout request failed with wallet_components_consistent.

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
  if not found or not settings.withdrawal_enabled then
    raise exception 'withdrawals disabled';
  end if;
  if p_amount is null or p_amount < settings.min_withdrawal or p_amount > settings.max_withdrawal then
    raise exception 'invalid withdrawal amount';
  end if;
  if p_upi_id is null or position('@' in p_upi_id) = 0 then
    raise exception 'invalid upi id';
  end if;

  select * into wallet from public.wallets where user_id = uid for update;
  if not found then
    raise exception 'wallet missing';
  end if;
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
    reference_type, reference_id, status
  ) values (
    uid, 'withdrawal_hold', p_amount,
    wallet.balance, wallet.balance,
    wallet.withdrawable_balance, wallet.withdrawable_balance - p_amount,
    wallet.reserved_balance, wallet.reserved_balance + p_amount,
    'withdrawal', row.id, 'completed'
  );

  update public.wallets
  set withdrawable_balance = withdrawable_balance - p_amount,
      reserved_balance = reserved_balance + p_amount
  where id = wallet.id
  returning * into wallet;

  return jsonb_build_object('withdrawal', to_jsonb(row), 'wallet', to_jsonb(wallet));
end;
$$;

-- Spins must spend withdrawable coins, not reserved payout holds.
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
  if wallet.withdrawable_balance < p_stake or wallet.balance < p_stake then
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

grant execute on function public.submit_withdrawal(numeric, text) to authenticated, anon, service_role;
grant execute on function public.perform_spin(numeric, uuid) to authenticated, anon, service_role;
