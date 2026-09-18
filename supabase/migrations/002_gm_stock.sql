-- Stok sederhana: banyak gudang & dapur (tempat produksi).
-- Seed awal: 2 gudang + 2 dapur. Prefix gm_ saja.

insert into public.gm_permissions (code, name, description) values
  ('stock.view', 'Lihat stok', 'Lihat saldo per gudang dan dapur'),
  ('stock.receipt', 'Barang datang', 'Input barang masuk'),
  ('stock.transfer', 'Pengambilan', 'Pindah stok dari gudang ke dapur'),
  ('master.manage', 'Master data', 'Barang dan lokasi (gudang / dapur)')
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
  'stock.view', 'stock.receipt', 'stock.transfer', 'master.manage'
)
where r.code = 'staff'
on conflict do nothing;

-- ─── locations ───────────────────────────────────────────────────────────────

create table if not exists public.gm_locations (
  id         uuid primary key default gen_random_uuid(),
  code       text not null unique,
  name       text not null,
  kind       text not null check (kind in ('warehouse', 'kitchen')),
  sort_order integer not null default 0,
  is_active  boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint gm_locations_name_not_empty check (trim(name) <> ''),
  constraint gm_locations_code_not_empty check (trim(code) <> '')
);

drop trigger if exists trg_gm_locations_updated_at on public.gm_locations;
create trigger trg_gm_locations_updated_at
  before update on public.gm_locations
  for each row execute function public.set_updated_at();

insert into public.gm_locations (code, name, kind, sort_order) values
  ('GUDANG-1', 'Gudang 1', 'warehouse', 1),
  ('GUDANG-2', 'Gudang 2', 'warehouse', 2),
  ('DAPUR-1', 'Dapur 1', 'kitchen', 3),
  ('DAPUR-2', 'Dapur 2', 'kitchen', 4)
on conflict (code) do nothing;

-- ─── items ───────────────────────────────────────────────────────────────────

create table if not exists public.gm_items (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  unit       text not null default 'pcs',
  is_active  boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint gm_items_name_not_empty check (trim(name) <> ''),
  constraint gm_items_unit_not_empty check (trim(unit) <> '')
);

create unique index if not exists idx_gm_items_name_lower
  on public.gm_items (lower(name));

drop trigger if exists trg_gm_items_updated_at on public.gm_items;
create trigger trg_gm_items_updated_at
  before update on public.gm_items
  for each row execute function public.set_updated_at();

-- ─── balances & documents ────────────────────────────────────────────────────

create table if not exists public.gm_stock_balances (
  item_id     uuid not null references public.gm_items(id) on delete restrict,
  location_id uuid not null references public.gm_locations(id) on delete restrict,
  qty         numeric(18, 4) not null default 0,
  updated_at  timestamptz not null default now(),
  primary key (item_id, location_id)
);

drop trigger if exists trg_gm_stock_balances_updated_at on public.gm_stock_balances;
create trigger trg_gm_stock_balances_updated_at
  before update on public.gm_stock_balances
  for each row execute function public.set_updated_at();

create table if not exists public.gm_stock_docs (
  id                 uuid primary key default gen_random_uuid(),
  doc_type           text not null check (doc_type in ('receipt', 'transfer')),
  doc_date           date not null default (timezone('Asia/Jakarta', now()))::date,
  from_location_id   uuid references public.gm_locations(id),
  to_location_id     uuid references public.gm_locations(id),
  note               text not null default '',
  created_by         uuid references public.gm_profiles(id) on delete set null,
  created_at         timestamptz not null default now()
);

create index if not exists idx_gm_stock_docs_type_date
  on public.gm_stock_docs (doc_type, doc_date desc, created_at desc);

create table if not exists public.gm_stock_doc_lines (
  id      uuid primary key default gen_random_uuid(),
  doc_id  uuid not null references public.gm_stock_docs(id) on delete cascade,
  item_id uuid not null references public.gm_items(id),
  qty     numeric(18, 4) not null check (qty > 0)
);

create index if not exists idx_gm_stock_doc_lines_doc
  on public.gm_stock_doc_lines (doc_id);

-- ─── posting ─────────────────────────────────────────────────────────────────

create or replace function public.gm_apply_stock_delta(
  p_item_id uuid,
  p_location_id uuid,
  p_qty_delta numeric
)
returns void
language plpgsql
as $$
declare
  v_qty numeric := 0;
  v_new numeric;
  v_name text;
begin
  if p_qty_delta = 0 then
    return;
  end if;

  select qty into v_qty
  from public.gm_stock_balances
  where item_id = p_item_id and location_id = p_location_id
  for update;

  if not found then
    insert into public.gm_stock_balances (item_id, location_id, qty)
    values (p_item_id, p_location_id, 0);
    v_qty := 0;
  end if;

  v_new := v_qty + p_qty_delta;
  if v_new < 0 then
    select name into v_name from public.gm_locations where id = p_location_id;
    raise exception 'Stok % tidak mencukupi', coalesce(v_name, 'lokasi');
  end if;

  update public.gm_stock_balances
  set qty = v_new
  where item_id = p_item_id and location_id = p_location_id;
end;
$$;

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

revoke all on function public.gm_post_stock_doc(text, date, uuid, uuid, text, jsonb) from public;
grant execute on function public.gm_post_stock_doc(text, date, uuid, uuid, text, jsonb) to authenticated;

-- ─── RLS ─────────────────────────────────────────────────────────────────────

alter table public.gm_locations enable row level security;
alter table public.gm_items enable row level security;
alter table public.gm_stock_balances enable row level security;
alter table public.gm_stock_docs enable row level security;
alter table public.gm_stock_doc_lines enable row level security;

drop policy if exists "gm_locations_select" on public.gm_locations;
create policy "gm_locations_select"
  on public.gm_locations for select
  using (public.gm_is_active_user());

drop policy if exists "gm_locations_write" on public.gm_locations;
create policy "gm_locations_write"
  on public.gm_locations for all
  using (public.gm_has_permission('master.manage'))
  with check (public.gm_has_permission('master.manage'));

drop policy if exists "gm_items_select" on public.gm_items;
create policy "gm_items_select"
  on public.gm_items for select
  using (public.gm_is_active_user());

drop policy if exists "gm_items_write" on public.gm_items;
create policy "gm_items_write"
  on public.gm_items for all
  using (public.gm_has_permission('master.manage'))
  with check (public.gm_has_permission('master.manage'));

drop policy if exists "gm_stock_balances_select" on public.gm_stock_balances;
create policy "gm_stock_balances_select"
  on public.gm_stock_balances for select
  using (public.gm_has_permission('stock.view'));

drop policy if exists "gm_stock_docs_select" on public.gm_stock_docs;
create policy "gm_stock_docs_select"
  on public.gm_stock_docs for select
  using (public.gm_has_permission('stock.view'));

drop policy if exists "gm_stock_doc_lines_select" on public.gm_stock_doc_lines;
create policy "gm_stock_doc_lines_select"
  on public.gm_stock_doc_lines for select
  using (public.gm_has_permission('stock.view'));

grant select, insert, update, delete on public.gm_locations to authenticated;
grant select, insert, update, delete on public.gm_items to authenticated;
grant select on public.gm_stock_balances to authenticated;
grant select on public.gm_stock_docs to authenticated;
grant select on public.gm_stock_doc_lines to authenticated;

notify pgrst, 'reload schema';
