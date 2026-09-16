-- NON-DESTRUCTIVE MIGRATION
-- Run this file once in the Supabase SQL Editor for the existing deployment.
-- It preserves every signup and enables adding or editing only its role field.

begin;

create or replace function public.update_signup_role(
  p_signup_id uuid,
  p_role text
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

  return query update public.signups
  set role = trim(p_role)
  where signup_id = p_signup_id
  returning *;
end;
$$;

grant execute on function public.update_signup_role(uuid, text) to anon;

commit;

-- Verification output. No signup is changed by running this migration.
select signup_id, event_id, slot_number, last_name, role, signed_up_at
from public.signups
order by event_id, slot_number;
