-- SIMKA PRO | supabase/migrations/20261012008000_keuangan_riwayat_putra_putri.sql | v1.0 | Fase 13 – Catatan keuangan tahun-tahun lalu dan tarif putra/putri | 12/10/2026
-- =====================================================================
-- SIMKA PRO · Migrasi 80: Keuangan santri – riwayat tahun lalu dan perbedaan putra/putri
-- RIWAYAT (santri kelas 8/9/11/12 sudah membayar sejak kelas 7/10)
--   1. Tagihan boleh dibuat untuk tahun ajaran yang sudah lewat (bulan-bulan TA lalu, tahunan/semesteran TA lalu).
--      Kelas santri pada periode itu dihitung mundur dari kelas sekarang (kelas 9 sekarang = kelas 7 pada TA dua tahun lalu;
--      kelas 10 → 9 berpindah jenjang SMA → Wustha). Santri yang belum masuk pada periode itu dilewati.
--      Tarif, batas berlaku jenis biaya, dan sasaran jenjang/kelas memakai kelas pada periode tagihan.
--   2. "Catatan pembayaran lama": pembayaran tahun lalu dicatat tanpa menerbitkan kuitansi bernomor (kuitansi aslinya sudah
--      diberikan dahulu), ditandai riwayat = true.
--   3. impor_riwayat_keuangan : impor Excel (NIS, kode biaya, periode, nominal, dibayar, tanggal bayar, cara, keterangan)
--      → tagihan dibuat bila belum ada, pembayaran dicatat sebagai catatan lama. Mode uji (pratinjau) tanpa menyimpan.
-- PUTRA/PUTRI
--   4. Tarif khusus per jenis kelamin (tarif paling khusus dipakai: kelas > jenjang > jenis kelamin), mis. SPP putri berbeda.
--   5. Jenis biaya dapat dibatasi hanya untuk putra atau putri; sasaran tagihan dapat disaring putra/putri.
-- Jalankan SETELAH migrasi 7900. Aman dijalankan ulang.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. KOLOM BARU
-- ---------------------------------------------------------------------
alter table public.fee_rates add column if not exists jenis_kelamin text;
alter table public.fee_rates drop constraint if exists fee_rates_jk_check;
alter table public.fee_rates add constraint fee_rates_jk_check check (jenis_kelamin in ('L','P'));
alter table public.fee_rates drop constraint if exists fee_rates_sasaran;
alter table public.fee_rates add constraint fee_rates_sasaran check (jenjang is not null or tingkat is not null or jenis_kelamin is not null);
drop index if exists public.fee_rates_unik;
create unique index if not exists fee_rates_unik2 on public.fee_rates (fee_type_id, coalesce(jenjang, ''), coalesce(tingkat, 0), coalesce(jenis_kelamin, ''));

alter table public.fee_types add column if not exists berlaku_jk text;
alter table public.fee_types drop constraint if exists fee_types_berlaku_jk_check;
alter table public.fee_types add constraint fee_types_berlaku_jk_check check (berlaku_jk in ('L','P'));

alter table public.payments add column if not exists riwayat boolean not null default false;   -- catatan pembayaran lama (tanpa kuitansi baru)

-- ---------------------------------------------------------------------
-- 2. TAHUN AJARAN DAN KELAS PADA SUATU PERIODE
-- ---------------------------------------------------------------------
/** Tahun awal tahun ajaran yang memuat tanggal (TA 2025/2026 → 2025). Memakai data tahun ajaran bila ada, selain itu Juli–Juni. */
create or replace function public._tahun_ta(p_tgl date)
returns int language sql stable security definer set search_path = public as $$
  select coalesce((select extract(year from mulai)::int from academic_years where p_tgl between mulai and selesai order by mulai desc limit 1),
                  extract(year from p_tgl)::int - case when extract(month from p_tgl) < 7 then 1 else 0 end)
$$;
create or replace function public._tahun_ta_aktif()
returns int language sql stable security definer set search_path = public as $$
  select coalesce((select extract(year from mulai)::int from academic_years where aktif limit 1), public._tahun_ta(public.hari_ini()))
$$;

/** Jenjang dan kelas santri pada periode acuan, dihitung mundur dari kelas sekarang. Kosong (null) bila belum masuk. */
create or replace function public._kelas_pada(p_tingkat smallint, p_jenjang text, p_tahun_masuk smallint, p_acuan date,
                                              out jenjang text, out tingkat smallint)
language plpgsql stable security definer set search_path = public as $$
declare v_ta int := public._tahun_ta(p_acuan); v_selisih int := greatest(public._tahun_ta_aktif() - public._tahun_ta(p_acuan), 0);
begin
  if p_tahun_masuk is not null and p_tahun_masuk > v_ta then return; end if;
  if v_selisih = 0 then jenjang := p_jenjang; tingkat := p_tingkat; return; end if;
  if p_tingkat - v_selisih < 7 then return; end if;
  tingkat := p_tingkat - v_selisih;
  jenjang := case when tingkat >= 10 then 'sma' else 'wustha' end;
