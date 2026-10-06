-- SIMKA PRO | supabase/cek-akhir-fase7-v1.0.sql | v1.0 | Penutupan Fase 7 – Perizinan santri dan Security | 06/10/2026
-- Pemeriksaan akhir Fase 7 (hanya membaca). Hasil yang benar: baris 1–14 "Sesuai"; baris 15–20 keterangan kesiapan data.
select 1 as no, 'Migrasi 5200–5600 terpasang' as pemeriksaan,
       case when (select count(distinct proname) from pg_proc where proname in ('catat_gerbang','terima_titipan','nilai_libur','pantauan_langsung',
         'riwayat_security_santri')) = 5 then 'Sesuai' else 'Periksa' end as hasil
union all select 2, 'Tabel Fase 7 ber-RLS (7)',
       case when (select count(*) from pg_tables where schemaname = 'public' and rowsecurity and tablename in ('gate_logs','parcels','guest_logs','parent_visits',
         'holiday_periods','holiday_eligibility','student_permits')) = 7 then 'Sesuai' else 'Periksa' end
union all select 3, 'Tabel Fase 7 tidak dapat ditulis langsung (hanya lewat fungsi)',
       case when not exists (select 1 from pg_policies where schemaname = 'public' and cmd in ('INSERT','UPDATE','DELETE','ALL') and tablename in ('gate_logs','parcels',
         'guest_logs','parent_visits','holiday_periods','holiday_eligibility')) then 'Sesuai' else 'Periksa' end
union all select 4, 'Pencatat gerbang hanya Security (pengasuh tidak lagi)',
       case when position('boleh_gerbang' in pg_get_functiondef('public.catat_gerbang(jsonb)'::regprocedure)) > 0
             and position('catat_gerbang(' in pg_get_functiondef('public.catat_gerbang_izin(uuid,text,timestamptz)'::regprocedure)) > 0 then 'Sesuai' else 'Periksa' end
union all select 5, 'Titipan: foto terima dan foto pengambil wajib',
       case when position('foto_terima_id' in pg_get_functiondef('public.terima_titipan(jsonb)'::regprocedure)) > 0
             and position('Foto pengambil' in pg_get_functiondef('public.ambil_titipan(uuid,jsonb)'::regprocedure)) > 0 then 'Sesuai' else 'Periksa' end
union all select 6, 'Izin jenis libur dan sumber cepat/libur',
       case when exists (select 1 from pg_constraint where conname = 'student_permits_jenis_check' and pg_get_constraintdef(oid) like '%libur%')
             and exists (select 1 from pg_constraint where conname = 'student_permits_sumber_check' and pg_get_constraintdef(oid) like '%cepat%') then 'Sesuai' else 'Periksa' end
union all select 7, 'Pengingat Security terjadwal (terlambat kembali, titipan lama)', case when exists (select 1 from cron.job where jobname = 'pengingat-security') then 'Sesuai' else 'Periksa' end
union all select 8, 'Izin admin kelola_security dan kelola_libur',
       case when (select count(*) from admin_capabilities where kode in ('kelola_security','kelola_libur')) = 2 then 'Sesuai' else 'Periksa' end
union all select 9, 'Template WA Fase 7 (titipan_santri, libur_santri)',
       case when (select count(*) from wa_templates where kode in ('titipan_santri','libur_santri')) = 2 then 'Sesuai' else 'Periksa' end
union all select 10, 'Hak lihat foto gerbang, titipan, lapor, jurnal musyrif',
       case when pg_get_functiondef('public.boleh_lihat_berkas'::regproc) like '%gate_logs%' and pg_get_functiondef('public.boleh_lihat_berkas'::regproc) like '%parcels%'
             and pg_get_functiondef('public.boleh_lihat_berkas'::regproc) like '%dorm_journals%' and pg_get_functiondef('public.boleh_lihat_berkas'::regproc) like '%extracurricular_journals ej%' then 'Sesuai' else 'Periksa' end
union all select 11, 'Pantauan langsung pimpinan', case when exists (select 1 from pg_proc where proname = 'boleh_pantauan') then 'Sesuai' else 'Periksa' end
union all select 12, 'Realtime Security dan pantauan (9 tabel)',
       case when not exists (select 1 from pg_publication where pubname = 'supabase_realtime')
             or (select count(*) from pg_publication_tables where pubname = 'supabase_realtime' and tablename in ('gate_logs','parcels','guest_logs','parent_visits',
               'attendances','student_attendance_sessions','student_attendance_exceptions','clinic_cases','student_permits')) = 9 then 'Sesuai' else 'Periksa' end
union all select 13, 'Ketentuan Security dan syarat libur terbaca',
       case when public.pengaturan_security() ? 'pengingat_titipan_hari' and public.syarat_libur_bawaan() ? 'kelas_min' then 'Sesuai' else 'Periksa' end
union all select 14, 'Fungsi Security tidak dapat dipanggil tanpa login (anon)',
       case when not exists (select 1 from information_schema.routine_privileges where grantee = 'anon' and routine_schema = 'public'
         and routine_name in ('catat_gerbang','terima_titipan','izin_cepat','nilai_libur','sahkan_libur','pantauan_langsung')) then 'Sesuai' else 'Periksa' end
union all select 15, 'Petugas Security berakun aktif', (select count(*)::text || ' orang' from public._petugas_security())
union all select 16, 'Pejabat pemutus Kesantrian (Kepala Bidang/Plt)', (select count(*)::text || ' orang' from public._pejabat_unit('KESANTRIAN', 30))
union all select 17, 'Kamar aktif tanpa musyrif',
       (select count(*)::text || ' kamar' from student_groups g join academic_years a on a.id = g.academic_year_id and a.aktif
         where g.aktif and g.jenis = 'kamar' and not exists (select 1 from group_keepers k where k.group_id = g.id))
union all select 18, 'Santri aktif tanpa nomor HP wali',
       (select count(*)::text || ' santri' from students s where s.status = 'aktif' and not exists (select 1 from student_contacts c where c.student_id = s.id and c.no_hp is not null))
union all select 19, 'Catatan gerbang / titipan / tamu / kunjungan',
       (select count(*) from gate_logs)::text || ' / ' || (select count(*) from parcels)::text || ' / ' || (select count(*) from guest_logs)::text || ' / ' || (select count(*) from parent_visits)::text
union all select 20, 'Periode libur (disahkan / semua)',
       (select count(*) filter (where status = 'disahkan'))::text || ' / ' || count(*)::text from holiday_periods
order by 1;
