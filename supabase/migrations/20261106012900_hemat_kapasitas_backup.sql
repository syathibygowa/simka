-- SIMKA PRO | supabase/migrations/20261106012900_hemat_kapasitas_backup.sql | v1.0 | 14.12.0: hemat log server, perawatan harian, pemantau kapasitas, lembar ringkas backup mingguan | 18/10/2026
-- =====================================================================
-- SIMKA PRO · Migrasi 129: Hemat log dan kapasitas database
--   1. Jadwal otomatis digabung: enam tugas berkala (pengingat presensi, security, agenda, klinik, penyapu notifikasi HP,
--      penutupan sesi presensi) yang sebelumnya berjalan ±1.800 kali sehari kini satu tugas "tugas-berkala" tiap 5 menit
--      (288 kali sehari). Klinik tetap tiap 10 menit dan penutupan sesi tiap 15 menit. Setiap jalan tercatat di log server,
--      jadi penggabungan ini mengurangi kiriman log ("Logs Ingest").
--   2. Perawatan harian 02.00 WITA (satu tugas "rawat-database") menggantikan tiga tugas lama:
--      * riwayat jalan jadwal otomatis (cron.job_run_details) disimpan 7 hari — sebelumnya tidak pernah dibersihkan
--        dan bertambah ±600 ribu baris (±100 MB) per tahun;
--      * audit log disimpan N bulan (bawaan 3, dapat diatur 1–24);
--      * notifikasi yang sudah dibaca disimpan N bulan (bawaan 6, dapat diatur 1–24);
--      * rincian presensi (titik GPS, perangkat) boleh dibatasi N bulan (bawaan: disimpan selamanya; rekap kehadiran tetap utuh);
--      * token reset sandi kedaluwarsa dihapus; heartbeat internal; ukuran database dicatat harian untuk perkiraan.
--   3. Pemantau kapasitas (Setelan → Kapasitas, khusus superadmin): ukuran database dibanding batas paket, tabel terbesar,
--      laju pertambahan per bulan, perkiraan bulan sampai batas, pengaturan retensi, tombol "Rawat sekarang".
--   4. Lembar ringkas untuk backup mingguan Google Sheets (fungsi lembar_backup, hanya untuk kunci server GAS): data santri,
--      pegawai, kelompok dan anggotanya, posisi hafalan, nilai akhir TA aktif, pelanggaran TA aktif, tunggakan, serta kegiatan
--      sepekan (presensi pegawai, absensi santri, santri tidak hadir, setoran, jurnal mengajar, klinik, izin, gerbang, tamu,
--      kunjungan) — dengan nama, bukan kode, sehingga mudah dibaca langsung.
-- Jalankan SETELAH migrasi 12800. Aman dijalankan ulang.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. PENGATURAN DAN RIWAYAT UKURAN
-- ---------------------------------------------------------------------
insert into public.institution_settings (kunci, nilai) values ('retensi', jsonb_build_object(
  'audit_bulan', 3, 'notifikasi_bulan', 6, 'rincian_presensi_bulan', null, 'batas_mb', 500))
on conflict (kunci) do nothing;

create table if not exists public.db_ukuran_harian (
  tanggal date primary key,
  bytes   bigint not null,
  dicatat timestamptz not null default now()
);
alter table public.db_ukuran_harian enable row level security;   -- dibaca lewat fungsi

-- ---------------------------------------------------------------------
-- 2. TUGAS BERKALA (gabungan) DAN PERAWATAN HARIAN
-- ---------------------------------------------------------------------
/** Satu tugas tiap 5 menit. Galat pada satu bagian tidak menghentikan bagian lain. */
create or replace function public.tugas_berkala()
returns void language plpgsql security definer set search_path = public as $$
declare v_menit int := extract(minute from now())::int;
begin
  begin perform public.kirim_pengingat_presensi(); exception when others then raise warning 'tugas_berkala presensi: %', sqlerrm; end;
  begin perform public.security_pengingat(); exception when others then raise warning 'tugas_berkala security: %', sqlerrm; end;
  begin perform public.kirim_pengingat_agenda(); exception when others then raise warning 'tugas_berkala agenda: %', sqlerrm; end;
  begin perform public.sapu_antrian_dorong(); exception when others then raise warning 'tugas_berkala dorong: %', sqlerrm; end;
  if v_menit % 10 < 5 then
    begin perform public.klinik_pengingat(); exception when others then raise warning 'tugas_berkala klinik: %', sqlerrm; end;
  end if;
  if v_menit % 15 < 5 then
    begin perform public.tutup_sesi_presensi(); exception when others then raise warning 'tugas_berkala tutup sesi: %', sqlerrm; end;
  end if;