end $$;

-- ---------------------------------------------------------------------
-- 3. TARIF: kelas > jenjang > jenis kelamin (tarif paling khusus)
-- ---------------------------------------------------------------------
create or replace function public._tarif_biaya(p_fee uuid, p_jenjang text, p_tingkat smallint, p_jk text)
returns numeric language sql stable security definer set search_path = public as $$
  select coalesce(
    (select r.nominal from fee_rates r
      where r.fee_type_id = p_fee
        and (r.tingkat is null or r.tingkat = p_tingkat) and (r.jenjang is null or r.jenjang = p_jenjang)
        and (r.jenis_kelamin is null or r.jenis_kelamin = p_jk)
      order by (r.tingkat is not null)::int * 4 + (r.jenjang is not null)::int * 2 + (r.jenis_kelamin is not null)::int desc limit 1),
    (select nominal from fee_types where id = p_fee))
$$;
create or replace function public._tarif_biaya(p_fee uuid, p_jenjang text, p_tingkat smallint)
returns numeric language sql stable security definer set search_path = public as $$
  select public._tarif_biaya(p_fee, p_jenjang, p_tingkat, null::text)
$$;

-- ---------------------------------------------------------------------
-- 4. JENIS BIAYA (tarif per jenis kelamin, berlaku putra/putri)
-- ---------------------------------------------------------------------
create or replace function public.daftar_jenis_biaya()
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform public._wajib_lihat_keuangan();
  return coalesce((select jsonb_agg(to_jsonb(f) || jsonb_build_object(
      'tarif', coalesce((select jsonb_agg(jsonb_build_object('id', r.id, 'jenjang', r.jenjang, 'tingkat', r.tingkat, 'jenis_kelamin', r.jenis_kelamin, 'nominal', r.nominal)
                                          order by r.jenjang nulls first, r.tingkat nulls first, r.jenis_kelamin nulls first) from fee_rates r where r.fee_type_id = f.id), '[]'::jsonb),
      'jumlah_tagihan', (select count(*) from bills b where b.fee_type_id = f.id and b.status <> 'batal'))
    order by f.aktif desc, f.urutan, f.nama) from fee_types f), '[]'::jsonb);
end $$;

create or replace function public.simpan_jenis_biaya(p jsonb)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v_id uuid := nullif(p->>'id', '')::uuid; r jsonb;
  v_jj text[] := nullif(array(select jsonb_array_elements_text(coalesce(p->'berlaku_jenjang', '[]'::jsonb))), '{}');
  v_tk smallint[] := nullif(array(select (jsonb_array_elements_text(coalesce(p->'berlaku_tingkat', '[]'::jsonb)))::smallint), '{}');
  v_jk text := nullif(p->>'berlaku_jk', '');
begin
  perform public._wajib_kelola_keuangan();
  if coalesce(p->>'siklus', '') not in ('sekali','semesteran','tahunan','bulanan') then raise exception 'Pilih siklus: bulanan, semesteran, tahunan, atau sekali.'; end if;
  if v_jj is not null and exists (select 1 from unnest(v_jj) j where j not in ('wustha','sma')) then raise exception 'Jenjang tidak dikenal.'; end if;
  if v_jk is not null and v_jk not in ('L','P') then raise exception 'Pilihan putra/putri tidak dikenal.'; end if;
  if v_id is null then
    insert into fee_types (kode, nama, siklus, nominal, santri_baru, keterangan, aktif, urutan, berlaku_jenjang, berlaku_tingkat, berlaku_jk)
    values (upper(trim(p->>'kode')), trim(p->>'nama'), p->>'siklus', coalesce((p->>'nominal')::numeric, 0),
            coalesce((p->>'santri_baru')::boolean, false), nullif(trim(coalesce(p->>'keterangan', '')), ''), coalesce((p->>'aktif')::boolean, true),
            coalesce((p->>'urutan')::int, (select coalesce(max(urutan), 0) + 1 from fee_types)), v_jj, v_tk, v_jk)
    returning id into v_id;
  else
    if (select siklus from fee_types where id = v_id) <> p->>'siklus' and exists (select 1 from bills where fee_type_id = v_id) then
      raise exception 'Siklus tidak dapat diubah karena jenis biaya ini sudah dipakai pada tagihan.'; end if;
    update fee_types set kode = upper(trim(p->>'kode')), nama = trim(p->>'nama'), siklus = p->>'siklus', nominal = coalesce((p->>'nominal')::numeric, 0),
      santri_baru = coalesce((p->>'santri_baru')::boolean, false), keterangan = nullif(trim(coalesce(p->>'keterangan', '')), ''),
      aktif = coalesce((p->>'aktif')::boolean, true), urutan = coalesce((p->>'urutan')::int, urutan),
      berlaku_jenjang = v_jj, berlaku_tingkat = v_tk, berlaku_jk = v_jk, updated_at = now()
     where id = v_id;
    if not found then raise exception 'Jenis biaya tidak ditemukan.'; end if;
  end if;
  if p ? 'tarif' then
    delete from fee_rates where fee_type_id = v_id;
    for r in select * from jsonb_array_elements(coalesce(p->'tarif', '[]'::jsonb)) loop
      if nullif(r->>'jenjang', '') is null and nullif(r->>'tingkat', '') is null and nullif(r->>'jenis_kelamin', '') is null then continue; end if;
      insert into fee_rates (fee_type_id, jenjang, tingkat, jenis_kelamin, nominal)
      values (v_id, nullif(r->>'jenjang', ''), nullif(r->>'tingkat', '')::smallint, nullif(r->>'jenis_kelamin', ''), coalesce((r->>'nominal')::numeric, 0));
    end loop;
  end if;
  return v_id;
