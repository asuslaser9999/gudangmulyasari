-- Gudang Mulyasari — prefix gm_ di database yang sama dengan Ultimate POS / Cinnamon / Inpin.
-- Tidak mengubah tabel profiles, cn_*, ip_*, atau objek POS lainnya.
-- User terpisah kecuali owner POS yang di-bootstrap ke gm_profiles.

create extension if not exists "pgcrypto";

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ─── permissions & roles ─────────────────────────────────────────────────────

create table if not exists public.gm_permissions (
  id          uuid primary key default gen_random_uuid(),
  code        text not null unique,
  name        text not null,
  description text not null default '',
  created_at  timestamptz not null default now()
);

create table if not exists public.gm_roles (
  id         uuid primary key default gen_random_uuid(),
  code       text not null unique,
  name       text not null,
  is_system  boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists trg_gm_roles_updated_at on public.gm_roles;
create trigger trg_gm_roles_updated_at
  before update on public.gm_roles
  for each row execute function public.set_updated_at();

create table if not exists public.gm_role_permissions (
  role_id       uuid not null references public.gm_roles(id) on delete cascade,
  permission_id uuid not null references public.gm_permissions(id) on delete cascade,
  primary key (role_id, permission_id)
);

insert into public.gm_permissions (code, name, description) values
  ('users.manage', 'Kelola user', 'Tambah/ubah user Gudang Mulyasari'),
  ('roles.manage', 'Kelola hak akses', 'Ubah permission per role')
on conflict (code) do nothing;

insert into public.gm_roles (code, name, is_system) values
  ('owner', 'Owner', true),
  ('staff', 'Staf gudang', true)
on conflict (code) do nothing;

insert into public.gm_role_permissions (role_id, permission_id)
select r.id, p.id
from public.gm_roles r
cross join public.gm_permissions p
where r.code = 'owner'
on conflict do nothing;

-- ─── profiles ────────────────────────────────────────────────────────────────

create table if not exists public.gm_profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  email        text,
  display_name text not null default '',
  username     text,
  role_id      uuid not null references public.gm_roles(id),
  is_active    boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

comment on table public.gm_profiles is
  'Profil pengguna Gudang Mulyasari (terpisah dari public.profiles, cn_profiles, ip_profiles).';

create unique index if not exists idx_gm_profiles_username_lower
  on public.gm_profiles (lower(username))
  where username is not null;

drop trigger if exists trg_gm_profiles_updated_at on public.gm_profiles;
create trigger trg_gm_profiles_updated_at
  before update on public.gm_profiles
  for each row execute function public.set_updated_at();

-- Hanya owner POS yang di-bootstrap. Kasir / staf app lain tidak disalin.
insert into public.gm_profiles (
  id, email, display_name, username, role_id, is_active, created_at, updated_at
)
select
  p.id,
  p.email,
  coalesce(
    nullif(p.display_name, ''),
    nullif(p.username, ''),
    split_part(coalesce(p.email, ''), '@', 1),
    ''
  ),
  p.username,
  (select id from public.gm_roles where code = 'owner'),
  coalesce(p.is_active, true),
  p.created_at,
  p.updated_at
from public.profiles p
where p.role = 'owner'
on conflict (id) do nothing;

-- ─── helpers ─────────────────────────────────────────────────────────────────

create or replace function public.gm_is_active_user()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.gm_profiles
    where id = auth.uid()
      and is_active = true
  );
$$;

create or replace function public.gm_is_owner()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.gm_profiles p
    join public.gm_roles r on r.id = p.role_id
    where p.id = auth.uid()
      and p.is_active = true
      and r.code = 'owner'
  );
$$;

create or replace function public.gm_has_permission(p_code text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.gm_profiles p
    join public.gm_roles r on r.id = p.role_id
    where p.id = auth.uid()
      and p.is_active = true
      and (
        r.code = 'owner'
        or exists (
          select 1
          from public.gm_role_permissions rp
          join public.gm_permissions perm on perm.id = rp.permission_id
          where rp.role_id = r.id
            and perm.code = p_code
        )
      )
  );
$$;

create or replace function public.gm_handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_username text;
  v_display_name text;
  v_role_id uuid;
  v_role_code text;
