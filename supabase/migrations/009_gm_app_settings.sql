-- Pengaturan kapan staf boleh memakai aplikasi.
-- Disinkronkan ke semua perangkat. Hanya owner yang boleh mengubah.
-- Jalankan setelah 008.

create table if not exists public.gm_app_settings (
  id text primary key default 'default'
    check (id = 'default'),
  staff_access_mode text not null default 'time_restricted'
    check (staff_access_mode in ('full', 'time_restricted', 'blocked')),
  staff_access_start text not null default '05:30',
  staff_access_end text not null default '16:30',
  updated_at timestamptz not null default now(),
  updated_by uuid references public.gm_profiles(id) on delete set null
);

comment on table public.gm_app_settings is
  'Pengaturan akses staf global — dibaca user gudang, diubah owner saja.';

insert into public.gm_app_settings (id)
values ('default')
on conflict (id) do nothing;

alter table public.gm_app_settings enable row level security;

drop policy if exists "gm_app_settings_select" on public.gm_app_settings;
create policy "gm_app_settings_select"
  on public.gm_app_settings for select
  using (public.gm_is_active_user());

drop policy if exists "gm_app_settings_update_owner" on public.gm_app_settings;
create policy "gm_app_settings_update_owner"
  on public.gm_app_settings for update
  using (public.gm_is_owner())
  with check (public.gm_is_owner());

drop policy if exists "gm_app_settings_insert_owner" on public.gm_app_settings;
create policy "gm_app_settings_insert_owner"
  on public.gm_app_settings for insert
  with check (public.gm_is_owner());

drop trigger if exists trg_gm_app_settings_updated_at on public.gm_app_settings;
create trigger trg_gm_app_settings_updated_at
  before update on public.gm_app_settings
  for each row execute function public.set_updated_at();

grant select, insert, update on public.gm_app_settings to authenticated;

notify pgrst, 'reload schema';
