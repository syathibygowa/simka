-- SIMKA PRO | supabase/migrations/20261004002700_berkas_wa.sql | v1.0 | Fase 3 – Perbaikan P3 (berkas dan WA) | 04/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 3 · Migrasi 27: Berkas Saya lanjutan dan WA (perbaikan dari uji pemilik proyek)
--   * document_categories : kategori berkas dapat dibuat sendiri (admin ber-izin kelola_berkas / superadmin)
--   * Berkas tanpa masa berlaku (tetap ada sampai dihapus), dapat diedit: ganti berkas, tambah penerima, beri tahu ulang
--   * Daftar pembaca pengumuman dan pembuka berkas menyertakan nomor HP (tombol WA)
--   * kontak_pengajuan(id): nomor HP pemohon dan penyetuju jenjang aktif (tombol WA di rincian pengajuan)
--   * Template WA baru: pengumuman, berkas, pengajuan (status dan pengingat penyetuju), verval presensi
-- Jalankan SETELAH migrasi 2600. Aman dijalankan ulang.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Kategori berkas
-- ---------------------------------------------------------------------
create table if not exists public.document_categories (
  kode    text primary key check (kode ~ '^[a-z0-9_]{2,30}$'),
  nama    text not null,
  ikon    text not null default 'File',
  warna   text not null default 'hakakses',
  urutan  int not null default 0,
  aktif   boolean not null default true
);
insert into public.document_categories (kode, nama, ikon, warna, urutan) values
  ('info', 'Info', 'Info', 'pengumuman', 1), ('formulir', 'Formulir', 'ClipboardText', 'shift', 2),
  ('surat', 'Surat', 'EnvelopeSimple', 'pegawai', 3), ('sk', 'SK', 'Stamp', 'beranda', 4),
  ('lainnya', 'Lainnya', 'File', 'hakakses', 99)
on conflict (kode) do nothing;
alter table public.document_categories enable row level security;
drop policy if exists baca on public.document_categories;
create policy baca on public.document_categories for select to authenticated using (true);
drop policy if exists kelola on public.document_categories;
create policy kelola on public.document_categories for all to authenticated using (public.admin_boleh('kelola_berkas')) with check (public.admin_boleh('kelola_berkas'));
grant select, insert, update, delete on public.document_categories to authenticated;
drop trigger if exists zz_audit on public.document_categories;
create trigger zz_audit after insert or update or delete on public.document_categories for each row execute function public.tg_audit();

alter table public.employee_documents drop constraint if exists employee_documents_kategori_check;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'employee_documents_kategori_fkey') then
    alter table public.employee_documents add constraint employee_documents_kategori_fkey
      foreign key (kategori) references public.document_categories(kode) on update cascade;
  end if;
end $$;
-- Tanpa masa berlaku: kosongkan isian lama
update public.employee_documents set berlaku_sampai = null where berlaku_sampai is not null;

-- ---------------------------------------------------------------------
-- 2. Simpan/ubah berkas pegawai
-- ---------------------------------------------------------------------
create or replace function public.simpan_berkas_pegawai(p jsonb)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v_id uuid := nullif(p->>'id', '')::uuid; v_n int; v_lama uuid; v_sasaran jsonb := coalesce(p->'sasaran', '{"jenis":"semua"}');
        v_kat text := coalesce(nullif(p->>'kategori', ''), 'info');
