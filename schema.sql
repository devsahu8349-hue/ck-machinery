-- =====================================================================
-- CK Enterprises - Machinery Running Records
-- Supabase (PostgreSQL) schema. Run ONCE in Supabase > SQL Editor.
-- =====================================================================

create extension if not exists "pgcrypto";

do $$ begin
  create type public.user_role as enum ('employee', 'admin');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.record_status as enum ('pending', 'approved', 'rejected');
exception when duplicate_object then null; end $$;

-- ---------- TABLES ----------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  role public.user_role not null default 'employee',
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.machines (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  name text not null,
  model text,
  serial_number text,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.sites (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  customer_name text,
  address text,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.running_records (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.profiles(id),
  machine_id uuid not null references public.machines(id),
  site_id uuid not null references public.sites(id),
  record_date date not null,
  opening_meter numeric(12,2) not null,
  closing_meter numeric(12,2) not null,
  running_hours numeric(12,2) not null default 0,   -- always computed by trigger
  fuel_liters numeric(12,2),
  operator_name text,
  work_description text,
  downtime_hours numeric(12,2),
  remarks text,
  status public.record_status not null default 'pending',
  reviewed_by uuid references public.profiles(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint meter_order check (closing_meter >= opening_meter),
  constraint fuel_nonneg check (fuel_liters is null or fuel_liters >= 0),
  constraint downtime_nonneg check (downtime_hours is null or downtime_hours >= 0)
);

create table if not exists public.record_edit_history (
  id uuid primary key default gen_random_uuid(),
  record_id uuid not null references public.running_records(id) on delete cascade,
  edited_by uuid not null references public.profiles(id),
  old_data jsonb not null,
  new_data jsonb not null,
  reason text,
  edited_at timestamptz not null default now()
);

create index if not exists idx_records_employee on public.running_records(employee_id, record_date desc);
create index if not exists idx_records_machine  on public.running_records(machine_id, record_date desc);
create index if not exists idx_records_status   on public.running_records(status);
create index if not exists idx_history_record   on public.record_edit_history(record_id, edited_at desc);

-- ---------- HELPER FUNCTIONS ----------
create or replace function public.is_admin()
returns boolean language sql stable security definer
set search_path = public
as $$ select exists (
  select 1 from public.profiles
  where id = auth.uid() and role = 'admin' and active = true
); $$;

create or replace function public.is_active_user()
returns boolean language sql stable security definer
set search_path = public
as $$ select exists (
  select 1 from public.profiles where id = auth.uid() and active = true
); $$;

-- Auto-create a profile whenever a user is created in Supabase Auth.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, role)
  values (new.id,
          coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
          'employee')
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- ---------- RECORD TRIGGER (server-side integrity) ----------
-- Running hours are ALWAYS computed here; employees can never self-approve.
create or replace function public.running_records_biu()
returns trigger language plpgsql
as $$
begin
  new.running_hours := new.closing_meter - new.opening_meter;
  new.updated_at := now();
  if tg_op = 'INSERT' and not public.is_admin() then
    new.status := 'pending';
    new.reviewed_by := null;
    new.reviewed_at := null;
  end if;
  return new;
end $$;

drop trigger if exists trg_running_records_biu on public.running_records;
create trigger trg_running_records_biu
before insert or update on public.running_records
for each row execute function public.running_records_biu();

-- ---------- ADMIN RPCs (atomic + audited) ----------
create or replace function public.admin_edit_record(
  p_id uuid, p_opening numeric, p_closing numeric, p_fuel numeric,
  p_operator text, p_work text, p_downtime numeric, p_remarks text, p_reason text)
returns void language plpgsql security definer
set search_path = public
as $$
declare v_old public.running_records; v_new public.running_records;
begin
  if not public.is_admin() then raise exception 'Admins only'; end if;
  if coalesce(trim(p_reason), '') = '' then raise exception 'A reason for the edit is required'; end if;
  select * into v_old from public.running_records where id = p_id for update;
  if not found then raise exception 'Record not found'; end if;

  update public.running_records set
    opening_meter = p_opening, closing_meter = p_closing, fuel_liters = p_fuel,
    operator_name = p_operator, work_description = p_work,
    downtime_hours = p_downtime, remarks = p_remarks
  where id = p_id returning * into v_new;

  insert into public.record_edit_history(record_id, edited_by, old_data, new_data, reason)
  values (p_id, auth.uid(), to_jsonb(v_old), to_jsonb(v_new), p_reason);
end $$;

create or replace function public.review_record(
  p_id uuid, p_status public.record_status, p_reason text default null)
returns void language plpgsql security definer
set search_path = public
as $$
declare v_old public.running_records; v_new public.running_records;
begin
  if not public.is_admin() then raise exception 'Admins only'; end if;
  if p_status = 'rejected' and coalesce(trim(p_reason), '') = '' then
    raise exception 'A reason is required when rejecting';
  end if;
  select * into v_old from public.running_records where id = p_id for update;
  if not found then raise exception 'Record not found'; end if;

  update public.running_records set
    status = p_status, reviewed_by = auth.uid(), reviewed_at = now()
  where id = p_id returning * into v_new;

  insert into public.record_edit_history(record_id, edited_by, old_data, new_data, reason)
  values (p_id, auth.uid(), to_jsonb(v_old), to_jsonb(v_new),
          coalesce(p_reason, 'Status changed to ' || p_status));
end $$;

revoke all on function public.admin_edit_record(uuid,numeric,numeric,numeric,text,text,numeric,text,text) from public, anon;
revoke all on function public.review_record(uuid,public.record_status,text) from public, anon;
grant execute on function public.admin_edit_record(uuid,numeric,numeric,numeric,text,text,numeric,text,text) to authenticated;
grant execute on function public.review_record(uuid,public.record_status,text) to authenticated;

-- ---------- ROW LEVEL SECURITY ----------
alter table public.profiles            enable row level security;
alter table public.machines            enable row level security;
alter table public.sites               enable row level security;
alter table public.running_records     enable row level security;
alter table public.record_edit_history enable row level security;

-- profiles
drop policy if exists "users read own profile" on public.profiles;
create policy "users read own profile" on public.profiles
for select using (id = auth.uid() or public.is_admin());

drop policy if exists "admin manages profiles" on public.profiles;
create policy "admin manages profiles" on public.profiles
for all using (public.is_admin()) with check (public.is_admin());

-- machines
drop policy if exists "authenticated read active machines" on public.machines;
create policy "authenticated read active machines" on public.machines
for select to authenticated using (active = true or public.is_admin());

drop policy if exists "admin manages machines" on public.machines;
create policy "admin manages machines" on public.machines
for all using (public.is_admin()) with check (public.is_admin());

-- sites
drop policy if exists "authenticated read active sites" on public.sites;
create policy "authenticated read active sites" on public.sites
for select to authenticated using (active = true or public.is_admin());

drop policy if exists "admin manages sites" on public.sites;
create policy "admin manages sites" on public.sites
for all using (public.is_admin()) with check (public.is_admin());

-- running_records: employees insert/read own; admins read all.
-- No direct UPDATE/DELETE policy: all admin changes go through the audited RPCs above.
drop policy if exists "employee reads own records" on public.running_records;
create policy "employee reads own records" on public.running_records
for select using (employee_id = auth.uid() or public.is_admin());

drop policy if exists "employee creates own records" on public.running_records;
create policy "employee creates own records" on public.running_records
for insert with check (
  employee_id = auth.uid() and status = 'pending' and public.is_active_user()
);

drop policy if exists "admin updates records" on public.running_records;
drop policy if exists "admin deletes records" on public.running_records;

-- edit history: read-only for admins (written only by the RPCs)
drop policy if exists "admin reads edit history" on public.record_edit_history;
create policy "admin reads edit history" on public.record_edit_history
for select using (public.is_admin());

drop policy if exists "admin writes edit history" on public.record_edit_history;

-- ---------- REPORTING VIEW (approved records only) ----------
create or replace view public.monthly_machine_summary
with (security_invoker = true) as
select
  m.code,
  m.name as machine_name,
  date_trunc('month', r.record_date)::date as month,
  count(*) as records,
  sum(r.running_hours) as total_running_hours,
  sum(coalesce(r.fuel_liters, 0)) as total_fuel_liters,
  sum(coalesce(r.downtime_hours, 0)) as total_downtime_hours
from public.running_records r
join public.machines m on m.id = r.machine_id
where r.status = 'approved'
group by m.code, m.name, date_trunc('month', r.record_date);
