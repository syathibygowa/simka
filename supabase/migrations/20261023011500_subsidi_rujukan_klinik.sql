-- SIMKA PRO | supabase/migrations/20261023011500_subsidi_rujukan_klinik.sql | v1.0 | 14.2.0: subsidi mengurangi tagihan yang sudah ada; sumber rujukan klinik dapat dipilih | 17/10/2026
-- =====================================================================
-- A. SUBSIDI SANTRI (perbaikan)
--    Masalah: subsidi hanya dihitung saat tagihan dibuat. Subsidi yang dicatat/diubah sesudahnya tidak mengurangi tagihan
--    yang sudah ada, dan subsidi bertanggal mulai "hari ini" tidak mengenai tagihan bulan/tahun yang sedang berjalan
--    (acuan tagihan = awal periode).
--    Perbaikan:
--    * Subsidi berlaku bila masa berlakunya BERIRISAN dengan periode tagihan (bulan, semester, tahun ajaran), bukan hanya
--      pada tanggal awal periode.
--    * Setiap subsidi ditambah/diubah/dihapus, tagihan santri itu yang belum lunas otomatis dihitung ulang
--      (tagihan yang potongannya diubah manual lewat "Ubah tagihan" tidak disentuh).
--    * Tagihan tidak pernah turun di bawah jumlah yang sudah dibayar.
--    * Sekali jalan: semua tagihan belum lunas milik santri bersubsidi dihitung ulang.
-- B. RUJUKAN KLINIK DARI ABSENSI
--    Ketentuan Klinik → "Sumber rujukan otomatis": centang absensi mana yang mengirim santri Sakit ke klinik.
--    Bawaan (keputusan pimpinan): hanya absensi asrama (musyrif). Absensi lain tetap mencatat Sakit tanpa rujukan.
-- Jalankan SETELAH migrasi 11400. Aman dijalankan ulang.
-- =====================================================================

create or replace function pg_temp.tambal(p_fn text, p_cari text, p_ganti text, p_tanda text)
returns text language plpgsql as $$
declare r record; v text; n int := 0;
begin
  for r in select p.oid from pg_proc p join pg_namespace s on s.oid = p.pronamespace where s.nspname = 'public' and p.proname = p_fn loop
    v := pg_get_functiondef(r.oid);
    if position(p_tanda in v) > 0 then n := n + 1; continue; end if;      -- sudah ditambal
    if position(p_cari in v) = 0 then raise notice 'Penambalan %: teks acuan tidak ditemukan, dilewati.', p_fn; continue; end if;
    execute replace(v, p_cari, p_ganti); n := n + 1;
  end loop;
  return p_fn || ': ' || n;
end $$;

-- =====================================================================
-- A. SUBSIDI
-- =====================================================================
alter table public.bills add column if not exists potongan_manual boolean not null default false;

-- Penanda potongan manual untuk tagihan lama: potongan berisi alasan yang bukan dari subsidi santri itu
do $$
begin
  if not exists (select 1 from institution_settings where kunci = 'migrasi_11500') then
    update bills b set potongan_manual = true
     where b.potongan > 0 and b.alasan_potongan is not null
       and not exists (select 1 from fee_subsidies s where s.student_id = b.student_id and position(s.alasan in b.alasan_potongan) = 1);
  end if;
end $$;

/** Rentang periode sebuah tagihan (awal–akhir) dari siklus jenis biaya dan kunci periode. */
create or replace function public._rentang_tagihan(p_fee uuid, p_kunci text, p_tagih date)
returns table (awal date, akhir date) language plpgsql stable security definer set search_path = public as $$
declare v_siklus text; v_ta text; v_mulai date;
begin
  select siklus into v_siklus from fee_types where id = p_fee;
  if p_kunci ~ '^[0-9]{4}-(0[1-9]|1[0-2])$' then
    awal := (p_kunci || '-01')::date; akhir := (awal + interval '1 month')::date - 1;
  elsif p_kunci ~ '^[0-9]{4}/[0-9]{4}' then
    v_ta := substr(p_kunci, 1, 9);
    select mulai into v_mulai from academic_years where nama = v_ta;
    v_mulai := coalesce(v_mulai, (left(v_ta, 4) || '-07-01')::date);
    if p_kunci ~ '-S2$' then awal := (v_mulai + interval '6 months')::date; akhir := (v_mulai + interval '12 months')::date - 1;
    elsif p_kunci ~ '-S1$' then awal := v_mulai; akhir := (v_mulai + interval '6 months')::date - 1;
    else awal := v_mulai; akhir := (v_mulai + interval '12 months')::date - 1;
    end if;
  else
    awal := coalesce(p_tagih, public.hari_ini()); akhir := awal;
  end if;
  return next;
end $$;

/** Potongan subsidi untuk satu tagihan. p_tanggal = awal periode; subsidi berlaku bila masa berlakunya beririsan
    dengan periode tagihan (bulan untuk bulanan, enam bulan untuk semesteran, setahun untuk tahunan). Hasil {potongan, alasan}. */
