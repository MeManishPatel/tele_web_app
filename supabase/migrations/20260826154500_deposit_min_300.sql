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
  if p_amount is null or p_amount < 300 then
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

grant execute on function public.submit_deposit(numeric, text, uuid, text, text) to authenticated;
