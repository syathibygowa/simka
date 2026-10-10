-- SIMKA PRO | supabase/migrations/20261010006300_laporan_kehadiran_santri.sql | v1.0 | Fase 8 – Tahap 3 Laporan kehadiran santri | 10/10/2026
-- =====================================================================
-- laporan_kehadiran_santri(mulai, selesai, cakupan, kelompok, jenjang, kegiatan, rinci)
--   Cakupan  : 'kelompok' (kelas, halaqah, kamar, atau ekskul tertentu), 'jenjang' ('wustha'/'sma'), 'semua',
--              'santri' (satu santri; kelompok = id santri).
--   Kegiatan : 'pokok' (gabungan kelas + halaqah + asrama), 'kelas', 'halaqah', 'asrama', 'ekskul' (dilaporkan terpisah).
--   Hak      : hanya santri yang terlihat oleh akun (santri_terlihat): pengasuh = santri asuhannya, Kepala Bidang
--              Wustha/SMA = jenjangnya, pimpinan lain/admin = semua. Kelompok di luar asuhan ditolak bagi pengasuh.
--   Hitungan : sesi wajib = sesi absensi yang sudah diisi pengampu selama santri menjadi anggota kelompok itu.
--              HISBAT: hadir murni = sesi tanpa pengecualian; Terlambat dan Bolos dihitung hadir (dilaporkan terpisah).
--              Kehadiran = (Hadir + Terlambat + Bolos) ÷ sesi wajib.
--   Pengisian: untuk pemantau, jumlah sesi terjadwal yang sudah lewat dan yang sudah diisi per kelompok (≤ 62 hari).
--   rinci    : baris per sesi per santri (rekap matriks dan laporan individu), paling banyak 80 santri.
-- Jalankan SETELAH migrasi 6200. Aman dijalankan ulang.
-- =====================================================================
create or replace function public.laporan_kehadiran_santri(p_mulai date, p_selesai date, p_cakupan text default 'kelompok',
    p_kelompok uuid default null, p_jenjang text default null, p_kegiatan text default 'pokok', p_rinci boolean default false)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare v_saya uuid := public.saya(); v_jenis text[]; v_santri uuid[]; v_ringkas jsonb; v_rinci jsonb := '[]'::jsonb; v_isi jsonb := '[]'::jsonb;
  v_pemantau boolean := public.is_admin() or public.boleh_pantau_absensi() or public.akses_luas('data_santri'); v_akhir date;
