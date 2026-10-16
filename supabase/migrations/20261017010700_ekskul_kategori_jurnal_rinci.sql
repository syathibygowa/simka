-- SIMKA PRO | supabase/migrations/20261017010700_ekskul_kategori_jurnal_rinci.sql | v1.0 | Perbaikan 13.7.0 Ekskul indoor/outdoor dan jurnal rinci | 16/10/2026
-- =====================================================================
-- SIMKA PRO · Migrasi 107: Ekskul
--   * Kategori ekskul: indoor / outdoor (student_groups.kategori_ekskul) — dipakai sebagai kelompok dan saringan di menu Ekskul.
--     atur_kategori_ekskul(group, kategori): superadmin, admin ber-izin kelompok_santri, atau hak fitur kelompok_santri ≥ 2.
--   * Jurnal pertemuan rinci dan WAJIB (seperti jurnal mengajar guru): extracurricular_journals.rincian =
--     { materi, submateri, kegiatan, metode[], media[], capaian, kendala, tindak_lanjut }.
--     simpan_rincian_jurnal_ekskul(sesi, rincian): dipanggil setelah absensi pertemuan tersimpan; materi, sub-materi,
--     kegiatan (≥ 10 huruf), minimal satu metode, dan capaian wajib diisi. Topik dan uraian lama ikut diperbarui.
--   * jurnal_ekskul_terakhir(group, tanggal): jurnal pertemuan sebelumnya (isian awal materi/metode/media).
-- Jalankan SETELAH migrasi 10600. Aman dijalankan ulang.
-- =====================================================================

-- 1. Kategori indoor/outdoor
alter table public.student_groups add column if not exists kategori_ekskul text;
alter table public.student_groups drop constraint if exists student_groups_kategori_ekskul_check;
alter table public.student_groups add constraint student_groups_kategori_ekskul_check check (kategori_ekskul is null or kategori_ekskul in ('indoor','outdoor'));

create or replace function public.atur_kategori_ekskul(p_group uuid, p_kategori text)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  if not (public.is_superadmin() or public.admin_boleh('kelompok_santri') or public.tingkat_fitur('kelompok_santri') >= 2) then
    raise exception 'Anda tidak berwenang mengatur kategori ekskul.' using errcode = '42501';
  end if;
  if p_kategori is not null and p_kategori not in ('indoor','outdoor') then raise exception 'Kategori ekskul harus indoor atau outdoor.'; end if;
  update student_groups set kategori_ekskul = p_kategori where id = p_group and jenis = 'ekskul';
  if not found then raise exception 'Ekskul tidak ditemukan.'; end if;
end $$;
revoke execute on function public.atur_kategori_ekskul(uuid,text) from public, anon;
grant execute on function public.atur_kategori_ekskul(uuid,text) to authenticated;

-- 2. Jurnal rinci
alter table public.extracurricular_journals add column if not exists rincian jsonb;

create or replace function public.simpan_rincian_jurnal_ekskul(p_sesi uuid, p jsonb)
returns void language plpgsql volatile security definer set search_path = public as $$
declare sa student_attendance_sessions; v_materi text := trim(coalesce(p->>'materi', '')); v_sub text := trim(coalesce(p->>'submateri', ''));
  v_keg text := trim(coalesce(p->>'kegiatan', '')); v_capai text := trim(coalesce(p->>'capaian', '')); v_isi jsonb;
begin
  select * into sa from student_attendance_sessions where id = p_sesi;
  if not found or sa.jenis <> 'ekskul' then raise exception 'Pertemuan ekskul tidak ditemukan. Simpan absensi pertemuan lebih dulu.'; end if;
  if not (public.is_superadmin() or public.admin_boleh('absensi_atas_nama') or sa.pengampu_id = public.saya() or sa.diinput_oleh = public.saya()
          or exists (select 1 from group_keepers k where k.group_id = sa.group_id and k.employee_id = public.saya())) then
    raise exception 'Anda bukan pembina/pelatih ekskul ini.' using errcode = '42501';
  end if;
  if length(v_materi) < 3 then raise exception 'Isi materi pokok pertemuan (minimal 3 huruf).'; end if;
  if length(v_sub) < 3 then raise exception 'Isi sub-materi/pembahasan pertemuan (minimal 3 huruf).'; end if;
  if length(v_keg) < 10 then raise exception 'Uraikan kegiatan latihan (minimal 10 huruf).'; end if;
  if jsonb_array_length(coalesce(p->'metode', '[]'::jsonb)) = 0 then raise exception 'Pilih minimal satu metode latihan.'; end if;
  if length(v_capai) < 3 then raise exception 'Isi capaian/hasil latihan santri.'; end if;
  v_isi := jsonb_build_object('materi', v_materi, 'submateri', v_sub, 'kegiatan', v_keg, 'metode', p->'metode', 'media', coalesce(p->'media', '[]'::jsonb),
                              'capaian', v_capai, 'kendala', nullif(trim(coalesce(p->>'kendala', '')), ''), 'tindak_lanjut', nullif(trim(coalesce(p->>'tindak_lanjut', '')), ''));
  insert into extracurricular_journals (session_id, topik, uraian, rincian)
  values (p_sesi, v_materi || ' – ' || v_sub, v_keg, v_isi)
  on conflict (session_id) do update set topik = excluded.topik, uraian = excluded.uraian, rincian = excluded.rincian, updated_at = now();
end $$;
revoke execute on function public.simpan_rincian_jurnal_ekskul(uuid,jsonb) from public, anon;
grant execute on function public.simpan_rincian_jurnal_ekskul(uuid,jsonb) to authenticated;

-- 3. Jurnal pertemuan sebelumnya (isian awal)
create or replace function public.jurnal_ekskul_terakhir(p_group uuid, p_tanggal date)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('tanggal', sa.tanggal, 'topik', j.topik, 'rincian', j.rincian)
    from student_attendance_sessions sa join extracurricular_journals j on j.session_id = sa.id
   where sa.group_id = p_group and sa.jenis = 'ekskul' and sa.tanggal < p_tanggal
     and sa.group_id in (select id from student_groups)
   order by sa.tanggal desc, sa.jam_mulai desc nulls last limit 1
$$;
revoke execute on function public.jurnal_ekskul_terakhir(uuid,date) from public, anon;
grant execute on function public.jurnal_ekskul_terakhir(uuid,date) to authenticated;

-- PEMERIKSAAN — hasil yang benar: 3 baris "Sesuai"
select '1. Kolom kategori ekskul (indoor/outdoor) tersedia' as pemeriksaan,
       case when exists (select 1 from information_schema.columns where table_name = 'student_groups' and column_name = 'kategori_ekskul') then 'Sesuai' else 'Periksa' end as hasil
union all
select '2. Kolom jurnal rinci ekskul tersedia',
       case when exists (select 1 from information_schema.columns where table_name = 'extracurricular_journals' and column_name = 'rincian') then 'Sesuai' else 'Periksa' end
union all
select '3. Fungsi kategori, jurnal rinci, dan jurnal terakhir tersedia',
       case when (select count(*) from pg_proc where pronamespace = 'public'::regnamespace
                   and proname in ('atur_kategori_ekskul','simpan_rincian_jurnal_ekskul','jurnal_ekskul_terakhir')) = 3 then 'Sesuai' else 'Periksa' end;
