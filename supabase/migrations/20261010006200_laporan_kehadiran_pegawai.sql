-- SIMKA PRO | supabase/migrations/20261010006200_laporan_kehadiran_pegawai.sql | v1.0 | Fase 8 – Tahap 2 Laporan kehadiran pegawai | 10/10/2026
-- =====================================================================
-- laporan_kehadiran_pegawai(mulai, selesai, cakupan, nilai, rinci)
--   Cakupan : 'saya' (diri sendiri), 'individu' (nilai = pegawai), 'fungsional' (nilai = jabatan fungsional),
--             'bidang' (nilai = bidang/unit beserta cabangnya), 'semua' (seluruh pegawai aktif).
--   Hak     : admin/superadmin semua pegawai; Kepala Bidang anggota bidangnya; Direktur, Wakil Direktur, Yayasan
--             seluruh pondok; pegawai lain hanya dirinya. Pegawai di luar hak tidak pernah ikut terhitung.
--   Hitungan: sesi wajib = sesi presensi tidak opsional yang tercatat + sesi terjadwal yang sudah lewat jendela
--             tutupnya tetapi tidak tercatat (sebelum penutupan otomatis aktif). Sesi tak tercatat dihitung
--             "Tanpa keterangan" dan ditandai sebagai tidak presensi.
--             Persentase = (Hadir + Terlambat + Dinas luar) ÷ sesi wajib. Izin, sakit, cuti mengurangi persentase
--             tetapi dicantumkan di keterangan sebagai ketidakhadiran berizin.
--   rinci   : true → juga mengembalikan baris per sesi (untuk rekap matriks dan laporan individu).
-- Batas: rentang paling lama 186 hari; rincian untuk lebih dari 40 pegawai paling lama 62 hari.
-- Jalankan SETELAH migrasi 6100. Aman dijalankan ulang.
-- =====================================================================
create or replace function public.laporan_kehadiran_pegawai(p_mulai date, p_selesai date, p_cakupan text default 'saya',
                                                            p_nilai uuid default null, p_rinci boolean default false)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare v_saya uuid := public.saya(); v_admin boolean := public.is_admin(); v_emps uuid[]; v_tutup_mulai date; v_akhir date;
  v_ringkas jsonb; v_rinci jsonb := '[]'::jsonb;
