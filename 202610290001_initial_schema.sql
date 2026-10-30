-- Initial Water Care schema for Supabase/PostgreSQL.
-- Public tracking uses an unguessable tracking ID; direct report reads stay restricted.

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  role text not null default 'resident'
    check (role in ('resident', 'surveyor', 'admin')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.water_points (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 1 and 200),
  source_type text not null check (char_length(trim(source_type)) between 1 and 100),
  address text,
  locality text not null check (char_length(trim(locality)) between 1 and 200),
  latitude numeric(9, 6) not null check (latitude between -90 and 90),
  longitude numeric(9, 6) not null check (longitude between -180 and 180),
  availability_status text not null default 'unknown'
    check (availability_status in ('available', 'limited', 'unavailable', 'unknown')),
  last_verified_at timestamptz,
  verification_source text,
  verified_by uuid references public.profiles (id) on delete set null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    availability_status = 'unknown'
    or (
      last_verified_at is not null
      and verification_source is not null
      and char_length(trim(verification_source)) > 0
    )
  )
);

create table public.facilities (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 1 and 200),
  facility_type text not null check (char_length(trim(facility_type)) between 1 and 100),
  location text not null check (char_length(trim(location)) between 1 and 300),
  condition text not null default 'unknown'
    check (condition in ('good', 'needs_attention', 'out_of_service', 'unknown')),
  maintenance_notes text,
  active boolean not null default true,
  updated_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  tracking_id text not null unique
    default ('WC-' || upper(replace(gen_random_uuid()::text, '-', ''))),
  issue_category text not null
    check (issue_category in ('no_supply', 'low_supply', 'quality_concern', 'leakage', 'tap_damage', 'other')),
  description text not null check (char_length(trim(description)) between 10 and 10000),
  water_point_id uuid references public.water_points (id) on delete set null,
  locality text not null check (char_length(trim(locality)) between 1 and 200),
  location_description text,
  contact_information text,
  status text not null default 'open'
    check (status in ('open', 'in_progress', 'resolved', 'closed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.report_updates (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.reports (id) on delete cascade,
  previous_status text not null
    check (previous_status in ('open', 'in_progress', 'resolved', 'closed')),
  new_status text not null
    check (new_status in ('open', 'in_progress', 'resolved', 'closed')),
  update_note text check (update_note is null or char_length(update_note) <= 2000),
  updated_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now(),
  check (previous_status <> new_status)
);

create table public.survey_records (
  id uuid primary key default gen_random_uuid(),
  water_point_id uuid references public.water_points (id) on delete set null,
  surveyor_id uuid not null references public.profiles (id),
  surveyed_at timestamptz not null,
  locality text not null check (char_length(trim(locality)) between 1 and 200),
  source_type text not null check (char_length(trim(source_type)) between 1 and 100),
  observed_availability text not null
    check (observed_availability in ('available', 'limited', 'unavailable', 'not_observed')),
  reported_supply_timings text,
  reported_interruptions text,
  observed_infrastructure_issues text,
  survey_method text not null check (char_length(trim(survey_method)) between 1 and 500),
  observed_conditions text,
  resident_reported_findings text,
  recommendations text,
  evidence_references text[] not null default '{}',
  verification_status text not null default 'pending'
    check (verification_status in ('pending', 'verified', 'rejected', 'correction_requested')),
  verified_by uuid references public.profiles (id) on delete set null,
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    (verification_status = 'verified' and verified_by is not null and verified_at is not null)
    or (verification_status <> 'verified' and verified_at is null)
  )
);

create table public.water_quality_tests (
  id uuid primary key default gen_random_uuid(),
  water_point_id uuid not null references public.water_points (id) on delete cascade,
  test_date timestamptz not null,
  parameter_name text not null check (char_length(trim(parameter_name)) between 1 and 200),
  measured_value numeric not null,
  unit text not null check (char_length(trim(unit)) between 1 and 50),
  applicable_standard text,
  testing_organization text not null check (char_length(trim(testing_organization)) between 1 and 300),
  evidence_reference text,
  verification_status text not null default 'pending'
    check (verification_status in ('pending', 'verified', 'rejected', 'correction_requested')),
  entered_by uuid not null references public.profiles (id),
  verified_by uuid references public.profiles (id) on delete set null,
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    (verification_status = 'verified' and verified_by is not null and verified_at is not null)
    or (verification_status <> 'verified' and verified_at is null)
  )
);

