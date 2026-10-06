-- SIMKA PRO | supabase/migrations/20261006005600_fase7_penutup.sql | v1.0 | Fase 7 – Tahap 5 Penutup fase | 06/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 7 · Migrasi 56: Penutup Fase 7
--   * riwayat_security_santri(): bagian "Security dan libur" di profil santri terpadu – riwayat gerbang (keluar, kembali,
--     ditolak, terlambat), titipan (termasuk siapa yang mengambil), kunjungan orang tua, dan keputusan libur yang disahkan.
--     Dapat dilihat oleh yang berhak melihat santri itu (pengasuh, pimpinan, admin) dan oleh petugas/pemantau Security.
-- Jalankan SETELAH migrasi 5500. Aman dijalankan ulang.
-- =====================================================================

create or replace function public.riwayat_security_santri(p_santri uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if not (public.boleh_lihat_security() or p_santri in (select public.santri_terlihat())) then
    raise exception 'Anda tidak berwenang melihat riwayat santri ini.' using errcode = '42501';
  end if;
  return jsonb_build_object(
    'gerbang', coalesce((select jsonb_agg(x order by x->>'waktu' desc) from (
        select jsonb_build_object('id', g.id, 'jenis', g.jenis, 'waktu', g.waktu, 'penjemput', g.penjemput, 'catatan', g.catatan,
               'terlambat_menit', g.terlambat_menit, 'petugas', e.nama_lengkap, 'alasan_izin', p.alasan, 'jenis_izin', p.jenis) x
          from gate_logs g left join employees e on e.id = g.petugas_id left join student_permits p on p.id = g.permit_id
         where g.student_id = p_santri order by g.waktu desc limit 30) q), '[]'::jsonb),
    'titipan', coalesce((select jsonb_agg(public._titipan_json(t.id) order by t.diterima_pada desc)
        from (select id, diterima_pada from parcels where student_id = p_santri order by diterima_pada desc limit 20) t), '[]'::jsonb),
    'kunjungan', coalesce((select jsonb_agg(public._kunjungan_json(v.id) order by v.datang_pada desc)
        from (select id, datang_pada from parent_visits where student_id = p_santri order by datang_pada desc limit 20) v), '[]'::jsonb),
    'libur', coalesce((select jsonb_agg(jsonb_build_object('periode', h.nama, 'pulang_pada', h.pulang_pada, 'kembali_batas', h.kembali_batas,
               'keputusan', e.keputusan, 'alasan_ubah', e.alasan_ubah, 'rincian', e.rincian) order by h.pulang_pada desc)
        from holiday_eligibility e join holiday_periods h on h.id = e.period_id
       where e.student_id = p_santri and h.status = 'disahkan'), '[]'::jsonb),
    'ringkasan', jsonb_build_object(
      'keluar', (select count(*) from gate_logs where student_id = p_santri and jenis = 'keluar'),
      'terlambat', (select count(*) from gate_logs where student_id = p_santri and jenis = 'kembali' and terlambat_menit > 0),
      'ditolak', (select count(*) from gate_logs where student_id = p_santri and jenis = 'ditolak'),
      'titipan_di_pos', (select count(*) from parcels where student_id = p_santri and status = 'di_pos')));
end $$;
revoke execute on function public.riwayat_security_santri(uuid) from public, anon;
grant execute on function public.riwayat_security_santri(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN (hasil yang benar: "Sesuai")
-- ---------------------------------------------------------------------
select '1. Riwayat Security di profil santri' as pemeriksaan,
       case when exists (select 1 from pg_proc where proname = 'riwayat_security_santri') then 'Sesuai' else 'Periksa' end as hasil;
