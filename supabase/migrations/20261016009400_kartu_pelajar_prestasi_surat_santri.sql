-- SIMKA PRO | supabase/migrations/20261016009400_kartu_pelajar_prestasi_surat_santri.sql | v1.0 | Tahap C: foto dan kartu pelajar santri, prestasi santri, surat rekomendasi/SKL/keterangan prestasi | 16/10/2026
-- A. Foto santri (bucket "profil", path santri/{id}/…) dan kartu pelajar berkode QR (verifikasi publik bersama kartu pegawai).
--    Foto dipasang oleh admin ber-izin Kelola santri, pengubah data santri, atau wali kelas santri tersebut; dapat dilihat oleh
--    pengguna yang berhak melihat santri itu. Foto yang sama dipakai di kartu pelajar dan halaman identitas rapor.
-- B. Prestasi/capaian santri: dicatat wali kelas, musyrif, muhaffizh, pembina ekskul santri tersebut, pimpinan, admin ber-izin
--    Kelola santri, dan superadmin. Pengasuh santri mendapat notifikasi. Prestasi bertanda "masuk rapor" tampil di rapor semester.
-- C. Surat santri dari template persuratan (nomor, tanda tangan elektronik, registri): Surat Rekomendasi Sekolah,
--    Surat Keterangan Lulus (SKL, dengan kotak pas foto), dan Surat Keterangan Prestasi. Data santri untuk surat ditambah
--    nama ayah/ibu, jumlah hafalan, tanggal masuk, dan daftar prestasi.
-- Aman dijalankan ulang.

-- =====================================================================
-- A. FOTO DAN KARTU PELAJAR
-- =====================================================================
create table if not exists public.student_cards (
  student_id   uuid primary key references public.students(id) on delete cascade,
  kode         text not null unique,
  dibuat_pada  timestamptz not null default now(),
  diganti_pada timestamptz
);
alter table public.student_cards enable row level security;   -- hanya lewat fungsi

create or replace function public._kode_kartu_santri()
returns text language plpgsql volatile set search_path = public as $$
declare v text;
begin
  loop
    v := public._kode_kartu();
    exit when not exists (select 1 from student_cards where kode = v) and not exists (select 1 from employee_cards where kode = v);
  end loop;
  return v;
end $$;

/** Hak mengelola foto santri dari path berkas "santri/{id}/…" (dipakai kebijakan storage). */
create or replace function public._boleh_foto_santri(p_bagian text)
returns boolean language sql stable security definer set search_path = public as $$
  select case when p_bagian ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
              then public.boleh_ubah_santri(p_bagian::uuid) else false end
$$;
create or replace function public._lihat_foto_santri(p_bagian text)
returns boolean language sql stable security definer set search_path = public as $$
  select case when p_bagian ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
              then p_bagian::uuid in (select public.santri_terlihat()) else false end
$$;

drop policy if exists "profil santri dikelola" on storage.objects;
create policy "profil santri dikelola" on storage.objects for all to authenticated
  using (bucket_id = 'profil' and split_part(name, '/', 1) = 'santri' and public._boleh_foto_santri(split_part(name, '/', 2)))
  with check (bucket_id = 'profil' and split_part(name, '/', 1) = 'santri' and public._boleh_foto_santri(split_part(name, '/', 2)));
drop policy if exists "profil santri dibaca" on storage.objects;
create policy "profil santri dibaca" on storage.objects for select to authenticated
  using (bucket_id = 'profil' and split_part(name, '/', 1) = 'santri' and public._lihat_foto_santri(split_part(name, '/', 2)));

drop policy if exists baca_foto_santri on public.storage_objects;
create policy baca_foto_santri on public.storage_objects for select to authenticated
  using (bucket = 'profil' and kategori = 'foto_santri' and public._lihat_foto_santri(split_part(kunci, '/', 2)));

