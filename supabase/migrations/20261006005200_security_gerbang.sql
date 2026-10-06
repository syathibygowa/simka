-- SIMKA PRO | supabase/migrations/20261006005200_security_gerbang.sql | v1.0 | Fase 7 – Tahap 1 Security: gerbang | 06/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 7 · Migrasi 52: Security – Gerbang santri (Blueprint Bagian 24)
--   * Pencatat gerbang adalah SECURITY (hak fitur "gerbang" tingkat ≥ 2; isi awal: jabatan Petugas keamanan).
--     Superadmin dan admin ber-izin kelola_security menjadi cadangan. Pengasuh tidak lagi mencatat keluar/kembali.
--   * gate_logs: catatan gerbang (keluar, kembali, ditolak) dengan foto opsional bersama penjemput.
--   * cari_santri_gerbang(): cari nama/NIS, boleh ditambah akhiran kelas atau kamar (contoh "ahmad 8A", "fatih umar");
--     setiap santri tampil dengan status gerbang hijau/merah.
--   * catat_gerbang(): keluar (izin harus disetujui dan berlaku), kembali (terlambat dihitung), ditolak (alasan wajib,
--     Kepala Bidang Kesantrian dan pengelola izin dinotifikasi).
--   * izin_cepat(): pejabat berwenang membuat izin yang langsung berlaku (mis. wali menjemput mendadak).
--   * security_pengingat() (pg_cron tiap 5 menit): santri lewat batas kembali → notifikasi sekali ke Kepala Bidang
--     Kesantrian, pengusul, dan semua pengasuh santri (musyrif, wali kelas, muhaffizh).
--   * ringkasan_security_beranda(): kartu langsung di Beranda.
--   * Perbaikan: hak lihat foto galat untuk foto yang bukan pengajuan/jurnal/berkas/agenda/pengumuman/kartu
--     (bentrok nama alias sejak Fase 4) – kini diperbaiki.
--   * Perbaikan Fase 6: foto Lapor ke Bidang dan Jurnal Musyrif kini dapat dibuka penerima laporan, pimpinan, dan pengasuh kamar.
-- Jalankan SETELAH migrasi 5100. Aman dijalankan ulang.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. IZIN ADMIN, PENGATURAN, KOLOM TAMBAHAN
-- ---------------------------------------------------------------------
insert into public.admin_capabilities (kode, nama, urutan) values
  ('kelola_security', 'Mengelola Security: gerbang, titipan, buku tamu, kunjungan, ketentuan (Fase 7)', 34)
on conflict (kode) do nothing;

alter table public.student_permits drop constraint if exists student_permits_sumber_check;
alter table public.student_permits add constraint student_permits_sumber_check check (sumber in ('pengasuh','klinik','admin','cepat'));
alter table public.student_permits drop constraint if exists student_permits_peran_pengusul_check;
alter table public.student_permits add constraint student_permits_peran_pengusul_check
  check (peran_pengusul in ('musyrif','wali_kelas','muhaffizh','petugas_klinik','admin','pimpinan'));
alter table public.student_permits add column if not exists terlambat_dikabari timestamptz;

-- ---------------------------------------------------------------------
-- 2. HAK
-- ---------------------------------------------------------------------
/** Petugas gerbang: Security (hak fitur gerbang ≥ 2), admin ber-izin kelola_security, superadmin. */
create or replace function public.boleh_gerbang()
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_superadmin() or public.admin_boleh('kelola_security') or public.tingkat_fitur('gerbang') >= 2
$$;
create or replace function public.boleh_kelola_security()
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_superadmin() or public.admin_boleh('kelola_security') or public.tingkat_fitur('gerbang') >= 3
$$;
/** Melihat informasi Security: petugas, admin, pemegang hak pantauan (pimpinan, yayasan), pimpinan Kesantrian. */
create or replace function public.boleh_lihat_security()
returns boolean language sql stable security definer set search_path = public as $$
  select public.boleh_gerbang() or public.is_admin() or public.tingkat_fitur('gerbang') >= 1
      or public.tingkat_fitur('pantauan') >= 1 or public.pimpinan_kesantrian()
      or public.saya() in (select public._pimpinan_puncak())
$$;
/** Izin cepat: pejabat yang dapat memutus izin Kesantrian (Kepala Bidang Kesantrian, Direktur/Wadir, Plt, superadmin). */
create or replace function public.boleh_izin_cepat()
returns boolean language sql stable security definer set search_path = public as $$
  select public.boleh_putus_izin('KESANTRIAN', 1)
$$;

create or replace function public.pengaturan_security()
returns jsonb language sql stable security definer set search_path = public as $$
  select '{"toleransi_terlambat_menit": 0, "keluar_lebih_awal_menit": 120}'::jsonb
         || coalesce((select nilai from institution_settings where kunci = 'security'), '{}'::jsonb)
$$;

