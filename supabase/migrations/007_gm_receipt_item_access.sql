-- Barang datang: staf hanya boleh input barang yang diizinkan.
-- Rekap memakai created_by yang sudah ada. Jalankan setelah 006.

create table if not exists public.gm_user_item_access (
  user_id uuid not null references public.gm_profiles(id) on delete cascade,
  item_id uuid not null references public.gm_items(id) on delete cascade,
  primary key (user_id, item_id)
);

insert into public.gm_user_item_access (user_id, item_id)
select p.id, i.id
from public.gm_profiles p
cross join public.gm_items i
on conflict do nothing;

create or replace function public.gm_can_receipt_item(p_item_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.gm_is_owner()
    or (
      public.gm_is_active_user()
      and exists (
        select 1
        from public.gm_user_item_access a
        where a.user_id = auth.uid()
          and a.item_id = p_item_id
      )
    );
$$;

grant execute on function public.gm_can_receipt_item(uuid) to authenticated;

alter table public.gm_user_item_access enable row level security;

drop policy if exists "gm_user_item_access_select" on public.gm_user_item_access;
create policy "gm_user_item_access_select"
  on public.gm_user_item_access for select
  using (user_id = auth.uid() or public.gm_has_permission('users.manage'));

drop policy if exists "gm_user_item_access_write" on public.gm_user_item_access;
create policy "gm_user_item_access_write"
  on public.gm_user_item_access for all
  using (public.gm_has_permission('users.manage'))
  with check (public.gm_has_permission('users.manage'));

grant select, insert, update, delete on public.gm_user_item_access to authenticated;

-- ─── posting: cek barang datang ──────────────────────────────────────────────

create or replace function public.gm_post_stock_doc(
  p_doc_type text,
  p_doc_date date,
  p_from_location_id uuid,
  p_to_location_id uuid,
  p_note text,
  p_lines jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_doc_id uuid;
  v_line jsonb;
  v_item_id uuid;
  v_qty numeric;
  v_from uuid;
  v_to uuid;
  v_from_kind text;
  v_to_kind text;
begin
  if not public.gm_is_active_user() then
    raise exception 'Tidak diizinkan';
  end if;

  if p_doc_type not in ('receipt', 'transfer') then
    raise exception 'Jenis dokumen tidak valid';
  end if;

  if p_doc_type = 'receipt' and not public.gm_has_permission('stock.receipt') then
    raise exception 'Tidak diizinkan input barang datang';
  end if;
  if p_doc_type = 'transfer' and not public.gm_has_permission('stock.transfer') then
    raise exception 'Tidak diizinkan pengambilan barang';
  end if;

  if p_lines is null or jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then
    raise exception 'Tambah minimal 1 barang';
  end if;

  if p_doc_type = 'receipt' then
    v_to := p_to_location_id;
    if v_to is null then
      select id into v_to
      from public.gm_locations
      where is_active = true and kind = 'warehouse'
      order by sort_order, name
      limit 1;
    end if;
    if v_to is null then
      raise exception 'Lokasi tujuan wajib diisi';
    end if;
    if not exists (
      select 1 from public.gm_locations
      where id = v_to and is_active = true
    ) then
      raise exception 'Lokasi tujuan tidak aktif';
    end if;
    if not public.gm_can_see_location(v_to) then
      raise exception 'Tidak diizinkan input stok di lokasi ini';
    end if;
    v_from := null;
  else
    v_from := p_from_location_id;
    v_to := p_to_location_id;
    if v_from is null then
      select id into v_from
      from public.gm_locations
      where is_active = true and kind = 'warehouse'
      order by sort_order, name
      limit 1;
    end if;
    if v_to is null then
      select id into v_to
      from public.gm_locations
      where is_active = true and kind = 'kitchen'
      order by sort_order, name
      limit 1;
    end if;
    if v_from is null or v_to is null or v_from = v_to then
      raise exception 'Pengambilan harus dari gudang ke dapur';
    end if;

    select kind into v_from_kind
    from public.gm_locations
    where id = v_from and is_active = true;
    select kind into v_to_kind
    from public.gm_locations
    where id = v_to and is_active = true;

    if v_from_kind is distinct from 'warehouse'
       or v_to_kind is distinct from 'kitchen' then
      raise exception 'Pengambilan harus dari gudang ke dapur (tempat produksi)';
    end if;
    if not public.gm_can_see_location(v_from)
       or not public.gm_can_see_location(v_to) then
      raise exception 'Tidak diizinkan pengambilan di lokasi ini';
    end if;
  end if;

  insert into public.gm_stock_docs (
    doc_type, doc_date, from_location_id, to_location_id, note, created_by
  )
  values (
    p_doc_type,
    coalesce(p_doc_date, (timezone('Asia/Jakarta', now()))::date),
    v_from,
    v_to,
    coalesce(p_note, ''),
    auth.uid()
  )
  returning id into v_doc_id;

  for v_line in select value from jsonb_array_elements(p_lines)
  loop
    v_item_id := (v_line->>'item_id')::uuid;
    v_qty := (v_line->>'qty')::numeric;
    if v_item_id is null or v_qty is null or v_qty <= 0 then
      raise exception 'Baris barang tidak valid';
    end if;
    if not exists (
      select 1 from public.gm_items where id = v_item_id and is_active = true
    ) then
      raise exception 'Barang tidak aktif atau tidak ditemukan';
    end if;
    if p_doc_type = 'receipt' and not public.gm_can_receipt_item(v_item_id) then
      raise exception 'Tidak diizinkan input barang datang untuk barang ini';
    end if;

    insert into public.gm_stock_doc_lines (doc_id, item_id, qty)
    values (v_doc_id, v_item_id, v_qty);

    if p_doc_type = 'receipt' then
      perform public.gm_apply_stock_delta(v_item_id, v_to, v_qty);
    else
      perform public.gm_apply_stock_delta(v_item_id, v_from, -v_qty);
      perform public.gm_apply_stock_delta(v_item_id, v_to, v_qty);
    end if;
  end loop;

  return v_doc_id;
end;
$$;

-- ─── kelola user: simpan barang datang yang diizinkan ────────────────────────

drop function if exists public.gm_admin_create_user(text, text, text, uuid, uuid[]);
drop function if exists public.gm_admin_update_user(uuid, text, uuid, boolean, text, uuid[]);

create or replace function public.gm_admin_create_user(
  p_display_name text,
  p_username text,
  p_password text,
  p_role_id uuid,
  p_location_ids uuid[] default '{}',
  p_item_ids uuid[] default '{}'
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
  v_item_id uuid;
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

  if p_item_ids is not null then
    foreach v_item_id in array p_item_ids
    loop
      insert into public.gm_user_item_access (user_id, item_id)
      values (v_user_id, v_item_id)
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
  p_location_ids uuid[] default null,
  p_item_ids uuid[] default null
)
returns void
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
  v_location_id uuid;
  v_item_id uuid;
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

  if p_item_ids is not null then
    delete from public.gm_user_item_access where user_id = p_user_id;
    foreach v_item_id in array p_item_ids
    loop
      insert into public.gm_user_item_access (user_id, item_id)
      values (p_user_id, v_item_id)
      on conflict do nothing;
    end loop;
  end if;
end;
$$;

revoke all on function public.gm_admin_create_user(text, text, text, uuid, uuid[], uuid[]) from public;
revoke all on function public.gm_admin_update_user(uuid, text, uuid, boolean, text, uuid[], uuid[]) from public;
grant execute on function public.gm_admin_create_user(text, text, text, uuid, uuid[], uuid[]) to authenticated;
grant execute on function public.gm_admin_update_user(uuid, text, uuid, boolean, text, uuid[], uuid[]) to authenticated;

notify pgrst, 'reload schema';
