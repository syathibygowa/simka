-- SIMKA PRO | supabase/migrations/20261105012800_tahsin.sql | v1.0 | 14.11.0: Tahsin (pembinaan bacaan santri sebelum menghafal) terpadu dengan Tahfizh | 18/10/2026
-- =====================================================================
-- SIMKA PRO · Migrasi 128: Tahsin
--   Santri yang masih tahsin (memperbaiki bacaan; umumnya santri baru atau pindahan) dikelola di menu Tahfizh → tab Tahsin.
--   Alur: muhaffizh/pengelola menandai santri tahsin (tanggal mulai, asal, tahap awal, pembina)
--         → pembina/muhaffizh mencatat perkembangan per pertemuan (tahap, materi, nilai Lancar/Cukup/Perlu diulang, naik tahap)
--         → bila tahapan tuntas, muhaffizh mengajukan lulus tahsin → Kepala Bidang Tahfizh/pengelola meluluskan
--         → santri mulai menghafal (program reguler) dan kembali tampil normal di setoran dan capaian.
--   Terpadu dengan Tahfizh: capaian bulanan santri tahsin berstatus "Tahsin" (bukan "Tidak tercapai"), tidak dihitung
--   sebagai bulan wajib target di rapor, tampil di Rekam Kesantrian, dan diberi penanda di setoran serta Data hafalan.
--   Tahapan tahsin dapat diubah pengelola (pengaturan "tahsin").
-- Jalankan SETELAH migrasi 12700. Aman dijalankan ulang.
-- =====================================================================

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

-- ---------------------------------------------------------------------
-- 1. TABEL DAN PENGATURAN
-- ---------------------------------------------------------------------
create table if not exists public.tahsin_santri (
  id                  uuid primary key default gen_random_uuid(),
  student_id          uuid not null references public.students(id) on delete cascade,
  academic_year_id    uuid references public.academic_years(id) on delete set null,
  mulai               date not null default public.hari_ini(),
  sumber              text not null default 'santri_baru' constraint tahsin_santri_sumber_check
                      check (sumber in ('santri_baru','pindahan','rekomendasi','lainnya')),
  tahap_awal          smallint not null default 1 check (tahap_awal between 1 and 20),
  tahap               smallint not null default 1 check (tahap between 1 and 20),
  pembina_id          uuid references public.employees(id) on delete set null,
  status              text not null default 'berjalan' constraint tahsin_santri_status_check
                      check (status in ('berjalan','lulus','dihentikan')),
  selesai             date,
  catatan             text,
  diajukan_lulus_pada timestamptz,
  diajukan_lulus_oleh uuid references public.employees(id) on delete set null,
  catatan_ajuan       text,
  diputus_oleh        uuid references public.employees(id) on delete set null,
  catatan_selesai     text,
  dicatat_oleh        uuid references public.employees(id) on delete set null,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);
create unique index if not exists tahsin_santri_berjalan_uidx on public.tahsin_santri (student_id) where status = 'berjalan';
create index if not exists tahsin_santri_status_idx on public.tahsin_santri (status, mulai desc);
alter table public.tahsin_santri enable row level security;   -- dibaca dan diubah lewat fungsi