begin
  if v_saya is null then raise exception 'Akun Anda belum aktif.'; end if;
  if p_mulai is null or p_selesai is null or p_selesai < p_mulai then raise exception 'Rentang tanggal tidak sah.'; end if;
  if p_selesai - p_mulai > 185 then raise exception 'Rentang laporan paling lama 186 hari (satu semester).'; end if;
  if p_cakupan not in ('kelompok','jenjang','semua','santri') then raise exception 'Cakupan laporan tidak dikenal.'; end if;
  v_jenis := case p_kegiatan when 'pokok' then array['kelas','halaqah','asrama'] when 'kelas' then array['kelas'] when 'halaqah' then array['halaqah']
                             when 'asrama' then array['asrama'] when 'ekskul' then array['ekskul'] end;
  if v_jenis is null then raise exception 'Jenis kegiatan tidak dikenal.'; end if;
  if p_cakupan = 'kelompok' and not (v_pemantau or p_kelompok in (select public.kelompok_saya())) then
    raise exception 'Anda hanya dapat melihat kelompok yang Anda ampu.' using errcode = '42501';
  end if;
  v_akhir := least(p_selesai, public.hari_ini());

  -- Santri dalam cakupan (selalu dibatasi santri yang terlihat)
  select array_agg(s.id order by s.nama_lengkap) into v_santri from students s
   where s.id in (select public.santri_terlihat())
     and case p_cakupan
           when 'santri' then s.id = p_kelompok
           when 'kelompok' then exists (select 1 from group_members m where m.group_id = p_kelompok and m.student_id = s.id
                                          and m.mulai <= p_selesai and (m.selesai is null or m.selesai >= p_mulai))
           when 'jenjang' then s.jenjang = p_jenjang and s.status in ('aktif','nonaktif')
           else s.status in ('aktif','nonaktif') end;
  v_santri := coalesce(v_santri, '{}');
  if p_cakupan = 'santri' and cardinality(v_santri) = 0 then raise exception 'Anda tidak berwenang melihat kehadiran santri tersebut.' using errcode = '42501'; end if;
  if p_rinci and cardinality(v_santri) > 80 then raise exception 'Rincian paling banyak 80 santri. Pilih satu kelompok atau satu santri.'; end if;

  create temp table if not exists _ls (student_id uuid, session_id uuid, group_id uuid, jenis text, tanggal date, nama_sesi text, kode text, keterangan text) on commit drop;
  truncate _ls;
  insert into _ls
  select a.sid, sa.id, sa.group_id, sa.jenis, sa.tanggal, sa.nama_sesi, coalesce(e.kode, 'H'), e.keterangan
    from student_attendance_sessions sa
    cross join lateral (select x as sid from public._anggota_pada(sa.group_id, sa.tanggal) x) a
    left join student_attendance_exceptions e on e.session_id = sa.id and e.student_id = a.sid
   where sa.tanggal between p_mulai and p_selesai and sa.jenis = any(v_jenis) and a.sid = any(v_santri)
     and (p_cakupan <> 'kelompok' or p_kegiatan = 'pokok' or sa.group_id = p_kelompok);

  select coalesce(jsonb_agg(x order by x->>'nama'), '[]'::jsonb) into v_ringkas from (
    select jsonb_build_object('student_id', s.id, 'nama', s.nama_lengkap, 'nis', s.nis, 'jenis_kelamin', s.jenis_kelamin, 'jenjang', s.jenjang,
      'kelas', public._kelompok_santri(s.id, 'kelas'), 'kamar', public._kelompok_santri(s.id, 'kamar'), 'halaqah', public._kelompok_santri(s.id, 'halaqah'),
      'sesi', count(l.*), 'hadir', count(l.*) filter (where l.kode = 'H'), 'terlambat', count(l.*) filter (where l.kode = 'T'),
      'bolos', count(l.*) filter (where l.kode = 'B'), 'izin', count(l.*) filter (where l.kode = 'I'), 'sakit', count(l.*) filter (where l.kode = 'S'),
      'absen', count(l.*) filter (where l.kode = 'A'), 'total_hadir', count(l.*) filter (where l.kode in ('H','T','B')),
      'persen', case when count(l.*) = 0 then null else round(100.0 * count(l.*) filter (where l.kode in ('H','T','B')) / count(l.*), 1) end,
      'per_kegiatan', (select coalesce(jsonb_object_agg(j, jsonb_build_object('sesi', n, 'hadir', h)), '{}'::jsonb)
                         from (select l2.jenis j, count(*) n, count(*) filter (where l2.kode in ('H','T','B')) h from _ls l2 where l2.student_id = s.id group by l2.jenis) q2)) x
      from students s left join _ls l on l.student_id = s.id
     where s.id = any(v_santri)
     group by s.id) q;

  if p_rinci then
    select coalesce(jsonb_agg(jsonb_build_object('student_id', l.student_id, 'tanggal', l.tanggal, 'jenis', l.jenis, 'nama_sesi', l.nama_sesi,
             'kelompok', g.nama, 'kode', l.kode, 'keterangan', l.keterangan) order by l.student_id, l.tanggal, l.jenis, l.nama_sesi), '[]'::jsonb)
      into v_rinci from _ls l left join student_groups g on g.id = l.group_id;
  end if;

  -- Kepatuhan pengisian per kelompok (pemantau; rentang ≤ 62 hari)
  if v_pemantau and v_akhir >= p_mulai and v_akhir - p_mulai <= 61 and p_cakupan <> 'santri' then
    select coalesce(jsonb_agg(z order by z->>'jenis', z->>'nama'), '[]'::jsonb) into v_isi from (
      select jsonb_build_object('group_id', g.id, 'nama', g.nama, 'jenis', g.jenis,
        'pengampu', (select string_agg(e.nama_lengkap, ', ') from group_keepers k join employees e on e.id = k.employee_id
                      where k.group_id = g.id and coalesce(k.peran, 'utama') = 'utama' and (k.sampai is null or k.sampai >= public.hari_ini())),
        'rencana', (select count(*) from generate_series(p_mulai, v_akhir, interval '1 day') d cross join lateral public.sesi_kelompok(g.id, d::date) sk where sk.selesai <= now()),
        'terisi', (select count(*) from student_attendance_sessions sa where sa.group_id = g.id and sa.tanggal between p_mulai and v_akhir)) z
        from student_groups g join academic_years ay on ay.id = g.academic_year_id and ay.aktif
       where g.aktif and (case when g.jenis = 'kamar' then 'asrama' else g.jenis end) = any(v_jenis)
         and (case p_cakupan when 'kelompok' then g.id = p_kelompok
                             when 'jenjang' then exists (select 1 from group_members m join students s on s.id = m.student_id
                                                          where m.group_id = g.id and m.selesai is null and s.jenjang = p_jenjang)
                             else true end)) q;
  end if;

  return jsonb_build_object('santri', v_ringkas, 'rinci', v_rinci, 'pengisian', v_isi, 'mulai', p_mulai, 'selesai', p_selesai, 'kegiatan', p_kegiatan);
end $$;
revoke execute on function public.laporan_kehadiran_santri(date, date, text, uuid, text, text, boolean) from public, anon;
grant execute on function public.laporan_kehadiran_santri(date, date, text, uuid, text, text, boolean) to authenticated;

-- PEMERIKSAAN (hasil yang benar: "Sesuai")
select '1. Fungsi laporan kehadiran santri' as pemeriksaan,
       case when exists (select 1 from pg_proc where proname = 'laporan_kehadiran_santri') then 'Sesuai' else 'Periksa' end as hasil;
