-- SIMKA PRO | supabase/migrations/20261010005900_kontrol_pimpinan.sql | v1.0 | Fase 8 – Tahap 0b: fungsi kontrol hanya Kepala Bidang ke atas | 10/10/2026
-- =====================================================================
-- Keputusan pemilik proyek (10/10/2026):
--   * Fungsi kontrol (memantau anggota, menyetujui, melihat data unit, statistik) hanya dipegang
--     Kepala Bidang, Direktur, Wakil Direktur, dan Yayasan (termasuk Plt).
--   * Wakil Kepala Bidang dan Wakil Kepala Sekolah tetap jabatan struktural (tunjangan tetap), tetapi
--     tidak memegang fungsi kontrol.
--   * Kepala Unit, Bendahara, dan Tata Usaha diperlakukan sebagai pegawai biasa sesuai tupoksinya.
--     Pengajuan pegawai unit naik ke Kepala Bidang → Direktur/Wakil Direktur → Yayasan.
-- Perubahan:
--   1. unit_pimpinan_saya(): hanya YAYASAN/DIREKTUR/WAKIL_DIREKTUR (semua unit) dan KEPALA_BIDANG
--      (bidangnya beserta cabangnya). Sebelumnya semua jabatan struktural memimpin unitnya.
--   2. calon_penyetuju(): jenjang pertama hanya Kepala Bidang (Kepala Unit tidak lagi menyetujui).
--      Pengajuan yang sedang menunggu Kepala Unit otomatis berpindah ke Kepala Bidang.
--   3. _pejabat_unit(): Bendahara tidak lagi terhitung pejabat unit.
--   4. Validator tahfizh: Kepala Bidang Tahfizh (bukan wakilnya); superadmin dapat memberi hak
--      individu "Tahfizh" tingkat 3 bila wakil perlu ikut memvalidasi.
--   5. boleh_lihat_berkas(), ringkasan_beranda(), profil_tugas_saya(): pimpinan tanpa Kepala Unit
--      dan tanpa jabatan struktural lain.
--   6. Hak fitur bawaan pemantauan (data santri, absensi, jadwal mengajar, pantauan) dicabut dari
--      Wakil Kepala Bidang, Wakil Kepala Sekolah, dan Bendahara. Dapat diberikan lagi per individu
--      di menu Hak Akses bila diperlukan.
-- Jalankan SETELAH migrasi 5800. Aman dijalankan ulang.
-- =====================================================================

-- 1. Unit yang dipimpin
create or replace function public.unit_pimpinan_saya()
returns setof uuid language sql stable security definer set search_path = public as $$
  select u.id from org_units u
  where exists (
    select 1 from employees e
    join employee_structurals es on es.employee_id = e.id
    join structural_positions sp on sp.id = es.structural_position_id
    where e.user_id = auth.uid() and e.status_akun = 'aktif'
      and (sp.kode in ('YAYASAN','DIREKTUR','WAKIL_DIREKTUR')
           or (sp.kode = 'KEPALA_BIDANG' and u.id in (select public.unit_turunan(es.org_unit_id))))
  )
$$;