begin
  if v_saya is null then raise exception 'Akun Anda belum aktif.'; end if;
  if p_mulai is null or p_selesai is null or p_selesai < p_mulai then raise exception 'Rentang tanggal tidak sah.'; end if;
  if p_selesai - p_mulai > 185 then raise exception 'Rentang laporan paling lama 186 hari (satu semester).'; end if;
  if p_cakupan not in ('saya','individu','fungsional','bidang','semua') then raise exception 'Cakupan laporan tidak dikenal.'; end if;

  -- Pegawai yang boleh dilihat, lalu disaring menurut cakupan
  select array_agg(e.id order by e.nama_lengkap) into v_emps
    from employees e
   where e.status_akun = 'aktif' and e.status_keaktifan = 'aktif' and e.peran <> 'superadmin'
     and (v_admin or e.id = v_saya or public.pimpinan_dari(e.id))
     and case p_cakupan
           when 'saya' then e.id = v_saya
           when 'individu' then e.id = p_nilai
           when 'fungsional' then exists (select 1 from employee_functions f where f.employee_id = e.id and f.functional_position_id = p_nilai)
           when 'bidang' then e.org_unit_id in (select public.unit_turunan(p_nilai))
           else true end;
  v_emps := coalesce(v_emps, '{}');
  if p_cakupan = 'individu' and cardinality(v_emps) = 0 then raise exception 'Anda tidak berwenang melihat kehadiran pegawai tersebut.' using errcode = '42501'; end if;
  if p_rinci and cardinality(v_emps) > 40 and p_selesai - p_mulai > 61 then
    raise exception 'Rincian lebih dari 40 pegawai paling lama 62 hari. Persempit cakupan atau periode.';
  end if;

  v_tutup_mulai := nullif(public.pengaturan_presensi()->>'mulai_tanggal', '')::date;
  v_akhir := least(p_selesai, public.hari_ini());

  create temp table if not exists _lk (employee_id uuid, tanggal date, nama_pola text, nama_sesi text, mulai timestamptz, selesai timestamptz,
    status text, terlambat_menit int, datang_pada timestamptz, pulang_pada timestamptz, status_pulang text, cepat_pulang_menit int,
    titik text, keterangan text, tidak_presensi boolean) on commit drop;
  truncate _lk;

  -- Sesi tercatat
  insert into _lk
  select a.employee_id, a.tanggal, a.nama_pola, a.nama_sesi, a.jadwal_mulai, a.jadwal_selesai, a.status, a.terlambat_menit,
         a.datang_pada, a.pulang_pada, a.status_pulang, a.cepat_pulang_menit,
         (select ev.titik_nama from attendance_events ev where ev.id = a.datang_event_id), a.keterangan, false
    from attendances a
   where a.employee_id = any(v_emps) and a.tanggal between p_mulai and p_selesai and not a.opsional;

  -- Sesi terjadwal yang sudah lewat tetapi tidak tercatat (sebelum penutupan otomatis berlaku)
  if v_akhir >= p_mulai then
    insert into _lk
    select j.employee_id, j.tanggal, j.nama_pola, j.nama_sesi, j.mulai, j.selesai, 'tanpa_keterangan', 0, null, null, null, 0, null,
           'Tidak presensi', true
      from unnest(v_emps) e(id)
      cross join generate_series(p_mulai, v_akhir, interval '1 day') d
      cross join lateral public.jadwal_pegawai(e.id, d::date) j
     where not j.opsional and j.tutup < now()
       and (v_tutup_mulai is null or j.tanggal < v_tutup_mulai)
       and not exists (select 1 from attendances a where a.employee_id = j.employee_id and a.tanggal = j.tanggal and a.session_id = j.session_id);
  end if;

  select coalesce(jsonb_agg(x order by x->>'nama'), '[]'::jsonb) into v_ringkas from (
    select jsonb_build_object(
      'employee_id', e.id, 'nama', e.nama_lengkap, 'niy', e.niy, 'status_kepegawaian', e.status_kepegawaian, 'unit', u.nama,
      'jabatan', (select string_agg(fp.nama, ', ' order by fp.urutan) from employee_functions ef join functional_positions fp on fp.id = ef.functional_position_id where ef.employee_id = e.id),
      'sesi_wajib', count(k.*),
      'hadir', count(k.*) filter (where k.status = 'hadir'),
      'terlambat', count(k.*) filter (where k.status = 'terlambat'),
      'menit_terlambat', coalesce(sum(k.terlambat_menit) filter (where k.status = 'terlambat'), 0),
      'dinas_luar', count(k.*) filter (where k.status = 'dinas_luar'),
      'izin', count(k.*) filter (where k.status = 'izin'),
      'sakit', count(k.*) filter (where k.status = 'sakit'),
      'cuti', count(k.*) filter (where k.status = 'cuti'),
      'tanpa_keterangan', count(k.*) filter (where k.status = 'tanpa_keterangan'),
      'tidak_presensi', count(k.*) filter (where k.tidak_presensi),
      'menunggu', count(k.*) filter (where k.status = 'menunggu_verval'),
      'cepat_pulang', count(k.*) filter (where k.status_pulang = 'cepat'),
      'tidak_presensi_pulang', count(k.*) filter (where k.status_pulang = 'tidak_presensi'),
      'total_hadir', count(k.*) filter (where k.status in ('hadir','terlambat','dinas_luar')),
      'persen', case when count(k.*) = 0 then null
                     else round(100.0 * count(k.*) filter (where k.status in ('hadir','terlambat','dinas_luar')) / count(k.*), 1) end) x
      from employees e left join org_units u on u.id = e.org_unit_id
      left join _lk k on k.employee_id = e.id
     where e.id = any(v_emps)
     group by e.id, u.nama) q;

  if p_rinci then
    select coalesce(jsonb_agg(jsonb_build_object('employee_id', k.employee_id, 'tanggal', k.tanggal, 'nama_pola', k.nama_pola, 'nama_sesi', k.nama_sesi,
             'mulai', k.mulai, 'selesai', k.selesai, 'status', k.status, 'terlambat_menit', k.terlambat_menit, 'datang_pada', k.datang_pada,
             'pulang_pada', k.pulang_pada, 'status_pulang', k.status_pulang, 'cepat_pulang_menit', k.cepat_pulang_menit, 'titik', k.titik,
             'keterangan', k.keterangan, 'tidak_presensi', k.tidak_presensi) order by k.employee_id, k.tanggal, k.mulai), '[]'::jsonb)
      into v_rinci from _lk k;
  end if;

  return jsonb_build_object('pegawai', v_ringkas, 'rinci', v_rinci, 'mulai', p_mulai, 'selesai', p_selesai,
    'penutupan_mulai', v_tutup_mulai, 'dihitung_sampai', v_akhir);
end $$;
revoke execute on function public.laporan_kehadiran_pegawai(date, date, text, uuid, boolean) from public, anon;
grant execute on function public.laporan_kehadiran_pegawai(date, date, text, uuid, boolean) to authenticated;

-- PEMERIKSAAN (hasil yang benar: "Sesuai")
select '1. Fungsi laporan kehadiran pegawai' as pemeriksaan,
       case when exists (select 1 from pg_proc where proname = 'laporan_kehadiran_pegawai') then 'Sesuai' else 'Periksa' end as hasil;