create table if not exists public.tahsin_logs (
  id          uuid primary key default gen_random_uuid(),
  tahsin_id   uuid not null references public.tahsin_santri(id) on delete cascade,
  student_id  uuid not null references public.students(id) on delete cascade,
  tanggal     date not null default public.hari_ini(),
  tahap       smallint not null,
  materi      text,
  nilai       text not null constraint tahsin_logs_nilai_check check (nilai in ('lancar','cukup','perlu_ulang')),
  naik_tahap  boolean not null default false,
  catatan     text,
  oleh        uuid references public.employees(id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint tahsin_logs_satu_hari unique (tahsin_id, tanggal)
);
create index if not exists tahsin_logs_santri_idx on public.tahsin_logs (student_id, tanggal desc);
alter table public.tahsin_logs enable row level security;

insert into public.institution_settings (kunci, nilai) values ('tahsin', jsonb_build_object(
  'tahapan', jsonb_build_array(
    jsonb_build_object('nama', 'Huruf hijaiyah dan makharijul huruf', 'uraian', 'Mengenal dan melafalkan huruf hijaiyah dari tempat keluarnya dengan benar'),
    jsonb_build_object('nama', 'Sifatul huruf', 'uraian', 'Membedakan sifat huruf: hams, jahr, isti''la, istifal, qalqalah, dan lainnya'),
    jsonb_build_object('nama', 'Harakat, tanwin, sukun, dan tasydid', 'uraian', 'Membaca harakat pendek, tanwin, sukun, dan tasydid dengan tepat'),
    jsonb_build_object('nama', 'Hukum nun sukun dan tanwin', 'uraian', 'Izhar, idgham, iqlab, dan ikhfa'),
    jsonb_build_object('nama', 'Hukum mim sukun, ghunnah, dan lam ta''rif', 'uraian', 'Ikhfa syafawi, idgham mimi, izhar syafawi, ghunnah musyaddadah, lam qamariyah dan syamsiyah'),
    jsonb_build_object('nama', 'Hukum mad', 'uraian', 'Mad thabi''i dan mad far''i beserta panjang bacaannya'),
    jsonb_build_object('nama', 'Waqaf dan ibtida''', 'uraian', 'Tanda waqaf, cara berhenti dan memulai bacaan'),
    jsonb_build_object('nama', 'Tilawah lancar', 'uraian', 'Membaca Al-Qur''an dengan tartil dan lancar; siap mulai menghafal')),
  'catatan_lulus', 'Santri lulus tahsin bila seluruh tahapan tuntas dan bacaan dinilai lancar oleh pembina, lalu disahkan Kepala Bidang Tahfizh.'))
on conflict (kunci) do nothing;

-- ---------------------------------------------------------------------
-- 2. HAK
-- ---------------------------------------------------------------------
/** Pengelola tahsin: Kepala Bidang Tahfizh (termasuk Plt), admin validasi/atur tahfizh, tingkat fitur Tahfizh ≥ 3, superadmin. */
create or replace function public.boleh_kelola_tahsin()
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_superadmin() or public.boleh_validasi_tahfizh() or public.boleh_atur_tahfizh()
$$;

/** Membina (mencatat perkembangan, mengajukan lulus): pengelola, pembina yang ditunjuk, atau muhaffizh halaqah santri. */
create or replace function public._boleh_bina_tahsin(p_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.boleh_kelola_tahsin() or exists (select 1 from tahsin_santri t where t.id = p_id
           and (t.pembina_id = public.saya() or public._muhaffizh_santri(t.student_id)))
$$;

create or replace function public._jumlah_tahap_tahsin()
returns int language sql stable security definer set search_path = public as $$
  select greatest(1, coalesce(jsonb_array_length((select nilai->'tahapan' from institution_settings where kunci = 'tahsin')), 8))
$$;

create or replace function public._nama_tahap_tahsin(p_tahap int)
returns text language sql stable security definer set search_path = public as $$
  select coalesce((select nilai->'tahapan'->(p_tahap - 1)->>'nama' from institution_settings where kunci = 'tahsin'), 'Tahap ' || p_tahap)
$$;

/** Santri sedang tahsin pada rentang tanggal (dipakai capaian bulanan dan setoran). */
create or replace function public._tahsin_pada(p_santri uuid, p_mulai date, p_selesai date)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from tahsin_santri t where t.student_id = p_santri and t.status <> 'dihentikan'
                   and t.mulai <= p_selesai and (t.selesai is null or t.selesai > p_mulai))
$$;

-- ---------------------------------------------------------------------
-- 3. PENGATURAN DAN DAFTAR
-- ---------------------------------------------------------------------
create or replace function public.pengaturan_tahsin()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce((select nilai from institution_settings where kunci = 'tahsin'), '{}'::jsonb)
         || jsonb_build_object('boleh_kelola', public.boleh_kelola_tahsin(), 'boleh_atur', public.is_superadmin() or public.boleh_atur_tahfizh() or public.pimpinan_tahfizh())
$$;

create or replace function public.simpan_pengaturan_tahsin(p jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare v_t jsonb := coalesce(p->'tahapan', '[]'::jsonb); v_bersih jsonb;
begin
  if not (public.is_superadmin() or public.boleh_atur_tahfizh() or public.pimpinan_tahfizh()) then
    raise exception 'Tahapan tahsin diatur oleh Kepala Bidang Tahfizh atau pengatur Tahfizh.' using errcode = '42501'; end if;
  select coalesce(jsonb_agg(jsonb_build_object('nama', trim(x->>'nama'), 'uraian', nullif(trim(coalesce(x->>'uraian', '')), '')) order by o), '[]'::jsonb) into v_bersih
    from jsonb_array_elements(v_t) with ordinality as e(x, o) where length(trim(coalesce(x->>'nama', ''))) >= 3;
  if jsonb_array_length(v_bersih) < 2 or jsonb_array_length(v_bersih) > 20 then raise exception 'Tahapan tahsin berisi 2 sampai 20 tahap (nama minimal 3 huruf).'; end if;
  insert into institution_settings (kunci, nilai) values ('tahsin', jsonb_build_object('tahapan', v_bersih, 'catatan_lulus', nullif(trim(coalesce(p->>'catatan_lulus', '')), '')))
  on conflict (kunci) do update set nilai = excluded.nilai;
  -- Tahap santri yang melebihi jumlah tahapan baru disesuaikan
  update tahsin_santri set tahap = least(tahap, jsonb_array_length(v_bersih)), tahap_awal = least(tahap_awal, jsonb_array_length(v_bersih))
   where status = 'berjalan' and tahap > jsonb_array_length(v_bersih);
end $$;

/** Pembina yang dapat dipilih: pengasuh halaqah tahun ajaran aktif dan pegawai bertingkat muhaffizh. */
create or replace function public.pembina_tahsin()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', e.id, 'nama', e.nama_lengkap, 'niy', e.niy) order by e.nama_lengkap), '[]'::jsonb)
    from employees e
   where e.status_keaktifan = 'aktif'
     and (e.level_muhaffizh is not null or exists (select 1 from group_keepers k join student_groups g on g.id = k.group_id and g.jenis = 'halaqah'
            join academic_years a on a.id = g.academic_year_id and a.aktif where k.employee_id = e.id and (k.sampai is null or k.sampai >= public.hari_ini())))
$$;

/** Santri aktif yang dapat ditandai tahsin (belum sedang tahsin). Muhaffizh: santri halaqahnya; pengelola: semua santri terlihat. */
create or replace function public.calon_tahsin()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('student_id', s.id, 'nis', s.nis, 'nama', s.nama_lengkap, 'jenis_kelamin', s.jenis_kelamin,
      'kelas', public._kelompok_santri(s.id, 'kelas'), 'halaqah', public._kelompok_santri(s.id, 'halaqah'), 'jalur_masuk', s.jalur_masuk,
      'tanggal_masuk', s.tanggal_masuk, 'baru', coalesce(s.tanggal_masuk >= public.hari_ini() - 180, false),
      'total_resmi', (select count(*) from juz_achievements j where j.student_id = s.id), 'sabaq_hal', coalesce(t.sabaq_hal, 0),
      'pernah_tahsin', exists (select 1 from tahsin_santri x where x.student_id = s.id and x.status = 'lulus'))
      order by coalesce(s.tanggal_masuk >= public.hari_ini() - 180, false) desc, coalesce(t.sabaq_hal, 0), s.nama_lengkap), '[]'::jsonb)
    from students s left join student_tahfizh t on t.student_id = s.id
   where s.status = 'aktif' and s.id in (select public.santri_terlihat())
     and not exists (select 1 from tahsin_santri x where x.student_id = s.id and x.status = 'berjalan')
     and (public.boleh_kelola_tahsin() or public._muhaffizh_santri(s.id))