-- 2. Penyetuju pengajuan: jenjang pertama hanya Kepala Bidang
create or replace function public.calon_penyetuju(p_emp uuid, p_peran text, p_tanggal date default null)
returns table (employee_id uuid, nama text, niy text, jabatan_tertulis text, plt boolean)
language plpgsql stable security definer set search_path = public as $$
declare v_unit uuid; v_atas uuid; v_temu uuid;
begin
  if p_peran = 'kepala_bidang' then
    select org_unit_id into v_unit from employees where id = p_emp;
    -- Telusuri dari unit pemohon ke atas; ambil Kepala Bidang terdekat (Kepala Unit dilewati)
    v_atas := v_unit;
    while v_atas is not null and v_temu is null loop
      if exists (select 1 from public.pemegang_jabatan(p_tanggal) h
                  where h.kode = 'KEPALA_BIDANG' and h.org_unit_id = v_atas and h.employee_id <> p_emp) then
        v_temu := v_atas;
      else
        select parent_id into v_atas from org_units where id = v_atas;
      end if;
    end loop;
    if v_temu is null then return; end if;
    return query
      select distinct on (h.employee_id) h.employee_id, e.nama_lengkap, e.niy,
             case when h.plt then 'Plt. ' else '' end || h.nama_jabatan || ' ' || regexp_replace(u.nama, '^(Bidang|Unit)\s+', '', 'i'), h.plt
        from public.pemegang_jabatan(p_tanggal) h join employees e on e.id = h.employee_id
        join org_units u on u.id = h.org_unit_id
       where h.kode = 'KEPALA_BIDANG' and h.org_unit_id = v_temu and h.employee_id <> p_emp
       order by h.employee_id, h.plt;
  elsif p_peran = 'direktur' then
    return query
      select distinct on (h.employee_id) h.employee_id, e.nama_lengkap, e.niy,
             case when h.plt then 'Plt. ' else '' end || case h.kode when 'DIREKTUR' then 'Direktur' else 'Wakil Direktur' end, h.plt
        from public.pemegang_jabatan(p_tanggal) h join employees e on e.id = h.employee_id
       where h.kode in ('DIREKTUR','WAKIL_DIREKTUR') and h.employee_id <> p_emp
       order by h.employee_id, h.plt;
  elsif p_peran = 'yayasan' then
    return query
      select distinct on (h.employee_id) h.employee_id, e.nama_lengkap, e.niy,
             case when h.plt then 'Plt. ' else '' end || 'Ketua Yayasan', h.plt
        from public.pemegang_jabatan(p_tanggal) h join employees e on e.id = h.employee_id
       where h.kode = 'YAYASAN' and h.employee_id <> p_emp
       order by h.employee_id, h.plt;
  end if;
end $$;

create or replace function public.nama_peran_jenjang(p text)
returns text language sql immutable as $$
  select case p when 'kepala_bidang' then 'Kepala Bidang' when 'direktur' then 'Direktur/Wakil Direktur'
                when 'yayasan' then 'Ketua Yayasan' else p end
$$;

-- 3. Pejabat unit (perizinan santri, lapor, security): tanpa Bendahara dan Tata Usaha
create or replace function public._pejabat_unit(p_kode text, p_maks int default 40)
returns setof uuid language sql stable security definer set search_path = public as $$
  select distinct e.id from employees e
    join employee_structurals es on es.employee_id = e.id
    join structural_positions sp on sp.id = es.structural_position_id and sp.tingkat <= p_maks and sp.kode not in ('BENDAHARA','TATA_USAHA')
    join org_units o on o.id = es.org_unit_id and o.kode = p_kode
   where e.status_akun = 'aktif' and e.status_keaktifan = 'aktif'
  union
  select distinct a.employee_id from acting_assignments a
    join structural_positions sp on sp.id = a.structural_position_id and sp.tingkat <= p_maks and sp.kode not in ('BENDAHARA','TATA_USAHA')
    join org_units o on o.id = a.org_unit_id and o.kode = p_kode
    join employees e on e.id = a.employee_id and e.status_akun = 'aktif'
   where public.hari_ini() between a.mulai and a.sampai
$$;

-- 4. Validator tahfizh
create or replace function public._validator_tahfizh()
returns setof uuid language sql stable security definer set search_path = public as $$
  select e.id from employees e where e.status_akun = 'aktif' and e.status_keaktifan = 'aktif'
     and (e.peran = 'superadmin' or (e.peran = 'admin' and exists (select 1 from admin_permissions p where p.employee_id = e.id and p.kode = 'validasi_tahfizh')))
  union
  select p.employee_id from public.pemegang_jabatan() p join org_units o on o.id = p.org_unit_id
   where o.kode = 'TAHFIZH' and p.kode = 'KEPALA_BIDANG'
$$;

create or replace function public.boleh_validasi_tahfizh()
returns boolean language sql stable security definer set search_path = public as $$
  select public.admin_boleh('validasi_tahfizh') or public.pimpinan_tahfizh() or public.tingkat_fitur('tahfizh') >= 3
$$;

