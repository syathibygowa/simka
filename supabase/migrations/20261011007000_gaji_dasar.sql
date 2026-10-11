-- SIMKA PRO | supabase/migrations/20261011007000_gaji_dasar.sql | v1.0 | Fase 11 – Tahap 1 Menu Gaji: hak, ketentuan, rekening | 11/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 11 · Migrasi 70: Dasar modul Gaji (Blueprint Bagian 36)
--   * Hak gaji:
--       - Pengelola  : superadmin, pemegang hak fitur slip_gaji tingkat 3 (jabatan Bendahara), admin ber-izin kelola_gaji.
--       - Pembaca    : pengelola + admin ber-izin lihat_gaji.
--     Tarif (salary_rates) kini dibaca pembaca gaji dan diubah pengelola gaji (sebelumnya superadmin + Bendahara).
--   * Ketentuan gaji (institution_settings kunci "gaji"): slip tampil di akun pegawai (bawaan TIDAK, arahan yayasan),
--     tanda tangan Direktur pada slip (bawaan tidak; Bendahara selalu), pembulatan, sakelar potongan izin/sakit/cuti/terlambat,
--     tanggal gajian, honorer menerima tunjangan jabatan, info kelebihan/kekurangan jam, catatan kaki slip.
--   * Rekening pegawai (employee_bank_accounts): cara bayar (transfer/tunai), bank, nomor rekening, atas nama.
--     Dibaca pemilik dan pembaca gaji; diubah pengelola gaji lewat fungsi simpan_rekening (satu baris atau impor massal).
--   * pegawai_gaji(): daftar pegawai aktif beserta data penentu gaji dan rekening untuk pengelola/pembaca gaji
--     (Bendahara adalah pegawai biasa secara peran, sehingga tidak dapat membaca v_pegawai pegawai lain).
-- Jalankan SETELAH migrasi 6900. Aman dijalankan ulang.
-- =====================================================================

insert into public.admin_capabilities (kode, nama, urutan) values
  ('kelola_gaji', 'Mengelola gaji: tarif, rekening, periode gaji, potongan, dan penerbitan slip', 45),
  ('lihat_gaji',  'Melihat data gaji seluruh pegawai (tanpa mengubah)', 46)
on conflict (kode) do nothing;

insert into public.institution_settings (kunci, nilai) values ('gaji', jsonb_build_object(
  'slip_pegawai', false, 'ttd_direktur', false, 'pembulatan', 100,
  'potong_izin', false, 'potong_sakit', false, 'potong_cuti', false, 'potong_terlambat', false,
  'tanggal_gajian', 1, 'honorer_tunjangan_jabatan', true, 'info_beban_kerja', true, 'catatan_slip', ''))
on conflict (kunci) do nothing;

-- ---------------------------------------------------------------------
-- 1. HAK
-- ---------------------------------------------------------------------
create or replace function public.boleh_kelola_gaji()
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_superadmin() or public.admin_boleh('kelola_gaji') or public.tingkat_fitur('slip_gaji') >= 3
$$;

create or replace function public.boleh_lihat_gaji()
returns boolean language sql stable security definer set search_path = public as $$
  select public.boleh_kelola_gaji() or public.admin_boleh('lihat_gaji')
$$;

drop policy if exists baca on public.salary_rates;
drop policy if exists kelola on public.salary_rates;
create policy baca on public.salary_rates for select to authenticated using (public.boleh_lihat_gaji());
create policy kelola on public.salary_rates for all to authenticated
  using (public.boleh_kelola_gaji()) with check (public.boleh_kelola_gaji());

-- ---------------------------------------------------------------------
-- 2. KETENTUAN GAJI
-- ---------------------------------------------------------------------
create or replace function public._pengaturan_gaji()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('slip_pegawai', false, 'ttd_direktur', false, 'pembulatan', 100,
           'potong_izin', false, 'potong_sakit', false, 'potong_cuti', false, 'potong_terlambat', false,
           'tanggal_gajian', 1, 'honorer_tunjangan_jabatan', true, 'info_beban_kerja', true, 'catatan_slip', '')
         || coalesce((select nilai from institution_settings where kunci = 'gaji'), '{}'::jsonb)