$$;

create or replace function public.daftar_tahsin(p_status text default 'berjalan')
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(x order by x->>'halaqah' nulls last, x->>'nama'), '[]'::jsonb) from (
    select jsonb_build_object('id', t.id, 'student_id', s.id, 'nis', s.nis, 'nama', s.nama_lengkap, 'jenis_kelamin', s.jenis_kelamin, 'status_santri', s.status,
      'kelas', public._kelompok_santri(s.id, 'kelas'), 'halaqah', public._kelompok_santri(s.id, 'halaqah'),
      'status', t.status, 'mulai', t.mulai, 'selesai', t.selesai, 'sumber', t.sumber, 'tahap_awal', t.tahap_awal, 'tahap', t.tahap,
      'tahap_nama', public._nama_tahap_tahsin(t.tahap), 'jumlah_tahap', public._jumlah_tahap_tahsin(),
      'lama_hari', coalesce(t.selesai, public.hari_ini()) - t.mulai, 'catatan', t.catatan,
      'pembina_id', t.pembina_id, 'pembina', (select nama_lengkap from employees where id = t.pembina_id),
      'muhaffizh', (select string_agg(distinct e.nama_lengkap, ', ') from group_members m join student_groups g on g.id = m.group_id and g.jenis = 'halaqah'
                     join academic_years a on a.id = g.academic_year_id and a.aktif join group_keepers k on k.group_id = g.id join employees e on e.id = k.employee_id
                    where m.student_id = s.id and m.selesai is null and (k.sampai is null or k.sampai >= public.hari_ini()) and k.peran = 'utama'),
      'wali', (select jsonb_build_object('nama', c.nama, 'hubungan', c.hubungan, 'no_hp', c.no_hp) from student_contacts c
                where c.student_id = s.id order by c.utama desc, array_position(array['ayah','ibu','wali'], c.hubungan) limit 1),
      'pertemuan', (select count(*) from tahsin_logs l where l.tahsin_id = t.id),
      'lancar', (select count(*) from tahsin_logs l where l.tahsin_id = t.id and l.nilai = 'lancar'),
      'terakhir', (select jsonb_build_object('tanggal', l.tanggal, 'tahap', l.tahap, 'materi', l.materi, 'nilai', l.nilai, 'catatan', l.catatan)
                     from tahsin_logs l where l.tahsin_id = t.id order by l.tanggal desc limit 1),
      'diajukan_lulus_pada', t.diajukan_lulus_pada, 'pengaju', (select nama_lengkap from employees where id = t.diajukan_lulus_oleh), 'catatan_ajuan', t.catatan_ajuan,
      'pemutus', (select nama_lengkap from employees where id = t.diputus_oleh), 'catatan_selesai', t.catatan_selesai,
      'dicatat_oleh', (select nama_lengkap from employees where id = t.dicatat_oleh), 'dicatat_pada', t.created_at,
      'boleh_bina', t.status = 'berjalan' and public._boleh_bina_tahsin(t.id),
      'boleh_putus', t.status = 'berjalan' and public.boleh_kelola_tahsin()) x
      from tahsin_santri t join students s on s.id = t.student_id
     where (p_status is null or t.status = p_status or (p_status = 'menunggu' and t.status = 'berjalan' and t.diajukan_lulus_pada is not null))
       and (t.status <> 'berjalan' or s.status = 'aktif')
       and (public.boleh_kelola_tahsin() or t.pembina_id = public.saya() or s.id in (select public.santri_terlihat()))
       and (t.status = 'berjalan' or coalesce(t.selesai, t.mulai) > public.hari_ini() - 730)) q
