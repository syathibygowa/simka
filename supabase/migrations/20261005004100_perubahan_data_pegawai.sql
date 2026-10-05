-- SIMKA PRO | supabase/migrations/20261005004100_perubahan_data_pegawai.sql | v1.0 | Fase 5 – Perbaikan: pegawai memperbarui data kepegawaiannya | 05/10/2026
-- =====================================================================
-- SIMKA PRO · Migrasi 41: Pegawai memperbarui data kepegawaiannya sendiri, diverifikasi-validasi SUPERADMIN saja.
--   * employee_data_requests : satu pengajuan per pengiriman (isian yang berubah saja, nilai lama, alasan, bukti opsional).
--     Satu pegawai hanya punya satu pengajuan "menunggu"; mengajukan lagi = memperbarui pengajuan itu.
--   * Disetujui superadmin → diterapkan lewat simpan_pegawai (riwayat kepegawaian tercatat dengan tanggal berlaku).
--   * Pegawai tidak lagi dapat mengubah kolom data diri secara langsung; yang tetap langsung hanya foto dan tema.
--   * Notifikasi: superadmin saat ada pengajuan; pegawai saat diputuskan.
-- Jalankan SETELAH migrasi 4000. Aman dijalankan ulang.
-- =====================================================================

create table if not exists public.employee_data_requests (
  id               uuid primary key default gen_random_uuid(),
  employee_id      uuid not null references public.employees(id) on delete cascade,
  data             jsonb not null,               -- {kolom: nilai baru}
  lama             jsonb not null default '{}',  -- {kolom: nilai saat diajukan}
  alasan           text,
  bukti_id         text,                          -- id berkas Google Drive (opsional)
  tanggal_berlaku  date,
  status           text not null default 'menunggu' constraint edr_status check (status in ('menunggu','disetujui','ditolak','dibatalkan')),
  catatan_verifikator text,
  diajukan_pada    timestamptz not null default now(),
  diputuskan_oleh  uuid references public.employees(id) on delete set null,
  diputuskan_pada  timestamptz
);
create unique index if not exists edr_menunggu_unik on public.employee_data_requests (employee_id) where status = 'menunggu';
create index if not exists edr_status_idx on public.employee_data_requests (status, diajukan_pada desc);

alter table public.employee_data_requests enable row level security;
drop policy if exists baca on public.employee_data_requests;
create policy baca on public.employee_data_requests for select to authenticated
  using (employee_id = public.saya() or public.is_superadmin());

drop trigger if exists zz_audit on public.employee_data_requests;
create trigger zz_audit after insert or update or delete on public.employee_data_requests for each row execute function public.tg_audit();

-- Pegawai biasa: kolom data diri kini lewat pengajuan; hanya foto dan tema yang langsung
create or replace function public.tg_employees_jaga()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  boleh_pegawai text[] := array['foto_id','tema','updated_at'];
  kolom_sistem text[]  := array['user_id','username','email','wajib_ganti_sandi'];
  k text;
begin
  new.updated_at := now();
  if auth.uid() is null then return new; end if;           -- service role / pg_cron

  if public.is_superadmin() then
    if old.peran = 'superadmin' and new.peran <> 'superadmin' then
      raise exception 'Peran superadmin tidak dapat dicabut dari akun superadmin.';
    end if;
    foreach k in array kolom_sistem loop
      if to_jsonb(new)->k is distinct from to_jsonb(old)->k and k <> 'wajib_ganti_sandi' then
        raise exception 'Kolom % hanya dapat diubah melalui menu kelola akun.', k;
      end if;
    end loop;
    return new;
  end if;

  if public.is_admin() then
    if new.peran is distinct from old.peran then
      raise exception 'Hanya superadmin yang dapat mengubah peran akun.';
    end if;
    if old.peran = 'superadmin' then
      raise exception 'Data superadmin hanya dapat diubah oleh superadmin.';
    end if;
    foreach k in array kolom_sistem loop
      if to_jsonb(new)->k is distinct from to_jsonb(old)->k then
        raise exception 'Kolom % hanya dapat diubah melalui menu kelola akun.', k;
      end if;
    end loop;
    return new;
  end if;

  -- pegawai biasa: hanya foto dan tema; data diri/kepegawaian lewat Profil → Data kepegawaian saya (diverifikasi superadmin)
  for k in select jsonb_object_keys(to_jsonb(new)) loop
    if not (k = any(boleh_pegawai)) and to_jsonb(new)->k is distinct from to_jsonb(old)->k then
      raise exception 'Perubahan % diajukan lewat Profil → Data kepegawaian saya dan diverifikasi superadmin.', k using errcode = '42501';
    end if;
  end loop;
  return new;
