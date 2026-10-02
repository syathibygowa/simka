-- =====================================================================
-- SIMKA PRO · Fase 1 · Migrasi 3: Row Level Security
-- Prinsip: pegawai membaca datanya sendiri; pimpinan membaca cabangnya;
-- admin dan superadmin membaca semua. Pengaturan sistem hanya superadmin.
-- =====================================================================

do $$
declare t text;
begin
  foreach t in array array['org_units','functional_positions','structural_positions','employees',
    'employee_functions','employee_structurals','employment_history','password_reset_tokens',
    'features','feature_grants','admin_capabilities','admin_permissions','institution_settings',
    'letterheads','signatories','signer_rules','academic_years','holiday_calendars','holidays',
    'letter_subject_codes','doc_number_formats','doc_counters','doc_numbers_issued',
    'storage_objects','notifications','audit_logs','heartbeat']
  loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

-- ---------- Data referensi: dibaca semua pengguna masuk, diubah superadmin ----------
do $$
declare t text;
begin
  foreach t in array array['org_units','functional_positions','structural_positions','features',
    'admin_capabilities','letterheads','signatories','signer_rules','academic_years',
    'holiday_calendars','letter_subject_codes']
  loop
    execute format('create policy baca_semua on public.%I for select to authenticated using (true)', t);
    execute format('create policy kelola_superadmin on public.%I for all to authenticated
                    using (public.is_superadmin()) with check (public.is_superadmin())', t);
  end loop;
end $$;

-- Struktur dan jabatan juga dibaca halaman Daftar (tanpa login)
create policy baca_anon on public.org_units for select to anon using (aktif);
create policy baca_anon on public.functional_positions for select to anon using (aktif);
create policy baca_anon on public.structural_positions for select to anon using (aktif);

-- Libur: admin dengan izin kalender dapat mengelola
create policy baca_semua on public.holidays for select to authenticated using (true);
create policy kelola_kalender on public.holidays for all to authenticated
  using (public.admin_boleh('kalender')) with check (public.admin_boleh('kalender'));

-- ---------- Pegawai ----------
create policy baca_pegawai on public.employees for select to authenticated
  using (user_id = auth.uid() or public.is_admin() or public.pimpinan_dari(id));

-- Admin dapat menambah data pegawai tanpa akun (impor Excel / input manual)
create policy tambah_pegawai on public.employees for insert to authenticated
  with check (public.admin_boleh('kelola_pegawai') and user_id is null
              and status_akun = 'tanpa_akun' and peran = 'pegawai');

create policy ubah_diri on public.employees for update to authenticated
  using (user_id = auth.uid() and status_akun = 'aktif')
  with check (user_id = auth.uid());
create policy ubah_admin on public.employees for update to authenticated
  using (public.admin_boleh('kelola_pegawai') or public.admin_boleh('verval_akun'))
  with check (public.admin_boleh('kelola_pegawai') or public.admin_boleh('verval_akun'));
create policy hapus_superadmin on public.employees for delete to authenticated
  using (public.is_superadmin() and status_akun in ('tanpa_akun','ditolak'));

-- ---------- Jabatan pegawai ----------
create policy baca on public.employee_functions for select to authenticated
  using (employee_id = public.saya() or public.is_admin() or public.pimpinan_dari(employee_id));
create policy kelola on public.employee_functions for all to authenticated
  using (public.admin_boleh('kelola_pegawai')) with check (public.admin_boleh('kelola_pegawai'));

create policy baca on public.employee_structurals for select to authenticated
  using (employee_id = public.saya() or public.is_admin() or public.pimpinan_dari(employee_id));
create policy kelola on public.employee_structurals for all to authenticated
  using (public.admin_boleh('kelola_pegawai')) with check (public.admin_boleh('kelola_pegawai'));

create policy baca on public.employment_history for select to authenticated
  using (employee_id = public.saya() or public.is_admin());
-- (penulisan hanya melalui pemicu)

-- ---------- Hak akses ----------
create policy baca on public.feature_grants for select to authenticated
  using (public.is_superadmin() or (sasaran = 'individu' and sasaran_id = public.saya()));
create policy kelola on public.feature_grants for all to authenticated
  using (public.is_superadmin()) with check (public.is_superadmin());

create policy baca on public.admin_permissions for select to authenticated
  using (public.is_superadmin() or employee_id = public.saya());
create policy kelola on public.admin_permissions for all to authenticated
  using (public.is_superadmin()) with check (public.is_superadmin());

-- ---------- Pengaturan lembaga ----------
create policy baca_publik on public.institution_settings for select to anon, authenticated
  using (publik or public.is_superadmin() or (kunci = 'kalender' and auth.uid() is not null));
create policy kelola on public.institution_settings for all to authenticated
  using (public.is_superadmin()) with check (public.is_superadmin());

-- Kop dibaca tanpa login juga (halaman cek keabsahan dokumen kelak)
create policy baca_anon on public.letterheads for select to anon using (aktif);

-- ---------- Penomoran ----------
create policy baca on public.doc_number_formats for select to authenticated using (public.is_admin());
create policy kelola on public.doc_number_formats for all to authenticated
  using (public.is_superadmin()) with check (public.is_superadmin());
create policy baca on public.doc_counters for select to authenticated using (public.is_admin());
create policy koreksi on public.doc_counters for update to authenticated
  using (public.is_superadmin()) with check (public.is_superadmin());
create policy baca on public.doc_numbers_issued for select to authenticated
  using (public.is_admin() or dibuat_oleh = public.saya());

-- ---------- Penyimpanan berkas ----------
create policy baca on public.storage_objects for select to authenticated
  using (publik or pemilik_id = public.saya() or public.is_admin());
create policy tambah on public.storage_objects for insert to authenticated
  with check (pemilik_id = public.saya() or public.is_admin());
create policy kelola on public.storage_objects for update to authenticated
  using (public.is_superadmin()) with check (public.is_superadmin());

-- ---------- Notifikasi ----------
create policy baca_sendiri on public.notifications for select to authenticated
  using (employee_id = public.saya());
-- penandaan dibaca lewat fungsi tandai_dibaca(); penghapusan oleh pemilik
create policy hapus_sendiri on public.notifications for delete to authenticated
  using (employee_id = public.saya());

-- ---------- Audit log: 30 hari terakhir ----------
create policy baca on public.audit_logs for select to authenticated
  using (created_at > now() - interval '30 days'
         and (employee_id = public.saya() or public.admin_boleh('audit_log')));

-- password_reset_tokens dan heartbeat: tanpa kebijakan = tertutup untuk klien
-- (hanya service role melalui Edge Function / GAS).

-- ---------- Hak eksekusi fungsi ----------
revoke execute on function public.ambil_nomor(text,date,text,text,text) from public, anon;
grant  execute on function public.ambil_nomor(text,date,text,text,text) to authenticated;
revoke execute on function public.rincian_akses(uuid) from public, anon;
grant  execute on function public.rincian_akses(uuid) to authenticated;
grant  execute on function public.waktu_server() to anon, authenticated;
grant  execute on function public.hijriah(date) to anon, authenticated;

-- ---------- Realtime ----------
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.notifications, public.employees;
  end if;
end $$;
