-- SIMKA PRO | supabase/migrations/20261010006400_laporan_layanan.sql | v1.0 | Fase 8 – Tahap 4 Laporan modul lain (Security, libur, pengajuan, klinik) | 10/10/2026
-- =====================================================================
-- Fungsi laporan periode untuk menu Dokumen → tab Rekap layanan. Semua mengembalikan satu objek JSON.
--   laporan_security(mulai, selesai)          : gerbang (keluar, kembali, terlambat, ditolak), titipan, tamu, kunjungan;
--                                               ringkasan, per hari, daftar terlambat/ditolak/titipan belum diambil.
--                                               Hak: boleh_lihat_security().
--   laporan_libur(mulai, selesai)             : periode libur yang pulangnya dalam rentang: peserta, boleh/tidak,
--                                               sudah pulang, kembali tepat/terlambat, belum kembali. Hak: boleh_lihat_libur().
--   laporan_pengajuan(mulai, selesai, unit)   : pengajuan izin/sakit/cuti/dinas luar per pegawai (jumlah dan hari dalam
--                                               rentang). Hak: admin ber-izin lihat_pengajuan semua; Kepala Bidang ke atas
--                                               anggotanya; pegawai lain dirinya.
--   laporan_klinik(mulai, selesai)            : kasus, pemeriksaan, kontrol, tindak lanjut, sembuh, surat sakit, per hari
--                                               dan per klinik; daftar kasus TANPA diagnosis. Hak: pengelola klinik,
--                                               pimpinan Kesantrian, petugas klinik (hanya kliniknya).
-- Urutan kolom daftar santri: NIS, Nama, JK. Rentang paling lama 186 hari.
-- Jalankan SETELAH migrasi 6300. Aman dijalankan ulang.
-- =====================================================================

create or replace function public._cek_rentang(p_mulai date, p_selesai date)
returns void language plpgsql immutable as $$
begin
  if p_mulai is null or p_selesai is null or p_selesai < p_mulai then raise exception 'Rentang tanggal tidak sah.'; end if;
  if p_selesai - p_mulai > 185 then raise exception 'Rentang laporan paling lama 186 hari (satu semester).'; end if;
end $$;

