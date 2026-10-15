-- SIMKA PRO | supabase/migrations/20261017009800_portal_wali_layanan.sql | v1.0 | Fase 9 – Tahap 13.1.0 Kehadiran, perizinan, kunjungan, titipan, riwayat sakit | 15/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 9 · Migrasi 98: data Portal Wali tahap 13.1.0 (Blueprint Bagian 26)
--   portal_data(token, bagian, p) menambah bagian:
--   * 'kehadiran'  : rekap HISBAT per kegiatan (kelas, halaqah, asrama, ekskul) + persentase program pokok
--                    + daftar sesi per tanggal. Keterangan Sakit tidak dikirim (detail kesehatan).
--   * 'perizinan'  : izin keluar/pulang yang disetujui (tanpa jejak persetujuan internal), keluar/kembali di gerbang,
--                    dan libur santri yang sudah disahkan.
--   * 'kunjungan'  : kunjungan orang tua/wali yang dicatat Security (tanpa foto dan nomor HP).
--   * 'titipan'    : titipan untuk santri: diterima dan diambil (tanpa foto).
--   * 'sakit'      : riwayat kunjungan Klinik ringkas (tanggal, keluhan umum, penanganan, status) TANPA diagnosis
--                    dan catatan pemeriksaan. Hanya bila butir "Riwayat sakit" dinyalakan superadmin (bawaan mati).
--   Periode p = {mulai, selesai} (yyyy-mm-dd); bawaan awal bulan ini s.d. hari ini; paling panjang 186 hari (satu semester).
--   Beranda menambah ringkasan kehadiran bulan ini.
-- Jalankan SETELAH migrasi 9700. Aman dijalankan ulang.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. PEMBANTU
-- ---------------------------------------------------------------------
/** Rentang periode portal: bawaan awal bulan ini s.d. hari ini; selesai ≤ hari ini; paling panjang 186 hari. */
create or replace function public._portal_rentang(p jsonb, out mulai date, out selesai date)
language plpgsql stable as $$
declare v_hari date := public.hari_ini();
begin
  begin selesai := nullif(p->>'selesai', '')::date; exception when others then selesai := null; end;
  begin mulai := nullif(p->>'mulai', '')::date; exception when others then mulai := null; end;
  selesai := least(coalesce(selesai, v_hari), v_hari);
  mulai := coalesce(mulai, date_trunc('month', selesai)::date);
  if mulai > selesai then mulai := selesai; end if;
  if selesai - mulai > 185 then mulai := selesai - 185; end if;
end $$;

/** Semua sesi absensi yang diikuti santri dalam rentang (keanggotaan pada tanggal sesi), beserta kodenya (H bila tidak ada pengecualian). */
create or replace function public._portal_sesi_santri(p_santri uuid, p_mulai date, p_selesai date)
returns table (tanggal date, jenis text, kelompok text, nama_sesi text, jam time, kode text, keterangan text)
language sql stable security definer set search_path = public as $$
  select sa.tanggal, sa.jenis, g.nama, sa.nama_sesi, sa.jam_mulai, coalesce(e.kode, 'H'), e.keterangan
    from student_attendance_sessions sa
    join student_groups g on g.id = sa.group_id
    join group_members m on m.group_id = sa.group_id and m.student_id = p_santri and m.mulai <= sa.tanggal
         and (m.selesai is null or m.selesai > sa.tanggal or (m.selesai = sa.tanggal and coalesce(m.alasan_keluar, '') not like 'Pindah ke %'))
    left join student_attendance_exceptions e on e.session_id = sa.id and e.student_id = p_santri
   where sa.tanggal between p_mulai and p_selesai
$$;