exception when unique_violation then
  raise exception 'Kode jenis biaya ganda, atau tarif dengan jenjang/kelas/jenis kelamin yang sama tercantum dua kali.';
end $$;

-- ---------------------------------------------------------------------
-- 5. PERIODE DAN SASARAN TAGIHAN
-- ---------------------------------------------------------------------
/** Periode tagihan. Tahunan/semesteran: p.academic_year_id, atau p.tahun_ajaran ("2024/2025") untuk tahun ajaran lalu yang
    belum tercatat di Pengaturan. Jatuh tempo bawaan tahun ajaran lalu = 30 hari sejak awal periode. */
create or replace function public._periode_tagihan(f fee_types, p jsonb)
returns table (kunci text, label text, acuan date, tempo date) language plpgsql stable security definer set search_path = public as $$
declare b text; ta academic_years; v_hari int := coalesce((public._pengaturan_keuangan()->>'jatuh_tempo_hari')::int, 10);
  v_tempo date := nullif(p->>'jatuh_tempo', '')::date; v_sem int; v_nama text := nullif(trim(coalesce(p->>'tahun_ajaran', '')), '');
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
  elsif f.siklus in ('tahunan','semesteran') then
    if nullif(p->>'academic_year_id', '') is not null then select * into ta from academic_years where id = (p->>'academic_year_id')::uuid;
    elsif v_nama is not null then
      select * into ta from academic_years where nama = v_nama;
      if ta.id is null then
        if v_nama !~ '^[0-9]{4}/[0-9]{4}$' or right(v_nama, 4)::int <> left(v_nama, 4)::int + 1 then raise exception 'Tahun ajaran tidak sah: %', v_nama; end if;
        ta.nama := v_nama; ta.mulai := (left(v_nama, 4) || '-07-01')::date; ta.semester := 1;
      end if;
    else select * into ta from academic_years where aktif;
    end if;
    if ta.nama is null then raise exception 'Pilih tahun ajaran tagihan.'; end if;
    if f.siklus = 'tahunan' then
      kunci := ta.nama; label := f.nama || ' ' || ta.nama; acuan := ta.mulai;
    else
      v_sem := coalesce(nullif(p->>'semester', '')::int, ta.semester, 1);
      if v_sem not in (1, 2) then raise exception 'Semester harus 1 (ganjil) atau 2 (genap).'; end if;
      kunci := ta.nama || '-S' || v_sem; label := f.nama || ' Semester ' || case v_sem when 1 then 'Ganjil' else 'Genap' end || ' ' || ta.nama;
      acuan := case v_sem when 1 then ta.mulai else (ta.mulai + interval '6 months')::date end;
    end if;
    tempo := coalesce(v_tempo, case when public._tahun_ta(acuan) < public._tahun_ta_aktif() then acuan + 30 else greatest(acuan, public.hari_ini()) + 30 end);
    return next;
  else
    kunci := 'sekali'; label := f.nama; acuan := public.hari_ini(); tempo := coalesce(v_tempo, public.hari_ini() + 30); return next;
  end if;
end $$;

/** Calon sasaran (tanpa memandang periode): santri aktif, santri tertentu, kelompok tertentu. */
create or replace function public._sasaran_tagihan(p jsonb)
returns setof uuid language plpgsql stable security definer set search_path = public as $$
declare s jsonb := coalesce(p->'sasaran', '{}'::jsonb);
begin
  return query
  select st.id from students st
   where st.status = 'aktif'
     and (jsonb_array_length(coalesce(s->'student_ids', '[]'::jsonb)) = 0 or st.id in (select (jsonb_array_elements_text(s->'student_ids'))::uuid))
     and (nullif(s->>'group_id', '') is null or st.id in (select m.student_id from group_members m where m.group_id = (s->>'group_id')::uuid and m.selesai is null));
end $$;

/** Sasaran pada satu periode beserta jenjang/kelas saat itu: batas berlaku jenis biaya (jenjang, kelas, putra/putri),
    saringan jenjang/kelas/putra-putri pengguna, dan "hanya santri baru" (masuk pada tahun ajaran periode itu). */