/** Pasang/ganti foto santri (berkas sudah diunggah ke bucket profil di santri/{id}/…). */
create or replace function public.pasang_foto_santri(p_santri uuid, p_obj uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
declare o storage_objects; v_lama uuid;
begin
  if not public.boleh_ubah_santri(p_santri) then raise exception 'Anda tidak berwenang mengganti foto santri ini.' using errcode = '42501'; end if;
  select * into o from storage_objects where id = p_obj;
  if o.id is null or o.bucket <> 'profil' or o.kunci not like 'santri/' || p_santri::text || '/%' then raise exception 'Berkas foto tidak sah.'; end if;
  select foto_id into v_lama from students where id = p_santri;
  update students set foto_id = p_obj, updated_at = now() where id = p_santri;
  update storage_objects set kategori = 'foto_santri', hapus_setelah = null where id = p_obj;
  if v_lama is not null and v_lama <> p_obj then update storage_objects set status = 'dihapus' where id = v_lama; end if;
end $$;

/** Data kartu pelajar untuk daftar santri (kode QR dibuat bila belum ada). */
create or replace function public.data_kartu_santri(p_ids uuid[])
returns jsonb language plpgsql volatile security definer set search_path = public as $$
begin
  if public.saya() is null and not public.is_superadmin() then raise exception 'Akun Anda belum aktif.' using errcode = '42501'; end if;
  if coalesce(array_length(p_ids, 1), 0) = 0 then return '[]'::jsonb; end if;
  if array_length(p_ids, 1) > 600 then raise exception 'Paling banyak 600 kartu sekali cetak.'; end if;
  if not (public.admin_boleh('kelola_santri') or public.admin_boleh('cetak_kartu'))
     and exists (select 1 from unnest(p_ids) x where not public.boleh_ubah_santri(x)) then
    raise exception 'Anda hanya dapat mencetak kartu pelajar santri yang Anda kelola.' using errcode = '42501';
  end if;
  insert into student_cards (student_id, kode)
  select x, public._kode_kartu_santri() from unnest(p_ids) x
   where exists (select 1 from students s where s.id = x) and not exists (select 1 from student_cards c where c.student_id = x)
  on conflict do nothing;
  return coalesce((select jsonb_agg(jsonb_build_object(
      'student_id', s.id, 'nama', s.nama_lengkap, 'nis', s.nis, 'nisn', s.nisn, 'jenis_kelamin', s.jenis_kelamin,
      'tempat_lahir', s.tempat_lahir, 'tanggal_lahir', s.tanggal_lahir, 'jenjang', s.jenjang, 'tingkat', s.tingkat,
      'kelas', public._kelompok_santri(s.id, 'kelas'), 'kamar', public._kelompok_santri(s.id, 'kamar'),
      'alamat', s.alamat, 'tahun_masuk', s.tahun_masuk, 'foto_id', s.foto_id, 'kode', c.kode, 'aktif', s.status = 'aktif',
      'wali', coalesce((select ct.nama from student_contacts ct where ct.student_id = s.id and ct.nama is not null
                         order by case ct.hubungan when 'ayah' then 1 when 'wali' then 2 else 3 end limit 1), ''))
      order by s.jenjang, s.tingkat, s.nama_lengkap)
    from students s join student_cards c on c.student_id = s.id where s.id = any (p_ids)), '[]'::jsonb);
end $$;

/** Ganti kode kartu pelajar (kartu hilang): kartu lama tidak berlaku. */
create or replace function public.ganti_kode_kartu_santri(p_santri uuid)
returns text language plpgsql volatile security definer set search_path = public as $$
declare v text := public._kode_kartu_santri();
begin
  if not (public.boleh_ubah_santri(p_santri) or public.admin_boleh('cetak_kartu')) then raise exception 'Tidak berwenang.' using errcode = '42501'; end if;
  insert into student_cards (student_id, kode) values (p_santri, v)
  on conflict (student_id) do update set kode = excluded.kode, diganti_pada = now();
  perform public.catat_audit('ganti_kode_kartu', 'student_cards', p_santri::text, 'Kode kartu pelajar diganti', null);
  return v;
end $$;

/** Verifikasi kartu (publik): kartu pegawai, lalu kartu pelajar. Hanya data minimal. */
create or replace function public.cek_kartu(p_kode text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_kode text := upper(regexp_replace(coalesce(p_kode, ''), '[^A-Za-z0-9]', '', 'g')); v jsonb;
  v_lembaga text := (select nilai->>'nama_lengkap' from institution_settings where kunci = 'identitas');
begin
  select jsonb_build_object('ditemukan', true, 'jenis', 'pegawai', 'nama', e.nama_lengkap, 'niy', e.niy, 'unit', u.nama,
           'jabatan', nullif(concat_ws(', ', (select string_agg(sp.nama, ', ') from employee_structurals es join structural_positions sp on sp.id = es.structural_position_id where es.employee_id = e.id),
              (select string_agg(fp.nama, ', ' order by fp.urutan) from employee_functions ef join functional_positions fp on fp.id = ef.functional_position_id where ef.employee_id = e.id)), ''),
           'berlaku', e.status_keaktifan = 'aktif', 'lembaga', v_lembaga)
    into v
    from employee_cards c join employees e on e.id = c.employee_id left join org_units u on u.id = e.org_unit_id
   where c.kode = v_kode;
  if v is not null then return v; end if;
  select jsonb_build_object('ditemukan', true, 'jenis', 'santri', 'nama', s.nama_lengkap, 'nis', s.nis,
           'jenjang', case s.jenjang when 'sma' then 'SMA' else 'Kesetaraan Wustha' end,
           'kelas', coalesce(public._kelompok_santri(s.id, 'kelas'), 'Kelas ' || s.tingkat),
           'berlaku', s.status = 'aktif', 'lembaga', v_lembaga)
    into v
    from student_cards c join students s on s.id = c.student_id
   where c.kode = v_kode;
  return coalesce(v, jsonb_build_object('ditemukan', false));
end $$;

-- =====================================================================
-- B. PRESTASI SANTRI
-- =====================================================================
create table if not exists public.student_achievements (
  id             uuid primary key default gen_random_uuid(),
  student_id     uuid not null references public.students(id) on delete cascade,
  tanggal        date not null default public.hari_ini(),
  bidang         text not null default 'non_akademik'
                 constraint student_achievements_bidang_check check (bidang in ('akademik','tahfizh','keagamaan','non_akademik','karakter')),
  tingkat        text not null default 'pondok'
                 constraint student_achievements_tingkat_check check (tingkat in ('pondok','kecamatan','kabupaten','provinsi','nasional','internasional')),
  nama_kegiatan  text not null constraint student_achievements_kegiatan_check check (length(trim(nama_kegiatan)) >= 3),
  capaian        text not null constraint student_achievements_capaian_check check (length(trim(capaian)) >= 2),
  penyelenggara  text,
  keterangan     text,
  bukti_id       uuid references public.storage_objects(id) on delete set null,
  masuk_rapor    boolean not null default true,
  dicatat_oleh   uuid references public.employees(id) on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index if not exists student_achievements_santri_idx on public.student_achievements (student_id, tanggal desc);
create index if not exists student_achievements_tanggal_idx on public.student_achievements (tanggal desc);
alter table public.student_achievements enable row level security;
drop policy if exists baca on public.student_achievements;
create policy baca on public.student_achievements for select to authenticated
  using (student_id in (select public.santri_terlihat()));

/** Pengasuh santri yang berlaku (wali kelas, musyrif, muhaffizh, pembina ekskul). */
create or replace function public._pengasuh_prestasi(p_santri uuid)
returns setof uuid language sql stable security definer set search_path = public as $$
  select distinct k.employee_id from group_members m
    join student_groups g on g.id = m.group_id and g.aktif and g.jenis in ('kamar','kelas','halaqah','ekskul')
    join academic_years a on a.id = g.academic_year_id and a.aktif
    join group_keepers k on k.group_id = g.id and (k.mulai is null or k.mulai <= public.hari_ini()) and (k.sampai is null or k.sampai >= public.hari_ini())
   where m.student_id = p_santri and m.selesai is null
$$;

/** Boleh mencatat prestasi santri: pengasuhnya, pimpinan (dalam cakupan), admin Kelola santri, superadmin. */
create or replace function public.boleh_catat_prestasi(p_santri uuid default null)
returns boolean language sql stable security definer set search_path = public as $$
  select public.admin_boleh('kelola_santri')
      or (p_santri is null and (exists (select 1 from public.unit_pimpinan_saya())
                                or exists (select 1 from group_keepers k join student_groups g on g.id = k.group_id and g.aktif
                                            where k.employee_id = public.saya() and g.jenis in ('kamar','kelas','halaqah','ekskul')
                                              and (k.sampai is null or k.sampai >= public.hari_ini()))))
      or (p_santri is not null and public.saya() in (select public._pengasuh_prestasi(p_santri)))
      or (p_santri is not null and exists (select 1 from public.unit_pimpinan_saya()) and p_santri in (select public.santri_terlihat()))
$$;

/** Simpan prestasi. p: { id?, student_id, tanggal, bidang, tingkat, nama_kegiatan, capaian, penyelenggara?, keterangan?, bukti_id?, masuk_rapor? } */
create or replace function public.simpan_prestasi(p jsonb)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v_id uuid := nullif(p->>'id', '')::uuid; v_santri uuid := nullif(p->>'student_id', '')::uuid; v_lama student_achievements;
  v_nama text; e uuid; v_saya uuid := public.saya();
begin
  if v_id is not null then
    select * into v_lama from student_achievements where id = v_id;
    if v_lama.id is null then raise exception 'Data prestasi tidak ditemukan.'; end if;
    v_santri := v_lama.student_id;
    if not (v_lama.dicatat_oleh = v_saya or public.admin_boleh('kelola_santri')
            or (exists (select 1 from public.unit_pimpinan_saya()) and v_santri in (select public.santri_terlihat()))) then
      raise exception 'Prestasi hanya dapat diubah oleh pencatatnya, pimpinan, atau admin.' using errcode = '42501';
    end if;
  elsif v_santri is null then raise exception 'Pilih santri.';
  end if;
  if not public.boleh_catat_prestasi(v_santri) then raise exception 'Anda tidak berwenang mencatat prestasi santri ini.' using errcode = '42501'; end if;
  if length(trim(coalesce(p->>'nama_kegiatan', ''))) < 3 then raise exception 'Isi nama kegiatan/lomba (minimal 3 huruf).'; end if;
  if length(trim(coalesce(p->>'capaian', ''))) < 2 then raise exception 'Isi capaian, misalnya Juara 1 atau Hafal 5 juz.'; end if;
  if coalesce(nullif(p->>'tanggal', '')::date, public.hari_ini()) > public.hari_ini() then raise exception 'Tanggal prestasi belum terjadi.'; end if;

  if v_id is null then
    insert into student_achievements (student_id, tanggal, bidang, tingkat, nama_kegiatan, capaian, penyelenggara, keterangan, bukti_id, masuk_rapor, dicatat_oleh)
    values (v_santri, coalesce(nullif(p->>'tanggal', '')::date, public.hari_ini()), coalesce(nullif(p->>'bidang', ''), 'non_akademik'),
            coalesce(nullif(p->>'tingkat', ''), 'pondok'), trim(p->>'nama_kegiatan'), trim(p->>'capaian'), nullif(trim(coalesce(p->>'penyelenggara', '')), ''),
            nullif(trim(coalesce(p->>'keterangan', '')), ''), nullif(p->>'bukti_id', '')::uuid, coalesce((p->>'masuk_rapor')::boolean, true), v_saya)
    returning id into v_id;
    select nama_lengkap into v_nama from students where id = v_santri;
    for e in select x from public._pengasuh_prestasi(v_santri) x where x is distinct from v_saya loop
      perform public.kirim_notifikasi(e, 'Prestasi santri dicatat: ' || v_nama,
        trim(p->>'capaian') || ' · ' || trim(p->>'nama_kegiatan'), '/santri/' || v_santri::text, 'Trophy', 'emas');
    end loop;
  else
    update student_achievements set
      tanggal = coalesce(nullif(p->>'tanggal', '')::date, tanggal), bidang = coalesce(nullif(p->>'bidang', ''), bidang),
      tingkat = coalesce(nullif(p->>'tingkat', ''), tingkat), nama_kegiatan = trim(p->>'nama_kegiatan'), capaian = trim(p->>'capaian'),
      penyelenggara = nullif(trim(coalesce(p->>'penyelenggara', '')), ''), keterangan = nullif(trim(coalesce(p->>'keterangan', '')), ''),
      bukti_id = case when p ? 'bukti_id' then nullif(p->>'bukti_id', '')::uuid else bukti_id end,
      masuk_rapor = coalesce((p->>'masuk_rapor')::boolean, masuk_rapor), updated_at = now()
     where id = v_id;
  end if;
  return v_id;
end $$;

create or replace function public.hapus_prestasi(p_id uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
declare v student_achievements;
begin
  select * into v from student_achievements where id = p_id;
  if v.id is null then raise exception 'Data prestasi tidak ditemukan.'; end if;
  if not (v.dicatat_oleh = public.saya() or public.admin_boleh('kelola_santri')
          or (exists (select 1 from public.unit_pimpinan_saya()) and v.student_id in (select public.santri_terlihat()))) then
    raise exception 'Prestasi hanya dapat dihapus oleh pencatatnya, pimpinan, atau admin.' using errcode = '42501';
  end if;
  delete from student_achievements where id = p_id;
  perform public.catat_audit('hapus_prestasi', 'student_achievements', p_id::text, v.capaian || ' · ' || v.nama_kegiatan, null);
end $$;

/** Daftar prestasi santri yang terlihat (satu santri atau rentang tanggal). */
create or replace function public.daftar_prestasi(p_mulai date default null, p_selesai date default null, p_santri uuid default null)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', a.id, 'student_id', a.student_id, 'nama', s.nama_lengkap, 'nis', s.nis, 'jenis_kelamin', s.jenis_kelamin, 'jenjang', s.jenjang,
      'kelas', public._kelompok_santri(s.id, 'kelas'), 'tanggal', a.tanggal, 'bidang', a.bidang, 'tingkat', a.tingkat,
      'nama_kegiatan', a.nama_kegiatan, 'capaian', a.capaian, 'penyelenggara', a.penyelenggara, 'keterangan', a.keterangan,
      'bukti_id', a.bukti_id, 'masuk_rapor', a.masuk_rapor, 'dicatat_oleh', a.dicatat_oleh, 'pencatat', e.nama_lengkap,
      'boleh_ubah', a.dicatat_oleh = public.saya() or public.admin_boleh('kelola_santri') or exists (select 1 from public.unit_pimpinan_saya()))
      order by a.tanggal desc, s.nama_lengkap), '[]'::jsonb)
    from student_achievements a join students s on s.id = a.student_id left join employees e on e.id = a.dicatat_oleh
   where a.student_id in (select public.santri_terlihat())
     and (p_santri is null or a.student_id = p_santri)
     and (p_mulai is null or a.tanggal >= p_mulai) and (p_selesai is null or a.tanggal <= p_selesai)
$$;

/** Pelengkap rapor kelas: foto santri dan prestasi bertanda masuk rapor pada rentang semester. */
create or replace function public.pelengkap_rapor(p_group uuid, p_semester smallint)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare g student_groups; r record;
begin
  select * into g from student_groups where id = p_group;
  if g.id is null then raise exception 'Kelas tidak ditemukan.'; end if;
  if not public._boleh_lihat_kelompok_rapor(p_group) then raise exception 'Anda tidak berwenang mencetak rapor kelas ini.' using errcode = '42501'; end if;
  select * into r from public.rentang_semester(g.academic_year_id, p_semester);
  return coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'foto_id', s.foto_id,
      'prestasi', coalesce((select jsonb_agg(jsonb_build_object('tanggal', a.tanggal, 'bidang', a.bidang, 'tingkat', a.tingkat,
                   'nama_kegiatan', a.nama_kegiatan, 'capaian', a.capaian, 'penyelenggara', a.penyelenggara) order by a.tanggal)
                 from student_achievements a where a.student_id = s.id and a.masuk_rapor and a.tanggal between r.mulai and r.selesai), '[]'::jsonb)))
    from students s where s.id in (select m.student_id from group_members m where m.group_id = p_group)), '[]'::jsonb);