create index water_points_locality_active_idx on public.water_points (locality, active);
create index facilities_location_active_idx on public.facilities (location, active);
create index reports_status_created_idx on public.reports (status, created_at desc);
create index reports_locality_created_idx on public.reports (locality, created_at desc);
create index report_updates_report_created_idx on public.report_updates (report_id, created_at);
create index survey_records_status_date_idx on public.survey_records (verification_status, surveyed_at desc);
create index survey_records_surveyor_date_idx on public.survey_records (surveyor_id, surveyed_at desc);
create index water_quality_point_date_idx on public.water_quality_tests (water_point_id, test_date desc);

create view public.verified_survey_records
with (security_barrier = true)
as
select
  id,
  water_point_id,
  surveyed_at,
  locality,
  source_type,
  observed_availability,
  reported_supply_timings,
  reported_interruptions,
  observed_infrastructure_issues,
  survey_method,
  observed_conditions,
  resident_reported_findings,
  recommendations,
  evidence_references,
  verification_status,
  verified_at,
  created_at,
  updated_at
from public.survey_records
where verification_status = 'verified';

create view public.verified_water_quality_tests
with (security_barrier = true)
as
select
  id,
  water_point_id,
  test_date,
  parameter_name,
  measured_value,
  unit,
  applicable_standard,
  testing_organization,
  evidence_reference,
  verification_status,
  verified_at,
  created_at,
  updated_at
from public.water_quality_tests
where verification_status = 'verified';

create function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create trigger water_points_set_updated_at
before update on public.water_points
for each row execute function public.set_updated_at();

create trigger facilities_set_updated_at
before update on public.facilities
for each row execute function public.set_updated_at();

create trigger reports_set_updated_at
before update on public.reports
for each row execute function public.set_updated_at();

create trigger survey_records_set_updated_at
before update on public.survey_records
for each row execute function public.set_updated_at();

create trigger water_quality_tests_set_updated_at
before update on public.water_quality_tests
for each row execute function public.set_updated_at();

create function public.create_resident_profile()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.profiles (id, role)
  values (new.id, 'resident')
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger auth_user_create_profile
after insert on auth.users
for each row execute function public.create_resident_profile();

create function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and role = 'admin'
  );
$$;

create function public.is_surveyor_or_admin()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and role in ('surveyor', 'admin')
  );
$$;

create function public.submit_report(
  p_issue_category text,
  p_description text,
  p_locality text,
  p_location_description text default null,
  p_water_point_id uuid default null,
  p_contact_information text default null
)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  new_tracking_id text;
begin
  if p_issue_category is null or p_issue_category not in ('no_supply', 'low_supply', 'quality_concern', 'leakage', 'tap_damage', 'other') then
    raise exception 'Choose a valid issue category.' using errcode = '22023';
  end if;
  if p_description is null or char_length(trim(p_description)) not between 10 and 10000 then
    raise exception 'Description must be between 10 and 10000 characters.' using errcode = '22023';
  end if;
  if p_locality is null or char_length(trim(p_locality)) not between 1 and 200 then
    raise exception 'Locality is required and must be 200 characters or fewer.' using errcode = '22023';
  end if;
  if p_location_description is not null and char_length(p_location_description) > 500 then
    raise exception 'Location details must be 500 characters or fewer.' using errcode = '22023';
  end if;
  if p_contact_information is not null and char_length(p_contact_information) > 200 then
    raise exception 'Contact information must be 200 characters or fewer.' using errcode = '22023';
  end if;

  insert into public.reports (
    issue_category, description, locality, location_description,
    water_point_id, contact_information
  )
  values (
    p_issue_category, trim(p_description), trim(p_locality), nullif(trim(p_location_description), ''),
    p_water_point_id, nullif(trim(p_contact_information), '')
  )
  returning tracking_id into new_tracking_id;

  return new_tracking_id;
end;
$$;

create function public.track_report(p_tracking_id text)
returns table (
  tracking_id text,
  issue_category text,
  locality text,
  description text,
  status text,
  created_at timestamptz,
  updated_at timestamptz,
  status_history jsonb
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    r.tracking_id,
    r.issue_category,
    r.locality,
    r.description,
    r.status,
    r.created_at,
    r.updated_at,
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'previous_status', u.previous_status,
            'new_status', u.new_status,
            'created_at', u.created_at
          )
          order by u.created_at
        )
        from public.report_updates as u
        where u.report_id = r.id
      ),
      '[]'::jsonb
    )
  from public.reports as r
  where r.tracking_id = upper(trim(p_tracking_id));
$$;

