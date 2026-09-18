-- Staf gudang boleh melihat nama user lain (untuk rekap pengambilan).
-- Tulis profil tetap hanya users.manage.

drop policy if exists "gm_profiles_select" on public.gm_profiles;
create policy "gm_profiles_select"
  on public.gm_profiles for select
  using (public.gm_is_active_user());
