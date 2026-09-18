-- Pengambilan: staf boleh pilih gudang asal mana pun (wajib dipilih).
-- Hak lokasi hanya membatasi dapur tujuan. Jalankan setelah 009.

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
      raise exception 'Pilih gudang asal';
    end if;
    if v_to is null then
      raise exception 'Pilih dapur tujuan';
    end if;
    if v_from = v_to then
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
    if not public.gm_can_see_location(v_to) then
      raise exception 'Tidak diizinkan pengambilan ke dapur ini';
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

notify pgrst, 'reload schema';
