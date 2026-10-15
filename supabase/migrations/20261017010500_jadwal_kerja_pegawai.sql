-- SIMKA PRO | supabase/migrations/20261017010500_jadwal_kerja_pegawai.sql | v1.0 | Perbaikan 13.6.0 Jadwal kerja semua pegawai (Penjadwalan) | 15/10/2026
-- =====================================================================
-- SIMKA PRO · Migrasi 105: Jadwal kerja/berkantor semua pegawai dalam satu pekan
--   Menampilkan jam presensi yang BENAR-BENAR dibaca sistem untuk setiap pegawai per tanggal, memakai fungsi yang sama
--   dengan halaman Presensi (jadwal_pegawai): pola dan sesi aktif, sesi yang dipegang, jadwal shift, serta hari libur kalender.
--   * jadwal_kerja_pekan(p_mulai) : 7 hari mulai p_mulai untuk semua pegawai aktif.
--     Hanya superadmin dan admin ber-izin "atur_presensi". Tidak mengubah data.
-- Jalankan SETELAH migrasi 10400. Aman dijalankan ulang.
-- =====================================================================

create or replace function public.jadwal_kerja_pekan(p_mulai date default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_mulai date := coalesce(p_mulai, public.hari_ini());
begin
  if not (public.is_superadmin() or public.admin_boleh('atur_presensi')) then
    raise exception 'Jadwal kerja pegawai hanya dapat dibuka superadmin dan admin Penjadwalan.' using errcode = '42501';
  end if;
  return jsonb_build_object(
    'mulai', v_mulai,
    -- Hari libur yang berlaku untuk semua pegawai pada pekan ini (nama libur ditampilkan di kepala kolom)
    'libur', coalesce((select jsonb_agg(jsonb_build_object('t', d::date,
                         'nama', (select string_agg(h.nama, ', ') from holidays h where d::date between h.tanggal_mulai and h.tanggal_akhir
                                    and 'semua' = any(h.berlaku_untuk))) order by d)
                        from generate_series(v_mulai, v_mulai + 6, interval '1 day') d
                       where public.libur_tugas(d::date, null)), '[]'::jsonb),
    'pegawai', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', e.id, 'niy', e.niy, 'nama', e.nama_lengkap, 'jk', e.jenis_kelamin,
               'unit_id', e.org_unit_id, 'unit', u.nama,
               'pola', (select coalesce(jsonb_agg(distinct p.nama), '[]'::jsonb) from employee_schedules es
                          join task_patterns p on p.id = es.pattern_id and p.aktif where es.employee_id = e.id and es.aktif),
               'hari', (select jsonb_agg(jsonb_build_object('t', d::date, 'sesi', (
                          select coalesce(jsonb_agg(jsonb_build_object(
                                   'pola', j.nama_pola, 'jenis', j.jenis_pola, 'sesi', j.nama_sesi, 'warna', j.warna, 'opsional', j.opsional,
                                   'mulai', to_char(j.mulai at time zone 'Asia/Makassar', 'HH24.MI'),
                                   'selesai', to_char(j.selesai at time zone 'Asia/Makassar', 'HH24.MI'),
                                   'buka', to_char(j.buka at time zone 'Asia/Makassar', 'HH24.MI'),
                                   'tepat', to_char(j.batas_tepat at time zone 'Asia/Makassar', 'HH24.MI'),
                                   'tutup', to_char(j.tutup at time zone 'Asia/Makassar', 'HH24.MI'),
                                   'pulang', j.wajib_pulang) order by j.mulai), '[]'::jsonb)
                            from public.jadwal_pegawai(e.id, d::date) j)) order by d)
                         from generate_series(v_mulai, v_mulai + 6, interval '1 day') d))
             order by e.nama_lengkap)
        from employees e left join org_units u on u.id = e.org_unit_id
       where e.status_keaktifan = 'aktif'), '[]'::jsonb));
end $$;
revoke execute on function public.jadwal_kerja_pekan(date) from public, anon;
grant execute on function public.jadwal_kerja_pekan(date) to authenticated;

-- PEMERIKSAAN — hasil yang benar: 2 baris "Sesuai"
select '1. Fungsi jadwal kerja pekanan tersedia' as pemeriksaan,
       case when exists (select 1 from pg_proc where proname = 'jadwal_kerja_pekan') then 'Sesuai' else 'Periksa' end as hasil
union all
select '2. Tertutup bagi pengguna tanpa login',
       case when not has_function_privilege('anon', 'public.jadwal_kerja_pekan(date)', 'execute') then 'Sesuai' else 'Periksa' end;
