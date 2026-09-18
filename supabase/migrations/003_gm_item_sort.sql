-- Urutan barang tersimpan (dipakai di Barang datang, stok, master).
-- Jangan edit 002; file ini aman dijalankan ulang.

alter table public.gm_items
  add column if not exists sort_order integer not null default 0;

update public.gm_items i
set sort_order = s.rn
from (
  select id, row_number() over (order by lower(name), id) as rn
  from public.gm_items
) s
where i.id = s.id
  and i.sort_order = 0;

notify pgrst, 'reload schema';