$$;

create or replace function public.riwayat_tahsin(p_id uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', l.id, 'tanggal', l.tanggal, 'tahap', l.tahap, 'tahap_nama', public._nama_tahap_tahsin(l.tahap),
      'materi', l.materi, 'nilai', l.nilai, 'naik_tahap', l.naik_tahap, 'catatan', l.catatan, 'oleh', (select nama_lengkap from employees where id = l.oleh))
      order by l.tanggal desc), '[]'::jsonb)
    from tahsin_logs l join tahsin_santri t on t.id = l.tahsin_id
   where l.tahsin_id = p_id
     and (public.boleh_kelola_tahsin() or t.pembina_id = public.saya() or t.student_id in (select public.santri_terlihat()))
$$;

-- ---------------------------------------------------------------------
-- 4. PENCATATAN
-- ---------------------------------------------------------------------
/** Tandai santri tahsin. p: { mulai, sumber, tahap, pembina_id, catatan }. Mengembalikan jumlah santri yang ditandai. */
create or replace function public.tandai_tahsin(p_santri uuid[], p jsonb default '{}'::jsonb)
returns int language plpgsql security definer set search_path = public as $$
declare v_saya uuid := public.saya(); v_id uuid; s students; v_n int := 0; v_mulai date := coalesce(nullif(p->>'mulai', '')::date, public.hari_ini());
  v_tahap int := greatest(1, coalesce(nullif(p->>'tahap', '')::int, 1)); v_pembina uuid := nullif(p->>'pembina_id', '')::uuid;
  v_sumber text := coalesce(nullif(p->>'sumber', ''), 'santri_baru');
begin
  if v_saya is null then raise exception 'Akun Anda belum aktif.' using errcode = '42501'; end if;
  if coalesce(array_length(p_santri, 1), 0) = 0 then raise exception 'Pilih santri yang akan ditandai tahsin.'; end if;
  if v_mulai > public.hari_ini() then raise exception 'Tanggal mulai tahsin tidak boleh melewati hari ini.'; end if;
  if v_tahap > public._jumlah_tahap_tahsin() then raise exception 'Tahap awal melebihi jumlah tahapan tahsin.'; end if;
  if v_sumber not in ('santri_baru','pindahan','rekomendasi','lainnya') then raise exception 'Asal santri tahsin tidak dikenal.'; end if;
  foreach v_id in array p_santri loop
    select * into s from students where id = v_id;
    if s.id is null or s.status <> 'aktif' then raise exception 'Santri tidak ditemukan atau tidak aktif.'; end if;
    if not (public.boleh_kelola_tahsin() or public._muhaffizh_santri(s.id)) then
      raise exception 'Santri tahsin ditandai oleh muhaffizh halaqahnya atau pengelola Tahfizh (%).', s.nama_lengkap using errcode = '42501'; end if;
    if exists (select 1 from tahsin_santri where student_id = s.id and status = 'berjalan') then continue; end if;
    insert into tahsin_santri (student_id, academic_year_id, mulai, sumber, tahap_awal, tahap, pembina_id, catatan, dicatat_oleh)
    values (s.id, (select id from academic_years where aktif), greatest(v_mulai, coalesce(s.tanggal_masuk, v_mulai)), v_sumber, v_tahap, v_tahap,
            coalesce(v_pembina, (select k.employee_id from group_members m join student_groups g on g.id = m.group_id and g.jenis = 'halaqah'
                                   join academic_years a on a.id = g.academic_year_id and a.aktif join group_keepers k on k.group_id = g.id
                                  where m.student_id = s.id and m.selesai is null and (k.sampai is null or k.sampai >= public.hari_ini())
                                  order by array_position(array['utama','pendamping','pengganti'], k.peran) limit 1)),
            nullif(trim(coalesce(p->>'catatan', '')), ''), v_saya);
    v_n := v_n + 1;
  end loop;
  if v_pembina is not null and v_pembina is distinct from v_saya and v_n > 0 then
    perform public.kirim_notifikasi(v_pembina, 'Santri tahsin baru', v_n || ' santri ditetapkan dalam pembinaan tahsin Anda.', '/tahfizh/tahsin', 'UserSound', 'teal');
  end if;
  return v_n;