end $$;

-- Kolom yang boleh diajukan pegawai
create or replace function public._kolom_ajuan_pegawai()
returns text[] language sql immutable as $$
  select array['nama_lengkap','niy','tempat_lahir','tanggal_lahir','jenis_kelamin','tmt_tugas','status_kepegawaian',
               'kategori_honorer','pendidikan_terakhir','status_keluarga','no_hp','level_muhaffizh']
$$;

-- p: {kolom: nilai baru, ...} (hanya yang berubah). Mengembalikan id pengajuan.
create or replace function public.ajukan_perubahan_pegawai(p jsonb, p_alasan text default null, p_bukti text default null, p_tanggal_berlaku date default null)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v_saya uuid := public.saya(); e employees; v_data jsonb := '{}'; v_lama jsonb := '{}'; k text; v_id uuid;
begin
  if v_saya is null then raise exception 'Sesi masuk tidak berlaku. Silakan masuk ulang.' using errcode = '42501'; end if;
  select * into e from employees where id = v_saya;
  for k in select jsonb_object_keys(p) loop
    if not (k = any(public._kolom_ajuan_pegawai())) then raise exception 'Kolom % tidak dapat diajukan lewat menu ini.', k; end if;
    if (to_jsonb(e)->>k) is distinct from nullif(trim(p->>k), '') then
      v_data := v_data || jsonb_build_object(k, nullif(trim(p->>k), ''));
      v_lama := v_lama || jsonb_build_object(k, to_jsonb(e)->k);
    end if;
  end loop;
  if v_data = '{}'::jsonb then raise exception 'Tidak ada data yang berubah.'; end if;
  if v_data ? 'nama_lengkap' and length(coalesce(v_data->>'nama_lengkap', '')) < 3 then raise exception 'Nama lengkap minimal 3 huruf.'; end if;
  if v_data ? 'no_hp' and coalesce(v_data->>'no_hp', '') !~ '^(\+?62|0)8[0-9]{7,12}$' then raise exception 'Nomor HP tidak valid (contoh 081234567890).'; end if;
  if length(trim(coalesce(p_alasan, ''))) < 5 then raise exception 'Tuliskan alasan/keterangan perubahan (minimal 5 huruf).'; end if;

  select id into v_id from employee_data_requests where employee_id = v_saya and status = 'menunggu' for update;
  if v_id is null then
    insert into employee_data_requests (employee_id, data, lama, alasan, bukti_id, tanggal_berlaku)
    values (v_saya, v_data, v_lama, trim(p_alasan), nullif(p_bukti, ''), p_tanggal_berlaku) returning id into v_id;
  else
    update employee_data_requests set data = v_data, lama = v_lama, alasan = trim(p_alasan), bukti_id = coalesce(nullif(p_bukti, ''), bukti_id),
           tanggal_berlaku = p_tanggal_berlaku, diajukan_pada = now() where id = v_id;
  end if;
  perform public.kirim_notifikasi(s.id, 'Pengajuan perubahan data: ' || e.nama_lengkap,
    (select string_agg(case x when 'nama_lengkap' then 'nama' when 'niy' then 'NIY' when 'tempat_lahir' then 'tempat lahir'
      when 'tanggal_lahir' then 'tanggal lahir' when 'jenis_kelamin' then 'jenis kelamin' when 'tmt_tugas' then 'TMT tugas'
      when 'status_kepegawaian' then 'status kepegawaian' when 'kategori_honorer' then 'kategori honorer'
      when 'pendidikan_terakhir' then 'pendidikan' when 'status_keluarga' then 'status keluarga' when 'no_hp' then 'nomor HP'
      when 'level_muhaffizh' then 'level muhaffizh' else x end, ', ') from jsonb_object_keys(v_data) x) || '. Mohon diverifikasi.', '/verifikasi/perubahan', 'IdentificationCard', 'biru')
    from employees s where s.peran = 'superadmin' and s.status_akun = 'aktif' and s.id <> v_saya;
  return v_id;
end $$;

