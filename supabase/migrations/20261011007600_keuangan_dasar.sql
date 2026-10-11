-- SIMKA PRO | supabase/migrations/20261011007600_keuangan_dasar.sql | v1.0 | Fase 13 – Tahap 1 Keuangan santri: jenis biaya, tarif, subsidi, tagihan | 11/10/2026
-- =====================================================================
-- SIMKA PRO · Migrasi 76: Keuangan santri – dasar (Blueprint Bagian 37; Fase 13 dipercepat)
--   * Ketentuan keuangan (institution_settings 'keuangan'): rekening lembaga, jatuh tempo bawaan, catatan dokumen
--   * fee_types     : jenis biaya; siklus sekali / tahunan / bulanan; nominal standar
--   * fee_rates     : tarif khusus per jenjang dan/atau tingkat (mengalahkan nominal standar)
--   * fee_subsidies : subsidi/keringanan per santri (persen atau nominal; semua jenis atau jenis tertentu; berjangka)
--   * bills         : tagihan per santri per jenis per periode; standar − potongan subsidi = tagihan; status
--                     belum / sebagian / lunas / batal mengikuti pembayaran (migrasi 7700)
--   * pratinjau_tagihan / buat_tagihan : tagihan massal per jenjang, tingkat, kelompok, atau santri tertentu
-- Akses: superadmin dan pegawai yang DITUNJUK superadmin untuk "keuangan" (migrasi 7500). Tabel hanya dapat dibaca
-- oleh mereka; seluruh penulisan lewat fungsi. Data keuangan tidak tampil di portal wali.
-- Jalankan SETELAH migrasi 7500. Aman dijalankan ulang.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. PEMBANTU
-- ---------------------------------------------------------------------
create or replace function public._rupiah(n numeric)
returns text language sql immutable as $$
  select 'Rp' || replace(to_char(round(coalesce(n, 0)), 'FM999,999,999,999,990'), ',', '.')
$$;

/** Kelas aktif santri pada tahun ajaran aktif. */
create or replace function public._kelas_santri(p_sid uuid)
returns text language sql stable security definer set search_path = public as $$
  select g.nama from group_members m join student_groups g on g.id = m.group_id
   where m.student_id = p_sid and m.selesai is null and g.jenis = 'kelas'
     and g.academic_year_id = (select id from academic_years where aktif) limit 1
$$;

