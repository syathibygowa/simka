-- SIMKA PRO | supabase/migrations/20261017010600_jam_pelajaran_per_hari.sql | v1.0 | Perbaikan 13.6.0 Jam pelajaran per hari (reguler/Jumat/Sabtu) | 15/10/2026
-- =====================================================================
-- SIMKA PRO · Migrasi 106: Jam pelajaran yang lebih fleksibel per hari
--   Sebelumnya: Senin–Kamis dan Sabtu memakai "jam reguler", Jumat memakai "jam Jumat".
--   Sekarang ada kumpulan jam ketiga "jam Sabtu", dan pembagian hari → kumpulan jam dapat diatur PER JENJANG
--   (bawaan sama seperti sebelumnya: Sen–Kam reguler, Jumat jam Jumat, Sabtu reguler).
--   * lesson_periods.jenis_hari  : 'reguler' | 'jumat' | 'sabtu'
--   * pengaturan jadwal_pelajaran.hari_jam = { "wustha": {"1":"reguler",…,"6":"sabtu"}, "sma": {…} }
--   * jenis_jam_hari(jenjang, hari) : kumpulan jam yang dipakai sebuah hari
--   * simpan_hari_jam(jenjang, peta): simpan pembagian; jadwal pelajaran pada hari yang berubah dipindah ke jam
--     dengan urutan sama pada kumpulan jam baru (yang tidak cocok/bentrok dikosongkan). Kumpulan jam baru yang
--     masih kosong otomatis disalin dari kumpulan jam lama agar langsung dapat diubah.
-- Jalankan SETELAH migrasi 10500. Aman dijalankan ulang.
-- =====================================================================

-- 1. Izinkan kumpulan jam Sabtu
alter table public.lesson_periods drop constraint if exists lesson_periods_jenis_hari_check;
alter table public.lesson_periods add constraint lesson_periods_jenis_hari_check check (jenis_hari in ('reguler','jumat','sabtu'));

-- 2. Kumpulan jam yang dipakai sebuah hari (per jenjang)
create or replace function public.jenis_jam_hari(p_jenjang text, p_hari int)
returns text language sql stable security definer set search_path = public as $$
  select coalesce(
    (select nullif(nilai->'hari_jam'->p_jenjang->>p_hari::text, '') from institution_settings where kunci = 'jadwal_pelajaran'),
    case when p_hari = coalesce((select (nilai->>'hari_jumat')::int from institution_settings where kunci = 'jadwal_pelajaran'), 5)
         then 'jumat' else 'reguler' end)
$$;
grant execute on function public.jenis_jam_hari(text,int) to authenticated;

-- 3. Penjaga jadwal memakai pembagian jam per hari
create or replace function public.tg_jadwal_jaga()
returns trigger language plpgsql security definer set search_path = public as $$
declare a teaching_assignments; g student_groups; p lesson_periods; st jsonb; b record; v_jenis_hari text;
begin
  select * into a from teaching_assignments where id = new.assignment_id;
  select * into g from student_groups where id = a.group_id;
  select * into p from lesson_periods where id = new.period_id;
  new.group_id := a.group_id; new.employee_id := a.employee_id;
  v_jenis_hari := public.jenis_jam_hari(g.jenjang, new.hari);   -- pembagian jam per hari (Mapel dan jam)
  if p.jenis <> 'jp' then raise exception 'Jam istirahat tidak dapat diisi pelajaran.'; end if;
  if p.jenjang <> g.jenjang or p.jenis_hari <> v_jenis_hari then
    raise exception 'Jam pelajaran tidak sesuai jenjang/hari kelas %.', g.nama;
  end if;
  select cs.id, gg.nama as kelas, pp.nama as jam, pp.jam_mulai, pp.jam_selesai into b
  from class_schedules cs join lesson_periods pp on pp.id = cs.period_id join student_groups gg on gg.id = cs.group_id
  where cs.employee_id = new.employee_id and cs.hari = new.hari and cs.id is distinct from new.id
    and pp.jam_mulai < p.jam_selesai and p.jam_mulai < pp.jam_selesai limit 1;
  if found then
    raise exception 'Bentrok: % sudah mengajar di kelas % pada % (% – %).', (select nama_lengkap from employees where id = new.employee_id),
      b.kelas, b.jam, to_char(b.jam_mulai, 'HH24.MI'), to_char(b.jam_selesai, 'HH24.MI');
  end if;
  return new;
end $$;