end $$;

-- =====================================================================
-- C. SURAT SANTRI
-- =====================================================================
create or replace function public.santri_untuk_surat(p_cari text)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(x order by x->>'nama'), '[]'::jsonb) from (
    select jsonb_build_object('id', s.id, 'nama', s.nama_lengkap, 'nis', s.nis, 'nisn', s.nisn, 'jk', s.jenis_kelamin,
      'tempat_lahir', s.tempat_lahir, 'tanggal_lahir', s.tanggal_lahir, 'jenjang', s.jenjang, 'tingkat', s.tingkat, 'alamat', s.alamat,
      'status', s.status, 'tanggal_masuk', s.tanggal_masuk, 'tahun_masuk', s.tahun_masuk, 'kelas', public._kelompok_santri(s.id, 'kelas'),
      'foto_id', s.foto_id,
      'wali', coalesce((select c.nama from student_contacts c where c.student_id = s.id and c.nama is not null
                         order by case c.hubungan when 'ayah' then 1 when 'wali' then 2 else 3 end limit 1), ''),
      'ayah', (select c.nama from student_contacts c where c.student_id = s.id and c.hubungan = 'ayah'),
      'ibu', (select c.nama from student_contacts c where c.student_id = s.id and c.hubungan = 'ibu'),
      'hafalan', (select count(*) from juz_achievements j where j.student_id = s.id),
      'prestasi', coalesce((select jsonb_agg(a.capaian || ' ' || a.nama_kegiatan
                              || case when a.tingkat <> 'pondok' then ' tingkat ' || case a.tingkat when 'kabupaten' then 'Kabupaten/Kota' else initcap(a.tingkat) end else '' end
                              || coalesce(' (' || a.penyelenggara || ', ' || extract(year from a.tanggal)::int || ')', ' (' || extract(year from a.tanggal)::int || ')')
                              order by a.tanggal desc) from student_achievements a where a.student_id = s.id), '[]'::jsonb)) x
      from students s
     where public.boleh_susun_surat() and length(trim(coalesce(p_cari, ''))) >= 2
       and (s.nama_lengkap ilike '%' || trim(p_cari) || '%' or s.nis like trim(p_cari) || '%' or s.nisn like trim(p_cari) || '%')
     limit 30) q
