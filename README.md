<!-- SIMKA PRO | README.md | v2.2 | 14.13.0: domain simka.digital, kapasitas dan backup ringkas, saringan corong | 19/10/2026 -->
# SIMKA PRO

**Sistem Manajemen Kepegawaian Terintegrasi** — Pondok Pesantren Tahfizhul Qur'an Imam Asy-Syathiby Wahdah Islamiyah Gowa.

Aplikasi web multidevice (desktop, tablet, HP; dapat dipasang sebagai aplikasi/PWA) untuk kepegawaian, kesantrian, tahfizh, akademik, persuratan, dan keuangan pondok. Acuan: *Blueprint SIMKA PRO Versi 2.0 (final)* dan *Dokumen Serah Terima* terbaru.

- **Alamat aplikasi:** https://simka.digital (alamat lama `syathibygowa.github.io/simka` dialihkan otomatis)
- **Cek keabsahan dokumen:** `#/cek/KODE` (QR pada setiap dokumen resmi)
- **Layar Pantauan:** `#/pantauan`
- **Versi:** lihat `src/lib/versi.js` (juga tampil di halaman Profil)

## Cakupan fitur

| Kelompok | Fitur utama |
|---|---|
| **Presensi pegawai** | GPS beberapa titik + selfie wajib, dihitung server; pola sesi per tugas, shift, toleransi; verval presensi luar area; penutupan otomatis harian; rekap dan laporan kehadiran |
| **Layanan pegawai** | Pengajuan izin/sakit/cuti/dinas luar berjenjang dengan surat bertanda tangan elektronik; jurnal harian; jurnal mengajar (termasuk guru pengganti); berkas pegawai; kartu pegawai ber-QR; agenda dan pengumuman |
| **Kepegawaian** | Data pegawai, jabatan struktural/fungsional, Plt; riwayat kepegawaian; beban kerja dan ekuivalensi jam; Surat Teguran SP1–SP3; **Rekam Kepegawaian** |
| **Kesantrian** | Data santri, mutasi dan status; kelompok (kelas, kamar, halaqah, ekskul); absensi HISBAT; perizinan berjenjang dan libur bertingkat; security (gerbang, tamu, kunjungan, titipan); klinik; Kedisiplinan Santri (pelanggaran, SP santri); prestasi; **Rekam Kesantrian**; Layar Pantauan |
| **Tahfizh** | Setoran sabaq/sabqi/manzil; **Tahsin** bagi santri yang belum menghafal (tahapan bacaan, catatan pertemuan, pengesahan lulus); capaian bulanan dan validasi juz; ujian kenaikan juz dan sertifikasi berjenjang dengan konfirmasi WhatsApp; **Khataman 30 juz** (undangan dan sertifikat penghargaan bertanda tangan elektronik); UTAS; dokumen tahfizh (suket, sertifikat) |
| **Akademik** | Jadwal pelajaran dan jam mengajar; penilaian Kurikulum Merdeka (SMA) dan K13 disesuaikan (Wustha); rapor sekolah dan rapor tahfizh; leger; naik kelas dan SK; kartu pelajar |
| **Administrasi** | Persuratan (surat masuk, disposisi, surat keluar dari template, tanda tangan elektronik); gaji dan tunjangan (fitur sensitif); keuangan santri dan kas pondok (tagihan, subsidi, pembayaran, rekening, BKK/BKM, bebas tunggakan) |
| **Portal Wali** | Masuk dengan NIS/NISN + tanggal lahir + nomor HP; kehadiran, hafalan, nilai, perizinan, keuangan (dapat diatur superadmin); unduh dokumen; notifikasi HP |
| **Sistem** | Hak akses per menu (Tidak ada/Lihat/Input-ubah/Kelola) berlapis semua pegawai → jabatan → bidang → individu; notifikasi dibaca/belum dibaca dan web push; template WhatsApp; audit log; setelan kop, logo, nomor surat, penanda tangan; **Kapasitas** (ukuran database, perkiraan, masa simpan data, perawatan harian) |

## Arsitektur