-- 4. Simpan pembagian hari → kumpulan jam satu jenjang
create or replace function public.simpan_hari_jam(p_jenjang text, p_peta jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare h int; v_lama text; v_baru text; r record; v_pindah int := 0; v_hapus int := 0; v_set jsonb; p_baru uuid;
begin
  if not public.boleh_atur_jadwal() then raise exception 'Anda tidak berwenang mengatur jam pelajaran.' using errcode = '42501'; end if;
  if p_jenjang not in ('wustha','sma') then raise exception 'Jenjang tidak dikenal.'; end if;
  for h in 1..6 loop
    v_baru := coalesce(p_peta->>h::text, public.jenis_jam_hari(p_jenjang, h));
    if v_baru not in ('reguler','jumat','sabtu') then raise exception 'Kumpulan jam % tidak dikenal.', v_baru; end if;
  end loop;

  for h in 1..6 loop
    v_lama := public.jenis_jam_hari(p_jenjang, h);
    v_baru := coalesce(p_peta->>h::text, v_lama);
    if v_baru = v_lama then continue; end if;
    -- Kumpulan jam baru masih kosong → salin dari kumpulan lama sebagai titik awal
    if not exists (select 1 from lesson_periods where jenjang = p_jenjang and jenis_hari = v_baru) then
      insert into lesson_periods (jenjang, jenis_hari, urutan, jenis, nama, jam_mulai, jam_selesai)
      select jenjang, v_baru, urutan, jenis, nama, jam_mulai, jam_selesai from lesson_periods where jenjang = p_jenjang and jenis_hari = v_lama;
    end if;
    -- Simpan pembagian sementara agar penjaga jadwal memakai kumpulan baru untuk hari ini
    select coalesce(nilai, '{}'::jsonb) into v_set from institution_settings where kunci = 'jadwal_pelajaran';
    v_set := jsonb_set(coalesce(v_set, '{}'::jsonb), array['hari_jam', p_jenjang],
               coalesce(v_set->'hari_jam'->p_jenjang, '{}'::jsonb) || jsonb_build_object(h::text, v_baru), true);
    insert into institution_settings (kunci, nilai) values ('jadwal_pelajaran', v_set)
      on conflict (kunci) do update set nilai = excluded.nilai;
    -- Pindahkan jadwal hari ini ke jam berurutan sama pada kumpulan baru
    for r in select cs.id, p.urutan from class_schedules cs join lesson_periods p on p.id = cs.period_id
              where cs.hari = h and p.jenjang = p_jenjang and p.jenis_hari = v_lama loop
      select id into p_baru from lesson_periods where jenjang = p_jenjang and jenis_hari = v_baru and urutan = r.urutan and jenis = 'jp';
      if p_baru is null then delete from class_schedules where id = r.id; v_hapus := v_hapus + 1; continue; end if;
      begin
        update class_schedules set period_id = p_baru where id = r.id; v_pindah := v_pindah + 1;
      exception when others then
        delete from class_schedules where id = r.id; v_hapus := v_hapus + 1;
      end;
    end loop;
  end loop;

  -- Lengkapi peta (hari yang tidak dikirim tetap)
  select coalesce(nilai, '{}'::jsonb) into v_set from institution_settings where kunci = 'jadwal_pelajaran';
  v_set := jsonb_set(coalesce(v_set, '{}'::jsonb), array['hari_jam', p_jenjang],
             (select jsonb_object_agg(x::text, public.jenis_jam_hari(p_jenjang, x)) from generate_series(1, 6) x), true);
  update institution_settings set nilai = v_set where kunci = 'jadwal_pelajaran';
  return jsonb_build_object('dipindah', v_pindah, 'dikosongkan', v_hapus, 'hari_jam', v_set->'hari_jam'->p_jenjang);
end $$;
revoke execute on function public.simpan_hari_jam(text,jsonb) from public, anon;
grant execute on function public.simpan_hari_jam(text,jsonb) to authenticated;

-- 5. Isi awal pembagian (sama dengan perilaku sebelumnya) bila belum ada
update institution_settings
   set nilai = jsonb_set(nilai, '{hari_jam}', '{"wustha": {"1":"reguler","2":"reguler","3":"reguler","4":"reguler","5":"jumat","6":"reguler"},
                                               "sma":    {"1":"reguler","2":"reguler","3":"reguler","4":"reguler","5":"jumat","6":"reguler"}}'::jsonb, true)
 where kunci = 'jadwal_pelajaran' and not (nilai ? 'hari_jam');

-- PEMERIKSAAN — hasil yang benar: 3 baris "Sesuai"
select '1. Kumpulan jam Sabtu diizinkan' as pemeriksaan,
       case when pg_get_constraintdef((select oid from pg_constraint where conname = 'lesson_periods_jenis_hari_check')) like '%sabtu%' then 'Sesuai' else 'Periksa' end as hasil
union all
select '2. Pembagian jam per hari tersimpan (Jumat memakai jam Jumat)',
       case when public.jenis_jam_hari('wustha', 5) = 'jumat' and public.jenis_jam_hari('sma', 1) = 'reguler' then 'Sesuai' else 'Periksa' end
union all
select '3. Penjaga jadwal memakai pembagian jam per hari',
       case when position('jenis_jam_hari' in (select prosrc from pg_proc where proname = 'tg_jadwal_jaga')) > 0 then 'Sesuai' else 'Periksa' end;