end $$;

/** Catat perkembangan tahsin satu pertemuan untuk beberapa santri.
    p_isi: [{ id (tahsin), materi, nilai lancar|cukup|perlu_ulang, naik (naik ke tahap berikutnya), catatan }]. Satu catatan per santri per tanggal (menimpa). */
create or replace function public.catat_tahsin(p_tanggal date, p_isi jsonb)
returns int language plpgsql security definer set search_path = public as $$
declare v_saya uuid := public.saya(); x jsonb; t tahsin_santri; v_n int := 0; v_tgl date := coalesce(p_tanggal, public.hari_ini());
  v_tahap int; v_maks int := public._jumlah_tahap_tahsin(); v_nilai text;
begin
  if v_saya is null then raise exception 'Akun Anda belum aktif.' using errcode = '42501'; end if;
  if v_tgl > public.hari_ini() then raise exception 'Tanggal pertemuan tidak boleh melewati hari ini.'; end if;
  for x in select * from jsonb_array_elements(coalesce(p_isi, '[]'::jsonb)) loop
    v_nilai := nullif(x->>'nilai', '');
    if v_nilai is null then continue; end if;
    if v_nilai not in ('lancar','cukup','perlu_ulang') then raise exception 'Nilai tahsin harus Lancar, Cukup, atau Perlu diulang.'; end if;
    select * into t from tahsin_santri where id = (x->>'id')::uuid for update;
    if t.id is null or t.status <> 'berjalan' then raise exception 'Data tahsin tidak ditemukan atau sudah selesai.'; end if;
    if not public._boleh_bina_tahsin(t.id) then raise exception 'Perkembangan tahsin dicatat oleh pembina atau muhaffizh santri.' using errcode = '42501'; end if;
    if v_tgl < t.mulai then raise exception 'Tanggal pertemuan sebelum tanggal mulai tahsin.'; end if;
    v_tahap := coalesce((select tahap from tahsin_logs where tahsin_id = t.id and tanggal = v_tgl), t.tahap);
    insert into tahsin_logs (tahsin_id, student_id, tanggal, tahap, materi, nilai, naik_tahap, catatan, oleh)
    values (t.id, t.student_id, v_tgl, v_tahap, nullif(trim(coalesce(x->>'materi', '')), ''), v_nilai,
            coalesce((x->>'naik')::boolean, false) and v_nilai = 'lancar', nullif(trim(coalesce(x->>'catatan', '')), ''), v_saya)
    on conflict (tahsin_id, tanggal) do update set materi = excluded.materi, nilai = excluded.nilai, naik_tahap = excluded.naik_tahap,
       catatan = excluded.catatan, oleh = excluded.oleh, updated_at = now();
    -- Tahap berjalan = tahap tertinggi yang dinyatakan naik + 1 (tidak kurang dari tahap awal, tidak lebih dari jumlah tahapan)
    update tahsin_santri set tahap = least(v_maks, greatest(tahap_awal, coalesce((select max(l.tahap) + 1 from tahsin_logs l where l.tahsin_id = t.id and l.naik_tahap), tahap_awal))),
           updated_at = now()
     where id = t.id;
    v_n := v_n + 1;
  end loop;
  return v_n;
end $$;

create or replace function public.hapus_catatan_tahsin(p_log uuid)
returns void language plpgsql security definer set search_path = public as $$
declare l tahsin_logs; v_maks int := public._jumlah_tahap_tahsin();
begin
  select * into l from tahsin_logs where id = p_log;
  if l.id is null then raise exception 'Catatan tidak ditemukan.'; end if;
  if not (public.boleh_kelola_tahsin() or (l.oleh = public.saya() and public._boleh_bina_tahsin(l.tahsin_id))) then
    raise exception 'Catatan tahsin dihapus oleh pencatatnya atau pengelola Tahfizh.' using errcode = '42501'; end if;
  if (select status from tahsin_santri where id = l.tahsin_id) <> 'berjalan' then raise exception 'Tahsin santri sudah selesai; catatan tidak dapat dihapus.'; end if;
  delete from tahsin_logs where id = p_log;
  update tahsin_santri set tahap = least(v_maks, greatest(tahap_awal, coalesce((select max(x.tahap) + 1 from tahsin_logs x where x.tahsin_id = l.tahsin_id and x.naik_tahap), tahap_awal))),
         updated_at = now() where id = l.tahsin_id;
end $$;

