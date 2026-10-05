-- SIMKA PRO | supabase/migrations/20261006004900_jurnal_musyrif_klinik.sql | v1.0 | Fase 6 – Tahap 3 Jurnal musyrif dan klinik lanjutan | 06/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 6 · Migrasi 49: Jurnal musyrif + Klinik lanjutan (Blueprint Bagian 21)
--   * dorm_journals: jurnal kepengasuhan per kamar per hari (waktu, kategori, uraian, santri terkait, foto opsional ke Drive,
--     tanda "penting" → notifikasi Kepala Bidang Kesantrian; pimpinan dapat memberi tanggapan).
--   * Klinik: pengingat jadwal kontrol (30 menit sebelumnya) dan pemberitahuan rujukan lewat batas waktu ke petugas
--     klinik dan Kepala Bidang Kesantrian — dijalankan pg_cron tiap 10 menit (klinik_pengingat()).
--   * clinic_letters: surat keterangan sakit santri (nomor SKS otomatis, kode validasi, masa istirahat, keperluan,
--     diagnosis hanya bila dicentang). Dicetak F4 berkop dengan tanda tangan elektronik petugas.
--   * Template WA baru: santri_sakit, santri_sembuh (ke orang tua/wali).
-- Jalankan SETELAH migrasi 4800. Aman dijalankan ulang.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. JURNAL MUSYRIF
-- ---------------------------------------------------------------------
create table if not exists public.dorm_journals (
  id              uuid primary key default gen_random_uuid(),
  group_id        uuid not null references public.student_groups(id) on delete cascade,
  tanggal         date not null,
  waktu           text not null default 'umum' check (waktu in ('pagi','siang','sore','malam','umum')),
  kategori        text not null check (kategori in ('ibadah','kebersihan','pembinaan','kesehatan','kedisiplinan','kejadian','lainnya')),
  uraian          text not null,
  santri_ids      uuid[] not null default '{}',
  foto_id         uuid references public.storage_objects(id) on delete set null,
  penting         boolean not null default false,
  tanggapan       text,
  ditanggapi_oleh uuid references public.employees(id) on delete set null,
  ditanggapi_pada timestamptz,
  dibuat_oleh     uuid references public.employees(id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index if not exists dj_kamar_tgl_idx on public.dorm_journals (group_id, tanggal desc);
drop trigger if exists aa_updated on public.dorm_journals;
create trigger aa_updated before update on public.dorm_journals for each row execute function public.tg_updated_at();
alter table public.dorm_journals enable row level security;
drop policy if exists baca on public.dorm_journals;
create policy baca on public.dorm_journals for select to authenticated using (public.boleh_lihat_kamar(group_id));
grant select on public.dorm_journals to authenticated;

create or replace function public.simpan_jurnal_musyrif(p jsonb)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v_id uuid := nullif(p->>'id', '')::uuid; v_group uuid := nullif(p->>'group_id', '')::uuid; v_tgl date := coalesce(nullif(p->>'tanggal', '')::date, public.hari_ini());
        v dorm_journals%rowtype; v_santri uuid[]; v_nama text; v_penting boolean := coalesce((p->>'penting')::boolean, false);
begin
  if public.saya() is null then raise exception 'Sesi tidak ditemukan. Silakan masuk kembali.' using errcode = '42501'; end if;
  if v_id is not null then
    select * into v from dorm_journals where id = v_id for update;
    if v.id is null then raise exception 'Jurnal tidak ditemukan.'; end if;
    if not (v.dibuat_oleh = public.saya() or public.is_superadmin()) then raise exception 'Hanya penulis jurnal yang dapat mengubahnya.' using errcode = '42501'; end if;
    if v.tanggal < public.hari_ini() - 7 and not public.is_superadmin() then raise exception 'Jurnal lebih dari 7 hari tidak dapat diubah.'; end if;
    v_group := v.group_id;
  end if;
  if not exists (select 1 from student_groups where id = v_group and jenis = 'kamar') then raise exception 'Pilih kamar.'; end if;
  if not (public.saya() in (select public._pengasuh_berlaku(v_group, v_tgl)) or public.is_superadmin()) then
    raise exception 'Hanya musyrif kamar ini yang dapat menulis jurnalnya.' using errcode = '42501';
  end if;
  if v_tgl > public.hari_ini() then raise exception 'Tanggal jurnal tidak boleh setelah hari ini.'; end if;
  if v_tgl < public.hari_ini() - 7 and not public.is_superadmin() then raise exception 'Jurnal paling lama 7 hari ke belakang.'; end if;
  if coalesce(p->>'kategori', '') not in ('ibadah','kebersihan','pembinaan','kesehatan','kedisiplinan','kejadian','lainnya') then raise exception 'Pilih kategori jurnal.'; end if;
  if length(trim(coalesce(p->>'uraian', ''))) < 5 then raise exception 'Tuliskan uraian kegiatan (minimal 5 huruf).'; end if;
  select coalesce(array_agg(x::uuid), '{}') into v_santri from jsonb_array_elements_text(coalesce(p->'santri_ids', '[]')) x
   where x::uuid in (select public._anggota_pada(v_group, v_tgl));
  if v_id is null then
    insert into dorm_journals (group_id, tanggal, waktu, kategori, uraian, santri_ids, foto_id, penting, dibuat_oleh)
    values (v_group, v_tgl, coalesce(nullif(p->>'waktu', ''), 'umum'), p->>'kategori', trim(p->>'uraian'), v_santri,
            nullif(p->>'foto_id', '')::uuid, v_penting, public.saya())
    returning id into v_id;
  else
    update dorm_journals set tanggal = v_tgl, waktu = coalesce(nullif(p->>'waktu', ''), 'umum'), kategori = p->>'kategori', uraian = trim(p->>'uraian'),
           santri_ids = v_santri, foto_id = coalesce(nullif(p->>'foto_id', '')::uuid, foto_id), penting = v_penting where id = v_id;
  end if;
  if v_penting and (v.id is null or not v.penting) then
    select nama into v_nama from student_groups where id = v_group;
    insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
    select x, 'Jurnal musyrif penting: ' || v_nama, left(trim(p->>'uraian'), 140), '/musyrif/jurnal', 'NotePencil', 'jingga'
      from public._pejabat_unit('KESANTRIAN', 30) x where x <> public.saya();
  end if;
  return v_id;
end $$;

create or replace function public.hapus_jurnal_musyrif(p_id uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
declare v dorm_journals%rowtype;
begin
  select * into v from dorm_journals where id = p_id;
  if v.id is null then raise exception 'Jurnal tidak ditemukan.'; end if;
  if not (v.dibuat_oleh = public.saya() and v.tanggal >= public.hari_ini() - 7 or public.is_superadmin()) then
    raise exception 'Hanya penulis (paling lama 7 hari) atau superadmin yang dapat menghapus jurnal.' using errcode = '42501';
  end if;
  delete from dorm_journals where id = p_id;
end $$;

create or replace function public.tanggapi_jurnal_musyrif(p_id uuid, p_tanggapan text)
returns void language plpgsql volatile security definer set search_path = public as $$
declare v dorm_journals%rowtype;
begin
  if not (public.pimpinan_kesantrian() or public.is_superadmin()) then raise exception 'Tanggapan jurnal diberikan pimpinan Kesantrian.' using errcode = '42501'; end if;
  select * into v from dorm_journals where id = p_id for update;
  if v.id is null then raise exception 'Jurnal tidak ditemukan.'; end if;
  update dorm_journals set tanggapan = nullif(trim(p_tanggapan), ''), ditanggapi_oleh = public.saya(), ditanggapi_pada = now() where id = p_id;
  if nullif(trim(p_tanggapan), '') is not null and v.dibuat_oleh is distinct from public.saya() then
    perform public.kirim_notifikasi(v.dibuat_oleh, 'Tanggapan atas jurnal Anda', left(trim(p_tanggapan), 140), '/musyrif/jurnal', 'ChatCircleText', 'biru');
  end if;
end $$;

create or replace function public.daftar_jurnal_musyrif(p_group uuid, p_mulai date, p_selesai date)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if not public.boleh_lihat_kamar(p_group) then raise exception 'Anda tidak berwenang melihat jurnal kamar ini.' using errcode = '42501'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', j.id, 'tanggal', j.tanggal, 'waktu', j.waktu, 'kategori', j.kategori, 'uraian', j.uraian,
      'santri', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'nama', s.nama_lengkap) order by s.nama_lengkap) from students s where s.id = any(j.santri_ids)), '[]'::jsonb),
      'foto_id', j.foto_id, 'penting', j.penting, 'tanggapan', j.tanggapan, 'ditanggapi_oleh', t.nama_lengkap, 'ditanggapi_pada', j.ditanggapi_pada,
      'penulis', e.nama_lengkap, 'dibuat_oleh', j.dibuat_oleh, 'created_at', j.created_at,
      'boleh_ubah', (j.dibuat_oleh = public.saya() and j.tanggal >= public.hari_ini() - 7) or public.is_superadmin())
      order by j.tanggal desc, array_position(array['pagi','siang','sore','malam','umum'], j.waktu), j.created_at)
    from dorm_journals j left join employees e on e.id = j.dibuat_oleh left join employees t on t.id = j.ditanggapi_oleh
   where j.group_id = p_group and j.tanggal between p_mulai and p_selesai), '[]'::jsonb);
