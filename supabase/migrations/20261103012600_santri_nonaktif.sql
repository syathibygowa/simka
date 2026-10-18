-- SIMKA PRO | supabase/migrations/20261103012600_santri_nonaktif.sql | v1.0 | 14.9.3: santri nonaktif/mutasi/lulus/berhenti tidak lagi tampil di daftar kerja | 18/10/2026
-- =====================================================================
-- SIMKA PRO · Migrasi 126: Santri yang tidak aktif keluar dari semua daftar kerja
--   Sebelumnya santri "Nonaktif sementara" tetap tercatat sebagai anggota kelas/kamar/halaqah/ekskul sehingga masih tampil di
--   Data hafalan, setoran, absensi, nilai, rapor, dan laporan. Sekarang:
--   * Status menjadi Nonaktif → keanggotaan kelompok ditutup per tanggal status (alasan "Nonaktif sementara"), seperti
--     Lulus/Berhenti/Mutasi. Sesi absensi dan setoran sesudah tanggal itu tidak lagi memuat santri tersebut.
--   * Status kembali Aktif → kelompok yang ditutup karena nonaktif dibuka kembali otomatis mulai tanggal aktif
--     (hanya kelompok tahun ajaran aktif yang masih aktif dan tidak bentrok).
--   * Daftar kerja (Data hafalan, capaian bulanan, setoran, nilai, ekskul, bahan rapor, laporan kehadiran, statistik santri aktif)
--     hanya memuat santri berstatus Aktif. Rapor tetap dapat dicetak untuk santri Lulus.
--   * Tidak diubah: Data Santri (semua status dengan saringan), riwayat/rekam, persuratan (SKL, surat pindah), keuangan
--     (tagihan tetap tercatat), pergantian tahun ajaran, dan rencana kenaikan kelas.
-- Jalankan SETELAH migrasi 12500. Aman dijalankan ulang.
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
-- 1. Keanggotaan kelompok mengikuti status santri
-- ---------------------------------------------------------------------
create or replace function public.tg_students_tutup_kelompok()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if old.status is not distinct from new.status then return new; end if;
  if new.status in ('mutasi_keluar','lulus','berhenti','nonaktif') then
    update group_members set selesai = greatest(mulai, new.status_sejak),
      alasan_keluar = case new.status when 'mutasi_keluar' then 'Mutasi keluar' when 'lulus' then 'Lulus'
                                      when 'nonaktif' then 'Nonaktif sementara' else 'Berhenti' end
    where student_id = new.id and selesai is null;
  elsif new.status = 'aktif' and old.status = 'nonaktif' then
    -- Pulihkan kelompok yang ditutup saat nonaktif (penutupan terakhir), bila kelompoknya masih berjalan
    insert into group_members (group_id, student_id, jenis, academic_year_id, mulai)
    select m.group_id, m.student_id, m.jenis, m.academic_year_id, greatest(new.status_sejak, m.selesai)
      from group_members m join student_groups g on g.id = m.group_id and g.aktif
      join academic_years a on a.id = m.academic_year_id and a.aktif
     where m.student_id = new.id and m.alasan_keluar = 'Nonaktif sementara'
       and m.selesai = (select max(x.selesai) from group_members x where x.student_id = new.id and x.alasan_keluar = 'Nonaktif sementara')
       and not exists (select 1 from group_members o where o.student_id = new.id and o.selesai is null
                        and (o.group_id = m.group_id or (o.jenis = m.jenis and o.jenis in ('kelas','kamar','halaqah') and o.academic_year_id = m.academic_year_id)));
  end if;
  return new;
end $$;

-- Santri yang saat ini sudah nonaktif: tutup keanggotaannya per tanggal status
update public.group_members m set selesai = greatest(m.mulai, coalesce(s.status_sejak, public.hari_ini())), alasan_keluar = 'Nonaktif sementara'
  from public.students s where s.id = m.student_id and s.status = 'nonaktif' and m.selesai is null;

-- ---------------------------------------------------------------------
-- 2. Daftar kerja hanya santri berstatus Aktif
-- ---------------------------------------------------------------------
select pg_temp.tambal('_anggota_pada', 's.status in (''aktif'',''nonaktif'')', 's.status = ''aktif''', 's.status = ''aktif''');
select pg_temp.tambal('daftar_tahfizh', 's.status in (''aktif'',''nonaktif'')', 's.status = ''aktif''', 's.status = ''aktif''');
select pg_temp.tambal('capaian_bulanan', 's.status in (''aktif'',''nonaktif'')', 's.status = ''aktif''', 's.status = ''aktif''');
select pg_temp.tambal('laporan_kehadiran_santri', 's.status in (''aktif'',''nonaktif'')', 's.status = ''aktif''', 's.status = ''aktif''');
select pg_temp.tambal('bahan_rapor_halaqah', 's.status in (''aktif'',''nonaktif'')', 's.status = ''aktif''', 's.status = ''aktif''');
select pg_temp.tambal('bahan_rapor_kelas', 's.status in (''aktif'',''nonaktif'')', 's.status = ''aktif''', 's.status = ''aktif''');
select pg_temp.tambal('nilai_ekskul', 's.status in (''aktif'',''nonaktif'')', 's.status = ''aktif''', 's.status = ''aktif''');
select pg_temp.tambal('lembar_nilai', 'st.status in (''aktif'',''nonaktif'')', 'st.status = ''aktif''', 'st.status = ''aktif''');
select pg_temp.tambal('data_rapor', 's.status in (''aktif'',''nonaktif'',''lulus'')', 's.status in (''aktif'',''lulus'')', 's.status in (''aktif'',''lulus'')');
select pg_temp.tambal('data_rapor_tahfizh', 's.status in (''aktif'',''nonaktif'',''lulus'')', 's.status in (''aktif'',''lulus'')', 's.status in (''aktif'',''lulus'')');
select pg_temp.tambal('statistik_santri', 'status in (''aktif'',''nonaktif'')) aktif', 'status = ''aktif'') aktif', 'status = ''aktif'') aktif');

-- ---------------------------------------------------------------------
-- PEMERIKSAAN — hasil yang benar: 3 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select '1. Nonaktif menutup keanggotaan kelompok' as pemeriksaan,
       case when position('Nonaktif sementara' in pg_get_functiondef('public.tg_students_tutup_kelompok()'::regprocedure)) > 0
             and not exists (select 1 from public.group_members m join public.students s on s.id = m.student_id
                              where s.status <> 'aktif' and m.selesai is null) then 'Sesuai' else 'Periksa' end as hasil
union all
select '2. Daftar kerja hanya santri aktif',
       case when (select count(*) from pg_proc p where p.pronamespace = 'public'::regnamespace
                   and p.proname in ('_anggota_pada','daftar_tahfizh','capaian_bulanan','laporan_kehadiran_santri','bahan_rapor_halaqah',
                                     'bahan_rapor_kelas','nilai_ekskul','lembar_nilai','data_rapor','data_rapor_tahfizh')
                   and pg_get_functiondef(p.oid) like '%''nonaktif''%') = 0 then 'Sesuai' else 'Periksa' end
union all
select '3. Statistik santri aktif tanpa nonaktif',
       case when position('status = ''aktif'') aktif' in pg_get_functiondef('public.statistik_santri()'::regprocedure)) > 0 then 'Sesuai' else 'Periksa' end;