| Bagian | Teknologi |
|---|---|
| Tampilan | Vite 5 + Vue 3 (`<script setup>`) + Pinia + Tailwind CSS 3, PWA, hash router |
| Hosting | GitHub Pages dengan domain sendiri `simka.digital` (DNS di Hostinger), deploy otomatis lewat GitHub Actions (`.github/workflows/deploy.yml`) |
| Database | Supabase (PostgreSQL + Row Level Security, Auth untuk pegawai, Edge Functions, Realtime, pg_cron) |
| Berkas | Google Drive melalui jembatan Google Apps Script (`gas/Kode.gs`); antrian sementara di Supabase Storage |
| Backup | GAS: mingguan ke Google Sheets (18 lembar ringkas mudah dibaca + data mentah per tabel) dan bulanan ke ZIP berisi CSV (data kegiatan + data induk) |

## Struktur folder

| Folder | Isi |
|---|---|
| `src/pages/` | Halaman per menu (presensi, santri, tahfizh, penilaian, keuangan, persuratan, dst.) |
| `src/components/` | Komponen bersama (kartu statistik, bilah tab, lembar bawah, tombol/pratinjau WhatsApp, grafik SVG, cetak F4) |
| `src/lib/` | Supabase, tanggal WITA dan Hijriah, menu, hak akses, WhatsApp, Excel, data demo |
| `src/stores/` | Penyimpanan data per fitur (Pinia) |
| `src/styles/` | `token.css` (warna dan tema), `cetak.css` (standar cetak F4) |
| `supabase/migrations/` | Skema, fungsi, RLS, isi awal, pg_cron — dijalankan berurutan menurut nama berkas |
| `supabase/functions/` | Edge Functions: `masuk`, `daftar`, `reset-sandi`, `kelola-akun`, `presensi`, `berkas`, `dorong`, `salin-logo` |
| `supabase/cek-akhir-*.sql` | Kueri pemeriksaan akhir per fase |
| `gas/` | Google Apps Script: email, pemindah berkas ke Drive, heartbeat, retensi, backup mingguan dan bulanan |

## Menjalankan

```bash
npm install
npm run dev                                   # tanpa .env.local → mode demo (data contoh)
npm run build                                 # hasil di dist/ untuk GitHub Pages
npx vite build --mode demo --outDir dist-demo # satu berkas HTML mandiri untuk pratinjau tampilan
```

Salin `.env.example` menjadi `.env.local`, lalu isi alamat dan anon key Supabase untuk tersambung ke server.

## Pemasangan pembaruan

1. Jalankan migrasi SQL baru di Supabase → SQL Editor, berurutan. Setiap migrasi aman dijalankan ulang dan diakhiri kueri **PEMERIKSAAN** yang semua barisnya harus "Sesuai".
2. Unggah berkas yang berubah ke repo ini (cabang `main`); GitHub Actions membangun dan menerbitkan aplikasi.
3. Bila `gas/Kode.gs` berubah, tempel ke proyek Apps Script lalu jalankan fungsi yang disebut di catatan versinya.

## Standar antarmuka

- Bahasa Indonesia baku; tanggal `dd/mm/yyyy` atau `dd mmmm yyyy`; jam WITA; tanggal Hijriah Ummul Qura.
- Ikon Phosphor duotone; setiap menu dan tab berwarna sendiri (kelas `.w-*`); tema Terang/Gelap/Ikuti sistem dengan kontras WCAG AA.
- Desktop: sidebar dan bilah atas. HP: navigasi bawah, kartu, tombol aksi mengambang, lembar bawah; saringan halaman diringkas menjadi kolom cari + tombol corong.
- Label tombol singkat dan seragam: Pratinjau, Ekspor, Impor, Cetak Rekap, Atur, Salin, Bergilir.
- Hemat server: pembaruan langsung diredam (maks. sekali per 10 detik), muat ulang berkala hanya saat layar terlihat, jadwal otomatis digabung.
- Cetak F4 215 × 330 mm, margin 2 cm, kop surat, garis tabel ½ pt, tanda tangan pimpinan (kiri) dan pegawai terkait (kanan).
- Urutan kolom: pegawai NIY › Nama › JK; santri NIS/NISN › Nama › JK.

## Keamanan

Seluruh aturan akses ada di RLS dan fungsi SQL `security definer` yang memeriksa hak. Anon key boleh publik. **`service_role` key dan rahasia GAS tidak pernah masuk repo**: simpan di Supabase Secrets dan Script Properties GAS.
