-- NON-DESTRUCTIVE MIGRATION
-- Run this file once in the Supabase SQL Editor for the existing deployment.
-- Existing events and signups are preserved. Existing signups receive a blank role.

begin;

alter table public.signups
  add column if not exists role text not null default '';

alter table public.signups
  drop constraint if exists signups_role_check;

alter table public.signups
  add constraint signups_role_check check (length(trim(role)) <= 160);

drop function if exists public.claim_next_slot(bigint, text);

create or replace function public.claim_next_slot(
  p_event_id bigint,
  p_last_name text,
  p_role text
)
returns setof public.signups
language plpgsql
security definer
set search_path = public
as $$
declare
  v_required integer;
  v_slot integer;
begin
  select slots_required into v_required from public.events
  where event_id = p_event_id for update;
  if v_required is null then raise exception 'Event not found'; end if;
  if coalesce(length(trim(p_last_name)), 0) < 1 then raise exception 'Last name is required'; end if;
  if coalesce(length(trim(p_role)), 0) < 1 then raise exception 'Role is required'; end if;

  select s into v_slot from generate_series(1, v_required) s
  where not exists (
    select 1 from public.signups x
    where x.event_id = p_event_id and x.slot_number = s
  )
  order by s limit 1;

  if v_slot is null then return; end if;

  return query insert into public.signups(event_id, slot_number, last_name, role)
    values (p_event_id, v_slot, trim(p_last_name), trim(p_role))
    returning *;
end;
$$;

grant execute on function public.claim_next_slot(bigint, text, text) to anon;

commit;

-- Verification output. Existing signup records remain in place.
select signup_id, event_id, slot_number, last_name, role, signed_up_at
from public.signups
order by event_id, slot_number;
