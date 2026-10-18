-- SIMKA PRO | supabase/migrations/20261028012000_keuangan_kas_laporan_bebas.sql | v1.0 | 14.7.0: rekening/kas, pengeluaran, buku kas, laporan satu halaman, Surat Keterangan Bebas Tunggakan | 18/10/2026
-- =====================================================================
-- SIMKA PRO · Migrasi 120: Keuangan komprehensif
--   A. REKENING DAN KAS (finance_accounts): kas tunai dan banyak rekening bank, saldo awal per tanggal, tampil di pesan/surat wali.
--      Rekening lama di Pengaturan otomatis dipindahkan. Setiap pembayaran dicatat masuk ke satu rekening/kas
--      (tunai → kas; transfer → rekening yang dipilih). Pengaturan "rekening" kini dibaca dari daftar rekening.
--   B. TRANSAKSI LAIN (finance_entries): PENGELUARAN dan pemasukan di luar tagihan (mis. donasi), dicatat langsung oleh
--      pengelola keuangan TANPA persetujuan, bernomor (BKK/BKM), dapat dibatalkan dengan alasan. Kategori diatur di Pengaturan.
--   C. PINDAH DANA antarrekening (finance_transfers), mis. setor kas ke bank.
--   D. BUKU KAS / REKENING KORAN: mutasi masuk-keluar dengan saldo berjalan per rekening atau gabungan.
--   E. LAPORAN SATU HALAMAN: pemasukan (per jenis biaya dan kategori), pengeluaran, saldo per rekening, tagihan per jenis
--      dengan persentase lunas.
--   F. SURAT KETERANGAN BEBAS TUNGGAKAN (clearance_letters): hanya terbit bila tidak ada tagihan terbuka; bernomor SKBT,
--      ditandatangani elektronik Bendahara (QR, Cek Keabsahan). Dipakai untuk ijazah, pindah, atau keperluan lain.
-- Jalankan SETELAH migrasi 11900. Aman dijalankan ulang.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. TABEL
-- ---------------------------------------------------------------------
create table if not exists public.finance_accounts (
  id                 uuid primary key default gen_random_uuid(),
  nama               text not null check (length(trim(nama)) >= 3),
  jenis              text not null default 'bank' check (jenis in ('kas','bank')),
  bank               text,
  nomor              text,
  atas_nama          text,
  keterangan         text,
  saldo_awal         numeric not null default 0,
  tanggal_saldo_awal date not null default public.hari_ini(),
  tampil_wali        boolean not null default true,
  aktif              boolean not null default true,
  urutan             int not null default 0,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

create table if not exists public.finance_entries (
  id              uuid primary key default gen_random_uuid(),
  tanggal         date not null default public.hari_ini(),
  arah            text not null check (arah in ('masuk','keluar')),
  account_id      uuid not null references public.finance_accounts(id),
  kategori        text not null check (length(trim(kategori)) >= 3),
  uraian          text not null check (length(trim(uraian)) >= 3),
  jumlah          numeric not null check (jumlah > 0),
  pihak           text,
  nomor_bukti     text,
  bukti_id        uuid references public.storage_objects(id) on delete set null,
  nomor           text,
  status          text not null default 'sah' check (status in ('sah','batal')),
  alasan_batal    text,
  dibatalkan_oleh uuid references public.employees(id) on delete set null,
  dibatalkan_pada timestamptz,
  dicatat_oleh    uuid references public.employees(id) on delete set null,
  created_at      timestamptz not null default now()
);
create index if not exists fe_tanggal_idx on public.finance_entries (tanggal, arah);
create index if not exists fe_akun_idx on public.finance_entries (account_id, tanggal);

create table if not exists public.finance_transfers (
  id              uuid primary key default gen_random_uuid(),
  tanggal         date not null default public.hari_ini(),
  dari_id         uuid not null references public.finance_accounts(id),
  ke_id           uuid not null references public.finance_accounts(id),
  jumlah          numeric not null check (jumlah > 0),
  keterangan      text,
  status          text not null default 'sah' check (status in ('sah','batal')),
  alasan_batal    text,
  dibatalkan_oleh uuid references public.employees(id) on delete set null,
  dibatalkan_pada timestamptz,
  dicatat_oleh    uuid references public.employees(id) on delete set null,
  created_at      timestamptz not null default now(),
  check (dari_id <> ke_id)
);
create index if not exists ft_tanggal_idx on public.finance_transfers (tanggal);

create table if not exists public.clearance_letters (
  id            uuid primary key default gen_random_uuid(),
  student_id    uuid not null references public.students(id) on delete cascade,
  nomor         text,
  tanggal       date not null default public.hari_ini(),
  keperluan     text not null,
  ringkasan     jsonb,
  kode_validasi text,
  document_id   uuid references public.document_registry(id) on delete set null,
  status        text not null default 'sah' check (status in ('sah','dicabut')),
  alasan_cabut  text,
  dibuat_oleh   uuid references public.employees(id) on delete set null,
  created_at    timestamptz not null default now()
);
create index if not exists cl_santri_idx on public.clearance_letters (student_id, tanggal desc);

alter table public.payments add column if not exists account_id uuid references public.finance_accounts(id);
create index if not exists pay_akun_idx on public.payments (account_id, tanggal);

do $$ declare t text; begin
  foreach t in array array['finance_accounts','finance_entries','finance_transfers','clearance_letters'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists baca on public.%I', t);
    execute format('create policy baca on public.%I for select to authenticated using (public.boleh_lihat_keuangan())', t);
    execute format('revoke all on public.%I from anon', t);
    execute format('grant select on public.%I to authenticated', t);
    execute format('drop trigger if exists zz_audit on public.%I', t);
    execute format('create trigger zz_audit after insert or update or delete on public.%I for each row execute function public.tg_audit()', t);
  end loop;
end $$;
drop trigger if exists aa_updated on public.finance_accounts;
create trigger aa_updated before update on public.finance_accounts for each row execute function public.tg_updated_at();

insert into public.doc_number_formats (kode, nama, pola, grup_urut, reset, aktif) values
  ('bebas_tunggakan', 'Surat keterangan bebas tunggakan', 'SKBT.{URUT3}/{UNIT}/{BLN_ROMAWI}/{THN}', 'bebas_tunggakan', 'tahun_masehi', true),
  ('bukti_keluar', 'Bukti kas keluar (pengeluaran)', 'BKK.{URUT3}/{UNIT}/{BLN_ROMAWI}/{THN}', 'bukti_keluar', 'tahun_masehi', true),
  ('bukti_masuk', 'Bukti kas masuk (pemasukan lain)', 'BKM.{URUT3}/{UNIT}/{BLN_ROMAWI}/{THN}', 'bukti_masuk', 'tahun_masehi', true)
on conflict (kode) do nothing;

-- ---------------------------------------------------------------------
-- 2. ISI AWAL REKENING: kas tunai + rekening lama di Pengaturan; pembayaran lama diberi rekening
-- ---------------------------------------------------------------------
do $$
declare r jsonb; v_awal date; v_kas uuid; i int := 1;
begin
  if exists (select 1 from finance_accounts) then return; end if;
  select coalesce(min(tanggal), public.hari_ini()) into v_awal from payments where status = 'sah' and not coalesce(riwayat, false);
  insert into finance_accounts (nama, jenis, keterangan, tanggal_saldo_awal, tampil_wali, urutan)
  values ('Kas Tunai Bendahara', 'kas', 'Uang tunai yang dipegang Bendahara Pondok', v_awal, false, 0) returning id into v_kas;
  for r in select * from jsonb_array_elements(coalesce((select nilai->'rekening' from institution_settings where kunci = 'keuangan'), '[]'::jsonb)) loop
    insert into finance_accounts (nama, jenis, bank, nomor, atas_nama, keterangan, tanggal_saldo_awal, tampil_wali, urutan)
    values (trim(r->>'bank') || ' ' || trim(r->>'nomor'), 'bank', trim(r->>'bank'), trim(r->>'nomor'), trim(r->>'atas_nama'), nullif(r->>'keterangan', ''), v_awal, true, i);
    i := i + 1;
  end loop;
end $$;

/** Rekening tujuan bawaan sebuah pembayaran: tunai → kas pertama; transfer → rekening yang nomornya disebut, atau rekening bank pertama. */
create or replace function public._akun_bawaan(p_cara text, p_rekening text)
returns uuid language sql stable security definer set search_path = public as $$
  select coalesce(
    case when p_cara = 'transfer' then
      coalesce((select id from finance_accounts where aktif and jenis = 'bank' and nomor is not null and p_rekening is not null
                  and replace(p_rekening, ' ', '') ilike '%' || replace(nomor, ' ', '') || '%' order by urutan limit 1),
               (select id from finance_accounts where aktif and jenis = 'bank' order by urutan limit 1)) end,
    (select id from finance_accounts where aktif and jenis = 'kas' order by urutan limit 1),
    (select id from finance_accounts where aktif order by urutan limit 1))
$$;

create or replace function public.tg_akun_pembayaran()
returns trigger language plpgsql security definer set search_path = public as $$
declare a finance_accounts;
begin
  if coalesce(new.riwayat, false) then return new; end if;
  if new.account_id is null then new.account_id := public._akun_bawaan(new.cara, new.rekening_tujuan); end if;
  select * into a from finance_accounts where id = new.account_id;
  if a.id is not null and a.jenis = 'bank' and new.rekening_tujuan is null then new.rekening_tujuan := coalesce(a.bank || ' ' || a.nomor, a.nama); end if;
  return new;
end $$;
drop trigger if exists ab_akun on public.payments;
create trigger ab_akun before insert on public.payments for each row execute function public.tg_akun_pembayaran();

update payments set account_id = public._akun_bawaan(cara, rekening_tujuan) where account_id is null and not coalesce(riwayat, false);

-- ---------------------------------------------------------------------
-- 3. PENGATURAN: kategori pengeluaran/pemasukan; rekening dibaca dari daftar rekening
-- ---------------------------------------------------------------------
create or replace function public._pengaturan_keuangan()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('rekening', '[]'::jsonb, 'jatuh_tempo_hari', 10, 'batas_surat_hari', 7,
           'catatan_kuitansi', 'Simpan kuitansi ini sebagai bukti pembayaran yang sah.',
           'catatan_tagihan', 'Apabila sudah melakukan pembayaran, mohon abaikan surat ini dan kirimkan bukti transfer kepada Bendahara.',
           'pengingat_hari', 3,
           'kategori_keluar', jsonb_build_array('Konsumsi dan dapur', 'Honor dan insentif', 'Listrik, air, dan internet', 'Perlengkapan kebersihan',
              'Alat tulis dan administrasi', 'Kegiatan santri', 'Pemeliharaan sarana', 'Transportasi', 'Kesehatan/klinik', 'Setoran ke yayasan', 'Lain-lain'),
           'kategori_masuk', jsonb_build_array('Donasi/infak', 'Bantuan pemerintah', 'Penjualan', 'Pengembalian dana', 'Bunga/bagi hasil bank', 'Lain-lain'),
           'catatan_bebas', 'Surat keterangan ini berlaku untuk keperluan yang disebutkan dan tidak menghapus kewajiban yang timbul setelah tanggal surat.')
         || coalesce((select nilai from institution_settings where kunci = 'keuangan'), '{}'::jsonb)
         || case when exists (select 1 from finance_accounts) then jsonb_build_object('rekening', coalesce((select jsonb_agg(jsonb_build_object(
                'id', a.id, 'bank', a.bank, 'nomor', a.nomor, 'atas_nama', a.atas_nama, 'keterangan', a.keterangan) order by a.urutan, a.nama)
                from finance_accounts a where a.aktif and a.jenis = 'bank' and a.tampil_wali), '[]'::jsonb)) else '{}'::jsonb end
$$;

create or replace function public.simpan_pengaturan_keuangan(p jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v jsonb := coalesce((select nilai from institution_settings where kunci = 'keuangan'), '{}'::jsonb); n int; k text;
begin
  perform public._wajib_kelola_keuangan();
  -- "rekening" kini dikelola di Pengaturan → Rekening dan kas (finance_accounts); isian lama diabaikan
  if p ? 'jatuh_tempo_hari' then n := coalesce((p->>'jatuh_tempo_hari')::int, 10);
    if n < 1 or n > 28 then raise exception 'Tanggal jatuh tempo bulanan antara 1 dan 28.'; end if; v := v || jsonb_build_object('jatuh_tempo_hari', n); end if;
  if p ? 'batas_surat_hari' then n := coalesce((p->>'batas_surat_hari')::int, 7);
    if n < 1 or n > 60 then raise exception 'Batas pembayaran surat tagihan antara 1 dan 60 hari.'; end if; v := v || jsonb_build_object('batas_surat_hari', n); end if;
  if p ? 'pengingat_hari' then n := coalesce((p->>'pengingat_hari')::int, 3);
    if n < 0 or n > 14 then raise exception 'Pengingat jatuh tempo antara 0 dan 14 hari sebelumnya.'; end if; v := v || jsonb_build_object('pengingat_hari', n); end if;
  if p ? 'catatan_kuitansi' then v := v || jsonb_build_object('catatan_kuitansi', left(trim(coalesce(p->>'catatan_kuitansi', '')), 300)); end if;
  if p ? 'catatan_tagihan' then v := v || jsonb_build_object('catatan_tagihan', left(trim(coalesce(p->>'catatan_tagihan', '')), 500)); end if;
  if p ? 'catatan_bebas' then v := v || jsonb_build_object('catatan_bebas', left(trim(coalesce(p->>'catatan_bebas', '')), 500)); end if;
  foreach k in array array['kategori_keluar','kategori_masuk'] loop
    if p ? k then
      if jsonb_typeof(p->k) <> 'array' or jsonb_array_length(p->k) = 0 then raise exception 'Isi sedikitnya satu kategori.'; end if;
      v := v || jsonb_build_object(k, (select coalesce(jsonb_agg(distinct trim(x)), '[]') from jsonb_array_elements_text(p->k) x where length(trim(x)) >= 3));
    end if;
  end loop;
  v := v - 'rekening';
  insert into institution_settings (kunci, nilai, updated_by) values ('keuangan', v, public.saya())
  on conflict (kunci) do update set nilai = excluded.nilai, updated_at = now(), updated_by = excluded.updated_by;
  return public._pengaturan_keuangan();
end $$;

-- ---------------------------------------------------------------------
-- 4. MUTASI DAN SALDO
-- ---------------------------------------------------------------------
/** Semua mutasi sah (pembayaran santri, transaksi lain, pindah dana) dalam rentang, sejak tanggal saldo awal rekening. */
create or replace function public._mutasi_keu(p_mulai date, p_selesai date, p_akun uuid default null)
returns table (tanggal date, waktu timestamptz, account_id uuid, sumber text, ref uuid, nomor text, uraian text, pihak text, kategori text, masuk numeric, keluar numeric)
language sql stable security definer set search_path = public as $$
  select py.tanggal, py.created_at, py.account_id, 'pembayaran', py.id, py.nomor,
         'Pembayaran santri: ' || coalesce((select string_agg(b.nama, ', ' order by b.jatuh_tempo) from payment_items pi join bills b on b.id = pi.bill_id where pi.payment_id = py.id), '-'),
         st.nama_lengkap || ' (' || st.nis || ')', 'Pembayaran tagihan santri', py.jumlah, 0::numeric
    from payments py join students st on st.id = py.student_id join finance_accounts a on a.id = py.account_id
   where py.status = 'sah' and not coalesce(py.riwayat, false) and py.tanggal >= a.tanggal_saldo_awal
     and (p_mulai is null or py.tanggal >= p_mulai) and (p_selesai is null or py.tanggal <= p_selesai) and (p_akun is null or py.account_id = p_akun)
  union all
  select e.tanggal, e.created_at, e.account_id, case e.arah when 'masuk' then 'masuk_lain' else 'keluar' end, e.id, e.nomor, e.uraian, e.pihak, e.kategori,
         case e.arah when 'masuk' then e.jumlah else 0 end, case e.arah when 'keluar' then e.jumlah else 0 end
    from finance_entries e join finance_accounts a on a.id = e.account_id
   where e.status = 'sah' and e.tanggal >= a.tanggal_saldo_awal
     and (p_mulai is null or e.tanggal >= p_mulai) and (p_selesai is null or e.tanggal <= p_selesai) and (p_akun is null or e.account_id = p_akun)
  union all
  select t.tanggal, t.created_at, t.dari_id, 'pindah_keluar', t.id, null, 'Pindah dana ke ' || k.nama || coalesce(' – ' || t.keterangan, ''), null, 'Pindah dana', 0, t.jumlah
    from finance_transfers t join finance_accounts d on d.id = t.dari_id join finance_accounts k on k.id = t.ke_id
   where t.status = 'sah' and t.tanggal >= d.tanggal_saldo_awal
     and (p_mulai is null or t.tanggal >= p_mulai) and (p_selesai is null or t.tanggal <= p_selesai) and (p_akun is null or t.dari_id = p_akun)
  union all
  select t.tanggal, t.created_at, t.ke_id, 'pindah_masuk', t.id, null, 'Pindah dana dari ' || d.nama || coalesce(' – ' || t.keterangan, ''), null, 'Pindah dana', t.jumlah, 0
    from finance_transfers t join finance_accounts d on d.id = t.dari_id join finance_accounts k on k.id = t.ke_id
   where t.status = 'sah' and t.tanggal >= k.tanggal_saldo_awal
     and (p_mulai is null or t.tanggal >= p_mulai) and (p_selesai is null or t.tanggal <= p_selesai) and (p_akun is null or t.ke_id = p_akun)
$$;

/** Saldo rekening pada akhir hari p_sampai (null = hari ini). */
create or replace function public._saldo_akun(p_akun uuid, p_sampai date default null)
returns numeric language sql stable security definer set search_path = public as $$
  select case when coalesce(p_sampai, public.hari_ini()) < a.tanggal_saldo_awal then 0
         else a.saldo_awal + coalesce((select sum(m.masuk - m.keluar) from public._mutasi_keu(null, coalesce(p_sampai, public.hari_ini()), a.id) m), 0) end
    from finance_accounts a where a.id = p_akun
$$;

create or replace function public._akun_json(a finance_accounts)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('id', a.id, 'nama', a.nama, 'jenis', a.jenis, 'bank', a.bank, 'nomor', a.nomor, 'atas_nama', a.atas_nama, 'keterangan', a.keterangan,
    'saldo_awal', a.saldo_awal, 'tanggal_saldo_awal', a.tanggal_saldo_awal, 'tampil_wali', a.tampil_wali, 'aktif', a.aktif, 'urutan', a.urutan,
    'saldo', public._saldo_akun(a.id, null),
    'dipakai', exists (select 1 from payments where account_id = a.id) or exists (select 1 from finance_entries where account_id = a.id)
               or exists (select 1 from finance_transfers where a.id in (dari_id, ke_id)))
$$;

create or replace function public.daftar_rekening_keu()
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform public._wajib_lihat_keuangan();
  return coalesce((select jsonb_agg(public._akun_json(a) order by a.aktif desc, a.urutan, a.nama) from finance_accounts a), '[]'::jsonb);
end $$;

/** p: { id?, nama, jenis, bank?, nomor?, atas_nama?, keterangan?, saldo_awal, tanggal_saldo_awal, tampil_wali, aktif, urutan } */
create or replace function public.simpan_rekening_keu(p jsonb)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid := nullif(p->>'id', '')::uuid; v_jenis text := coalesce(nullif(p->>'jenis', ''), 'bank');
begin
  perform public._wajib_kelola_keuangan();
  if length(trim(coalesce(p->>'nama', ''))) < 3 then raise exception 'Isi nama rekening/kas (minimal 3 huruf).'; end if;
  if v_jenis not in ('kas','bank') then raise exception 'Jenis harus kas atau bank.'; end if;
  if v_jenis = 'bank' and (length(trim(coalesce(p->>'bank', ''))) < 2 or coalesce(p->>'nomor', '') !~ '^[0-9 .-]{5,30}$' or length(trim(coalesce(p->>'atas_nama', ''))) < 3) then
    raise exception 'Lengkapi nama bank, nomor rekening (angka), dan atas nama.'; end if;
  if coalesce((p->>'saldo_awal')::numeric, 0) < 0 then raise exception 'Saldo awal tidak boleh negatif.'; end if;
  if v_id is null then
    insert into finance_accounts (nama, jenis, bank, nomor, atas_nama, keterangan, saldo_awal, tanggal_saldo_awal, tampil_wali, aktif, urutan)
    values (trim(p->>'nama'), v_jenis, nullif(trim(coalesce(p->>'bank', '')), ''), nullif(trim(coalesce(p->>'nomor', '')), ''), nullif(trim(coalesce(p->>'atas_nama', '')), ''),
            nullif(trim(coalesce(p->>'keterangan', '')), ''), round(coalesce((p->>'saldo_awal')::numeric, 0)), coalesce(nullif(p->>'tanggal_saldo_awal', '')::date, public.hari_ini()),
            coalesce((p->>'tampil_wali')::boolean, v_jenis = 'bank'), coalesce((p->>'aktif')::boolean, true), coalesce((p->>'urutan')::int, 0))
    returning id into v_id;
  else
    update finance_accounts set nama = trim(p->>'nama'), jenis = v_jenis, bank = nullif(trim(coalesce(p->>'bank', '')), ''), nomor = nullif(trim(coalesce(p->>'nomor', '')), ''),
      atas_nama = nullif(trim(coalesce(p->>'atas_nama', '')), ''), keterangan = nullif(trim(coalesce(p->>'keterangan', '')), ''),
      saldo_awal = round(coalesce((p->>'saldo_awal')::numeric, 0)), tanggal_saldo_awal = coalesce(nullif(p->>'tanggal_saldo_awal', '')::date, tanggal_saldo_awal),
      tampil_wali = coalesce((p->>'tampil_wali')::boolean, tampil_wali), aktif = coalesce((p->>'aktif')::boolean, aktif), urutan = coalesce((p->>'urutan')::int, urutan)
     where id = v_id;
    if not found then raise exception 'Rekening tidak ditemukan.'; end if;
  end if;
  if not exists (select 1 from finance_accounts where aktif) then raise exception 'Sedikitnya satu rekening/kas harus aktif.'; end if;
  return v_id;
end $$;

create or replace function public.hapus_rekening_keu(p_id uuid)
returns text language plpgsql security definer set search_path = public as $$
begin
  perform public._wajib_kelola_keuangan();
  if exists (select 1 from payments where account_id = p_id) or exists (select 1 from finance_entries where account_id = p_id)
     or exists (select 1 from finance_transfers where p_id in (dari_id, ke_id)) then
    update finance_accounts set aktif = false where id = p_id;
    if not exists (select 1 from finance_accounts where aktif) then raise exception 'Sedikitnya satu rekening/kas harus aktif.'; end if;
    return 'nonaktif';
  end if;
  delete from finance_accounts where id = p_id;
  return 'dihapus';
end $$;

-- ---------------------------------------------------------------------
-- 5. TRANSAKSI LAIN (pengeluaran, pemasukan lain) DAN PINDAH DANA
-- ---------------------------------------------------------------------
/** p: { arah, tanggal, account_id, kategori, uraian, jumlah, pihak?, nomor_bukti?, bukti_id? } → { id, nomor } */
create or replace function public.catat_transaksi_keu(p jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_arah text := p->>'arah'; v_tgl date := coalesce(nullif(p->>'tanggal', '')::date, public.hari_ini()); v_j numeric := round(coalesce((p->>'jumlah')::numeric, 0));
  v_akun uuid := nullif(p->>'account_id', '')::uuid; v_id uuid; v_nomor text;
begin
  perform public._wajib_kelola_keuangan();
  if v_arah not in ('masuk','keluar') then raise exception 'Pilih pemasukan atau pengeluaran.'; end if;
  if v_tgl > public.hari_ini() then raise exception 'Tanggal transaksi tidak boleh melewati hari ini.'; end if;
  if v_j <= 0 then raise exception 'Isi jumlah transaksi.'; end if;
  if not exists (select 1 from finance_accounts where id = v_akun and aktif) then raise exception 'Pilih rekening/kas yang aktif.'; end if;
  if v_tgl < (select tanggal_saldo_awal from finance_accounts where id = v_akun) then raise exception 'Tanggal transaksi sebelum tanggal saldo awal rekening ini.'; end if;
  if length(trim(coalesce(p->>'kategori', ''))) < 3 then raise exception 'Pilih kategori.'; end if;
  if length(trim(coalesce(p->>'uraian', ''))) < 3 then raise exception 'Isi uraian transaksi.'; end if;
  perform set_config('simka.nomor_sistem', '1', true);
  v_nomor := public.ambil_nomor(case v_arah when 'keluar' then 'bukti_keluar' else 'bukti_masuk' end, v_tgl, 'D', null, 'pondok')->>'nomor';
  perform set_config('simka.nomor_sistem', '', true);
  insert into finance_entries (tanggal, arah, account_id, kategori, uraian, jumlah, pihak, nomor_bukti, bukti_id, nomor, dicatat_oleh)
  values (v_tgl, v_arah, v_akun, trim(p->>'kategori'), trim(p->>'uraian'), v_j, nullif(trim(coalesce(p->>'pihak', '')), ''),
          nullif(trim(coalesce(p->>'nomor_bukti', '')), ''), nullif(p->>'bukti_id', '')::uuid, v_nomor, public.saya())
  returning id into v_id;
  return jsonb_build_object('id', v_id, 'nomor', v_nomor, 'saldo', public._saldo_akun(v_akun, null));
end $$;

create or replace function public.batal_transaksi_keu(p_id uuid, p_alasan text)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public._wajib_kelola_keuangan();
  if length(trim(coalesce(p_alasan, ''))) < 5 then raise exception 'Alasan pembatalan wajib diisi (paling sedikit 5 karakter).'; end if;
  update finance_entries set status = 'batal', alasan_batal = trim(p_alasan), dibatalkan_oleh = public.saya(), dibatalkan_pada = now() where id = p_id and status = 'sah';
  if not found then raise exception 'Transaksi tidak ditemukan atau sudah dibatalkan.'; end if;
end $$;

/** p: { tanggal, dari_id, ke_id, jumlah, keterangan? } */
create or replace function public.catat_pindah_dana(p jsonb)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_tgl date := coalesce(nullif(p->>'tanggal', '')::date, public.hari_ini()); v_j numeric := round(coalesce((p->>'jumlah')::numeric, 0));
  v_dari uuid := nullif(p->>'dari_id', '')::uuid; v_ke uuid := nullif(p->>'ke_id', '')::uuid;
begin
  perform public._wajib_kelola_keuangan();
  if v_dari is null or v_ke is null or v_dari = v_ke then raise exception 'Pilih rekening asal dan tujuan yang berbeda.'; end if;
  if (select count(*) from finance_accounts where id in (v_dari, v_ke) and aktif) <> 2 then raise exception 'Rekening asal dan tujuan harus aktif.'; end if;
  if v_j <= 0 then raise exception 'Isi jumlah yang dipindahkan.'; end if;
  if v_tgl > public.hari_ini() then raise exception 'Tanggal tidak boleh melewati hari ini.'; end if;
  insert into finance_transfers (tanggal, dari_id, ke_id, jumlah, keterangan, dicatat_oleh)
  values (v_tgl, v_dari, v_ke, v_j, nullif(trim(coalesce(p->>'keterangan', '')), ''), public.saya()) returning id into v_id;
  return v_id;
end $$;

create or replace function public.batal_pindah_dana(p_id uuid, p_alasan text)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public._wajib_kelola_keuangan();
  if length(trim(coalesce(p_alasan, ''))) < 5 then raise exception 'Alasan pembatalan wajib diisi (paling sedikit 5 karakter).'; end if;
  update finance_transfers set status = 'batal', alasan_batal = trim(p_alasan), dibatalkan_oleh = public.saya(), dibatalkan_pada = now() where id = p_id and status = 'sah';
  if not found then raise exception 'Pindah dana tidak ditemukan atau sudah dibatalkan.'; end if;
end $$;

/** Daftar transaksi lain dan pindah dana. p: { mulai, selesai, arah? ('masuk'|'keluar'|'pindah'), account_id? } */
create or replace function public.daftar_transaksi_keu(p jsonb)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_mulai date := coalesce(nullif(p->>'mulai', '')::date, date_trunc('month', public.hari_ini())::date);
  v_selesai date := coalesce(nullif(p->>'selesai', '')::date, public.hari_ini()); v_akun uuid := nullif(p->>'account_id', '')::uuid; v_arah text := nullif(p->>'arah', '');
begin
  perform public._wajib_lihat_keuangan();
  return coalesce((select jsonb_agg(x order by x->>'tanggal' desc, x->>'dibuat' desc) from (
    select jsonb_build_object('id', e.id, 'jenis', e.arah, 'tanggal', e.tanggal, 'account_id', e.account_id, 'akun', a.nama, 'kategori', e.kategori, 'uraian', e.uraian,
      'jumlah', e.jumlah, 'pihak', e.pihak, 'nomor_bukti', e.nomor_bukti, 'bukti_id', e.bukti_id, 'nomor', e.nomor, 'status', e.status, 'alasan_batal', e.alasan_batal,
      'pencatat', pe.nama_lengkap, 'dibuat', e.created_at) x
      from finance_entries e join finance_accounts a on a.id = e.account_id left join employees pe on pe.id = e.dicatat_oleh
     where e.tanggal between v_mulai and v_selesai and (v_arah is null or e.arah = v_arah) and (v_akun is null or e.account_id = v_akun)
    union all
    select jsonb_build_object('id', t.id, 'jenis', 'pindah', 'tanggal', t.tanggal, 'account_id', t.dari_id, 'akun', d.nama, 'ke_id', t.ke_id, 'akun_tujuan', k.nama,
      'kategori', 'Pindah dana', 'uraian', coalesce(t.keterangan, 'Pindah dana'), 'jumlah', t.jumlah, 'status', t.status, 'alasan_batal', t.alasan_batal,
      'pencatat', pe.nama_lengkap, 'dibuat', t.created_at)
      from finance_transfers t join finance_accounts d on d.id = t.dari_id join finance_accounts k on k.id = t.ke_id left join employees pe on pe.id = t.dicatat_oleh
     where t.tanggal between v_mulai and v_selesai and (v_arah is null or v_arah = 'pindah') and (v_akun is null or v_akun in (t.dari_id, t.ke_id))) q), '[]'::jsonb);
end $$;

-- ---------------------------------------------------------------------
-- 6. BUKU KAS / REKENING KORAN
-- ---------------------------------------------------------------------
/** p: { mulai, selesai, account_id? } → { akun: [{id, nama, saldo_awal, masuk, keluar, saldo_akhir}], saldo_awal, baris: [... saldo berjalan], masuk, keluar, saldo_akhir } */
create or replace function public.buku_kas(p jsonb)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_mulai date := coalesce(nullif(p->>'mulai', '')::date, date_trunc('month', public.hari_ini())::date);
  v_selesai date := coalesce(nullif(p->>'selesai', '')::date, public.hari_ini()); v_akun uuid := nullif(p->>'account_id', '')::uuid;
  v_akun_json jsonb; v_awal numeric; v_baris jsonb;
begin
  perform public._wajib_lihat_keuangan();
  if v_selesai < v_mulai then raise exception 'Tanggal akhir tidak boleh sebelum tanggal awal.'; end if;
  if v_selesai - v_mulai > 400 then raise exception 'Rentang buku kas paling lama 400 hari.'; end if;
  select coalesce(jsonb_agg(jsonb_build_object('id', a.id, 'nama', a.nama, 'jenis', a.jenis, 'bank', a.bank, 'nomor', a.nomor, 'atas_nama', a.atas_nama,
           'saldo_awal', public._saldo_akun(a.id, v_mulai - 1),
           'masuk', coalesce((select sum(m.masuk) from public._mutasi_keu(v_mulai, v_selesai, a.id) m), 0),
           'keluar', coalesce((select sum(m.keluar) from public._mutasi_keu(v_mulai, v_selesai, a.id) m), 0),
           'saldo_akhir', public._saldo_akun(a.id, v_selesai)) order by a.urutan, a.nama), '[]'::jsonb)
    into v_akun_json from finance_accounts a where (v_akun is null and (a.aktif or exists (select 1 from public._mutasi_keu(v_mulai, v_selesai, a.id)))) or a.id = v_akun;
  select coalesce(sum((x->>'saldo_awal')::numeric), 0) into v_awal from jsonb_array_elements(v_akun_json) x;
  -- Saldo awal rekening yang dimulai di dalam rentang ikut sebagai baris "Saldo awal"
  with m as (
    select a.tanggal_saldo_awal tanggal, a.created_at waktu, a.id account_id, 'saldo_awal' sumber, a.id ref, null::text nomor, 'Saldo awal ' || a.nama uraian,
           null::text pihak, 'Saldo awal' kategori, a.saldo_awal masuk, 0::numeric keluar
      from finance_accounts a where a.saldo_awal > 0 and a.tanggal_saldo_awal between v_mulai and v_selesai and (v_akun is null or a.id = v_akun)
        and (v_akun is not null or a.aktif or exists (select 1 from public._mutasi_keu(v_mulai, v_selesai, a.id)))
    union all
    select * from public._mutasi_keu(v_mulai, v_selesai, v_akun) mk
     where v_akun is not null or not (mk.sumber in ('pindah_masuk','pindah_keluar'))   -- pada buku gabungan pindah dana saling meniadakan
  ), u as (
    select m.*, a.nama akun, v_awal + sum(m.masuk - m.keluar) over (order by m.tanggal, m.waktu, m.sumber, m.ref rows unbounded preceding) saldo
      from m join finance_accounts a on a.id = m.account_id
  )
  select coalesce(jsonb_agg(jsonb_build_object('tanggal', u.tanggal, 'sumber', u.sumber, 'ref', u.ref, 'nomor', u.nomor, 'uraian', u.uraian, 'pihak', u.pihak,
           'kategori', u.kategori, 'akun', u.akun, 'account_id', u.account_id, 'masuk', u.masuk, 'keluar', u.keluar, 'saldo', u.saldo)
           order by u.tanggal, u.waktu, u.sumber, u.ref), '[]'::jsonb)
    into v_baris from u;
  -- saldo awal gabungan tidak memuat rekening yang baru dimulai di dalam rentang (ditampilkan sebagai baris)
  return jsonb_build_object('mulai', v_mulai, 'selesai', v_selesai, 'akun', v_akun_json, 'saldo_awal', v_awal, 'baris', v_baris,
    'masuk', coalesce((select sum((x->>'masuk')::numeric) from jsonb_array_elements(v_baris) x), 0),
    'keluar', coalesce((select sum((x->>'keluar')::numeric) from jsonb_array_elements(v_baris) x), 0),
    'saldo_akhir', coalesce((select sum((x->>'saldo_akhir')::numeric) from jsonb_array_elements(v_akun_json) x), 0));
end $$;

-- ---------------------------------------------------------------------
-- 7. LAPORAN KEUANGAN SATU HALAMAN
-- ---------------------------------------------------------------------
/** p: { mulai, selesai } */
create or replace function public.laporan_keuangan(p jsonb)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_mulai date := coalesce(nullif(p->>'mulai', '')::date, date_trunc('month', public.hari_ini())::date);
  v_selesai date := coalesce(nullif(p->>'selesai', '')::date, public.hari_ini());
begin
  perform public._wajib_lihat_keuangan();
  if v_selesai < v_mulai then raise exception 'Tanggal akhir tidak boleh sebelum tanggal awal.'; end if;
  return jsonb_build_object('mulai', v_mulai, 'selesai', v_selesai,
    -- Pemasukan dari pembayaran tagihan per jenis biaya (berdasarkan tanggal bayar)
    'masuk_tagihan', coalesce((select jsonb_agg(jsonb_build_object('jenis', f.nama, 'jumlah', x.j, 'transaksi', x.n) order by f.urutan, f.nama)
        from fee_types f join lateral (select sum(pi.jumlah) j, count(distinct py.id) n from payment_items pi join payments py on py.id = pi.payment_id join bills b on b.id = pi.bill_id
                                        where b.fee_type_id = f.id and py.status = 'sah' and py.tanggal between v_mulai and v_selesai) x on x.j > 0), '[]'::jsonb),
    'masuk_lain', coalesce((select jsonb_agg(jsonb_build_object('kategori', kategori, 'jumlah', j, 'transaksi', n) order by j desc)
        from (select kategori, sum(jumlah) j, count(*) n from finance_entries where status = 'sah' and arah = 'masuk' and tanggal between v_mulai and v_selesai group by kategori) q), '[]'::jsonb),
    'keluar', coalesce((select jsonb_agg(jsonb_build_object('kategori', kategori, 'jumlah', j, 'transaksi', n) order by j desc)
        from (select kategori, sum(jumlah) j, count(*) n from finance_entries where status = 'sah' and arah = 'keluar' and tanggal between v_mulai and v_selesai group by kategori) q), '[]'::jsonb),
    'akun', coalesce((select jsonb_agg(jsonb_build_object('nama', a.nama, 'jenis', a.jenis, 'saldo_awal', public._saldo_akun(a.id, v_mulai - 1),
           'masuk', coalesce((select sum(m.masuk) from public._mutasi_keu(v_mulai, v_selesai, a.id) m), 0),
           'keluar', coalesce((select sum(m.keluar) from public._mutasi_keu(v_mulai, v_selesai, a.id) m), 0),
           'saldo_akhir', public._saldo_akun(a.id, v_selesai)) order by a.urutan, a.nama)
        from finance_accounts a where a.aktif or exists (select 1 from public._mutasi_keu(v_mulai, v_selesai, a.id))), '[]'::jsonb),
    -- Tagihan yang jatuh tempo dalam rentang, per jenis: nominal, dibayar (sampai hari ini), sisa, persentase lunas
    'tagihan', coalesce((select jsonb_agg(jsonb_build_object('jenis', f.nama, 'siklus', f.siklus, 'tagihan', x.n, 'santri', x.s, 'lunas', x.l, 'nominal', x.nom, 'dibayar', x.d,
           'sisa', x.nom - x.d, 'persen', case when x.nom > 0 then round(x.d * 100 / x.nom, 1) else 100 end) order by f.urutan, f.nama)
        from fee_types f join lateral (select count(*) n, count(distinct student_id) s, count(*) filter (where status = 'lunas') l, coalesce(sum(nominal), 0) nom, coalesce(sum(dibayar), 0) d
                                        from bills where fee_type_id = f.id and status <> 'batal' and jatuh_tempo between v_mulai and v_selesai) x on x.n > 0), '[]'::jsonb),
    'tunggakan', jsonb_build_object('santri', (select count(distinct student_id) from bills where status in ('belum','sebagian') and jatuh_tempo < public.hari_ini()),
                                   'jumlah', (select coalesce(sum(nominal - dibayar), 0) from bills where status in ('belum','sebagian') and jatuh_tempo < public.hari_ini())),
    'subsidi', (select coalesce(sum(potongan), 0) from bills where status <> 'batal' and jatuh_tempo between v_mulai and v_selesai));
end $$;

-- ---------------------------------------------------------------------
-- 8. SURAT KETERANGAN BEBAS TUNGGAKAN
-- ---------------------------------------------------------------------
/** Pemeriksaan: tagihan terbuka (yang sudah ditagihkan sampai hari ini) dan ringkasan tagihan lunas. */
create or replace function public.cek_bebas_tunggakan(p_sid uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform public._wajib_lihat_keuangan();
  return jsonb_build_object(
    'santri', public._santri_keu(p_sid),
    'terbuka', coalesce((select jsonb_agg(jsonb_build_object('bill_id', b.id, 'tagihan', b.nama, 'jatuh_tempo', b.jatuh_tempo, 'sisa', b.nominal - b.dibayar) order by b.jatuh_tempo)
                          from bills b where b.student_id = p_sid and b.status in ('belum','sebagian') and b.tanggal_tagih <= public.hari_ini()), '[]'::jsonb),
    'mendatang', coalesce((select jsonb_agg(jsonb_build_object('bill_id', b.id, 'tagihan', b.nama, 'tanggal_tagih', b.tanggal_tagih, 'sisa', b.nominal - b.dibayar) order by b.tanggal_tagih)
                          from bills b where b.student_id = p_sid and b.status in ('belum','sebagian') and b.tanggal_tagih > public.hari_ini()), '[]'::jsonb),
    'lunas', jsonb_build_object('tagihan', (select count(*) from bills where student_id = p_sid and status = 'lunas'),
                                'jumlah', (select coalesce(sum(nominal), 0) from bills where student_id = p_sid and status = 'lunas'),
                                'terakhir', (select max(py.tanggal) from payments py where py.student_id = p_sid and py.status = 'sah')),
    'riwayat', coalesce((select jsonb_agg(jsonb_build_object('id', l.id, 'nomor', l.nomor, 'tanggal', l.tanggal, 'keperluan', l.keperluan, 'status', l.status) order by l.tanggal desc)
                          from clearance_letters l where l.student_id = p_sid), '[]'::jsonb));
end $$;

/** p: { student_id, keperluan } → { id, nomor, kode_validasi } */
create or replace function public.terbitkan_bebas_tunggakan(p jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare st students; v_cek jsonb; v_ttd uuid; v_nomor text; v_id uuid; v_dok jsonb; v_kep text := trim(coalesce(p->>'keperluan', '')); v_ring jsonb;
begin
  perform public._wajib_kelola_keuangan();
  select * into st from students where id = nullif(p->>'student_id', '')::uuid;
  if st.id is null then raise exception 'Santri tidak ditemukan.'; end if;
  if length(v_kep) < 5 then raise exception 'Tuliskan keperluan surat (minimal 5 huruf), mis. pengambilan ijazah atau pindah sekolah.'; end if;
  v_cek := public.cek_bebas_tunggakan(st.id);
  if jsonb_array_length(v_cek->'terbuka') > 0 then
    raise exception 'Santri ini masih memiliki % tagihan belum lunas (%). Surat bebas tunggakan belum dapat diterbitkan.',
      jsonb_array_length(v_cek->'terbuka'), public._rupiah((select sum((x->>'sisa')::numeric) from jsonb_array_elements(v_cek->'terbuka') x));
  end if;
  v_ttd := public._ttd_keuangan();
  perform set_config('simka.nomor_sistem', '1', true);
  v_nomor := public.ambil_nomor('bebas_tunggakan', public.hari_ini(), 'D', null, 'pondok')->>'nomor';
  perform set_config('simka.nomor_sistem', '', true);
  v_ring := jsonb_build_object('lunas', v_cek->'lunas', 'mendatang', v_cek->'mendatang');
  insert into clearance_letters (student_id, nomor, keperluan, ringkasan, dibuat_oleh)
  values (st.id, v_nomor, v_kep, v_ring, public.saya()) returning id into v_id;
  v_dok := public._daftarkan_dok_keuangan('bebas_tunggakan', 'Surat Keterangan Bebas Tunggakan', v_nomor, 'Bebas tunggakan untuk ' || v_kep,
    st.nama_lengkap || ' (NIS ' || st.nis || ')', to_char(public.hari_ini(), 'DD/MM/YYYY'), 'clearance_letters', v_id, '/keuangan/santri?santri=' || st.id,
    jsonb_build_object('santri', public._santri_keu(st.id), 'nomor', v_nomor, 'keperluan', v_kep, 'ringkasan', v_ring), v_ttd);
  update clearance_letters set kode_validasi = v_dok->>'kode', document_id = (v_dok->>'document_id')::uuid where id = v_id;
  return jsonb_build_object('id', v_id, 'nomor', v_nomor, 'kode_validasi', v_dok->>'kode');
end $$;

create or replace function public.surat_bebas_tunggakan(p_ids uuid[])
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform public._wajib_lihat_keuangan();
  return coalesce((select jsonb_agg(to_jsonb(l) || jsonb_build_object('santri', public._santri_keu(l.student_id),
      'ttd', (select jsonb_build_object('nama', s.nama, 'jabatan', s.jabatan, 'niy', s.niy, 'waktu', s.waktu)
                from document_signatures s where s.document_id = l.document_id order by s.urutan limit 1))
    order by l.created_at) from clearance_letters l where l.id = any(p_ids)), '[]'::jsonb);
end $$;

create or replace function public.daftar_bebas_tunggakan(p jsonb default '{}'::jsonb)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform public._wajib_lihat_keuangan();
  return coalesce((select jsonb_agg(jsonb_build_object('id', l.id, 'student_id', l.student_id, 'nama', st.nama_lengkap, 'nis', st.nis, 'kelas', public._kelas_santri(st.id),
      'nomor', l.nomor, 'tanggal', l.tanggal, 'keperluan', l.keperluan, 'status', l.status, 'alasan_cabut', l.alasan_cabut, 'kode_validasi', l.kode_validasi,
      'pembuat', e.nama_lengkap) order by l.created_at desc)
    from clearance_letters l join students st on st.id = l.student_id left join employees e on e.id = l.dibuat_oleh
   where (nullif(p->>'student_id', '') is null or l.student_id = (p->>'student_id')::uuid)), '[]'::jsonb);
end $$;

create or replace function public.cabut_bebas_tunggakan(p_id uuid, p_alasan text)
returns void language plpgsql security definer set search_path = public as $$
declare l clearance_letters;
begin
  perform public._wajib_kelola_keuangan();
  if length(trim(coalesce(p_alasan, ''))) < 5 then raise exception 'Alasan pencabutan wajib diisi (paling sedikit 5 karakter).'; end if;
  select * into l from clearance_letters where id = p_id for update;
  if l.id is null or l.status <> 'sah' then raise exception 'Surat tidak ditemukan atau sudah dicabut.'; end if;
  update clearance_letters set status = 'dicabut', alasan_cabut = trim(p_alasan) where id = p_id;
  update document_registry set status = 'dicabut', dicabut_pada = now(), dicabut_oleh = public.saya(), alasan_cabut = trim(p_alasan) where id = l.document_id;
end $$;

-- ---------------------------------------------------------------------
-- 9. PENAMBALAN DI TEMPAT
-- ---------------------------------------------------------------------
create or replace function pg_temp.tambal(p_fn text, p_cari text, p_ganti text, p_tanda text)
returns text language plpgsql as $$
declare r record; v text; n int := 0;
begin
  for r in select p.oid from pg_proc p join pg_namespace s on s.oid = p.pronamespace where s.nspname = 'public' and p.proname = p_fn loop
    v := pg_get_functiondef(r.oid);
    if position(p_tanda in v) > 0 then n := n + 1; continue; end if;
    if position(p_cari in v) = 0 then raise notice 'Penambalan %: teks acuan tidak ditemukan, dilewati.', p_fn; continue; end if;
    execute replace(v, p_cari, p_ganti); n := n + 1;
  end loop;
  return p_fn || ': ' || n;
end $$;
-- Pembayaran memilih rekening/kas tujuan (account_id); kosong = bawaan (tunai → kas, transfer → rekening bank)
select pg_temp.tambal('catat_pembayaran', 'v_total, nullif(p->>''bukti_id'', '''')::uuid, public.saya(), v_riwayat)',
  'v_total, nullif(p->>''bukti_id'', '''')::uuid, public.saya(), v_riwayat, case when v_riwayat then null else nullif(p->>''account_id'', '''')::uuid end)', 'account_id');
select pg_temp.tambal('catat_pembayaran', 'bukti_id, dicatat_oleh, riwayat)', 'bukti_id, dicatat_oleh, riwayat, account_id)', 'riwayat, account_id)');
-- Ringkasan: saldo seluruh rekening dan pengeluaran bulan ini
select pg_temp.tambal('ringkasan_keuangan', '''ada_penanda_tangan'', exists',
  '''saldo'', coalesce((select sum(public._saldo_akun(a.id, null)) from finance_accounts a where a.aktif), 0),
    ''keluar_bulan_ini'', (select coalesce(sum(jumlah), 0) from finance_entries where status = ''sah'' and arah = ''keluar'' and tanggal >= v_awal),
    ''masuk_lain_bulan_ini'', (select coalesce(sum(jumlah), 0) from finance_entries where status = ''sah'' and arah = ''masuk'' and tanggal >= v_awal),
    ''ada_penanda_tangan'', exists', 'keluar_bulan_ini');
-- Pemberitahuan SP-3 (14.6.0) membuka rincian keuangan santri tersebut
select pg_temp.tambal('tg_sp_santri_surat', '''/keuangan'', ''CashRegister''', '''/keuangan/santri?santri='' || w.student_id, ''CashRegister''', '/keuangan/santri?santri=');

-- ---------------------------------------------------------------------
-- 10. HAK EKSEKUSI
-- ---------------------------------------------------------------------
do $$ declare f text; begin
  foreach f in array array['daftar_rekening_keu()', 'simpan_rekening_keu(jsonb)', 'hapus_rekening_keu(uuid)', 'catat_transaksi_keu(jsonb)', 'batal_transaksi_keu(uuid,text)',
                           'catat_pindah_dana(jsonb)', 'batal_pindah_dana(uuid,text)', 'daftar_transaksi_keu(jsonb)', 'buku_kas(jsonb)', 'laporan_keuangan(jsonb)',
                           'cek_bebas_tunggakan(uuid)', 'terbitkan_bebas_tunggakan(jsonb)', 'surat_bebas_tunggakan(uuid[])', 'daftar_bebas_tunggakan(jsonb)',
                           'cabut_bebas_tunggakan(uuid,text)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  foreach f in array array['_akun_bawaan(text,text)', 'tg_akun_pembayaran()', '_mutasi_keu(date,date,uuid)', '_saldo_akun(uuid,date)', '_akun_json(finance_accounts)'] loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- 11. PEMERIKSAAN — hasil yang benar: 6 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select '1. Tabel rekening, transaksi, pindah dana, bebas tunggakan dengan RLS' as pemeriksaan,
       case when (select count(*) from pg_class where relname in ('finance_accounts','finance_entries','finance_transfers','clearance_letters') and relrowsecurity) = 4
            then 'Sesuai' else 'Periksa' end as hasil
union all
select '2. Kas tunai tersedia dan rekening lama dipindahkan',
       case when exists (select 1 from public.finance_accounts where jenis = 'kas') then 'Sesuai' else 'Periksa' end
union all
select '3. Pembayaran tercatat pada rekening/kas',
       case when not exists (select 1 from public.payments where account_id is null and status = 'sah' and not coalesce(riwayat, false))
             and position('account_id' in pg_get_functiondef('public.catat_pembayaran(jsonb)'::regprocedure)) > 0 then 'Sesuai' else 'Periksa' end
union all
select '4. Format nomor SKBT, BKK, BKM',
       case when (select count(*) from public.doc_number_formats where kode in ('bebas_tunggakan','bukti_keluar','bukti_masuk')) = 3 then 'Sesuai' else 'Periksa' end
union all
select '5. Buku kas dan laporan keuangan tersedia',
       case when to_regprocedure('public.buku_kas(jsonb)') is not null and to_regprocedure('public.laporan_keuangan(jsonb)') is not null then 'Sesuai' else 'Periksa' end
union all
select '6. Ringkasan memuat saldo dan pengeluaran',
       case when position('keluar_bulan_ini' in pg_get_functiondef('public.ringkasan_keuangan()'::regprocedure)) > 0 then 'Sesuai' else 'Periksa' end;