end $$;

/** Perawatan harian; mengembalikan jumlah baris yang dibersihkan. Dipanggil jadwal 02.00 WITA atau tombol "Rawat sekarang". */
create or replace function public.rawat_database()
returns jsonb language plpgsql security definer set search_path = public as $$
declare r jsonb := coalesce((select nilai from institution_settings where kunci = 'retensi'), '{}'::jsonb);
  v_audit int := greatest(1, least(24, coalesce((r->>'audit_bulan')::int, 3)));
  v_notif int := greatest(1, least(24, coalesce((r->>'notifikasi_bulan')::int, 6)));
  v_rinci int := nullif(r->>'rincian_presensi_bulan', '')::int;
  n_cron bigint := 0; n_audit bigint := 0; n_notif bigint := 0; n_rinci bigint := 0; n_token bigint := 0;
begin
  if auth.uid() is not null and not public.is_superadmin() then
    raise exception 'Perawatan database hanya untuk superadmin.' using errcode = '42501'; end if;
  begin
    delete from cron.job_run_details where end_time < now() - interval '7 days'; get diagnostics n_cron = row_count;
  exception when others then n_cron := -1; end;
  delete from audit_logs where created_at < now() - make_interval(months => v_audit); get diagnostics n_audit = row_count;
  delete from notifications where dibaca_pada is not null and created_at < now() - make_interval(months => v_notif); get diagnostics n_notif = row_count;
  delete from password_reset_tokens where kedaluwarsa < now() - interval '1 day'; get diagnostics n_token = row_count;
  if v_rinci is not null and v_rinci >= 6 then
    delete from attendance_events where tanggal < (public.hari_ini() - make_interval(months => v_rinci))::date; get diagnostics n_rinci = row_count;
  end if;
  insert into heartbeat (sumber, catatan) values ('pg_cron', 'perawatan harian');
  insert into db_ukuran_harian (tanggal, bytes) values (public.hari_ini(), pg_database_size(current_database()))
  on conflict (tanggal) do update set bytes = excluded.bytes, dicatat = now();
  return jsonb_build_object('riwayat_cron', n_cron, 'audit', n_audit, 'notifikasi', n_notif, 'rincian_presensi', n_rinci, 'token', n_token);
end $$;

-- Ganti jadwal lama (aman bila sebagian tidak ada)
select cron.unschedule(jobname) from cron.job
 where jobname in ('pengingat-presensi','pengingat-security','pengingat-agenda','pengingat-klinik','sapu-antrian-dorong','tutup-sesi-presensi',
                   'hapus-audit-3-bulan','bersihkan-token-notifikasi','heartbeat-internal');
select cron.schedule('tugas-berkala', '*/5 * * * *', $$ select public.tugas_berkala() $$);
select cron.schedule('rawat-database', '0 18 * * *', $$ select public.rawat_database() $$);   -- 18.00 UTC = 02.00 WITA

-- Bersihkan riwayat jadwal yang sudah menumpuk dan catat ukuran hari ini
select public.rawat_database();

-- ---------------------------------------------------------------------
-- 3. PEMANTAU KAPASITAS (superadmin)
-- ---------------------------------------------------------------------
create or replace function public.kapasitas_database()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_ukuran bigint := pg_database_size(current_database()); v_awal record; v_laju numeric; r jsonb;
  v_batas bigint;