$$;

/** Ketentuan gaji. Pegawai lain hanya menerima penanda slip tampil atau tidak. */
create or replace function public.pengaturan_gaji()
returns jsonb language sql stable security definer set search_path = public as $$
  select case when public.boleh_lihat_gaji() then public._pengaturan_gaji()
              when public.saya() is not null then jsonb_build_object('slip_pegawai', (public._pengaturan_gaji()->>'slip_pegawai')::boolean)
              else '{}'::jsonb end
$$;

create or replace function public.simpan_pengaturan_gaji(p jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare v jsonb := public._pengaturan_gaji(); k text; v_bulat int; v_tgl int;
begin
  if not public.boleh_kelola_gaji() then raise exception 'Anda tidak berwenang mengatur ketentuan gaji.' using errcode = '42501'; end if;
  foreach k in array array['slip_pegawai','ttd_direktur','potong_izin','potong_sakit','potong_cuti','potong_terlambat',
                           'honorer_tunjangan_jabatan','info_beban_kerja'] loop
    if p ? k then v := v || jsonb_build_object(k, coalesce((p->>k)::boolean, false)); end if;
  end loop;
  if p ? 'pembulatan' then
    v_bulat := coalesce((p->>'pembulatan')::int, 100);
    if v_bulat not in (1, 100, 500, 1000) then raise exception 'Pembulatan hanya 1, 100, 500, atau 1.000 rupiah.'; end if;
    v := v || jsonb_build_object('pembulatan', v_bulat);
  end if;
  if p ? 'tanggal_gajian' then
    v_tgl := coalesce((p->>'tanggal_gajian')::int, 1);
    if v_tgl < 1 or v_tgl > 28 then raise exception 'Tanggal gajian antara 1 dan 28.'; end if;
    v := v || jsonb_build_object('tanggal_gajian', v_tgl);
  end if;
  if p ? 'catatan_slip' then v := v || jsonb_build_object('catatan_slip', left(trim(coalesce(p->>'catatan_slip', '')), 300)); end if;
  insert into institution_settings (kunci, nilai, updated_by) values ('gaji', v, public.saya())
  on conflict (kunci) do update set nilai = excluded.nilai, updated_at = now(), updated_by = excluded.updated_by;
  return public._pengaturan_gaji();
end $$;

/** Penanda menu dan tab Gaji untuk akun yang sedang masuk. */
create or replace function public.hak_gaji()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'kelola', public.boleh_kelola_gaji(),
    'lihat', public.boleh_lihat_gaji(),
    'superadmin', public.is_superadmin(),
    'bendahara', public.is_bendahara(),
    'slip_saya', public.saya() is not null and coalesce((public._pengaturan_gaji()->>'slip_pegawai')::boolean, false),
    'tampil', public.boleh_lihat_gaji()
              or (public.saya() is not null and coalesce((public._pengaturan_gaji()->>'slip_pegawai')::boolean, false)),
    'pengaturan', public.pengaturan_gaji())
$$;

-- ---------------------------------------------------------------------
-- 3. REKENING PEGAWAI
-- ---------------------------------------------------------------------
create table if not exists public.employee_bank_accounts (
  employee_id    uuid primary key references public.employees(id) on delete cascade,
  cara_bayar     text not null default 'transfer' check (cara_bayar in ('transfer','tunai')),
  bank           text,
  nomor_rekening text check (nomor_rekening is null or nomor_rekening ~ '^[0-9][0-9 .-]{3,29}$'),
  atas_nama      text,
  catatan        text,
  updated_by     uuid references public.employees(id) on delete set null,
  updated_at     timestamptz not null default now(),
  check (cara_bayar = 'tunai' or (bank is not null and nomor_rekening is not null and atas_nama is not null))
);
comment on table public.employee_bank_accounts is 'Rekening penerimaan gaji pegawai (tampil di slip). Diubah pengelola gaji lewat simpan_rekening.';

alter table public.employee_bank_accounts enable row level security;
drop policy if exists baca on public.employee_bank_accounts;
create policy baca on public.employee_bank_accounts for select to authenticated
  using (employee_id = public.saya() or public.boleh_lihat_gaji());
