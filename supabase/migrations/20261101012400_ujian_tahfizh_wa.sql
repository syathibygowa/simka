-- SIMKA PRO | supabase/migrations/20261101012400_ujian_tahfizh_wa.sql | v1.0 | 14.9.1: alur WhatsApp ujian kenaikan juz dan sertifikasi, keterangan hasil dan catatan perbaikan | 18/10/2026
-- =====================================================================
-- SIMKA PRO · Migrasi 124: Ujian tahfizh — konfirmasi WhatsApp dan keterangan hasil
--   * tahfizh_exams: kolom keterangan (lulus / perbaikan / tidak_lulus) dan catatan_perbaikan.
--       Tuntas → Lulus. Remidi → penguji memilih Perbaikan (ujian ulang setelah diperbaiki) atau Tidak lulus.
--   * nilai_ujian(...) menerima p_keterangan dan p_perbaikan (parameter lama tetap berlaku). Catatan perbaikan ikut notifikasi.
--   * daftar_ujian(...) menambah keterangan, catatan perbaikan, muhaffizh halaqah beserta nomor HP-nya, nomor HP perekomendasi
--     dan penguji, serta tanda "antrian saya" untuk penguji.
--   * Template WA baru: ujian_rekomendasi (muhaffizh → penguji), ujian_jadwal (penguji → muhaffizh), ujian_hasil (penguji → muhaffizh).
--     Dapat diubah di Setelan → Template WA.
-- Jalankan SETELAH migrasi 12300. Aman dijalankan ulang.
-- =====================================================================

alter table public.tahfizh_exams add column if not exists keterangan text;
alter table public.tahfizh_exams add column if not exists catatan_perbaikan text;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'tahfizh_exams_keterangan_check') then
    alter table public.tahfizh_exams add constraint tahfizh_exams_keterangan_check check (keterangan is null or keterangan in ('lulus','perbaikan','tidak_lulus'));
  end if;
end $$;
-- Ujian lama yang sudah dinilai: Tuntas = Lulus, Remidi = Perbaikan
update public.tahfizh_exams set keterangan = case hasil when 'tuntas' then 'lulus' else 'perbaikan' end where status = 'selesai' and hasil is not null and keterangan is null;