$$;

insert into public.letter_templates (kode, nama, kategori, perihal_kode, format_nomor, dk, kop_kode, bentuk, judul, subjudul, hal_bawaan, kepada_bawaan, opsi, isi, isian, penanda, bawaan, urutan) values
('rekomendasi_sekolah', 'Surat Rekomendasi Sekolah', 'santri', 'IL', 'surat', 'K', 'pondok', 'tengah', 'SURAT REKOMENDASI', null, 'Rekomendasi Santri', null,
 '{"salam": false}',
$t$Yang bertanda tangan di bawah ini, {penanda.jabatan} {lembaga}, dengan ini memberikan rekomendasi kepada:

Nama : {santri.nama}
NIS/NISN : {santri.nis} / {santri.nisn}
Tempat, tanggal lahir : {santri.ttl}
Jenis kelamin : {santri.jk}
Kelas : {santri.kelas} ({santri.jenjang})
Nama orang tua/wali : {santri.wali}
Jumlah hafalan : {santri.hafalan}

untuk {tujuan}.

Selama menjadi santri di {lembaga}, yang bersangkutan berakhlak baik, aktif mengikuti kegiatan pendidikan dan pembinaan, serta memiliki capaian sebagai berikut:

{prestasi}

Berdasarkan hal tersebut, kami merekomendasikan yang bersangkutan untuk dapat diterima dan mengikuti pendidikan di lembaga yang dituju.

Demikian surat rekomendasi ini dibuat dengan sebenarnya untuk dipergunakan sebagaimana mestinya.$t$,
 '[{"kunci":"santri","label":"Santri","jenis":"santri","wajib":true},{"kunci":"tujuan","label":"Tujuan rekomendasi","jenis":"teks","wajib":true,"bawaan":"melanjutkan pendidikan di "},{"kunci":"prestasi","label":"Capaian dan prestasi","jenis":"daftar","gaya":"angka","wajib":false}]',
 '[{"jabatan":"Direktur"}]', true, 14),

