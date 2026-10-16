-- SIMKA PRO | supabase/migrations/20261018011000_hapus_periode_libur.sql | v1.0 | Perbaikan 13.8.0: periode libur santri yang dibatalkan dapat dihapus | 16/10/2026
-- Periode libur berstatus "batal" dapat dihapus permanen beserta hasil penilaian santrinya.
--   * Hanya periode yang sudah dibatalkan (draf/dinilai/disahkan harus dibatalkan lebih dulu).
--   * Wewenang sama dengan pembatalan: pengelola libur; periode yang pernah disahkan hanya oleh pejabat pengesah.
--   * Izin libur santri yang dulu dibuat (sudah berstatus dibatalkan) tetap tersimpan di Perizinan sebagai riwayat.
--   * Tercatat di Audit Log.
-- Aman dijalankan ulang.

create or replace function public.hapus_periode_libur(p_id uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
declare h holiday_periods%rowtype; v_jumlah int;
begin
  select * into h from holiday_periods where id = p_id for update;
  if h.id is null then raise exception 'Periode libur tidak ditemukan.'; end if;
  if h.status <> 'batal' then raise exception 'Hanya periode yang sudah dibatalkan yang dapat dihapus. Batalkan periode lebih dulu.'; end if;
  if h.disahkan_pada is not null and not public.boleh_sahkan_libur() then
    raise exception 'Periode yang pernah disahkan hanya dapat dihapus oleh pejabat pengesah.' using errcode = '42501';
  end if;
  if not (public.boleh_kelola_libur() or public.boleh_sahkan_libur()) then raise exception 'Anda tidak berwenang menghapus periode libur.' using errcode = '42501'; end if;
  select count(*) into v_jumlah from holiday_eligibility where period_id = p_id;
  delete from holiday_periods where id = p_id;   -- hasil penilaian ikut terhapus (on delete cascade)
  perform public.catat_audit('hapus_periode_libur', 'holiday_periods', p_id::text,
    'Menghapus periode libur yang dibatalkan: ' || h.nama || ' (' || v_jumlah || ' santri dinilai)',
    jsonb_build_object('nama', h.nama, 'jenis', h.jenis, 'pulang_pada', h.pulang_pada, 'kembali_batas', h.kembali_batas, 'catatan', h.catatan));
end $$;
revoke execute on function public.hapus_periode_libur(uuid) from public, anon;
grant execute on function public.hapus_periode_libur(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN — hasil yang benar: 2 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select 'Fungsi hapus_periode_libur tersedia' as pemeriksaan,
       case when to_regprocedure('public.hapus_periode_libur(uuid)') is not null then 'Sesuai' else 'Periksa' end as hasil
union all
select 'Hanya pengguna masuk yang dapat menjalankan',
       case when has_function_privilege('authenticated', 'public.hapus_periode_libur(uuid)', 'execute')
             and not has_function_privilege('anon', 'public.hapus_periode_libur(uuid)', 'execute') then 'Sesuai' else 'Periksa' end;