grant select on public.employee_bank_accounts to authenticated;

/** Simpan rekening satu pegawai (objek) atau banyak sekaligus (larik, untuk impor Excel).
 *  Setiap baris: employee_id atau niy, cara_bayar, bank, nomor_rekening, atas_nama, catatan.
 *  Hasil: { disimpan, gagal: [{baris, pesan}] }. */
create or replace function public.simpan_rekening(p jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare r jsonb; i int := 0; v_emp uuid; v_cara text; v_bank text; v_no text; v_an text; n int := 0; v_gagal jsonb := '[]'::jsonb;
begin
  if not public.boleh_kelola_gaji() then raise exception 'Anda tidak berwenang mengubah rekening pegawai.' using errcode = '42501'; end if;
  for r in select x from jsonb_array_elements(case when jsonb_typeof(p) = 'array' then p else jsonb_build_array(p) end) x loop
    i := i + 1;
    begin
      v_emp := nullif(r->>'employee_id', '')::uuid;
      if v_emp is null and nullif(trim(r->>'niy'), '') is not null then
        select id into v_emp from employees where niy = trim(r->>'niy');
      end if;
      if v_emp is null or not exists (select 1 from employees where id = v_emp) then raise exception 'Pegawai tidak ditemukan (periksa NIY).'; end if;
      v_cara := coalesce(nullif(lower(trim(r->>'cara_bayar')), ''), 'transfer');
      if v_cara not in ('transfer','tunai') then raise exception 'Cara bayar hanya transfer atau tunai.'; end if;
      v_bank := nullif(trim(r->>'bank'), '');
      v_no := nullif(regexp_replace(trim(coalesce(r->>'nomor_rekening', '')), '\s+', '', 'g'), '');
      v_an := nullif(trim(r->>'atas_nama'), '');
      if v_cara = 'transfer' then
        if v_bank is null or v_no is null or v_an is null then raise exception 'Transfer memerlukan nama bank, nomor rekening, dan atas nama.'; end if;
        if v_no !~ '^[0-9][0-9.-]{3,29}$' then raise exception 'Nomor rekening hanya berisi angka (boleh titik atau tanda hubung).'; end if;
      end if;
      insert into employee_bank_accounts (employee_id, cara_bayar, bank, nomor_rekening, atas_nama, catatan, updated_by, updated_at)
      values (v_emp, v_cara, v_bank, v_no, v_an, nullif(trim(r->>'catatan'), ''), public.saya(), now())
      on conflict (employee_id) do update set cara_bayar = excluded.cara_bayar, bank = excluded.bank, nomor_rekening = excluded.nomor_rekening,
        atas_nama = excluded.atas_nama, catatan = excluded.catatan, updated_by = excluded.updated_by, updated_at = now();
      n := n + 1;
    exception when others then
      if jsonb_typeof(p) <> 'array' then raise; end if;
      v_gagal := v_gagal || jsonb_build_object('baris', i, 'pesan', sqlerrm);
    end;
  end loop;
  return jsonb_build_object('disimpan', n, 'gagal', v_gagal);
end $$;

create or replace function public.hapus_rekening(p_emp uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  if not public.boleh_kelola_gaji() then raise exception 'Anda tidak berwenang mengubah rekening pegawai.' using errcode = '42501'; end if;
  delete from employee_bank_accounts where employee_id = p_emp;
end $$;

-- ---------------------------------------------------------------------
-- 4. DATA PEGAWAI UNTUK GAJI
-- ---------------------------------------------------------------------
/** Pegawai aktif beserta data penentu gaji (jabatan, status, pendidikan, TMT, level) dan rekening.
 *  Hanya pengelola/pembaca gaji. Bentuk baris mengikuti v_pegawai agar perhitungan di aplikasi sama. */
create or replace function public.pegawai_gaji()
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if not public.boleh_lihat_gaji() then raise exception 'Anda tidak berwenang melihat data gaji.' using errcode = '42501'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', v.id, 'niy', v.niy, 'nama_lengkap', v.nama_lengkap, 'jenis_kelamin', v.jenis_kelamin,
      'org_unit_id', v.org_unit_id, 'nama_unit', v.nama_unit,
      'tmt_tugas', v.tmt_tugas, 'status_kepegawaian', v.status_kepegawaian, 'kategori_honorer', v.kategori_honorer,
      'pendidikan_terakhir', v.pendidikan_terakhir, 'level_muhaffizh', v.level_muhaffizh, 'status_keaktifan', v.status_keaktifan,
      'jabatan_struktural', v.jabatan_struktural, 'structural_position_id', v.structural_position_id, 'unit_struktural_id', v.unit_struktural_id,
      'jabatan_fungsional', v.jabatan_fungsional, 'fungsional_ids', v.fungsional_ids, 'no_hp', v.no_hp,
      'rekening', case when b.employee_id is null then null else jsonb_build_object('cara_bayar', b.cara_bayar, 'bank', b.bank,
                    'nomor_rekening', b.nomor_rekening, 'atas_nama', b.atas_nama, 'catatan', b.catatan, 'updated_at', b.updated_at) end)
      order by v.nama_lengkap)
    from v_pegawai v left join employee_bank_accounts b on b.employee_id = v.id
    where v.status_keaktifan = 'aktif' and v.peran <> 'superadmin'), '[]'::jsonb);
