-- SIMKA PRO | supabase/migrations/20261004003700_tahun_ajaran.sql | v1.0 | Fase 4 – Tahap 6 Tahun ajaran, statistik, laporan | 05/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 4 · Migrasi 37: Pergantian tahun ajaran, statistik santri, kohort (Blueprint Bagian 16 dan 44)
--   * promotions                : rencana kenaikan per santri untuk tahun ajaran baru (naik, tinggal kelas, lulus)
--   * buat_draf_tahun_ajaran()  : membuat tahun ajaran baru (belum aktif) + rencana kenaikan + salinan kelompok sebagai DRAF
--                                 (kelas dinaikkan otomatis 7A → 8A, 9A → 10A; kamar, halaqah, ekskul, lainnya disalin
--                                 beserta pengasuh dan anggotanya; santri yang lulus tidak ikut)
--   * hapus_draf_tahun_ajaran() : membatalkan draf
--   * aktifkan_tahun_ajaran()   : menerapkan kenaikan dan kelulusan, mengunci tahun ajaran lama (arsip baca saja),
--                                 menonaktifkan akun pelatih ekskul luar yang tidak diperpanjang
--   * statistik_santri()        : angka langsung untuk beranda dan laporan (per jenjang/kelas, kohort angkatan, absensi hari ini)
-- Jalankan SETELAH migrasi 3600. Aman dijalankan ulang.
-- =====================================================================

create table if not exists public.promotions (
  id                uuid primary key default gen_random_uuid(),
  academic_year_id  uuid not null references public.academic_years(id) on delete cascade,   -- tahun ajaran BARU
  student_id        uuid not null references public.students(id) on delete cascade,
  aksi              text not null check (aksi in ('naik','tinggal','lulus')),
  jenjang_lama      text not null, tingkat_lama smallint not null,
  jenjang_baru      text, tingkat_baru smallint,
  diterapkan        boolean not null default false,
  created_at        timestamptz not null default now(),
  unique (academic_year_id, student_id)
);
alter table public.promotions enable row level security;
drop policy if exists baca on public.promotions;
create policy baca on public.promotions for select to authenticated using (student_id in (select public.santri_terlihat()));

create or replace function public.boleh_ganti_ta()
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_superadmin() or (public.admin_boleh('kelola_santri') and public.admin_boleh('kelompok_santri'))
$$;

-- Penambahan anggota pada draf memakai tingkat hasil rencana kenaikan
create or replace function public._masukkan_anggota(p_group uuid, p_santri uuid, p_tanggal date, p_alasan text)
returns text language plpgsql volatile security definer set search_path = public as $$
declare g student_groups; s students; v_lama uuid; v_nama_lama text; pr promotions;
begin
  select * into g from student_groups where id = p_group;
  select * into s from students where id = p_santri;
  if not found then raise exception 'Santri tidak ditemukan.'; end if;
  if s.status not in ('aktif','nonaktif') then raise exception '% berstatus tidak aktif.', s.nama_lengkap; end if;
  if not g.aktif then raise exception 'Kelompok % nonaktif.', g.nama; end if;
  if g.jenis_kelamin is not null and g.jenis_kelamin <> s.jenis_kelamin then
    raise exception '% tidak sesuai: kelompok % khusus %.', s.nama_lengkap, g.nama, case g.jenis_kelamin when 'L' then 'putra' else 'putri' end;
  end if;
  -- Draf tahun ajaran baru: tingkat/status santri mengikuti rencana kenaikan (promotions) yang belum diterapkan
  select * into pr from promotions where academic_year_id = g.academic_year_id and student_id = p_santri and not diterapkan;
  if found then
    if pr.aksi = 'lulus' then raise exception '% direncanakan lulus pada pergantian tahun ajaran ini.', s.nama_lengkap; end if;
    s.tingkat := pr.tingkat_baru; s.jenjang := pr.jenjang_baru;
  end if;
  if g.jenis = 'kelas' and (g.tingkat <> s.tingkat or g.jenjang <> s.jenjang) then
    raise exception '% tercatat kelas % sedangkan % untuk kelas %. Ubah kelas di Data Santri bila perlu.', s.nama_lengkap, s.tingkat, g.nama, g.tingkat;
  end if;
  if exists (select 1 from group_members where group_id = p_group and student_id = p_santri and selesai is null) then return 'sudah'; end if;
  if g.jenis in ('kelas','kamar','halaqah') then
    select m.id, gg.nama into v_lama, v_nama_lama from group_members m join student_groups gg on gg.id = m.group_id
    where m.student_id = p_santri and m.academic_year_id = g.academic_year_id and m.jenis = g.jenis and m.selesai is null;
    if v_lama is not null then
      update group_members set selesai = greatest(mulai, p_tanggal),
        alasan_keluar = 'Pindah ke ' || g.nama || coalesce(': ' || nullif(trim(p_alasan), ''), '')
      where id = v_lama;
      update student_groups set naqib_id = null where naqib_id = p_santri and id <> p_group and jenis = 'halaqah';
    end if;
  end if;
  insert into group_members (group_id, student_id, mulai) values (p_group, p_santri, p_tanggal);
  return case when v_lama is null then 'ditambah' else 'dipindah' end;