end $$;

-- ---------------------------------------------------------------------
-- 2. KLINIK: pengingat kontrol dan rujukan lewat batas
-- ---------------------------------------------------------------------
alter table public.clinic_cases add column if not exists kontrol_diingatkan timestamptz;
alter table public.clinic_cases add column if not exists lewat_dikabari timestamptz;

create or replace function public.tg_klinik_sakit()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'ditangani' and new.tindak_lanjut in ('istirahat','rawat','rujuk','pulang') and new.sakit_sejak is null then
    new.sakit_sejak := now();
  end if;
  if tg_op = 'UPDATE' and new.kontrol_pada is distinct from old.kontrol_pada then new.kontrol_diingatkan := null; end if;
  return new;
end $$;

create or replace function public.klinik_pengingat()
returns int language plpgsql volatile security definer set search_path = public as $$
declare r record; n int := 0;
begin
  -- Jadwal kontrol 30 menit lagi (atau sudah lewat) → petugas klinik terkait
  for r in select c.id, c.klinik, c.kontrol_pada, s.nama_lengkap from clinic_cases c join students s on s.id = c.student_id
            where c.status = 'ditangani' and c.kontrol_pada is not null and c.kontrol_diingatkan is null and c.kontrol_pada <= now() + interval '30 minutes'
  loop
    insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
    select st.employee_id, 'Jadwal kontrol: ' || r.nama_lengkap, 'Kontrol ' || to_char(r.kontrol_pada at time zone 'Asia/Makassar', 'DD/MM HH24.MI') || ' WITA',
           '/klinik/dirawat', 'CalendarCheck', 'merah'
      from clinic_staff st join employees e on e.id = st.employee_id and e.status_akun = 'aktif' where st.klinik = r.klinik and st.aktif;
    update clinic_cases set kontrol_diingatkan = now() where id = r.id; n := n + 1;
  end loop;
  -- Rujukan lewat batas waktu (belum diperiksa) → petugas klinik dan Kepala Bidang Kesantrian, sekali
  for r in select c.id, c.klinik, s.nama_lengkap, c.keluhan from clinic_cases c join students s on s.id = c.student_id
            where c.status = 'menunggu' and c.lewat_dikabari is null
              and (select min(batas_waktu) from clinic_referrals x where x.case_id = c.id) < now()
  loop
    insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
    select distinct x, 'Rujukan lewat batas: ' || r.nama_lengkap, r.keluhan || ' · belum diperiksa', '/klinik/antrean', 'Siren', 'merah'
      from (select st.employee_id x from clinic_staff st join employees e on e.id = st.employee_id and e.status_akun = 'aktif' where st.klinik = r.klinik and st.aktif
            union select public._pejabat_unit('KESANTRIAN', 30)) q;
    update clinic_cases set lewat_dikabari = now() where id = r.id; n := n + 1;
  end loop;
  return n;
