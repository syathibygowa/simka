-- SIMKA PRO | supabase/migrations/20261011007700_keuangan_pembayaran.sql | v1.0 | Fase 13 – Tahap 2 Pembayaran, kuitansi, surat tagihan, tunggakan, pengingat | 11/10/2026
-- =====================================================================
-- SIMKA PRO · Migrasi 77: Keuangan santri – pembayaran dan penagihan (Blueprint Bagian 37)
--   * payments, payment_items : pembayaran (tunai/transfer, foto bukti) dialokasikan ke satu atau beberapa tagihan;
--                               pembayaran sebagian boleh; tidak boleh melebihi sisa tagihan
--   * Kuitansi bernomor (format "kuitansi"), bertanda tangan elektronik Bendahara Pondok (penanda tangan keuangan
--     yang ditunjuk superadmin), kode validasi di Cek Keabsahan; pembayaran dapat dibatalkan beralasan (kuitansi dicabut)
--   * billing_letters         : Surat Tagihan bernomor (format "tagihan") per santri: rincian tagihan berjalan dan tunggakan,
--                               batas pembayaran, rekening lembaga; terbit satu atau banyak sekaligus; catat terkirim WA
--   * Laporan: ringkasan, per santri, rincian santri, daftar pembayaran, posisi tunggakan per tanggal
--   * Pengingat harian 07.05 WITA: tagihan jatuh tempo N hari lagi; tiap Senin: ringkasan tunggakan
--   * Kuitansi dan surat tagihan hanya terlihat pembaca keuangan; tidak masuk buku agenda surat keluar
-- Jalankan SETELAH migrasi 7600. Aman dijalankan ulang.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. TABEL
-- ---------------------------------------------------------------------
create table if not exists public.payments (
  id              uuid primary key default gen_random_uuid(),
  student_id      uuid not null references public.students(id) on delete restrict,
  tanggal         date not null default public.hari_ini(),
  cara            text not null constraint payments_cara_check check (cara in ('tunai','transfer')),
  rekening_tujuan text,
  penyetor        text,
  keterangan      text,
  jumlah          numeric(14,0) not null constraint payments_jumlah_check check (jumlah > 0),
  bukti_id        uuid references public.storage_objects(id) on delete set null,
  nomor           text,
  kode_validasi   text,
  document_id     uuid references public.document_registry(id) on delete set null,
  status          text not null default 'sah' constraint payments_status_check check (status in ('sah','batal')),
  alasan_batal    text,
  dibatalkan_oleh uuid references public.employees(id) on delete set null,
  dibatalkan_pada timestamptz,
  dicatat_oleh    uuid references public.employees(id) on delete set null,
  created_at      timestamptz not null default now()
);
create index if not exists payments_tanggal_idx on public.payments (tanggal desc);
create index if not exists payments_santri_idx on public.payments (student_id);

create table if not exists public.payment_items (
  id          uuid primary key default gen_random_uuid(),
  payment_id  uuid not null references public.payments(id) on delete cascade,
  bill_id     uuid not null references public.bills(id) on delete restrict,
  jumlah      numeric(14,0) not null constraint payment_items_jumlah_check check (jumlah > 0),
  sisa_setelah numeric(14,0),
  constraint payment_items_unik unique (payment_id, bill_id)
);
create index if not exists payment_items_bill_idx on public.payment_items (bill_id);

create table if not exists public.billing_letters (
  id            uuid primary key default gen_random_uuid(),
  student_id    uuid not null references public.students(id) on delete restrict,
  nomor         text,
  tanggal       date not null default public.hari_ini(),
  batas_bayar   date not null,
  rincian       jsonb not null default '[]'::jsonb,
  total         numeric(14,0) not null default 0,
  catatan       text,
  kode_validasi text,
  document_id   uuid references public.document_registry(id) on delete set null,
  status        text not null default 'sah' constraint billing_letters_status_check check (status in ('sah','dicabut')),
  dikirim_pada  timestamptz,
  dibuat_oleh   uuid references public.employees(id) on delete set null,
  created_at    timestamptz not null default now()
);
create index if not exists billing_letters_santri_idx on public.billing_letters (student_id, tanggal desc);

