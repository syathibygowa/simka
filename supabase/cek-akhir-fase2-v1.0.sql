-- SIMKA PRO | supabase/cek-akhir-fase2-v1.0.sql | v1.0 | Fase 2 – Tahap 8 Pemeriksaan akhir | 03/10/2026
-- Pemeriksaan akhir Fase 2 (presensi pegawai). Jalankan di SQL Editor SETELAH migrasi 1200–1800.
-- Hasil yang benar: 14 baris; baris 1–13 "Sesuai", baris 14 menampilkan status penutupan otomatis.
select 1 as no, 'Tabel presensi (13)' as pemeriksaan,
       case when count(*) = 13 then 'Sesuai' else 'Periksa: ' || count(*) end as hasil
  from information_schema.tables where table_schema = 'public' and table_name in ('gps_points','task_patterns','pattern_sessions',
   'employee_schedules','shift_rosters','shift_swaps','attendance_checks','attendance_events','attendances','attendance_status_history',
   'correction_requests','suspicion_flags','attendance_reminders')
union all
select 2, 'RLS aktif di semua tabel presensi',
       case when count(*) = 13 then 'Sesuai' else 'Periksa: ' || count(*) end
  from pg_tables where schemaname = 'public' and rowsecurity and tablename in ('gps_points','task_patterns','pattern_sessions',
   'employee_schedules','shift_rosters','shift_swaps','attendance_checks','attendance_events','attendances','attendance_status_history',
   'correction_requests','suspicion_flags','attendance_reminders')
union all
select 3, 'Fungsi inti presensi',
       case when count(distinct proname) = 14 then 'Sesuai' else 'Periksa: ' || count(distinct proname) end
  from pg_proc where pronamespace = 'public'::regnamespace and proname in ('jadwal_pegawai','rencana_presensi','periksa_presensi',
   'catat_presensi','_catat_presensi','presensi_harian','tutup_sesi_presensi','periksa_kecurigaan','sinkron_jadwal','pratinjau_jadwal',
   'atur_pola_jabatan','izin_admin_saya','titik_terdekat','jarak_meter')
union all
select 4, 'Fungsi shift, verval, koreksi, rekap',
       case when count(distinct proname) = 20 then 'Sesuai' else 'Periksa: ' || count(distinct proname) end
  from pg_proc where pronamespace = 'public'::regnamespace and proname in ('data_shift','simpan_jadwal_shift','ajukan_tukar_shift',
   'jawab_tukar_shift','putuskan_tukar_shift','batalkan_tukar_shift','verval_presensi','ajukan_koreksi','putuskan_koreksi','ubah_presensi',
   'catat_presensi_manual','ajukan_izin_sesi','batalkan_izin_sesi','tinjau_kecurigaan','panel_verval','riwayat_presensi',
   'statistik_presensi','rekap_harian','rekap_presensi','kirim_pengingat_presensi')
union all
select 5, 'Pola tugas isi awal (8)',
       case when count(*) >= 8 then 'Sesuai' else 'Periksa: ' || count(*) end
  from public.task_patterns where kode in ('GURU','KANTOR','STRUKTURAL','MUHAFFIZH','MUSYRIF','EKSKUL','MEDIS','SECURITY')
union all
select 6, 'Pemicu riwayat, sinkron, notifikasi',
       case when (select count(*) from pg_trigger where tgname in ('zz_riwayat','zz_sinkron_jadwal','zz_notif_verval','zz_notif_curiga','aa_sesi_jaga','aa_shift_jaga')) = 8
            then 'Sesuai' else 'Periksa' end
union all
select 7, 'Jadwal pg_cron presensi (3)',
       case when (select count(*) from cron.job where jobname in ('tutup-sesi-presensi','penyapuan-presensi-harian','pengingat-presensi')) = 3
            then 'Sesuai' else 'Periksa' end
union all
select 8, 'Catat presensi hanya untuk service_role',
       case when not has_function_privilege('authenticated', 'public.catat_presensi(uuid,uuid,text,text,uuid,text,text,text,text,text,boolean)', 'execute')
             and not has_function_privilege('anon', 'public.catat_presensi(uuid,uuid,text,text,uuid,text,text,text,text,text,boolean)', 'execute')
            then 'Sesuai' else 'Periksa' end
union all
select 9, 'Tabel presensi tanpa kebijakan tulis untuk klien',
       case when not exists (select 1 from pg_policies where schemaname = 'public' and tablename in ('attendances','attendance_events','attendance_status_history')
                              and cmd in ('INSERT','UPDATE','DELETE','ALL')) then 'Sesuai' else 'Periksa' end
union all
select 10, 'Izin admin atur_presensi dan verval_presensi',
       case when (select count(*) from public.admin_capabilities where kode in ('atur_presensi','verval_presensi')) = 2 then 'Sesuai' else 'Periksa' end
union all
select 11, 'Pengaturan presensi tersimpan',
       case when exists (select 1 from public.institution_settings where kunci = 'presensi') then 'Sesuai' else 'Periksa' end
union all
select 12, 'Realtime tabel attendances',
       case when exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'attendances') then 'Sesuai' else 'Periksa' end
union all
select 13, 'Titik GPS aktif minimal 1',
       case when exists (select 1 from public.gps_points where aktif) then 'Sesuai' else 'Periksa: tambahkan titik di Pengaturan Presensi' end
union all
select 14, 'Penutupan otomatis',
       coalesce('Aktif sejak ' || to_char((public.pengaturan_presensi()->>'mulai_tanggal')::date, 'DD/MM/YYYY'), 'Belum aktif (aktifkan setelah uji coba)')
order by 1;
