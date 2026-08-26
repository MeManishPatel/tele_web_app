-- Deposits visible to admin, payment receipt storage, review RPCs.

alter table public.deposit_requests
  add column if not exists screenshot_url text;

alter table public.platform_settings
  add column if not exists admin_access_code text;

update public.platform_settings
set admin_access_code = coalesce(nullif(admin_access_code, ''), '__ADMIN_CODE__')
where id = 1;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'payment-screenshots',
  'payment-screenshots',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic']
)
on conflict (id) do update
set file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists receipts_insert_own on storage.objects;
create policy receipts_insert_own
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'payment-screenshots'
  and split_part(name, '/', 1) = auth.uid()::text
);

drop policy if exists receipts_select_own on storage.objects;
create policy receipts_select_own
on storage.objects
for select
to authenticated
using (
  bucket_id = 'payment-screenshots'
  and split_part(name, '/', 1) = auth.uid()::text
);

drop function if exists public.submit_deposit(numeric, text, uuid);
drop function if exists public.submit_deposit(numeric, text, uuid, text, text);

create or replace function public.submit_deposit(
  p_amount numeric,
  p_utr text,
  p_package_id uuid default null,
  p_screenshot_path text default null,
  p_screenshot_url text default null
)
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

  insert into public.deposit_requests (
    user_id, package_id, amount, coins, utr_number, status, screenshot_path, screenshot_url
  ) values (
    uid, p_package_id, p_amount, p_amount, trim(p_utr), 'pending',
    p_screenshot_path, p_screenshot_url
  )
  returning * into row;

  return to_jsonb(row);
end;
$$;

create or replace function public.admin_list_deposits(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  expected text;
begin
  select admin_access_code into expected from public.platform_settings where id = 1;
  if expected is null or expected = '' or p_code is distinct from expected then
    raise exception 'unauthorized';
  end if;

  return coalesce((
    select jsonb_agg(row_to_json(x) order by x.submitted_at desc)
    from (
      select
        d.id,
        d.user_id,
        d.amount,
        d.coins,
        d.utr_number,
        d.screenshot_path,
        d.screenshot_url,
        d.status,
        d.admin_note,
        d.submitted_at,
        u.first_name,
        u.last_name,
        u.username,
        u.telegram_id
      from public.deposit_requests d
      left join public.users u on u.id = d.user_id
    ) x
  ), '[]'::jsonb);
end;
$$;

create or replace function public.admin_review_deposit(
  p_code text,
  p_deposit_id uuid,
  p_approve boolean,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  expected text;
  dep public.deposit_requests%rowtype;
  wallet public.wallets%rowtype;
begin
  select admin_access_code into expected from public.platform_settings where id = 1;
  if expected is null or expected = '' or p_code is distinct from expected then
    raise exception 'unauthorized';
  end if;

  select * into dep from public.deposit_requests where id = p_deposit_id for update;
  if not found then
    raise exception 'deposit not found';
  end if;
  if dep.status is distinct from 'pending' then
    raise exception 'deposit already reviewed';
  end if;

  if p_approve then
    select * into wallet from public.wallets where user_id = dep.user_id for update;
    if not found then
      raise exception 'wallet missing';
    end if;

    insert into public.wallet_transactions (
      user_id, type, amount,
      balance_before, balance_after,
      withdrawable_before, withdrawable_after,
      reserved_before, reserved_after,
      reference_type, reference_id
    ) values (
      dep.user_id, 'deposit', dep.coins,
      wallet.balance, wallet.balance + dep.coins,
      wallet.withdrawable_balance, wallet.withdrawable_balance + dep.coins,
      wallet.reserved_balance, wallet.reserved_balance,
      'deposit', dep.id
    );

    update public.wallets
    set balance = balance + dep.coins,
        withdrawable_balance = withdrawable_balance + dep.coins
    where id = wallet.id;

    update public.deposit_requests
    set status = 'approved',
        admin_note = p_note,
        reviewed_at = now()
    where id = dep.id
    returning * into dep;
  else
    update public.deposit_requests
    set status = 'rejected',
        admin_note = p_note,
        reviewed_at = now()
    where id = dep.id
    returning * into dep;
  end if;

  return to_jsonb(dep);
end;
$$;

grant execute on function public.submit_deposit(numeric, text, uuid, text, text) to authenticated;
grant execute on function public.admin_list_deposits(text) to anon, authenticated;
grant execute on function public.admin_review_deposit(text, uuid, boolean, text) to anon, authenticated;
