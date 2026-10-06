-- SIMKA PRO | supabase/cek-akhir-fase6-v1.0.sql | v1.0 | Penutupan Fase 6 – Klinik dan lapor | 06/10/2026
-- Pemeriksaan akhir Fase 6 (hanya membaca). Hasil yang benar: baris 1–12 "Sesuai"; baris 13–18 keterangan kesiapan data.
select 1 as no, 'Migrasi 4600–5100 terpasang' as pemeriksaan,
       case when (select count(distinct proname) from pg_proc where proname in ('buat_rujukan','absensi_asrama_rinci','ajukan_izin','simpan_jurnal_musyrif',
         'kirim_laporan','ringkasan_layanan_beranda')) = 6 then 'Sesuai' else 'Periksa' end as hasil
union all select 2, 'Tabel Fase 6 ber-RLS (14)',
       case when (select count(*) from pg_tables where schemaname = 'public' and rowsecurity and tablename in ('clinic_staff','clinic_cases','clinic_referrals',
         'clinic_visits','clinic_followups','clinic_letters','student_permits','student_permit_approvals','dorm_journals','report_categories',
         'incident_reports','incident_updates','wa_templates','institution_settings')) = 14 then 'Sesuai' else 'Periksa' end
union all select 3, 'Tabel Fase 6 tidak dapat ditulis langsung (hanya lewat fungsi)',
       case when not exists (select 1 from pg_policies where schemaname = 'public' and cmd in ('INSERT','UPDATE','DELETE','ALL') and tablename in ('clinic_staff',
         'clinic_cases','clinic_referrals','clinic_visits','clinic_followups','clinic_letters','student_permits','student_permit_approvals','dorm_journals',
         'report_categories','incident_reports','incident_updates')) then 'Sesuai' else 'Periksa' end
union all select 4, 'Catatan pemeriksaan klinik tidak masuk audit log (rahasia)',
       case when not exists (select 1 from pg_trigger where tgrelid = 'public.clinic_visits'::regclass and tgname = 'zz_audit') then 'Sesuai' else 'Periksa' end
union all select 5, 'Satu kasus klinik terbuka per santri', case when exists (select 1 from pg_indexes where indexname = 'clinic_cases_satu_terbuka') then 'Sesuai' else 'Periksa' end
union all select 6, 'Status otomatis Sakit/Izin dan rujukan dari absensi',
       case when position('status_otomatis_sesi' in pg_get_functiondef('public.simpan_absensi_santri'::regproc)) > 0
             and position('_rujukan_internal' in pg_get_functiondef('public.simpan_absensi_santri'::regproc)) > 0 then 'Sesuai' else 'Periksa' end
union all select 7, 'Klinik dipulangkan → usulan izin; waktu mulai sakit',
       case when (select count(*) from pg_trigger where tgrelid = 'public.clinic_cases'::regclass and tgname in ('zz_usulan_izin','ab_sakit')) = 2 then 'Sesuai' else 'Periksa' end
union all select 8, 'Pengingat klinik terjadwal (pg_cron tiap 10 menit)', case when exists (select 1 from cron.job where jobname = 'pengingat-klinik') then 'Sesuai' else 'Periksa' end
union all select 9, 'Izin admin kelola_klinik, kelola_izin_santri, kelola_lapor',
       case when (select count(*) from admin_capabilities where kode in ('kelola_klinik','kelola_izin_santri','kelola_lapor')) = 3 then 'Sesuai' else 'Periksa' end
union all select 10, 'Template WA Fase 6 (5)',
       case when (select count(*) from wa_templates where kode in ('rekap_asrama','rekap_kamar','izin_santri','santri_sakit','santri_sembuh')) = 5 then 'Sesuai' else 'Periksa' end
union all select 11, 'Format nomor surat keterangan sakit (SKS)', case when exists (select 1 from doc_number_formats where kode = 'sks') then 'Sesuai' else 'Periksa' end
union all select 12, 'Pantauan langsung klinik, izin, laporan (realtime)',
       case when not exists (select 1 from pg_publication where pubname = 'supabase_realtime')
             or (select count(*) from pg_publication_tables where pubname = 'supabase_realtime' and tablename in ('clinic_cases','student_permits','incident_reports')) = 3
            then 'Sesuai' else 'Periksa' end
union all select 13, 'Kesiapan: petugas klinik aktif putra / putri',
       (select count(*) filter (where klinik = 'putra') || ' / ' || count(*) filter (where klinik = 'putri') from clinic_staff where aktif)
union all select 14, 'Kesiapan: pemutus izin Kesantrian/Tahfizh/Wustha/SMA, Direktur-Wadir',
       (select string_agg((select count(*) from public._pejabat_unit(k, 30))::text, '/') from unnest(array['KESANTRIAN','TAHFIZH','WUSTHA','SMA']) k)
       || ', ' || (select count(*) from public._pimpinan_puncak())
union all select 15, 'Kesiapan: kamar aktif / tanpa musyrif / tanpa tautan grup WA wali',
       (select count(*) || ' / ' || count(*) filter (where not exists (select 1 from group_keepers k where k.group_id = g.id)) || ' / ' || count(*) filter (where nullif(g.wa_wali, '') is null)
          from student_groups g join academic_years a on a.id = g.academic_year_id and a.aktif where g.jenis = 'kamar' and g.aktif)
union all select 16, 'Kesiapan: pegawai aktif tanpa bidang/unit (tidak menerima laporan unit)',
       (select count(*)::text from employees where status_keaktifan = 'aktif' and status_akun = 'aktif' and org_unit_id is null)
union all select 17, 'Data: kasus klinik / izin santri / jurnal musyrif / laporan',
       (select count(*) from clinic_cases)::text || ' / ' || (select count(*) from student_permits)::text || ' / ' || (select count(*) from dorm_journals)::text
       || ' / ' || (select count(*) from incident_reports)::text
union all select 18, 'Pelapor anonim', case when (public.pengaturan_lapor()->>'anonim_diizinkan')::boolean then 'Aktif' else 'Nonaktif (bawaan)' end
order by 1;
