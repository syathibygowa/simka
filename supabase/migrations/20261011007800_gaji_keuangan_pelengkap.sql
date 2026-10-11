-- SIMKA PRO | supabase/migrations/20261011007800_gaji_keuangan_pelengkap.sql | v1.0 | Fase 11 & 13 – Pelengkap sesuai blueprint | 11/10/2026
-- =====================================================================
-- SIMKA PRO · Migrasi 78: Pelengkap Gaji (Bagian 36) dan Keuangan santri (Bagian 37)
-- GAJI
--   1. Log audit: setiap koreksi/penetapan/pinjaman/simpanan/periode tercatat di log audit (siapa, kapan, apa, alasan);
--      log gaji/keuangan hanya terbaca oleh yang berhak (admin ber-izin audit_log tidak otomatis melihatnya)
--   2. impor_komponen_gaji : impor Excel jam honor (guru/muhaffizh), potongan lain, dan tambahan per pegawai
--   3. perkiraan_gaji_saya : perkiraan potongan berjalan untuk pegawai — HANYA bila Ketentuan "slip tampil di akun pegawai" aktif
--   4. Notifikasi langsung kepada pengelola gaji saat data penentu gaji berubah (status, pendidikan, level, kategori, jabatan)
-- KEUANGAN SANTRI
--   5. Siklus "semesteran" (ganjil/genap per tahun ajaran)
--   6. Jenis biaya dapat dibatasi berlaku untuk jenjang/kelas tertentu (otomatis saat tagihan dibuat)
--   7. kelompok_keuangan : daftar kelas/kamar/halaqah untuk sasaran tagihan dan saringan; posisi tunggakan memuat kamar dan halaqah
--   8. Template WA "tagihan baru" dan "pengingat jatuh tempo"
-- Jalankan SETELAH migrasi 7700. Aman dijalankan ulang.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. LOG AUDIT GAJI
-- ---------------------------------------------------------------------
-- a. Tabel yang jarang berubah: pencatatan otomatis per baris
do $$
declare t text;
begin
  foreach t in array array['salary_decisions','employee_loans','loan_payments','savings_programs','savings_members','savings_transactions',
                           'employee_bank_accounts','payroll_slip_requests'] loop
    execute format('drop trigger if exists zz_audit on public.%I', t);
    execute format('create trigger zz_audit after insert or update or delete on public.%I for each row execute function public.tg_audit()', t);
  end loop;
end $$;