('keterangan_lulus', 'Surat Keterangan Lulus (SKL)', 'santri', 'IL', 'surat', 'K', 'pondok', 'tengah', 'SURAT KETERANGAN LULUS', null, 'Keterangan Lulus', null,
 '{"salam": false, "pas_foto": true}',
$t$Yang bertanda tangan di bawah ini, {penanda.jabatan} {lembaga}, berdasarkan hasil rapat dewan guru tentang penetapan kelulusan santri Tahun Ajaran {tahun_ajaran} pada tanggal {tanggal_rapat}, menerangkan bahwa:

Nama : {santri.nama}
NIS/NISN : {santri.nis} / {santri.nisn}
Tempat, tanggal lahir : {santri.ttl}
Jenis kelamin : {santri.jk}
Nama orang tua : {santri.orang_tua}
Jenjang : {santri.jenjang}
Jumlah hafalan : {santri.hafalan}

dinyatakan:

== *LULUS*

dari {santri.jenjang} {lembaga} Tahun Ajaran {tahun_ajaran}.

Surat keterangan ini berlaku sementara sampai dengan diterbitkannya ijazah dan diberikan untuk keperluan {keperluan}.

Demikian surat keterangan ini dibuat dengan sebenarnya untuk dipergunakan sebagaimana mestinya.$t$,
 '[{"kunci":"santri","label":"Santri","jenis":"santri","wajib":true},{"kunci":"tanggal_rapat","label":"Tanggal rapat penetapan kelulusan","jenis":"tanggal","wajib":true},{"kunci":"keperluan","label":"Keperluan","jenis":"teks","wajib":true,"bawaan":"pendaftaran ke jenjang pendidikan berikutnya"}]',
 '[{"jabatan":"Direktur"}]', true, 15),