create or replace function public._sasaran_periode(p jsonb, p_acuan date)
returns table (student_id uuid, jenjang text, tingkat smallint, jenis_kelamin text)
language plpgsql stable security definer set search_path = public as $$
declare s jsonb := coalesce(p->'sasaran', '{}'::jsonb); f fee_types; v_ta int := public._tahun_ta(p_acuan);
begin
  select * into f from fee_types where id = nullif(p->>'fee_type_id', '')::uuid;
  return query
  select st.id, k.jenjang, k.tingkat, st.jenis_kelamin
    from students st
    cross join lateral public._kelas_pada(st.tingkat, st.jenjang, st.tahun_masuk, p_acuan) k
   where st.id in (select public._sasaran_tagihan(p)) and k.tingkat is not null
     and (f.berlaku_jenjang is null or k.jenjang = any(f.berlaku_jenjang))
     and (f.berlaku_tingkat is null or k.tingkat = any(f.berlaku_tingkat))
     and (f.berlaku_jk is null or st.jenis_kelamin = f.berlaku_jk)
     and (nullif(s->>'jenjang', '') is null or k.jenjang = s->>'jenjang')
     and (jsonb_array_length(coalesce(s->'tingkat', '[]'::jsonb)) = 0 or k.tingkat in (select (jsonb_array_elements_text(s->'tingkat'))::smallint))
     and (nullif(s->>'jk', '') is null or st.jenis_kelamin = s->>'jk')
     and (not coalesce((s->>'hanya_baru')::boolean, false) or st.tahun_masuk = v_ta);
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
      select jsonb_build_object('student_id', st.id, 'nis', st.nis, 'nama', st.nama_lengkap, 'jk', st.jenis_kelamin, 'jenjang', sp.jenjang, 'tingkat', sp.tingkat,
             'tingkat_kini', st.tingkat, 'kelas', public._kelas_santri(st.id), 'kunci', x.kunci, 'label', x.label, 'jatuh_tempo', x.tempo, 'standar', t.standar,
             'potongan', (s.v->>'potongan')::numeric, 'alasan_potongan', s.v->>'alasan', 'nominal', t.standar - (s.v->>'potongan')::numeric,
             'ada', exists (select 1 from bills b where b.student_id = st.id and b.fee_type_id = f.id and b.kunci_periode = x.kunci and b.status <> 'batal')) r
        from public._periode_tagihan(f, p) x
        cross join lateral public._sasaran_periode(p, x.acuan) sp
        join students st on st.id = sp.student_id
        cross join lateral (select public._tarif_biaya(f.id, sp.jenjang, sp.tingkat, sp.jenis_kelamin) standar) t
        cross join lateral (select public._potongan_subsidi(st.id, f.id, x.acuan, t.standar) v) s) q), '[]'::jsonb));
end $$;