end $$;
revoke execute on function public.klinik_pengingat() from public, anon, authenticated;
select cron.unschedule('pengingat-klinik') where exists (select 1 from cron.job where jobname = 'pengingat-klinik');
select cron.schedule('pengingat-klinik', '*/10 * * * *', $$ select public.klinik_pengingat() $$);

-- ---------------------------------------------------------------------
-- 3. SURAT KETERANGAN SAKIT
-- ---------------------------------------------------------------------
insert into public.doc_number_formats (kode, nama, pola, grup_urut, reset)
values ('sks', 'Surat keterangan sakit santri', 'SKS.{URUT3}/{UNIT}/{BLN_ROMAWI}/{THN}', 'sks', 'tahun_masehi')
on conflict (kode) do nothing;

create table if not exists public.clinic_letters (
  id               uuid primary key default gen_random_uuid(),
  case_id          uuid not null references public.clinic_cases(id) on delete cascade,
  nomor            text not null,
  kode_validasi    text not null unique,
  tanggal          date not null,
  istirahat_mulai  date not null,
  istirahat_sampai date not null,
  keperluan        text,
  diagnosis        text,                -- diisi hanya bila petugas memilih mencantumkannya
  dibuat_oleh      uuid references public.employees(id) on delete set null,
  created_at       timestamptz not null default now()
);
create index if not exists cl_case_idx on public.clinic_letters (case_id);
alter table public.clinic_letters enable row level security;
drop policy if exists baca on public.clinic_letters;
create policy baca on public.clinic_letters for select to authenticated
  using (exists (select 1 from clinic_cases c where c.id = case_id and (public.boleh_detail_klinik(c.klinik) or c.student_id in (select public.santri_terlihat()))));
