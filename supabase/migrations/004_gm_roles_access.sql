-- Hak akses granular + lokasi stok per user + hapus pengambilan.
-- Prefix gm_ saja. Jalankan di SQL Editor setelah 001–003.

insert into public.gm_permissions (code, name, description) values
  ('items.manage', 'Tambah barang', 'Tambah dan ubah master barang'),
  ('locations.manage', 'Tambah gudang/dapur', 'Tambah gudang atau dapur baru'),
  ('stock.transfer_delete', 'Hapus pengambilan', 'Hapus riwayat pengambilan dan kembalikan stok')
on conflict (code) do nothing;

insert into public.gm_role_permissions (role_id, permission_id)
select r.id, p.id
from public.gm_roles r
cross join public.gm_permissions p
where r.code = 'owner'
on conflict do nothing;

insert into public.gm_role_permissions (role_id, permission_id)
select r.id, p.id
from public.gm_roles r
join public.gm_permissions p on p.code in (
  'stock.view',
  'stock.receipt',
  'stock.transfer',
  'stock.transfer_delete',
  'items.manage',
  'locations.manage',
  'master.manage'
)
where r.code = 'staff'
on conflict do nothing;

-- ─── lokasi stok yang boleh dilihat user ─────────────────────────────────────

create table if not exists public.gm_user_location_access (
  user_id     uuid not null references public.gm_profiles(id) on delete cascade,
  location_id uuid not null references public.gm_locations(id) on delete cascade,
  primary key (user_id, location_id)
);

-- User lama: semua lokasi, supaya tampilan tidak kosong setelah migrasi.
insert into public.gm_user_location_access (user_id, location_id)
select p.id, l.id
from public.gm_profiles p
cross join public.gm_locations l
on conflict do nothing;

create or replace function public.gm_can_see_location(p_location_id uuid)
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
        from public.gm_user_location_access a
        where a.user_id = auth.uid()
          and a.location_id = p_location_id
      )
    );
$$;

grant execute on function public.gm_can_see_location(uuid) to authenticated;

-- ─── posting: cek lokasi yang diizinkan ──────────────────────────────────────

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

-- ─── hapus pengambilan (kembalikan stok) ─────────────────────────────────────

create or replace function public.gm_void_stock_transfer_line(p_line_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_doc_id uuid;
  v_item_id uuid;
  v_qty numeric;
  v_from uuid;
  v_to uuid;
  v_type text;
begin
  if not public.gm_has_permission('stock.transfer_delete') then
    raise exception 'Tidak diizinkan hapus pengambilan';
  end if;

  select
    l.doc_id, l.item_id, l.qty, d.doc_type, d.from_location_id, d.to_location_id
  into v_doc_id, v_item_id, v_qty, v_type, v_from, v_to
  from public.gm_stock_doc_lines l
  join public.gm_stock_docs d on d.id = l.doc_id
  where l.id = p_line_id;

  if not found then
    raise exception 'Pengambilan tidak ditemukan';
  end if;
  if v_type is distinct from 'transfer' then
    raise exception 'Hanya pengambilan yang bisa dihapus';
  end if;
  if v_from is null or v_to is null then
    raise exception 'Lokasi pengambilan tidak lengkap';
  end if;
  if not public.gm_can_see_location(v_from)
     and not public.gm_can_see_location(v_to) then
    raise exception 'Tidak diizinkan hapus pengambilan di lokasi ini';
  end if;

  perform public.gm_apply_stock_delta(v_item_id, v_to, -v_qty);
  perform public.gm_apply_stock_delta(v_item_id, v_from, v_qty);

  delete from public.gm_stock_doc_lines where id = p_line_id;
  if not exists (
    select 1 from public.gm_stock_doc_lines where doc_id = v_doc_id
  ) then
    delete from public.gm_stock_docs where id = v_doc_id;
  end if;
end;
$$;

revoke all on function public.gm_void_stock_transfer_line(uuid) from public;
grant execute on function public.gm_void_stock_transfer_line(uuid) to authenticated;

-- ─── RLS ─────────────────────────────────────────────────────────────────────

alter table public.gm_user_location_access enable row level security;

drop policy if exists "gm_user_location_access_select" on public.gm_user_location_access;
create policy "gm_user_location_access_select"
  on public.gm_user_location_access for select
  using (user_id = auth.uid() or public.gm_has_permission('users.manage'));

drop policy if exists "gm_user_location_access_write" on public.gm_user_location_access;
create policy "gm_user_location_access_write"
  on public.gm_user_location_access for all
  using (public.gm_has_permission('users.manage'))
  with check (public.gm_has_permission('users.manage'));

drop policy if exists "gm_items_write" on public.gm_items;
create policy "gm_items_write"
  on public.gm_items for all
  using (
    public.gm_has_permission('items.manage')
    or public.gm_has_permission('master.manage')
  )
  with check (
    public.gm_has_permission('items.manage')
    or public.gm_has_permission('master.manage')
  );

drop policy if exists "gm_locations_write" on public.gm_locations;
create policy "gm_locations_write"
  on public.gm_locations for all
  using (
    public.gm_has_permission('locations.manage')
    or public.gm_has_permission('master.manage')
  )
  with check (
    public.gm_has_permission('locations.manage')
    or public.gm_has_permission('master.manage')
  );

drop policy if exists "gm_stock_balances_select" on public.gm_stock_balances;
create policy "gm_stock_balances_select"
  on public.gm_stock_balances for select
  using (
    public.gm_has_permission('stock.view')
    and public.gm_can_see_location(location_id)
  );

drop policy if exists "gm_stock_docs_select" on public.gm_stock_docs;
create policy "gm_stock_docs_select"
  on public.gm_stock_docs for select
  using (
    public.gm_has_permission('stock.view')
    and (
      (from_location_id is not null and public.gm_can_see_location(from_location_id))
      or (to_location_id is not null and public.gm_can_see_location(to_location_id))
    )
  );

drop policy if exists "gm_stock_doc_lines_select" on public.gm_stock_doc_lines;
create policy "gm_stock_doc_lines_select"
  on public.gm_stock_doc_lines for select
  using (
    exists (
      select 1
      from public.gm_stock_docs d
      where d.id = doc_id
        and public.gm_has_permission('stock.view')
        and (
          (d.from_location_id is not null and public.gm_can_see_location(d.from_location_id))
          or (d.to_location_id is not null and public.gm_can_see_location(d.to_location_id))
        )
    )
  );

grant select, insert, update, delete on public.gm_user_location_access to authenticated;

notify pgrst, 'reload schema';