/** Ubah pembina, tahap, atau catatan. p: { pembina_id, tahap, catatan } */
create or replace function public.ubah_tahsin(p_id uuid, p jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare t tahsin_santri; v_tahap int; v_pembina uuid;
begin
  select * into t from tahsin_santri where id = p_id for update;
  if t.id is null or t.status <> 'berjalan' then raise exception 'Data tahsin tidak ditemukan atau sudah selesai.'; end if;
  if not public._boleh_bina_tahsin(p_id) then raise exception 'Data tahsin diubah oleh pembina, muhaffizh, atau pengelola.' using errcode = '42501'; end if;
  v_tahap := coalesce(nullif(p->>'tahap', '')::int, t.tahap);
  if v_tahap < 1 or v_tahap > public._jumlah_tahap_tahsin() then raise exception 'Tahap di luar daftar tahapan tahsin.'; end if;
  v_pembina := case when p ? 'pembina_id' then nullif(p->>'pembina_id', '')::uuid else t.pembina_id end;
  update tahsin_santri set tahap = v_tahap, tahap_awal = least(tahap_awal, v_tahap), pembina_id = v_pembina,
         catatan = case when p ? 'catatan' then nullif(trim(coalesce(p->>'catatan', '')), '') else catatan end, updated_at = now()
   where id = p_id;
  if v_pembina is not null and v_pembina is distinct from t.pembina_id and v_pembina is distinct from public.saya() then
    perform public.kirim_notifikasi(v_pembina, 'Santri tahsin baru', (select nama_lengkap from students where id = t.student_id) || ' kini dalam pembinaan tahsin Anda.',
                                    '/tahfizh/tahsin', 'UserSound', 'teal');
  end if;
end $$;

/** Pembina/muhaffizh mengajukan lulus tahsin kepada Kepala Bidang Tahfizh. */
create or replace function public.ajukan_lulus_tahsin(p_id uuid, p_catatan text default null)
returns void language plpgsql security definer set search_path = public as $$
declare t tahsin_santri; v_saya uuid := public.saya(); v_nama text;
begin
  select * into t from tahsin_santri where id = p_id for update;
  if t.id is null or t.status <> 'berjalan' then raise exception 'Data tahsin tidak ditemukan atau sudah selesai.'; end if;
  if not public._boleh_bina_tahsin(p_id) then raise exception 'Lulus tahsin diajukan oleh pembina atau muhaffizh santri.' using errcode = '42501'; end if;
  if not exists (select 1 from tahsin_logs where tahsin_id = p_id) then raise exception 'Catat perkembangan tahsin sedikitnya satu kali sebelum mengajukan lulus.'; end if;
  update tahsin_santri set diajukan_lulus_pada = now(), diajukan_lulus_oleh = v_saya, catatan_ajuan = nullif(trim(coalesce(p_catatan, '')), ''), updated_at = now() where id = p_id;
  select nama_lengkap into v_nama from students where id = t.student_id;
  perform public.kirim_notifikasi(e, 'Pengajuan lulus tahsin: ' || v_nama, 'Tahap ' || t.tahap || ' dari ' || public._jumlah_tahap_tahsin() || '. Mohon diputuskan.',
                                  '/tahfizh/tahsin', 'UserSound', 'teal')
    from public._validator_tahfizh() e where e is distinct from v_saya;
end $$;

/** Pengelola meluluskan (santri mulai menghafal) atau mengembalikan pengajuan. */
create or replace function public.putuskan_tahsin(p_id uuid, p_lulus boolean, p_catatan text default null)
returns void language plpgsql security definer set search_path = public as $$
declare t tahsin_santri; v_saya uuid := public.saya(); v_nama text; v_tuju uuid;
begin
  if not public.boleh_kelola_tahsin() then raise exception 'Lulus tahsin disahkan oleh Kepala Bidang Tahfizh atau pengelola Tahfizh.' using errcode = '42501'; end if;
  select * into t from tahsin_santri where id = p_id for update;
  if t.id is null or t.status <> 'berjalan' then raise exception 'Data tahsin tidak ditemukan atau sudah selesai.'; end if;
  select nama_lengkap into v_nama from students where id = t.student_id;
  if p_lulus then
    update tahsin_santri set status = 'lulus', selesai = public.hari_ini(), tahap = public._jumlah_tahap_tahsin(), diputus_oleh = v_saya,
           catatan_selesai = nullif(trim(coalesce(p_catatan, '')), ''), updated_at = now() where id = p_id;
    insert into student_tahfizh (student_id) values (t.student_id) on conflict (student_id) do nothing;
  else
    if length(trim(coalesce(p_catatan, ''))) < 5 then raise exception 'Tuliskan catatan perbaikan (minimal 5 huruf).'; end if;
    update tahsin_santri set diajukan_lulus_pada = null, diajukan_lulus_oleh = null,
           catatan_ajuan = 'Belum lulus: ' || trim(p_catatan), updated_at = now() where id = p_id;
  end if;
  for v_tuju in select distinct u from unnest(array[t.pembina_id, t.diajukan_lulus_oleh]) u where u is not null and u is distinct from v_saya loop
    perform public.kirim_notifikasi(v_tuju, case when p_lulus then 'Lulus tahsin: ' || v_nama else 'Tahsin dilanjutkan: ' || v_nama end,
      case when p_lulus then 'Santri mulai menghafal. Catat setoran sabaq pada halaqahnya.' else trim(p_catatan) end,
      case when p_lulus then '/tahfizh/setoran' else '/tahfizh/tahsin' end, case when p_lulus then 'SealCheck' else 'ArrowCounterClockwise' end,
      case when p_lulus then 'hijau' else 'jingga' end);
  end loop;
end $$;

/** Hentikan (salah tanda, santri pindah halaqah ke program lain, dsb.). */
create or replace function public.hentikan_tahsin(p_id uuid, p_alasan text)
returns void language plpgsql security definer set search_path = public as $$
declare t tahsin_santri;
begin
  select * into t from tahsin_santri where id = p_id for update;
  if t.id is null or t.status <> 'berjalan' then raise exception 'Data tahsin tidak ditemukan atau sudah selesai.'; end if;
  if not (public.boleh_kelola_tahsin() or (public._boleh_bina_tahsin(p_id) and t.dicatat_oleh = public.saya())) then
    raise exception 'Tahsin dihentikan oleh pengelola Tahfizh atau penandanya.' using errcode = '42501'; end if;
  if length(trim(coalesce(p_alasan, ''))) < 5 then raise exception 'Tuliskan alasan penghentian (minimal 5 huruf).'; end if;
  if not exists (select 1 from tahsin_logs where tahsin_id = p_id) and t.mulai >= public.hari_ini() - 7 then
    delete from tahsin_santri where id = p_id;   -- salah tanda tanpa catatan: hapus saja
  else
    update tahsin_santri set status = 'dihentikan', selesai = public.hari_ini(), catatan_selesai = trim(p_alasan), diputus_oleh = public.saya(), updated_at = now() where id = p_id;
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 5. TERPADU DENGAN TAHFIZH
-- ---------------------------------------------------------------------
-- 5a. Capaian bulanan: santri yang tahsin pada bulan itu berstatus "tahsin" (kecuali target tetap tercapai)
alter table public.monthly_achievements drop constraint if exists monthly_status;
alter table public.monthly_achievements add constraint monthly_status
  check (status in ('tercapai','tidak_tercapai','murojaah','khatam','tidak_terdata','tahsin'));

select pg_temp.tambal('capaian_bulanan',
  'ma.posisi_awal_hal, ma.posisi_akhir_hal, ma.tambah_hal as tambah_beku, ma.target_hal as target_beku, ma.pekan_efektif as pekan_beku',
  'ma.posisi_awal_hal, ma.posisi_akhir_hal, ma.tambah_hal as tambah_beku, ma.target_hal as target_beku, ma.pekan_efektif as pekan_beku,
           public._tahsin_pada(s.id, v_b, v_akhir) as tahsin',
  'public._tahsin_pada(s.id, v_b, v_akhir) as tahsin');
select pg_temp.tambal('capaian_bulanan',
  'when d.sesi = 0 then ''tidak_terdata''',
  'when d.tahsin and d.akhir - d.awal < d.target then ''tahsin''
              when d.sesi = 0 then ''tidak_terdata''',
  'when d.tahsin and d.akhir - d.awal < d.target then ''tahsin''');

-- 5b. Rapor tahfizh: bulan tahsin tidak dihitung sebagai bulan wajib target
select pg_temp.tambal('bahan_rapor_halaqah', 'ma.status <> ''tidak_terdata''', 'ma.status not in (''tidak_terdata'',''tahsin'')', 'ma.status not in (''tidak_terdata'',''tahsin'')');

-- 5c. Rekam Kesantrian: riwayat tahsin pada bagian hafalan
select pg_temp.tambal('rekam_kesantrian',
  '''halaqah'', (select nama from student_groups where id = v_hq),',
  '''halaqah'', (select nama from student_groups where id = v_hq),
        ''tahsin'', coalesce((select jsonb_agg(jsonb_build_object(''status'', ts.status, ''mulai'', ts.mulai, ''selesai'', ts.selesai, ''sumber'', ts.sumber,
                           ''tahap'', ts.tahap, ''tahap_nama'', public._nama_tahap_tahsin(ts.tahap), ''jumlah_tahap'', public._jumlah_tahap_tahsin(),
                           ''pembina'', (select e.nama_lengkap from employees e where e.id = ts.pembina_id),
                           ''pertemuan'', (select count(*) from tahsin_logs l where l.tahsin_id = ts.id),
                           ''lancar'', (select count(*) from tahsin_logs l where l.tahsin_id = ts.id and l.nilai = ''lancar''),
                           ''catatan_selesai'', ts.catatan_selesai) order by ts.mulai desc)
                           from tahsin_santri ts where ts.student_id = s.id and ts.status <> ''dihentikan''), ''[]''::jsonb),',
  '''tahsin'', coalesce((select jsonb_agg(');

-- 5d. Penanda santri tahsin untuk setoran dan Data hafalan (dibaca tampilan)
create or replace function public.santri_tahsin_aktif()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_object_agg(t.student_id, jsonb_build_object('id', t.id, 'tahap', t.tahap, 'tahap_nama', public._nama_tahap_tahsin(t.tahap),
                                   'jumlah_tahap', public._jumlah_tahap_tahsin(), 'mulai', t.mulai)), '{}'::jsonb)
    from tahsin_santri t join students s on s.id = t.student_id and s.status = 'aktif'
   where t.status = 'berjalan' and (public.boleh_kelola_tahsin() or t.pembina_id = public.saya() or s.id in (select public.santri_terlihat()))
$$;

-- ---------------------------------------------------------------------
-- 6. TEMPLATE WHATSAPP
-- ---------------------------------------------------------------------
insert into public.wa_templates (kode, nama, isi, variabel, keterangan) values
  ('tahsin_perkembangan_wali', 'Perkembangan tahsin ke orang tua/wali',
   E'{salam}, Bapak/Ibu {nama_wali}.\n\nKami sampaikan perkembangan *tahsin* (perbaikan bacaan Al-Qur''an) ananda *{nama_santri}* ({kelas}):\n• Tahap: {tahap}\n• Pertemuan: {pertemuan}\n• Catatan terakhir: {catatan}\n\nMohon doa dan dukungan Bapak/Ibu agar ananda segera lancar membaca dan mulai menghafal.\n\n{penutup}\n{pengirim}\n{jabatan_pengirim}',
   '{nama_wali,nama_santri,kelas,tahap,pertemuan,catatan}', 'Tombol "WA orang tua" di Tahfizh → Tahsin.'),
  ('tahsin_lulus_wali', 'Lulus tahsin ke orang tua/wali',
   E'{salam}, Bapak/Ibu {nama_wali}.\n\nAlhamdulillah, ananda *{nama_santri}* ({kelas}) telah *lulus tahsin* dan insya Allah mulai menghafal Al-Qur''an bersama halaqah {halaqah}.\n\nSemoga Allah memudahkan ananda menjadi penghafal Al-Qur''an. Mohon terus doakan dan motivasi ananda.\n\n{penutup}\n{pengirim}\n{jabatan_pengirim}',
   '{nama_wali,nama_santri,kelas,halaqah}', 'Tombol "WA orang tua" setelah santri lulus tahsin.')
on conflict (kode) do nothing;

do $$ declare f text; begin
  foreach f in array array['boleh_kelola_tahsin()','pengaturan_tahsin()','simpan_pengaturan_tahsin(jsonb)','pembina_tahsin()','calon_tahsin()','daftar_tahsin(text)',
                           'riwayat_tahsin(uuid)','tandai_tahsin(uuid[],jsonb)','catat_tahsin(date,jsonb)','hapus_catatan_tahsin(uuid)','ubah_tahsin(uuid,jsonb)',
                           'ajukan_lulus_tahsin(uuid,text)','putuskan_tahsin(uuid,boolean,text)','hentikan_tahsin(uuid,text)','santri_tahsin_aktif()'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  foreach f in array array['_boleh_bina_tahsin(uuid)','_jumlah_tahap_tahsin()','_nama_tahap_tahsin(integer)','_tahsin_pada(uuid,date,date)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN — hasil yang benar: 4 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select '1. Tabel tahsin dan tahapan tersedia' as pemeriksaan,
       case when to_regclass('public.tahsin_santri') is not null and to_regclass('public.tahsin_logs') is not null
             and public._jumlah_tahap_tahsin() >= 2 then 'Sesuai' else 'Periksa' end as hasil
union all
select '2. Capaian bulanan mengenal status Tahsin',
       case when position('d.tahsin' in pg_get_functiondef('public.capaian_bulanan(date,uuid)'::regprocedure)) > 0
             and position('''tahsin''' in pg_get_constraintdef((select oid from pg_constraint where conname = 'monthly_status'))) > 0 then 'Sesuai' else 'Periksa' end
union all
select '3. Rapor dan Rekam Kesantrian memuat tahsin',
       case when (select count(*) from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname in ('bahan_rapor_halaqah','rekam_kesantrian')
                   and pg_get_functiondef(p.oid) like '%tahsin%') = 2 then 'Sesuai' else 'Periksa' end
union all
select '4. Fungsi tahsin dan template WA',
       case when (select count(*) from pg_proc where pronamespace = 'public'::regnamespace and proname in ('tandai_tahsin','catat_tahsin','ajukan_lulus_tahsin',
                   'putuskan_tahsin','hentikan_tahsin','daftar_tahsin','santri_tahsin_aktif')) = 7
             and (select count(*) from public.wa_templates where kode in ('tahsin_perkembangan_wali','tahsin_lulus_wali')) = 2 then 'Sesuai' else 'Periksa' end;