begin
  if not public.boleh_kelola_berkas() then raise exception 'Anda tidak berwenang mengirim berkas pegawai.' using errcode = '42501'; end if;
  if length(trim(coalesce(p->>'judul', ''))) < 3 then raise exception 'Judul berkas minimal 3 karakter.'; end if;
  if nullif(p->>'berkas_id', '') is null and nullif(trim(coalesce(p->>'tautan_luar', '')), '') is null then
    raise exception 'Unggah berkas atau isi tautan (https://).';
  end if;
  if not exists (select 1 from document_categories where kode = v_kat and aktif) then raise exception 'Kategori berkas tidak dikenal atau nonaktif.'; end if;
  if v_id is not null then
    select berkas_id into v_lama from employee_documents where id = v_id;
    if not found then raise exception 'Berkas tidak ditemukan.'; end if;
    update employee_documents set judul = trim(p->>'judul'), kategori = v_kat, keterangan = nullif(trim(coalesce(p->>'keterangan', '')), ''),
           berkas_id = coalesce(nullif(p->>'berkas_id', '')::uuid, berkas_id), tautan_luar = nullif(trim(coalesce(p->>'tautan_luar', '')), ''),
           berlaku_sampai = null
     where id = v_id;
    -- berkas fisik diganti: berkas lama dihapus GAS, berkas baru menjadi milik sistem
    if nullif(p->>'berkas_id', '') is not null and v_lama is distinct from (p->>'berkas_id')::uuid then
      update storage_objects set kategori = 'berkas_pegawai', hapus_setelah = null where id = (p->>'berkas_id')::uuid;
      if v_lama is not null then update storage_objects set hapus_setelah = public.hari_ini() where id = v_lama; end if;
    end if;
    -- sasaran tambahan (penerima baru)
    if p ? 'sasaran_tambah' then
      insert into employee_document_targets (document_id, employee_id)
      select v_id, x from public.penerima_sasaran(p->'sasaran_tambah') x on conflict do nothing;
      get diagnostics v_n = row_count;
      if v_n > 0 then
        update employee_documents set ringkasan_sasaran = ringkasan_sasaran || '; ' || public.ringkas_sasaran(p->'sasaran_tambah') where id = v_id;
        insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
        select t.employee_id, 'Berkas baru untuk Anda', trim(p->>'judul'), '/berkas/' || v_id, 'FolderOpen', 'biru'
          from employee_document_targets t where t.document_id = v_id and t.dibuka_pertama is null and t.jumlah_buka = 0
           and t.employee_id in (select public.penerima_sasaran(p->'sasaran_tambah'));
      end if;
    end if;
    -- beri tahu ulang semua penerima bahwa berkas diperbarui
    if coalesce((p->>'beri_tahu')::boolean, false) then
      insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
      select t.employee_id, 'Berkas diperbarui', trim(p->>'judul'), '/berkas/' || v_id, 'FolderOpen', 'biru'
        from employee_document_targets t where t.document_id = v_id and t.employee_id is distinct from public.saya();
    end if;
    return v_id;
  end if;
  insert into employee_documents (judul, kategori, keterangan, berkas_id, tautan_luar, sasaran, ringkasan_sasaran, berlaku_sampai, dibuat_oleh)
  values (trim(p->>'judul'), v_kat, nullif(trim(coalesce(p->>'keterangan', '')), ''), nullif(p->>'berkas_id', '')::uuid,
          nullif(trim(coalesce(p->>'tautan_luar', '')), ''), v_sasaran, public.ringkas_sasaran(v_sasaran),
          null, public.saya())
  returning id into v_id;
  insert into employee_document_targets (document_id, employee_id)
  select v_id, x from public.penerima_sasaran(v_sasaran) x on conflict do nothing;
  get diagnostics v_n = row_count;
  if v_n = 0 then raise exception 'Sasaran yang dipilih tidak memiliki penerima (pegawai aktif berakun).'; end if;
  -- Berkas yang diunggah menjadi milik sistem (tidak ikut terhapus bersama akun pengunggah)
  update storage_objects set kategori = 'berkas_pegawai', hapus_setelah = null where id = nullif(p->>'berkas_id', '')::uuid;
  insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
  select t.employee_id,
         (select nama from document_categories where kode = v_kat) || ' baru untuk Anda',
         trim(p->>'judul'), '/berkas/' || v_id, 'FolderOpen', 'biru'
    from employee_document_targets t where t.document_id = v_id and t.employee_id is distinct from public.saya();
  return v_id;
end $$;

-- ---------------------------------------------------------------------
-- 3. Nomor HP untuk tombol WA
-- ---------------------------------------------------------------------
drop function if exists public.pembuka_berkas(uuid);
create or replace function public.pembuka_berkas(p_id uuid)
returns table (employee_id uuid, nama text, unit text, dibuka_pertama timestamptz, dibuka_terakhir timestamptz, jumlah_buka int, no_hp text)
language sql stable security definer set search_path = public as $$
  select t.employee_id, e.nama_lengkap, u.nama, t.dibuka_pertama, t.dibuka_terakhir, t.jumlah_buka, e.no_hp
    from employee_document_targets t join employees e on e.id = t.employee_id left join org_units u on u.id = e.org_unit_id
   where t.document_id = p_id and public.boleh_kelola_berkas()
   order by t.dibuka_pertama nulls first, e.nama_lengkap
$$;
drop function if exists public.pembaca_pengumuman(uuid);
create or replace function public.pembaca_pengumuman(p_id uuid)
returns table (employee_id uuid, nama text, unit text, dibaca_pada timestamptz, no_hp text)
language sql stable security definer set search_path = public as $$
  select t.employee_id, e.nama_lengkap, u.nama, t.dibaca_pada, e.no_hp
    from announcement_targets t join employees e on e.id = t.employee_id
    left join org_units u on u.id = e.org_unit_id
   where t.announcement_id = p_id and public.boleh_umumkan()
   order by t.dibaca_pada nulls first, e.nama_lengkap
$$;