-- ---------------------------------------------------------------------
-- Penilaian: keterangan dan catatan perbaikan
-- ---------------------------------------------------------------------
drop function if exists public.nilai_ujian(uuid, numeric, numeric, text);
create or replace function public.nilai_ujian(p_id uuid, p_tajwid numeric, p_itqan numeric, p_catatan text default null,
  p_keterangan text default null, p_perbaikan text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare r tahfizh_exams; st tahfizh_settings; v_ta uuid := (select id from academic_years where aktif); v_akhir numeric; pr predicate_ranges;
  v_hasil text; v_nama text; j smallint; v_ket text; v_perbaikan text := nullif(trim(p_perbaikan), '');
begin
  select * into r from tahfizh_exams where id = p_id for update;
  if not found or r.status not in ('menunggu','dijadwalkan') then raise exception 'Ujian tidak ditemukan atau sudah dinilai.'; end if;
  if not (public._penguji_aktif(r.jenis, public.saya()) or public.is_superadmin()) then
    raise exception 'Hanya penguji aktif yang dapat menilai ujian ini.' using errcode = '42501';
  end if;
  if r.penguji_id is not null and r.penguji_id <> public.saya() and not public.is_superadmin() then
    raise exception 'Ujian ini dipegang penguji lain.';
  end if;
  if public._muhaffizh_dari(r.student_id, public.saya()) then raise exception 'Muhaffizh tidak menguji santri halaqahnya sendiri.'; end if;
  if p_tajwid is null or p_itqan is null or p_tajwid not between 0 and 100 or p_itqan not between 0 and 100 then
    raise exception 'Nilai Tajwid dan Itqan harus 0–100.';
  end if;
  select * into st from tahfizh_settings where academic_year_id = v_ta;
  v_akhir := round(p_tajwid * coalesce(st.bobot_tajwid, 50) / 100.0 + p_itqan * coalesce(st.bobot_itqan, 50) / 100.0, 2);
  select * into pr from predicate_ranges where academic_year_id = v_ta and v_akhir between nilai_min and nilai_maks order by nilai_min desc limit 1;
  v_hasil := case when v_akhir >= coalesce(st.kkm, 80) then 'tuntas' else 'remidi' end;
  v_ket := case when v_hasil = 'tuntas' then 'lulus' when p_keterangan = 'tidak_lulus' then 'tidak_lulus' else 'perbaikan' end;
  if v_hasil = 'remidi' and v_perbaikan is null then raise exception 'Tuliskan catatan perbaikan untuk santri yang belum lulus.'; end if;
  select nama_lengkap into v_nama from students where id = r.student_id;

  update tahfizh_exams set nilai_tajwid = p_tajwid, nilai_itqan = p_itqan, nilai_akhir = v_akhir, huruf = pr.huruf, predikat = pr.deskripsi_rapor,
         hasil = v_hasil, kkm = coalesce(st.kkm, 80), catatan_penguji = nullif(trim(p_catatan), ''), diuji_pada = now(),
         penguji_id = coalesce(penguji_id, public.saya()), status = 'selesai', keterangan = v_ket, catatan_perbaikan = v_perbaikan
   where id = p_id;

  -- Kenaikan juz Tuntas → usulan capaian juz (sumber ujian) untuk divalidasi
  if r.jenis = 'kenaikan' and v_hasil = 'tuntas' then
    foreach j in array r.juz loop
      insert into juz_proposals (student_id, juz, sumber, ref_id, catatan, diusulkan_oleh)
      select r.student_id, j, 'ujian', r.id, 'Ujian kenaikan juz: nilai ' || v_akhir || ' (' || coalesce(pr.huruf, '-') || ')', public.saya()
       where not exists (select 1 from juz_achievements where student_id = r.student_id and juz = j)
      on conflict do nothing;
    end loop;
    perform public.kirim_notifikasi(v, 'Usulan capaian juz dari ujian: ' || v_nama, 'Juz ' || array_to_string(r.juz, ', ') || ' Tuntas (' || v_akhir || '). Mohon divalidasi.',
      '/tahfizh/capaian?bagian=usulan', 'SealCheck', 'kuning')
      from public._validator_tahfizh() v where v is distinct from public.saya();
  end if;

  if r.direkomendasikan_oleh is not null and r.direkomendasikan_oleh <> public.saya() then
    perform public.kirim_notifikasi(r.direkomendasikan_oleh,
      'Hasil ujian ' || v_nama || ': ' || case v_ket when 'lulus' then 'LULUS' when 'perbaikan' then 'PERBAIKAN' else 'TIDAK LULUS' end,
      case r.jenis when 'kenaikan' then 'Kenaikan juz ' || array_to_string(r.juz, ', ') else 'Sertifikasi ' || r.jenjang || ' juz' end
      || ' · nilai ' || v_akhir || coalesce(' (' || pr.huruf || ', ' || pr.deskripsi_rapor || ')', '')
      || coalesce('. Perbaikan: ' || v_perbaikan, '') || coalesce('. Catatan: ' || nullif(trim(p_catatan), ''), ''),
      '/tahfizh/ujian', 'Exam', case v_hasil when 'tuntas' then 'hijau' else 'merah' end);
  end if;
  return jsonb_build_object('nilai_akhir', v_akhir, 'huruf', pr.huruf, 'predikat', pr.deskripsi_rapor, 'hasil', v_hasil, 'keterangan', v_ket);
end $$;
revoke execute on function public.nilai_ujian(uuid, numeric, numeric, text, text, text) from public, anon;
grant execute on function public.nilai_ujian(uuid, numeric, numeric, text, text, text) to authenticated;

-- ---------------------------------------------------------------------
-- Daftar ujian: data untuk pesan WhatsApp
-- ---------------------------------------------------------------------
drop function if exists public.daftar_ujian(text, text);
create or replace function public.daftar_ujian(p_jenis text default null, p_status text default null)
returns table(id uuid, jenis text, student_id uuid, nis text, nama text, jenis_kelamin text, kelas text, halaqah text, juz smallint[], jenjang smallint, status text,
  ujian_ke smallint, direkomendasikan_oleh text, direkomendasikan_pada timestamptz, catatan_rekomendasi text, penguji_id uuid, penguji text, jadwal timestamptz,
  nilai_tajwid numeric, nilai_itqan numeric, nilai_akhir numeric, huruf text, predikat text, hasil text, kkm numeric, catatan_penguji text, diuji_pada timestamptz,
  alasan_batal text, total_resmi integer, penguji_saya boolean, boleh_nilai boolean, muhaffizh_saya boolean,
  keterangan text, catatan_perbaikan text, muhaffizh text, hp_muhaffizh text, hp_perekomendasi text, hp_penguji text)
language sql stable security definer set search_path = public as $$
  with kel as (
    select m.student_id, g.id gid, g.jenis, g.nama from group_members m join student_groups g on g.id = m.group_id
      join academic_years a on a.id = g.academic_year_id and a.aktif where m.selesai is null and g.jenis in ('kelas','halaqah')
  )
  select t.id, t.jenis, s.id, s.nis, s.nama_lengkap, s.jenis_kelamin,
         (select k.nama from kel k where k.student_id = s.id and k.jenis = 'kelas' limit 1),
         (select k.nama from kel k where k.student_id = s.id and k.jenis = 'halaqah' limit 1),
         t.juz, t.jenjang, t.status, t.ujian_ke, (select nama_lengkap from employees where id = t.direkomendasikan_oleh), t.direkomendasikan_pada,
         t.catatan_rekomendasi, t.penguji_id, (select nama_lengkap from employees where id = t.penguji_id), t.jadwal,
         t.nilai_tajwid, t.nilai_itqan, t.nilai_akhir, t.huruf, t.predikat, t.hasil, t.kkm, t.catatan_penguji, t.diuji_pada, t.alasan_batal,
         (select count(*) from juz_achievements j where j.student_id = s.id)::int,
         t.penguji_id = public.saya(),
         t.status in ('menunggu','dijadwalkan') and public._penguji_aktif(t.jenis, public.saya())
           and (t.penguji_id is null or t.penguji_id = public.saya()) and not public._muhaffizh_dari(s.id, public.saya()),
         public._muhaffizh_santri(s.id),
         t.keterangan, t.catatan_perbaikan,
         mh.nama_lengkap, mh.no_hp,
         (select no_hp from employees where id = t.direkomendasikan_oleh),
         (select no_hp from employees where id = t.penguji_id)
    from tahfizh_exams t join students s on s.id = t.student_id
    left join lateral (select e.nama_lengkap, e.no_hp from kel k join group_keepers gk on gk.group_id = k.gid join employees e on e.id = gk.employee_id
                        where k.student_id = s.id and k.jenis = 'halaqah' and (gk.sampai is null or gk.sampai >= public.hari_ini())
                          and (gk.mulai is null or gk.mulai <= public.hari_ini())
                        order by array_position(array['utama','pendamping','pengganti'], gk.peran) limit 1) mh on true
   where (p_jenis is null or t.jenis = p_jenis)
     and (p_status is null or t.status = p_status or (p_status = 'aktif' and t.status in ('menunggu','dijadwalkan')))
     and (s.id in (select public.santri_terlihat()) or t.penguji_id = public.saya() or public._penguji_aktif(t.jenis, public.saya()))
     and (t.status in ('menunggu','dijadwalkan') or coalesce(t.diuji_pada, t.updated_at) > now() - interval '1 year')
   order by case t.status when 'dijadwalkan' then 0 when 'menunggu' then 1 else 2 end, coalesce(t.jadwal, t.direkomendasikan_pada), t.diuji_pada desc
   limit 500
$$;
revoke execute on function public.daftar_ujian(text, text) from public, anon;
grant execute on function public.daftar_ujian(text, text) to authenticated;

-- ---------------------------------------------------------------------
-- Template WhatsApp
-- ---------------------------------------------------------------------
insert into public.wa_templates (kode, nama, isi, variabel, keterangan) values
  ('ujian_rekomendasi', 'Rekomendasi ujian tahfizh ke penguji',
   E'{salam}, {nama}.\n\nMohon izin, kami merekomendasikan santri berikut untuk *{jenis_ujian}*:\n• Nama: *{nama_santri}*\n• Kelas: {kelas}\n• Halaqah: {halaqah}\n• Materi ujian: {materi}\n• Catatan: {catatan}\n\nMohon berkenan menjadwalkan ujiannya di SIMKA PRO (Tahfizh → Ujian): {tautan}\n\n{penutup}\n{pengirim}\n{jabatan_pengirim}',
   '{nama,jenis_ujian,nama_santri,kelas,halaqah,materi,catatan,tautan}', 'Muncul setelah muhaffizh merekomendasikan ujian (Tahfizh → Ujian).'),
  ('ujian_jadwal', 'Jadwal ujian tahfizh ke muhaffizh',
   E'{salam}, {nama}.\n\nJadwal *{jenis_ujian}* santri berikut telah ditetapkan:\n• Nama: *{nama_santri}*\n• Kelas: {kelas}\n• Halaqah: {halaqah}\n• Materi ujian: {materi}\n• Jadwal: *{jadwal}*\n• Penguji: {penguji}\n\nMohon santri disiapkan dan hadir tepat waktu.\n{penutup}\n{pengirim}',
   '{nama,jenis_ujian,nama_santri,kelas,halaqah,materi,jadwal,penguji}', 'Muncul setelah penguji menjadwalkan ujian (Tahfizh → Ujian).'),
  ('ujian_hasil', 'Hasil ujian tahfizh ke muhaffizh',
   E'{salam}, {nama}.\n\nBerikut hasil *{jenis_ujian}*:\n• Nama: *{nama_santri}*\n• Kelas: {kelas}\n• Halaqah: {halaqah}\n• Muhaffizh: {muhaffizh}\n• Materi ujian: {materi}\n• Nilai: Tajwid {nilai_tajwid}, Itqan {nilai_itqan}, nilai akhir *{nilai_akhir}*, predikat {predikat}\n• Keterangan: *{keterangan_ujian}*\n• Catatan perbaikan: {catatan_perbaikan}\n\n{penutup}\n{pengirim}\n{jabatan_pengirim}',
   '{nama,jenis_ujian,nama_santri,kelas,halaqah,muhaffizh,materi,nilai_tajwid,nilai_itqan,nilai_akhir,predikat,keterangan_ujian,catatan_perbaikan}', 'Muncul setelah penguji menyimpan nilai ujian (Tahfizh → Ujian).')
on conflict (kode) do nothing;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN — hasil yang benar: 4 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select '1. Kolom keterangan dan catatan perbaikan' as pemeriksaan,
       case when (select count(*) from information_schema.columns where table_schema = 'public' and table_name = 'tahfizh_exams'
                   and column_name in ('keterangan','catatan_perbaikan')) = 2 then 'Sesuai' else 'Periksa' end as hasil
union all
select '2. Penilaian ujian menerima keterangan',
       case when to_regprocedure('public.nilai_ujian(uuid,numeric,numeric,text,text,text)') is not null
             and to_regprocedure('public.nilai_ujian(uuid,numeric,numeric,text)') is null then 'Sesuai' else 'Periksa' end
union all
select '3. Daftar ujian memuat nomor HP muhaffizh',
       case when position('hp_muhaffizh' in pg_get_function_result('public.daftar_ujian(text,text)'::regprocedure)) > 0 then 'Sesuai' else 'Periksa' end
union all
select '4. Template WA ujian (3)',
       case when (select count(*) from public.wa_templates where kode in ('ujian_rekomendasi','ujian_jadwal','ujian_hasil')) = 3 then 'Sesuai' else 'Periksa' end;
