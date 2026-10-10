-- SIMKA PRO | supabase/migrations/20261010006100_perbaikan_registri.sql | v1.0 | Fase 8 – Perbaikan: galat "infinite recursion" tab Dokumen resmi | 10/10/2026
-- =====================================================================
-- Masalah: kebijakan baca document_registry memeriksa document_signatures, dan kebijakan baca document_signatures
--          memeriksa document_registry, sehingga PostgreSQL berputar tanpa akhir ("infinite recursion detected in
--          policy for relation document_signatures") dan tab Rekap → Dokumen resmi kosong.
-- Perbaikan: pemeriksaan hak dipindah ke satu fungsi security definer (tidak melewati RLS lagi).
-- Jalankan SETELAH migrasi 6000. Aman dijalankan ulang.
-- =====================================================================
create or replace function public.boleh_lihat_dokumen(p_doc uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_admin()
      or exists (select 1 from document_registry d where d.id = p_doc and d.diterbitkan_oleh = public.saya())
      or exists (select 1 from document_signatures s where s.document_id = p_doc and s.employee_id = public.saya())
$$;
revoke execute on function public.boleh_lihat_dokumen(uuid) from public, anon;
grant execute on function public.boleh_lihat_dokumen(uuid) to authenticated;

drop policy if exists baca on public.document_registry;
create policy baca on public.document_registry for select to authenticated using (public.boleh_lihat_dokumen(id));
drop policy if exists baca on public.document_signatures;
create policy baca on public.document_signatures for select to authenticated using (public.boleh_lihat_dokumen(document_id));

-- PEMERIKSAAN (hasil yang benar: "Sesuai" dan angka jumlah dokumen yang terbaca)
select '1. Kebijakan registri tanpa putaran' as pemeriksaan,
       case when (select count(*) from pg_policies where tablename in ('document_registry','document_signatures')
                   and qual like '%boleh_lihat_dokumen%') = 2 then 'Sesuai' else 'Periksa' end as hasil
union all
select '2. Dokumen terdaftar', (select count(*)::text || ' dokumen' from document_registry);