('keterangan_prestasi', 'Surat Keterangan Prestasi', 'santri', 'IL', 'surat', 'K', 'pondok', 'tengah', 'SURAT KETERANGAN PRESTASI', null, 'Keterangan Prestasi Santri', null,
 '{"salam": false}',
$t$Yang bertanda tangan di bawah ini, {penanda.jabatan} {lembaga}, menerangkan bahwa:

Nama : {santri.nama}
NIS/NISN : {santri.nis} / {santri.nisn}
Tempat, tanggal lahir : {santri.ttl}
Kelas : {santri.kelas} ({santri.jenjang})
Nama orang tua/wali : {santri.wali}

adalah benar santri {lembaga} yang telah meraih prestasi sebagai berikut:

{prestasi}

Surat keterangan ini diberikan sebagai bentuk penghargaan atas prestasi tersebut dan untuk keperluan {keperluan}.

Demikian surat keterangan ini dibuat dengan sebenarnya untuk dipergunakan sebagaimana mestinya.$t$,
 '[{"kunci":"santri","label":"Santri","jenis":"santri","wajib":true},{"kunci":"prestasi","label":"Prestasi","jenis":"daftar","gaya":"angka","wajib":true},{"kunci":"keperluan","label":"Keperluan","jenis":"teks","wajib":true}]',
 '[{"jabatan":"Direktur"}]', true, 16)
