-- SIMKA PRO | supabase/migrations/20261029012100_rekam_kepegawaian.sql | v1.0 | 14.8.0: Rekam Kepegawaian individu (laporan menyeluruh satu pegawai pada satu periode) | 18/10/2026
-- =====================================================================
-- SIMKA PRO · Migrasi 121: Rekam Kepegawaian
--   Satu fungsi baca, rekam_kepegawaian(pegawai, mulai, selesai), menyatukan seluruh catatan seorang pegawai dalam satu periode
--   (paling lama 366 hari) seperti rekam medis: identitas dan jabatan, riwayat kepegawaian, kehadiran (ringkas, per bulan,
--   per hari dalam pekan), pengajuan izin/sakit/cuti/dinas luar, jurnal harian, mengajar (penugasan, jurnal mengajar per bulan),
--   absensi santri yang diisi, tugas pengasuhan, beban kerja, dan surat teguran.
--   Hak baca sama dengan laporan kehadiran: dirinya, atasan langsung (pimpinan unitnya), dan pemegang hak melihat semua pegawai.
--   Surat teguran hanya dimuat bila pembaca berhak melihatnya (boleh_lihat_teguran). Data gaji tidak dimuat.
-- Jalankan SETELAH migrasi 12000. Aman dijalankan ulang.
-- =====================================================================

