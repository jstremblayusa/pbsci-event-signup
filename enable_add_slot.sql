-- NON-DESTRUCTIVE MIGRATION
-- Run this file once in the Supabase SQL Editor for the existing deployment.
-- It preserves every current event and signup.

begin;

-- The original schema limited each event to no more than 20 positions.
alter table public.events
  drop constraint if exists events_slots_required_check;

alter table public.events
  add constraint events_slots_required_check check (slots_required >= 1);

-- A single UPDATE is atomic, so simultaneous clicks cannot overwrite one another.
create or replace function public.add_event_slot(p_event_id bigint)
returns setof public.events
language sql
security definer
set search_path = public
as $$
  update public.events
  set slots_required = slots_required + 1
  where event_id = p_event_id
  returning *;
$$;

grant execute on function public.add_event_slot(bigint) to anon;

commit;

-- Verification output. Existing signup rows are not changed.
select event_id, event_name, event_date, slots_required
from public.events
order by event_date, start_sort;
