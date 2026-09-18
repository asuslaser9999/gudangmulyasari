# Gudang Mulyasari

Aplikasi gudang. Login dan template mengikuti Mulyasari POS.

Memakai **project Supabase yang sama** dengan Mulyasari POS. Semua tabel/RPC berprefix `gm_` dan tidak menulis tabel POS (`profiles`, `products`, ...), Cinnamon (`cn_*`), atau Inpin (`ip_*`).

## Setup

1. Salin `.env` dari Mulyasari POS ke folder ini (URL + anon key yang sama), atau salin `.env.example` menjadi `.env`.
2. Di Supabase SQL Editor, jalankan berurutan:
   - `supabase/migrations/001_gm_core.sql`
   - `supabase/migrations/002_gm_stock.sql`
   - `supabase/migrations/003_gm_item_sort.sql`
   - `supabase/migrations/004_gm_roles_access.sql`
   - `supabase/migrations/005_gm_admin_users.sql`
   - `supabase/migrations/006_gm_profile_select.sql`
   - `supabase/migrations/007_gm_receipt_item_access.sql`
   - `supabase/migrations/008_gm_void_receipt.sql`
   - `supabase/migrations/009_gm_app_settings.sql`
3. `flutter pub get` lalu `flutter run`

## Release (APK + EXE)

Hasil akhir ada di folder `dist/`, sama seperti Mulyasari POS:

- `dist/InventoriGudang-v1.0.0.apk`
- `dist/InventoriGudang-Windows-x64/` (salin seluruh folder, bukan hanya `.exe`)

```powershell
powershell -File scripts/package_release.ps1
```

User Gudang Mulyasari **terpisah** dari kasir POS dan staf app lain (domain `@gudangmulyasari.pos`). Owner POS di-bootstrap sebagai owner di sini.