do $$
declare t text;
begin
  foreach t in array array['payments','payment_items','billing_letters'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists baca on public.%I', t);
    execute format('create policy baca on public.%I for select to authenticated using (public.boleh_lihat_keuangan())', t);
    execute format('drop trigger if exists zz_audit on public.%I', t);
    execute format('create trigger zz_audit after insert or update or delete on public.%I for each row execute function public.tg_audit()', t);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- 2. PEMBANTU
-- ---------------------------------------------------------------------
create or replace function public._santri_keu(p_sid uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('id', st.id, 'nis', st.nis, 'nama', st.nama_lengkap, 'jk', st.jenis_kelamin, 'jenjang', st.jenjang,
           'tingkat', st.tingkat, 'status', st.status, 'kelas', public._kelas_santri(st.id), 'wali', public._kontak_wali(st.id))
    from students st where st.id = p_sid
$$;

/** Penanda tangan dokumen keuangan: pengguna bila ia penanda tangan, selain itu penanda tangan pertama yang ditunjuk. */
create or replace function public._ttd_keuangan()
returns uuid language plpgsql stable security definer set search_path = public as $$
declare v uuid;
begin
  if public.saya() in (select public._pejabat_keuangan()) then return public.saya(); end if;
  select x into v from public._pejabat_keuangan() x limit 1;
  if v is null then raise exception 'Superadmin belum menunjuk penanda tangan keuangan (Bendahara Pondok) di Hak Akses → Fitur sensitif.'; end if;
  return v;
end $$;

create or replace function public._daftarkan_dok_keuangan(p_jenis text, p_jenis_nama text, p_nomor text, p_perihal text, p_subjek text, p_periode text,
  p_ref_tabel text, p_ref uuid, p_tautan text, p_isi jsonb, p_ttd uuid)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare v_kode text := public._kode_dokumen(); v_doc uuid; e employees;
begin
  select * into e from employees where id = p_ttd;
  insert into document_registry (kode, jenis, jenis_nama, nomor, perihal, subjek, periode, kop_kode, status, sidik, ref_tabel, ref_id,
                                 diterbitkan_pada, diterbitkan_oleh, mode_ttd, tautan, isi)
  values (v_kode, p_jenis, p_jenis_nama, p_nomor, p_perihal, p_subjek, p_periode, 'pondok', 'sah', public._sidik(p_isi), p_ref_tabel, p_ref,
          now(), public.saya(), 'elektronik', p_tautan, p_isi)
  returning id into v_doc;
  insert into document_signatures (document_id, urutan, posisi, employee_id, nama, jabatan, niy, status, waktu)
  values (v_doc, 1, 'kanan', e.id, e.nama_lengkap, public._jabatan_ttd('keuangan', e.id), e.niy, 'ditandatangani', now());
  return jsonb_build_object('kode', v_kode, 'document_id', v_doc);
end $$;

-- ---------------------------------------------------------------------
-- 3. PEMBAYARAN DAN KUITANSI
-- ---------------------------------------------------------------------
/** Catat pembayaran. p: { student_id, tanggal, cara, rekening_tujuan, penyetor, keterangan, bukti_id,
    alokasi: [{bill_id, jumlah}] — atau jumlah saja (dialokasikan ke tagihan tertua lebih dulu) }. Hasil {id, nomor, kode_validasi}. */
create or replace function public.catat_pembayaran(p jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare st students; v_tgl date := coalesce(nullif(p->>'tanggal', '')::date, public.hari_ini()); v_id uuid; v_total numeric := 0;
  a jsonb; b bills; v_j numeric; v_sisa numeric; v_alok jsonb := '[]'::jsonb; v_ttd uuid; v_nomor text; v_dok jsonb; v_isi jsonb; x jsonb;
begin
  perform public._wajib_kelola_keuangan();
  select * into st from students where id = (p->>'student_id')::uuid;
  if st.id is null then raise exception 'Santri tidak ditemukan.'; end if;
  if coalesce(p->>'cara', '') not in ('tunai','transfer') then raise exception 'Pilih cara bayar: tunai atau transfer.'; end if;
  if v_tgl > public.hari_ini() then raise exception 'Tanggal pembayaran tidak boleh melewati hari ini.'; end if;
  v_ttd := public._ttd_keuangan();
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

  insert into payments (student_id, tanggal, cara, rekening_tujuan, penyetor, keterangan, jumlah, bukti_id, dicatat_oleh)
  values (st.id, v_tgl, p->>'cara', nullif(trim(coalesce(p->>'rekening_tujuan', '')), ''), nullif(trim(coalesce(p->>'penyetor', '')), ''),
          nullif(trim(coalesce(p->>'keterangan', '')), ''), v_total, nullif(p->>'bukti_id', '')::uuid, public.saya())
  returning id into v_id;
  for x in select * from jsonb_array_elements(v_alok) loop
    update bills set dibayar = dibayar + (x->>'jumlah')::numeric where id = (x->>'bill_id')::uuid;
    perform public._segarkan_tagihan((x->>'bill_id')::uuid);
    insert into payment_items (payment_id, bill_id, jumlah, sisa_setelah)
    select v_id, b2.id, (x->>'jumlah')::numeric, b2.nominal - b2.dibayar from bills b2 where b2.id = (x->>'bill_id')::uuid;
  end loop;

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

create or replace function public.batalkan_pembayaran(p_id uuid, p_alasan text)
returns void language plpgsql volatile security definer set search_path = public as $$
declare py payments; i payment_items;
begin
  perform public._wajib_kelola_keuangan();
  select * into py from payments where id = p_id for update;
  if py.id is null or py.status = 'batal' then raise exception 'Pembayaran tidak ditemukan atau sudah dibatalkan.'; end if;
  if length(trim(coalesce(p_alasan, ''))) < 5 then raise exception 'Alasan pembatalan wajib diisi (paling sedikit 5 karakter).'; end if;
  for i in select * from payment_items where payment_id = p_id loop
    update bills set dibayar = greatest(dibayar - i.jumlah, 0) where id = i.bill_id;
    perform public._segarkan_tagihan(i.bill_id);
  end loop;
  update payments set status = 'batal', alasan_batal = trim(p_alasan), dibatalkan_oleh = public.saya(), dibatalkan_pada = now() where id = p_id;
  update document_registry set status = 'dicabut', dicabut_pada = now(), dicabut_oleh = public.saya(), alasan_cabut = 'Pembayaran dibatalkan: ' || trim(p_alasan)
   where id = py.document_id;
end $$;

/** Satu atau banyak kuitansi untuk dicetak. */
create or replace function public.kuitansi(p_ids uuid[])
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform public._wajib_lihat_keuangan();
  return coalesce((select jsonb_agg(to_jsonb(py) || jsonb_build_object('santri', public._santri_keu(py.student_id),
      'rincian', (select jsonb_agg(jsonb_build_object('tagihan', b.nama, 'jatuh_tempo', b.jatuh_tempo, 'nominal', b.nominal, 'jumlah', pi.jumlah, 'sisa', pi.sisa_setelah)
                                    order by b.jatuh_tempo) from payment_items pi join bills b on b.id = pi.bill_id where pi.payment_id = py.id),
      'sisa_total', (select coalesce(sum(nominal - dibayar), 0) from bills where student_id = py.student_id and status in ('belum','sebagian')),
      'ttd', (select jsonb_build_object('nama', s.nama, 'jabatan', s.jabatan, 'niy', s.niy, 'waktu', s.waktu)
                from document_signatures s where s.document_id = py.document_id order by s.urutan limit 1),
      'dicatat', (select nama_lengkap from employees where id = py.dicatat_oleh))
    order by py.tanggal, py.created_at) from payments py where py.id = any(p_ids)), '[]'::jsonb);
end $$;

/** Daftar pembayaran. p: { mulai, akhir, student_id, cara, status }. */
create or replace function public.daftar_pembayaran(p jsonb)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform public._wajib_lihat_keuangan();
  return coalesce((select jsonb_agg(jsonb_build_object('id', py.id, 'tanggal', py.tanggal, 'cara', py.cara, 'rekening_tujuan', py.rekening_tujuan,
      'penyetor', py.penyetor, 'keterangan', py.keterangan, 'jumlah', py.jumlah, 'nomor', py.nomor, 'kode_validasi', py.kode_validasi, 'status', py.status,
      'alasan_batal', py.alasan_batal, 'bukti_id', py.bukti_id, 'created_at', py.created_at, 'dicatat', (select nama_lengkap from employees where id = py.dicatat_oleh),
      'student_id', st.id, 'nis', st.nis, 'nama', st.nama_lengkap, 'jk', st.jenis_kelamin, 'jenjang', st.jenjang, 'tingkat', st.tingkat,
      'kelas', public._kelas_santri(st.id), 'wali', public._kontak_wali(st.id),
      'rincian', (select jsonb_agg(jsonb_build_object('bill_id', b.id, 'tagihan', b.nama, 'jenis', f.nama, 'fee_type_id', f.id, 'jumlah', pi.jumlah, 'sisa', pi.sisa_setelah)
                                    order by b.jatuh_tempo) from payment_items pi join bills b on b.id = pi.bill_id join fee_types f on f.id = b.fee_type_id where pi.payment_id = py.id))
    order by py.tanggal desc, py.created_at desc)
    from payments py join students st on st.id = py.student_id
   where py.tanggal between coalesce(nullif(p->>'mulai', '')::date, '2000-01-01') and coalesce(nullif(p->>'akhir', '')::date, '2999-12-31')
     and (nullif(p->>'student_id', '') is null or py.student_id = (p->>'student_id')::uuid)
     and (nullif(p->>'cara', '') is null or py.cara = p->>'cara')
     and (nullif(p->>'status', '') is null or py.status = p->>'status')), '[]'::jsonb);
end $$;

-- ---------------------------------------------------------------------
-- 4. SURAT TAGIHAN
-- ---------------------------------------------------------------------
/** Terbitkan surat tagihan untuk satu atau banyak santri. p: { student_ids:[..], batas_bayar, catatan, tempo_sampai }.
    Memuat tagihan belum/sebagian lunas yang jatuh tempo paling lambat tempo_sampai (bawaan: batas bayar).
    Santri tanpa tagihan terbuka dilewati. Hasil: [{id, student_id, nomor, kode_validasi, total}]. */
create or replace function public.terbitkan_surat_tagihan(p jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare v_batas date := coalesce(nullif(p->>'batas_bayar', '')::date,
                                 public.hari_ini() + coalesce((public._pengaturan_keuangan()->>'batas_surat_hari')::int, 7));
  v_sampai date; v_ttd uuid; s uuid; st students; v_rinci jsonb; v_total numeric; v_id uuid; v_nomor text; v_dok jsonb; v_hasil jsonb := '[]'::jsonb;
begin
  perform public._wajib_kelola_keuangan();
  if v_batas < public.hari_ini() then raise exception 'Batas pembayaran tidak boleh sebelum hari ini.'; end if;
  v_sampai := coalesce(nullif(p->>'tempo_sampai', '')::date, v_batas);
  if jsonb_array_length(coalesce(p->'student_ids', '[]'::jsonb)) = 0 then raise exception 'Pilih santri yang ditagih.'; end if;
  v_ttd := public._ttd_keuangan();
  for s in select (jsonb_array_elements_text(p->'student_ids'))::uuid loop
    select * into st from students where id = s;
    select coalesce(jsonb_agg(jsonb_build_object('bill_id', b.id, 'tagihan', b.nama, 'jatuh_tempo', b.jatuh_tempo, 'nominal', b.nominal, 'dibayar', b.dibayar,
             'sisa', b.nominal - b.dibayar, 'lewat', b.jatuh_tempo < public.hari_ini()) order by b.jatuh_tempo, b.nama), '[]'::jsonb),
           coalesce(sum(b.nominal - b.dibayar), 0)
      into v_rinci, v_total
      from bills b where b.student_id = s and b.status in ('belum','sebagian') and b.jatuh_tempo <= v_sampai;
    if st.id is null or v_total <= 0 then continue; end if;
    perform set_config('simka.nomor_sistem', '1', true);
    v_nomor := public.ambil_nomor('tagihan', public.hari_ini(), 'D', null, 'pondok')->>'nomor';
    perform set_config('simka.nomor_sistem', '', true);
    insert into billing_letters (student_id, nomor, batas_bayar, rincian, total, catatan, dibuat_oleh)
    values (s, v_nomor, v_batas, v_rinci, v_total, nullif(trim(coalesce(p->>'catatan', '')), ''), public.saya()) returning id into v_id;
    v_dok := public._daftarkan_dok_keuangan('tagihan_santri', 'Surat Tagihan', v_nomor, 'Tagihan ' || public._rupiah(v_total) || ', batas ' || to_char(v_batas, 'DD/MM/YYYY'),
      st.nama_lengkap || ' (NIS ' || st.nis || ')', to_char(public.hari_ini(), 'DD/MM/YYYY'), 'billing_letters', v_id, '/keuangan/santri?santri=' || s,
      jsonb_build_object('santri', public._santri_keu(s), 'nomor', v_nomor, 'batas_bayar', v_batas, 'rincian', v_rinci, 'total', v_total), v_ttd);
    update billing_letters set kode_validasi = v_dok->>'kode', document_id = (v_dok->>'document_id')::uuid where id = v_id;
    v_hasil := v_hasil || jsonb_build_array(jsonb_build_object('id', v_id, 'student_id', s, 'nomor', v_nomor, 'kode_validasi', v_dok->>'kode', 'total', v_total));
  end loop;
  return v_hasil;
end $$;

create or replace function public.surat_tagihan(p_ids uuid[])
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform public._wajib_lihat_keuangan();
  return coalesce((select jsonb_agg(to_jsonb(l) || jsonb_build_object('santri', public._santri_keu(l.student_id),
      'ttd', (select jsonb_build_object('nama', s.nama, 'jabatan', s.jabatan, 'niy', s.niy, 'waktu', s.waktu)
                from document_signatures s where s.document_id = l.document_id order by s.urutan limit 1))
    order by l.created_at) from billing_letters l where l.id = any(p_ids)), '[]'::jsonb);
end $$;

create or replace function public.catat_kirim_tagihan(p_id uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  perform public._wajib_kelola_keuangan();
  update billing_letters set dikirim_pada = now() where id = p_id;
end $$;

create or replace function public.cabut_surat_tagihan(p_id uuid, p_alasan text)
returns void language plpgsql volatile security definer set search_path = public as $$
declare l billing_letters;
begin
  perform public._wajib_kelola_keuangan();
  select * into l from billing_letters where id = p_id;
  if l.id is null or l.status = 'dicabut' then raise exception 'Surat tagihan tidak ditemukan atau sudah dicabut.'; end if;
  if length(trim(coalesce(p_alasan, ''))) < 5 then raise exception 'Alasan pencabutan wajib diisi (paling sedikit 5 karakter).'; end if;
  update billing_letters set status = 'dicabut' where id = p_id;
  update document_registry set status = 'dicabut', dicabut_pada = now(), dicabut_oleh = public.saya(), alasan_cabut = trim(p_alasan) where id = l.document_id;
end $$;

-- ---------------------------------------------------------------------
-- 5. LAPORAN
-- ---------------------------------------------------------------------
/** Per santri: total tagihan, dibayar, sisa, tunggakan lewat tempo. p: { jenjang, group_id, status ('tunggak'|'lewat'|'lunas'), q, semua_status } */
create or replace function public.santri_keuangan(p jsonb)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform public._wajib_lihat_keuangan();
  return coalesce((select jsonb_agg(r order by r->>'nama') from (
    select jsonb_build_object('id', st.id, 'nis', st.nis, 'nama', st.nama_lengkap, 'jk', st.jenis_kelamin, 'jenjang', st.jenjang, 'tingkat', st.tingkat,
           'status', st.status, 'kelas', public._kelas_santri(st.id), 'wali', public._kontak_wali(st.id),
           'tagihan', coalesce(t.tagihan, 0), 'dibayar', coalesce(t.dibayar, 0), 'sisa', coalesce(t.sisa, 0), 'lewat', coalesce(t.lewat, 0),
           'jumlah_terbuka', coalesce(t.terbuka, 0), 'tempo_tertua', t.tertua,
           'subsidi', (select count(*) from fee_subsidies s where s.student_id = st.id and s.aktif and (s.sampai is null or s.sampai >= public.hari_ini())),
           'surat_terakhir', (select max(tanggal) from billing_letters l where l.student_id = st.id and l.status = 'sah')) r
      from students st
      left join lateral (select sum(b.nominal) tagihan, sum(b.dibayar) dibayar, sum(b.nominal - b.dibayar) filter (where b.status in ('belum','sebagian')) sisa,
                                sum(b.nominal - b.dibayar) filter (where b.status in ('belum','sebagian') and b.jatuh_tempo < public.hari_ini()) lewat,
                                count(*) filter (where b.status in ('belum','sebagian')) terbuka,
                                min(b.jatuh_tempo) filter (where b.status in ('belum','sebagian')) tertua
                           from bills b where b.student_id = st.id and b.status <> 'batal') t on true
     where (st.status = 'aktif' or coalesce((p->>'semua_status')::boolean, false) or coalesce(t.sisa, 0) > 0)
       and (nullif(p->>'jenjang', '') is null or st.jenjang = p->>'jenjang')
       and (nullif(p->>'group_id', '') is null or st.id in (select m.student_id from group_members m where m.group_id = (p->>'group_id')::uuid and m.selesai is null))
       and (nullif(p->>'q', '') is null or st.nama_lengkap ilike '%' || (p->>'q') || '%' or st.nis like (p->>'q') || '%')
       and (case coalesce(p->>'status', '') when 'tunggak' then coalesce(t.sisa, 0) > 0 when 'lewat' then coalesce(t.lewat, 0) > 0
              when 'lunas' then coalesce(t.tagihan, 0) > 0 and coalesce(t.sisa, 0) = 0 else true end)) q), '[]'::jsonb);
end $$;

create or replace function public.rincian_keuangan_santri(p_sid uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform public._wajib_lihat_keuangan();
  return jsonb_build_object('santri', public._santri_keu(p_sid),
    'kontak', coalesce((select jsonb_agg(jsonb_build_object('hubungan', c.hubungan, 'nama', c.nama, 'no_hp', c.no_hp, 'utama', c.utama)
                                         order by c.utama desc, c.hubungan) from student_contacts c where c.student_id = p_sid), '[]'::jsonb),
    'tagihan', public.daftar_tagihan(jsonb_build_object('student_id', p_sid, 'status', '')),
    'pembayaran', public.daftar_pembayaran(jsonb_build_object('student_id', p_sid)),
    'subsidi', coalesce((select jsonb_agg(to_jsonb(s) || jsonb_build_object('jenis_biaya', (select nama from fee_types where id = s.fee_type_id),
                 'berlaku', s.aktif and s.mulai <= public.hari_ini() and (s.sampai is null or s.sampai >= public.hari_ini())) order by s.mulai desc)
                 from fee_subsidies s where s.student_id = p_sid), '[]'::jsonb),
    'surat', coalesce((select jsonb_agg(jsonb_build_object('id', l.id, 'nomor', l.nomor, 'tanggal', l.tanggal, 'batas_bayar', l.batas_bayar, 'total', l.total,
                 'status', l.status, 'kode_validasi', l.kode_validasi, 'dikirim_pada', l.dikirim_pada) order by l.created_at desc)
                 from billing_letters l where l.student_id = p_sid), '[]'::jsonb));
end $$;

/** Posisi tunggakan per tanggal: setiap tagihan yang jatuh tempo paling lambat tanggal itu dan masih bersisa pada tanggal itu
    (pembayaran sesudah tanggal itu tidak dihitung). Hasil per tagihan; pengelompokan (santri/kelas/jenis/jenjang) di aplikasi. */
create or replace function public.posisi_tunggakan(p_tanggal date default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_tgl date := coalesce(p_tanggal, public.hari_ini());
begin
  perform public._wajib_lihat_keuangan();
  return coalesce((select jsonb_agg(r order by r->>'nama', r->>'jatuh_tempo') from (
    select jsonb_build_object('bill_id', b.id, 'student_id', st.id, 'nis', st.nis, 'nama', st.nama_lengkap, 'jk', st.jenis_kelamin, 'jenjang', st.jenjang,
           'tingkat', st.tingkat, 'kelas', public._kelas_santri(st.id), 'wali', public._kontak_wali(st.id), 'status_santri', st.status,
           'fee_type_id', f.id, 'jenis', f.nama, 'tagihan', b.nama, 'jatuh_tempo', b.jatuh_tempo, 'nominal', b.nominal,
           'dibayar', coalesce(x.bayar, 0), 'sisa', b.nominal - coalesce(x.bayar, 0), 'hari_lewat', v_tgl - b.jatuh_tempo) r
      from bills b join students st on st.id = b.student_id join fee_types f on f.id = b.fee_type_id
      left join lateral (select sum(pi.jumlah) bayar from payment_items pi join payments py on py.id = pi.payment_id
                          where pi.bill_id = b.id and py.status = 'sah' and py.tanggal <= v_tgl) x on true
     where b.status <> 'batal' and b.jatuh_tempo <= v_tgl and b.nominal - coalesce(x.bayar, 0) > 0) q), '[]'::jsonb);
end $$;

/** Ringkasan keuangan untuk tab Ringkasan (angka langsung). */
create or replace function public.ringkasan_keuangan()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_hari date := public.hari_ini(); v_awal date := date_trunc('month', public.hari_ini())::date;
begin
  perform public._wajib_lihat_keuangan();
  return jsonb_build_object(
    'tagihan', (select coalesce(sum(nominal), 0) from bills where status <> 'batal'),
    'dibayar', (select coalesce(sum(dibayar), 0) from bills where status <> 'batal'),
    'sisa', (select coalesce(sum(nominal - dibayar), 0) from bills where status in ('belum','sebagian')),
    'lewat', (select coalesce(sum(nominal - dibayar), 0) from bills where status in ('belum','sebagian') and jatuh_tempo < v_hari),
    'santri_menunggak', (select count(distinct student_id) from bills where status in ('belum','sebagian') and jatuh_tempo < v_hari),
    'tempo_pekan', (select count(*) from bills where status in ('belum','sebagian') and jatuh_tempo between v_hari and v_hari + 7),
    'tempo_pekan_nominal', (select coalesce(sum(nominal - dibayar), 0) from bills where status in ('belum','sebagian') and jatuh_tempo between v_hari and v_hari + 7),
    'masuk_hari_ini', (select coalesce(sum(jumlah), 0) from payments where status = 'sah' and tanggal = v_hari),
    'transaksi_hari_ini', (select count(*) from payments where status = 'sah' and tanggal = v_hari),
    'masuk_bulan_ini', (select coalesce(sum(jumlah), 0) from payments where status = 'sah' and tanggal >= v_awal),
    'transaksi_bulan_ini', (select count(*) from payments where status = 'sah' and tanggal >= v_awal),
    'per_jenis', coalesce((select jsonb_agg(jsonb_build_object('fee_type_id', f.id, 'jenis', f.nama, 'siklus', f.siklus, 'tagihan', x.t, 'dibayar', x.d, 'sisa', x.s) order by f.urutan, f.nama)
       from fee_types f join lateral (select coalesce(sum(nominal), 0) t, coalesce(sum(dibayar), 0) d, coalesce(sum(nominal - dibayar) filter (where status in ('belum','sebagian')), 0) s
                                       from bills where fee_type_id = f.id and status <> 'batal') x on true where x.t > 0), '[]'::jsonb),
    'per_bulan', coalesce((select jsonb_agg(jsonb_build_object('bulan', to_char(m, 'YYYY-MM'),
       'masuk', (select coalesce(sum(jumlah), 0) from payments where status = 'sah' and date_trunc('month', tanggal) = m)) order by m)
       from generate_series(date_trunc('month', v_hari) - interval '5 months', date_trunc('month', v_hari), interval '1 month') m), '[]'::jsonb),
    'tempo_terdekat', coalesce((select jsonb_agg(r) from (select jsonb_build_object('bill_id', b.id, 'student_id', b.student_id, 'nama', st.nama_lengkap, 'nis', st.nis,
       'kelas', public._kelas_santri(st.id), 'tagihan', b.nama, 'jatuh_tempo', b.jatuh_tempo, 'sisa', b.nominal - b.dibayar) r
       from bills b join students st on st.id = b.student_id where b.status in ('belum','sebagian') and b.jatuh_tempo >= v_hari
       order by b.jatuh_tempo, st.nama_lengkap limit 8) q), '[]'::jsonb),
    'ada_penanda_tangan', exists (select 1 from public._pejabat_keuangan()),
    'jenis_biaya', (select count(*) from fee_types where aktif));
end $$;

/** Kartu Beranda (Untuk Anda) bagi pembaca keuangan. */
create or replace function public.ringkasan_keuangan_beranda()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_hari date := public.hari_ini();
begin
  if not public.boleh_lihat_keuangan() then return null; end if;
  return jsonb_build_object('masuk_hari_ini', (select coalesce(sum(jumlah), 0) from payments where status = 'sah' and tanggal = v_hari),
    'transaksi_hari_ini', (select count(*) from payments where status = 'sah' and tanggal = v_hari),
    'santri_menunggak', (select count(distinct student_id) from bills where status in ('belum','sebagian') and jatuh_tempo < v_hari),
    'tempo_pekan', (select count(*) from bills where status in ('belum','sebagian') and jatuh_tempo between v_hari and v_hari + 7),
    'ada_penanda_tangan', exists (select 1 from public._pejabat_keuangan()));
end $$;

-- ---------------------------------------------------------------------
-- 6. PENGINGAT HARIAN (07.05 WITA)
-- ---------------------------------------------------------------------
create or replace function public.pengingat_keuangan_harian()
returns void language plpgsql volatile security definer set search_path = public as $$
declare v_hari date := public.hari_ini(); v_n int := coalesce((public._pengaturan_keuangan()->>'pengingat_hari')::int, 3);
  v_tempo int; v_nom numeric; v_lewat int; v_lewat_nom numeric; v_emp uuid;
begin
  select count(*), coalesce(sum(nominal - dibayar), 0) into v_tempo, v_nom from bills
   where status in ('belum','sebagian') and jatuh_tempo = v_hari + v_n;
  select count(distinct student_id), coalesce(sum(nominal - dibayar), 0) into v_lewat, v_lewat_nom from bills
   where status in ('belum','sebagian') and jatuh_tempo < v_hari;
  for v_emp in select sa.employee_id from sensitive_access sa join employees e on e.id = sa.employee_id
                where sa.fitur = 'keuangan' and sa.tingkat = 'kelola' and e.status_akun = 'aktif' and e.status_keaktifan = 'aktif' loop
    if v_tempo > 0 then
      perform public.kirim_notifikasi(v_emp, v_tempo || ' tagihan santri jatuh tempo ' || case when v_n = 0 then 'hari ini' else v_n || ' hari lagi' end,
        'Sisa ' || public._rupiah(v_nom) || ' pada ' || to_char(v_hari + v_n, 'DD/MM/YYYY') || '. Kirim pengingat kepada wali melalui WA.',
        '/keuangan/tagihan?status=tunggak', 'CalendarCheck', 'oranye');
    end if;
    if extract(isodow from v_hari) = 1 and v_lewat > 0 then
      perform public.kirim_notifikasi(v_emp, v_lewat || ' santri menunggak', 'Tunggakan lewat jatuh tempo ' || public._rupiah(v_lewat_nom) || '.',
        '/keuangan/tunggakan', 'WarningCircle', 'merah');
    end if;
  end loop;
end $$;
revoke execute on function public.pengingat_keuangan_harian() from public, anon, authenticated;
do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    perform cron.unschedule('pengingat-keuangan') where exists (select 1 from cron.job where jobname = 'pengingat-keuangan');
    perform cron.schedule('pengingat-keuangan', '5 23 * * *', 'select public.pengingat_keuangan_harian()');
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 7. KERAHASIAAN DOKUMEN DAN BERKAS
-- ---------------------------------------------------------------------
create or replace function public.boleh_lihat_dokumen(p_doc uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select case (select jenis from document_registry where id = p_doc)
    when 'slip_gaji' then public.boleh_lihat_gaji()
         or exists (select 1 from document_registry d join payroll_lines l on l.id = d.ref_id
                  where d.id = p_doc and d.ref_tabel = 'payroll_lines' and l.employee_id = public.saya() and public._slip_terbuka(l))
    when 'kuitansi' then public.boleh_lihat_keuangan()
    when 'tagihan_santri' then public.boleh_lihat_keuangan()
    else public.is_admin()
      or exists (select 1 from document_registry d where d.id = p_doc and d.diterbitkan_oleh = public.saya())
      or exists (select 1 from document_signatures s where s.document_id = p_doc and s.employee_id = public.saya()) end
$$;

do $$
declare d text := pg_get_functiondef('public.buku_agenda_keluar(date,date)'::regprocedure);
begin
  if position('''kuitansi''' in d) = 0 then
    if position('(''surat_keluar'',''slip_gaji'')' in d) = 0 then raise exception 'buku_agenda_keluar tidak dikenali; hubungi pengembang.'; end if;
    execute replace(d, '(''surat_keluar'',''slip_gaji'')', '(''surat_keluar'',''slip_gaji'',''kuitansi'',''tagihan_santri'')');
  end if;
end $$;

-- Foto bukti pembayaran: hanya pembaca keuangan (Edge Function "berkas")
do $$
declare d text := pg_get_functiondef('public.boleh_lihat_berkas(uuid,uuid)'::regprocedure);
  cabang text := $c$
  -- Bukti pembayaran santri (Fase 13): hanya superadmin dan yang ditunjuk untuk keuangan
  if exists (select 1 from payments py where py.bukti_id = p_obj) then
    return public._akses_sensitif('keuangan', p_emp) is not null;
  end if;
  return false;
end $c$;
begin
  if position('payments py' in d) > 0 then return; end if;
  if d !~ E'\\n\\s*return false;\\s*\\nend' then raise exception 'boleh_lihat_berkas tidak dikenali; hubungi pengembang.'; end if;
  execute regexp_replace(d, E'\\n\\s*return false;\\s*\\nend', cabang);
end $$;

-- ---------------------------------------------------------------------
-- 8. TEMPLATE WA KE WALI (dapat disunting di Setelan → Template WA)
-- ---------------------------------------------------------------------
insert into public.wa_templates (kode, nama, isi, variabel, keterangan) values
  ('tagihan_santri', 'Surat tagihan ke wali',
   E'{salam}, Bapak/Ibu {nama_wali}.\n\nKami sampaikan tagihan ananda *{nama_santri}* (NIS {nis}, {kelas}):\n{rincian}\n\n*Jumlah: {total}*\nMohon dibayarkan paling lambat *{batas_bayar}*.\n\nPembayaran dapat ditransfer ke:\n{rekening}\n\nSurat tagihan resmi nomor {nomor}; keabsahan dapat diperiksa dengan kode {kode_validasi} di {tautan_cek}\n\nApabila sudah membayar, mohon kirimkan bukti transfer melalui nomor ini.\n{penutup}\n{pengirim}\n{jabatan_pengirim}',
   '{nama_wali,nama_santri,nis,kelas,rincian,total,batas_bayar,rekening,nomor,kode_validasi,tautan_cek}', 'Keuangan: kirim surat tagihan kepada orang tua/wali.'),
  ('kuitansi_santri', 'Konfirmasi pembayaran ke wali',
   E'{salam}, Bapak/Ibu {nama_wali}.\n\nAlhamdulillah, pembayaran untuk ananda *{nama_santri}* ({kelas}) telah kami terima:\n{rincian}\n\n*Jumlah: {jumlah}*\nTanggal: {tanggal}\nKuitansi nomor {nomor} (kode validasi {kode_validasi}).\n{sisa}\n\nJazakumullahu khairan atas kerja samanya.\n{pengirim}\n{jabatan_pengirim}',
   '{nama_wali,nama_santri,kelas,rincian,jumlah,tanggal,nomor,kode_validasi,sisa}', 'Keuangan: konfirmasi pembayaran diterima.'),
  ('tunggakan_santri', 'Pemberitahuan tunggakan ke wali',
   E'{salam}, Bapak/Ibu {nama_wali}.\n\nMohon maaf mengganggu. Berdasarkan catatan kami, terdapat tagihan ananda *{nama_santri}* ({kelas}) yang telah melewati jatuh tempo:\n{rincian}\n\n*Jumlah: {total}*\n\nPembayaran dapat ditransfer ke:\n{rekening}\n\nApabila sudah membayar, mohon kirimkan bukti transfer melalui nomor ini. Bila ada kendala, silakan menghubungi kami.\n{penutup}\n{pengirim}\n{jabatan_pengirim}',
   '{nama_wali,nama_santri,kelas,rincian,total,rekening}', 'Keuangan: pemberitahuan tunggakan.')
on conflict (kode) do nothing;

-- ---------------------------------------------------------------------
-- 9. HAK EKSEKUSI
-- ---------------------------------------------------------------------
do $$
declare f text;
begin
  foreach f in array array['catat_pembayaran(jsonb)','batalkan_pembayaran(uuid,text)','kuitansi(uuid[])','daftar_pembayaran(jsonb)',
      'terbitkan_surat_tagihan(jsonb)','surat_tagihan(uuid[])','catat_kirim_tagihan(uuid)','cabut_surat_tagihan(uuid,text)',
      'santri_keuangan(jsonb)','rincian_keuangan_santri(uuid)','posisi_tunggakan(date)','ringkasan_keuangan()','ringkasan_keuangan_beranda()',
      'boleh_lihat_dokumen(uuid)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  foreach f in array array['_santri_keu(uuid)','_ttd_keuangan()',
      '_daftarkan_dok_keuangan(text,text,text,text,text,text,text,uuid,text,jsonb,uuid)'] loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- 10. PEMERIKSAAN (hasil yang benar: baris 1–6 "Sesuai"; baris 7 informasi)
-- ---------------------------------------------------------------------
select '1. Tabel pembayaran, rincian, surat tagihan (RLS)' as pemeriksaan,
       case when (select count(*) from pg_tables where tablename in ('payments','payment_items','billing_letters') and rowsecurity) = 3 then 'Sesuai' else 'Periksa' end as hasil
union all select '2. Format nomor kuitansi dan surat tagihan',
       case when (select count(*) from doc_number_formats where kode in ('kuitansi','tagihan') and aktif) = 2 then 'Sesuai' else 'Periksa: aktifkan di Setelan → Penomoran' end
union all select '3. Kuitansi/surat tagihan tidak masuk buku agenda',
       case when pg_get_functiondef('public.buku_agenda_keluar(date,date)'::regprocedure) like '%tagihan_santri%' then 'Sesuai' else 'Periksa' end
union all select '4. Foto bukti bayar hanya untuk pembaca keuangan',
       case when pg_get_functiondef('public.boleh_lihat_berkas(uuid,uuid)'::regprocedure) like '%payments py%' then 'Sesuai' else 'Periksa' end
union all select '5. Template WA keuangan (3)',
       case when (select count(*) from wa_templates where kode in ('tagihan_santri','kuitansi_santri','tunggakan_santri')) = 3 then 'Sesuai' else 'Periksa' end
union all select '6. Pengingat harian 07.05 WITA',
       case when not exists (select 1 from pg_namespace where nspname = 'cron') then 'Lewati (pg_cron tidak ada)'
            when exists (select 1 from cron.job where jobname = 'pengingat-keuangan') then 'Sesuai' else 'Periksa' end
union all select '7. Penanda tangan keuangan ditunjuk', (select count(*) || ' pegawai' from public._pejabat_keuangan());