begin
  v_username := lower(trim(coalesce(
    new.raw_user_meta_data->>'gm_username',
    new.raw_user_meta_data->>'username',
    ''
  )));
  if v_username = '' and new.email is not null
     and new.email like '%@gudangmulyasari.pos' then
    v_username := lower(split_part(new.email, '@', 1));
  end if;

  -- Akun POS / Cinnamon / Inpin tidak otomatis masuk Gudang Mulyasari.
  if coalesce(new.raw_user_meta_data->>'gm_role_code', '') = ''
     and coalesce(new.raw_user_meta_data->>'gm_role_id', '') = ''
     and coalesce(new.email, '') not like '%@gudangmulyasari.pos' then
    return new;
  end if;

  v_display_name := coalesce(new.raw_user_meta_data->>'display_name', v_username, '');
  v_role_code := coalesce(new.raw_user_meta_data->>'gm_role_code', 'staff');

  if not exists (select 1 from public.gm_profiles) then
    v_role_code := 'owner';
  end if;

  if new.raw_user_meta_data ? 'gm_role_id' then
    v_role_id := (new.raw_user_meta_data->>'gm_role_id')::uuid;
  else
    select id into v_role_id from public.gm_roles where code = v_role_code;
  end if;

  if v_role_id is null then
    select id into v_role_id from public.gm_roles where code = 'staff';
  end if;

  insert into public.gm_profiles (
    id, email, role_id, display_name, username, is_active
  )
  values (
    new.id,
    new.email,
    v_role_id,
    v_display_name,
    nullif(v_username, ''),
    true
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_gm on auth.users;
create trigger on_auth_user_created_gm
  after insert on auth.users
  for each row execute function public.gm_handle_new_user();

create or replace function public.gm_resolve_login_email(p_username text)
returns text
language sql
stable
security definer
set search_path = public
as $$
  with input as (
    select lower(trim(p_username)) as val
  )
  select coalesce(
    (
      select p.email
      from public.gm_profiles p, input
      where lower(p.username) = input.val
      limit 1
    ),
    (
      select p.email
      from public.gm_profiles p, input
      where lower(p.email) = input.val
      limit 1
    ),
    (
      select p.email
      from public.gm_profiles p, input
      where lower(split_part(p.email, '@', 1)) = input.val
      limit 1
    ),
    (select input.val || '@gudangmulyasari.pos' from input)
  );
$$;

revoke all on function public.gm_resolve_login_email(text) from public;
grant execute on function public.gm_resolve_login_email(text) to anon, authenticated;

grant execute on function public.gm_is_active_user() to authenticated;
grant execute on function public.gm_is_owner() to authenticated;
grant execute on function public.gm_has_permission(text) to authenticated;

-- ─── RLS ─────────────────────────────────────────────────────────────────────

alter table public.gm_permissions enable row level security;
alter table public.gm_roles enable row level security;
alter table public.gm_role_permissions enable row level security;
alter table public.gm_profiles enable row level security;

drop policy if exists "gm_permissions_select" on public.gm_permissions;
create policy "gm_permissions_select"
  on public.gm_permissions for select
  using (public.gm_is_active_user());

drop policy if exists "gm_roles_select" on public.gm_roles;
create policy "gm_roles_select"
  on public.gm_roles for select
  using (public.gm_is_active_user());

drop policy if exists "gm_roles_write" on public.gm_roles;
create policy "gm_roles_write"
  on public.gm_roles for all
  using (public.gm_has_permission('roles.manage'))
  with check (public.gm_has_permission('roles.manage'));

drop policy if exists "gm_role_permissions_select" on public.gm_role_permissions;
create policy "gm_role_permissions_select"
  on public.gm_role_permissions for select
  using (public.gm_is_active_user());

drop policy if exists "gm_role_permissions_write" on public.gm_role_permissions;
create policy "gm_role_permissions_write"
  on public.gm_role_permissions for all
  using (public.gm_has_permission('roles.manage'))
  with check (public.gm_has_permission('roles.manage'));

drop policy if exists "gm_profiles_select" on public.gm_profiles;
create policy "gm_profiles_select"
  on public.gm_profiles for select
  using (id = auth.uid() or public.gm_has_permission('users.manage'));

drop policy if exists "gm_profiles_update" on public.gm_profiles;
create policy "gm_profiles_update"
  on public.gm_profiles for update
  using (public.gm_has_permission('users.manage'))
  with check (public.gm_has_permission('users.manage'));

drop policy if exists "gm_profiles_insert" on public.gm_profiles;
create policy "gm_profiles_insert"
  on public.gm_profiles for insert
  with check (public.gm_has_permission('users.manage'));

grant select on public.gm_permissions to authenticated;
grant select on public.gm_roles to authenticated;
grant select, insert, update, delete on public.gm_role_permissions to authenticated;
grant select, insert, update on public.gm_profiles to authenticated;
