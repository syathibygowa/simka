-- SIMKA PRO | supabase/cek-akhir-fase4-v1.0.sql | v1.0 | Penutupan Fase 4 – Santri dan akademik dasar | 05/10/2026
-- Pemeriksaan akhir Fase 4 (hanya membaca). Hasil yang benar: baris 1–14 "Sesuai"; baris 15–18 keterangan kesiapan data.
select 1 as no, 'Migrasi 3000–3700 terpasang' as pemeriksaan,
       case when (select count(*) from pg_proc where proname in ('simpan_santri_form','impor_pembagian','_rt_rw','simpan_absensi_santri',
         'jabatan_pengasuh','sinkron_sesi_ekskul','jadwal_mengajar','aktifkan_tahun_ajaran')) = 8 then 'Sesuai' else 'Periksa' end as hasil
union all select 2, 'Tabel santri, kelompok, absensi, ekskul, jadwal, kenaikan ber-RLS (20)',
       case when (select count(*) from pg_tables where schemaname = 'public' and rowsecurity and tablename in ('students','student_contacts','student_status_history',
         'student_mutations','student_groups','group_keepers','group_members','student_attendance_sessions','student_attendance_exceptions','student_attendance_logs',
         'extracurricular_schedules','extracurricular_journals','subjects','lesson_periods','teaching_assignments','class_schedules','teaching_plans','teaching_journals',
         'promotions','academic_years')) = 20 then 'Sesuai' else 'Periksa' end
union all select 3, 'Tabel santri/kelompok/absensi tidak dapat ditulis langsung',
       case when not exists (select 1 from pg_policies where schemaname = 'public' and cmd in ('INSERT','UPDATE','ALL') and tablename in ('students','student_contacts',
         'student_groups','group_keepers','group_members','student_attendance_sessions','student_attendance_exceptions','teaching_journals','promotions')) then 'Sesuai' else 'Periksa' end
union all select 4, 'Izin admin Fase 4 (kelola_santri, kelompok_santri, absensi_atas_nama, atur_jadwal)',
       case when (select count(*) from admin_capabilities where kode in ('kelola_santri','kelompok_santri','absensi_atas_nama','atur_jadwal')) = 4 then 'Sesuai' else 'Periksa' end
union all select 5, 'NIS 7 digit: tahun masuk dan angkatan otomatis',
       case when (select attgenerated from pg_attribute where attrelid = 'public.students'::regclass and attname = 'angkatan') = 's' then 'Sesuai' else 'Periksa' end
union all select 6, 'Kolom alamat lengkap dan nomor KK',
       case when (select count(*) from information_schema.columns where table_name = 'students' and column_name in ('no_kk','rt','rw','kelurahan','kecamatan','kota_kab','provinsi')) = 7 then 'Sesuai' else 'Periksa' end
union all select 7, 'Satu kelas, satu kamar, satu halaqah per santri per tahun ajaran',
       case when exists (select 1 from pg_indexes where indexname = 'group_members_satu_jenis') then 'Sesuai' else 'Periksa' end
union all select 8, 'Pengasuh kelas/kamar/halaqah wajib berjabatan tupoksi',
       case when public.jabatan_pengasuh('halaqah') = 'MUHAFFIZH' then 'Sesuai' else 'Periksa' end
union all select 9, 'Sesi halaqah (MUHAFFIZH) dan asrama (MUSYRIF) dari pola presensi',
       case when exists (select 1 from task_patterns where kode = 'MUHAFFIZH') and exists (select 1 from task_patterns where kode = 'MUSYRIF') then 'Sesuai' else 'Periksa' end
union all select 10, 'Jadwal ekskul tersambung ke presensi pembina (pola EKSKUL tanpa kalender pekanan)',
       case when (select kalender from task_patterns where kode = 'EKSKUL') is null and exists (select 1 from pg_trigger where tgname = 'zz_sinkron_ekskul') then 'Sesuai' else 'Periksa' end
union all select 11, 'Jabatan Pelatih ekskul (luar)', case when exists (select 1 from functional_positions where kode = 'PELATIH_EKSKUL') then 'Sesuai' else 'Periksa' end
union all select 12, 'Jam Guru Mapel otomatis dari jadwal', case when exists (select 1 from pg_trigger where tgname = 'zz_sinkron_jam') then 'Sesuai' else 'Periksa' end
union all select 13, 'Template WA wali (wali_santri, absen_santri, rekap_santri)',
       case when (select count(*) from wa_templates where kode in ('wali_santri','absen_santri','rekap_santri')) = 3 then 'Sesuai' else 'Periksa' end
union all select 14, 'Satu tahun ajaran aktif', case when (select count(*) from academic_years where aktif) = 1 then 'Sesuai' else 'Periksa' end
union all select 15, 'Kesiapan: santri aktif / data wajib kurang',
       (select count(*) filter (where status = 'aktif') || ' aktif / ' || count(*) filter (where status = 'aktif' and (nisn is null or tempat_lahir is null or tanggal_lahir is null)) || ' kurang' from students)
union all select 16, 'Kesiapan: kelompok tahun ajaran aktif (kelas/kamar/halaqah/ekskul)',
       (select coalesce(string_agg(jenis || ' ' || n, ', '), 'belum ada') from (select g.jenis, count(*) n from student_groups g join academic_years a on a.id = g.academic_year_id and a.aktif
         where g.aktif group by g.jenis order by g.jenis) x)
union all select 17, 'Kesiapan: kelompok tanpa pengasuh',
       (select count(*)::text from student_groups g join academic_years a on a.id = g.academic_year_id and a.aktif
         where g.aktif and g.jenis in ('kelas','kamar','halaqah','ekskul') and not exists (select 1 from group_keepers k where k.group_id = g.id))
union all select 18, 'Kesiapan: penugasan / jam terjadwal',
       (select count(*) || ' penugasan / ' || (select count(*) from class_schedules) || ' JP' from teaching_assignments t join academic_years a on a.id = t.academic_year_id and a.aktif)
order by 1;
