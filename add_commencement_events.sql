-- Run this file once in the Supabase SQL Editor to add the two commencement
-- events without deleting or modifying any existing faculty signups.

insert into public.events (
  event_name, event_date, start_time, end_time, start_sort, location,
  season, description, special_notes, details_key, slots_required
)
select
  'Fall 2026 Commencement', '2026-12-11', 'Schedule TBA', '', '00:00',
  'Location TBA', 'FALL 2026 · COMMENCEMENT',
  'Faculty participation in Fall 2026 Commencement. The event schedule and location will be added when announced.',
  '', '', 2
where not exists (
  select 1 from public.events
  where event_name = 'Fall 2026 Commencement' and event_date = '2026-12-11'
);

insert into public.events (
  event_name, event_date, start_time, end_time, start_sort, location,
  season, description, special_notes, details_key, slots_required
)
select
  'Spring 2027 Commencement', '2027-04-30', 'Schedule TBA', '', '00:00',
  'Location TBA', 'SPRING 2027 · COMMENCEMENT',
  'Faculty participation in Spring 2027 Commencement. The event schedule and location will be added when announced.',
  '', '', 2
where not exists (
  select 1 from public.events
  where event_name = 'Spring 2027 Commencement' and event_date = '2027-04-30'
);