-- b. Komponen dan baris gaji sering dihitung ulang, sehingga dicatat per tindakan pengguna (bukan per baris).
create or replace function public._audit_gaji(p_aksi text, p jsonb)
returns void language plpgsql volatile security definer set search_path = public as $$
declare i payroll_items; l payroll_lines; v_per text; v_ring text; v_ref text;
begin
  if p ? 'p_item' then
    select * into i from payroll_items where id = (p->>'p_item')::uuid;
    select * into l from payroll_lines where id = i.line_id;
  elsif p ? 'p_line' then
    select * into l from payroll_lines where id = (p->>'p_line')::uuid;
  end if;
  select public.nama_bulan_periode(tahun, bulan) into v_per from payroll_periods where id = coalesce(l.period_id, nullif(p->>'p_period', '')::uuid);
  v_ring := case p_aksi
    when 'ubah_item_gaji' then 'Koreksi ' || coalesce(i.label, 'komponen') || ': ' || public._rupiah(i.besaran) || ' → '
         || case when p->>'p_besaran' is null then coalesce(p->>'p_jumlah', '–') || ' jam' else public._rupiah((p->>'p_besaran')::numeric) end
         || ' (' || coalesce(p->>'p_alasan', '') || ')'
    when 'kembalikan_item_gaji' then 'Kembalikan ' || coalesce(i.label, 'komponen') || ' ke nilai skema ' || public._rupiah(i.besaran_skema)
    when 'tambah_item_gaji' then 'Tambah ' || coalesce(p->'p'->>'jenis', 'pendapatan') || ' "' || coalesce(p->'p'->>'label', '') || '" '
         || public._rupiah((p->'p'->>'besaran')::numeric) || coalesce(' (' || nullif(p->'p'->>'alasan', '') || ')', '')
    when 'hapus_item_gaji' then 'Hapus komponen ' || coalesce(i.label, '') || ' ' || public._rupiah(i.besaran)
    when 'atur_diterima_gaji' then case when p->>'p_diterima' is null then 'Hapus penetapan jumlah diterima'
         else 'Tetapkan jumlah diterima ' || public._rupiah((p->>'p_diterima')::numeric) || ' (semula ' || public._rupiah(l.diterima) || '; ' || coalesce(p->>'p_alasan', '') || ')' end
    when 'impor_diterima_gaji' then 'Impor jumlah diterima: ' || jsonb_array_length(coalesce(p->'p', '[]'::jsonb)) || ' baris'
    when 'impor_komponen_gaji' then 'Impor komponen (jam honor/potongan/tambahan): ' || jsonb_array_length(coalesce(p->'p', '[]'::jsonb)) || ' baris'
    when 'buat_periode_gaji' then 'Buat periode gaji ' || public.nama_bulan_periode((p->>'p_tahun')::int, (p->>'p_bulan')::int)
    when 'hapus_periode_gaji' then 'Hapus periode gaji'
    when 'ubah_periode_gaji' then 'Ubah periode gaji (tanggal bayar/catatan)'
    when 'tambah_baris_gaji' then 'Tambah pegawai ke periode'
    when 'hapus_baris_gaji' then 'Hapus pegawai dari periode'
    when 'ajukan_periode_gaji' then 'Ajukan penerbitan slip'
    when 'tarik_pengajuan_gaji' then 'Tarik pengajuan penerbitan'
    when 'mulai_revisi_slip' then 'Mulai revisi slip (' || coalesce(p->>'p_alasan', '') || ')'
    when 'batalkan_revisi_slip' then 'Batalkan revisi slip'
    when 'tutup_slip_pegawai' then 'Tutup akses slip pegawai'
    when 'tanggapi_permintaan_slip' then 'Tanggapi permintaan slip: ' || coalesce(p->>'p_aksi', '')
    when 'simpan_penetapan_gaji' then 'Simpan penetapan yayasan ' || coalesce(p->'p'->>'mode', '') || ' ' || public._rupiah((p->'p'->>'nilai')::numeric)
    when 'hapus_penetapan_gaji' then 'Hapus penetapan yayasan'
    when 'simpan_pinjaman' then 'Simpan pinjaman ' || public._rupiah((p->'p'->>'pokok')::numeric)
    when 'bayar_pinjaman' then 'Catat pembayaran pinjaman ' || public._rupiah((p->>'p_besaran')::numeric)
    when 'batalkan_pinjaman' then 'Batalkan pinjaman (' || coalesce(p->>'p_alasan', '') || ')'
    when 'catat_transaksi_simpanan' then 'Transaksi simpanan ' || coalesce(p->'p'->>'jenis', '') || ' ' || public._rupiah((p->'p'->>'besaran')::numeric)
    else replace(p_aksi, '_', ' ') end;
  v_ref := coalesce(p->>'p_item', p->>'p_line', p->>'p_period', p->>'p_loan', p->>'p_id', p->'p'->>'id', p->'p'->>'employee_id');
  perform public.catat_audit(p_aksi, 'gaji', v_ref, concat_ws(' · ', l.data->>'nama', v_per, v_ring), p);
end $$;
revoke execute on function public._audit_gaji(text,jsonb) from public, anon, authenticated;

-- Sisipkan pencatatan pada setiap fungsi gaji yang mengubah data (sesudah pemeriksaan hak kelola).
do $$
declare f record; d text; v_args text;
begin
  for f in select p.oid, p.proname, pg_get_function_identity_arguments(p.oid) args from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname = 'public' and p.prosrc like '%_wajib_kelola_gaji();%' and p.prosrc not like '%_audit_gaji(%'
              and p.proname in ('ubah_item_gaji','kembalikan_item_gaji','tambah_item_gaji','hapus_item_gaji','atur_diterima_gaji','impor_diterima_gaji',
                'buat_periode_gaji','hapus_periode_gaji','ubah_periode_gaji','tambah_baris_gaji','hapus_baris_gaji','ajukan_periode_gaji','tarik_pengajuan_gaji',
                'mulai_revisi_slip','batalkan_revisi_slip','tutup_slip_pegawai','tanggapi_permintaan_slip','simpan_penetapan_gaji','hapus_penetapan_gaji',
                'simpan_pinjaman','bayar_pinjaman','batalkan_pinjaman','catat_transaksi_simpanan') loop
    select string_agg(format('%L, %s', a, a), ', ') into v_args
      from (select split_part(trim(x), ' ', 1) a from unnest(string_to_array(f.args, ',')) x) q;
    d := pg_get_functiondef(f.oid);
    d := regexp_replace(d, '_wajib_kelola_gaji\(\);', format('_wajib_kelola_gaji(); perform public._audit_gaji(%L, jsonb_build_object(%s));', f.proname, v_args));
    execute d;
  end loop;
