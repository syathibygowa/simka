-- SIMKA PRO | supabase/cek-akhir-fase3-v1.1.sql | v1.1 | Penutupan Fase 3 – Administrasi pegawai (dengan perbaikan P1–P5) | 04/10/2026
-- =====================================================================
-- Pemeriksaan akhir Fase 3 (migrasi 1900–2900). Hanya membaca, tidak mengubah data.
-- Hasil yang benar: baris 1–19 "Sesuai". Baris 20–22 adalah keterangan kesiapan data
-- (boleh "Belum" selama uji coba; lengkapi sebelum dipakai penuh).
-- =====================================================================
select * from (values
  (1, 'Migrasi 1900–2400 terpasang (fungsi kunci tiap tahap)',
   case when (select count(*) from pg_proc where pronamespace = 'public'::regnamespace and proname in
     ('simpan_pengumuman','ajukan_pengajuan','jurnal_saya','cek_kartu','kalender_saya','ringkasan_beranda')) = 6 then 'Sesuai' else 'Periksa' end),
  (2, 'Tabel Fase 3 lengkap (19 tabel, 2 kolom baru, skema privat)',
   case when (select count(*) from pg_tables where schemaname = 'public' and tablename in
     ('announcements','announcement_targets','push_subscriptions','push_queue','leave_types','leave_tiers','acting_assignments',
      'leave_requests','leave_approvals','journal_items','journal_checks','journal_entries','employee_documents','employee_document_targets',
      'employee_cards','agendas','agenda_targets','agenda_reminders_sent','wa_templates')) = 19
     and exists (select 1 from information_schema.columns where table_name = 'attendances' and column_name = 'leave_request_id')
     and exists (select 1 from information_schema.columns where table_name = 'signatories' and column_name = 'sumber_jabatan')
     and exists (select 1 from information_schema.tables where table_schema = 'privat' and table_name = 'rahasia')
   then 'Sesuai' else 'Periksa' end),
  (3, 'RLS aktif di semua tabel Fase 3',
   case when (select bool_and(rowsecurity) from pg_tables where schemaname = 'public' and tablename in
     ('announcements','announcement_targets','push_subscriptions','push_queue','leave_types','leave_tiers','acting_assignments',
      'leave_requests','leave_approvals','journal_items','journal_checks','journal_entries','employee_documents','employee_document_targets',
      'employee_cards','agendas','agenda_targets','agenda_reminders_sent','wa_templates')) then 'Sesuai' else 'Periksa' end),
  (4, 'Izin admin Fase 3 (10)',
   case when (select count(*) from admin_capabilities where kode in ('atur_pengajuan','lihat_pengajuan','atur_jurnal','verval_jurnal',
     'kelola_berkas','cetak_kartu','kelola_agenda','audit_log','kelola_kelompok','atur_beban_kerja')) = 10 then 'Sesuai' else 'Periksa' end),
  (5, 'Ekstensi pg_net aktif (notifikasi HP)',
   case when exists (select 1 from pg_extension where extname = 'pg_net') then 'Sesuai' else 'Periksa' end),
  (6, 'Pemicu notifikasi ke HP (zz_dorong)',
   case when exists (select 1 from pg_trigger where tgname = 'zz_dorong') then 'Sesuai' else 'Periksa' end),
  (7, 'Jadwal pg_cron Fase 3 (sapu-antrian-dorong, pengingat-agenda)',
   case when (select count(*) from cron.job where jobname in ('sapu-antrian-dorong','pengingat-agenda')) = 2 then 'Sesuai' else 'Periksa' end),
  (8, 'Jenis pengajuan aktif (minimal 9) dan jenjang persetujuan',
   case when (select count(*) from leave_types where aktif) >= 9 and exists (select 1 from leave_tiers) then 'Sesuai' else 'Periksa' end),
  (9, 'Butir ceklist jurnal (minimal 30)',
   case when (select count(*) from journal_items) >= 30 then 'Sesuai' else 'Periksa' end),
  (10, 'Template WA (minimal 11)',
   case when (select count(*) from wa_templates) >= 11 then 'Sesuai' else 'Periksa' end),
  (11, 'Verifikasi kartu dapat dibuka tanpa masuk',
   case when has_function_privilege('anon', 'public.cek_kartu(text)', 'execute') then 'Sesuai' else 'Periksa' end),
  (12, 'Fungsi internal dorong tertutup bagi pengguna',
   case when not has_function_privilege('authenticated', 'public._dorong_rahasia()', 'execute')
         and not has_function_privilege('anon', 'public._dorong_ambil(int)', 'execute') then 'Sesuai' else 'Periksa' end),
  (13, 'Penanda tangan Direktur tertaut ke jabatan struktural',
   case when exists (select 1 from signatories where sumber_jabatan = 'DIREKTUR') then 'Sesuai' else 'Periksa: tautkan di Pengaturan → Penanda tangan' end),
  (14, 'Format nomor dokumen "pengajuan" aktif',
   case when exists (select 1 from doc_number_formats where kode = 'pengajuan' and aktif) then 'Sesuai' else 'Periksa' end),
  (15, 'Perbaikan P1: kelompok pegawai dan lampiran pengumuman (2500)',
   case when exists (select 1 from pg_tables where tablename = 'employee_groups')
         and exists (select 1 from information_schema.columns where table_name = 'announcements' and column_name = 'lampiran_id') then 'Sesuai' else 'Periksa' end),
  (16, 'Perbaikan P2: agenda berulang, warna, pengingat menit (2600)',
   case when exists (select 1 from pg_proc where proname = 'kejadian_agenda')
         and exists (select 1 from cron.job where jobname = 'pengingat-agenda' and schedule = '*/5 * * * *') then 'Sesuai' else 'Periksa' end),
  (17, 'Perbaikan P3: kategori berkas dan template WA (2700)',
   case when exists (select 1 from pg_tables where tablename = 'document_categories')
         and (select count(*) from wa_templates) >= 11 then 'Sesuai' else 'Periksa' end),
  (18, 'Perbaikan P4: data kartu portrait (2800)',
   case when position('jabatan_kartu' in pg_get_function_result('public.data_kartu(uuid[])'::regprocedure)) > 0 then 'Sesuai' else 'Periksa' end),
  (19, 'Perbaikan P5: ekuivalensi jam beban kerja (2900)',
   case when (select count(*) from pg_tables where tablename in ('workload_components','employee_workloads','workload_snapshots') and rowsecurity) = 3
         and public.jam_wajib('tetap') is not null then 'Sesuai' else 'Periksa' end),
  (20, 'Keterangan: pemegang jabatan Direktur/Wadir berakun aktif',
   case when exists (select 1 from public.pemegang_jabatan(null) where kode in ('DIREKTUR','WAKIL_DIREKTUR')) then 'Sesuai' else 'Belum: isi jabatan struktural di Data Pegawai' end),
  (21, 'Keterangan: kunci notifikasi HP (VAPID) sudah dibuat',
   case when exists (select 1 from privat.rahasia where kunci = 'vapid') then 'Sesuai' else 'Belum: uji fungsi dorong {"aksi":"kunci"}' end),
  (22, 'Keterangan: pegawai aktif tanpa NIY',
   (select case when count(*) = 0 then 'Sesuai' else 'Belum: ' || count(*) || ' pegawai' end from employees where status_keaktifan = 'aktif' and nullif(trim(coalesce(niy, '')), '') is null))
) t(no, pemeriksaan, hasil) order by no;