-- Identitas santri ringkas untuk daftar laporan
create or replace function public._santri_ringkas(p_id uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('nis', s.nis, 'nama', s.nama_lengkap, 'jk', s.jenis_kelamin,
           'kelas', public._kelompok_santri(s.id, 'kelas'), 'kamar', public._kelompok_santri(s.id, 'kamar'))
    from students s where s.id = p_id
$$;

-- ---------------------------------------------------------------------
-- 1. SECURITY
-- ---------------------------------------------------------------------
create or replace function public.laporan_security(p_mulai date, p_selesai date)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare a timestamptz := (p_mulai::timestamp at time zone 'Asia/Makassar'); b timestamptz := ((p_selesai + 1)::timestamp at time zone 'Asia/Makassar');
begin
  perform public._cek_rentang(p_mulai, p_selesai);
  if not public.boleh_lihat_security() then raise exception 'Anda tidak berwenang melihat laporan Security.' using errcode = '42501'; end if;
  return jsonb_build_object(
    'ringkas', jsonb_build_object(
      'keluar', (select count(*) from gate_logs where jenis = 'keluar' and waktu >= a and waktu < b),
      'kembali', (select count(*) from gate_logs where jenis = 'kembali' and waktu >= a and waktu < b),
      'terlambat', (select count(*) from gate_logs where jenis = 'kembali' and coalesce(terlambat_menit, 0) > 0 and waktu >= a and waktu < b),
      'ditolak', (select count(*) from gate_logs where jenis = 'ditolak' and waktu >= a and waktu < b),
      'titipan', (select count(*) from parcels where status <> 'batal' and diterima_pada >= a and diterima_pada < b),
      'titipan_diambil', (select count(*) from parcels where status = 'diambil' and diterima_pada >= a and diterima_pada < b),
      'titipan_dikembalikan', (select count(*) from parcels where status = 'dikembalikan' and diterima_pada >= a and diterima_pada < b),
      'titipan_belum', (select count(*) from parcels where status = 'di_pos' and diterima_pada >= a and diterima_pada < b),
      'tamu', (select count(*) from guest_logs where masuk_pada >= a and masuk_pada < b),
      'tamu_orang', (select coalesce(sum(jumlah_orang), 0) from guest_logs where masuk_pada >= a and masuk_pada < b),
      'kunjungan', (select count(*) from parent_visits where datang_pada >= a and datang_pada < b),
      'kunjungan_luar_jadwal', (select count(*) from parent_visits where luar_jadwal and datang_pada >= a and datang_pada < b)),
    'harian', (select coalesce(jsonb_agg(jsonb_build_object('tanggal', d::date,
        'keluar', (select count(*) from gate_logs g where g.jenis = 'keluar' and (g.waktu at time zone 'Asia/Makassar')::date = d::date),
        'kembali', (select count(*) from gate_logs g where g.jenis = 'kembali' and (g.waktu at time zone 'Asia/Makassar')::date = d::date),
        'terlambat', (select count(*) from gate_logs g where g.jenis = 'kembali' and coalesce(g.terlambat_menit, 0) > 0 and (g.waktu at time zone 'Asia/Makassar')::date = d::date),
        'ditolak', (select count(*) from gate_logs g where g.jenis = 'ditolak' and (g.waktu at time zone 'Asia/Makassar')::date = d::date),
        'titipan', (select count(*) from parcels t where t.status <> 'batal' and (t.diterima_pada at time zone 'Asia/Makassar')::date = d::date),
        'tamu', (select count(*) from guest_logs t where (t.masuk_pada at time zone 'Asia/Makassar')::date = d::date),
        'kunjungan', (select count(*) from parent_visits t where (t.datang_pada at time zone 'Asia/Makassar')::date = d::date)) order by d), '[]'::jsonb)
        from generate_series(p_mulai, p_selesai, interval '1 day') d),
    'terlambat', (select coalesce(jsonb_agg(public._santri_ringkas(g.student_id) || jsonb_build_object('waktu', g.waktu, 'menit', g.terlambat_menit,
                     'alasan', (select p.alasan from student_permits p where p.id = g.permit_id), 'batas', (select p.kembali_batas from student_permits p where p.id = g.permit_id))
                   order by g.waktu), '[]'::jsonb)
                    from gate_logs g where g.jenis = 'kembali' and coalesce(g.terlambat_menit, 0) > 0 and g.waktu >= a and g.waktu < b),
    'ditolak_daftar', (select coalesce(jsonb_agg(public._santri_ringkas(g.student_id) || jsonb_build_object('waktu', g.waktu, 'catatan', g.catatan) order by g.waktu), '[]'::jsonb)
                    from gate_logs g where g.jenis = 'ditolak' and g.waktu >= a and g.waktu < b),
    'titipan_belum_daftar', (select coalesce(jsonb_agg(public._santri_ringkas(t.student_id) || jsonb_build_object('diterima', t.diterima_pada, 'jenis', t.jenis,
                     'uraian', t.uraian, 'pengirim', t.pengirim) order by t.diterima_pada), '[]'::jsonb)
                    from parcels t where t.status = 'di_pos' and t.diterima_pada >= a and t.diterima_pada < b));
end $$;

-- ---------------------------------------------------------------------
-- 2. LIBUR SANTRI
-- ---------------------------------------------------------------------
create or replace function public.laporan_libur(p_mulai date, p_selesai date)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform public._cek_rentang(p_mulai, p_selesai);
  if not public.boleh_lihat_libur() then raise exception 'Anda tidak berwenang melihat laporan libur santri.' using errcode = '42501'; end if;
  return jsonb_build_object(
    'periode', (select coalesce(jsonb_agg(jsonb_build_object('id', h.id, 'nama', h.nama, 'jenis', h.jenis, 'pulang_pada', h.pulang_pada, 'kembali_batas', h.kembali_batas,
        'jenjang', h.jenjang, 'jenis_kelamin', h.jenis_kelamin, 'status', h.status,
        'peserta', (select count(*) from holiday_eligibility e where e.period_id = h.id),
        'boleh', (select count(*) from holiday_eligibility e where e.period_id = h.id and coalesce(e.keputusan, e.otomatis) = 'boleh'),
        'tidak', (select count(*) from holiday_eligibility e where e.period_id = h.id and coalesce(e.keputusan, e.otomatis) = 'tidak'),
        'pertimbangan', (select count(*) from holiday_eligibility e where e.period_id = h.id and e.keputusan is null and e.otomatis = 'pertimbangan'),
        'pulang', (select count(*) from holiday_eligibility e join student_permits p on p.id = e.permit_id where e.period_id = h.id and p.keluar_aktual is not null),
        'kembali_tepat', (select count(*) from holiday_eligibility e join student_permits p on p.id = e.permit_id where e.period_id = h.id and p.kembali_pada <= p.kembali_batas),
        'kembali_terlambat', (select count(*) from holiday_eligibility e join student_permits p on p.id = e.permit_id where e.period_id = h.id and p.kembali_pada > p.kembali_batas),
        'belum_kembali', (select count(*) from holiday_eligibility e join student_permits p on p.id = e.permit_id
                           where e.period_id = h.id and p.keluar_aktual is not null and p.kembali_pada is null and p.kembali_batas < now())) order by h.pulang_pada), '[]'::jsonb)
      from holiday_periods h where h.status <> 'batal' and (h.pulang_pada at time zone 'Asia/Makassar')::date between p_mulai and p_selesai),
    'masalah', (select coalesce(jsonb_agg(public._santri_ringkas(p.student_id) || jsonb_build_object('periode', h.nama, 'batas', p.kembali_batas, 'kembali', p.kembali_pada,
        'keadaan', case when p.kembali_pada is null then 'Belum kembali' else 'Terlambat kembali' end,
        'menit', case when p.kembali_pada is not null then round(extract(epoch from p.kembali_pada - p.kembali_batas) / 60) end) order by h.pulang_pada, p.kembali_batas), '[]'::jsonb)
      from holiday_periods h join holiday_eligibility e on e.period_id = h.id join student_permits p on p.id = e.permit_id
     where h.status <> 'batal' and (h.pulang_pada at time zone 'Asia/Makassar')::date between p_mulai and p_selesai
       and ((p.kembali_pada > p.kembali_batas) or (p.keluar_aktual is not null and p.kembali_pada is null and p.kembali_batas < now()))));
end $$;

-- ---------------------------------------------------------------------
-- 3. PENGAJUAN PEGAWAI
-- ---------------------------------------------------------------------
create or replace function public.laporan_pengajuan(p_mulai date, p_selesai date, p_unit uuid default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_saya uuid := public.saya(); v_semua boolean := public.admin_boleh('lihat_pengajuan') or public.is_superadmin();
begin
  perform public._cek_rentang(p_mulai, p_selesai);
  if v_saya is null then raise exception 'Akun Anda belum aktif.'; end if;
  return jsonb_build_object(
    'jenis', (select coalesce(jsonb_agg(jsonb_build_object('id', t.id, 'nama', t.nama, 'kelompok', t.kelompok) order by t.urutan), '[]'::jsonb) from leave_types t where t.aktif),
    'pegawai', (select coalesce(jsonb_agg(x order by x->>'nama'), '[]'::jsonb) from (
      select jsonb_build_object('employee_id', e.id, 'niy', e.niy, 'nama', e.nama_lengkap, 'jk', e.jenis_kelamin, 'unit', u.nama,
        'per_jenis', (select coalesce(jsonb_object_agg(q.leave_type_id, jsonb_build_object('kali', q.kali, 'hari', q.hari)), '{}'::jsonb) from (
            select r.leave_type_id, count(*) kali,
                   sum(greatest(0, least(r.selesai, p_selesai) - greatest(r.mulai, p_mulai) + 1)) hari
              from leave_requests r where r.employee_id = e.id and r.status = 'disetujui' and r.mulai <= p_selesai and r.selesai >= p_mulai
             group by r.leave_type_id) q),
        'menunggu', (select count(*) from leave_requests r where r.employee_id = e.id and r.status = 'menunggu' and r.mulai <= p_selesai and r.selesai >= p_mulai),
        'ditolak', (select count(*) from leave_requests r where r.employee_id = e.id and r.status = 'ditolak' and r.mulai <= p_selesai and r.selesai >= p_mulai),
        'total_hari', (select coalesce(sum(greatest(0, least(r.selesai, p_selesai) - greatest(r.mulai, p_mulai) + 1)), 0)
                         from leave_requests r where r.employee_id = e.id and r.status = 'disetujui' and r.mulai <= p_selesai and r.selesai >= p_mulai)) x
        from employees e left join org_units u on u.id = e.org_unit_id
       where e.status_akun = 'aktif' and e.status_keaktifan = 'aktif' and e.peran <> 'superadmin'
         and (v_semua or e.id = v_saya or public.pimpinan_dari(e.id))
         and (p_unit is null or e.org_unit_id in (select public.unit_turunan(p_unit)))) q));
end $$;

-- ---------------------------------------------------------------------
-- 4. KLINIK (tanpa diagnosis)
-- ---------------------------------------------------------------------
create or replace function public.laporan_klinik(p_mulai date, p_selesai date)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare a timestamptz := (p_mulai::timestamp at time zone 'Asia/Makassar'); b timestamptz := ((p_selesai + 1)::timestamp at time zone 'Asia/Makassar');
  v_klinik text[];
begin
  perform public._cek_rentang(p_mulai, p_selesai);
  if public.boleh_kelola_klinik() or public.pimpinan_kesantrian() then v_klinik := array['putra','putri'];
  else select array_agg(k) into v_klinik from public.klinik_petugas_saya() k; end if;
  if v_klinik is null or cardinality(v_klinik) = 0 then raise exception 'Anda tidak berwenang melihat laporan klinik.' using errcode = '42501'; end if;
  return jsonb_build_object('klinik', to_jsonb(v_klinik),
    'per_klinik', (select coalesce(jsonb_agg(jsonb_build_object('klinik', k,
        'kasus', (select count(*) from clinic_cases c where c.klinik = k and c.dibuka_pada >= a and c.dibuka_pada < b and c.status <> 'batal'),
        'rujukan', (select count(*) from clinic_referrals r join clinic_cases c on c.id = r.case_id where c.klinik = k and r.dirujuk_pada >= a and r.dirujuk_pada < b),
        'datang_sendiri', (select count(*) from clinic_cases c where c.klinik = k and c.sumber = 'datang_sendiri' and c.dibuka_pada >= a and c.dibuka_pada < b),
        'pemeriksaan', (select count(*) from clinic_visits v join clinic_cases c on c.id = v.case_id where c.klinik = k and v.jenis = 'pemeriksaan' and v.waktu >= a and v.waktu < b),
        'kontrol', (select count(*) from clinic_visits v join clinic_cases c on c.id = v.case_id where c.klinik = k and v.jenis = 'kontrol' and v.waktu >= a and v.waktu < b),
        'kembali', (select count(*) from clinic_visits v join clinic_cases c on c.id = v.case_id where c.klinik = k and v.tindak_lanjut = 'kembali' and v.waktu >= a and v.waktu < b),
        'istirahat', (select count(*) from clinic_visits v join clinic_cases c on c.id = v.case_id where c.klinik = k and v.tindak_lanjut = 'istirahat' and v.waktu >= a and v.waktu < b),
        'rawat', (select count(*) from clinic_visits v join clinic_cases c on c.id = v.case_id where c.klinik = k and v.tindak_lanjut = 'rawat' and v.waktu >= a and v.waktu < b),
        'rujuk', (select count(*) from clinic_visits v join clinic_cases c on c.id = v.case_id where c.klinik = k and v.tindak_lanjut = 'rujuk' and v.waktu >= a and v.waktu < b),
        'pulang', (select count(*) from clinic_visits v join clinic_cases c on c.id = v.case_id where c.klinik = k and v.tindak_lanjut = 'pulang' and v.waktu >= a and v.waktu < b),
        'sembuh', (select count(*) from clinic_cases c where c.klinik = k and c.hasil = 'sembuh' and c.selesai_pada >= a and c.selesai_pada < b),
        'surat_sakit', (select count(*) from clinic_letters l join clinic_cases c on c.id = l.case_id where c.klinik = k and l.tanggal between p_mulai and p_selesai))), '[]'::jsonb)
      from unnest(v_klinik) k),
    'harian', (select coalesce(jsonb_agg(jsonb_build_object('tanggal', d::date,
        'kasus', (select count(*) from clinic_cases c where c.klinik = any(v_klinik) and c.status <> 'batal' and (c.dibuka_pada at time zone 'Asia/Makassar')::date = d::date),
        'pemeriksaan', (select count(*) from clinic_visits v join clinic_cases c on c.id = v.case_id where c.klinik = any(v_klinik) and (v.waktu at time zone 'Asia/Makassar')::date = d::date),
        'dirawat', (select count(*) from clinic_cases c where c.klinik = any(v_klinik) and c.tindak_lanjut in ('rawat','istirahat') and c.sakit_sejak is not null
                      and (c.sakit_sejak at time zone 'Asia/Makassar')::date <= d::date and (c.selesai_pada is null or (c.selesai_pada at time zone 'Asia/Makassar')::date >= d::date))) order by d), '[]'::jsonb)
        from generate_series(p_mulai, p_selesai, interval '1 day') d),
    'kasus', (select coalesce(jsonb_agg(public._santri_ringkas(c.student_id) || jsonb_build_object('dibuka', c.dibuka_pada, 'klinik', c.klinik, 'keluhan', c.keluhan,
        'tindak_lanjut', c.tindak_lanjut, 'status', c.status, 'hasil', c.hasil, 'selesai', c.selesai_pada) order by c.dibuka_pada), '[]'::jsonb)
      from clinic_cases c where c.klinik = any(v_klinik) and c.status <> 'batal' and c.dibuka_pada >= a and c.dibuka_pada < b));
end $$;

do $$ declare f text; begin
  foreach f in array array['laporan_security(date,date)','laporan_libur(date,date)','laporan_pengajuan(date,date,uuid)','laporan_klinik(date,date)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  foreach f in array array['_santri_ringkas(uuid)','_cek_rentang(date,date)'] loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
  end loop;
end $$;

-- PEMERIKSAAN (hasil yang benar: "Sesuai")
select '1. Fungsi laporan Security, libur, pengajuan, klinik' as pemeriksaan,
       case when (select count(*) from pg_proc where proname in ('laporan_security','laporan_libur','laporan_pengajuan','laporan_klinik')) = 4 then 'Sesuai' else 'Periksa' end as hasil;