end $$;


-- ---------------------------------------------------------------------
-- 1. DRAF TAHUN AJARAN BARU
-- ---------------------------------------------------------------------
-- Usulan bawaan: kelas 7–11 naik, kelas 12 lulus (kelas 9 naik ke kelas 10 SMA di pondok)
create or replace function public.rencana_kenaikan()
returns table (student_id uuid, nis text, nama text, jenis_kelamin text, jenjang text, tingkat smallint, rombel text, status text, usulan text)
language sql stable security definer set search_path = public as $$
  select s.id, s.nis, s.nama_lengkap, s.jenis_kelamin, s.jenjang, s.tingkat,
         (select g.nama from group_members m join student_groups g on g.id = m.group_id join academic_years a on a.id = g.academic_year_id and a.aktif
          where m.student_id = s.id and m.selesai is null and g.jenis = 'kelas' limit 1),
         s.status, case when s.tingkat >= 12 then 'lulus' else 'naik' end
  from students s where s.status in ('aktif','nonaktif') and public.boleh_ganti_ta()
  order by s.tingkat, s.nama_lengkap
$$;

-- p: {nama, mulai, selesai, keputusan: [{student_id, aksi}], salin_kelompok: true}
create or replace function public.buat_draf_tahun_ajaran(p jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare v_lama academic_years; v_baru uuid; k jsonb; s students; v_tb smallint; v_jb text; g student_groups; v_gid uuid;
  v_nama text; n_kel int := 0; n_ang int := 0; n_naik int := 0; n_tinggal int := 0; n_lulus int := 0; m record; r record;
begin
  if not public.boleh_ganti_ta() then raise exception 'Pergantian tahun ajaran hanya untuk superadmin atau admin ber-izin kelola santri dan kelompok santri.' using errcode = '42501'; end if;
  select * into v_lama from academic_years where aktif;
  if v_lama.id is null then raise exception 'Belum ada tahun ajaran aktif.'; end if;
  if trim(p->>'nama') = v_lama.nama then raise exception 'Tahun ajaran baru harus berbeda dari tahun ajaran aktif.'; end if;
  select id into v_baru from academic_years where nama = trim(p->>'nama');
  if v_baru is not null then
    if (select aktif or terkunci from academic_years where id = v_baru) then raise exception 'Tahun ajaran % sudah aktif atau terkunci.', p->>'nama'; end if;
    if exists (select 1 from student_groups where academic_year_id = v_baru) or exists (select 1 from promotions where academic_year_id = v_baru) then
      raise exception 'Draf tahun ajaran % sudah ada. Hapus draf lebih dulu bila ingin membuat ulang.', p->>'nama';
    end if;
    update academic_years set mulai = (p->>'mulai')::date, selesai = (p->>'selesai')::date, semester = 1 where id = v_baru;
  else
    insert into academic_years (nama, mulai, selesai, semester, aktif) values (trim(p->>'nama'), (p->>'mulai')::date, (p->>'selesai')::date, 1, false)
    returning id into v_baru;
  end if;

  -- Rencana kenaikan (santri yang tidak dikirim memakai usulan bawaan)
  for s in select * from students where status in ('aktif','nonaktif') loop
    select x into k from jsonb_array_elements(coalesce(p->'keputusan', '[]')) x where x->>'student_id' = s.id::text limit 1;
    v_nama := coalesce(k->>'aksi', case when s.tingkat >= 12 then 'lulus' else 'naik' end);
    if v_nama = 'naik' and s.tingkat >= 12 then v_nama := 'lulus'; end if;
    v_tb := case v_nama when 'naik' then s.tingkat + 1 when 'tinggal' then s.tingkat end;
    v_jb := case when v_tb is null then null when v_tb >= 10 then 'sma' else 'wustha' end;
    insert into promotions (academic_year_id, student_id, aksi, jenjang_lama, tingkat_lama, jenjang_baru, tingkat_baru)
    values (v_baru, s.id, v_nama, s.jenjang, s.tingkat, v_jb, v_tb);
    if v_nama = 'naik' then n_naik := n_naik + 1; elsif v_nama = 'tinggal' then n_tinggal := n_tinggal + 1; else n_lulus := n_lulus + 1; end if;
  end loop;

  if coalesce((p->>'salin_kelompok')::boolean, true) then
    -- Kelas: rombel naik satu tingkat (angka di depan nama diganti); santri tinggal kelas masuk rombel bernama sama
    for g in select * from student_groups where academic_year_id = v_lama.id and jenis = 'kelas' and aktif order by tingkat, nama loop
      for m in select pr.* from group_members gm join promotions pr on pr.student_id = gm.student_id and pr.academic_year_id = v_baru
               where gm.group_id = g.id and gm.selesai is null and pr.aksi in ('naik','tinggal') loop
        v_nama := case when m.aksi = 'tinggal' then g.nama
                       when g.nama ~ ('^' || g.tingkat || '(\D|$)') then regexp_replace(g.nama, '^' || g.tingkat, (g.tingkat + 1)::text)
                       else g.nama || ' (kelas ' || (g.tingkat + 1) || ')' end;
        select id into v_gid from student_groups where academic_year_id = v_baru and jenis = 'kelas' and nama = v_nama;
        if v_gid is null then
          insert into student_groups (academic_year_id, jenis, nama, jenjang, tingkat, jenis_kelamin, keterangan, urutan)
          values (v_baru, 'kelas', v_nama, m.jenjang_baru, m.tingkat_baru, g.jenis_kelamin, 'Draf dari ' || g.nama || ' ' || v_lama.nama, g.urutan)
          returning id into v_gid;
          n_kel := n_kel + 1;
        end if;
        insert into group_members (group_id, student_id, mulai) values (v_gid, m.student_id, (p->>'mulai')::date) on conflict do nothing;
        n_ang := n_ang + 1; v_gid := null;
      end loop;
    end loop;
    -- Kamar, halaqah, ekskul, lainnya: disalin beserta pengasuh (utama/pendamping), anggota yang tidak lulus, dan jadwal ekskul
    for g in select * from student_groups where academic_year_id = v_lama.id and jenis <> 'kelas' and aktif loop
      insert into student_groups (academic_year_id, jenis, nama, jenjang, tingkat, jenis_kelamin, keterangan, wa_wali, wa_internal, urutan)
      values (v_baru, g.jenis, g.nama, g.jenjang, g.tingkat, g.jenis_kelamin, g.keterangan, g.wa_wali, g.wa_internal, g.urutan)
      returning id into v_gid;
      n_kel := n_kel + 1;
      insert into group_keepers (group_id, employee_id, peran) select v_gid, k2.employee_id, k2.peran from group_keepers k2
        where k2.group_id = g.id and k2.peran in ('utama','pendamping') on conflict do nothing;
      insert into group_members (group_id, student_id, mulai)
      select v_gid, gm.student_id, (p->>'mulai')::date from group_members gm join promotions pr on pr.student_id = gm.student_id and pr.academic_year_id = v_baru
      where gm.group_id = g.id and gm.selesai is null and pr.aksi <> 'lulus' on conflict do nothing;
      get diagnostics v_tb = row_count; n_ang := n_ang + v_tb;
      if g.jenis = 'ekskul' then
        insert into extracurricular_schedules (group_id, hari, jam_mulai, jam_selesai, tempat)
        select v_gid, hari, jam_mulai, jam_selesai, tempat from extracurricular_schedules where group_id = g.id and aktif;
      end if;
    end loop;
  end if;
  perform public.catat_audit('draf_tahun_ajaran', 'academic_years', v_baru::text, 'Draf tahun ajaran ' || trim(p->>'nama'), null);
  return jsonb_build_object('academic_year_id', v_baru, 'naik', n_naik, 'tinggal', n_tinggal, 'lulus', n_lulus, 'kelompok', n_kel, 'keanggotaan', n_ang);
end $$;

create or replace function public.hapus_draf_tahun_ajaran(p_ta uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  if not public.boleh_ganti_ta() then raise exception 'Anda tidak berwenang.' using errcode = '42501'; end if;
  if (select aktif or terkunci from academic_years where id = p_ta) then raise exception 'Tahun ajaran ini sudah aktif atau terkunci; tidak dapat dihapus.'; end if;
  if exists (select 1 from student_attendance_sessions sa join student_groups g on g.id = sa.group_id where g.academic_year_id = p_ta) then
    raise exception 'Draf ini sudah memiliki absensi; tidak dapat dihapus.';
  end if;
  delete from teaching_assignments where academic_year_id = p_ta;
  delete from student_groups where academic_year_id = p_ta;
  delete from promotions where academic_year_id = p_ta;
  delete from academic_years where id = p_ta;
end $$;

-- Ubah keputusan satu santri pada draf: naik / tinggal / lulus
create or replace function public.ubah_rencana_kenaikan(p_ta uuid, p_santri uuid, p_aksi text)
returns void language plpgsql volatile security definer set search_path = public as $$
declare pr promotions;
begin
  if not public.boleh_ganti_ta() then raise exception 'Anda tidak berwenang.' using errcode = '42501'; end if;
  select * into pr from promotions where academic_year_id = p_ta and student_id = p_santri and not diterapkan;
  if not found then raise exception 'Rencana kenaikan tidak ditemukan atau sudah diterapkan.'; end if;
  if p_aksi = 'naik' and pr.tingkat_lama >= 12 then raise exception 'Kelas 12 tidak dapat naik; pilih Lulus atau Tinggal.'; end if;
  update promotions set aksi = p_aksi,
    tingkat_baru = case p_aksi when 'naik' then pr.tingkat_lama + 1 when 'tinggal' then pr.tingkat_lama end,
    jenjang_baru = case when p_aksi = 'lulus' then null when (case p_aksi when 'naik' then pr.tingkat_lama + 1 else pr.tingkat_lama end) >= 10 then 'sma' else 'wustha' end
  where id = pr.id;
  -- Keanggotaan draf yang tidak lagi sesuai dilepas (diatur ulang di Kelompok Santri)
  delete from group_members gm using student_groups g
  where gm.group_id = g.id and g.academic_year_id = p_ta and gm.student_id = p_santri
    and (p_aksi = 'lulus' or (g.jenis = 'kelas' and g.tingkat is distinct from (select tingkat_baru from promotions where id = pr.id)));
end $$;

-- ---------------------------------------------------------------------
-- 2. AKTIFKAN TAHUN AJARAN BARU
-- ---------------------------------------------------------------------
create or replace function public.aktifkan_tahun_ajaran(p_ta uuid)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare v_lama academic_years; v_baru academic_years; pr record; n_naik int := 0; n_lulus int := 0; n_pelatih int := 0;
begin
  if not public.boleh_ganti_ta() then raise exception 'Anda tidak berwenang mengaktifkan tahun ajaran.' using errcode = '42501'; end if;
  select * into v_baru from academic_years where id = p_ta;
  if not found or v_baru.aktif then raise exception 'Tahun ajaran tidak ditemukan atau sudah aktif.'; end if;
  if v_baru.terkunci then raise exception 'Tahun ajaran ini terkunci (arsip).'; end if;
  select * into v_lama from academic_years where aktif;
  -- Terapkan kenaikan dan kelulusan
  for pr in select * from promotions where academic_year_id = p_ta and not diterapkan loop
    if pr.aksi = 'lulus' then
      perform set_config('simka.alasan', 'Lulus' || coalesce(' tahun ajaran ' || v_lama.nama, ''), true);
      update students set status = 'lulus', status_sejak = coalesce(least(v_lama.selesai, public.hari_ini()), public.hari_ini())
      where id = pr.student_id and status in ('aktif','nonaktif');
      n_lulus := n_lulus + 1;
    elsif pr.aksi = 'naik' then
      update students set tingkat = pr.tingkat_baru, jenjang = pr.jenjang_baru where id = pr.student_id;
      n_naik := n_naik + 1;
    end if;
  end loop;
  perform set_config('simka.alasan', '', true);
  update promotions set diterapkan = true where academic_year_id = p_ta;
  if v_lama.id is not null then update academic_years set aktif = false, terkunci = true where id = v_lama.id; end if;
  update academic_years set aktif = true where id = p_ta;
  -- Pelatih ekskul dari luar yang tidak lagi membina ekskul di tahun ajaran baru: akun dinonaktifkan
  update employees e set status_keaktifan = 'nonaktif'
  where e.status_keaktifan = 'aktif'
    and exists (select 1 from employee_functions ef join functional_positions fp on fp.id = ef.functional_position_id where ef.employee_id = e.id and fp.kode = 'PELATIH_EKSKUL')
    and not exists (select 1 from employee_functions ef join functional_positions fp on fp.id = ef.functional_position_id where ef.employee_id = e.id and fp.kode <> 'PELATIH_EKSKUL')
    and not exists (select 1 from employee_structurals es where es.employee_id = e.id)
    and not exists (select 1 from group_keepers k join student_groups g on g.id = k.group_id where k.employee_id = e.id and g.academic_year_id = p_ta and g.jenis = 'ekskul');
  get diagnostics n_pelatih = row_count;
  perform public.sinkron_sesi_ekskul();
  perform public.sinkron_jam_mengajar();
  perform public.catat_audit('aktifkan_tahun_ajaran', 'academic_years', p_ta::text, 'Tahun ajaran ' || v_baru.nama || ' diaktifkan; ' || coalesce(v_lama.nama, '-') || ' dikunci', null);
  return jsonb_build_object('naik', n_naik, 'lulus', n_lulus, 'pelatih_dinonaktifkan', n_pelatih, 'ta_lama', v_lama.nama, 'ta_baru', v_baru.nama);
end $$;

-- ---------------------------------------------------------------------
-- 3. STATISTIK SANTRI (beranda dan laporan; sesuai cakupan pengguna)
-- ---------------------------------------------------------------------
create or replace function public.statistik_santri()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_ids uuid[]; v_tgl date := public.hari_ini(); hasil jsonb;
begin
  select coalesce(array_agg(x), '{}') into v_ids from public.santri_terlihat() x;
  select jsonb_build_object(
    'aktif', count(*) filter (where status = 'aktif'),
    'putra', count(*) filter (where status = 'aktif' and jenis_kelamin = 'L'),
    'putri', count(*) filter (where status = 'aktif' and jenis_kelamin = 'P'),
    'wustha', count(*) filter (where status = 'aktif' and jenjang = 'wustha'),
    'sma', count(*) filter (where status = 'aktif' and jenjang = 'sma'),
    'nonaktif', count(*) filter (where status = 'nonaktif'),
    'lulus', count(*) filter (where status = 'lulus'),
    'keluar', count(*) filter (where status in ('mutasi_keluar','berhenti')),
    'data_kurang', count(*) filter (where status = 'aktif' and (nisn is null or tempat_lahir is null or tanggal_lahir is null)),
    'per_tingkat', coalesce((select jsonb_agg(jsonb_build_object('jenjang', jenjang, 'tingkat', tingkat, 'L', l, 'P', pr) order by tingkat)
                    from (select jenjang, tingkat, count(*) filter (where jenis_kelamin = 'L') l, count(*) filter (where jenis_kelamin = 'P') pr
                          from students where id = any(v_ids) and status = 'aktif' group by jenjang, tingkat) t), '[]'),
    'kohort', coalesce((select jsonb_agg(jsonb_build_object('angkatan', angkatan, 'tahun_masuk', tahun_masuk, 'total', total, 'aktif', aktif,
                          'lulus', lulus, 'keluar', keluar) order by angkatan desc)
                    from (select angkatan, tahun_masuk, count(*) total, count(*) filter (where status in ('aktif','nonaktif')) aktif,
                                 count(*) filter (where status = 'lulus') lulus, count(*) filter (where status in ('mutasi_keluar','berhenti')) keluar
                          from students where id = any(v_ids) group by angkatan, tahun_masuk) k), '[]'),
    'hari_ini', (select jsonb_build_object('sesi', count(*), 'anggota', coalesce(sum(jumlah_anggota), 0), 'hadir', coalesce(sum(jumlah_hadir), 0),
                   'izin', coalesce(sum(jumlah_izin), 0), 'sakit', coalesce(sum(jumlah_sakit), 0), 'absen', coalesce(sum(jumlah_absen), 0))
                 from student_attendance_sessions sa where sa.tanggal = v_tgl and sa.jenis in ('kelas','halaqah','asrama')
                   and (public.is_admin() or sa.group_id in (select id from student_groups))))
  into hasil from students where id = any(v_ids);
  return hasil;
end $$;

do $$
declare f text;
begin
  foreach f in array array['boleh_ganti_ta()','rencana_kenaikan()','buat_draf_tahun_ajaran(jsonb)','hapus_draf_tahun_ajaran(uuid)',
    'ubah_rencana_kenaikan(uuid,uuid,text)','aktifkan_tahun_ajaran(uuid)','statistik_santri()']
  loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  execute 'revoke execute on function public._masukkan_anggota(uuid,uuid,date,text) from public, anon, authenticated';
end $$;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN — hasil yang benar: 4 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select 'Tabel rencana kenaikan (promotions) dengan RLS' as pemeriksaan,
       case when exists (select 1 from pg_tables where tablename = 'promotions' and rowsecurity) then 'Sesuai' else 'Periksa' end as hasil
union all
select 'Fungsi pergantian tahun ajaran (4)',
       case when (select count(distinct proname) from pg_proc where proname in ('buat_draf_tahun_ajaran','hapus_draf_tahun_ajaran','ubah_rencana_kenaikan','aktifkan_tahun_ajaran')) = 4
            then 'Sesuai' else 'Periksa' end
union all
select 'Statistik santri tersedia', case when exists (select 1 from pg_proc where proname = 'statistik_santri') then 'Sesuai' else 'Periksa' end
union all
select 'Migrasi 3600 sudah terpasang', case when exists (select 1 from pg_proc where proname = 'jadwal_mengajar') then 'Sesuai' else 'Periksa: jalankan 3600 dulu' end;
