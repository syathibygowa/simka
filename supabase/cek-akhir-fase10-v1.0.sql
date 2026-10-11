-- SIMKA PRO | supabase/cek-akhir-fase10-v1.0.sql | v1.0 | Penutupan Fase 10 – Persuratan | 11/10/2026
-- Pemeriksaan akhir Fase 10 (hanya membaca, aman dijalankan kapan saja).
-- Hasil yang benar: baris 1–10 "Sesuai"; baris 11–14 keterangan kesiapan data (bukan galat).
select 1 as no, 'Migrasi 6700–6900 terpasang (tabel persuratan)' as pemeriksaan,
       case when to_regclass('public.incoming_letters') is not null and to_regclass('public.letter_dispositions') is not null
             and to_regclass('public.letter_templates') is not null and to_regclass('public.outgoing_letters') is not null then 'Sesuai' else 'Periksa' end as hasil
union all select 2, 'Fungsi pokok persuratan (12)',
       case when (select count(distinct proname) from pg_proc where pronamespace = 'public'::regnamespace and proname in (
         'catat_surat_masuk','beri_disposisi','selesaikan_disposisi','daftar_surat_masuk','buku_agenda_masuk','simpan_surat_keluar','kirim_surat_ke_tu',
         'ajukan_surat_keluar','batalkan_surat_keluar','revisi_surat_keluar','buku_agenda_keluar','ringkasan_persuratan')) = 12 then 'Sesuai' else 'Periksa' end
union all select 3, 'Semua tabel persuratan tertutup untuk tulis langsung (RLS)',
       case when (select bool_and(relrowsecurity) from pg_class where relnamespace = 'public'::regnamespace
                   and relname in ('incoming_letters','letter_dispositions','letter_templates','outgoing_letters'))
             and (select count(*) from pg_policies where schemaname = 'public' and cmd <> 'SELECT'
                   and tablename in ('incoming_letters','letter_dispositions','letter_templates','outgoing_letters')) = 0 then 'Sesuai' else 'Periksa' end
union all select 4, 'Hanya Tata Usaha yang mengajukan tanda tangan dan merevisi surat',
       case when (select bool_and(prosrc like '%boleh_kelola_persuratan%') from pg_proc where pronamespace = 'public'::regnamespace
                   and proname in ('ajukan_surat_keluar','revisi_surat_keluar')) then 'Sesuai' else 'Periksa' end
union all select 5, 'Nomor surat terbit saat sah; revisi sah menandai surat lama "Direvisi"',
       case when exists (select 1 from pg_trigger where tgname = 'ab_surat_keluar' and not tgisinternal)
             and (select prosrc from pg_proc where pronamespace = 'public'::regnamespace and proname = 'tg_registri_surat_keluar') like '%revisi_dari%' then 'Sesuai' else 'Periksa' end
union all select 6, 'Buku agenda surat keluar menginventaris surat dari modul lain',
       case when (select prosrc from pg_proc where pronamespace = 'public'::regnamespace and proname = 'buku_agenda_keluar') like '%student_mutations%' then 'Sesuai' else 'Periksa' end
union all select 7, 'Format nomor agenda masuk, surat, dan SK aktif',
       case when (select count(*) from doc_number_formats where kode in ('agenda_masuk','surat','sk') and aktif) = 3 then 'Sesuai' else 'Periksa' end
union all select 8, 'Pengingat batas disposisi terjadwal (07.00 WITA)',
       case when exists (select 1 from cron.job where jobname = 'pengingat-disposisi') then 'Sesuai' else 'Periksa' end
union all select 9, 'Hak lihat pindaian surat masuk dan arsip surat keluar',
       case when (select prosrc from pg_proc where pronamespace = 'public'::regnamespace and proname = 'boleh_lihat_berkas') like '%incoming_letters%'
             and (select prosrc from pg_proc where pronamespace = 'public'::regnamespace and proname = 'boleh_lihat_berkas') like '%outgoing_letters%' then 'Sesuai' else 'Periksa' end
union all select 10, 'Realtime persuratan aktif',
       case when not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then 'Sesuai (Realtime tidak dipakai)'
            when (select count(*) from pg_publication_tables where pubname = 'supabase_realtime'
                   and tablename in ('incoming_letters','letter_dispositions','outgoing_letters')) = 3 then 'Sesuai' else 'Periksa' end
union all select 11, 'Template surat aktif', (select count(*) filter (where aktif)::text || ' template (' || count(*) filter (where bawaan)::text || ' bawaan)' from letter_templates)
union all select 12, 'Pengelola persuratan (jabatan Tata Usaha / izin admin)', (select count(*)::text || ' pegawai' from public._pengelola_surat())
union all select 13, 'Penanda tangan terhubung akun (syarat TTD elektronik)',
       (select count(*) filter (where employee_id is not null)::text || ' dari ' || count(*)::text || ' penanda tangan aktif' from signatories where aktif)
union all select 14, 'Surat tahun ini', (select count(*)::text || ' surat masuk' from incoming_letters where tanggal_terima >= date_trunc('year', public.hari_ini()))
       || ' · ' || (select count(*)::text || ' surat keluar terbit' from outgoing_letters where status in ('terbit','direvisi') and tanggal_surat >= date_trunc('year', public.hari_ini()))
order by no;