/** Rekap HISBAT satu santri: {kelas:{sesi,hadir,izin,sakit,bolos,absen,terlambat}, …, pokok:{…, persen}}. Terlambat dan Bolos dihitung hadir. */
create or replace function public._portal_rekap_hadir(p_santri uuid, p_mulai date, p_selesai date)
returns jsonb language sql stable security definer set search_path = public as $$
  with x as (select * from public._portal_sesi_santri(p_santri, p_mulai, p_selesai)),
  per as (
    select jenis, count(*)::int as sesi, count(*) filter (where kode not in ('I','S','A'))::int as hadir,
           count(*) filter (where kode = 'I')::int as izin, count(*) filter (where kode = 'S')::int as sakit,
           count(*) filter (where kode = 'B')::int as bolos, count(*) filter (where kode = 'A')::int as absen,
           count(*) filter (where kode = 'T')::int as terlambat
      from x group by jenis),
  pokok as (
    select coalesce(sum(sesi), 0)::int as sesi, coalesce(sum(hadir), 0)::int as hadir, coalesce(sum(izin), 0)::int as izin,
           coalesce(sum(sakit), 0)::int as sakit, coalesce(sum(bolos), 0)::int as bolos, coalesce(sum(absen), 0)::int as absen,
           coalesce(sum(terlambat), 0)::int as terlambat
      from per where jenis in ('kelas','halaqah','asrama'))
  select coalesce((select jsonb_object_agg(jenis, to_jsonb(per) - 'jenis' || jsonb_build_object('persen',
            case when sesi > 0 then round(hadir * 100.0 / sesi, 1) end)) from per), '{}'::jsonb)
      || jsonb_build_object('pokok', (select to_jsonb(pokok) || jsonb_build_object('persen',
            case when pokok.sesi > 0 then round(pokok.hadir * 100.0 / pokok.sesi, 1) end) from pokok))
$$;

-- ---------------------------------------------------------------------
-- 2. BAGIAN PORTAL
-- ---------------------------------------------------------------------
create or replace function public._portal_kehadiran(p_santri uuid, p_set jsonb, p jsonb)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare r record;
begin
  select * into r from public._portal_rentang(p);
  return jsonb_build_object(
    'mulai', r.mulai, 'selesai', r.selesai,
    'rekap', public._portal_rekap_hadir(p_santri, r.mulai, r.selesai),
    'sesi', coalesce((
      select jsonb_agg(jsonb_build_object('t', x.tanggal, 'j', x.jenis, 'g', x.kelompok, 's', x.nama_sesi,
                         'jam', to_char(x.jam, 'HH24.MI'), 'k', x.kode,
                         -- Keterangan sakit tidak dikirim ke wali (detail kesehatan)
                         'ket', case when x.kode in ('I','B','A','T') then nullif(trim(x.keterangan), '') end)
                       order by x.tanggal desc, x.jam nulls last, x.nama_sesi)
        from public._portal_sesi_santri(p_santri, r.mulai, r.selesai) x), '[]'::jsonb));
end $$;

create or replace function public._portal_perizinan(p_santri uuid, p_set jsonb, p jsonb)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare r record; v_sakit boolean := public._portal_butir(p_set, 'sakit');
begin
  select * into r from public._portal_rentang(p);
  return jsonb_build_object(
    'mulai', r.mulai, 'selesai', r.selesai,
    'izin', coalesce((
      select jsonb_agg(jsonb_build_object(
               'jenis', x.jenis,
               'alasan', case when x.sumber = 'klinik' and not v_sakit then 'Izin pulang dari Klinik' else x.alasan end,
               'penjemput', x.penjemput, 'hubungan_penjemput', x.hubungan_penjemput,
               'keluar_pada', x.keluar_pada, 'kembali_batas', x.kembali_batas, 'lama_hari', x.lama_hari,
               'keluar_aktual', x.keluar_aktual, 'kembali_pada', x.kembali_pada,
               -- Status untuk wali: disetujui/keluar/kembali (izin yang masih diajukan atau ditolak tidak dikirim)
               'status', x.status,
               'terlambat', (x.status = 'keluar' and now() > x.kembali_batas) or (x.status = 'kembali' and x.kembali_pada > x.kembali_batas))
             order by x.keluar_pada desc)
        from student_permits x
       where x.student_id = p_santri and x.status in ('disetujui','keluar','kembali')
         and (x.keluar_pada at time zone 'Asia/Makassar')::date <= r.selesai
         and (coalesce(x.kembali_pada, x.kembali_batas) at time zone 'Asia/Makassar')::date >= r.mulai), '[]'::jsonb),
    'libur', coalesce((
      select jsonb_agg(jsonb_build_object('nama', h.nama, 'jenis', h.jenis, 'pulang_pada', h.pulang_pada, 'kembali_batas', h.kembali_batas,
                                          'keputusan', e.keputusan) order by h.pulang_pada desc)
        from holiday_eligibility e join holiday_periods h on h.id = e.period_id and h.status = 'disahkan'
       where e.student_id = p_santri and e.keputusan is not null
         and (h.pulang_pada at time zone 'Asia/Makassar')::date <= r.selesai + 60
         and (h.kembali_batas at time zone 'Asia/Makassar')::date >= r.mulai), '[]'::jsonb));