-- 5a. Berkas (foto jurnal pegawai dan sejenisnya): pejabat yang memantau = Kepala Bidang ke atas
do $$
declare d text := pg_get_functiondef('public.boleh_lihat_berkas(uuid,uuid)'::regprocedure);
  lama text := '(sp.tingkat <= 20 or t.org_unit_id in (select public.unit_turunan(es.org_unit_id)))';
  baru text := '(sp.kode in (''YAYASAN'',''DIREKTUR'',''WAKIL_DIREKTUR'') or (sp.kode = ''KEPALA_BIDANG'' and t.org_unit_id in (select public.unit_turunan(es.org_unit_id))))';
begin
  if position(lama in d) > 0 then execute replace(d, lama, baru);
  elsif position(baru in d) = 0 then raise exception 'boleh_lihat_berkas tidak dikenali; hubungi pengembang.'; end if;
end $$;

-- 5b. Beranda pimpinan dan profil tugas: tanpa Kepala Unit
do $$
declare f text; d text;
  lama text := '''DIREKTUR'',''WAKIL_DIREKTUR'',''YAYASAN'',''KEPALA_BIDANG'',''KEPALA_UNIT''';
  baru text := '''DIREKTUR'',''WAKIL_DIREKTUR'',''YAYASAN'',''KEPALA_BIDANG''';
begin
  foreach f in array array['public.ringkasan_beranda()', 'public.profil_tugas_saya()'] loop
    d := pg_get_functiondef(f::regprocedure);
    if position(lama in d) > 0 then execute replace(d, lama, baru); end if;
  end loop;
end $$;

-- 6. Hak fitur bawaan pemantauan dicabut dari wakil dan bendahara
delete from feature_grants g
 using structural_positions sp
 where g.sasaran = 'struktural' and g.sasaran_id = sp.id and g.mode = 'tambah'
   and ((sp.kode in ('WAKIL_KEPALA_BIDANG','WAKIL_KEPALA_SEKOLAH')
          and g.feature_kode in ('data_santri','absensi_kelas','absensi_halaqah','absensi_asrama','absensi_ekskul','jadwal_mengajar','pantauan'))
     or (sp.kode = 'BENDAHARA' and g.feature_kode = 'pantauan'));

do $$ declare f text; begin
  foreach f in array array['unit_pimpinan_saya()','calon_penyetuju(uuid,text,date)','_pejabat_unit(text,integer)','_validator_tahfizh()','boleh_validasi_tahfizh()'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- 7. PEMERIKSAAN (hasil yang benar: semua baris "Sesuai")
select '1. Pimpinan unit hanya Kepala Bidang ke atas' as pemeriksaan,
       case when position('KEPALA_BIDANG' in pg_get_functiondef('public.unit_pimpinan_saya()'::regprocedure)) > 0
             and position('tingkat <= 20' in pg_get_functiondef('public.unit_pimpinan_saya()'::regprocedure)) = 0 then 'Sesuai' else 'Periksa' end as hasil
union all
select '2. Kepala Unit tidak lagi menyetujui pengajuan',
       case when position('KEPALA_UNIT' in pg_get_functiondef('public.calon_penyetuju(uuid,text,date)'::regprocedure)) = 0 then 'Sesuai' else 'Periksa' end
union all
select '3. Beranda pimpinan tanpa Kepala Unit',
       case when position('KEPALA_UNIT' in pg_get_functiondef('public.ringkasan_beranda()'::regprocedure)) = 0
             and position('KEPALA_UNIT' in pg_get_functiondef('public.profil_tugas_saya()'::regprocedure)) = 0 then 'Sesuai' else 'Periksa' end
union all
select '4. Berkas: pemantau Kepala Bidang ke atas',
       case when position('tingkat <= 20' in pg_get_functiondef('public.boleh_lihat_berkas(uuid,uuid)'::regprocedure)) = 0 then 'Sesuai' else 'Periksa' end
union all
select '5. Hak pemantauan wakil dan bendahara dicabut',
       case when not exists (select 1 from feature_grants g join structural_positions sp on sp.id = g.sasaran_id
                              where g.sasaran = 'struktural' and sp.kode in ('WAKIL_KEPALA_BIDANG','WAKIL_KEPALA_SEKOLAH','BENDAHARA')
                                and g.feature_kode in ('data_santri','absensi_kelas','absensi_halaqah','absensi_asrama','absensi_ekskul','jadwal_mengajar','pantauan'))
            then 'Sesuai' else 'Periksa' end;