on conflict (kode) do nothing;

-- =====================================================================
-- HAK EKSEKUSI
-- =====================================================================
do $$ declare f text; begin
  foreach f in array array['_kode_kartu_santri()','_pengasuh_prestasi(uuid)'] loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
  end loop;
  foreach f in array array['_boleh_foto_santri(text)','_lihat_foto_santri(text)','pasang_foto_santri(uuid,uuid)','data_kartu_santri(uuid[])',
    'ganti_kode_kartu_santri(uuid)','boleh_catat_prestasi(uuid)','simpan_prestasi(jsonb)','hapus_prestasi(uuid)','daftar_prestasi(date,date,uuid)',
    'pelengkap_rapor(uuid,smallint)','santri_untuk_surat(text)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  execute 'revoke execute on function public.cek_kartu(text) from public';
  execute 'grant execute on function public.cek_kartu(text) to anon, authenticated';
end $$;

-- PEMERIKSAAN — hasil yang benar: 3 baris "Sesuai"
select '1. Kartu pelajar dan foto santri' as pemeriksaan,
       case when to_regclass('public.student_cards') is not null
             and (select count(*) from pg_proc where proname in ('pasang_foto_santri','data_kartu_santri','ganti_kode_kartu_santri')) = 3
             and (select count(*) from pg_policies where schemaname = 'storage' and policyname in ('profil santri dikelola','profil santri dibaca')) = 2
            then 'Sesuai' else 'Periksa' end as hasil
union all
select '2. Prestasi santri', case when to_regclass('public.student_achievements') is not null
             and (select count(*) from pg_proc where proname in ('simpan_prestasi','hapus_prestasi','daftar_prestasi','pelengkap_rapor','boleh_catat_prestasi')) = 5
            then 'Sesuai' else 'Periksa' end
union all
select '3. Template surat rekomendasi, SKL, keterangan prestasi', case when (select count(*) from letter_templates
             where kode in ('rekomendasi_sekolah','keterangan_lulus','keterangan_prestasi')) = 3 then 'Sesuai' else 'Periksa' end;