grant select on public.clinic_letters to authenticated;

create or replace function public.buat_surat_sakit(p jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare c clinic_cases%rowtype; v_mulai date := coalesce(nullif(p->>'istirahat_mulai', '')::date, public.hari_ini());
        v_sampai date := coalesce(nullif(p->>'istirahat_sampai', '')::date, public.hari_ini()); v_nomor jsonb; v_kode text; v_id uuid;
        a text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; i int;
begin
  select * into c from clinic_cases where id = nullif(p->>'case_id', '')::uuid;
  if c.id is null then raise exception 'Kasus tidak ditemukan.'; end if;
  if not public.boleh_periksa_klinik(c.klinik) then raise exception 'Surat keterangan sakit dibuat petugas klinik.' using errcode = '42501'; end if;
  if not exists (select 1 from clinic_visits where case_id = c.id) then raise exception 'Santri belum diperiksa.'; end if;
  if v_sampai < v_mulai then raise exception 'Akhir masa istirahat sebelum awalnya.'; end if;
  if v_sampai - v_mulai > 30 then raise exception 'Masa istirahat paling lama 31 hari.'; end if;
  perform set_config('simka.nomor_sistem', '1', true);
  v_nomor := public.ambil_nomor('sks', public.hari_ini(), 'D', null, 'pondok');
  loop
    v_kode := '';
    for i in 1..8 loop v_kode := v_kode || substr(a, 1 + floor(random() * length(a))::int, 1); end loop;
    v_kode := substr(v_kode, 1, 4) || '-' || substr(v_kode, 5, 4);
    exit when not exists (select 1 from clinic_letters where kode_validasi = v_kode);
  end loop;
  insert into clinic_letters (case_id, nomor, kode_validasi, tanggal, istirahat_mulai, istirahat_sampai, keperluan, diagnosis, dibuat_oleh)
  values (c.id, v_nomor->>'nomor', v_kode, public.hari_ini(), v_mulai, v_sampai, nullif(trim(p->>'keperluan'), ''),
          case when coalesce((p->>'cantumkan_diagnosis')::boolean, false) then nullif(trim(p->>'diagnosis'), '') end, public.saya())
  returning id into v_id;
  insert into clinic_followups (case_id, jenis, isi, oleh) values (c.id, 'catatan', 'Surat keterangan sakit ' || (v_nomor->>'nomor'), public.saya());
  return public.surat_sakit(v_id);
end $$;

/** Data lengkap satu surat untuk dicetak. */
create or replace function public.surat_sakit(p_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare l clinic_letters%rowtype; c clinic_cases%rowtype;
begin
  select * into l from clinic_letters where id = p_id; if l.id is null then return null; end if;
  select * into c from clinic_cases where id = l.case_id;
  if not (public.boleh_detail_klinik(c.klinik) or c.student_id in (select public.santri_terlihat())) then
    raise exception 'Anda tidak berwenang melihat surat ini.' using errcode = '42501';
  end if;
  return (select to_jsonb(l) || jsonb_build_object(
      'nama', s.nama_lengkap, 'nis', s.nis, 'jenis_kelamin', s.jenis_kelamin, 'tempat_lahir', s.tempat_lahir, 'tanggal_lahir', s.tanggal_lahir,
      'jenjang', s.jenjang, 'tingkat', s.tingkat, 'kelas', public._kelompok_santri(s.id, 'kelas'), 'kamar', public._kelompok_santri(s.id, 'kamar'),
      'keluhan', c.keluhan, 'klinik', c.klinik, 'tindak_lanjut', c.tindak_lanjut,
      'diperiksa_pada', (select min(v.waktu) from clinic_visits v where v.case_id = c.id),
      'petugas', e.nama_lengkap, 'petugas_niy', e.niy)
    from students s left join employees e on e.id = l.dibuat_oleh where s.id = c.student_id);
end $$;

create or replace function public.daftar_surat_sakit(p_case uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', l.id, 'nomor', l.nomor, 'tanggal', l.tanggal, 'istirahat_mulai', l.istirahat_mulai,
           'istirahat_sampai', l.istirahat_sampai, 'kode_validasi', l.kode_validasi) order by l.created_at desc), '[]'::jsonb)
    from clinic_letters l join clinic_cases c on c.id = l.case_id
   where l.case_id = p_case and (public.boleh_detail_klinik(c.klinik) or c.student_id in (select public.santri_terlihat()))