create or replace function public.simpan_pengaturan_security(p jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare t int := (p->>'toleransi_terlambat_menit')::int; a int := (p->>'keluar_lebih_awal_menit')::int; v jsonb;
begin
  if not public.boleh_kelola_security() then raise exception 'Anda tidak berwenang mengubah ketentuan Security.' using errcode = '42501'; end if;
  if t is null or t < 0 or t > 720 then raise exception 'Toleransi terlambat kembali harus 0–720 menit.'; end if;
  if a is null or a < 0 or a > 1440 then raise exception 'Batas keluar lebih awal harus 0–1440 menit.'; end if;
  v := public.pengaturan_security() || jsonb_build_object('toleransi_terlambat_menit', t, 'keluar_lebih_awal_menit', a);
  insert into institution_settings (kunci, nilai, updated_by) values ('security', v, public.saya())
  on conflict (kunci) do update set nilai = excluded.nilai, updated_at = now(), updated_by = excluded.updated_by;
  return public.pengaturan_security();
end $$;

create or replace function public.hak_security()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('gerbang', public.boleh_gerbang(), 'kelola', public.boleh_kelola_security(),
    'lihat', public.boleh_lihat_security(), 'izin_cepat', public.boleh_izin_cepat(),
    'puncak', public.is_superadmin() or public.saya() in (select public._pimpinan_puncak()))
$$;

/** Petugas Security aktif (jabatan fungsional SECURITY). */
create or replace function public._petugas_security()
returns setof uuid language sql stable security definer set search_path = public as $$
  select distinct e.id from employees e join employee_functions f on f.employee_id = e.id
    join functional_positions fp on fp.id = f.functional_position_id and fp.kode = 'SECURITY'
   where e.status_akun = 'aktif' and e.status_keaktifan = 'aktif'
$$;

-- ---------------------------------------------------------------------
-- 3. TABEL CATATAN GERBANG
-- ---------------------------------------------------------------------
create table if not exists public.gate_logs (
  id              uuid primary key default gen_random_uuid(),
  jenis           text not null check (jenis in ('keluar','kembali','ditolak')),
  student_id      uuid not null references public.students(id) on delete cascade,
  permit_id       uuid references public.student_permits(id) on delete set null,
  waktu           timestamptz not null default now(),
  petugas_id      uuid references public.employees(id) on delete set null,
  foto_id         uuid references public.storage_objects(id) on delete set null,
  penjemput       text,
  catatan         text,
  terlambat_menit int,
  created_at      timestamptz not null default now()
);
create index if not exists gl_waktu_idx on public.gate_logs (waktu desc);
create index if not exists gl_santri_idx on public.gate_logs (student_id, waktu desc);
drop trigger if exists zz_audit on public.gate_logs;
create trigger zz_audit after insert or update or delete on public.gate_logs for each row execute function public.tg_audit();
alter table public.gate_logs enable row level security;
drop policy if exists baca on public.gate_logs;
create policy baca on public.gate_logs for select to authenticated
  using (public.boleh_lihat_security() or student_id in (select public.santri_terlihat()));
do $$ begin
  alter publication supabase_realtime add table public.gate_logs;
exception when others then null; end $$;

-- ---------------------------------------------------------------------
-- 4. STATUS GERBANG SEORANG SANTRI
-- ---------------------------------------------------------------------
/** warna: hijau (boleh keluar), biru (sedang di luar), merah (tidak boleh keluar). kode: boleh, di_luar, terlambat,
    belum_waktunya, kedaluwarsa, menunggu, tidak_ada. */
create or replace function public._status_gerbang(p_santri uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare p student_permits%rowtype; v_awal int := (public.pengaturan_security()->>'keluar_lebih_awal_menit')::int;
begin
  -- Sedang di luar
  select * into p from student_permits where student_id = p_santri and status = 'keluar' order by keluar_aktual desc nulls last limit 1;
  if p.id is not null then
    return jsonb_build_object('kode', case when now() > p.kembali_batas then 'terlambat' else 'di_luar' end,
      'warna', case when now() > p.kembali_batas then 'merah' else 'biru' end, 'permit_id', p.id,
      'label', case when now() > p.kembali_batas then 'Terlambat kembali' else 'Sedang di luar pondok' end);
  end if;
  -- Izin disetujui yang masih berlaku (paling dekat)
  select * into p from student_permits where student_id = p_santri and status = 'disetujui' and kembali_batas > now()
   order by keluar_pada limit 1;
  if p.id is not null then
    if now() >= p.keluar_pada - make_interval(mins => v_awal) then
      return jsonb_build_object('kode', 'boleh', 'warna', 'hijau', 'permit_id', p.id, 'label', 'Izin disetujui dan berlaku');
    end if;
    return jsonb_build_object('kode', 'belum_waktunya', 'warna', 'merah', 'permit_id', p.id,
      'label', 'Izin baru berlaku ' || to_char(p.keluar_pada at time zone 'Asia/Makassar', 'DD/MM HH24.MI') || ' WITA');
  end if;
  select * into p from student_permits where student_id = p_santri and status in ('diajukan','disetujui_bidang') order by keluar_pada limit 1;
  if p.id is not null then
    return jsonb_build_object('kode', 'menunggu', 'warna', 'merah', 'permit_id', p.id, 'label', 'Izin belum disetujui');
  end if;
  select * into p from student_permits where student_id = p_santri and status = 'disetujui' and kembali_batas <= now()
   order by kembali_batas desc limit 1;
  if p.id is not null then
    return jsonb_build_object('kode', 'kedaluwarsa', 'warna', 'merah', 'permit_id', p.id, 'label', 'Izin sudah kedaluwarsa');
  end if;
  return jsonb_build_object('kode', 'tidak_ada', 'warna', 'merah', 'permit_id', null, 'label', 'Tidak ada izin');
end $$;

/** Ringkasan izin untuk kartu gerbang. */
create or replace function public._izin_gerbang_json(p_id uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('id', p.id, 'jenis', p.jenis, 'alasan', p.alasan, 'penjemput', p.penjemput, 'hubungan_penjemput', p.hubungan_penjemput,
    'hp_penjemput', p.hp_penjemput, 'keluar_pada', p.keluar_pada, 'kembali_batas', p.kembali_batas, 'lama_hari', p.lama_hari, 'status', p.status,
    'keluar_aktual', p.keluar_aktual, 'kembali_pada', p.kembali_pada, 'sumber', p.sumber, 'pengusul', e.nama_lengkap, 'peran_pengusul', p.peran_pengusul,
    'disetujui_oleh', (select string_agg(coalesce(ae.nama_lengkap, '–') || ' (' || coalesce(a.sebagai, '') || ')', ', ' order by a.pada)
                         from student_permit_approvals a left join employees ae on ae.id = a.oleh where a.permit_id = p.id and a.keputusan = 'setuju'))
    from student_permits p left join employees e on e.id = p.pengusul_id where p.id = p_id
$$;

/** Data santri untuk gerbang: identitas, kelas, kamar, status gerbang, izin terkait. */
create or replace function public._santri_gerbang_json(p_santri uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('student_id', s.id, 'nama', s.nama_lengkap, 'nis', s.nis, 'jenis_kelamin', s.jenis_kelamin, 'jenjang', s.jenjang,
    'kelas', public._kelompok_santri(s.id, 'kelas'), 'kamar', public._kelompok_santri(s.id, 'kamar'),
    'status', st, 'izin', case when st->>'permit_id' is not null then public._izin_gerbang_json((st->>'permit_id')::uuid) end)
    from students s, lateral (select public._status_gerbang(s.id) st) x where s.id = p_santri
$$;

/** Cari santri aktif di gerbang. Setiap kata harus cocok dengan nama, NIS, kelas, atau kamar. */
create or replace function public.cari_santri_gerbang(p_q text, p_batas int default 30)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_kata text[];
begin
  if not public.boleh_lihat_security() then raise exception 'Anda tidak berwenang membuka gerbang.' using errcode = '42501'; end if;
  v_kata := array_remove(regexp_split_to_array(lower(trim(coalesce(p_q, ''))), '\s+'), '');
  if cardinality(v_kata) = 0 or length(array_to_string(v_kata, '')) < 2 then return '[]'::jsonb; end if;
  return coalesce((select jsonb_agg(public._santri_gerbang_json(q.id) order by q.nama_lengkap) from (
    select s.id, s.nama_lengkap from students s
     where s.status = 'aktif'
       and not exists (select 1 from unnest(v_kata) k
                        where position(k in lower(s.nama_lengkap || ' ' || s.nis || ' ' || coalesce(public._kelompok_santri(s.id, 'kelas'), '')
                                                  || ' ' || coalesce(public._kelompok_santri(s.id, 'kamar'), ''))) = 0)
     order by s.nama_lengkap limit greatest(1, least(p_batas, 60))) q), '[]'::jsonb);
end $$;

/** Satu santri (setelah dicatat / dari tautan). */
create or replace function public.santri_gerbang(p_santri uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if not public.boleh_lihat_security() then raise exception 'Anda tidak berwenang membuka gerbang.' using errcode = '42501'; end if;
  return public._santri_gerbang_json(p_santri);
end $$;

/** Daftar gerbang hari ini: siap keluar (izin berlaku), di luar (termasuk terlambat), kembali hari ini, ditolak hari ini. */
create or replace function public.daftar_gerbang()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_awal int := (public.pengaturan_security()->>'keluar_lebih_awal_menit')::int; v_hari date := public.hari_ini();
begin
  if not public.boleh_lihat_security() then raise exception 'Anda tidak berwenang membuka gerbang.' using errcode = '42501'; end if;
  return jsonb_build_object(
    'siap', coalesce((select jsonb_agg(public._santri_gerbang_json(s) order by k) from (
        select distinct on (p.student_id) p.student_id s, p.keluar_pada k from student_permits p
         where p.status = 'disetujui' and p.kembali_batas > now()
           and ((p.keluar_pada at time zone 'Asia/Makassar')::date <= v_hari or p.keluar_pada - make_interval(mins => v_awal) <= now())
         order by p.student_id, p.keluar_pada) q), '[]'::jsonb),
    'di_luar', coalesce((select jsonb_agg(public._santri_gerbang_json(s) order by t) from (
        select distinct on (p.student_id) p.student_id s, p.kembali_batas t from student_permits p where p.status = 'keluar'
         order by p.student_id, p.kembali_batas) q), '[]'::jsonb),
    'log_hari_ini', coalesce((select jsonb_agg(jsonb_build_object('id', g.id, 'jenis', g.jenis, 'waktu', g.waktu, 'student_id', g.student_id,
        'nama', s.nama_lengkap, 'nis', s.nis, 'kelas', public._kelompok_santri(s.id, 'kelas'), 'kamar', public._kelompok_santri(s.id, 'kamar'),
        'petugas', e.nama_lengkap, 'penjemput', g.penjemput, 'catatan', g.catatan, 'terlambat_menit', g.terlambat_menit, 'foto_id', g.foto_id) order by g.waktu desc)
      from gate_logs g join students s on s.id = g.student_id left join employees e on e.id = g.petugas_id
     where (g.waktu at time zone 'Asia/Makassar')::date = v_hari), '[]'::jsonb));
end $$;

/** Riwayat gerbang pada rentang tanggal (jenis kosong = semua). */
create or replace function public.riwayat_gerbang(p_mulai date, p_selesai date, p_jenis text default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if not public.boleh_lihat_security() then raise exception 'Anda tidak berwenang membuka riwayat gerbang.' using errcode = '42501'; end if;
  if p_selesai < p_mulai then raise exception 'Tanggal akhir harus setelah tanggal awal.'; end if;
  if p_selesai - p_mulai > 366 then raise exception 'Rentang paling lama satu tahun.'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', g.id, 'jenis', g.jenis, 'waktu', g.waktu, 'student_id', g.student_id,
      'nama', s.nama_lengkap, 'nis', s.nis, 'jenis_kelamin', s.jenis_kelamin, 'kelas', public._kelompok_santri(s.id, 'kelas'), 'kamar', public._kelompok_santri(s.id, 'kamar'),
      'petugas', e.nama_lengkap, 'penjemput', g.penjemput, 'catatan', g.catatan, 'terlambat_menit', g.terlambat_menit, 'foto_id', g.foto_id,
      'alasan_izin', p.alasan, 'kembali_batas', p.kembali_batas, 'jenis_izin', p.jenis) order by g.waktu desc)
    from gate_logs g join students s on s.id = g.student_id left join employees e on e.id = g.petugas_id
    left join student_permits p on p.id = g.permit_id
   where (g.waktu at time zone 'Asia/Makassar')::date between p_mulai and p_selesai
     and (p_jenis is null or p_jenis = '' or g.jenis = p_jenis)), '[]'::jsonb);
end $$;

-- ---------------------------------------------------------------------
-- 5. CATAT DI GERBANG
-- ---------------------------------------------------------------------
/** Pengasuh santri yang berlaku hari ini: musyrif (kamar), wali kelas (kelas), muhaffizh (halaqah). */
create or replace function public._pengasuh_santri(p_santri uuid)
returns setof uuid language sql stable security definer set search_path = public as $$
  select distinct k.employee_id from group_members m
    join student_groups g on g.id = m.group_id and g.aktif and g.jenis in ('kamar','kelas','halaqah')
    join academic_years a on a.id = g.academic_year_id and a.aktif
    join group_keepers k on k.group_id = g.id and (k.mulai is null or k.mulai <= public.hari_ini()) and (k.sampai is null or k.sampai >= public.hari_ini())
   where m.student_id = p_santri and m.selesai is null
$$;

/** p: { aksi: keluar|kembali|ditolak, permit_id?, student_id?, foto_id?, penjemput?, catatan? } */
create or replace function public.catat_gerbang(p jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare v_aksi text := p->>'aksi'; v student_permits%rowtype; v_santri uuid := nullif(p->>'student_id', '')::uuid;
        v_awal int := (public.pengaturan_security()->>'keluar_lebih_awal_menit')::int; v_nama text; v_log uuid; v_menit int;
        v_foto uuid := nullif(p->>'foto_id', '')::uuid; v_catatan text := nullif(trim(coalesce(p->>'catatan', '')), '');
begin
  if not public.boleh_gerbang() then raise exception 'Hanya petugas Security yang dapat mencatat di gerbang.' using errcode = '42501'; end if;
  if v_aksi not in ('keluar','kembali','ditolak') then raise exception 'Aksi harus keluar, kembali, atau ditolak.'; end if;
  if nullif(p->>'permit_id', '') is not null then
    select * into v from student_permits where id = (p->>'permit_id')::uuid for update;
    if v.id is null then raise exception 'Izin tidak ditemukan.'; end if;
    v_santri := v.student_id;
  end if;
  select nama_lengkap into v_nama from students where id = v_santri;
  if v_nama is null then raise exception 'Santri tidak ditemukan.'; end if;

  if v_aksi = 'keluar' then
    if v.id is null then raise exception 'Santri hanya dapat keluar dengan izin yang sudah disetujui.'; end if;
    if v.status <> 'disetujui' then raise exception '% tidak dapat keluar: izin berstatus %.', v_nama,
      case v.status when 'keluar' then 'sedang di luar' when 'kembali' then 'sudah selesai' when 'ditolak' then 'ditolak' when 'dibatalkan' then 'dibatalkan' else 'belum disetujui' end; end if;
    if now() >= v.kembali_batas then raise exception 'Izin % sudah kedaluwarsa (batas kembali %).', v_nama, to_char(v.kembali_batas at time zone 'Asia/Makassar', 'DD/MM/YYYY HH24.MI'); end if;
    if now() < v.keluar_pada - make_interval(mins => v_awal) then
      raise exception 'Izin % baru berlaku %.', v_nama, to_char(v.keluar_pada at time zone 'Asia/Makassar', 'DD/MM/YYYY HH24.MI') || ' WITA';
    end if;
    update student_permits set status = 'keluar', keluar_aktual = now(), dicatat_keluar_oleh = public.saya() where id = v.id;
    insert into gate_logs (jenis, student_id, permit_id, petugas_id, foto_id, penjemput, catatan)
    values ('keluar', v_santri, v.id, public.saya(), v_foto, coalesce(nullif(trim(p->>'penjemput'), ''), v.penjemput), v_catatan) returning id into v_log;

  elsif v_aksi = 'kembali' then
    if v.id is null then
      select * into v from student_permits where student_id = v_santri and status = 'keluar' order by keluar_aktual desc nulls last limit 1 for update;
    end if;
    if v.id is null or v.status <> 'keluar' then raise exception '% tidak tercatat sedang di luar pondok.', v_nama; end if;
    v_menit := case when now() > v.kembali_batas then floor(extract(epoch from (now() - v.kembali_batas)) / 60)::int end;
    update student_permits set status = 'kembali', kembali_pada = now(), dicatat_kembali_oleh = public.saya() where id = v.id;
    insert into gate_logs (jenis, student_id, permit_id, petugas_id, foto_id, penjemput, catatan, terlambat_menit)
    values ('kembali', v_santri, v.id, public.saya(), v_foto, nullif(trim(p->>'penjemput'), ''), v_catatan, v_menit) returning id into v_log;
    -- Bila keterlambatan sudah dikabarkan, kabari pula bahwa santri sudah kembali
    if v.terlambat_dikabari is not null then
      insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
      select distinct x, 'Sudah kembali: ' || v_nama, 'Kembali ' || to_char(now() at time zone 'Asia/Makassar', 'DD/MM HH24.MI') || ' WITA · terlambat '
             || public._durasi_menit(v_menit), '/izin-santri/riwayat', 'SignIn', 'hijau'
        from (select v.pengusul_id x union select public._pengasuh_santri(v_santri) union select public._pejabat_unit('KESANTRIAN', 30)) q
       where x is not null and x is distinct from public.saya();
    end if;

  else -- ditolak
    if length(coalesce(v_catatan, '')) < 5 then raise exception 'Tuliskan alasan/keterangan penolakan (minimal 5 huruf).'; end if;
    insert into gate_logs (jenis, student_id, permit_id, petugas_id, foto_id, penjemput, catatan)
    values ('ditolak', v_santri, v.id, public.saya(), v_foto, nullif(trim(p->>'penjemput'), ''), v_catatan) returning id into v_log;
    insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
    select distinct x, 'Ditolak di gerbang: ' || v_nama,
           v_catatan || coalesce(' · penjemput ' || nullif(trim(p->>'penjemput'), ''), '') || '. Bila perlu, buat izin cepat di menu Security.',
           '/security/gerbang?santri=' || v_santri, 'ShieldCheck', 'jingga'
      from (select public._pejabat_unit('KESANTRIAN', 30) x
            union select ap.employee_id from admin_permissions ap join employees e on e.id = ap.employee_id and e.status_akun = 'aktif'
                   where ap.kode = 'kelola_izin_santri') q
     where x is not null and x is distinct from public.saya();
  end if;
  return public._santri_gerbang_json(v_santri) || jsonb_build_object('log_id', v_log);
end $$;

create or replace function public._durasi_menit(p int)
returns text language sql immutable as $$
  select case when p is null then '0 menit' when p < 60 then p || ' menit'
              when p < 1440 then (p / 60) || ' jam' || case when p % 60 > 0 then ' ' || (p % 60) || ' menit' else '' end
              else (p / 1440) || ' hari' || case when (p % 1440) / 60 > 0 then ' ' || ((p % 1440) / 60) || ' jam' else '' end end
$$;

/** Fungsi lama (Fase 6) tetap tersedia, kini hanya untuk petugas gerbang. */
create or replace function public.catat_gerbang_izin(p_id uuid, p_aksi text, p_waktu timestamptz default null)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  perform public.catat_gerbang(jsonb_build_object('aksi', p_aksi, 'permit_id', p_id));
end $$;

-- ---------------------------------------------------------------------
-- 6. IZIN CEPAT (langsung berlaku)
-- ---------------------------------------------------------------------
create or replace function public.izin_cepat(p jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare v_s record; v_keluar timestamptz := coalesce((p->>'keluar_pada')::timestamptz, now()); v_kembali timestamptz := (p->>'kembali_batas')::timestamptz;
        v_lama int; v_batas int := (public.pengaturan_izin()->>'batas_hari_bidang')::int; v_puncak boolean; v_id uuid; v_sebagai text;
begin
  if not public.boleh_izin_cepat() then
    raise exception 'Izin cepat hanya dapat dibuat Kepala Bidang Kesantrian, Direktur/Wadir, Plt, atau superadmin.' using errcode = '42501';
  end if;
  select id, nama_lengkap, status into v_s from students where id = nullif(p->>'student_id', '')::uuid;
  if v_s.id is null then raise exception 'Pilih santri.'; end if;
  if v_s.status <> 'aktif' then raise exception '% tidak berstatus aktif.', v_s.nama_lengkap; end if;
  if length(trim(coalesce(p->>'alasan', ''))) < 5 then raise exception 'Tuliskan alasan izin (minimal 5 huruf).'; end if;
  if v_kembali is null or v_kembali <= v_keluar then raise exception 'Batas kembali harus setelah waktu keluar.'; end if;
  if v_keluar < now() - interval '1 hour' then raise exception 'Waktu keluar izin cepat paling lambat satu jam yang lalu.'; end if;
  if coalesce(p->>'jenis', 'pulang') = 'pulang' and length(trim(coalesce(p->>'penjemput', ''))) < 2 then raise exception 'Isi nama penjemput untuk izin pulang.'; end if;
  if exists (select 1 from student_permits where student_id = v_s.id and status in ('disetujui','keluar')
              and keluar_pada < v_kembali and kembali_batas > v_keluar) then
    raise exception '% sudah memiliki izin yang berlaku pada rentang tersebut.', v_s.nama_lengkap;
  end if;
  v_lama := greatest(1, ceil(extract(epoch from (v_kembali - v_keluar)) / 86400.0)::int);
  v_puncak := public.is_superadmin() or public.saya() in (select public._pimpinan_puncak());
  if v_lama > v_batas and not v_puncak then
    raise exception 'Izin lebih dari % hari memerlukan Direktur/Wakil Direktur. Ajukan melalui menu Perizinan Santri.', v_batas;
  end if;
  -- Izin menunggu pada rentang yang sama digantikan oleh izin cepat
  update student_permits set status = 'dibatalkan', catatan = trim(coalesce(catatan || E'\n', '') || 'Digantikan izin cepat di gerbang.')
   where student_id = v_s.id and status in ('diajukan','disetujui_bidang') and keluar_pada < v_kembali and kembali_batas > v_keluar;
  insert into student_permits (student_id, jenis, alasan, penjemput, hubungan_penjemput, hp_penjemput, keluar_pada, kembali_batas,
                               lama_hari, sumber, pengusul_id, peran_pengusul, unit_kode, perlu_pimpinan, status, catatan)
  values (v_s.id, case when p->>'jenis' = 'keluar' then 'keluar' else 'pulang' end, trim(p->>'alasan'),
          nullif(trim(p->>'penjemput'), ''), nullif(trim(p->>'hubungan_penjemput'), ''), nullif(trim(p->>'hp_penjemput'), ''),
          v_keluar, v_kembali, v_lama, 'cepat', public.saya(), 'pimpinan', 'KESANTRIAN', v_lama > v_batas, 'disetujui',
          nullif(trim(p->>'catatan'), ''))
  returning id into v_id;
  v_sebagai := case when public.saya() in (select public._pimpinan_puncak()) then 'Direktur/Wakil Direktur'
                    when public.saya() in (select public._pejabat_unit('KESANTRIAN', 30)) then 'Kepala Bidang Kesantrian' else 'Superadmin' end;
  insert into student_permit_approvals (permit_id, tingkat, keputusan, oleh, sebagai, catatan)
  values (v_id, 1, 'setuju', public.saya(), v_sebagai, 'Izin cepat');
  if v_lama > v_batas then
    insert into student_permit_approvals (permit_id, tingkat, keputusan, oleh, sebagai, catatan)
    values (v_id, 2, 'setuju', public.saya(), v_sebagai, 'Izin cepat');
  end if;
  perform public._kabari_hasil_izin(v_id, 'Izin cepat: ' || v_s.nama_lengkap,
    to_char(v_keluar at time zone 'Asia/Makassar', 'DD/MM HH24.MI') || ' s.d. ' || to_char(v_kembali at time zone 'Asia/Makassar', 'DD/MM HH24.MI') || ' · ' || trim(p->>'alasan'), 'hijau');
  insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
  select x, 'Izin cepat berlaku: ' || v_s.nama_lengkap, 'Santri boleh keluar sampai ' || to_char(v_kembali at time zone 'Asia/Makassar', 'DD/MM HH24.MI') || ' WITA.',
         '/security/gerbang?santri=' || v_s.id, 'ShieldCheck', 'hijau'
    from public._petugas_security() x where x is distinct from public.saya();
  return public._santri_gerbang_json(v_s.id);
end $$;

-- ---------------------------------------------------------------------
-- 7. PENGINGAT TERLAMBAT KEMBALI (pg_cron tiap 5 menit)
-- ---------------------------------------------------------------------
create or replace function public.security_pengingat()
returns int language plpgsql volatile security definer set search_path = public as $$
declare r record; n int := 0; v_tol int := (public.pengaturan_security()->>'toleransi_terlambat_menit')::int;
begin
  for r in select p.id, p.student_id, p.pengusul_id, p.kembali_batas, s.nama_lengkap,
                  coalesce(public._kelompok_santri(s.id, 'kamar'), '') kamar, coalesce(public._kelompok_santri(s.id, 'kelas'), '') kelas
             from student_permits p join students s on s.id = p.student_id
            where p.status = 'keluar' and p.terlambat_dikabari is null and now() > p.kembali_batas + make_interval(mins => v_tol)
  loop
    insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
    select distinct x, 'Terlambat kembali: ' || r.nama_lengkap,
           'Batas kembali ' || to_char(r.kembali_batas at time zone 'Asia/Makassar', 'DD/MM HH24.MI') || ' WITA'
           || case when r.kelas <> '' then ' · ' || r.kelas else '' end || case when r.kamar <> '' then ' · ' || r.kamar else '' end
           || '. Mohon hubungi wali santri.', '/izin-santri/aktif', 'Siren', 'merah'
      from (select r.pengusul_id x union select public._pengasuh_santri(r.student_id) union select public._pejabat_unit('KESANTRIAN', 30)) q
     where x is not null;
    update student_permits set terlambat_dikabari = now() where id = r.id; n := n + 1;
  end loop;
  return n;
end $$;
revoke execute on function public.security_pengingat() from public, anon, authenticated;
select cron.unschedule('pengingat-security') where exists (select 1 from cron.job where jobname = 'pengingat-security');
select cron.schedule('pengingat-security', '*/5 * * * *', $$ select public.security_pengingat() $$);

-- ---------------------------------------------------------------------
-- 8. KARTU BERANDA
-- ---------------------------------------------------------------------
create or replace function public.ringkasan_security_beranda()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_hari date := public.hari_ini(); v_awal int := (public.pengaturan_security()->>'keluar_lebih_awal_menit')::int;
begin
  if public.saya() is null or not public.boleh_lihat_security() then return null; end if;
  return jsonb_build_object(
    'petugas', public.boleh_gerbang(),
    'siap', (select count(distinct p.student_id) from student_permits p where p.status = 'disetujui' and p.kembali_batas > now()
              and ((p.keluar_pada at time zone 'Asia/Makassar')::date <= v_hari or p.keluar_pada - make_interval(mins => v_awal) <= now())),
    'di_luar', (select count(*) from student_permits p where p.status = 'keluar'),
    'terlambat', (select count(*) from student_permits p where p.status = 'keluar' and now() > p.kembali_batas),
    'keluar_hari_ini', (select count(*) from gate_logs g where g.jenis = 'keluar' and (g.waktu at time zone 'Asia/Makassar')::date = v_hari),
    'kembali_hari_ini', (select count(*) from gate_logs g where g.jenis = 'kembali' and (g.waktu at time zone 'Asia/Makassar')::date = v_hari),
    'ditolak_hari_ini', (select count(*) from gate_logs g where g.jenis = 'ditolak' and (g.waktu at time zone 'Asia/Makassar')::date = v_hari));
end $$;

-- ---------------------------------------------------------------------
-- 9. DAFTAR IZIN (Fase 6): tombol catat hanya untuk petugas gerbang
-- ---------------------------------------------------------------------
create or replace function public.daftar_izin(p_cakupan text, p_mulai date default null, p_selesai date default null, p_group uuid default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_mulai date := coalesce(p_mulai, public.hari_ini() - 30); v_selesai date := coalesce(p_selesai, public.hari_ini() + 30);
begin
  if public.saya() is null then return '[]'::jsonb; end if;
  return coalesce((select jsonb_agg(x order by x->>'urut', x->>'keluar_pada' desc) from (
    select jsonb_build_object('id', p.id, 'student_id', p.student_id, 'nama', s.nama_lengkap, 'nis', s.nis, 'jenis_kelamin', s.jenis_kelamin,
      'kelas', public._kelompok_santri(s.id, 'kelas'), 'kamar', public._kelompok_santri(s.id, 'kamar'),
      'jenis', p.jenis, 'alasan', p.alasan, 'penjemput', p.penjemput, 'hubungan_penjemput', p.hubungan_penjemput, 'hp_penjemput', p.hp_penjemput,
      'keluar_pada', p.keluar_pada, 'kembali_batas', p.kembali_batas, 'lama_hari', p.lama_hari, 'sumber', p.sumber,
      'peran_pengusul', p.peran_pengusul, 'pengusul', e.nama_lengkap, 'unit_kode', p.unit_kode, 'pemutus', public._label_unit_izin(p.unit_kode),
      'perlu_pimpinan', p.perlu_pimpinan, 'status', p.status, 'keluar_aktual', p.keluar_aktual, 'kembali_pada', p.kembali_pada,
      'catatan', p.catatan, 'created_at', p.created_at,
      'terlambat', (p.status = 'keluar' and now() > p.kembali_batas) or (p.status = 'kembali' and p.kembali_pada > p.kembali_batas),
      'boleh_putus', (p.status = 'diajukan' and public.boleh_putus_izin(p.unit_kode, 1)) or (p.status = 'disetujui_bidang' and public.boleh_putus_izin(p.unit_kode, 2)),
      'boleh_ubah', p.status = 'diajukan' and (p.pengusul_id = public.saya() or public.boleh_putus_izin(p.unit_kode, 1) or public.boleh_kelola_izin()),
      'boleh_batal', p.status in ('diajukan','disetujui_bidang','disetujui') and (p.pengusul_id = public.saya() or public.boleh_kelola_izin() or public.boleh_putus_izin(p.unit_kode, 1)),
      'boleh_catat', p.status in ('disetujui','keluar') and public.boleh_gerbang(),
      'terlambat_menit', case when p.status = 'kembali' and p.kembali_pada > p.kembali_batas then floor(extract(epoch from (p.kembali_pada - p.kembali_batas)) / 60)::int end,
      'keputusan', coalesce((select jsonb_agg(jsonb_build_object('tingkat', a.tingkat, 'keputusan', a.keputusan, 'sebagai', a.sebagai, 'oleh', ae.nama_lengkap,
                    'catatan', a.catatan, 'pada', a.pada) order by a.pada) from student_permit_approvals a left join employees ae on ae.id = a.oleh
                    where a.permit_id = p.id), '[]'::jsonb),
      'urut', case when p.status in ('diajukan','disetujui_bidang') then '0' when p.status = 'keluar' and now() > p.kembali_batas then '1'
                   when p.status in ('disetujui','keluar') then '2' else '3' end) x
      from student_permits p join students s on s.id = p.student_id left join employees e on e.id = p.pengusul_id
     where public.boleh_lihat_izin(p.student_id, p.unit_kode)
       and (p_group is null or p.student_id in (select m.student_id from group_members m where m.group_id = p_group and m.selesai is null))
       and case p_cakupan
             when 'persetujuan' then (p.status = 'diajukan' and public.boleh_putus_izin(p.unit_kode, 1)) or (p.status = 'disetujui_bidang' and public.boleh_putus_izin(p.unit_kode, 2))
             when 'menunggu' then p.status in ('diajukan','disetujui_bidang')
             when 'aktif' then p.status in ('disetujui','keluar')
             when 'semua' then (p.keluar_pada at time zone 'Asia/Makassar')::date between v_mulai and v_selesai
                               or p.status in ('diajukan','disetujui_bidang','disetujui','keluar')
             else false end) q), '[]'::jsonb);
end $$;

-- ---------------------------------------------------------------------
-- 10. HAK LIHAT FOTO (Edge Function "berkas"): foto gerbang + perbaikan foto Lapor dan Jurnal Musyrif
-- ---------------------------------------------------------------------
create or replace function public.boleh_lihat_berkas(p_obj uuid, p_emp uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 VOLATILE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r leave_requests; v_peran text; j journal_entries;
  izin boolean := false; v_sub text;
begin
  select peran into v_peran from employees where id = p_emp;
  if v_peran = 'superadmin' then return true; end if;
  for r in select * from leave_requests where lampiran_id = p_obj loop
    if r.employee_id = p_emp
       or (v_peran = 'admin' and exists (select 1 from admin_permissions where employee_id = p_emp and kode = 'lihat_pengajuan'))
       or exists (select 1 from leave_approvals a where a.request_id = r.id and a.oleh = p_emp)
       or exists (select 1 from leave_approvals a, public.calon_penyetuju(r.employee_id, a.peran) c
                   where a.request_id = r.id and a.status = 'menunggu' and c.employee_id = p_emp) then
      return true;
    end if;
  end loop;
  for j in select * from journal_entries where foto_id = p_obj loop
    if j.employee_id = p_emp
       or (v_peran = 'admin' and exists (select 1 from admin_permissions where employee_id = p_emp and kode = 'verval_jurnal'))
       or exists (select 1 from employees t, employee_structurals es join structural_positions sp on sp.id = es.structural_position_id
                   where t.id = j.employee_id and es.employee_id = p_emp
                     and (sp.tingkat <= 20 or t.org_unit_id in (select public.unit_turunan(es.org_unit_id)))) then
      return true;
    end if;
  end loop;
  if exists (select 1 from employee_documents d where d.berkas_id = p_obj and (
              exists (select 1 from employee_document_targets t where t.document_id = d.id and t.employee_id = p_emp)
              or (v_peran = 'admin' and exists (select 1 from admin_permissions where employee_id = p_emp and kode = 'kelola_berkas')))) then
    return true;
  end if;
  -- Lampiran agenda: penerima, pembuat, dan admin
  if exists (select 1 from agendas g where g.lampiran_id = p_obj and (
              exists (select 1 from agenda_targets t where t.agenda_id = g.id and t.employee_id = p_emp)
              or g.dibuat_oleh = p_emp or v_peran = 'admin')) then
    return true;
  end if;
  -- Lampiran pengumuman: penerima dan pembuat pengumuman
  if exists (select 1 from announcements a where a.lampiran_id = p_obj and (
              exists (select 1 from announcement_targets t where t.announcement_id = a.id and t.employee_id = p_emp)
              or a.dibuat_oleh = p_emp or v_peran = 'admin')) then
    return true;
  end if;
  -- Foto profil pegawai untuk pencetak kartu
  if v_peran = 'admin' and exists (select 1 from admin_permissions where employee_id = p_emp and kode = 'cetak_kartu')
     and exists (select 1 from employees where foto_id = p_obj) then
    return true;
  end if;
  -- Foto jurnal ekskul: pengasuh kelompok, admin, dan pimpinan yang dapat melihat santri
  -- (perbaikan Fase 7: alias "j" bentrok dengan variabel j sehingga fungsi galat untuk semua foto yang sampai di sini)
  if exists (select 1 from extracurricular_journals ej join student_attendance_sessions sa on sa.id = ej.session_id
             where ej.foto_id = p_obj and (v_peran = 'admin'
               or p_emp in (select employee_id from group_keepers where group_id = sa.group_id)
               or public.tingkat_fitur_pegawai(p_emp, 'absensi_ekskul') >= 1)) then
    return true;
  end if;
  -- Foto Lapor ke Bidang dan Jurnal Musyrif (perbaikan Fase 6): diperiksa dengan hak pegawai yang meminta
  -- (pelapor, penerima laporan, pimpinan; pengasuh/pimpinan kamar), memakai fungsi hak yang sama dengan aplikasi.
  if exists (select 1 from incident_reports ir where ir.foto_id = p_obj) or exists (select 1 from dorm_journals dj where dj.foto_id = p_obj) then
    v_sub := current_setting('request.jwt.claim.sub', true);
    perform set_config('request.jwt.claim.sub', coalesce((select user_id::text from employees where id = p_emp), ''), true);
    izin := exists (select 1 from incident_reports ir where ir.foto_id = p_obj and (ir.pelapor_id = p_emp or public.boleh_tangani_lapor(ir.unit_kode)))
         or exists (select 1 from dorm_journals dj where dj.foto_id = p_obj and public.boleh_lihat_kamar(dj.group_id));
    perform set_config('request.jwt.claim.sub', coalesce(v_sub, ''), true);
    if izin then return true; end if;
  end if;
  -- Foto gerbang Security (Fase 7): petugas gerbang, pemegang hak pantauan, dan admin
  if exists (select 1 from gate_logs gl where gl.foto_id = p_obj) and (v_peran = 'admin'
       or public.tingkat_fitur_pegawai(p_emp, 'gerbang') >= 1 or public.tingkat_fitur_pegawai(p_emp, 'pantauan') >= 1) then
    return true;
  end if;
  return false;
end $function$;
revoke execute on function public.boleh_lihat_berkas(uuid,uuid) from public, anon, authenticated;
grant execute on function public.boleh_lihat_berkas(uuid,uuid) to service_role;

-- ---------------------------------------------------------------------
-- 11. HAK EKSEKUSI
-- ---------------------------------------------------------------------
do $$
declare f text;
begin
  foreach f in array array['boleh_gerbang()','boleh_kelola_security()','boleh_lihat_security()','boleh_izin_cepat()','pengaturan_security()',
    'simpan_pengaturan_security(jsonb)','hak_security()','cari_santri_gerbang(text,integer)','santri_gerbang(uuid)','daftar_gerbang()',
    'riwayat_gerbang(date,date,text)','catat_gerbang(jsonb)','catat_gerbang_izin(uuid,text,timestamptz)','izin_cepat(jsonb)',
    'ringkasan_security_beranda()','daftar_izin(text,date,date,uuid)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  foreach f in array array['_status_gerbang(uuid)','_izin_gerbang_json(uuid)','_santri_gerbang_json(uuid)','_petugas_security()','_pengasuh_santri(uuid)'] loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN (hasil yang benar: baris 1–7 "Sesuai"; baris 8 menampilkan jumlah petugas Security berakun aktif)
-- ---------------------------------------------------------------------
select '1. Izin admin kelola_security' as pemeriksaan,
       case when exists (select 1 from public.admin_capabilities where kode = 'kelola_security') then 'Sesuai' else 'Periksa' end as hasil
union all select '2. Tabel catatan gerbang (gate_logs)', case when to_regclass('public.gate_logs') is not null then 'Sesuai' else 'Periksa' end
union all select '3. Fungsi gerbang (cari, catat, izin cepat)', case when (select count(*) from pg_proc where proname in ('cari_santri_gerbang','catat_gerbang','izin_cepat','daftar_gerbang','riwayat_gerbang')) = 5 then 'Sesuai' else 'Periksa' end
union all select '4. Jadwal pengingat terlambat (pengingat-security)', case when exists (select 1 from cron.job where jobname = 'pengingat-security') then 'Sesuai' else 'Periksa' end
union all select '5. Izin cepat dapat dicatat (sumber cepat)', case when exists (select 1 from pg_constraint where conname = 'student_permits_sumber_check' and pg_get_constraintdef(oid) like '%cepat%') then 'Sesuai' else 'Periksa' end
union all select '6. Hak fitur gerbang untuk jabatan Security', case when exists (select 1 from feature_grants g join functional_positions fp on fp.id = g.sasaran_id where g.feature_kode = 'gerbang' and fp.kode = 'SECURITY' and g.tingkat >= 2) then 'Sesuai' else 'Periksa' end
union all select '7. Hak lihat foto lapor/jurnal musyrif (perbaikan)', case when pg_get_functiondef('public.boleh_lihat_berkas'::regproc) like '%dorm_journals%' then 'Sesuai' else 'Periksa' end
union all select '8. Petugas Security berakun aktif', (select count(*)::text || ' orang' from public._petugas_security());