end $$;

-- c. Log audit gaji dan keuangan hanya terbaca oleh yang berhak atas data itu (admin ber-izin audit_log tidak otomatis)
drop policy if exists baca on public.audit_logs;
create policy baca on public.audit_logs for select to authenticated
  using (created_at > now() - interval '30 days'
         and (employee_id = public.saya() or public.admin_boleh('audit_log'))
         and (tabel is null or tabel not in ('gaji','salary_rates','salary_decisions','employee_loans','loan_payments','savings_programs','savings_members',
                                             'savings_transactions','employee_bank_accounts','payroll_slip_requests') or public.boleh_lihat_gaji())
         and (tabel is null or tabel not in ('fee_types','fee_rates','fee_subsidies','bills','payments','payment_items','billing_letters') or public.boleh_lihat_keuangan())
         and (tabel is null or tabel <> 'sensitive_access' or public.is_superadmin()));

-- ---------------------------------------------------------------------
-- 2. IMPOR EXCEL: JAM HONOR, POTONGAN LAIN, TAMBAHAN
-- ---------------------------------------------------------------------
/** p: [{ niy, jam_guru, jam_muhaffizh, potongan, ket_potongan, tambahan, ket_tambahan }]. Kolom kosong = tidak diubah.
    Potongan/tambahan hasil impor sebelumnya diganti (tidak menumpuk). Hasil per baris: {niy, nama, hasil (diubah/lewati/galat), ket}. */