/** Kontak WA pada rincian pengajuan: pemohon dan calon penyetuju jenjang yang sedang menunggu. */
create or replace function public.kontak_pengajuan(p_id uuid)
returns table (peran text, employee_id uuid, nama text, jabatan text, no_hp text)
language plpgsql stable security definer set search_path = public as $$
declare r leave_requests; a leave_approvals;
begin
  if not public.boleh_lihat_pengajuan(p_id) and not public.is_superadmin() then raise exception 'Tidak berwenang.' using errcode = '42501'; end if;
  select * into r from leave_requests where id = p_id;
  return query select 'pemohon'::text, e.id, e.nama_lengkap, null::text, e.no_hp from employees e where e.id = r.employee_id;
  if r.status = 'menunggu' then
    select * into a from leave_approvals where request_id = p_id and urutan = r.langkah_ke;
    return query select 'penyetuju'::text, c.employee_id, c.nama, c.jabatan_tertulis, e.no_hp
                   from public.calon_penyetuju(r.employee_id, a.peran) c join employees e on e.id = c.employee_id;
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 4. Template WA tambahan
-- ---------------------------------------------------------------------
insert into public.wa_templates (kode, nama, isi, variabel, keterangan) values
  ('pengumuman', 'Pengumuman',
   E'{salam}, {nama}.\n\n*{judul}*\n{isi_singkat}\n\nSelengkapnya di SIMKA PRO: {tautan}\n\n{penutup}\n{pengirim}',
   '{nama,judul,isi_singkat,tautan,pengirim}', 'Tombol WA di daftar pembaca pengumuman (mengingatkan yang belum membaca).'),
  ('berkas_baru', 'Berkas untuk pegawai',
   E'{salam}, {nama}.\n\nAda {kategori} untuk Anda di menu Berkas Saya SIMKA PRO:\n*{judul}*\n\nSilakan dibuka di {tautan}\n\n{penutup}\n{pengirim}',
   '{nama,kategori,judul,tautan,pengirim}', 'Konfirmasi WA setelah mengirim berkas.'),
  ('pengajuan_status', 'Kabar pengajuan untuk pemohon',
   E'{salam}, {nama}.\n\nPengajuan {jenis} Anda ({tanggal}, {lama}) saat ini *{status}*.\n{alasan}\n\nRincian dan surat: {tautan}\n\n{penutup}\n{pengirim}',
   '{nama,jenis,tanggal,lama,status,alasan,tautan,pengirim}', 'Tombol WA ke pemohon di rincian pengajuan.'),
  ('pengajuan_pengingat', 'Pengingat untuk penyetuju',
   E'{salam}, {nama}.\n\nMohon maaf mengganggu. Ada pengajuan {jenis} dari {pemohon} ({tanggal}, {lama}) yang menunggu persetujuan Anda sebagai {jabatan}.\n\nSilakan diputuskan di SIMKA PRO: {tautan}\n\n{penutup}\n{pengirim}',
   '{nama,jenis,pemohon,tanggal,lama,jabatan,tautan,pengirim}', 'Tombol WA ke penyetuju jenjang aktif di rincian pengajuan.'),
  ('verval_presensi', 'Hasil verval presensi',
   E'{salam}, {nama}.\n\nPresensi Anda pada sesi {sesi}, {tanggal} telah diverval dengan status *{status_presensi}*.\nCatatan: {catatan_verval}\n\n{penutup}\n{pengirim}',
   '{nama,sesi,tanggal,status_presensi,catatan_verval,pengirim}', 'Tombol WA setelah verval presensi.')
on conflict (kode) do nothing;

-- ---------------------------------------------------------------------
-- 5. Hak eksekusi
-- ---------------------------------------------------------------------
do $$
declare f text;
begin
  foreach f in array array['simpan_berkas_pegawai(jsonb)','pembuka_berkas(uuid)','pembaca_pengumuman(uuid)','kontak_pengajuan(uuid)']
  loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN — hasil yang benar: 5 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select 'Kategori berkas (minimal 5) dengan RLS' as pemeriksaan,
       case when (select count(*) from public.document_categories) >= 5
             and exists (select 1 from pg_tables where tablename = 'document_categories' and rowsecurity) then 'Sesuai' else 'Periksa' end as hasil
union all
select 'Kategori berkas tertaut ke daftar kategori',
       case when exists (select 1 from pg_constraint where conname = 'employee_documents_kategori_fkey') then 'Sesuai' else 'Periksa' end
union all
select 'Nomor HP di daftar pembaca dan pembuka',
       case when position('no_hp' in pg_get_function_result('public.pembaca_pengumuman(uuid)'::regprocedure)) > 0
             and position('no_hp' in pg_get_function_result('public.pembuka_berkas(uuid)'::regprocedure)) > 0 then 'Sesuai' else 'Periksa' end
union all
select 'Template WA (minimal 11)',
       case when (select count(*) from public.wa_templates) >= 11 then 'Sesuai' else 'Periksa' end
union all
select 'Migrasi 2600 sudah terpasang',
       case when exists (select 1 from pg_proc where proname = 'kejadian_agenda') then 'Sesuai' else 'Periksa: jalankan 2600 dulu' end;
