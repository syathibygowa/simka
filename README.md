# SIMKA PRO

Sistem Manajemen Kepegawaian Terintegrasi — Pondok Pesantren Tahfizhul Qur'an Imam Asy-Syathiby Wahdah Islamiyah Gowa.

Acuan: Blueprint SIMKA PRO Versi 2.0 (final) dan Dokumen Serah Terima.

## Struktur

| Folder | Isi |
|---|---|
| `src/` | Aplikasi Vite + Vue 3 + Tailwind (PWA, hash router) |
| `src/styles/` | `token.css` (warna dan tema), `cetak.css` (standar cetak F4) |
| `src/lib/` | Supabase, tanggal/jam WITA, menu, adapter penyimpanan, Excel, WA, data demo |
| `src/stores/` | Sesi, tema, notifikasi, statistik langsung, data pegawai |
| `src/components/cetak/` | Kerangka dokumen F4 (kop, judul, tabel, tanda tangan) |
| `supabase/migrations/` | Skema, fungsi, RLS, isi awal, storage, pg_cron |
| `supabase/functions/` | Edge Functions: masuk, daftar, reset-sandi, kelola-akun, salin-logo |
| `gas/` | Google Apps Script: pemindah berkas ke Drive, email, heartbeat, backup, retensi |

## Menjalankan

```bash
npm install
npm run dev          # tanpa .env.local → mode demo (data contoh)
npm run build        # hasil di dist/ untuk GitHub Pages
npm run build:demo   # satu berkas HTML mandiri untuk pratinjau tampilan
```

Salin `.env.example` menjadi `.env.local` dan isi alamat serta anon key Supabase untuk tersambung ke server.

## Standar antarmuka

- Ikon Phosphor duotone; setiap menu/tab berwarna sendiri (kelas `.w-*` di `token.css`).
- Desktop: sidebar kiri dan bilah atas. Mobile: bilah aplikasi, navigasi bawah, kartu, FAB, bottom sheet.
- Tema Terang/Gelap/Ikuti sistem; seluruh warna teks memenuhi kontras WCAG AA.
- Tanggal `dd/mm/yyyy` atau `dd mmmm yyyy`, bawaan hari ini; jam bawaan mengikuti jam saat ini (WITA).
- Cetak: F4 215 × 330 mm, margin 2 cm, kop surat, garis tabel ½ pt, tebal hanya judul dan kepala tabel, tanda tangan pimpinan (kiri) dan pegawai (kanan) sejajar.

## Rahasia

Anon key boleh publik. `service_role` key dan rahasia GAS **tidak pernah** masuk repo: simpan di Supabase Secrets dan Script Properties GAS.