begin
  if not public.is_superadmin() then raise exception 'Kapasitas database hanya dapat dilihat superadmin.' using errcode = '42501'; end if;
  r := coalesce((select nilai from institution_settings where kunci = 'retensi'), '{}'::jsonb);
  v_batas := coalesce((r->>'batas_mb')::bigint, 500) * 1024 * 1024;
  -- Laju: dari catatan paling lama dalam 180 hari terakhir (minimal 14 hari jarak) ke ukuran sekarang
  select tanggal, bytes into v_awal from db_ukuran_harian where tanggal >= public.hari_ini() - 180 order by tanggal limit 1;
  if v_awal.tanggal is not null and public.hari_ini() - v_awal.tanggal >= 14 then
    v_laju := greatest(0, (v_ukuran - v_awal.bytes)::numeric / (public.hari_ini() - v_awal.tanggal) * 30);
  end if;
  return jsonb_build_object(
    'ukuran', v_ukuran, 'batas', v_batas, 'persen', round(v_ukuran::numeric / v_batas * 100, 1),
    'laju_bulan', v_laju, 'bulan_tersisa', case when v_laju > 0 then floor((v_batas - v_ukuran) / v_laju) end,
    'sejak', v_awal.tanggal, 'retensi', r,
    'tabel', (select coalesce(jsonb_agg(x order by (x->>'bytes')::bigint desc), '[]'::jsonb) from (
        select jsonb_build_object('tabel', n.nspname || '.' || c.relname, 'bytes', pg_total_relation_size(c.oid), 'baris', greatest(c.reltuples, 0)::bigint) x
          from pg_class c join pg_namespace n on n.oid = c.relnamespace
         where c.relkind = 'r' and n.nspname in ('public','cron','auth','storage')
         order by pg_total_relation_size(c.oid) desc limit 15) q),
    'riwayat', (select coalesce(jsonb_agg(jsonb_build_object('tanggal', tanggal, 'bytes', bytes) order by tanggal), '[]'::jsonb)
                  from (select * from db_ukuran_harian where tanggal >= public.hari_ini() - 400) d),
    'jadwal', (select coalesce(jsonb_agg(jsonb_build_object('nama', jobname, 'jadwal', schedule) order by jobname), '[]'::jsonb) from cron.job));
end $$;

