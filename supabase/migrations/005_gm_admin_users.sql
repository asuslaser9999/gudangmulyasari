-- Tambah/ubah user Gudang tanpa Edge Function.
-- Jalankan di SQL Editor setelah 004_gm_roles_access.sql.

create or replace function public.gm_admin_create_user(
  p_display_name text,
  p_username text,
  p_password text,
  p_role_id uuid,
  p_location_ids uuid[] default '{}'
)
returns uuid
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
  v_username text;
  v_email text;
  v_user_id uuid := gen_random_uuid();
  v_instance_id uuid;
  v_role_code text;
  v_location_id uuid;
begin
  if not public.gm_has_permission('users.manage') then
    raise exception 'Tidak punya hak kelola user';
  end if;

  v_username := lower(trim(coalesce(p_username, '')));
  if v_username !~ '^[a-z0-9_]{3,32}$' then
    raise exception 'Username 3–32 karakter: huruf kecil, angka, underscore';
  end if;
  if trim(coalesce(p_display_name, '')) = '' then
    raise exception 'Nama wajib diisi';
  end if;
  if p_password is null or length(p_password) < 6 then
    raise exception 'Password minimal 6 karakter';
  end if;
  if p_role_id is null then
    raise exception 'Role wajib dipilih';
  end if;

  select code into v_role_code from public.gm_roles where id = p_role_id;
  if v_role_code is null then
    raise exception 'Role tidak ditemukan';
  end if;

  if exists (
    select 1 from public.gm_profiles where lower(username) = v_username
  ) then
    raise exception 'Username sudah digunakan di Gudang Mulyasari';
  end if;

  v_email := v_username || '@gudangmulyasari.pos';
  if exists (select 1 from auth.users where lower(email) = v_email) then
    raise exception 'Username sudah digunakan';
  end if;

  select instance_id into v_instance_id
  from auth.users
  where instance_id is not null
  limit 1;
  v_instance_id := coalesce(
    v_instance_id,
    '00000000-0000-0000-0000-000000000000'::uuid
  );

  insert into auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    confirmation_token,
    email_change,
    email_change_token_new,
    recovery_token
  ) values (
    v_instance_id,
    v_user_id,
    'authenticated',
    'authenticated',
    v_email,
    crypt(p_password, gen_salt('bf', 10)),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    jsonb_build_object(
      'gm_username', v_username,
      'gm_role_id', p_role_id,
      'gm_role_code', v_role_code,
      'display_name', trim(p_display_name),
      'username', 'gm_' || v_username
    ),
    now(),
    now(),
    '',
    '',
    '',
    ''
  );

  insert into auth.identities (
    id,
    user_id,
    identity_data,
    provider,
    provider_id,
    last_sign_in_at,
    created_at,
    updated_at
  ) values (
    v_user_id,
    v_user_id,
    jsonb_build_object('sub', v_user_id::text, 'email', v_email),
    'email',
    v_user_id::text,
    now(),
    now(),
    now()
  );

  insert into public.gm_profiles (
    id, email, display_name, username, role_id, is_active
  ) values (
    v_user_id,
    v_email,
    trim(p_display_name),
    v_username,
    p_role_id,
    true
  )
  on conflict (id) do update
  set
    email = excluded.email,
    display_name = excluded.display_name,
    username = excluded.username,
    role_id = excluded.role_id,
    is_active = true;

  if p_location_ids is not null then
    foreach v_location_id in array p_location_ids
    loop
      insert into public.gm_user_location_access (user_id, location_id)
      values (v_user_id, v_location_id)
      on conflict do nothing;
    end loop;
  end if;

  return v_user_id;
end;
$$;

create or replace function public.gm_admin_update_user(
  p_user_id uuid,
  p_display_name text default null,
  p_role_id uuid default null,
  p_is_active boolean default null,
  p_password text default null,
  p_location_ids uuid[] default null
)
returns void
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
  v_location_id uuid;
begin
  if not public.gm_has_permission('users.manage') then
    raise exception 'Tidak punya hak kelola user';
  end if;
  if p_user_id is null then
    raise exception 'User tidak ditemukan';
  end if;
  if not exists (select 1 from public.gm_profiles where id = p_user_id) then
    raise exception 'User tidak ditemukan';
  end if;
  if p_is_active = false and p_user_id = auth.uid() then
    raise exception 'Tidak bisa menonaktifkan akun sendiri';
  end if;
  if p_password is not null and length(trim(p_password)) > 0 and length(p_password) < 6 then
    raise exception 'Password minimal 6 karakter';
  end if;

  update public.gm_profiles
  set
    display_name = coalesce(nullif(trim(p_display_name), ''), display_name),
    role_id = coalesce(p_role_id, role_id),
    is_active = coalesce(p_is_active, is_active)
  where id = p_user_id;

  if p_password is not null and length(trim(p_password)) > 0 then
    update auth.users
    set
      encrypted_password = crypt(p_password, gen_salt('bf', 10)),
      updated_at = now()
    where id = p_user_id;
  end if;

  if p_location_ids is not null then
    delete from public.gm_user_location_access where user_id = p_user_id;
    foreach v_location_id in array p_location_ids
    loop
      insert into public.gm_user_location_access (user_id, location_id)
      values (p_user_id, v_location_id)
      on conflict do nothing;
    end loop;
  end if;
end;
$$;

revoke all on function public.gm_admin_create_user(text, text, text, uuid, uuid[]) from public;
revoke all on function public.gm_admin_update_user(uuid, text, uuid, boolean, text, uuid[]) from public;
grant execute on function public.gm_admin_create_user(text, text, text, uuid, uuid[]) to authenticated;
grant execute on function public.gm_admin_update_user(uuid, text, uuid, boolean, text, uuid[]) to authenticated;

notify pgrst, 'reload schema';