create or replace function public._potongan_subsidi(p_sid uuid, p_fee uuid, p_tanggal date, p_standar numeric)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare s record; v_pot numeric := 0; v_alasan text[] := '{}'; v_siklus text; v_akhir date;
begin
  select siklus into v_siklus from fee_types where id = p_fee;
  v_akhir := case v_siklus when 'bulanan' then (date_trunc('month', p_tanggal) + interval '1 month')::date - 1
                           when 'semesteran' then (p_tanggal + interval '6 months')::date - 1
                           when 'tahunan' then (p_tanggal + interval '12 months')::date - 1
                           else p_tanggal end;
  for s in select * from fee_subsidies where student_id = p_sid and aktif and (fee_type_id is null or fee_type_id = p_fee)
             and mulai <= v_akhir and (sampai is null or sampai >= p_tanggal) order by jenis desc, created_at loop
    -- persen dihitung dari standar, nominal dikurangkan langsung
    v_pot := v_pot + case when s.jenis = 'persen' then round(p_standar * s.nilai / 100) else s.nilai end;
    v_alasan := array_append(v_alasan, s.alasan || ' (' || case when s.jenis = 'persen' then trim(to_char(s.nilai, 'FM990.##')) || '%' else public._rupiah(s.nilai) end || ')');
  end loop;
  return jsonb_build_object('potongan', round(least(v_pot, p_standar)), 'alasan', nullif(array_to_string(v_alasan, '; '), ''));
end $$;

/** Hitung ulang potongan subsidi pada tagihan santri yang belum lunas, atau lunas karena subsidi (bukan potongan manual).
    Tagihan tidak turun di bawah jumlah yang sudah dibayar; tagihan lunas tanpa potongan tidak disentuh. Hasil: jumlah tagihan yang berubah. */
create or replace function public._terapkan_subsidi(p_sid uuid)
returns int language plpgsql volatile security definer set search_path = public as $$
declare b record; v_sub jsonb; v_pot numeric; n int := 0;
begin
  for b in select x.*, r.awal from bills x cross join lateral public._rentang_tagihan(x.fee_type_id, x.kunci_periode, x.tanggal_tagih) r
            where x.student_id = p_sid and not x.potongan_manual
              and (x.status in ('belum','sebagian') or (x.status = 'lunas' and x.potongan > 0)) for update of x loop
    v_sub := public._potongan_subsidi(p_sid, b.fee_type_id, b.awal, b.standar);
    v_pot := least((v_sub->>'potongan')::numeric, b.standar - b.dibayar);
    if v_pot is distinct from b.potongan or (v_sub->>'alasan') is distinct from b.alasan_potongan then
      update bills set potongan = v_pot, alasan_potongan = v_sub->>'alasan', updated_at = now() where id = b.id;
      perform public._segarkan_tagihan(b.id);
      n := n + 1;
    end if;
  end loop;
  return n;
end $$;

create or replace function public.tg_subsidi_tagihan()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op in ('UPDATE','DELETE') then perform public._terapkan_subsidi(old.student_id); end if;
  if tg_op in ('INSERT','UPDATE') and (tg_op = 'INSERT' or new.student_id <> old.student_id) then perform public._terapkan_subsidi(new.student_id);
  end if;
  return null;
end $$;
drop trigger if exists zb_subsidi_tagihan on public.fee_subsidies;
create trigger zb_subsidi_tagihan after insert or update or delete on public.fee_subsidies for each row execute function public.tg_subsidi_tagihan();

