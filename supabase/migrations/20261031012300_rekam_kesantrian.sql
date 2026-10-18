-- SIMKA PRO | supabase/migrations/20261031012300_rekam_kesantrian.sql | v1.0 | 14.9.0: Rekam Kesantrian (rekam menyeluruh satu santri) | 18/10/2026
-- =====================================================================
-- SIMKA PRO · Migrasi 123: Rekam Kesantrian
--   rekam_kesantrian(santri, mulai, selesai) menyatukan untuk satu santri:
--   * profil      : data singkat, kontak utama, kelompok berjalan beserta pengasuhnya, riwayat kelompok semua tahun ajaran,
--                   riwayat status/mutasi/kenaikan kelas.
--   * kehadiran   : rekap HISBAT per program (kelas, halaqah, asrama, ekskul) dan per bulan pada periode.
--   * hafalan     : posisi terakhir, juz tuntas, capaian bulanan dan setoran per bulan pada periode.
--   * ujian       : seluruh ujian kenaikan juz/sertifikasi yang selesai dan UTAS final (semua tahun).
--   * nilai       : nilai akhir per mapel rapor setiap semester yang pernah diikuti (periode dibuka/ditutup), keputusan naik kelas.
--   * prestasi    : seluruh prestasi (bertanda "dalam periode").
--   * disiplin    : seluruh pelanggaran dan Surat Peringatan — hanya bagi yang berhak melihat kedisiplinan santri ini.
--   * security    : keluar/kembali gerbang, kunjungan, titipan pada periode.
--   * klinik      : ringkas tanpa diagnosis dan tanpa rincian pemeriksaan.
--   * perizinan   : izin keluar/pulang pada periode dan keputusan libur yang disahkan.
--   * keuangan    : hanya bagi pemegang akses keuangan (fitur sensitif) dan bila fitur keuangan dipakai.
-- Hak baca sama dengan Detail Santri (santri_terlihat): admin, pemegang Data Santri sesuai jenjang, dan pengasuh kelompoknya.
-- Rentang periode paling lama 366 hari. Tidak ada tabel baru (hemat penyimpanan).
-- Jalankan SETELAH migrasi 12200. Aman dijalankan ulang.
-- =====================================================================