$$;

-- ---------------------------------------------------------------------
-- 4. TEMPLATE WA, HAK EKSEKUSI
-- ---------------------------------------------------------------------
insert into public.wa_templates (kode, nama, isi, variabel, keterangan) values
  ('santri_sakit', 'Kabar santri sakit ke wali',
   E'{salam}, Bapak/Ibu {nama_wali}.\n\nKami kabarkan ananda *{nama_santri}* ({kelas}) sedang dalam penanganan Klinik pondok.\n• Keluhan: {keluhan}\n• Penanganan: {penanganan}\n• Sejak: {tanggal}\n{keterangan}\n\nMohon doanya agar ananda segera pulih.\n{penutup}\n{pengirim}\n{jabatan_pengirim}',
   '{nama_wali,nama_santri,kelas,keluhan,penanganan,tanggal,keterangan,pengirim}', 'Klinik: kabari orang tua/wali bahwa santri sakit, dirujuk, atau dipulangkan.'),
  ('santri_sembuh', 'Kabar santri sembuh ke wali',
   E'{salam}, Bapak/Ibu {nama_wali}.\n\nAlhamdulillah, ananda *{nama_santri}* ({kelas}) telah dinyatakan sembuh oleh Klinik pondok pada {tanggal} dan kembali mengikuti kegiatan.\n\n{penutup}\n{pengirim}\n{jabatan_pengirim}',
   '{nama_wali,nama_santri,kelas,tanggal,pengirim}', 'Klinik: kabari orang tua/wali bahwa santri sudah sembuh.')
on conflict (kode) do nothing;

do $$
declare f text;
begin
  foreach f in array array['simpan_jurnal_musyrif(jsonb)','hapus_jurnal_musyrif(uuid)','tanggapi_jurnal_musyrif(uuid,text)',
    'daftar_jurnal_musyrif(uuid,date,date)','buat_surat_sakit(jsonb)','surat_sakit(uuid)','daftar_surat_sakit(uuid)']
  loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN — hasil yang benar: 4 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select '1. Jurnal musyrif (tabel + RLS)' as pemeriksaan,
       case when exists (select 1 from pg_tables where schemaname = 'public' and tablename = 'dorm_journals' and rowsecurity) then 'Sesuai' else 'Periksa' end as hasil
union all
select '2. Pengingat klinik terjadwal tiap 10 menit', case when exists (select 1 from cron.job where jobname = 'pengingat-klinik') then 'Sesuai' else 'Periksa' end
union all
select '3. Surat keterangan sakit (tabel + format nomor SKS)', case when exists (select 1 from pg_tables where tablename = 'clinic_letters')
         and exists (select 1 from public.doc_number_formats where kode = 'sks') then 'Sesuai' else 'Periksa' end
union all
select '4. Template WA santri_sakit dan santri_sembuh', case when (select count(*) from public.wa_templates where kode in ('santri_sakit','santri_sembuh')) = 2 then 'Sesuai' else 'Periksa' end;