create or replace function public.impor_komponen_gaji(p_period uuid, p jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare r jsonb; l payroll_lines; v_hasil jsonb := '[]'::jsonb; v_ket text[]; v_item uuid; v_kode text; v_kolom text; v_nilai numeric;
begin
  perform public._wajib_kelola_gaji();
  perform public._wajib_periode_draf(p_period);
  perform public._audit_gaji('impor_komponen_gaji', jsonb_build_object('p_period', p_period, 'p', p));
  for r in select * from jsonb_array_elements(coalesce(p, '[]'::jsonb)) loop
    v_ket := '{}';
    select * into l from payroll_lines where period_id = p_period and data->>'niy' = trim(r->>'niy');
    if l.id is null then
      v_hasil := v_hasil || jsonb_build_array(jsonb_build_object('niy', r->>'niy', 'hasil', 'lewati', 'ket', 'NIY tidak ada pada periode ini')); continue;
    end if;
    begin
      foreach v_kolom in array array['jam_guru','jam_muhaffizh'] loop
        if nullif(r->>v_kolom, '') is null then continue; end if;
        v_kode := replace(v_kolom, 'jam_', ''); v_nilai := (r->>v_kolom)::numeric;
        select id into v_item from payroll_items where line_id = l.id and kategori = 'honor' and kode = v_kode;
        if v_item is null then v_ket := array_append(v_ket, 'tidak ada honor ' || v_kode);
        else perform public.ubah_item_gaji(v_item, null, v_nilai, 'Impor Excel'); v_ket := array_append(v_ket, 'jam ' || v_kode || ' ' || v_nilai); end if;
      end loop;
      foreach v_kolom in array array['potongan','tambahan'] loop
        if nullif(r->>v_kolom, '') is null then continue; end if;
        delete from payroll_items where line_id = l.id and kategori = case v_kolom when 'potongan' then 'potongan_lain' else 'tambahan' end and alasan = 'Impor Excel';
        v_nilai := round((r->>v_kolom)::numeric);
        if v_nilai > 0 then
          perform public.tambah_item_gaji(l.id, jsonb_build_object('jenis', case v_kolom when 'potongan' then 'potongan' else 'pendapatan' end,
            'label', coalesce(nullif(trim(r->>('ket_' || v_kolom)), ''), case v_kolom when 'potongan' then 'Potongan lain' else 'Tambahan' end),
            'besaran', v_nilai, 'alasan', 'Impor Excel'));
        else perform public._hitung_baris(l.id); end if;
        v_ket := array_append(v_ket, v_kolom || ' ' || public._rupiah(v_nilai));
      end loop;
      v_hasil := v_hasil || jsonb_build_array(jsonb_build_object('niy', r->>'niy', 'nama', l.data->>'nama', 'hasil', 'diubah', 'ket', array_to_string(v_ket, '; ')));
    exception when others then
      v_hasil := v_hasil || jsonb_build_array(jsonb_build_object('niy', r->>'niy', 'nama', l.data->>'nama', 'hasil', 'galat', 'ket', sqlerrm));
    end;
  end loop;
  return v_hasil;
end $$;

-- ---------------------------------------------------------------------
-- 3. PERKIRAAN POTONGAN BERJALAN (pegawai) — hanya bila slip tampil di akun pegawai
-- ---------------------------------------------------------------------
create or replace function public.perkiraan_gaji_saya(p_bulan date default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_emp uuid := public.saya(); v_awal date := date_trunc('month', coalesce(p_bulan, public.hari_ini()))::date; v_akhir date;
  v_set jsonb := public._pengaturan_gaji(); v_bulat int; k record; v_kh jsonb; v_tugas jsonb := '[]'::jsonb; v_pot boolean;
begin
  if v_emp is null then raise exception 'Sesi tidak ditemukan.'; end if;
  if not coalesce((v_set->>'slip_pegawai')::boolean, false) then
    raise exception 'Perkiraan potongan tidak ditampilkan di akun pegawai.' using errcode = '42501'; end if;
  v_akhir := (v_awal + interval '1 month - 1 day')::date;
  v_bulat := greatest(1, coalesce((v_set->>'pembulatan')::int, 100));
  v_pot := coalesce((v_set->>'potong_kehadiran')::boolean, false);
  for k in select * from public._komponen_skema(v_emp, v_akhir) where kategori = 'fungsional' and besaran > 0 order by urutan loop
    v_kh := public._kehadiran_tugas(v_emp, k.kode, v_awal, v_akhir);
    if v_kh is null then continue; end if;
    v_tugas := v_tugas || jsonb_build_array(v_kh || jsonb_build_object('kode', k.kode, 'tugas', regexp_replace(k.label, '^Tunjangan ', ''), 'tunjangan', k.besaran,
      'perkiraan', case when (v_kh->>'wajib')::int > 0 then round(k.besaran * (v_kh->>'tanpa')::numeric / (v_kh->>'wajib')::numeric / v_bulat) * v_bulat else 0 end));
  end loop;
  return jsonb_build_object('bulan', to_char(v_awal, 'YYYY-MM'), 'sampai', least(v_akhir, public.hari_ini()), 'potong_aktif', v_pot,
    'potong_izin', coalesce((v_set->>'potong_izin')::boolean, false), 'tugas', v_tugas,
    'pinjaman', coalesce((select jsonb_agg(jsonb_build_object('keterangan', x.keterangan, 'cicilan', x.cicilan,
        'sisa', x.pokok - coalesce((select sum(besaran) from loan_payments where loan_id = x.id), 0)))
        from employee_loans x where x.employee_id = v_emp and x.status = 'aktif'), '[]'::jsonb),
    'simpanan', coalesce((select jsonb_agg(jsonb_build_object('program', sp.nama, 'setoran', sm.setoran))
        from savings_members sm join savings_programs sp on sp.id = sm.program_id where sm.employee_id = v_emp and sm.aktif and sm.setoran > 0), '[]'::jsonb));
end $$;

-- ---------------------------------------------------------------------
-- 4. NOTIFIKASI PERUBAHAN DATA PENENTU GAJI
-- ---------------------------------------------------------------------
create or replace function public.tg_perubahan_gaji()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_n int; v_contoh record; v_emp uuid;
  v_label jsonb := '{"status_kepegawaian":"status kepegawaian","pendidikan":"pendidikan","level_muhaffizh":"level muhaffizh","kategori_honorer":"kategori honorer","jabatan_struktural":"jabatan struktural","jabatan_fungsional":"jabatan fungsional"}';
begin
  select count(*) into v_n from baru where jenis in ('status_kepegawaian','pendidikan','level_muhaffizh','kategori_honorer','jabatan_struktural','jabatan_fungsional');
  if v_n = 0 then return null; end if;
  select b.jenis, b.nilai_lama, b.nilai_baru, e.nama_lengkap into v_contoh from baru b join employees e on e.id = b.employee_id
   where b.jenis in ('status_kepegawaian','pendidikan','level_muhaffizh','kategori_honorer','jabatan_struktural','jabatan_fungsional') limit 1;
  for v_emp in select sa.employee_id from sensitive_access sa join employees e on e.id = sa.employee_id
                where sa.fitur = 'gaji' and sa.tingkat = 'kelola' and e.status_akun = 'aktif' and e.status_keaktifan = 'aktif' loop
    perform public.kirim_notifikasi(v_emp,
      case when v_n = 1 then 'Perubahan ' || (v_label->>v_contoh.jenis) || ': ' || v_contoh.nama_lengkap else v_n || ' perubahan data penentu gaji' end,
      case when v_n = 1 then coalesce(v_contoh.nilai_lama, '–') || ' → ' || coalesce(v_contoh.nilai_baru, '–') || '. Tunjangan ikut berubah pada periode gaji berikutnya.'
           else 'Periksa daftar perubahan di Tunjangan → Pengingat kenaikan.' end,
      '/tunjangan/pengingat', 'TrendUp', 'oranye');
  end loop;
  return null;
end $$;
drop trigger if exists zz_perubahan_gaji on public.employment_history;
create trigger zz_perubahan_gaji after insert on public.employment_history referencing new table as baru
  for each statement execute function public.tg_perubahan_gaji();

-- ---------------------------------------------------------------------
-- 5–6. JENIS BIAYA: SIKLUS SEMESTERAN DAN BATAS BERLAKU JENJANG/KELAS
-- ---------------------------------------------------------------------
alter table public.fee_types drop constraint if exists fee_types_siklus_check;
alter table public.fee_types add constraint fee_types_siklus_check check (siklus in ('sekali','semesteran','tahunan','bulanan'));
alter table public.fee_types add column if not exists berlaku_jenjang text[];     -- kosong = semua jenjang
alter table public.fee_types add column if not exists berlaku_tingkat smallint[];  -- kosong = semua kelas

create or replace function public.simpan_jenis_biaya(p jsonb)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v_id uuid := nullif(p->>'id', '')::uuid; r jsonb;
  v_jj text[] := nullif(array(select jsonb_array_elements_text(coalesce(p->'berlaku_jenjang', '[]'::jsonb))), '{}');
  v_tk smallint[] := nullif(array(select (jsonb_array_elements_text(coalesce(p->'berlaku_tingkat', '[]'::jsonb)))::smallint), '{}');
begin
  perform public._wajib_kelola_keuangan();
  if coalesce(p->>'siklus', '') not in ('sekali','semesteran','tahunan','bulanan') then raise exception 'Pilih siklus: bulanan, semesteran, tahunan, atau sekali.'; end if;
  if v_jj is not null and exists (select 1 from unnest(v_jj) j where j not in ('wustha','sma')) then raise exception 'Jenjang tidak dikenal.'; end if;
  if v_id is null then
    insert into fee_types (kode, nama, siklus, nominal, santri_baru, keterangan, aktif, urutan, berlaku_jenjang, berlaku_tingkat)
    values (upper(trim(p->>'kode')), trim(p->>'nama'), p->>'siklus', coalesce((p->>'nominal')::numeric, 0),
            coalesce((p->>'santri_baru')::boolean, false), nullif(trim(coalesce(p->>'keterangan', '')), ''), coalesce((p->>'aktif')::boolean, true),
            coalesce((p->>'urutan')::int, (select coalesce(max(urutan), 0) + 1 from fee_types)), v_jj, v_tk)
    returning id into v_id;
  else
    if (select siklus from fee_types where id = v_id) <> p->>'siklus' and exists (select 1 from bills where fee_type_id = v_id) then
      raise exception 'Siklus tidak dapat diubah karena jenis biaya ini sudah dipakai pada tagihan.'; end if;
    update fee_types set kode = upper(trim(p->>'kode')), nama = trim(p->>'nama'), siklus = p->>'siklus', nominal = coalesce((p->>'nominal')::numeric, 0),
      santri_baru = coalesce((p->>'santri_baru')::boolean, false), keterangan = nullif(trim(coalesce(p->>'keterangan', '')), ''),
      aktif = coalesce((p->>'aktif')::boolean, true), urutan = coalesce((p->>'urutan')::int, urutan), berlaku_jenjang = v_jj, berlaku_tingkat = v_tk, updated_at = now()
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

/** Periode tagihan. Semesteran: p.academic_year_id + p.semester (1 ganjil, 2 genap; bawaan semester berjalan). */
create or replace function public._periode_tagihan(f fee_types, p jsonb)
returns table (kunci text, label text, acuan date, tempo date) language plpgsql stable security definer set search_path = public as $$
declare b text; ta academic_years; v_hari int := coalesce((public._pengaturan_keuangan()->>'jatuh_tempo_hari')::int, 10);
  v_tempo date := nullif(p->>'jatuh_tempo', '')::date; v_sem int;
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
    select * into ta from academic_years where id = coalesce(nullif(p->>'academic_year_id', '')::uuid, (select id from academic_years where aktif));
    if ta.id is null then raise exception 'Pilih tahun ajaran tagihan.'; end if;
    if f.siklus = 'tahunan' then
      kunci := ta.nama; label := f.nama || ' ' || ta.nama; acuan := ta.mulai;
    else
      v_sem := coalesce(nullif(p->>'semester', '')::int, ta.semester, 1);
      if v_sem not in (1, 2) then raise exception 'Semester harus 1 (ganjil) atau 2 (genap).'; end if;
      kunci := ta.nama || '-S' || v_sem; label := f.nama || ' Semester ' || case v_sem when 1 then 'Ganjil' else 'Genap' end || ' ' || ta.nama;
      acuan := case v_sem when 1 then ta.mulai else (ta.mulai + interval '6 months')::date end;
    end if;
    tempo := coalesce(v_tempo, greatest(acuan, public.hari_ini()) + 30); return next;
  else
    kunci := 'sekali'; label := f.nama; acuan := public.hari_ini(); tempo := coalesce(v_tempo, public.hari_ini() + 30); return next;
  end if;
end $$;

/** Sasaran tagihan: saringan pengguna + batas berlaku jenis biaya (jenjang/kelas). */
create or replace function public._sasaran_tagihan(p jsonb)
returns setof uuid language plpgsql stable security definer set search_path = public as $$
declare s jsonb := coalesce(p->'sasaran', '{}'::jsonb); v_thn int := extract(year from public.hari_ini())::int; f fee_types;
begin
  select * into f from fee_types where id = nullif(p->>'fee_type_id', '')::uuid;
  return query
  select st.id from students st
   where st.status = 'aktif'
     and (f.berlaku_jenjang is null or st.jenjang = any(f.berlaku_jenjang))
     and (f.berlaku_tingkat is null or st.tingkat = any(f.berlaku_tingkat))
     and (jsonb_array_length(coalesce(s->'student_ids', '[]'::jsonb)) = 0 or st.id in (select (jsonb_array_elements_text(s->'student_ids'))::uuid))
     and (nullif(s->>'jenjang', '') is null or st.jenjang = s->>'jenjang')
     and (jsonb_array_length(coalesce(s->'tingkat', '[]'::jsonb)) = 0 or st.tingkat in (select (jsonb_array_elements_text(s->'tingkat'))::smallint))
     and (nullif(s->>'group_id', '') is null or st.id in (select m.student_id from group_members m where m.group_id = (s->>'group_id')::uuid and m.selesai is null))
     and (not coalesce((s->>'hanya_baru')::boolean, false) or st.tahun_masuk = (select extract(year from mulai)::int from academic_years where aktif)
          or st.tahun_masuk = v_thn);
end $$;

-- ---------------------------------------------------------------------
-- 7. KELOMPOK (KELAS, KAMAR, HALAQAH) UNTUK KEUANGAN
-- ---------------------------------------------------------------------
-- Nama kamar/halaqah santri memakai _kelompok_santri(santri, jenis) yang sudah ada sejak migrasi klinik (4600).

create or replace function public.kelompok_keuangan()
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform public._wajib_lihat_keuangan();
  return coalesce((select jsonb_agg(jsonb_build_object('id', g.id, 'jenis', g.jenis, 'nama', g.nama, 'jenjang', g.jenjang, 'tingkat', g.tingkat,
      'anggota', (select count(*) from group_members m join students s on s.id = m.student_id where m.group_id = g.id and m.selesai is null and s.status = 'aktif'))
    order by case g.jenis when 'kelas' then 1 when 'kamar' then 2 when 'halaqah' then 3 else 4 end, g.tingkat nulls last, g.urutan, g.nama)
    from student_groups g where g.aktif and g.jenis in ('kelas','kamar','halaqah') and g.academic_year_id = (select id from academic_years where aktif)), '[]'::jsonb);
end $$;

create or replace function public.posisi_tunggakan(p_tanggal date default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_tgl date := coalesce(p_tanggal, public.hari_ini());
begin
  perform public._wajib_lihat_keuangan();
  return coalesce((select jsonb_agg(r order by r->>'nama', r->>'jatuh_tempo') from (
    select jsonb_build_object('bill_id', b.id, 'student_id', st.id, 'nis', st.nis, 'nama', st.nama_lengkap, 'jk', st.jenis_kelamin, 'jenjang', st.jenjang,
           'tingkat', st.tingkat, 'kelas', public._kelas_santri(st.id), 'kamar', public._kelompok_santri(st.id, 'kamar'),
           'halaqah', public._kelompok_santri(st.id, 'halaqah'), 'wali', public._kontak_wali(st.id), 'status_santri', st.status,
           'fee_type_id', f.id, 'jenis', f.nama, 'tagihan', b.nama, 'jatuh_tempo', b.jatuh_tempo, 'nominal', b.nominal,
           'dibayar', coalesce(x.bayar, 0), 'sisa', b.nominal - coalesce(x.bayar, 0), 'hari_lewat', v_tgl - b.jatuh_tempo) r
      from bills b join students st on st.id = b.student_id join fee_types f on f.id = b.fee_type_id
      left join lateral (select sum(pi.jumlah) bayar from payment_items pi join payments py on py.id = pi.payment_id
                          where pi.bill_id = b.id and py.status = 'sah' and py.tanggal <= v_tgl) x on true
     where b.status <> 'batal' and b.jatuh_tempo <= v_tgl and b.nominal - coalesce(x.bayar, 0) > 0) q), '[]'::jsonb);
end $$;

/** Daftar tagihan (v2): + kontak wali, saringan jatuh tempo (tempo_dari/tempo_sampai), status 'segera' (belum lunas, jatuh tempo ≤ N hari). */
create or replace function public.daftar_tagihan(p jsonb)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform public._wajib_lihat_keuangan();
  return coalesce((select jsonb_agg(jsonb_build_object('id', b.id, 'student_id', b.student_id, 'nis', st.nis, 'nama', st.nama_lengkap, 'jk', st.jenis_kelamin,
      'jenjang', st.jenjang, 'tingkat', st.tingkat, 'kelas', public._kelas_santri(st.id), 'wali', public._kontak_wali(st.id), 'fee_type_id', b.fee_type_id, 'jenis', f.nama, 'siklus', f.siklus,
      'kunci_periode', b.kunci_periode, 'tagihan', b.nama, 'tanggal_tagih', b.tanggal_tagih, 'jatuh_tempo', b.jatuh_tempo, 'standar', b.standar,
      'potongan', b.potongan, 'alasan_potongan', b.alasan_potongan, 'nominal', b.nominal, 'dibayar', b.dibayar, 'sisa', b.nominal - b.dibayar,
      'status', b.status, 'catatan', b.catatan, 'created_at', b.created_at, 'lewat', b.status in ('belum','sebagian') and b.jatuh_tempo < public.hari_ini())
    order by st.nama_lengkap, b.jatuh_tempo)
    from bills b join students st on st.id = b.student_id join fee_types f on f.id = b.fee_type_id
   where (nullif(p->>'fee_type_id', '') is null or b.fee_type_id = (p->>'fee_type_id')::uuid)
     and (nullif(p->>'kunci_periode', '') is null or b.kunci_periode = p->>'kunci_periode')
     and (jsonb_array_length(coalesce(p->'kunci', '[]'::jsonb)) = 0 or b.kunci_periode in (select jsonb_array_elements_text(p->'kunci')))
     and (nullif(p->>'student_id', '') is null or b.student_id = (p->>'student_id')::uuid)
     and (case coalesce(p->>'status', '') when '' then b.status <> 'batal' when 'tunggak' then b.status in ('belum','sebagian')
            when 'lewat' then b.status in ('belum','sebagian') and b.jatuh_tempo < public.hari_ini()
            when 'segera' then b.status in ('belum','sebagian') and b.jatuh_tempo between public.hari_ini()
                               and public.hari_ini() + greatest(coalesce((public._pengaturan_keuangan()->>'pengingat_hari')::int, 3), 7)
            else b.status = p->>'status' end)
     and (nullif(p->>'tempo_dari', '') is null or b.jatuh_tempo >= (p->>'tempo_dari')::date)
     and (nullif(p->>'tempo_sampai', '') is null or b.jatuh_tempo <= (p->>'tempo_sampai')::date)
     and (nullif(p->>'jenjang', '') is null or st.jenjang = p->>'jenjang')
     and (nullif(p->>'group_id', '') is null or st.id in (select m.student_id from group_members m where m.group_id = (p->>'group_id')::uuid and m.selesai is null))
     and (nullif(p->>'q', '') is null or st.nama_lengkap ilike '%' || (p->>'q') || '%' or st.nis like (p->>'q') || '%')), '[]'::jsonb);
end $$;

-- ---------------------------------------------------------------------
-- 8. TEMPLATE WA: TAGIHAN BARU DAN PENGINGAT JATUH TEMPO
-- ---------------------------------------------------------------------
insert into public.wa_templates (kode, nama, isi, variabel, keterangan) values
  ('tagihan_baru', 'Pemberitahuan tagihan baru ke wali',
   E'{salam}, Bapak/Ibu {nama_wali}.\n\nKami informasikan tagihan baru untuk ananda *{nama_santri}* ({kelas}):\n{rincian}\n\n*Jumlah: {total}*\nJatuh tempo: {batas_bayar}\n\nPembayaran dapat ditransfer ke:\n{rekening}\n\nMohon kirimkan bukti transfer melalui nomor ini.\n{penutup}\n{pengirim}\n{jabatan_pengirim}',
   '{nama_wali,nama_santri,kelas,rincian,total,batas_bayar,rekening}', 'Keuangan: kabari wali saat tagihan baru dibuat.'),
  ('pengingat_jatuh_tempo', 'Pengingat jatuh tempo ke wali',
   E'{salam}, Bapak/Ibu {nama_wali}.\n\nMengingatkan dengan hormat, tagihan ananda *{nama_santri}* ({kelas}) akan jatuh tempo pada *{batas_bayar}*:\n{rincian}\n\n*Jumlah: {total}*\n\nPembayaran dapat ditransfer ke:\n{rekening}\n\nApabila sudah membayar, mohon abaikan pesan ini.\n{penutup}\n{pengirim}\n{jabatan_pengirim}',
   '{nama_wali,nama_santri,kelas,rincian,total,batas_bayar,rekening}', 'Keuangan: pengingat menjelang jatuh tempo.')
on conflict (kode) do nothing;

-- ---------------------------------------------------------------------
-- 9. HAK EKSEKUSI
-- ---------------------------------------------------------------------
do $$
declare f text;
begin
  foreach f in array array['impor_komponen_gaji(uuid,jsonb)','perkiraan_gaji_saya(date)','simpan_jenis_biaya(jsonb)','kelompok_keuangan()','posisi_tunggakan(date)','daftar_tagihan(jsonb)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  foreach f in array array['_periode_tagihan(fee_types,jsonb)','_sasaran_tagihan(jsonb)','tg_perubahan_gaji()'] loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- 10. PEMERIKSAAN (hasil yang benar: semua "Sesuai")
-- ---------------------------------------------------------------------
select '1. Fungsi gaji tercatat di log audit (23)' as pemeriksaan,
       case when (select count(*) from pg_proc where prosrc like '%_audit_gaji(%' and proname <> '_audit_gaji') >= 20 then 'Sesuai'
            else 'Periksa: ' || (select count(*) from pg_proc where prosrc like '%_audit_gaji(%' and proname <> '_audit_gaji') end as hasil
union all select '1b. Log audit gaji/keuangan tertutup bagi admin biasa',
       case when (select qual from pg_policies where tablename = 'audit_logs' and policyname = 'baca') like '%boleh_lihat_keuangan%' then 'Sesuai' else 'Periksa' end
union all select '2. Impor komponen dan perkiraan potongan pegawai',
       case when (select count(*) from pg_proc where proname in ('impor_komponen_gaji','perkiraan_gaji_saya')) = 2 then 'Sesuai' else 'Periksa' end
union all select '3. Notifikasi perubahan data penentu gaji',
       case when exists (select 1 from pg_trigger where tgname = 'zz_perubahan_gaji') then 'Sesuai' else 'Periksa' end
union all select '4. Siklus semesteran dan batas berlaku jenis biaya',
       case when (select count(*) from information_schema.columns where table_name = 'fee_types' and column_name in ('berlaku_jenjang','berlaku_tingkat')) = 2
             and pg_get_constraintdef((select oid from pg_constraint where conname = 'fee_types_siklus_check')) like '%semesteran%' then 'Sesuai' else 'Periksa' end
union all select '5. Template WA tagihan baru dan pengingat',
       case when (select count(*) from wa_templates where kode in ('tagihan_baru','pengingat_jatuh_tempo')) = 2 then 'Sesuai' else 'Periksa' end;