end $$;

create or replace function public._portal_kunjungan(p_santri uuid, p_set jsonb, p jsonb)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare r record;
begin
  select * into r from public._portal_rentang(p);
  return jsonb_build_object('mulai', r.mulai, 'selesai', r.selesai, 'kunjungan', coalesce((
    select jsonb_agg(jsonb_build_object('pengunjung', v.pengunjung, 'hubungan', v.hubungan, 'jumlah_orang', v.jumlah_orang,
                                        'datang_pada', v.datang_pada, 'pulang_pada', v.pulang_pada, 'luar_jadwal', v.luar_jadwal)
                     order by v.datang_pada desc)
      from parent_visits v
     where v.student_id = p_santri and (v.datang_pada at time zone 'Asia/Makassar')::date between r.mulai and r.selesai), '[]'::jsonb));
end $$;

create or replace function public._portal_titipan(p_santri uuid, p_set jsonb, p jsonb)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare r record;
begin
  select * into r from public._portal_rentang(p);
  return jsonb_build_object('mulai', r.mulai, 'selesai', r.selesai, 'titipan', coalesce((
    select jsonb_agg(jsonb_build_object('jenis', t.jenis, 'uraian', t.uraian, 'nominal', t.nominal, 'pengirim', t.pengirim,
                                        'ekspedisi', t.ekspedisi, 'status', t.status, 'diterima_pada', t.diterima_pada,
                                        'diambil_pada', t.diambil_pada, 'pengambil_jenis', t.pengambil_jenis, 'pengambil_nama', t.pengambil_nama)
                     order by t.diterima_pada desc)
      from parcels t
     where t.student_id = p_santri and t.status <> 'batal'
       and ((t.diterima_pada at time zone 'Asia/Makassar')::date between r.mulai and r.selesai or t.status = 'di_pos')), '[]'::jsonb));
end $$;

create or replace function public._portal_sakit(p_santri uuid, p_set jsonb, p jsonb)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare r record;
begin
  select * into r from public._portal_rentang(p);
  return jsonb_build_object('mulai', r.mulai, 'selesai', r.selesai, 'kasus', coalesce((
    select jsonb_agg(jsonb_build_object('dibuka_pada', c.dibuka_pada, 'keluhan', c.keluhan, 'status', c.status,
                                        'tindak_lanjut', c.tindak_lanjut, 'kontrol_pada', c.kontrol_pada,
                                        'selesai_pada', c.selesai_pada, 'hasil', c.hasil)
                     order by c.dibuka_pada desc)
      from clinic_cases c
     where c.student_id = p_santri and c.status <> 'batal'
       and (c.dibuka_pada at time zone 'Asia/Makassar')::date <= r.selesai
       and coalesce((c.selesai_pada at time zone 'Asia/Makassar')::date, r.selesai) >= r.mulai), '[]'::jsonb));
end $$;