create or replace function public.batalkan_perubahan_pegawai(p_id uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  update employee_data_requests set status = 'dibatalkan', diputuskan_pada = now()
   where id = p_id and employee_id = public.saya() and status = 'menunggu';
  if not found then raise exception 'Pengajuan tidak ditemukan atau sudah diputuskan.'; end if;
end $$;

-- Superadmin memutuskan. Setuju → diterapkan lewat simpan_pegawai (riwayat kepegawaian tercatat).
-- p_koreksi (opsional): nilai yang dikoreksi superadmin sebelum disetujui.
create or replace function public.putuskan_perubahan_pegawai(p_id uuid, p_setuju boolean, p_catatan text default null, p_koreksi jsonb default null)
returns void language plpgsql volatile security definer set search_path = public as $$
declare r employee_data_requests; e employees; v_data jsonb;
begin
  if not public.is_superadmin() then raise exception 'Perubahan data kepegawaian hanya diverifikasi superadmin.' using errcode = '42501'; end if;
  select * into r from employee_data_requests where id = p_id and status = 'menunggu' for update;
  if not found then raise exception 'Pengajuan tidak ditemukan atau sudah diputuskan.'; end if;
  if not p_setuju and length(trim(coalesce(p_catatan, ''))) < 5 then raise exception 'Tuliskan alasan penolakan (minimal 5 huruf).'; end if;
  select * into e from employees where id = r.employee_id;
  if p_setuju then
    v_data := r.data || coalesce(p_koreksi - array(select k from jsonb_object_keys(coalesce(p_koreksi, '{}')) k where not (k = any(public._kolom_ajuan_pegawai()))), '{}');
    perform public.simpan_pegawai(jsonb_build_object('id', r.employee_id, 'nama_lengkap', coalesce(v_data->>'nama_lengkap', e.nama_lengkap),
      'tanggal_berlaku', coalesce(r.tanggal_berlaku, public.hari_ini())) || (v_data - 'nama_lengkap'));
  end if;
  update employee_data_requests set status = case when p_setuju then 'disetujui' else 'ditolak' end,
         data = coalesce(v_data, data), catatan_verifikator = nullif(trim(p_catatan), ''), diputuskan_oleh = public.saya(), diputuskan_pada = now()
   where id = p_id;
  perform public.kirim_notifikasi(r.employee_id,
    case when p_setuju then 'Perubahan data kepegawaian disetujui' else 'Perubahan data kepegawaian ditolak' end,
    coalesce(nullif(trim(p_catatan), ''), case when p_setuju then 'Data Anda sudah diperbarui.' else '' end), '/profil/data', 'IdentificationCard',
    case when p_setuju then 'hijau' else 'merah' end);
end $$;

create or replace function public.daftar_perubahan_pegawai(p_status text default 'menunggu')
returns table (id uuid, employee_id uuid, nama text, niy text, data jsonb, lama jsonb, alasan text, bukti_id text, tanggal_berlaku date,
               status text, catatan_verifikator text, diajukan_pada timestamptz, diputuskan_oleh text, diputuskan_pada timestamptz)
language sql stable security definer set search_path = public as $$
  select r.id, r.employee_id, e.nama_lengkap, e.niy, r.data, r.lama, r.alasan, r.bukti_id, r.tanggal_berlaku, r.status, r.catatan_verifikator,
         r.diajukan_pada, (select nama_lengkap from employees where id = r.diputuskan_oleh), r.diputuskan_pada
    from employee_data_requests r join employees e on e.id = r.employee_id
   where (public.is_superadmin() or r.employee_id = public.saya())
     and (p_status is null or r.status = p_status)
   order by r.diajukan_pada desc limit 300
$$;

do $$
declare f text;
begin
  foreach f in array array['ajukan_perubahan_pegawai(jsonb,text,text,date)','batalkan_perubahan_pegawai(uuid)',
    'putuskan_perubahan_pegawai(uuid,boolean,text,jsonb)','daftar_perubahan_pegawai(text)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- PEMERIKSAAN — hasil yang benar: 3 baris, semuanya "Sesuai"
select 'Tabel pengajuan perubahan data dengan RLS' as pemeriksaan,
       case when exists (select 1 from pg_tables where schemaname = 'public' and tablename = 'employee_data_requests' and rowsecurity) then 'Sesuai' else 'Periksa' end as hasil
union all
select 'Fungsi pengajuan (4) tersedia',
       case when (select count(distinct proname) from pg_proc where proname in ('ajukan_perubahan_pegawai','batalkan_perubahan_pegawai','putuskan_perubahan_pegawai','daftar_perubahan_pegawai')) = 4 then 'Sesuai' else 'Periksa' end
union all
select 'Penjaga data pegawai diperbarui', case when prosrc like '%Data kepegawaian saya%' then 'Sesuai' else 'Periksa' end from pg_proc where proname = 'tg_employees_jaga';