/** Buat tagihan massal. Tagihan yang sudah ada (jenis + periode + santri) dilewati. Hasil {dibuat, dilewati, nominal}. */
create or replace function public.buat_tagihan(p jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare f fee_types; v_dibuat int := 0; v_lewat int := 0; v_total numeric := 0; x record; sp record; v_std numeric; v_sub jsonb;
begin
  perform public._wajib_kelola_keuangan();
  select * into f from fee_types where id = (p->>'fee_type_id')::uuid;
  if f.id is null then raise exception 'Pilih jenis biaya.'; end if;
  if not f.aktif then raise exception 'Jenis biaya ini nonaktif.'; end if;
  for x in select * from public._periode_tagihan(f, p) loop
    for sp in select * from public._sasaran_periode(p, x.acuan) loop
      if exists (select 1 from bills b where b.student_id = sp.student_id and b.fee_type_id = f.id and b.kunci_periode = x.kunci and b.status <> 'batal') then
        v_lewat := v_lewat + 1; continue; end if;
      v_std := public._tarif_biaya(f.id, sp.jenjang, sp.tingkat, sp.jenis_kelamin);
      v_sub := public._potongan_subsidi(sp.student_id, f.id, x.acuan, v_std);
      insert into bills (student_id, fee_type_id, kunci_periode, nama, tanggal_tagih, jatuh_tempo, standar, potongan, alasan_potongan, status, catatan, dibuat_oleh)
      values (sp.student_id, f.id, x.kunci, x.label, least(x.acuan, public.hari_ini()), x.tempo, v_std, (v_sub->>'potongan')::numeric, v_sub->>'alasan',
              case when v_std - (v_sub->>'potongan')::numeric <= 0 then 'lunas' else 'belum' end, nullif(trim(coalesce(p->>'catatan', '')), ''), public.saya());
      v_dibuat := v_dibuat + 1; v_total := v_total + v_std - (v_sub->>'potongan')::numeric;
    end loop;
  end loop;
  perform public.catat_audit('buat_tagihan', 'bills', f.id::text, v_dibuat || ' tagihan ' || f.nama || ' dibuat; ' || v_lewat || ' dilewati', null);
  return jsonb_build_object('dibuat', v_dibuat, 'dilewati', v_lewat, 'nominal', v_total);
end $$;

-- ---------------------------------------------------------------------
-- 6. PEMBAYARAN: catatan pembayaran lama (tanpa kuitansi bernomor)
-- ---------------------------------------------------------------------
create or replace function public.catat_pembayaran(p jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare st students; v_tgl date := coalesce(nullif(p->>'tanggal', '')::date, public.hari_ini()); v_id uuid; v_total numeric := 0;
  a jsonb; b bills; v_j numeric; v_sisa numeric; v_alok jsonb := '[]'::jsonb; v_ttd uuid; v_nomor text; v_dok jsonb; v_isi jsonb; x jsonb;
  v_riwayat boolean := coalesce((p->>'riwayat')::boolean, false);
begin
  perform public._wajib_kelola_keuangan();
  select * into st from students where id = (p->>'student_id')::uuid;
  if st.id is null then raise exception 'Santri tidak ditemukan.'; end if;
  if coalesce(p->>'cara', '') not in ('tunai','transfer') then raise exception 'Pilih cara bayar: tunai atau transfer.'; end if;
  if v_tgl > public.hari_ini() then raise exception 'Tanggal pembayaran tidak boleh melewati hari ini.'; end if;
  if not v_riwayat then v_ttd := public._ttd_keuangan(); end if;
  if jsonb_array_length(coalesce(p->'alokasi', '[]'::jsonb)) > 0 then
    for a in select * from jsonb_array_elements(p->'alokasi') loop
      v_j := round(coalesce((a->>'jumlah')::numeric, 0));
      if v_j <= 0 then continue; end if;
      select * into b from bills where id = (a->>'bill_id')::uuid and student_id = st.id for update;
      if b.id is null or b.status = 'batal' then raise exception 'Tagihan tidak ditemukan untuk santri ini.'; end if;
      if v_j > b.nominal - b.dibayar then raise exception '% melebihi sisa tagihan % (%).', public._rupiah(v_j), b.nama, public._rupiah(b.nominal - b.dibayar); end if;
      v_alok := v_alok || jsonb_build_array(jsonb_build_object('bill_id', b.id, 'jumlah', v_j));
      v_total := v_total + v_j;
    end loop;
  else
    v_sisa := round(coalesce((p->>'jumlah')::numeric, 0));
    if v_sisa <= 0 then raise exception 'Isi jumlah pembayaran.'; end if;
    for b in select * from bills where student_id = st.id and status in ('belum','sebagian') order by jatuh_tempo, created_at for update loop
      exit when v_sisa <= 0;
      v_j := least(v_sisa, b.nominal - b.dibayar);
      v_alok := v_alok || jsonb_build_array(jsonb_build_object('bill_id', b.id, 'jumlah', v_j));
      v_total := v_total + v_j; v_sisa := v_sisa - v_j;
    end loop;
    if v_sisa > 0 then raise exception 'Jumlah melebihi seluruh sisa tagihan santri ini; kelebihan %.', public._rupiah(v_sisa); end if;
  end if;
  if v_total <= 0 then raise exception 'Tidak ada tagihan yang dibayar.'; end if;

  insert into payments (student_id, tanggal, cara, rekening_tujuan, penyetor, keterangan, jumlah, bukti_id, dicatat_oleh, riwayat)
  values (st.id, v_tgl, p->>'cara', nullif(trim(coalesce(p->>'rekening_tujuan', '')), ''), nullif(trim(coalesce(p->>'penyetor', '')), ''),
          coalesce(nullif(trim(coalesce(p->>'keterangan', '')), ''), case when v_riwayat then 'Catatan pembayaran lama' end),
          v_total, nullif(p->>'bukti_id', '')::uuid, public.saya(), v_riwayat)
  returning id into v_id;
  for x in select * from jsonb_array_elements(v_alok) loop
    update bills set dibayar = dibayar + (x->>'jumlah')::numeric where id = (x->>'bill_id')::uuid;
    perform public._segarkan_tagihan((x->>'bill_id')::uuid);
    insert into payment_items (payment_id, bill_id, jumlah, sisa_setelah)
    select v_id, b2.id, (x->>'jumlah')::numeric, b2.nominal - b2.dibayar from bills b2 where b2.id = (x->>'bill_id')::uuid;
  end loop;

  if v_riwayat then
    perform public.catat_audit('catat_pembayaran_lama', 'payments', v_id::text,
      'Catatan pembayaran lama ' || public._rupiah(v_total) || ' – ' || st.nama_lengkap || ' (' || to_char(v_tgl, 'DD/MM/YYYY') || ')', null);
    return jsonb_build_object('id', v_id, 'nomor', null, 'kode_validasi', null, 'jumlah', v_total, 'riwayat', true);
  end if;

  perform set_config('simka.nomor_sistem', '1', true);
  v_nomor := public.ambil_nomor('kuitansi', v_tgl, 'D', null, 'pondok')->>'nomor';
  perform set_config('simka.nomor_sistem', '', true);
  v_isi := jsonb_build_object('santri', public._santri_keu(st.id), 'tanggal', v_tgl, 'cara', p->>'cara', 'jumlah', v_total, 'nomor', v_nomor,
    'rincian', (select jsonb_agg(jsonb_build_object('tagihan', b3.nama, 'jumlah', pi.jumlah, 'sisa', pi.sisa_setelah) order by b3.jatuh_tempo)
                  from payment_items pi join bills b3 on b3.id = pi.bill_id where pi.payment_id = v_id));
  v_dok := public._daftarkan_dok_keuangan('kuitansi', 'Kuitansi Pembayaran', v_nomor,
    'Pembayaran ' || public._rupiah(v_total) || ' – ' || (select string_agg(b3.nama, ', ' order by b3.jatuh_tempo) from payment_items pi join bills b3 on b3.id = pi.bill_id where pi.payment_id = v_id),
    st.nama_lengkap || ' (NIS ' || st.nis || ')', to_char(v_tgl, 'DD/MM/YYYY'), 'payments', v_id, '/keuangan/pembayaran?bayar=' || v_id, v_isi, v_ttd);
  update payments set nomor = v_nomor, kode_validasi = v_dok->>'kode', document_id = (v_dok->>'document_id')::uuid where id = v_id;
  return jsonb_build_object('id', v_id, 'nomor', v_nomor, 'kode_validasi', v_dok->>'kode', 'jumlah', v_total);
end $$;

-- daftar_pembayaran memuat penanda riwayat
do $$
declare d text := pg_get_functiondef('public.daftar_pembayaran(jsonb)'::regprocedure);
begin
  if position('''riwayat'', py.riwayat' in d) = 0 then
    execute replace(d, '''status'', py.status,', '''status'', py.status, ''riwayat'', py.riwayat,');
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 7. IMPOR CATATAN KEUANGAN LAMA (Excel)
-- ---------------------------------------------------------------------
/** p: { uji: bool, baris: [{ nis, kode, periode, nominal, dibayar, tanggal_bayar, cara, keterangan }] }
    periode: bulanan "2025-07" atau "07/2025"; tahunan "2024/2025"; semesteran "2024/2025-S1" (S2, Ganjil, Genap); sekali boleh kosong.
    nominal kosong = tarif (kelas pada periode itu, jenis kelamin) dikurangi subsidi; terisi = jumlah tagihan apa adanya.
    Tagihan yang sudah ada dipakai (tidak digandakan); dibayar > 0 dicatat sebagai catatan pembayaran lama (tanpa kuitansi baru).
    uji = true → hanya memeriksa, tidak ada yang disimpan.
    Hasil: [{ baris, nis, nama, tagihan, hasil: 'dibuat'|'dibayar'|'ada'|'galat', ket }] */
create or replace function public.impor_riwayat_keuangan(p jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare r jsonb; i int := 0; v_hasil jsonb := '[]'::jsonb; st students; f fee_types; v_per text; v_kunci text; v_label text; v_acuan date; v_tempo date;
  m text[]; k record; v_std numeric; v_sub jsonb; v_pot numeric; v_bill bills; v_bayar numeric; v_tgl date; v_cara text; v_h text; v_ket text;
  v_hari int := coalesce((public._pengaturan_keuangan()->>'jatuh_tempo_hari')::int, 10); v_uji boolean := coalesce((p->>'uji')::boolean, false);
  n_buat int := 0; n_bayar int := 0; n_galat int := 0; v_total numeric := 0;
begin
  perform public._wajib_kelola_keuangan();
  if jsonb_array_length(coalesce(p->'baris', '[]'::jsonb)) = 0 then raise exception 'Tidak ada baris yang diimpor.'; end if;
  if jsonb_array_length(p->'baris') > 3000 then raise exception 'Paling banyak 3.000 baris sekali impor.'; end if;
  begin
    for r in select * from jsonb_array_elements(p->'baris') loop
      i := i + 1; st := null; f := null; v_label := null; v_h := null; v_ket := null;
      begin
        select * into st from students where nis = trim(coalesce(r->>'nis', ''));
        if st.id is null then raise exception 'NIS % tidak ditemukan.', coalesce(r->>'nis', '(kosong)'); end if;
        select * into f from fee_types where kode = upper(trim(coalesce(r->>'kode', '')));
        if f.id is null then raise exception 'Kode biaya % tidak dikenal.', coalesce(r->>'kode', '(kosong)'); end if;
        v_per := lower(regexp_replace(trim(coalesce(r->>'periode', '')), '\s+', ' ', 'g'));
        if f.siklus = 'bulanan' then
          if v_per ~ '^[0-9]{4}-[0-9]{1,2}$' then m := regexp_match(v_per, '^([0-9]{4})-([0-9]{1,2})$'); m := array[m[1], m[2]];
          elsif v_per ~ '^[0-9]{1,2}[/-][0-9]{4}$' then m := regexp_match(v_per, '^([0-9]{1,2})[/-]([0-9]{4})$'); m := array[m[2], m[1]];
          else raise exception 'Periode bulanan "%" tidak sah; tulis 2025-07 atau 07/2025.', r->>'periode'; end if;
          if m[2]::int not between 1 and 12 then raise exception 'Bulan pada periode "%" tidak sah.', r->>'periode'; end if;
          v_kunci := m[1] || '-' || lpad(m[2], 2, '0'); v_acuan := (v_kunci || '-01')::date;
          v_label := f.nama || ' ' || public.nama_bulan_periode(m[1]::int, m[2]::int); v_tempo := v_acuan + (v_hari - 1);
        elsif f.siklus = 'tahunan' then
          if v_per !~ '^[0-9]{4}/[0-9]{4}$' then raise exception 'Periode tahunan "%" tidak sah; tulis 2024/2025.', r->>'periode'; end if;
          v_kunci := v_per; v_acuan := coalesce((select mulai from academic_years where nama = v_per), (left(v_per, 4) || '-07-01')::date);
          v_label := f.nama || ' ' || v_per; v_tempo := v_acuan + 30;
        elsif f.siklus = 'semesteran' then
          m := regexp_match(v_per, '^([0-9]{4}/[0-9]{4})[ -]*(s1|s2|1|2|ganjil|genap)$');
          if m is null then raise exception 'Periode semesteran "%" tidak sah; tulis 2024/2025-S1 atau 2024/2025-S2.', r->>'periode'; end if;
          m[2] := case when m[2] in ('s1','1','ganjil') then '1' else '2' end;
          v_kunci := m[1] || '-S' || m[2];
          v_acuan := coalesce((select mulai from academic_years where nama = m[1]), (left(m[1], 4) || '-07-01')::date) + case when m[2] = '2' then interval '6 months' else interval '0' end;
          v_label := f.nama || ' Semester ' || case m[2] when '1' then 'Ganjil' else 'Genap' end || ' ' || m[1]; v_tempo := v_acuan + 30;
        else
          v_kunci := 'sekali'; v_label := f.nama;
          v_acuan := coalesce(nullif(r->>'tanggal_bayar', '')::date, public.hari_ini()); v_tempo := v_acuan;
        end if;
        if v_acuan > public.hari_ini() then raise exception 'Periode % belum tiba; impor hanya untuk catatan yang sudah berjalan.', r->>'periode'; end if;

        select * into v_bill from bills where student_id = st.id and fee_type_id = f.id and kunci_periode = v_kunci and status <> 'batal' for update;
        if v_bill.id is null then
          select * into k from public._kelas_pada(st.tingkat, st.jenjang, st.tahun_masuk, v_acuan);
          if k.tingkat is null and f.siklus <> 'sekali' then raise exception '% belum menjadi santri pada periode %.', st.nama_lengkap, r->>'periode'; end if;
          if nullif(trim(coalesce(r->>'nominal', '')), '') is not null then
            v_std := round((r->>'nominal')::numeric); v_pot := 0; v_sub := null;
          else
            v_std := public._tarif_biaya(f.id, coalesce(k.jenjang, st.jenjang), coalesce(k.tingkat, st.tingkat), st.jenis_kelamin);
            v_sub := public._potongan_subsidi(st.id, f.id, v_acuan, v_std); v_pot := (v_sub->>'potongan')::numeric;
          end if;
          if v_std < 0 then raise exception 'Nominal tagihan tidak boleh negatif.'; end if;
          insert into bills (student_id, fee_type_id, kunci_periode, nama, tanggal_tagih, jatuh_tempo, standar, potongan, alasan_potongan, status, catatan, dibuat_oleh)
          values (st.id, f.id, v_kunci, v_label, least(v_acuan, public.hari_ini()), v_tempo, v_std, v_pot, v_sub->>'alasan',
                  case when v_std - v_pot <= 0 then 'lunas' else 'belum' end, 'Impor catatan lama', public.saya())
          returning * into v_bill;
          v_h := 'dibuat'; v_ket := 'Tagihan ' || public._rupiah(v_bill.nominal) || ' dibuat'; n_buat := n_buat + 1;
        else
          v_h := 'ada'; v_ket := 'Tagihan sudah ada (' || public._rupiah(v_bill.nominal) || ', dibayar ' || public._rupiah(v_bill.dibayar) || ')';
        end if;

        v_bayar := round(coalesce(nullif(trim(coalesce(r->>'dibayar', '')), '')::numeric, 0));
        if v_bayar < 0 then raise exception 'Jumlah dibayar tidak boleh negatif.'; end if;
        if v_bayar > 0 then
          if v_bayar > v_bill.nominal - v_bill.dibayar then
            raise exception 'Dibayar % melebihi sisa tagihan %.', public._rupiah(v_bayar), public._rupiah(v_bill.nominal - v_bill.dibayar); end if;
          v_tgl := coalesce(nullif(r->>'tanggal_bayar', '')::date, least(v_tempo, public.hari_ini()));
          if v_tgl > public.hari_ini() then raise exception 'Tanggal bayar melewati hari ini.'; end if;
          v_cara := case when lower(coalesce(r->>'cara', '')) like 'trans%' then 'transfer' else 'tunai' end;
          perform public.catat_pembayaran(jsonb_build_object('student_id', st.id, 'tanggal', v_tgl, 'cara', v_cara, 'riwayat', true,
            'keterangan', coalesce(nullif(trim(coalesce(r->>'keterangan', '')), ''), 'Impor catatan pembayaran lama'),
            'alokasi', jsonb_build_array(jsonb_build_object('bill_id', v_bill.id, 'jumlah', v_bayar))));
          v_h := case v_h when 'dibuat' then 'dibuat' else 'dibayar' end;
          v_ket := v_ket || '; pembayaran ' || public._rupiah(v_bayar) || ' (' || to_char(v_tgl, 'DD/MM/YYYY') || ') dicatat';
          n_bayar := n_bayar + 1; v_total := v_total + v_bayar;
        end if;
        v_hasil := v_hasil || jsonb_build_array(jsonb_build_object('baris', i, 'nis', st.nis, 'nama', st.nama_lengkap, 'tagihan', v_label, 'hasil', v_h, 'ket', v_ket));
      exception when others then
        n_galat := n_galat + 1;
        v_hasil := v_hasil || jsonb_build_array(jsonb_build_object('baris', i, 'nis', coalesce(st.nis, r->>'nis'), 'nama', st.nama_lengkap,
          'tagihan', coalesce(v_label, r->>'periode'), 'hasil', 'galat', 'ket', sqlerrm));
      end;
    end loop;
    if v_uji then raise exception using errcode = 'P0001', message = 'SIMKA_UJI_IMPOR'; end if;
    perform public.catat_audit('impor_riwayat_keuangan', 'bills', null,
      'Impor catatan keuangan lama: ' || n_buat || ' tagihan dibuat, ' || n_bayar || ' pembayaran lama ' || public._rupiah(v_total) || ', ' || n_galat || ' baris galat', null);
  exception when sqlstate 'P0001' then
    if sqlerrm <> 'SIMKA_UJI_IMPOR' then raise; end if;   -- mode uji: seluruh perubahan dibatalkan, hasil pemeriksaan tetap dikembalikan
  end;
  return v_hasil;
end $$;

-- ---------------------------------------------------------------------
-- 8. HAK FUNGSI
-- ---------------------------------------------------------------------
do $$
declare f text;
begin
  foreach f in array array['daftar_jenis_biaya()','simpan_jenis_biaya(jsonb)','pratinjau_tagihan(jsonb)','buat_tagihan(jsonb)','catat_pembayaran(jsonb)',
      'daftar_pembayaran(jsonb)','impor_riwayat_keuangan(jsonb)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  foreach f in array array['_tahun_ta(date)','_tahun_ta_aktif()','_kelas_pada(smallint,text,smallint,date)','_tarif_biaya(uuid,text,smallint,text)',
      '_tarif_biaya(uuid,text,smallint)','_periode_tagihan(fee_types,jsonb)','_sasaran_tagihan(jsonb)','_sasaran_periode(jsonb,date)'] loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- 9. PEMERIKSAAN (hasil yang benar: semua "Sesuai")
-- ---------------------------------------------------------------------
select '1. Tarif per jenis kelamin dan batas putra/putri' as pemeriksaan,
       case when (select count(*) from information_schema.columns where (table_name, column_name) in (('fee_rates','jenis_kelamin'),('fee_types','berlaku_jk'))) = 2
             and exists (select 1 from pg_indexes where indexname = 'fee_rates_unik2') then 'Sesuai' else 'Periksa' end as hasil
union all select '2. Kelas dihitung mundur (kelas 9 → kelas 7 dua tahun lalu; kelas 10 → Wustha 9)',
       case when (select tingkat from public._kelas_pada(9::smallint, 'wustha', null, (make_date(public._tahun_ta_aktif() - 2, 8, 1)))) = 7
             and (select jenjang from public._kelas_pada(10::smallint, 'sma', null, (make_date(public._tahun_ta_aktif() - 1, 8, 1)))) = 'wustha'
             and (select tingkat from public._kelas_pada(7::smallint, 'wustha', null, (make_date(public._tahun_ta_aktif() - 1, 8, 1)))) is null then 'Sesuai' else 'Periksa' end
union all select '3. Catatan pembayaran lama (kolom riwayat) dan impor',
       case when exists (select 1 from information_schema.columns where table_name = 'payments' and column_name = 'riwayat')
             and (select count(*) from pg_proc where proname in ('impor_riwayat_keuangan','_sasaran_periode')) = 2
             and pg_get_functiondef('public.daftar_pembayaran(jsonb)'::regprocedure) like '%py.riwayat%' then 'Sesuai' else 'Periksa' end
union all select '4. Fungsi pembantu tertutup bagi pengguna',
       case when not has_function_privilege('authenticated', 'public._sasaran_periode(jsonb,date)', 'execute')
             and not has_function_privilege('anon', 'public.impor_riwayat_keuangan(jsonb)', 'execute') then 'Sesuai' else 'Periksa' end;
