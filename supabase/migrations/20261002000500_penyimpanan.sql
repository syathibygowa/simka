-- =====================================================================
-- SIMKA PRO · Fase 1 · Migrasi 5: Bucket Supabase Storage dan kebijakannya
--   publik  : logo dan kop (dibaca siapa saja)
--   antrian : berkas yang menunggu dipindah GAS ke Google Drive (tiap 5 menit)
--   profil  : foto profil/kartu (privat)
-- Struktur path antrian/profil: {employee_id}/{nama-berkas}
-- =====================================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('publik',  'publik',  true,  1048576, array['image/png','image/jpeg','image/webp','image/svg+xml']),
  ('antrian', 'antrian', false, 5242880, array['image/jpeg','image/png','image/webp','application/pdf']),
  ('profil',  'profil',  false, 1048576, array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;

-- publik
create policy "publik dibaca semua" on storage.objects for select
  using (bucket_id = 'publik');
create policy "publik dikelola superadmin" on storage.objects for all to authenticated
  using (bucket_id = 'publik' and public.is_superadmin())
  with check (bucket_id = 'publik' and public.is_superadmin());

-- antrian
create policy "antrian unggah sendiri" on storage.objects for insert to authenticated
  with check (bucket_id = 'antrian' and (storage.foldername(name))[1] = public.saya()::text);
create policy "antrian baca sendiri atau admin" on storage.objects for select to authenticated
  using (bucket_id = 'antrian' and ((storage.foldername(name))[1] = public.saya()::text or public.is_admin()));

-- profil
create policy "profil kelola sendiri" on storage.objects for all to authenticated
  using (bucket_id = 'profil' and (storage.foldername(name))[1] = public.saya()::text)
  with check (bucket_id = 'profil' and (storage.foldername(name))[1] = public.saya()::text);
create policy "profil dibaca admin" on storage.objects for select to authenticated
  using (bucket_id = 'profil' and public.is_admin());
