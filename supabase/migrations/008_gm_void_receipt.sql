-- Owner boleh hapus baris rekap barang datang; stok lokasi masuk dikurangi.
-- Jalankan setelah 007.

create or replace function public.gm_void_stock_receipt_line(p_line_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_doc_id uuid;
  v_item_id uuid;
  v_qty numeric;
  v_to uuid;
  v_type text;
begin
  if not public.gm_is_owner() then
    raise exception 'Hanya owner yang boleh hapus barang datang';
  end if;

  select
    l.doc_id, l.item_id, l.qty, d.doc_type, d.to_location_id
  into v_doc_id, v_item_id, v_qty, v_type, v_to
  from public.gm_stock_doc_lines l
  join public.gm_stock_docs d on d.id = l.doc_id
  where l.id = p_line_id;

  if not found then
    raise exception 'Barang datang tidak ditemukan';
  end if;
  if v_type is distinct from 'receipt' then
    raise exception 'Hanya barang datang yang bisa dihapus di sini';
  end if;
  if v_to is null then
    raise exception 'Lokasi masuk tidak lengkap';
  end if;

  perform public.gm_apply_stock_delta(v_item_id, v_to, -v_qty);

  delete from public.gm_stock_doc_lines where id = p_line_id;
  if not exists (
    select 1 from public.gm_stock_doc_lines where doc_id = v_doc_id
  ) then
    delete from public.gm_stock_docs where id = v_doc_id;
  end if;
end;
$$;

revoke all on function public.gm_void_stock_receipt_line(uuid) from public;
grant execute on function public.gm_void_stock_receipt_line(uuid) to authenticated;

notify pgrst, 'reload schema';