create function public.admin_update_report_status(
  p_report_id uuid,
  p_new_status text,
  p_update_note text default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  old_status text;
begin
  if not public.is_admin() then
    raise exception 'Administrator access is required.' using errcode = '42501';
  end if;
  if p_new_status is null or p_new_status not in ('open', 'in_progress', 'resolved', 'closed') then
    raise exception 'Choose a valid report status.' using errcode = '22023';
  end if;
  if p_update_note is not null and char_length(p_update_note) > 2000 then
    raise exception 'Update notes must be 2000 characters or fewer.' using errcode = '22023';
  end if;

  select status into old_status
  from public.reports
  where id = p_report_id
  for update;
  if old_status is null then
    raise exception 'Report was not found.' using errcode = 'P0002';
  end if;
  if old_status = p_new_status then
    return;
  end if;
  if not (
    (old_status = 'open' and p_new_status in ('in_progress', 'closed'))
    or (old_status = 'in_progress' and p_new_status in ('open', 'resolved', 'closed'))
    or (old_status = 'resolved' and p_new_status in ('in_progress', 'closed'))
    or (old_status = 'closed' and p_new_status = 'open')
  ) then
    raise exception 'That report status change is not allowed.' using errcode = '22023';
  end if;

  update public.reports
  set status = p_new_status
  where id = p_report_id;

  insert into public.report_updates (
    report_id, previous_status, new_status, update_note, updated_by
  )
  values (
    p_report_id, old_status, p_new_status, nullif(trim(p_update_note), ''), (select auth.uid())
  );
end;
$$;

alter table public.profiles enable row level security;
alter table public.water_points enable row level security;
alter table public.facilities enable row level security;
alter table public.reports enable row level security;
alter table public.report_updates enable row level security;
alter table public.survey_records enable row level security;
alter table public.water_quality_tests enable row level security;

create policy "Profiles are visible to their owner or administrators"
on public.profiles for select to authenticated
using (id = (select auth.uid()) or (select public.is_admin()));

create policy "Administrators manage profiles"
on public.profiles for all to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));

create policy "Public can read active water points"
on public.water_points for select to anon, authenticated
using (active = true);

create policy "Administrators manage water points"
on public.water_points for all to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));

create policy "Public can read active facilities"
on public.facilities for select to anon, authenticated
using (active = true);

create policy "Administrators manage facilities"
on public.facilities for all to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));

create policy "Administrators read reports"
on public.reports for select to authenticated
using ((select public.is_admin()));

create policy "Administrators read report history"
on public.report_updates for select to authenticated
using ((select public.is_admin()));

create policy "Public can read verified surveys"
on public.survey_records for select to anon, authenticated
using (verification_status = 'verified');

create policy "Surveyors submit their own survey records"
on public.survey_records for insert to authenticated
with check (
  (select public.is_surveyor_or_admin())
  and surveyor_id = (select auth.uid())
  and verification_status = 'pending'
  and verified_by is null
  and verified_at is null
);

create policy "Surveyors edit pending records and administrators review them"
on public.survey_records for update to authenticated
using (
  (select public.is_admin())
  or (
    surveyor_id = (select auth.uid())
    and verification_status in ('pending', 'correction_requested')
  )
)
with check (
  (select public.is_admin())
  or (
    surveyor_id = (select auth.uid())
    and verification_status in ('pending', 'correction_requested')
    and verified_by is null
    and verified_at is null
  )
);

create policy "Public can read verified water quality tests"
on public.water_quality_tests for select to anon, authenticated
using (verification_status = 'verified');

create policy "Surveyors submit unverified water quality tests"
on public.water_quality_tests for insert to authenticated
with check (
  (select public.is_surveyor_or_admin())
  and entered_by = (select auth.uid())
  and verification_status = 'pending'
  and verified_by is null
  and verified_at is null
);

create policy "Administrators manage water quality verification"
on public.water_quality_tests for update to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));

grant select on public.water_points, public.facilities to anon, authenticated;
grant insert, update on public.water_points, public.facilities to authenticated;
grant select on public.reports to authenticated;
grant select on public.report_updates to authenticated;
grant select, update on public.profiles to authenticated;
grant select, insert, update on public.survey_records to authenticated;
grant select, insert, update on public.water_quality_tests to authenticated;
grant select on public.verified_survey_records, public.verified_water_quality_tests to anon, authenticated;

revoke all on function public.create_resident_profile() from public, anon, authenticated;
revoke all on function public.set_updated_at() from public, anon, authenticated;
revoke all on function public.is_admin() from public, anon;
revoke all on function public.is_surveyor_or_admin() from public, anon;
revoke all on function public.submit_report(text, text, text, text, uuid, text) from public;
revoke all on function public.track_report(text) from public;
revoke all on function public.admin_update_report_status(uuid, text, text) from public, anon;
grant execute on function public.is_admin() to authenticated;
grant execute on function public.is_surveyor_or_admin() to authenticated;
grant execute on function public.submit_report(text, text, text, text, uuid, text) to anon, authenticated;
grant execute on function public.track_report(text) to anon, authenticated;
grant execute on function public.admin_update_report_status(uuid, text, text) to authenticated;
