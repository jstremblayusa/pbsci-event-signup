-- NON-DESTRUCTIVE MIGRATION
-- Run this file once in the Supabase SQL Editor for the existing deployment.
-- It preserves every event and signup. Existing signups receive a blank
-- location that can be completed with the app's Edit details button.

begin;

alter table public.signups
  add column if not exists location text not null default '';

-- New signups provide both a role and a location. This four-argument version
-- can coexist safely with the earlier three-argument function.
create or replace function public.claim_next_slot(
  p_event_id bigint,
  p_last_name text,
  p_role text,
  p_location text
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
  select slots_required into v_required
  from public.events
  where event_id = p_event_id
  for update;

  if v_required is null then
    raise exception 'Event not found';
  end if;

  select s into v_slot
  from generate_series(1, v_required) s
  where not exists (
    select 1
    from public.signups x
    where x.event_id = p_event_id and x.slot_number = s
  )
  order by s
  limit 1;

  if v_slot is null then
    return;
  end if;

  if coalesce(length(trim(p_last_name)), 0) < 1 then
    raise exception 'Last name is required';
  end if;
  if coalesce(length(trim(p_role)), 0) < 1 then
    raise exception 'Role is required';
  end if;
  if coalesce(length(trim(p_location)), 0) < 1 then
    raise exception 'Location is required';
  end if;

  return query
  insert into public.signups(event_id, slot_number, last_name, role, location)
  values (
    p_event_id,
    v_slot,
    trim(p_last_name),
    left(trim(p_role), 160),
    left(trim(p_location), 240)
  )
  returning *;
end;
$$;

-- Update only the descriptive fields for one existing signup. The signup ID,
-- event, slot number, name, and timestamp remain unchanged.
create or replace function public.update_signup_details(
  p_signup_id uuid,
  p_role text,
  p_location text
)
returns setof public.signups
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(length(trim(p_role)), 0) < 1 then
    raise exception 'Role is required';
  end if;
  if coalesce(length(trim(p_location)), 0) < 1 then
    raise exception 'Location is required';
  end if;

  return query
  update public.signups
  set role = left(trim(p_role), 160),
      location = left(trim(p_location), 240)
  where signup_id = p_signup_id
  returning *;
end;
$$;

grant execute on function public.claim_next_slot(bigint, text, text, text) to anon;
grant execute on function public.update_signup_details(uuid, text, text) to anon;

commit;

-- Verification output only. This SELECT does not change any data.
select signup_id, event_id, slot_number, last_name, role, location, signed_up_at
from public.signups
order by event_id, slot_number;