-- Beranda: tambah ringkasan kehadiran bulan ini (program pokok)
create or replace function public._portal_beranda(p_santri uuid, p_set jsonb, p_hubungan text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare s students; v_ta uuid; v_hari date := public.hari_ini(); hasil jsonb; v_wali text;
begin
  select x.* into s from students x where x.id = p_santri;
  select id into v_ta from academic_years where aktif limit 1;
  select c.nama into v_wali from student_contacts c where c.student_id = p_santri and c.hubungan = p_hubungan;
  hasil := jsonb_build_object(
    'butir', p_set->'butir',
    'lembaga', (select coalesce(nilai->>'nama_lengkap', nilai->>'nama') from institution_settings where kunci = 'identitas'),
    'tanggal', v_hari,
    'wali', jsonb_build_object('hubungan', p_hubungan, 'nama', v_wali),
    'santri', jsonb_build_object(
      'nis', s.nis, 'nama', s.nama_lengkap, 'panggilan', s.nama_panggilan, 'jk', s.jenis_kelamin,
      'jenjang', s.jenjang, 'tingkat', s.tingkat,
      'kelas', public._kelompok_santri(s.id, 'kelas'),
      'kamar', case when public._portal_butir(p_set, 'profil') then public._kelompok_santri(s.id, 'kamar') end,
      'halaqah', case when public._portal_butir(p_set, 'profil') then public._kelompok_santri(s.id, 'halaqah') end,
      'ekskul', case when public._portal_butir(p_set, 'profil') then public._kelompok_santri(s.id, 'ekskul') end,
      'program', case when public._portal_butir(p_set, 'hafalan') then (select program from student_tahfizh where student_id = s.id) end,
      'tempat_lahir', case when public._portal_butir(p_set, 'profil') then s.tempat_lahir end,
      'tanggal_lahir', case when public._portal_butir(p_set, 'profil') then s.tanggal_lahir end,
      'tahun_masuk', s.tahun_masuk));

  if public._portal_butir(p_set, 'pengasuh') then
    hasil := hasil || jsonb_build_object('pengasuh', coalesce((
      select jsonb_agg(jsonb_build_object('tugas', x.tugas, 'nama', x.nama, 'kelompok', x.kelompok) order by x.urut, x.kelompok)
      from (
        select distinct on (g.id)
               case g.jenis when 'kelas' then 'Wali kelas'
                            when 'kamar' then case when e.jenis_kelamin = 'P' then 'Musyrifah' else 'Musyrif' end
                            when 'halaqah' then case when e.jenis_kelamin = 'P' then 'Muhaffizhah' else 'Muhaffizh' end
                            else 'Pembina ekskul' end as tugas,
               e.nama_lengkap as nama, g.nama as kelompok,
               array_position(array['kelas','halaqah','kamar','ekskul'], g.jenis) as urut
          from group_members m
          join student_groups g on g.id = m.group_id and g.aktif and g.academic_year_id = v_ta and g.jenis in ('kelas','kamar','halaqah','ekskul')
          join group_keepers k on k.group_id = g.id and (k.mulai is null or k.mulai <= v_hari) and (k.sampai is null or k.sampai >= v_hari)
          join employees e on e.id = k.employee_id
         where m.student_id = p_santri and m.selesai is null
         order by g.id, array_position(array['utama','pendamping','pengganti'], k.peran)
      ) x), '[]'::jsonb));
  end if;

  if public._portal_butir(p_set, 'kehadiran') then
    hasil := hasil || jsonb_build_object(
      'hari_ini', coalesce((
        select jsonb_agg(jsonb_build_object('jenis', x.jenis, 'kelompok', x.kelompok, 'sesi', x.nama_sesi,
                                            'jam', to_char(x.jam, 'HH24.MI'), 'kode', x.kode) order by x.jam nulls last, x.nama_sesi)
          from public._portal_sesi_santri(p_santri, v_hari, v_hari) x), '[]'::jsonb),
      'bulan_ini', public._portal_rekap_hadir(p_santri, date_trunc('month', v_hari)::date, v_hari)->'pokok');
  end if;
  return hasil;
end $$;

/** Pintu tunggal data portal (13.1.0: beranda, kehadiran, perizinan, kunjungan, titipan, sakit). */
create or replace function public.portal_data(p_token text, p_bagian text, p jsonb default '{}'::jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare v_set jsonb := public._portal_set(); gs guardian_sessions; v_butir text;
begin
  if not coalesce((v_set->>'aktif')::boolean, false) then
    return jsonb_build_object('tutup', true, 'pesan', v_set->>'pesan_tutup');
  end if;
  gs := public._portal_sesi(p_token);
  if gs.id is null then return jsonb_build_object('sesi_berakhir', true); end if;
  -- Butir informasi yang harus dinyalakan untuk setiap bagian
  v_butir := case p_bagian when 'kehadiran' then 'kehadiran' when 'perizinan' then 'perizinan' when 'kunjungan' then 'kunjungan'
                           when 'titipan' then 'titipan' when 'sakit' then 'sakit' end;
  if v_butir is not null and not public._portal_butir(v_set, v_butir) then
    return jsonb_build_object('nonaktif', true, 'butir', v_set->'butir');
  end if;
  p := coalesce(p, '{}'::jsonb);
  case coalesce(p_bagian, '')
    when 'beranda'   then return public._portal_beranda(gs.student_id, v_set, gs.hubungan);
    when 'kehadiran' then return public._portal_kehadiran(gs.student_id, v_set, p);
    when 'perizinan' then return public._portal_perizinan(gs.student_id, v_set, p);
    when 'kunjungan' then return public._portal_kunjungan(gs.student_id, v_set, p);
    when 'titipan'   then return public._portal_titipan(gs.student_id, v_set, p);
    when 'sakit'     then return public._portal_sakit(gs.student_id, v_set, p);
    else return jsonb_build_object('galat', 'Bagian portal tidak dikenal.');
  end case;
end $$;

-- ---------------------------------------------------------------------
-- 3. HAK EKSEKUSI (pembantu internal tertutup bagi aplikasi)
-- ---------------------------------------------------------------------
do $$ declare f text; begin
  foreach f in array array['_portal_rentang(jsonb)','_portal_sesi_santri(uuid,date,date)','_portal_rekap_hadir(uuid,date,date)',
                           '_portal_kehadiran(uuid,jsonb,jsonb)','_portal_perizinan(uuid,jsonb,jsonb)','_portal_kunjungan(uuid,jsonb,jsonb)',
                           '_portal_titipan(uuid,jsonb,jsonb)','_portal_sakit(uuid,jsonb,jsonb)','_portal_beranda(uuid,jsonb,text)'] loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
  end loop;
  execute 'revoke execute on function public.portal_data(text,text,jsonb) from public';
  execute 'grant execute on function public.portal_data(text,text,jsonb) to anon, authenticated';
end $$;

-- PEMERIKSAAN — hasil yang benar: 3 baris "Sesuai"
select '1. Bagian portal kehadiran, perizinan, kunjungan, titipan, sakit' as pemeriksaan,
       case when (select count(*) from pg_proc where pronamespace = 'public'::regnamespace and proname in
             ('_portal_kehadiran','_portal_perizinan','_portal_kunjungan','_portal_titipan','_portal_sakit','_portal_rekap_hadir')) = 6
            then 'Sesuai' else 'Periksa' end as hasil
union all
select '2. Pembantu portal tertutup bagi pengguna tanpa login',
       case when not has_function_privilege('anon', 'public._portal_sakit(uuid,jsonb,jsonb)', 'execute')
             and has_function_privilege('anon', 'public.portal_data(text,text,jsonb)', 'execute') then 'Sesuai' else 'Periksa' end
union all
select '3. Riwayat sakit tetap mengikuti sakelar superadmin',
       case when (select nilai->'butir' ? 'sakit' from institution_settings where kunci = 'portal_wali') then 'Sesuai' else 'Periksa' end;
