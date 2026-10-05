-- SIMKA PRO | supabase/cek-akhir-fase5-v1.0.sql | v1.0 | Penutupan Fase 5 – Tahfizh | 05/10/2026
-- Pemeriksaan akhir Fase 5 (hanya membaca). Hasil yang benar: baris 1–12 "Sesuai"; baris 13–17 keterangan kesiapan data.
select 1 as no, 'Migrasi 3800–4500 terpasang' as pemeriksaan,
       case when (select count(distinct proname) from pg_proc where proname in ('daftar_tahfizh','simpan_setoran','capaian_bulanan','ajukan_perubahan_pegawai',
         'selesai_ganti_sandi','nilai_ujian','data_laporan_tahfizh','hafalan_santri')) = 8 then 'Sesuai' else 'Periksa' end as hasil
union all select 2, 'Tabel tahfizh ber-RLS (14)',
       case when (select count(*) from pg_tables where schemaname = 'public' and rowsecurity and tablename in ('tahfizh_settings','predicate_ranges','tahfizh_targets',
         'tahfizh_months','tahfizh_examiners','student_tahfizh','juz_achievements','memorization_sessions','memorization_logs','juz_proposals',
         'monthly_achievements','tahfizh_exams','employee_data_requests','wa_templates')) = 14 then 'Sesuai' else 'Periksa' end
union all select 3, 'Tabel tahfizh tidak dapat ditulis langsung (hanya lewat fungsi)',
       case when not exists (select 1 from pg_policies where schemaname = 'public' and cmd in ('INSERT','UPDATE','DELETE','ALL') and tablename in ('tahfizh_settings',
         'predicate_ranges','tahfizh_targets','tahfizh_months','tahfizh_examiners','student_tahfizh','juz_achievements','memorization_sessions','memorization_logs',
         'juz_proposals','monthly_achievements','tahfizh_exams','employee_data_requests')) then 'Sesuai' else 'Periksa' end
union all select 4, 'Izin admin atur_tahfizh dan validasi_tahfizh',
       case when (select count(*) from admin_capabilities where kode in ('atur_tahfizh','validasi_tahfizh')) = 2 then 'Sesuai' else 'Periksa' end
union all select 5, 'Pengaturan tahfizh tahun ajaran aktif (pengaturan, predikat, 12 target, bulan efektif)',
       case when exists (select 1 from tahfizh_settings s join academic_years a on a.id = s.academic_year_id and a.aktif)
             and (select count(*) from predicate_ranges p join academic_years a on a.id = p.academic_year_id and a.aktif) >= 2
             and (select count(*) from tahfizh_targets t join academic_years a on a.id = t.academic_year_id and a.aktif) = 12
             and (select count(*) from tahfizh_months m join academic_years a on a.id = m.academic_year_id and a.aktif) >= 10 then 'Sesuai' else 'Periksa' end
union all select 6, 'Bobot Tajwid + Itqan = 100', case when not exists (select 1 from tahfizh_settings where bobot_tajwid + bobot_itqan <> 100) then 'Sesuai' else 'Periksa' end
union all select 7, 'Rentang predikat tidak bertumpuk',
       case when not exists (select 1 from predicate_ranges a join predicate_ranges b on a.academic_year_id = b.academic_year_id and a.id <> b.id
         and a.nilai_min <= b.nilai_maks and b.nilai_min <= a.nilai_maks) then 'Sesuai' else 'Periksa' end
union all select 8, 'Penguji dikelola penuh (tanpa penguji bawaan terkunci)',
       case when (select pronargs from pg_proc where proname = 'penguji_tahfizh') = 1
             and pg_get_function_result((select oid from pg_proc where proname = 'penguji_tahfizh')) like '%no_hp%' then 'Sesuai' else 'Periksa' end
union all select 9, 'Pantauan langsung setoran dan ujian (realtime)',
       case when not exists (select 1 from pg_publication where pubname = 'supabase_realtime')
             or (select count(*) from pg_publication_tables where pubname = 'supabase_realtime' and tablename in ('memorization_sessions','tahfizh_exams')) = 2 then 'Sesuai' else 'Periksa' end
union all select 10, 'Template WA tahfizh (rekap_hafalan, penguji_ujian)',
       case when (select count(*) from wa_templates where kode in ('rekap_hafalan','penguji_ujian')) = 2 then 'Sesuai' else 'Periksa' end
union all select 11, 'Perbaikan ganti sandi terpasang',
       case when (select prorettype::regtype::text from pg_proc where proname = 'selesai_ganti_sandi') = 'boolean' then 'Sesuai' else 'Periksa' end
union all select 12, 'Tahun ajaran baru otomatis mendapat pengaturan tahfizh', case when exists (select 1 from pg_trigger where tgname = 'zz_tahfizh') then 'Sesuai' else 'Periksa' end
union all select 13, 'Kesiapan: santri aktif / punya data hafalan / belum terdata',
       (select count(*) || ' aktif / ' || count(*) filter (where exists (select 1 from student_tahfizh t where t.student_id = s.id and t.posisi_pada is not null)
         or exists (select 1 from juz_achievements j where j.student_id = s.id)) || ' terdata' from students s where s.status = 'aktif')
union all select 14, 'Kesiapan: halaqah aktif / tanpa muhaffizh',
       (select count(*) || ' halaqah / ' || count(*) filter (where not exists (select 1 from group_keepers k where k.group_id = g.id)) || ' tanpa muhaffizh'
          from student_groups g join academic_years a on a.id = g.academic_year_id and a.aktif where g.jenis = 'halaqah' and g.aktif)
union all select 15, 'Kesiapan: penguji aktif kenaikan / sertifikasi',
       (select count(*) filter (where jenis = 'kenaikan' and aktif) || ' / ' || count(*) filter (where jenis = 'sertifikasi' and aktif) from tahfizh_examiners)
union all select 16, 'Kesiapan: program Takhassus (santri) dan target Takhassus berbeda dari Reguler',
       (select count(*) from student_tahfizh where program = 'takhassus')::text || ' santri / '
       || case when exists (select 1 from tahfizh_targets r join tahfizh_targets t on t.academic_year_id = r.academic_year_id and t.tingkat = r.tingkat
            join academic_years a on a.id = r.academic_year_id and a.aktif where r.program = 'reguler' and t.program = 'takhassus' and t.pekan_hal <> r.pekan_hal)
          then 'target sudah dibedakan' else 'target masih sama' end
union all select 17, 'Kesiapan: setoran / ujian / usulan menunggu',
       (select count(*) from memorization_sessions)::text || ' sesi setoran / ' || (select count(*) from tahfizh_exams)::text || ' ujian / '
       || (select count(*) from juz_proposals where status = 'menunggu')::text || ' usulan menunggu'
order by 1;