create or replace function public.rekam_kepegawaian(p_emp uuid, p_mulai date, p_selesai date)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare e employees; v_saya uuid := public.saya(); v_hari date := public.hari_ini(); v_akhir date;
begin
  if v_saya is null then raise exception 'Akun Anda belum aktif.'; end if;
  select * into e from employees where id = p_emp;
  if e.id is null then raise exception 'Pegawai tidak ditemukan.'; end if;
  if not (e.id = v_saya or public.lihat_semua_pegawai() or public.pimpinan_dari(e.id)) then
    raise exception 'Anda tidak berwenang melihat rekam kepegawaian pegawai ini.' using errcode = '42501'; end if;
  if p_mulai is null or p_selesai is null or p_selesai < p_mulai then raise exception 'Rentang tanggal tidak sah.'; end if;
  if p_selesai - p_mulai > 365 then raise exception 'Rentang rekam kepegawaian paling lama 366 hari.'; end if;
  v_akhir := least(p_selesai, v_hari);

  return jsonb_build_object(
    'mulai', p_mulai, 'selesai', p_selesai, 'dibuat', now(),
    -- ---------- Identitas dan jabatan ----------
    'profil', jsonb_build_object('id', e.id, 'nama', e.nama_lengkap, 'niy', e.niy, 'jenis_kelamin', e.jenis_kelamin, 'tempat_lahir', e.tempat_lahir,
      'tanggal_lahir', e.tanggal_lahir, 'tmt_tugas', e.tmt_tugas, 'status_kepegawaian', e.status_kepegawaian, 'kategori_honorer', e.kategori_honorer,
      'pendidikan', e.pendidikan_terakhir, 'status_keluarga', e.status_keluarga, 'no_hp', e.no_hp, 'foto_id', e.foto_id, 'status_keaktifan', e.status_keaktifan,
      'level_muhaffizh', e.level_muhaffizh,
      'unit', (select nama from org_units where id = e.org_unit_id),
      'bidang', (select nama from org_units where id = public._bidang_unit(e.org_unit_id)),
      'masa_kerja_bulan', case when e.tmt_tugas is null then null else (extract(year from age(v_hari, e.tmt_tugas)) * 12 + extract(month from age(v_hari, e.tmt_tugas)))::int end,
      'struktural', coalesce((select jsonb_agg(jsonb_build_object('jabatan', sp.nama, 'unit', u.nama, 'tmt', es.tmt) order by sp.nama)
                     from employee_structurals es join structural_positions sp on sp.id = es.structural_position_id left join org_units u on u.id = es.org_unit_id
                    where es.employee_id = e.id), '[]'::jsonb),
      'fungsional', coalesce((select jsonb_agg(fp.nama order by fp.urutan) from employee_functions ef join functional_positions fp on fp.id = ef.functional_position_id
                    where ef.employee_id = e.id), '[]'::jsonb),
      'plt', coalesce((select jsonb_agg(jsonb_build_object('jabatan', sp.nama, 'unit', u.nama, 'mulai', a.mulai, 'sampai', a.sampai) order by a.mulai)
                     from acting_assignments a join structural_positions sp on sp.id = a.structural_position_id left join org_units u on u.id = a.org_unit_id
                    where a.employee_id = e.id and a.sampai >= p_mulai and a.mulai <= p_selesai), '[]'::jsonb)),
    'riwayat', coalesce((select jsonb_agg(jsonb_build_object('tanggal', h.tanggal_berlaku, 'jenis', h.jenis, 'lama', h.nilai_lama, 'baru', h.nilai_baru, 'alasan', h.alasan)
                     order by h.tanggal_berlaku desc nulls last, h.created_at desc)
                     from (select * from employment_history where employee_id = e.id order by tanggal_berlaku desc nulls last, created_at desc limit 40) h), '[]'::jsonb),
    -- ---------- Kehadiran ----------
    'presensi', (select jsonb_build_object(
        'sesi', count(*), 'hadir', count(*) filter (where status = 'hadir'), 'terlambat', count(*) filter (where status = 'terlambat'),
        'menit_terlambat', coalesce(sum(terlambat_menit) filter (where status = 'terlambat'), 0), 'dinas_luar', count(*) filter (where status = 'dinas_luar'),
        'izin', count(*) filter (where status = 'izin'), 'sakit', count(*) filter (where status = 'sakit'), 'cuti', count(*) filter (where status = 'cuti'),
        'tanpa_keterangan', count(*) filter (where status = 'tanpa_keterangan'), 'menunggu', count(*) filter (where status = 'menunggu_verval'),
        'cepat_pulang', count(*) filter (where status_pulang = 'cepat'), 'menit_cepat', coalesce(sum(cepat_pulang_menit) filter (where status_pulang = 'cepat'), 0),
        'tidak_presensi_pulang', count(*) filter (where status_pulang = 'tidak_presensi'),
        'hari_hadir', count(distinct tanggal) filter (where status in ('hadir','terlambat','dinas_luar')),
        'persen', case when count(*) = 0 then null else round(100.0 * count(*) filter (where status in ('hadir','terlambat','dinas_luar')) / count(*), 1) end,
        'tepat_waktu', case when count(*) filter (where status in ('hadir','terlambat')) = 0 then null
                            else round(100.0 * count(*) filter (where status = 'hadir') / count(*) filter (where status in ('hadir','terlambat')), 1) end)
      from attendances where employee_id = e.id and tanggal between p_mulai and v_akhir and not opsional),
    'presensi_bulan', coalesce((select jsonb_agg(jsonb_build_object('bulan', to_char(m, 'YYYY-MM'), 'sesi', x.sesi, 'hadir', x.hadir, 'terlambat', x.lambat, 'menit', x.menit,
        'tanpa_keterangan', x.tk, 'izin_sakit_cuti', x.isc, 'dinas_luar', x.dl,
        'persen', case when x.sesi = 0 then null else round(100.0 * (x.hadir + x.lambat + x.dl) / x.sesi, 1) end) order by m)
      from generate_series(date_trunc('month', p_mulai), date_trunc('month', p_selesai), interval '1 month') m
      cross join lateral (select count(*) sesi, count(*) filter (where status = 'hadir') hadir, count(*) filter (where status = 'terlambat') lambat,
                                 coalesce(sum(terlambat_menit) filter (where status = 'terlambat'), 0) menit, count(*) filter (where status = 'tanpa_keterangan') tk,
                                 count(*) filter (where status in ('izin','sakit','cuti')) isc, count(*) filter (where status = 'dinas_luar') dl
                            from attendances where employee_id = e.id and not opsional and tanggal between greatest(m::date, p_mulai) and least((m + interval '1 month - 1 day')::date, v_akhir)) x), '[]'::jsonb),
    'presensi_hari', coalesce((select jsonb_agg(jsonb_build_object('hari', d, 'sesi', count_all, 'terlambat', lambat, 'tanpa_keterangan', tk) order by d)
      from (select extract(isodow from tanggal)::int d, count(*) count_all, count(*) filter (where status = 'terlambat') lambat, count(*) filter (where status = 'tanpa_keterangan') tk
              from attendances where employee_id = e.id and not opsional and tanggal between p_mulai and v_akhir group by 1) q), '[]'::jsonb),
    -- ---------- Pengajuan ----------
    'pengajuan', coalesce((select jsonb_agg(jsonb_build_object('mulai', r.mulai, 'selesai', r.selesai, 'hari', r.jumlah_hari, 'jenis', t.nama, 'kelompok', t.kelompok,
        'status', r.status, 'alasan', left(r.alasan, 160), 'nomor', r.nomor_surat) order by r.mulai desc)
      from leave_requests r join leave_types t on t.id = r.leave_type_id
     where r.employee_id = e.id and r.mulai <= p_selesai and r.selesai >= p_mulai), '[]'::jsonb),
    -- ---------- Jurnal harian ----------
    'jurnal', (select jsonb_build_object('entri', count(*), 'hari', count(distinct tanggal), 'disetujui', count(*) filter (where status = 'disetujui'),
        'menunggu', count(*) filter (where status = 'menunggu'), 'dikembalikan', count(*) filter (where status = 'dikembalikan'),
        'jam', round(coalesce(sum(extract(epoch from (jam_selesai - jam_mulai)) / 3600.0), 0)::numeric, 1))
      from journal_entries where employee_id = e.id and tanggal between p_mulai and p_selesai),
    'jurnal_bulan', coalesce((select jsonb_agg(jsonb_build_object('bulan', to_char(m, 'YYYY-MM'),
        'hari', (select count(distinct tanggal) from journal_entries j where j.employee_id = e.id and date_trunc('month', j.tanggal) = m and j.tanggal between p_mulai and p_selesai),
        'hari_hadir', (select count(distinct tanggal) from attendances a where a.employee_id = e.id and date_trunc('month', a.tanggal) = m and a.tanggal between p_mulai and v_akhir
                         and a.status in ('hadir','terlambat','dinas_luar'))) order by m)
      from generate_series(date_trunc('month', p_mulai), date_trunc('month', p_selesai), interval '1 month') m), '[]'::jsonb),
    -- ---------- Mengajar ----------
    'mengajar', coalesce((select jsonb_agg(jsonb_build_object('kelas', g.nama, 'mapel', s.nama, 'jp', ta.jp_pekan, 'tahun', y.nama,
        'terlaksana', (select count(*) from teaching_journals tj where tj.assignment_id = ta.id and tj.tanggal between p_mulai and p_selesai and tj.status = 'terlaksana'),
        'tidak', (select count(*) from teaching_journals tj where tj.assignment_id = ta.id and tj.tanggal between p_mulai and p_selesai and tj.status = 'tidak_terlaksana'))
        order by y.nama desc, s.nama, g.nama)
      from teaching_assignments ta join student_groups g on g.id = ta.group_id join subjects s on s.id = ta.subject_id join academic_years y on y.id = ta.academic_year_id
     where ta.employee_id = e.id and (y.aktif or exists (select 1 from teaching_journals tj where tj.assignment_id = ta.id and tj.tanggal between p_mulai and p_selesai))), '[]'::jsonb),
    'mengajar_bulan', coalesce((select jsonb_agg(jsonb_build_object('bulan', to_char(m, 'YYYY-MM'),
        'terlaksana', (select count(*) from teaching_journals tj where tj.employee_id = e.id and date_trunc('month', tj.tanggal) = m and tj.tanggal between p_mulai and p_selesai and tj.status = 'terlaksana'),
        'tidak', (select count(*) from teaching_journals tj where tj.employee_id = e.id and date_trunc('month', tj.tanggal) = m and tj.tanggal between p_mulai and p_selesai and tj.status = 'tidak_terlaksana')) order by m)
      from generate_series(date_trunc('month', p_mulai), date_trunc('month', p_selesai), interval '1 month') m), '[]'::jsonb),
    'absensi_santri', coalesce((select jsonb_agg(jsonb_build_object('jenis', jenis, 'sesi', n, 'terlambat_isi', t) order by n desc)
      from (select jenis, count(*) n, count(*) filter (where diisi_terlambat) t from student_attendance_sessions
             where coalesce(pengampu_id, diinput_oleh) = e.id and tanggal between p_mulai and p_selesai group by jenis) q), '[]'::jsonb),
    -- ---------- Tugas pengasuhan ----------
    'tugas', coalesce((select jsonb_agg(jsonb_build_object('jenis', g.jenis, 'kelompok', g.nama, 'peran', k.peran, 'mulai', k.mulai, 'sampai', k.sampai,
        'anggota', (select count(*) from group_members m where m.group_id = g.id and m.selesai is null)) order by g.jenis, g.nama)
      from group_keepers k join student_groups g on g.id = k.group_id join academic_years y on y.id = g.academic_year_id
     where k.employee_id = e.id and (k.sampai is null or k.sampai >= p_mulai) and (k.mulai is null or k.mulai <= p_selesai) and (y.aktif or g.aktif)), '[]'::jsonb),
    -- ---------- Beban kerja ----------
    'beban', jsonb_build_object(
      'jam', (select coalesce(sum(w.jam), 0) from employee_workloads w where w.employee_id = e.id),
      'rincian', coalesce((select jsonb_agg(jsonb_build_object('komponen', c.nama, 'jam', w.jam) order by c.urutan) from employee_workloads w join workload_components c on c.id = w.component_id
                            where w.employee_id = e.id and w.jam > 0), '[]'::jsonb),
      'kunci', (select jsonb_build_object('periode', s.periode, 'jam_wajib', s.jam_wajib, 'total', s.total, 'selisih', s.selisih, 'status', s.status)
                  from workload_snapshots s where s.employee_id = e.id order by s.periode desc limit 1)),
    -- ---------- Surat teguran (hanya bagi yang berhak) ----------
    'teguran', case when public.boleh_lihat_teguran(e.id) or e.id = v_saya then coalesce((select jsonb_agg(jsonb_build_object('tingkat', w.tingkat, 'nomor', w.nomor,
        'tanggal', coalesce(w.tanggal_surat, w.diusulkan_pada::date), 'kategori', to_jsonb(w.kategori), 'status', w.status, 'berlaku_sampai', w.berlaku_sampai) order by w.diusulkan_pada desc)
      from employee_warnings w where w.employee_id = e.id and w.status in ('terbit','dicabut') and coalesce(w.tanggal_surat, w.diusulkan_pada::date) <= p_selesai
        and coalesce(w.berlaku_sampai, w.tanggal_surat) >= p_mulai), '[]'::jsonb) else null end);
end $$;

revoke execute on function public.rekam_kepegawaian(uuid, date, date) from public, anon;
grant execute on function public.rekam_kepegawaian(uuid, date, date) to authenticated;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN — hasil yang benar: 2 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select '1. Fungsi rekam kepegawaian tersedia' as pemeriksaan,
       case when to_regprocedure('public.rekam_kepegawaian(uuid,date,date)') is not null then 'Sesuai' else 'Periksa' end as hasil
union all
select '2. Hanya untuk pengguna masuk',
       case when not has_function_privilege('anon', 'public.rekam_kepegawaian(uuid,date,date)', 'execute') then 'Sesuai' else 'Periksa' end;