end $$;

-- ---------------------------------------------------------------------
-- 5. HAK EKSEKUSI
-- ---------------------------------------------------------------------
do $$
declare f text;
begin
  foreach f in array array['boleh_kelola_gaji()','boleh_lihat_gaji()','pengaturan_gaji()','simpan_pengaturan_gaji(jsonb)','hak_gaji()',
    'simpan_rekening(jsonb)','hapus_rekening(uuid)','pegawai_gaji()'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  execute 'revoke execute on function public._pengaturan_gaji() from public, anon, authenticated';
end $$;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN (hasil yang benar: baris 1–6 "Sesuai"; baris 7–8 keterangan data)
-- ---------------------------------------------------------------------
select '1. Izin admin kelola_gaji dan lihat_gaji' as pemeriksaan,
       case when (select count(*) from admin_capabilities where kode in ('kelola_gaji','lihat_gaji')) = 2 then 'Sesuai' else 'Periksa' end as hasil
union all select '2. Ketentuan gaji tersimpan', case when exists (select 1 from institution_settings where kunci = 'gaji') then 'Sesuai' else 'Periksa' end
union all select '3. Slip bawaan tidak tampil di akun pegawai', case when (public._pengaturan_gaji()->>'slip_pegawai')::boolean = false then 'Sesuai' else 'Diaktifkan (sesuai pilihan)' end
union all select '4. Tabel rekening tertutup untuk tulis langsung', case when (select relrowsecurity from pg_class where relname = 'employee_bank_accounts')
  and (select count(*) from pg_policies where tablename = 'employee_bank_accounts' and cmd <> 'SELECT') = 0 then 'Sesuai' else 'Periksa' end
union all select '5. Fungsi gaji (6)', case when (select count(*) from pg_proc where proname in ('boleh_kelola_gaji','boleh_lihat_gaji','pengaturan_gaji',
  'simpan_pengaturan_gaji','hak_gaji','pegawai_gaji')) = 6 then 'Sesuai' else 'Periksa' end
union all select '6. Kebijakan tarif memakai hak gaji', case when (select qual from pg_policies where tablename = 'salary_rates' and policyname = 'baca') like '%boleh_lihat_gaji%' then 'Sesuai' else 'Periksa' end
union all select '7. Pemegang jabatan Bendahara', (select count(*) || ' pegawai' from employee_structurals es join structural_positions sp on sp.id = es.structural_position_id where sp.kode = 'BENDAHARA')
union all select '8. Pegawai aktif dengan rekening', (select count(*) || ' dari ' || (select count(*) from employees where status_keaktifan = 'aktif' and peran <> 'superadmin') || ' pegawai'
  from employee_bank_accounts b join employees e on e.id = b.employee_id where e.status_keaktifan = 'aktif');