create or replace function public.simpan_retensi(p jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare v_a int := (p->>'audit_bulan')::int; v_n int := (p->>'notifikasi_bulan')::int; v_r int := nullif(p->>'rincian_presensi_bulan', '')::int;
  v_b int := coalesce((p->>'batas_mb')::int, 500);
begin
  if not public.is_superadmin() then raise exception 'Retensi data hanya dapat diatur superadmin.' using errcode = '42501'; end if;
  if v_a is null or v_a not between 1 and 24 then raise exception 'Masa simpan audit log 1 sampai 24 bulan.'; end if;
  if v_n is null or v_n not between 1 and 24 then raise exception 'Masa simpan notifikasi 1 sampai 24 bulan.'; end if;
  if v_r is not null and v_r not between 6 and 120 then raise exception 'Masa simpan rincian presensi 6 sampai 120 bulan, atau kosong (selamanya).'; end if;
  if v_b not between 100 and 1000000 then raise exception 'Batas kapasitas tidak wajar.'; end if;
  insert into institution_settings (kunci, nilai) values ('retensi', jsonb_build_object('audit_bulan', v_a, 'notifikasi_bulan', v_n, 'rincian_presensi_bulan', v_r, 'batas_mb', v_b))
  on conflict (kunci) do update set nilai = excluded.nilai;
end $$;

do $$ declare f text; begin
  foreach f in array array['kapasitas_database()','simpan_retensi(jsonb)','rawat_database()'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  execute 'revoke execute on function public.tugas_berkala() from public, anon, authenticated';
end $$;

-- ---------------------------------------------------------------------
-- 4. LEMBAR RINGKAS BACKUP MINGGUAN (dipanggil GAS dengan kunci service_role)
-- ---------------------------------------------------------------------
create or replace function public._posisi_teks(p_hal int)
returns text language sql immutable as $$
  select case when coalesce(p_hal, 0) = 0 then '0'
              when p_hal % 20 = 0 then (p_hal / 20) || ' juz'
              when p_hal < 20 then p_hal || ' hal'
              else (p_hal / 20) || ' juz ' || (p_hal % 20) || ' hal' end
$$;

/** Daftar lembar yang tersedia: [kode, judul, keterangan]. */
create or replace function public.daftar_lembar_backup()
returns json language sql stable security definer set search_path = public as $$
  select json_agg(json_build_object('kode', k, 'judul', j, 'ket', t) order by o) from (values
    (1, 'santri', 'Santri', 'Seluruh santri: identitas, kelompok aktif, status, orang tua/wali'),
    (2, 'pegawai', 'Pegawai', 'Seluruh pegawai: unit, jabatan, status'),
    (3, 'kelompok', 'Kelompok', 'Kelas, halaqah, kamar, ekskul tahun ajaran aktif beserta pengasuh'),
    (4, 'anggota', 'Anggota kelompok', 'Santri per kelompok (keanggotaan berjalan)'),
    (5, 'hafalan', 'Posisi hafalan', 'Posisi sabaq/sabqi/manzil, juz resmi, tahsin'),
    (6, 'presensi', 'Presensi pegawai', 'Presensi pegawai pada periode'),
    (7, 'absensi', 'Absensi santri', 'Sesi absensi santri pada periode (rekap per sesi)'),
    (8, 'tidak_hadir', 'Santri tidak hadir', 'Santri izin/sakit/bolos/absen/terlambat pada periode'),
    (9, 'setoran', 'Setoran hafalan', 'Setoran hafalan per santri pada periode'),
    (10, 'jurnal_mengajar', 'Jurnal mengajar', 'Jurnal mengajar guru pada periode'),
    (11, 'nilai', 'Nilai akhir', 'Nilai akhir mata pelajaran tahun ajaran aktif'),
    (12, 'pelanggaran', 'Pelanggaran', 'Pelanggaran santri tahun ajaran aktif'),
    (13, 'klinik', 'Klinik', 'Kasus klinik pada periode dan yang masih berjalan'),
    (14, 'izin', 'Izin santri', 'Perizinan santri pada periode dan yang belum kembali'),
    (15, 'gerbang', 'Gerbang', 'Keluar-masuk gerbang pada periode'),
    (16, 'tamu', 'Tamu', 'Buku tamu pada periode'),
    (17, 'kunjungan', 'Kunjungan orang tua', 'Kunjungan orang tua pada periode'),
    (18, 'tunggakan', 'Tunggakan', 'Tagihan santri yang belum lunas')) v(o, k, j, t)
$$;

create or replace function public.lembar_backup(p_jenis text, p_mulai date default null, p_selesai date default null)
returns json language plpgsql stable security definer set search_path = public as $$
declare v_m date := coalesce(p_mulai, public.hari_ini() - 7); v_s date := coalesce(p_selesai, public.hari_ini() - 1);
  v_ta academic_years; v json;
  -- Waktu ditulis dd/mm/yyyy hh:mm WITA
begin
  select * into v_ta from academic_years where aktif limit 1;
  case p_jenis
  when 'santri' then
    select json_agg(json_build_object('NIS', s.nis, 'NISN', s.nisn, 'Nama', s.nama_lengkap, 'JK', s.jenis_kelamin, 'Jenjang', upper(s.jenjang), 'Tingkat', s.tingkat,
        'Kelas', public._kelompok_santri(s.id, 'kelas'), 'Halaqah', public._kelompok_santri(s.id, 'halaqah'), 'Kamar', public._kelompok_santri(s.id, 'kamar'),
        'Status', s.status, 'Tempat lahir', s.tempat_lahir, 'Tanggal lahir', to_char(s.tanggal_lahir, 'DD/MM/YYYY'), 'Tanggal masuk', to_char(s.tanggal_masuk, 'DD/MM/YYYY'),
        'Jalur masuk', s.jalur_masuk, 'Orang tua/wali', c.nama, 'Hubungan', c.hubungan, 'HP wali', c.no_hp, 'Alamat', s.alamat)
        order by array_position(array['aktif','nonaktif','mutasi_keluar','lulus','berhenti'], s.status), s.nama_lengkap) into v
      from students s left join lateral (select x.nama, x.hubungan, x.no_hp from student_contacts x where x.student_id = s.id
                                          order by x.utama desc, array_position(array['ayah','ibu','wali'], x.hubungan) limit 1) c on true;
  when 'pegawai' then
    select json_agg(json_build_object('NIY', e.niy, 'Nama', e.nama_lengkap, 'JK', e.jenis_kelamin, 'Unit', o.nama,
        'Jabatan struktural', (select string_agg(sp.nama || coalesce(' ' || ou.nama, ''), '; ') from employee_structurals es join structural_positions sp on sp.id = es.structural_position_id
                                 left join org_units ou on ou.id = es.org_unit_id where es.employee_id = e.id),
        'Tugas fungsional', (select string_agg(fp.nama, ', ' order by fp.urutan) from employee_functions ef join functional_positions fp on fp.id = ef.functional_position_id where ef.employee_id = e.id),
        'Status kepegawaian', e.status_kepegawaian, 'TMT', to_char(e.tmt_tugas, 'DD/MM/YYYY'), 'Pendidikan', e.pendidikan_terakhir, 'HP', e.no_hp, 'Email', e.email,
        'Keaktifan', e.status_keaktifan, 'Akun', e.status_akun) order by e.status_keaktifan <> 'aktif', e.nama_lengkap) into v
      from employees e left join org_units o on o.id = e.org_unit_id;
  when 'kelompok' then
    select json_agg(json_build_object('Jenis', g.jenis, 'Kelompok', g.nama, 'Jenjang', upper(g.jenjang), 'Tingkat', g.tingkat, 'JK', g.jenis_kelamin,
        'Pengasuh', (select string_agg(e.nama_lengkap || ' (' || k.peran || ')', ', ') from group_keepers k join employees e on e.id = k.employee_id
                      where k.group_id = g.id and (k.sampai is null or k.sampai >= public.hari_ini())),
        'Anggota', (select count(*) from group_members m join students s on s.id = m.student_id and s.status = 'aktif' where m.group_id = g.id and m.selesai is null))
        order by g.jenis, g.urutan, g.nama) into v
      from student_groups g where g.academic_year_id = v_ta.id and g.aktif;
  when 'anggota' then
    select json_agg(json_build_object('Jenis', g.jenis, 'Kelompok', g.nama, 'NIS', s.nis, 'Nama', s.nama_lengkap, 'JK', s.jenis_kelamin, 'Mulai', to_char(m.mulai, 'DD/MM/YYYY'))
        order by g.jenis, g.nama, s.nama_lengkap) into v
      from group_members m join student_groups g on g.id = m.group_id and g.academic_year_id = v_ta.id
      join students s on s.id = m.student_id and s.status = 'aktif' where m.selesai is null;
  when 'hafalan' then
    select json_agg(json_build_object('NIS', s.nis, 'Nama', s.nama_lengkap, 'JK', s.jenis_kelamin, 'Kelas', public._kelompok_santri(s.id, 'kelas'),
        'Halaqah', public._kelompok_santri(s.id, 'halaqah'), 'Program', coalesce(t.program, 'reguler'),
        'Sabaq', public._posisi_teks(t.sabaq_hal), 'Sabqi', public._posisi_teks(t.sabqi_hal), 'Manzil', public._posisi_teks(t.manzil_hal),
        'Juz resmi', (select count(*) from juz_achievements j where j.student_id = s.id),
        'Daftar juz', (select string_agg(j.juz::text, ', ' order by j.juz) from juz_achievements j where j.student_id = s.id),
        'Tahsin', (select 'Tahap ' || ts.tahap from tahsin_santri ts where ts.student_id = s.id and ts.status = 'berjalan'),
        'Posisi per', to_char(t.posisi_pada at time zone 'Asia/Makassar', 'DD/MM/YYYY')) order by public._kelompok_santri(s.id, 'halaqah') nulls last, s.nama_lengkap) into v
      from students s left join student_tahfizh t on t.student_id = s.id where s.status = 'aktif';
  when 'presensi' then
    select json_agg(json_build_object('Tanggal', to_char(a.tanggal, 'DD/MM/YYYY'), 'NIY', e.niy, 'Nama', e.nama_lengkap, 'Sesi', a.nama_sesi, 'Status', a.status,
        'Datang', to_char(a.datang_pada at time zone 'Asia/Makassar', 'HH24:MI'), 'Terlambat (menit)', a.terlambat_menit,
        'Pulang', to_char(a.pulang_pada at time zone 'Asia/Makassar', 'HH24:MI'), 'Status pulang', a.status_pulang, 'Sumber', a.sumber, 'Keterangan', a.keterangan)
        order by a.tanggal, e.nama_lengkap, a.jadwal_mulai) into v
      from attendances a join employees e on e.id = a.employee_id where a.tanggal between v_m and v_s;
  when 'absensi' then
    select json_agg(json_build_object('Tanggal', to_char(x.tanggal, 'DD/MM/YYYY'), 'Jenis', x.jenis, 'Kelompok', g.nama, 'Sesi', x.nama_sesi,
        'Jam', to_char(x.jam_mulai, 'HH24:MI'), 'Pengampu', e.nama_lengkap, 'Anggota', x.jumlah_anggota, 'Hadir', x.jumlah_hadir, 'Izin', x.jumlah_izin,
        'Sakit', x.jumlah_sakit, 'Bolos', x.jumlah_bolos, 'Absen', x.jumlah_absen, 'Terlambat', x.jumlah_terlambat, 'Catatan', x.catatan)
        order by x.tanggal, x.jam_mulai, g.nama) into v
      from student_attendance_sessions x join student_groups g on g.id = x.group_id left join employees e on e.id = x.pengampu_id
     where x.tanggal between v_m and v_s;
  when 'tidak_hadir' then
    select json_agg(json_build_object('Tanggal', to_char(x.tanggal, 'DD/MM/YYYY'), 'Sesi', x.nama_sesi, 'Kelompok', g.nama, 'NIS', s.nis, 'Nama', s.nama_lengkap,
        'Kode', case k.kode when 'I' then 'Izin' when 'S' then 'Sakit' when 'B' then 'Bolos' when 'A' then 'Absen' when 'T' then 'Terlambat' else k.kode end,
        'Keterangan', k.keterangan) order by x.tanggal, x.jam_mulai, g.nama, s.nama_lengkap) into v
      from student_attendance_exceptions k join student_attendance_sessions x on x.id = k.session_id
      join student_groups g on g.id = x.group_id join students s on s.id = k.student_id
     where x.tanggal between v_m and v_s;
  when 'setoran' then
    select json_agg(json_build_object('Tanggal', to_char(l.tanggal, 'DD/MM/YYYY'), 'Halaqah', g.nama, 'Sesi', ms.nama_sesi, 'NIS', s.nis, 'Nama', s.nama_lengkap,
        'Sabaq', public._posisi_teks(l.sabaq_hal), 'Sabqi', public._posisi_teks(l.sabqi_hal), 'Manzil', public._posisi_teks(l.manzil_hal),
        'Tambah (hal)', l.tambah_hal, 'Juz sedang', l.juz_sedang, 'Catatan', l.catatan) order by l.tanggal, g.nama, ms.jam_mulai, s.nama_lengkap) into v
      from memorization_logs l join memorization_sessions ms on ms.id = l.session_id join student_groups g on g.id = ms.group_id
      join students s on s.id = l.student_id where l.tanggal between v_m and v_s;
  when 'jurnal_mengajar' then
    select json_agg(json_build_object('Tanggal', to_char(j.tanggal, 'DD/MM/YYYY'), 'Jam', lp.nama, 'Guru', coalesce(ep.nama_lengkap, e.nama_lengkap),
        'Keterangan guru', case when j.pengganti_id is not null then 'Pengganti dari ' || e.nama_lengkap end, 'Kelas', g.nama, 'Mapel', sb.nama,
        'Status', j.status, 'Materi', coalesce(j.materi, j.bab), 'Hadir', j.jumlah_hadir, 'Anggota', j.jumlah_anggota) order by j.tanggal, lp.urutan, g.nama) into v
      from teaching_journals j join teaching_assignments ta on ta.id = j.assignment_id join student_groups g on g.id = ta.group_id
      join subjects sb on sb.id = ta.subject_id left join employees e on e.id = ta.employee_id left join employees ep on ep.id = j.pengganti_id
      left join lesson_periods lp on lp.id = j.period_id where j.tanggal between v_m and v_s;
  when 'nilai' then
    select json_agg(json_build_object('Kelas', g.nama, 'Mapel', sb.nama, 'Guru', e.nama_lengkap, 'Semester', f.semester, 'NIS', s.nis, 'Nama', s.nama_lengkap,
        'Nilai', coalesce(f.koreksi, f.nilai), 'Keterampilan', f.keterampilan) order by g.nama, sb.urutan, sb.nama, f.semester, s.nama_lengkap) into v
      from grade_finals f join teaching_assignments ta on ta.id = f.assignment_id and ta.academic_year_id = v_ta.id
      join student_groups g on g.id = ta.group_id join subjects sb on sb.id = ta.subject_id left join employees e on e.id = ta.employee_id
      join students s on s.id = f.student_id;
  when 'pelanggaran' then
    select json_agg(json_build_object('Tanggal', to_char(p.tanggal, 'DD/MM/YYYY'), 'NIS', s.nis, 'Nama', s.nama_lengkap, 'Kelas', public._kelompok_santri(s.id, 'kelas'),
        'Kategori', p.kategori, 'Tingkat', p.tingkat, 'Tempat', p.tempat, 'Uraian', p.uraian, 'Tindakan', p.tindakan,
        'Dicatat oleh', (select nama_lengkap from employees where id = p.dicatat_oleh)) order by p.tanggal, s.nama_lengkap) into v
      from student_violations p join students s on s.id = p.student_id where p.tanggal >= coalesce(v_ta.mulai, v_m);
  when 'klinik' then
    select json_agg(json_build_object('Dibuka', to_char(c.dibuka_pada at time zone 'Asia/Makassar', 'DD/MM/YYYY HH24:MI'), 'NIS', s.nis, 'Nama', s.nama_lengkap,
        'Kelas', public._kelompok_santri(s.id, 'kelas'), 'Kamar', public._kelompok_santri(s.id, 'kamar'), 'Klinik', c.klinik, 'Keluhan', c.keluhan,
        'Tindak lanjut', c.tindak_lanjut, 'Status', c.status, 'Selesai', to_char(c.selesai_pada at time zone 'Asia/Makassar', 'DD/MM/YYYY HH24:MI'), 'Hasil', c.hasil)
        order by c.dibuka_pada) into v
      from clinic_cases c join students s on s.id = c.student_id
     where c.status <> 'batal' and ((c.dibuka_pada at time zone 'Asia/Makassar')::date between v_m and v_s or c.selesai_pada is null);
  when 'izin' then
    select json_agg(json_build_object('Keluar', to_char(coalesce(p.keluar_aktual, p.keluar_pada) at time zone 'Asia/Makassar', 'DD/MM/YYYY HH24:MI'), 'NIS', s.nis, 'Nama', s.nama_lengkap,
        'Kelas', public._kelompok_santri(s.id, 'kelas'), 'Jenis', p.jenis, 'Alasan', p.alasan, 'Penjemput', p.penjemput, 'Hubungan', p.hubungan_penjemput,
        'Batas kembali', to_char(p.kembali_batas at time zone 'Asia/Makassar', 'DD/MM/YYYY HH24:MI'), 'Status', p.status,
        'Kembali', to_char(p.kembali_pada at time zone 'Asia/Makassar', 'DD/MM/YYYY HH24:MI')) order by p.keluar_pada) into v
      from student_permits p join students s on s.id = p.student_id
     where p.status not in ('dibatalkan') and ((p.keluar_pada at time zone 'Asia/Makassar')::date between v_m and v_s or p.status = 'keluar');
  when 'gerbang' then
    select json_agg(json_build_object('Waktu', to_char(x.waktu at time zone 'Asia/Makassar', 'DD/MM/YYYY HH24:MI'), 'Jenis', x.jenis, 'NIS', s.nis, 'Nama', s.nama_lengkap,
        'Penjemput', x.penjemput, 'Terlambat (menit)', x.terlambat_menit, 'Petugas', (select nama_lengkap from employees where id = x.petugas_id), 'Catatan', x.catatan)
        order by x.waktu) into v
      from gate_logs x join students s on s.id = x.student_id where (x.waktu at time zone 'Asia/Makassar')::date between v_m and v_s;
  when 'tamu' then
    select json_agg(json_build_object('Masuk', to_char(x.masuk_pada at time zone 'Asia/Makassar', 'DD/MM/YYYY HH24:MI'), 'Nama', x.nama, 'Instansi', x.instansi, 'HP', x.hp,
        'Keperluan', x.keperluan, 'Ditemui', coalesce((select nama_lengkap from employees where id = x.ditemui_id), x.ditemui_teks), 'Jumlah orang', x.jumlah_orang,
        'Keluar', to_char(x.keluar_pada at time zone 'Asia/Makassar', 'DD/MM/YYYY HH24:MI')) order by x.masuk_pada) into v
      from guest_logs x where (x.masuk_pada at time zone 'Asia/Makassar')::date between v_m and v_s;
  when 'kunjungan' then
    select json_agg(json_build_object('Datang', to_char(x.datang_pada at time zone 'Asia/Makassar', 'DD/MM/YYYY HH24:MI'), 'NIS', s.nis, 'Santri', s.nama_lengkap,
        'Pengunjung', x.pengunjung, 'Hubungan', x.hubungan, 'HP', x.hp, 'Jumlah orang', x.jumlah_orang, 'Luar jadwal', case when x.luar_jadwal then 'Ya' else '' end,
        'Pulang', to_char(x.pulang_pada at time zone 'Asia/Makassar', 'DD/MM/YYYY HH24:MI')) order by x.datang_pada) into v
      from parent_visits x join students s on s.id = x.student_id where (x.datang_pada at time zone 'Asia/Makassar')::date between v_m and v_s;
  when 'tunggakan' then
    select json_agg(json_build_object('NIS', s.nis, 'Nama', s.nama_lengkap, 'Kelas', public._kelompok_santri(s.id, 'kelas'), 'Tagihan', b.nama,
        'Jatuh tempo', to_char(b.jatuh_tempo, 'DD/MM/YYYY'), 'Nominal', b.nominal, 'Dibayar', b.dibayar, 'Sisa', b.nominal - b.dibayar, 'Status', b.status)
        order by s.nama_lengkap, b.jatuh_tempo) into v
      from bills b join students s on s.id = b.student_id where b.status in ('belum','sebagian');
  else raise exception 'Jenis lembar tidak dikenal: %', p_jenis;
  end case;
  return coalesce(v, '[]'::json);
end $$;

revoke execute on function public.lembar_backup(text,date,date) from public, anon, authenticated;
revoke execute on function public.daftar_lembar_backup() from public, anon, authenticated;
grant execute on function public.lembar_backup(text,date,date) to service_role;
grant execute on function public.daftar_lembar_backup() to service_role;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN — hasil yang benar: 4 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select '1. Jadwal otomatis digabung (tugas-berkala, rawat-database)' as pemeriksaan,
       case when (select count(*) from cron.job where jobname in ('tugas-berkala','rawat-database')) = 2
             and not exists (select 1 from cron.job where jobname in ('pengingat-presensi','pengingat-security','pengingat-agenda','pengingat-klinik',
                               'sapu-antrian-dorong','tutup-sesi-presensi','hapus-audit-3-bulan','bersihkan-token-notifikasi','heartbeat-internal'))
            then 'Sesuai' else 'Periksa' end as hasil
union all
select '2. Riwayat jadwal otomatis ≤ 7 hari',
       case when not exists (select 1 from cron.job_run_details where end_time < now() - interval '8 days') then 'Sesuai' else 'Periksa' end
union all
select '3. Ukuran database tercatat hari ini',
       case when exists (select 1 from public.db_ukuran_harian where tanggal = public.hari_ini()) then 'Sesuai' else 'Periksa' end
union all
select '4. Lembar ringkas backup mingguan (18 lembar)',
       case when json_array_length(public.daftar_lembar_backup()) = 18
             and json_typeof(public.lembar_backup('santri')) = 'array' and json_typeof(public.lembar_backup('setoran')) = 'array' then 'Sesuai' else 'Periksa' end;