-- Nilai akhir rapor satu santri untuk semua semester yang pernah diikuti
create or replace function public._rekam_nilai_santri(p_santri uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare x record; v jsonb := '[]'::jsonb; v_mapel jsonb;
begin
  for x in
    select distinct g.id gid, g.nama kelas, g.jenjang, g.tingkat, a.id ta_id, a.nama ta, a.mulai ta_mulai, gp.semester, gp.status
      from group_members m join student_groups g on g.id = m.group_id and g.jenis = 'kelas' and g.jenjang in ('sma','wustha')
      join academic_years a on a.id = g.academic_year_id
      join grade_periods gp on gp.academic_year_id = g.academic_year_id and gp.jenis = g.jenjang and gp.status in ('dibuka','ditutup')
     where m.student_id = p_santri
     order by a.mulai, gp.semester
  loop
    select coalesce(jsonb_agg(jsonb_build_object('nama', r.nama, 'kelompok', r.kelompok, 'urutan', r.urutan, 'kkm', r.kkm, 'nilai', n.nilai,
             'predikat', (select rp.huruf from report_predicates rp where rp.academic_year_id = x.ta_id and rp.kelompok = x.jenjang
                            and round(n.nilai) between rp.nilai_min and rp.nilai_maks limit 1),
             'tuntas', case when n.nilai is null then null else n.nilai >= coalesce(r.kkm, 0) end) order by r.urutan, r.nama), '[]'::jsonb)
      into v_mapel
      from report_subjects r
      left join (select * from public.nilai_rapor_kelas(x.gid, x.semester) z where z.student_id = p_santri) n on n.report_subject_id = r.id
     where r.academic_year_id = x.ta_id and r.jenis = x.jenjang and r.tingkat = x.tingkat and r.aktif;
    v := v || jsonb_build_array(jsonb_build_object('ta', x.ta, 'semester', x.semester, 'kelas', x.kelas, 'jenjang', x.jenjang, 'tingkat', x.tingkat,
      'status', x.status, 'mapel', v_mapel,
      'pd', coalesce((select jsonb_agg(jsonb_build_object('kegiatan', eg.nama, 'nilai', e.nilai) order by eg.nama)
                        from report_extracurricular e join student_groups eg on eg.id = e.group_id
                       where e.student_id = p_santri and e.academic_year_id = x.ta_id and e.semester = x.semester and e.nilai is not null), '[]'::jsonb),
      'keputusan', case when x.semester = 2 then (select jsonb_build_object('keputusan', d.keputusan, 'ke_tingkat', d.ke_tingkat)
                      from report_decisions d where d.student_id = p_santri and d.academic_year_id = x.ta_id) end));
  end loop;
  return v;
end $$;
revoke execute on function public._rekam_nilai_santri(uuid) from public, anon, authenticated;

create or replace function public.rekam_kesantrian(p_santri uuid, p_mulai date, p_selesai date)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare s students; v_hari date := public.hari_ini(); v_akhir date; v_disiplin boolean; v_keu boolean; v_hq uuid;
begin
  if public.saya() is null then raise exception 'Akun Anda belum aktif.'; end if;
  select * into s from students where id = p_santri;
  if s.id is null then raise exception 'Santri tidak ditemukan.'; end if;
  if p_santri not in (select public.santri_terlihat()) then
    raise exception 'Anda tidak berwenang melihat rekam kesantrian santri ini.' using errcode = '42501'; end if;
  if p_mulai is null or p_selesai is null or p_selesai < p_mulai then raise exception 'Rentang tanggal tidak sah.'; end if;
  if p_selesai - p_mulai > 365 then raise exception 'Rentang rekam kesantrian paling lama 366 hari.'; end if;
  v_akhir := least(p_selesai, v_hari);
  v_disiplin := public.boleh_lihat_disiplin(p_santri);
  v_keu := public.boleh_lihat_keuangan() and exists (select 1 from bills where student_id = p_santri);
  select g.id into v_hq from group_members m join student_groups g on g.id = m.group_id and g.jenis = 'halaqah'
    join academic_years a on a.id = g.academic_year_id and a.aktif where m.student_id = p_santri and m.selesai is null limit 1;

  return jsonb_build_object(
    'mulai', p_mulai, 'selesai', p_selesai, 'dibuat', now(),
    -- ---------- Data singkat ----------
    'profil', jsonb_build_object('id', s.id, 'nama', s.nama_lengkap, 'panggilan', s.nama_panggilan, 'nis', s.nis, 'nisn', s.nisn,
      'jenis_kelamin', s.jenis_kelamin, 'tempat_lahir', s.tempat_lahir, 'tanggal_lahir', s.tanggal_lahir, 'jenjang', s.jenjang, 'tingkat', s.tingkat,
      'status', s.status, 'status_sejak', s.status_sejak, 'tahun_masuk', s.tahun_masuk, 'angkatan', s.angkatan, 'tanggal_masuk', s.tanggal_masuk,
      'jalur_masuk', s.jalur_masuk, 'diterima_tingkat', s.diterima_tingkat, 'asal_sekolah', s.asal_sekolah, 'hafalan_awal_juz', s.hafalan_awal_juz,
      'foto_id', s.foto_id, 'kota', s.kota_kab, 'provinsi', s.provinsi,
      'kontak', (select jsonb_build_object('nama', c.nama, 'hubungan', c.hubungan, 'no_hp', c.no_hp) from student_contacts c
                  where c.student_id = s.id order by c.utama desc, array_position(array['ayah','ibu','wali'], c.hubungan) limit 1)),
    'kelompok', coalesce((select jsonb_agg(jsonb_build_object('jenis', g.jenis, 'nama', g.nama, 'mulai', m.mulai,
        'pengasuh', (select string_agg(e.nama_lengkap, ', ' order by array_position(array['utama','pendamping','pengganti'], k.peran))
                       from group_keepers k join employees e on e.id = k.employee_id
                      where k.group_id = g.id and (k.sampai is null or k.sampai >= v_hari) and (k.mulai is null or k.mulai <= v_hari)),
        'utama', (select jsonb_build_object('nama', e.nama_lengkap, 'niy', e.niy) from group_keepers k join employees e on e.id = k.employee_id
                   where k.group_id = g.id and (k.sampai is null or k.sampai >= v_hari) and (k.mulai is null or k.mulai <= v_hari)
                   order by array_position(array['utama','pendamping','pengganti'], k.peran) limit 1))
        order by array_position(array['kelas','kamar','halaqah','ekskul','lainnya'], g.jenis), g.nama)
      from group_members m join student_groups g on g.id = m.group_id join academic_years a on a.id = g.academic_year_id and a.aktif
     where m.student_id = s.id and m.selesai is null), '[]'::jsonb),
    'riwayat_kelompok', coalesce((select jsonb_agg(jsonb_build_object('tahun', a.nama, 'jenis', g.jenis, 'nama', g.nama, 'mulai', m.mulai, 'selesai', m.selesai,
        'alasan', m.alasan_keluar, 'aktif', a.aktif and m.selesai is null) order by a.mulai desc, array_position(array['kelas','kamar','halaqah','ekskul','lainnya'], g.jenis), m.mulai)
      from group_members m join student_groups g on g.id = m.group_id join academic_years a on a.id = g.academic_year_id where m.student_id = s.id), '[]'::jsonb),
    'riwayat', coalesce((select jsonb_agg(x order by x->>'tanggal' desc) from (
        select jsonb_build_object('tanggal', h.tanggal, 'jenis', 'status', 'lama', h.status_lama, 'baru', h.status_baru, 'alasan', h.alasan) x
          from student_status_history h where h.student_id = s.id
        union all
        select jsonb_build_object('tanggal', mu.tanggal, 'jenis', 'mutasi_' || mu.jenis, 'baru', mu.sekolah, 'alasan', mu.alasan, 'nomor', mu.nomor_surat)
          from student_mutations mu where mu.student_id = s.id
        union all
        select jsonb_build_object('tanggal', a.selesai, 'jenis', 'kenaikan', 'aksi', p.aksi, 'lama', p.tingkat_lama, 'baru', p.tingkat_baru, 'tahun', a.nama)
          from promotions p join academic_years a on a.id = p.academic_year_id where p.student_id = s.id and p.diterapkan) q), '[]'::jsonb),
    -- ---------- Kehadiran (HISBAT) ----------
    'kehadiran', (select jsonb_build_object(
        'program', coalesce((select jsonb_object_agg(jenis, jsonb_build_object('sesi', n, 'hadir', h, 'izin', i, 'sakit', sk, 'bolos', b, 'absen', ab, 'terlambat', t,
                       'persen', case when n > 0 then round(100.0 * h / n, 1) end))
            from (select jenis, count(*) n, count(*) filter (where kode not in ('I','S','A')) h, count(*) filter (where kode = 'I') i,
                         count(*) filter (where kode = 'S') sk, count(*) filter (where kode = 'B') b, count(*) filter (where kode = 'A') ab,
                         count(*) filter (where kode = 'T') t
                    from public._portal_sesi_santri(s.id, p_mulai, v_akhir) group by jenis) q), '{}'::jsonb),
        'bulan', coalesce((select jsonb_agg(jsonb_build_object('bulan', to_char(m, 'YYYY-MM'), 'sesi', z.n, 'hadir', z.h, 'izin', z.i, 'sakit', z.sk,
                       'bolos', z.b, 'absen', z.ab, 'terlambat', z.t, 'persen', case when z.n > 0 then round(100.0 * z.h / z.n, 1) end,
                       'kelas', z.pk, 'halaqah', z.ph, 'asrama', z.pa) order by m)
            from generate_series(date_trunc('month', p_mulai), date_trunc('month', p_selesai), interval '1 month') m
            cross join lateral (
              select count(*) n, count(*) filter (where kode not in ('I','S','A')) h, count(*) filter (where kode = 'I') i,
                     count(*) filter (where kode = 'S') sk, count(*) filter (where kode = 'B') b, count(*) filter (where kode = 'A') ab,
                     count(*) filter (where kode = 'T') t,
                     round(100.0 * count(*) filter (where jenis = 'kelas' and kode not in ('I','S','A')) / nullif(count(*) filter (where jenis = 'kelas'), 0), 1) pk,
                     round(100.0 * count(*) filter (where jenis = 'halaqah' and kode not in ('I','S','A')) / nullif(count(*) filter (where jenis = 'halaqah'), 0), 1) ph,
                     round(100.0 * count(*) filter (where jenis = 'asrama' and kode not in ('I','S','A')) / nullif(count(*) filter (where jenis = 'asrama'), 0), 1) pa
                from public._portal_sesi_santri(s.id, greatest(m::date, p_mulai), least((m + interval '1 month - 1 day')::date, v_akhir))
               where jenis in ('kelas','halaqah','asrama')) z), '[]'::jsonb),
        'tidak_hadir', coalesce((select jsonb_agg(jsonb_build_object('tanggal', tanggal, 'jenis', jenis, 'kelompok', kelompok, 'sesi', nama_sesi, 'kode', kode,
                       'keterangan', keterangan) order by tanggal desc, jam desc nulls last)
            from (select * from public._portal_sesi_santri(s.id, p_mulai, v_akhir) where kode in ('I','S','B','A') order by tanggal desc, jam desc nulls last limit 60) q), '[]'::jsonb))),
    -- ---------- Hafalan ----------
    'hafalan', (select jsonb_build_object(
        'program', coalesce(t.program, 'reguler'), 'sabaq_hal', coalesce(t.sabaq_hal, 0), 'sabqi_hal', coalesce(t.sabqi_hal, 0), 'manzil_hal', coalesce(t.manzil_hal, 0),
        'juz_sedang', t.juz_sedang, 'posisi_pada', t.posisi_pada, 'awal_sabaq_hal', t.awal_sabaq_hal,
        'halaqah', (select nama from student_groups where id = v_hq),
        'juz', coalesce((select jsonb_agg(jsonb_build_object('juz', j.juz, 'sumber', j.sumber, 'tanggal', j.tanggal) order by j.juz)
                           from juz_achievements j where j.student_id = s.id), '[]'::jsonb),
        'bulanan', coalesce((select jsonb_agg(jsonb_build_object('bulan', b.bulan, 'status', b.status, 'tambah_hal', b.tambah_hal, 'target_hal', b.target_hal,
                           'posisi_akhir_hal', b.posisi_akhir_hal, 'disahkan', b.disahkan_pada is not null, 'halaqah', b.halaqah) order by b.bulan)
                           from monthly_achievements b where b.student_id = s.id and b.bulan between date_trunc('month', p_mulai)::date and p_selesai), '[]'::jsonb),
        'setoran', (select jsonb_build_object('sesi', count(*), 'tambah_hal', coalesce(sum(greatest(l.tambah_hal, 0)), 0),
                           'janggal', count(*) filter (where cardinality(l.janggal) > 0), 'hari', count(distinct l.tanggal))
                      from memorization_logs l where l.student_id = s.id and l.tanggal between p_mulai and v_akhir),
        'setoran_bulan', coalesce((select jsonb_agg(jsonb_build_object('bulan', to_char(m, 'YYYY-MM'),
                           'sesi', (select count(*) from memorization_logs l where l.student_id = s.id and l.tanggal between greatest(m::date, p_mulai) and least((m + interval '1 month - 1 day')::date, v_akhir)),
                           'tambah_hal', (select coalesce(sum(greatest(l.tambah_hal, 0)), 0) from memorization_logs l where l.student_id = s.id
                                            and l.tanggal between greatest(m::date, p_mulai) and least((m + interval '1 month - 1 day')::date, v_akhir))) order by m)
                           from generate_series(date_trunc('month', p_mulai), date_trunc('month', p_selesai), interval '1 month') m), '[]'::jsonb))
      from (select 1) d left join student_tahfizh t on t.student_id = s.id),
    -- ---------- Ujian tahfizh (semua tahun) ----------
    'ujian', coalesce((select jsonb_agg(jsonb_build_object('jenis', x.jenis, 'juz', x.juz, 'jenjang', x.jenjang, 'ujian_ke', x.ujian_ke,
        'tajwid', x.nilai_tajwid, 'itqan', x.nilai_itqan, 'nilai_akhir', x.nilai_akhir, 'huruf', x.huruf, 'predikat', x.predikat, 'hasil', x.hasil,
        'tanggal', (x.diuji_pada at time zone 'Asia/Makassar')::date, 'penguji', (select e.nama_lengkap from employees e where e.id = x.penguji_id)) order by x.diuji_pada desc)
      from tahfizh_exams x where x.student_id = s.id and x.status = 'selesai'), '[]'::jsonb),
    'utas', coalesce((select jsonb_agg(jsonb_build_object('ta', a.nama, 'semester', u.semester, 'juz', u.juz, 'total_juz', u.total_juz,
        'tajwid', u.tajwid, 'itqan', u.itqan, 'nilai_akhir', u.nilai_akhir, 'huruf', u.huruf, 'tuntas', u.tuntas, 'tanggal', u.diuji_pada,
        'predikat', (select case when coalesce(rs.bahasa_predikat, 'arab') = 'arab' then coalesce(rp.sebutan_arab, rp.sebutan) else rp.sebutan end
                       from report_predicates rp left join report_settings rs on rs.academic_year_id = u.academic_year_id and rs.jenis = 'tahfizh'
                      where rp.academic_year_id = u.academic_year_id and rp.kelompok = 'utas' and u.nilai_akhir between rp.nilai_min and rp.nilai_maks limit 1))
        order by a.mulai desc, u.semester desc)
      from utas_results u join academic_years a on a.id = u.academic_year_id where u.student_id = s.id and u.status = 'final'), '[]'::jsonb),
    -- ---------- Nilai akhir rapor per semester ----------
    'nilai', public._rekam_nilai_santri(s.id),
    -- ---------- Prestasi (semua) ----------
    'prestasi', coalesce((select jsonb_agg(jsonb_build_object('tanggal', p.tanggal, 'bidang', p.bidang, 'tingkat', p.tingkat, 'kegiatan', p.nama_kegiatan,
        'capaian', p.capaian, 'penyelenggara', p.penyelenggara, 'dalam_periode', p.tanggal between p_mulai and p_selesai) order by p.tanggal desc)
      from student_achievements p where p.student_id = s.id), '[]'::jsonb),
    -- ---------- Kedisiplinan: seluruh riwayat, hanya bagi yang berhak ----------
    'pelanggaran', case when v_disiplin then coalesce((select jsonb_agg(jsonb_build_object('tanggal', v.tanggal, 'kategori', v.kategori, 'tingkat', v.tingkat,
        'tempat', v.tempat, 'uraian', left(v.uraian, 200), 'tindakan', left(v.tindakan, 160), 'dalam_periode', v.tanggal between p_mulai and p_selesai) order by v.tanggal desc, v.jam desc nulls last)
      from (select * from student_violations where student_id = s.id order by tanggal desc, jam desc nulls last limit 80) v), '[]'::jsonb) end,
    'sp', case when v_disiplin then coalesce((select jsonb_agg(jsonb_build_object('tingkat', w.tingkat, 'nomor', w.nomor,
        'tanggal', coalesce(w.tanggal_surat, (w.diusulkan_pada at time zone 'Asia/Makassar')::date), 'kategori', to_jsonb(w.kategori), 'sanksi', to_jsonb(w.sanksi),
        'uraian', left(w.uraian, 200), 'status', w.status, 'berlaku_sampai', w.berlaku_sampai, 'diserahkan_pada', w.diserahkan_pada, 'alasan', w.alasan,
        'keadaan', case when w.status = 'terbit' and (w.berlaku_sampai is null or w.berlaku_sampai >= v_hari) then 'aktif' when w.status = 'terbit' then 'berakhir' else w.status end)
        order by w.diusulkan_pada desc)
      from student_warnings w where w.student_id = s.id and w.status in ('diusulkan','terbit','dicabut')), '[]'::jsonb) end,
    -- ---------- Security pada periode ----------
    'security', jsonb_build_object(
      'keluar', (select count(*) from gate_logs where student_id = s.id and jenis = 'keluar' and (waktu at time zone 'Asia/Makassar')::date between p_mulai and p_selesai),
      'kembali', (select count(*) from gate_logs where student_id = s.id and jenis = 'kembali' and (waktu at time zone 'Asia/Makassar')::date between p_mulai and p_selesai),
      'terlambat', (select count(*) from gate_logs where student_id = s.id and jenis = 'kembali' and terlambat_menit > 0 and (waktu at time zone 'Asia/Makassar')::date between p_mulai and p_selesai),
      'ditolak', (select count(*) from gate_logs where student_id = s.id and jenis = 'ditolak' and (waktu at time zone 'Asia/Makassar')::date between p_mulai and p_selesai),
      'kunjungan', (select count(*) from parent_visits where student_id = s.id and (datang_pada at time zone 'Asia/Makassar')::date between p_mulai and p_selesai),
      'titipan', (select count(*) from parcels where student_id = s.id and (diterima_pada at time zone 'Asia/Makassar')::date between p_mulai and p_selesai),
      'gerbang', coalesce((select jsonb_agg(jsonb_build_object('waktu', g.waktu, 'jenis', g.jenis, 'terlambat_menit', g.terlambat_menit, 'penjemput', g.penjemput,
                    'catatan', left(g.catatan, 120)) order by g.waktu desc)
          from (select * from gate_logs where student_id = s.id and (waktu at time zone 'Asia/Makassar')::date between p_mulai and p_selesai order by waktu desc limit 40) g), '[]'::jsonb),
      'kunjungan_daftar', coalesce((select jsonb_agg(jsonb_build_object('datang_pada', v.datang_pada, 'pengunjung', v.pengunjung, 'hubungan', v.hubungan, 'luar_jadwal', v.luar_jadwal) order by v.datang_pada desc)
          from (select * from parent_visits where student_id = s.id and (datang_pada at time zone 'Asia/Makassar')::date between p_mulai and p_selesai order by datang_pada desc limit 20) v), '[]'::jsonb)),
    -- ---------- Klinik: ringkas, tanpa diagnosis ----------
    'klinik', jsonb_build_object(
      'kasus', (select count(*) from clinic_cases where student_id = s.id and status <> 'batal' and (dibuka_pada at time zone 'Asia/Makassar')::date between p_mulai and p_selesai),
      'istirahat', (select count(*) from clinic_cases where student_id = s.id and status <> 'batal' and tindak_lanjut in ('istirahat','rawat') and (dibuka_pada at time zone 'Asia/Makassar')::date between p_mulai and p_selesai),
      'rujuk', (select count(*) from clinic_cases where student_id = s.id and status <> 'batal' and tindak_lanjut = 'rujuk' and (dibuka_pada at time zone 'Asia/Makassar')::date between p_mulai and p_selesai),
      'pulang', (select count(*) from clinic_cases where student_id = s.id and status <> 'batal' and tindak_lanjut = 'pulang' and (dibuka_pada at time zone 'Asia/Makassar')::date between p_mulai and p_selesai),
      'daftar', coalesce((select jsonb_agg(jsonb_build_object('tanggal', (c.dibuka_pada at time zone 'Asia/Makassar')::date, 'keluhan', left(c.keluhan, 80),
                    'tindak_lanjut', c.tindak_lanjut, 'status', c.status, 'hasil', c.hasil) order by c.dibuka_pada desc)
          from (select * from clinic_cases where student_id = s.id and status <> 'batal' and (dibuka_pada at time zone 'Asia/Makassar')::date between p_mulai and p_selesai order by dibuka_pada desc limit 30) c), '[]'::jsonb)),
    -- ---------- Perizinan dan libur pada periode ----------
    'izin', coalesce((select jsonb_agg(jsonb_build_object('jenis', p.jenis, 'alasan', left(p.alasan, 160), 'status', p.status, 'keluar_pada', p.keluar_pada,
        'kembali_batas', p.kembali_batas, 'kembali_pada', p.kembali_pada, 'lama_hari', p.lama_hari, 'penjemput', p.penjemput,
        'terlambat', (p.status = 'keluar' and now() > p.kembali_batas) or (p.status = 'kembali' and p.kembali_pada > p.kembali_batas)) order by p.keluar_pada desc)
      from (select * from student_permits where student_id = s.id and jenis <> 'libur' and status not in ('dibatalkan')
              and (keluar_pada at time zone 'Asia/Makassar')::date between p_mulai and p_selesai order by keluar_pada desc limit 40) p), '[]'::jsonb),
    'libur', coalesce((select jsonb_agg(jsonb_build_object('periode', h.nama, 'pulang_pada', h.pulang_pada, 'kembali_batas', h.kembali_batas,
        'keputusan', e.keputusan, 'tingkat', e.tingkat, 'alasan_ubah', e.alasan_ubah,
        'kembali_pada', (select p.kembali_pada from student_permits p where p.id = e.permit_id),
        'terlambat', (select p.kembali_pada > p.kembali_batas from student_permits p where p.id = e.permit_id)) order by h.pulang_pada desc)
      from holiday_eligibility e join holiday_periods h on h.id = e.period_id
     where e.student_id = s.id and h.status = 'disahkan' and (h.pulang_pada at time zone 'Asia/Makassar')::date between p_mulai and p_selesai), '[]'::jsonb),
    -- ---------- Keuangan: hanya pemegang akses keuangan ----------
    'keuangan', case when v_keu then jsonb_build_object(
      'ringkas', (select jsonb_build_object('sisa', coalesce(sum(b.nominal - b.dibayar), 0),
          'tunggakan', coalesce(sum(b.nominal - b.dibayar) filter (where b.jatuh_tempo < v_hari), 0),
          'jumlah_tunggak', count(*) filter (where b.jatuh_tempo < v_hari and b.nominal > b.dibayar))
          from bills b where b.student_id = s.id and b.status in ('belum','sebagian')),
      'periode', (select jsonb_build_object('tagihan', coalesce(sum(b.nominal), 0), 'dibayar', coalesce(sum(b.dibayar), 0), 'jumlah', count(*))
          from bills b where b.student_id = s.id and b.status <> 'batal' and b.tanggal_tagih between p_mulai and p_selesai),
      'tagihan', coalesce((select jsonb_agg(jsonb_build_object('nama', b.nama, 'tanggal_tagih', b.tanggal_tagih, 'jatuh_tempo', b.jatuh_tempo, 'nominal', b.nominal,
          'dibayar', b.dibayar, 'status', b.status, 'lewat', b.status in ('belum','sebagian') and b.jatuh_tempo < v_hari) order by b.jatuh_tempo desc, b.nama)
          from bills b where b.student_id = s.id and b.status <> 'batal' and (b.status in ('belum','sebagian') or b.tanggal_tagih between p_mulai and p_selesai)), '[]'::jsonb),
      'pembayaran', coalesce((select jsonb_agg(jsonb_build_object('tanggal', y.tanggal, 'nomor', y.nomor, 'jumlah', y.jumlah, 'cara', y.cara) order by y.tanggal desc, y.created_at desc)
          from payments y where y.student_id = s.id and y.status = 'sah' and y.tanggal between p_mulai and p_selesai), '[]'::jsonb),
      'bulan', coalesce((select jsonb_agg(jsonb_build_object('bulan', to_char(m, 'YYYY-MM'),
          'dibayar', (select coalesce(sum(y.jumlah), 0) from payments y where y.student_id = s.id and y.status = 'sah' and date_trunc('month', y.tanggal) = m)) order by m)
          from generate_series(date_trunc('month', p_mulai), date_trunc('month', p_selesai), interval '1 month') m), '[]'::jsonb)) end,
    'hak', jsonb_build_object('disiplin', v_disiplin, 'keuangan', v_keu));
end $$;

revoke execute on function public.rekam_kesantrian(uuid, date, date) from public, anon;
grant execute on function public.rekam_kesantrian(uuid, date, date) to authenticated;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN — hasil yang benar: 3 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select '1. Fungsi rekam kesantrian tersedia' as pemeriksaan,
       case when to_regprocedure('public.rekam_kesantrian(uuid,date,date)') is not null
             and to_regprocedure('public._rekam_nilai_santri(uuid)') is not null then 'Sesuai' else 'Periksa' end as hasil
union all
select '2. Hanya untuk pengguna masuk',
       case when not has_function_privilege('anon', 'public.rekam_kesantrian(uuid,date,date)', 'execute')
             and has_function_privilege('authenticated', 'public.rekam_kesantrian(uuid,date,date)', 'execute') then 'Sesuai' else 'Periksa' end
union all
select '3. Fungsi bantu nilai tidak dapat dipanggil langsung',
       case when not has_function_privilege('authenticated', 'public._rekam_nilai_santri(uuid)', 'execute') then 'Sesuai' else 'Periksa' end;