/** Pratinjau sebelum simpan: berapa tagihan santri ini yang akan disesuaikan oleh subsidi. */
create or replace function public.tagihan_terdampak_subsidi(p_sid uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform public._wajib_lihat_keuangan();
  return jsonb_build_object(
    'belum_lunas', (select count(*) from bills where student_id = p_sid and status in ('belum','sebagian') and not potongan_manual),
    'manual', (select count(*) from bills where student_id = p_sid and status in ('belum','sebagian') and potongan_manual),
    'lunas', (select count(*) from bills where student_id = p_sid and status = 'lunas'));
end $$;

/** Ubah tagihan: potongan yang diubah manual ditandai agar tidak ditimpa perhitungan subsidi. */
select pg_temp.tambal('ubah_tagihan',
  'potongan = coalesce((p->>''potongan'')::numeric, potongan),',
  'potongan = coalesce((p->>''potongan'')::numeric, potongan), potongan_manual = potongan_manual or (p ? ''potongan'' and (p->>''potongan'')::numeric is distinct from potongan),',
  'potongan_manual');

/** Simpan subsidi: tanggal mulai kosong = awal tahun ajaran aktif (bukan hari ini). */
select pg_temp.tambal('simpan_subsidi',
  'coalesce(nullif(p->>''mulai'', '''')::date, public.hari_ini())',
  'coalesce(nullif(p->>''mulai'', '''')::date, (select mulai from academic_years where aktif limit 1), public.hari_ini())',
  'academic_years where aktif');

-- Sekali jalan: hitung ulang tagihan semua santri bersubsidi
do $$
declare s uuid; n int := 0;
begin
  if not exists (select 1 from institution_settings where kunci = 'migrasi_11500') then
    for s in select distinct student_id from fee_subsidies loop n := n + public._terapkan_subsidi(s); end loop;
    insert into institution_settings (kunci, nilai, publik) values ('migrasi_11500', jsonb_build_object('tagihan_disesuaikan', n, 'pada', now()), false)
    on conflict (kunci) do nothing;
    raise notice 'Tagihan disesuaikan dengan subsidi: %', n;
  end if;
end $$;

-- =====================================================================
-- B. SUMBER RUJUKAN KLINIK DARI ABSENSI
-- =====================================================================
/** Pengaturan klinik + bawaan sumber_absensi = ['asrama']. */
select pg_temp.tambal('pengaturan_klinik', '''kop'', ''pondok'')', '''kop'', ''pondok'', ''sumber_absensi'', jsonb_build_array(''asrama''))', 'sumber_absensi');

select pg_temp.tambal('simpan_pengaturan_klinik',
  '  insert into institution_settings (kunci, nilai, updated_by) values (''klinik'', v, public.saya())',
  '  if p ? ''sumber_absensi'' then
    if jsonb_typeof(p->''sumber_absensi'') <> ''array''
       or exists (select 1 from jsonb_array_elements_text(p->''sumber_absensi'') x where x not in (''asrama'',''kelas'',''halaqah'',''ekskul'')) then
      raise exception ''Sumber rujukan absensi tidak dikenal.'';
    end if;
    v := v || jsonb_build_object(''sumber_absensi'', (select coalesce(jsonb_agg(distinct x), ''[]''::jsonb) from jsonb_array_elements_text(p->''sumber_absensi'') x));
  end if;
  insert into institution_settings (kunci, nilai, updated_by) values (''klinik'', v, public.saya())',
  'sumber_absensi');

/** Apakah absensi jenis ini (asrama, kelas, halaqah, ekskul) mengirim santri Sakit ke klinik. */
create or replace function public.rujuk_klinik_dari(p_jenis text)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(public.pengaturan_klinik()->'sumber_absensi', '["asrama"]'::jsonb) ? case p_jenis when 'kamar' then 'asrama' else p_jenis end
$$;
grant execute on function public.rujuk_klinik_dari(text) to authenticated;

-- Simpan absensi: keluhan wajib dan rujukan hanya bila sumber absensi ini dicentang
select pg_temp.tambal('simpan_absensi_santri',
  '    if r->>''kode'' = ''S''
       and not exists (select 1 from jsonb_array_elements(v_oto) o where o->>''student_id'' = r->>''student_id'')',
  '    if r->>''kode'' = ''S'' and public.rujuk_klinik_dari(v_jenis)
       and not exists (select 1 from jsonb_array_elements(v_oto) o where o->>''student_id'' = r->>''student_id'')',
  'rujuk_klinik_dari');

-- Hak eksekusi fungsi bantu
do $$
declare f text;
begin
  foreach f in array array['_rentang_tagihan(uuid,text,date)', '_terapkan_subsidi(uuid)', 'tg_subsidi_tagihan()'] loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
  end loop;
  revoke execute on function public.tagihan_terdampak_subsidi(uuid) from public, anon;
  grant execute on function public.tagihan_terdampak_subsidi(uuid) to authenticated;
end $$;

-- =====================================================================
-- PEMERIKSAAN — hasil yang benar: 5 baris, semuanya "Sesuai"
-- =====================================================================
select '1. Subsidi berlaku pada periode tagihan yang beririsan' as pemeriksaan,
       case when position('v_akhir' in pg_get_functiondef('public._potongan_subsidi(uuid,uuid,date,numeric)'::regprocedure)) > 0 then 'Sesuai' else 'Periksa' end as hasil
union all
select '2. Tagihan otomatis disesuaikan saat subsidi berubah',
       case when exists (select 1 from pg_trigger where tgname = 'zb_subsidi_tagihan') then 'Sesuai' else 'Periksa' end
union all
select '3. Potongan manual tidak ditimpa subsidi',
       case when position('potongan_manual' in pg_get_functiondef('public.ubah_tagihan(uuid,jsonb)'::regprocedure)) > 0 then 'Sesuai' else 'Periksa' end
union all
select '4. Ketentuan klinik: sumber rujukan absensi (bawaan asrama)',
       case when public.pengaturan_klinik() ? 'sumber_absensi'
             and position('sumber_absensi' in pg_get_functiondef('public.simpan_pengaturan_klinik(jsonb)'::regprocedure)) > 0 then 'Sesuai' else 'Periksa' end
union all
select '5. Absensi hanya merujuk dari sumber yang dicentang',
       case when position('rujuk_klinik_dari' in pg_get_functiondef('public.simpan_absensi_santri(jsonb)'::regprocedure)) > 0 then 'Sesuai' else 'Periksa' end;