/** Kontak WA utama santri (utama, lalu ayah/ibu/wali yang memiliki nomor). */
create or replace function public._kontak_wali(p_sid uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('nama', c.nama, 'hubungan', c.hubungan, 'no_hp', c.no_hp)
    from student_contacts c where c.student_id = p_sid and c.no_hp is not null
   order by c.utama desc, case c.hubungan when 'ayah' then 1 when 'ibu' then 2 else 3 end limit 1
$$;

create or replace function public._wajib_kelola_keuangan()
returns void language plpgsql stable security definer set search_path = public as $$
begin
  if not public.boleh_kelola_keuangan() then raise exception 'Anda tidak berwenang mengelola keuangan santri.' using errcode = '42501'; end if;
end $$;
create or replace function public._wajib_lihat_keuangan()
returns void language plpgsql stable security definer set search_path = public as $$
begin
  if not public.boleh_lihat_keuangan() then raise exception 'Anda tidak berwenang melihat keuangan santri.' using errcode = '42501'; end if;
end $$;

-- ---------------------------------------------------------------------
-- 1. KETENTUAN KEUANGAN
-- ---------------------------------------------------------------------
create or replace function public._pengaturan_keuangan()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('rekening', '[]'::jsonb, 'jatuh_tempo_hari', 10, 'batas_surat_hari', 7,
           'catatan_kuitansi', 'Simpan kuitansi ini sebagai bukti pembayaran yang sah.',
           'catatan_tagihan', 'Apabila sudah melakukan pembayaran, mohon abaikan surat ini dan kirimkan bukti transfer kepada Bendahara.',
           'pengingat_hari', 3)
         || coalesce((select nilai from institution_settings where kunci = 'keuangan'), '{}'::jsonb)
$$;

create or replace function public.pengaturan_keuangan()
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform public._wajib_lihat_keuangan();
  return public._pengaturan_keuangan();
end $$;

create or replace function public.simpan_pengaturan_keuangan(p jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare v jsonb := public._pengaturan_keuangan(); r jsonb; v_rek jsonb := '[]'::jsonb; n int;
begin
  perform public._wajib_kelola_keuangan();
  if p ? 'rekening' then
    for r in select * from jsonb_array_elements(coalesce(p->'rekening', '[]'::jsonb)) loop
      if length(trim(coalesce(r->>'bank', ''))) < 2 or coalesce(r->>'nomor', '') !~ '^[0-9 .-]{5,30}$' or length(trim(coalesce(r->>'atas_nama', ''))) < 3 then
        raise exception 'Lengkapi bank, nomor rekening (angka), dan atas nama setiap rekening lembaga.'; end if;
      v_rek := v_rek || jsonb_build_array(jsonb_build_object('bank', trim(r->>'bank'), 'nomor', trim(r->>'nomor'), 'atas_nama', trim(r->>'atas_nama'),
                                                            'keterangan', nullif(trim(coalesce(r->>'keterangan', '')), '')));
    end loop;
    v := v || jsonb_build_object('rekening', v_rek);
  end if;
  if p ? 'jatuh_tempo_hari' then n := coalesce((p->>'jatuh_tempo_hari')::int, 10);
    if n < 1 or n > 28 then raise exception 'Tanggal jatuh tempo bulanan antara 1 dan 28.'; end if; v := v || jsonb_build_object('jatuh_tempo_hari', n); end if;
  if p ? 'batas_surat_hari' then n := coalesce((p->>'batas_surat_hari')::int, 7);
    if n < 1 or n > 60 then raise exception 'Batas pembayaran surat tagihan antara 1 dan 60 hari.'; end if; v := v || jsonb_build_object('batas_surat_hari', n); end if;
  if p ? 'pengingat_hari' then n := coalesce((p->>'pengingat_hari')::int, 3);
    if n < 0 or n > 14 then raise exception 'Pengingat jatuh tempo antara 0 dan 14 hari sebelumnya.'; end if; v := v || jsonb_build_object('pengingat_hari', n); end if;
  if p ? 'catatan_kuitansi' then v := v || jsonb_build_object('catatan_kuitansi', left(trim(coalesce(p->>'catatan_kuitansi', '')), 300)); end if;
  if p ? 'catatan_tagihan' then v := v || jsonb_build_object('catatan_tagihan', left(trim(coalesce(p->>'catatan_tagihan', '')), 500)); end if;
  insert into institution_settings (kunci, nilai, updated_by) values ('keuangan', v, public.saya())
  on conflict (kunci) do update set nilai = excluded.nilai, updated_at = now(), updated_by = excluded.updated_by;
  return public._pengaturan_keuangan();
end $$;

-- ---------------------------------------------------------------------
-- 2. TABEL
-- ---------------------------------------------------------------------
create table if not exists public.fee_types (
  id          uuid primary key default gen_random_uuid(),
  kode        text not null constraint fee_types_kode_unik unique constraint fee_types_kode_check check (kode ~ '^[A-Z0-9_]{2,20}$'),
  nama        text not null constraint fee_types_nama_check check (length(trim(nama)) >= 3),
  siklus      text not null constraint fee_types_siklus_check check (siklus in ('sekali','tahunan','bulanan')),
  nominal     numeric(14,0) not null default 0 constraint fee_types_nominal_check check (nominal >= 0),
  santri_baru boolean not null default false,          -- bawaan sasaran: hanya santri baru (mis. uang pangkal)
  keterangan  text,
  aktif       boolean not null default true,
  urutan      int not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table if not exists public.fee_rates (
  id          uuid primary key default gen_random_uuid(),
  fee_type_id uuid not null references public.fee_types(id) on delete cascade,
  jenjang     text constraint fee_rates_jenjang_check check (jenjang in ('wustha','sma')),
  tingkat     smallint constraint fee_rates_tingkat_check check (tingkat between 7 and 12),
  nominal     numeric(14,0) not null constraint fee_rates_nominal_check check (nominal >= 0),
  created_at  timestamptz not null default now(),
  constraint fee_rates_sasaran check (jenjang is not null or tingkat is not null)
);
create unique index if not exists fee_rates_unik on public.fee_rates (fee_type_id, coalesce(jenjang, ''), coalesce(tingkat, 0));

create table if not exists public.fee_subsidies (
  id          uuid primary key default gen_random_uuid(),
  student_id  uuid not null references public.students(id) on delete cascade,
  fee_type_id uuid references public.fee_types(id) on delete cascade,     -- kosong = semua jenis biaya
  jenis       text not null constraint fee_subsidies_jenis_check check (jenis in ('persen','nominal')),
  nilai       numeric(14,2) not null constraint fee_subsidies_nilai_check check (nilai > 0),
  mulai       date not null default public.hari_ini(),
  sampai      date,
  alasan      text not null constraint fee_subsidies_alasan_check check (length(trim(alasan)) >= 3),
  aktif       boolean not null default true,
  dibuat_oleh uuid references public.employees(id) on delete set null,
  created_at  timestamptz not null default now(),
  constraint fee_subsidies_persen check (jenis <> 'persen' or nilai <= 100),
  constraint fee_subsidies_rentang check (sampai is null or sampai >= mulai)
);
create index if not exists fee_subsidies_santri_idx on public.fee_subsidies (student_id);

create table if not exists public.bills (
  id              uuid primary key default gen_random_uuid(),
  student_id      uuid not null references public.students(id) on delete restrict,
  fee_type_id     uuid not null references public.fee_types(id) on delete restrict,
  kunci_periode   text not null,                 -- bulanan: YYYY-MM · tahunan: nama TA (2026/2027) · sekali: 'sekali'
  nama            text not null,                 -- mis. "SPP Oktober 2026"
  tanggal_tagih   date not null default public.hari_ini(),
  jatuh_tempo     date not null,
  standar         numeric(14,0) not null constraint bills_standar_check check (standar >= 0),
  potongan        numeric(14,0) not null default 0 constraint bills_potongan_check check (potongan >= 0),
  alasan_potongan text,
  nominal         numeric(14,0) generated always as (greatest(standar - potongan, 0)) stored,
  dibayar         numeric(14,0) not null default 0,
  status          text not null default 'belum' constraint bills_status_check check (status in ('belum','sebagian','lunas','batal')),
  catatan         text,
  alasan_batal    text,
  dibatalkan_pada timestamptz,
  dibuat_oleh     uuid references public.employees(id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint bills_potongan_wajar check (potongan <= standar)
);
create unique index if not exists bills_unik on public.bills (student_id, fee_type_id, kunci_periode) where status <> 'batal';
create index if not exists bills_santri_idx on public.bills (student_id, status);
create index if not exists bills_tempo_idx on public.bills (jatuh_tempo) where status in ('belum','sebagian');

do $$
declare t text;
begin
  foreach t in array array['fee_types','fee_rates','fee_subsidies','bills'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists baca on public.%I', t);
    execute format('create policy baca on public.%I for select to authenticated using (public.boleh_lihat_keuangan())', t);
    execute format('drop trigger if exists zz_audit on public.%I', t);
    execute format('create trigger zz_audit after insert or update or delete on public.%I for each row execute function public.tg_audit()', t);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- 3. HAK KEUANGAN
-- ---------------------------------------------------------------------
create or replace function public._pejabat_keuangan()
returns setof uuid language sql stable security definer set search_path = public as $$
  select sa.employee_id from sensitive_access sa join employees e on e.id = sa.employee_id
   where sa.fitur = 'keuangan' and sa.penanda_tangan and sa.tingkat = 'kelola' and e.status_keaktifan = 'aktif' and e.status_akun = 'aktif'
   order by sa.created_at
$$;

create or replace function public.hak_keuangan()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_ttd boolean := public.saya() in (select public._pejabat_keuangan());
begin
  return jsonb_build_object('kelola', public.boleh_kelola_keuangan(), 'lihat', public.boleh_lihat_keuangan(), 'superadmin', public.is_superadmin(),
    'penanda_tangan', v_ttd, 'jabatan_ttd', case when v_ttd then public._jabatan_ttd('keuangan', public.saya()) end,
    'ada_penanda_tangan', exists (select 1 from public._pejabat_keuangan()),
    'pengaturan', case when public.boleh_lihat_keuangan() then public._pengaturan_keuangan() else '{}'::jsonb end);
end $$;

-- ---------------------------------------------------------------------
-- 4. JENIS BIAYA DAN TARIF
-- ---------------------------------------------------------------------
/** Tarif standar seorang santri: tarif tingkat > tarif jenjang > nominal standar jenis biaya. */
create or replace function public._tarif_biaya(p_fee uuid, p_jenjang text, p_tingkat smallint)
returns numeric language sql stable security definer set search_path = public as $$
  select coalesce(
    (select nominal from fee_rates where fee_type_id = p_fee and tingkat = p_tingkat and (jenjang is null or jenjang = p_jenjang) limit 1),
    (select nominal from fee_rates where fee_type_id = p_fee and tingkat is null and jenjang = p_jenjang limit 1),
    (select nominal from fee_types where id = p_fee))
$$;

create or replace function public.daftar_jenis_biaya()
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform public._wajib_lihat_keuangan();
  return coalesce((select jsonb_agg(to_jsonb(f) || jsonb_build_object(
      'tarif', coalesce((select jsonb_agg(jsonb_build_object('id', r.id, 'jenjang', r.jenjang, 'tingkat', r.tingkat, 'nominal', r.nominal)
                                          order by r.jenjang nulls first, r.tingkat nulls first) from fee_rates r where r.fee_type_id = f.id), '[]'::jsonb),
      'jumlah_tagihan', (select count(*) from bills b where b.fee_type_id = f.id and b.status <> 'batal'))
    order by f.aktif desc, f.urutan, f.nama) from fee_types f), '[]'::jsonb);
end $$;

create or replace function public.simpan_jenis_biaya(p jsonb)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v_id uuid := nullif(p->>'id', '')::uuid; r jsonb;
begin
  perform public._wajib_kelola_keuangan();
  if coalesce(p->>'siklus', '') not in ('sekali','tahunan','bulanan') then raise exception 'Pilih siklus: sekali, tahunan, atau bulanan.'; end if;
  if v_id is null then
    insert into fee_types (kode, nama, siklus, nominal, santri_baru, keterangan, aktif, urutan)
    values (upper(trim(p->>'kode')), trim(p->>'nama'), p->>'siklus', coalesce((p->>'nominal')::numeric, 0),
            coalesce((p->>'santri_baru')::boolean, false), nullif(trim(coalesce(p->>'keterangan', '')), ''), coalesce((p->>'aktif')::boolean, true),
            coalesce((p->>'urutan')::int, (select coalesce(max(urutan), 0) + 1 from fee_types)))
    returning id into v_id;
  else
    if (select siklus from fee_types where id = v_id) <> p->>'siklus' and exists (select 1 from bills where fee_type_id = v_id) then
      raise exception 'Siklus tidak dapat diubah karena jenis biaya ini sudah dipakai pada tagihan.'; end if;
    update fee_types set kode = upper(trim(p->>'kode')), nama = trim(p->>'nama'), siklus = p->>'siklus', nominal = coalesce((p->>'nominal')::numeric, 0),
      santri_baru = coalesce((p->>'santri_baru')::boolean, false), keterangan = nullif(trim(coalesce(p->>'keterangan', '')), ''),
      aktif = coalesce((p->>'aktif')::boolean, true), urutan = coalesce((p->>'urutan')::int, urutan), updated_at = now()
     where id = v_id;
    if not found then raise exception 'Jenis biaya tidak ditemukan.'; end if;
  end if;
  if p ? 'tarif' then
    delete from fee_rates where fee_type_id = v_id;
    for r in select * from jsonb_array_elements(coalesce(p->'tarif', '[]'::jsonb)) loop
      if nullif(r->>'jenjang', '') is null and nullif(r->>'tingkat', '') is null then continue; end if;
      insert into fee_rates (fee_type_id, jenjang, tingkat, nominal)
      values (v_id, nullif(r->>'jenjang', ''), nullif(r->>'tingkat', '')::smallint, coalesce((r->>'nominal')::numeric, 0));
    end loop;
  end if;
  return v_id;
exception when unique_violation then
  raise exception 'Kode jenis biaya atau tarif per jenjang/tingkat ganda.';
end $$;

/** Hapus jenis biaya yang belum dipakai; bila sudah dipakai, dinonaktifkan. Hasil: 'dihapus' | 'dinonaktifkan'. */
create or replace function public.hapus_jenis_biaya(p_id uuid)
returns text language plpgsql volatile security definer set search_path = public as $$
begin
  perform public._wajib_kelola_keuangan();
  if exists (select 1 from bills where fee_type_id = p_id) then
    update fee_types set aktif = false, updated_at = now() where id = p_id; return 'dinonaktifkan';
  end if;
  delete from fee_types where id = p_id; return 'dihapus';
end $$;

-- ---------------------------------------------------------------------
-- 5. SUBSIDI SANTRI
-- ---------------------------------------------------------------------
/** Potongan subsidi untuk satu tagihan (tanggal acuan = awal periode tagihan). Hasil {potongan, alasan}. */
create or replace function public._potongan_subsidi(p_sid uuid, p_fee uuid, p_tanggal date, p_standar numeric)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare s record; v_pot numeric := 0; v_alasan text[] := '{}';
begin
  for s in select * from fee_subsidies where student_id = p_sid and aktif and (fee_type_id is null or fee_type_id = p_fee)
             and mulai <= p_tanggal and (sampai is null or sampai >= p_tanggal) order by jenis desc, created_at loop
    -- persen dihitung dari standar, nominal dikurangkan langsung
    v_pot := v_pot + case when s.jenis = 'persen' then round(p_standar * s.nilai / 100) else s.nilai end;
    v_alasan := array_append(v_alasan, s.alasan || ' (' || case when s.jenis = 'persen' then trim(to_char(s.nilai, 'FM990.##')) || '%' else public._rupiah(s.nilai) end || ')');
  end loop;
  return jsonb_build_object('potongan', round(least(v_pot, p_standar)), 'alasan', nullif(array_to_string(v_alasan, '; '), ''));
end $$;

create or replace function public.simpan_subsidi(p jsonb)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v_id uuid := nullif(p->>'id', '')::uuid;
begin
  perform public._wajib_kelola_keuangan();
  if v_id is null then
    insert into fee_subsidies (student_id, fee_type_id, jenis, nilai, mulai, sampai, alasan, aktif, dibuat_oleh)
    values ((p->>'student_id')::uuid, nullif(p->>'fee_type_id', '')::uuid, p->>'jenis', (p->>'nilai')::numeric,
            coalesce(nullif(p->>'mulai', '')::date, public.hari_ini()), nullif(p->>'sampai', '')::date, trim(p->>'alasan'),
            coalesce((p->>'aktif')::boolean, true), public.saya())
    returning id into v_id;
  else
    update fee_subsidies set fee_type_id = nullif(p->>'fee_type_id', '')::uuid, jenis = p->>'jenis', nilai = (p->>'nilai')::numeric,
      mulai = coalesce(nullif(p->>'mulai', '')::date, mulai), sampai = nullif(p->>'sampai', '')::date, alasan = trim(p->>'alasan'),
      aktif = coalesce((p->>'aktif')::boolean, true)
     where id = v_id;
  end if;
  return v_id;
end $$;

create or replace function public.hapus_subsidi(p_id uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  perform public._wajib_kelola_keuangan();
  delete from fee_subsidies where id = p_id;
end $$;

create or replace function public.daftar_subsidi()
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform public._wajib_lihat_keuangan();
  return coalesce((select jsonb_agg(to_jsonb(s) || jsonb_build_object('nis', st.nis, 'nama', st.nama_lengkap, 'jk', st.jenis_kelamin,
      'jenjang', st.jenjang, 'tingkat', st.tingkat, 'kelas', public._kelas_santri(st.id),
      'jenis_biaya', (select nama from fee_types where id = s.fee_type_id),
      'berlaku', s.aktif and s.mulai <= public.hari_ini() and (s.sampai is null or s.sampai >= public.hari_ini()),
      'oleh', (select nama_lengkap from employees where id = s.dibuat_oleh))
    order by st.nama_lengkap, s.mulai desc) from fee_subsidies s join students st on st.id = s.student_id), '[]'::jsonb);
end $$;

-- ---------------------------------------------------------------------
-- 6. TAGIHAN MASSAL
-- ---------------------------------------------------------------------
/** Periode tagihan untuk satu jenis biaya. p: { bulan: ['2026-10',...] (bulanan) | academic_year_id (tahunan) }.
    Hasil baris: kunci, nama periode, tanggal acuan, jatuh tempo bawaan. */
create or replace function public._periode_tagihan(f fee_types, p jsonb)
returns table (kunci text, label text, acuan date, tempo date) language plpgsql stable security definer set search_path = public as $$
declare b text; ta academic_years; v_hari int := coalesce((public._pengaturan_keuangan()->>'jatuh_tempo_hari')::int, 10);
  v_tempo date := nullif(p->>'jatuh_tempo', '')::date;
begin
  if f.siklus = 'bulanan' then
    if jsonb_array_length(coalesce(p->'bulan', '[]'::jsonb)) = 0 then raise exception 'Pilih paling sedikit satu bulan tagihan.'; end if;
    for b in select jsonb_array_elements_text(p->'bulan') loop
      if b !~ '^[0-9]{4}-(0[1-9]|1[0-2])$' then raise exception 'Bulan tagihan tidak sah: %', b; end if;
      kunci := b; acuan := (b || '-01')::date;
      label := f.nama || ' ' || public.nama_bulan_periode(extract(year from acuan)::int, extract(month from acuan)::int);
      tempo := coalesce(case when jsonb_array_length(p->'bulan') = 1 then v_tempo end, acuan + (v_hari - 1));
      return next;
    end loop;
  elsif f.siklus = 'tahunan' then
    select * into ta from academic_years where id = coalesce(nullif(p->>'academic_year_id', '')::uuid, (select id from academic_years where aktif));
    if ta.id is null then raise exception 'Pilih tahun ajaran tagihan.'; end if;
    kunci := ta.nama; label := f.nama || ' ' || ta.nama; acuan := ta.mulai;
    tempo := coalesce(v_tempo, greatest(ta.mulai, public.hari_ini()) + 30); return next;
  else
    kunci := 'sekali'; label := f.nama; acuan := public.hari_ini(); tempo := coalesce(v_tempo, public.hari_ini() + 30); return next;
  end if;
end $$;

/** Santri sasaran tagihan. p.sasaran: { jenjang, tingkat:[..], group_id, student_ids:[..], hanya_baru } — semua santri aktif bila kosong. */
create or replace function public._sasaran_tagihan(p jsonb)
returns setof uuid language plpgsql stable security definer set search_path = public as $$
declare s jsonb := coalesce(p->'sasaran', '{}'::jsonb); v_thn int := extract(year from public.hari_ini())::int;
begin
  return query
  select st.id from students st
   where st.status = 'aktif'
     and (jsonb_array_length(coalesce(s->'student_ids', '[]'::jsonb)) = 0 or st.id in (select (jsonb_array_elements_text(s->'student_ids'))::uuid))
     and (nullif(s->>'jenjang', '') is null or st.jenjang = s->>'jenjang')
     and (jsonb_array_length(coalesce(s->'tingkat', '[]'::jsonb)) = 0 or st.tingkat in (select (jsonb_array_elements_text(s->'tingkat'))::smallint))
     and (nullif(s->>'group_id', '') is null or st.id in (select m.student_id from group_members m where m.group_id = (s->>'group_id')::uuid and m.selesai is null))
     and (not coalesce((s->>'hanya_baru')::boolean, false) or st.tahun_masuk = (select extract(year from mulai)::int from academic_years where aktif)
          or st.tahun_masuk = v_thn);
end $$;

create or replace function public.pratinjau_tagihan(p jsonb)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare f fee_types;
begin
  perform public._wajib_kelola_keuangan();
  select * into f from fee_types where id = (p->>'fee_type_id')::uuid;
  if f.id is null then raise exception 'Pilih jenis biaya.'; end if;
  return jsonb_build_object('periode', (select coalesce(jsonb_agg(jsonb_build_object('kunci', x.kunci, 'label', x.label, 'jatuh_tempo', x.tempo)), '[]'::jsonb)
                                        from public._periode_tagihan(f, p) x),
    'baris', coalesce((select jsonb_agg(r order by r->>'nama', r->>'kunci') from (
      select jsonb_build_object('student_id', st.id, 'nis', st.nis, 'nama', st.nama_lengkap, 'jk', st.jenis_kelamin, 'jenjang', st.jenjang, 'tingkat', st.tingkat,
             'kelas', public._kelas_santri(st.id), 'kunci', x.kunci, 'label', x.label, 'standar', t.standar,
             'potongan', (s.v->>'potongan')::numeric, 'alasan_potongan', s.v->>'alasan', 'nominal', t.standar - (s.v->>'potongan')::numeric,
             'ada', exists (select 1 from bills b where b.student_id = st.id and b.fee_type_id = f.id and b.kunci_periode = x.kunci and b.status <> 'batal')) r
        from students st
        cross join public._periode_tagihan(f, p) x
        cross join lateral (select public._tarif_biaya(f.id, st.jenjang, st.tingkat) standar) t
        cross join lateral (select public._potongan_subsidi(st.id, f.id, x.acuan, t.standar) v) s
       where st.id in (select public._sasaran_tagihan(p))) q), '[]'::jsonb));
end $$;

/** Buat tagihan massal. Tagihan yang sudah ada (jenis + periode + santri) dilewati. Hasil {dibuat, dilewati, nominal}. */
create or replace function public.buat_tagihan(p jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare f fee_types; v_dibuat int := 0; v_lewat int := 0; v_total numeric := 0; x record; st students; v_std numeric; v_sub jsonb;
begin
  perform public._wajib_kelola_keuangan();
  select * into f from fee_types where id = (p->>'fee_type_id')::uuid;
  if f.id is null then raise exception 'Pilih jenis biaya.'; end if;
  if not f.aktif then raise exception 'Jenis biaya ini nonaktif.'; end if;
  for x in select * from public._periode_tagihan(f, p) loop
    for st in select * from students where id in (select public._sasaran_tagihan(p)) loop
      if exists (select 1 from bills b where b.student_id = st.id and b.fee_type_id = f.id and b.kunci_periode = x.kunci and b.status <> 'batal') then
        v_lewat := v_lewat + 1; continue; end if;
      v_std := public._tarif_biaya(f.id, st.jenjang, st.tingkat);
      v_sub := public._potongan_subsidi(st.id, f.id, x.acuan, v_std);
      insert into bills (student_id, fee_type_id, kunci_periode, nama, jatuh_tempo, standar, potongan, alasan_potongan, status, catatan, dibuat_oleh)
      values (st.id, f.id, x.kunci, x.label, x.tempo, v_std, (v_sub->>'potongan')::numeric, v_sub->>'alasan',
              case when v_std - (v_sub->>'potongan')::numeric <= 0 then 'lunas' else 'belum' end, nullif(trim(coalesce(p->>'catatan', '')), ''), public.saya());
      v_dibuat := v_dibuat + 1; v_total := v_total + v_std - (v_sub->>'potongan')::numeric;
    end loop;
  end loop;
  perform public.catat_audit('buat_tagihan', 'bills', f.id::text, v_dibuat || ' tagihan ' || f.nama || ' dibuat; ' || v_lewat || ' dilewati', null);
  return jsonb_build_object('dibuat', v_dibuat, 'dilewati', v_lewat, 'nominal', v_total);
end $$;

/** Status tagihan dari nominal dan pembayarannya. */
create or replace function public._segarkan_tagihan(p_bill uuid)
returns void language sql volatile security definer set search_path = public as $$
  update bills set status = case when status = 'batal' then 'batal' when dibayar >= nominal then 'lunas' when dibayar > 0 then 'sebagian' else 'belum' end,
                   updated_at = now()
   where id = p_bill
$$;

/** Ubah satu tagihan (standar, potongan dan alasannya, jatuh tempo, catatan). */
create or replace function public.ubah_tagihan(p_id uuid, p jsonb)
returns void language plpgsql volatile security definer set search_path = public as $$
declare b bills;
begin
  perform public._wajib_kelola_keuangan();
  select * into b from bills where id = p_id for update;
  if b.id is null or b.status = 'batal' then raise exception 'Tagihan tidak ditemukan atau sudah dibatalkan.'; end if;
  if length(trim(coalesce(p->>'alasan', ''))) < 3 then raise exception 'Tulis alasan perubahan tagihan.'; end if;
  update bills set standar = coalesce((p->>'standar')::numeric, standar), potongan = coalesce((p->>'potongan')::numeric, potongan),
    alasan_potongan = case when p ? 'alasan_potongan' then nullif(trim(p->>'alasan_potongan'), '') else alasan_potongan end,
    jatuh_tempo = coalesce(nullif(p->>'jatuh_tempo', '')::date, jatuh_tempo),
    catatan = trim(both ' ' from coalesce(catatan || E'\n', '') || to_char(now() at time zone 'Asia/Makassar', 'DD/MM/YYYY') || ': ' || trim(p->>'alasan'))
   where id = p_id;
  if (select nominal < dibayar from bills where id = p_id) then raise exception 'Tagihan tidak boleh lebih kecil dari jumlah yang sudah dibayar (%).', public._rupiah(b.dibayar); end if;
  perform public._segarkan_tagihan(p_id);
end $$;

create or replace function public.batalkan_tagihan(p_id uuid, p_alasan text)
returns void language plpgsql volatile security definer set search_path = public as $$
declare b bills;
begin
  perform public._wajib_kelola_keuangan();
  select * into b from bills where id = p_id;
  if b.id is null or b.status = 'batal' then raise exception 'Tagihan tidak ditemukan atau sudah dibatalkan.'; end if;
  if b.dibayar > 0 then raise exception 'Tagihan ini sudah dibayar %. Batalkan pembayarannya dulu.', public._rupiah(b.dibayar); end if;
  if length(trim(coalesce(p_alasan, ''))) < 3 then raise exception 'Tulis alasan pembatalan.'; end if;
  update bills set status = 'batal', alasan_batal = trim(p_alasan), dibatalkan_pada = now(), updated_at = now() where id = p_id;
end $$;

/** Daftar tagihan dengan saringan: fee_type_id, kunci_periode, status ('tunggak' = belum/sebagian), jenjang, group_id, q. */
create or replace function public.daftar_tagihan(p jsonb)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform public._wajib_lihat_keuangan();
  return coalesce((select jsonb_agg(jsonb_build_object('id', b.id, 'student_id', b.student_id, 'nis', st.nis, 'nama', st.nama_lengkap, 'jk', st.jenis_kelamin,
      'jenjang', st.jenjang, 'tingkat', st.tingkat, 'kelas', public._kelas_santri(st.id), 'fee_type_id', b.fee_type_id, 'jenis', f.nama, 'siklus', f.siklus,
      'kunci_periode', b.kunci_periode, 'tagihan', b.nama, 'tanggal_tagih', b.tanggal_tagih, 'jatuh_tempo', b.jatuh_tempo, 'standar', b.standar,
      'potongan', b.potongan, 'alasan_potongan', b.alasan_potongan, 'nominal', b.nominal, 'dibayar', b.dibayar, 'sisa', b.nominal - b.dibayar,
      'status', b.status, 'catatan', b.catatan, 'lewat', b.status in ('belum','sebagian') and b.jatuh_tempo < public.hari_ini())
    order by st.nama_lengkap, b.jatuh_tempo)
    from bills b join students st on st.id = b.student_id join fee_types f on f.id = b.fee_type_id
   where (nullif(p->>'fee_type_id', '') is null or b.fee_type_id = (p->>'fee_type_id')::uuid)
     and (nullif(p->>'kunci_periode', '') is null or b.kunci_periode = p->>'kunci_periode')
     and (nullif(p->>'student_id', '') is null or b.student_id = (p->>'student_id')::uuid)
     and (case coalesce(p->>'status', '') when '' then b.status <> 'batal' when 'tunggak' then b.status in ('belum','sebagian')
            when 'lewat' then b.status in ('belum','sebagian') and b.jatuh_tempo < public.hari_ini() else b.status = p->>'status' end)
     and (nullif(p->>'jenjang', '') is null or st.jenjang = p->>'jenjang')
     and (nullif(p->>'group_id', '') is null or st.id in (select m.student_id from group_members m where m.group_id = (p->>'group_id')::uuid and m.selesai is null))
     and (nullif(p->>'q', '') is null or st.nama_lengkap ilike '%' || (p->>'q') || '%' or st.nis like (p->>'q') || '%')), '[]'::jsonb);
end $$;

-- ---------------------------------------------------------------------
-- 7. HAK EKSEKUSI
-- ---------------------------------------------------------------------
do $$
declare f text;
begin
  foreach f in array array['pengaturan_keuangan()','simpan_pengaturan_keuangan(jsonb)','hak_keuangan()','daftar_jenis_biaya()','simpan_jenis_biaya(jsonb)',
      'hapus_jenis_biaya(uuid)','simpan_subsidi(jsonb)','hapus_subsidi(uuid)','daftar_subsidi()','pratinjau_tagihan(jsonb)','buat_tagihan(jsonb)',
      'ubah_tagihan(uuid,jsonb)','batalkan_tagihan(uuid,text)','daftar_tagihan(jsonb)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  foreach f in array array['_kelas_santri(uuid)','_kontak_wali(uuid)','_wajib_kelola_keuangan()','_wajib_lihat_keuangan()','_pengaturan_keuangan()',
      '_pejabat_keuangan()','_tarif_biaya(uuid,text,smallint)','_potongan_subsidi(uuid,uuid,date,numeric)','_periode_tagihan(fee_types,jsonb)',
      '_sasaran_tagihan(jsonb)','_segarkan_tagihan(uuid)'] loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- 8. PEMERIKSAAN (hasil yang benar: semua "Sesuai")
-- ---------------------------------------------------------------------
select '1. Tabel jenis biaya, tarif, subsidi, tagihan (RLS)' as pemeriksaan,
       case when (select count(*) from pg_tables where tablename in ('fee_types','fee_rates','fee_subsidies','bills') and rowsecurity) = 4 then 'Sesuai' else 'Periksa' end as hasil
union all select '2. Fungsi tagihan massal',
       case when (select count(*) from pg_proc where proname in ('pratinjau_tagihan','buat_tagihan','daftar_tagihan')) = 3 then 'Sesuai' else 'Periksa' end
union all select '3. Hak keuangan dari penunjukan superadmin',
       case when pg_get_functiondef('public.boleh_kelola_keuangan()'::regprocedure) like '%_akses_sensitif%' then 'Sesuai' else 'Periksa: jalankan 7500 dulu' end
union all select '4. Format rupiah', case when public._rupiah(1250000) = 'Rp1.250.000' then 'Sesuai' else 'Periksa' end;
