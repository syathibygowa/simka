-- SIMKA PRO | supabase/migrations/20261102012500_hal_terbuka_lama.sql | v1.0 | 14.9.2: jam Takhassus dari jadwal, guru pengganti jurnal mengajar, surat pindah ber-QR, hak akses Penilaian tingkat 1–2 | 18/10/2026
-- =====================================================================
-- SIMKA PRO · Migrasi 125: Penuntasan hal terbuka lama
--   1. Jam Takhassus dari jadwal: mapel berkelompok "Takhassus" (Jadwal Pelajaran → Pengaturan → Mapel) dihitung ke komponen
--      beban kerja "Pengajar Takhassus" (T_TAKHASSUS), mapel lain tetap ke "Guru mata pelajaran". 1 JP = jam_per_jp.
--   2. Guru pengganti jurnal mengajar: guru lain (pegawai yang mengajar atau berjabatan Guru) dapat mengisi jurnal kelas yang
--      ditinggal guru pengampunya lewat "Mengajar sebagai pengganti". Tercatat di teaching_journals.pengganti_id; pertemuan itu
--      tidak dihitung "terlaksana" bagi guru pengampu di Rekam Kepegawaian, tetapi terhitung pada bulan mengajar guru pengganti.
--   3. Surat Keterangan Pindah santri ber-QR: terdaftar di Cek Keabsahan (kode validasi), termasuk surat yang sudah terbit.
--   4. Hak akses Penilaian (fitur "nilai"): tingkat 1 Lihat dan 2 Input/ubah kini berpengaruh.
-- Jalankan SETELAH migrasi 12400. Aman dijalankan ulang.
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
-- 1. JAM TAKHASSUS DARI JADWAL
-- ---------------------------------------------------------------------
alter table public.subjects drop constraint if exists subjects_kelompok_check;
alter table public.subjects add constraint subjects_kelompok_check check (kelompok in ('umum','pondok','muatan_lokal','takhassus'));

create or replace function public.sinkron_jam_mengajar()
returns void language plpgsql security definer set search_path = public as $$
declare v_comp uuid; v_tk uuid; v_faktor numeric := coalesce((select (nilai->>'jam_per_jp')::numeric from institution_settings where kunci = 'jadwal_pelajaran'), 1);
  v_ket constant text := 'Otomatis dari jadwal pelajaran'; v_ket_tk constant text := 'Otomatis dari jadwal pelajaran (takhassus)';
begin
  select c.id into v_comp from workload_components c join functional_positions fp on fp.id = c.functional_position_id where fp.kode = 'GURU';
  select c.id into v_tk from workload_components c where c.kode = 'T_TAKHASSUS';
  -- Guru mata pelajaran: semua mapel terjadwal selain kelompok Takhassus
  if v_comp is not null then
    insert into employee_workloads (employee_id, component_id, jam, catatan)
    select cs.employee_id, v_comp, least(99, count(*) * v_faktor), v_ket
      from class_schedules cs join teaching_assignments t on t.id = cs.assignment_id join academic_years a on a.id = t.academic_year_id and a.aktif
      join subjects s on s.id = t.subject_id
     where s.kelompok <> 'takhassus'
     group by cs.employee_id
    on conflict (employee_id, component_id) do update set jam = excluded.jam, catatan = excluded.catatan, updated_at = now();
    delete from employee_workloads w where w.component_id = v_comp and w.catatan = v_ket
      and not exists (select 1 from class_schedules cs join teaching_assignments t on t.id = cs.assignment_id join subjects s on s.id = t.subject_id
                      join academic_years a on a.id = t.academic_year_id and a.aktif where cs.employee_id = w.employee_id and s.kelompok <> 'takhassus');
  end if;
  -- Pengajar Takhassus: mapel kelompok Takhassus
  if v_tk is not null then
    insert into employee_workloads (employee_id, component_id, jam, catatan)
    select cs.employee_id, v_tk, least(99, count(*) * v_faktor), v_ket_tk
      from class_schedules cs join teaching_assignments t on t.id = cs.assignment_id join academic_years a on a.id = t.academic_year_id and a.aktif
      join subjects s on s.id = t.subject_id
     where s.kelompok = 'takhassus'
     group by cs.employee_id
    on conflict (employee_id, component_id) do update set jam = excluded.jam, catatan = excluded.catatan, updated_at = now();
    delete from employee_workloads w where w.component_id = v_tk and w.catatan = v_ket_tk
      and not exists (select 1 from class_schedules cs join teaching_assignments t on t.id = cs.assignment_id join subjects s on s.id = t.subject_id
                      join academic_years a on a.id = t.academic_year_id and a.aktif where cs.employee_id = w.employee_id and s.kelompok = 'takhassus');
  end if;
end $$;
-- Sinkron ulang setelah mapel berubah kelompok
create or replace function public.tg_sinkron_jam_mengajar()
returns trigger language plpgsql security definer set search_path = public as $$ begin perform public.sinkron_jam_mengajar(); return null; end $$;
drop trigger if exists zz_sinkron_jam on public.subjects;
create trigger zz_sinkron_jam after update of kelompok on public.subjects for each statement execute function public.tg_sinkron_jam_mengajar();
select public.sinkron_jam_mengajar();

-- ---------------------------------------------------------------------
-- 2. GURU PENGGANTI PADA JURNAL MENGAJAR
-- ---------------------------------------------------------------------
alter table public.teaching_journals add column if not exists pengganti_id uuid references public.employees(id) on delete set null;
create index if not exists teaching_journals_pengganti_idx on public.teaching_journals (pengganti_id, tanggal) where pengganti_id is not null;

/** Pegawai yang boleh menjadi guru pengganti: punya penugasan mengajar di tahun ajaran aktif atau berjabatan fungsional Guru. */
create or replace function public._guru_aktif(p_emp uuid default null)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(p_emp, public.saya()) is not null and (
    exists (select 1 from teaching_assignments t join academic_years a on a.id = t.academic_year_id and a.aktif where t.employee_id = coalesce(p_emp, public.saya()))
    or exists (select 1 from employee_functions ef join functional_positions fp on fp.id = ef.functional_position_id
                where ef.employee_id = coalesce(p_emp, public.saya()) and fp.kode = 'GURU'))
$$;

/** Semua jam pelajaran pada satu tanggal (kecuali milik sendiri) untuk diisi guru pengganti. */
create or replace function public.slot_pengganti(p_tanggal date default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_tgl date := coalesce(p_tanggal, public.hari_ini()); v_dow int := extract(dow from coalesce(p_tanggal, public.hari_ini())); v_saya uuid := public.saya();
begin
  if v_saya is null then raise exception 'Akun Anda belum aktif.'; end if;
  if not (public._guru_aktif(v_saya) or public.admin_boleh('atur_jadwal')) then
    raise exception 'Hanya guru yang dapat mengisi jurnal sebagai guru pengganti.' using errcode = '42501'; end if;
  if v_tgl > public.hari_ini() then return '[]'; end if;
  if v_dow = 0 or public.libur_tugas(v_tgl, 'sekolah') then return '[]'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object(
      'tanggal', v_tgl, 'terbuka', public._jurnal_mengajar_terbuka(v_tgl),
      'assignment_id', t.id, 'period_id', p.id, 'jam_ke', p.nama, 'urutan', p.urutan, 'jam_mulai', p.jam_mulai, 'jam_selesai', p.jam_selesai,
      'group_id', g.id, 'kelas', g.nama, 'jenjang', g.jenjang, 'tingkat', g.tingkat, 'mapel', s.nama, 'kode_mapel', s.kode,
      'employee_id', t.employee_id, 'guru', e.nama_lengkap,
      'jurnal', (select jsonb_build_object('id', j.id, 'status', j.status, 'materi', j.materi, 'keterangan', j.keterangan, 'bab', j.bab, 'subbab', j.subbab,
                   'metode', j.metode, 'media', j.media, 'alat', j.alat, 'sumber', j.sumber, 'tujuan', j.tujuan, 'kegiatan', j.kegiatan, 'absen', j.absen,
                   'jumlah_anggota', j.jumlah_anggota, 'jumlah_hadir', j.jumlah_hadir,
                   'pengganti', (select nama_lengkap from employees where id = j.pengganti_id), 'milik_saya', j.pengganti_id = v_saya,
                   'oleh_guru', j.pengganti_id is null and j.employee_id = t.employee_id)
                 from teaching_journals j where j.assignment_id = t.id and j.tanggal = v_tgl and j.period_id = p.id),
      'terakhir', (select jsonb_build_object('tanggal', j4.tanggal, 'bab', j4.bab, 'subbab', j4.subbab, 'metode', j4.metode, 'media', j4.media, 'alat', j4.alat, 'sumber', j4.sumber)
                   from teaching_journals j4 where j4.assignment_id = t.id and j4.tanggal < v_tgl and j4.status = 'terlaksana'
                   order by j4.tanggal desc, j4.updated_at desc limit 1))
    order by g.jenjang desc, g.tingkat, g.nama, p.jam_mulai)
    from class_schedules cs join teaching_assignments t on t.id = cs.assignment_id join academic_years a on a.id = t.academic_year_id and a.aktif
    join lesson_periods p on p.id = cs.period_id join student_groups g on g.id = t.group_id join subjects s on s.id = t.subject_id
    join employees e on e.id = t.employee_id
    where cs.hari = v_dow and t.employee_id <> v_saya), '[]');
end $$;
revoke execute on function public.slot_pengganti(date) from public, anon;
grant execute on function public.slot_pengganti(date) to authenticated;

-- Simpan jurnal: guru pengganti boleh mengisi jam guru lain (selama belum diisi guru pengampunya)
select pg_temp.tambal('simpan_jurnal_mengajar',
  $c$    if t.employee_id <> v_saya and not public.admin_boleh('atur_jadwal') then raise exception 'Anda bukan guru pada penugasan ini.' using errcode = '42501'; end if;$c$,
  $c$    if t.employee_id <> v_saya and not public.admin_boleh('atur_jadwal')
       and not (coalesce((r->>'pengganti')::boolean, false) and public._guru_aktif(v_saya)) then
      raise exception 'Anda bukan guru pada penugasan ini. Bila Anda menggantikan guru lain, isi lewat "Mengajar sebagai pengganti".' using errcode = '42501'; end if;
    if coalesce((r->>'pengganti')::boolean, false) and t.employee_id <> v_saya and exists (select 1 from teaching_journals jx where jx.assignment_id = t.id
         and jx.tanggal = v_tgl and jx.period_id = (r->>'period_id')::uuid and jx.pengganti_id is null and jx.employee_id = t.employee_id) then
      raise exception 'Jurnal jam ini sudah diisi oleh guru pengampunya.'; end if;$c$,
  '_guru_aktif(v_saya)');
select pg_temp.tambal('simpan_jurnal_mengajar',
  E'    n := n + 1;\n  end loop;',
  E'    update teaching_journals set pengganti_id = case when coalesce((r->>''pengganti'')::boolean, false) and t.employee_id <> v_saya then v_saya end\n     where assignment_id = t.id and tanggal = v_tgl and period_id = (r->>''period_id'')::uuid;\n    n := n + 1;\n  end loop;',
  'set pengganti_id = case');
-- Guru pengganti dapat memuat daftar santri kelas yang digantikannya (untuk menandai ketidakhadiran)
select pg_temp.tambal('peserta_pelajaran', 'or t.group_id in (select public.kelompok_saya())) then',
  'or t.group_id in (select public.kelompok_saya()) or public._guru_aktif()) then', 'or public._guru_aktif())');
-- Jadwal mengajar guru pengampu menampilkan nama pengganti
select pg_temp.tambal('jadwal_mengajar', $c$'jumlah_hadir', j.jumlah_hadir)$c$,
  $c$'jumlah_hadir', j.jumlah_hadir, 'pengganti', (select nama_lengkap from employees where id = j.pengganti_id))$c$, $c$'pengganti', (select nama_lengkap$c$);
-- Rekam Kepegawaian: pertemuan yang diisi pengganti tidak dihitung terlaksana bagi guru pengampu
select pg_temp.tambal('rekam_kepegawaian',
  $c$where tj.assignment_id = ta.id and tj.tanggal between p_mulai and p_selesai and tj.status = 'terlaksana')$c$,
  $c$where tj.assignment_id = ta.id and tj.tanggal between p_mulai and p_selesai and tj.status = 'terlaksana' and tj.pengganti_id is null)$c$,
  $c$p_selesai and tj.status = 'terlaksana' and tj.pengganti_id is null$c$);
select pg_temp.tambal('rekam_kepegawaian',
  $c$where tj.assignment_id = ta.id and tj.status = 'terlaksana')$c$,
  $c$where tj.assignment_id = ta.id and tj.status = 'terlaksana' and tj.pengganti_id is null)$c$,
  $c$ta.id and tj.status = 'terlaksana' and tj.pengganti_id is null$c$);

-- ---------------------------------------------------------------------
-- 3. SURAT KETERANGAN PINDAH BER-QR
-- ---------------------------------------------------------------------
alter table public.student_mutations add column if not exists kode_validasi text;
alter table public.student_mutations add column if not exists document_id uuid;

create or replace function public._daftar_surat_pindah(p_mid uuid)
returns text language plpgsql security definer set search_path = public as $$
declare m record; v_kode text; v_doc uuid; v_isi jsonb; k signatories; d signatories;
begin
  select mu.*, s.nama_lengkap, s.nis, s.nisn into m from student_mutations mu join students s on s.id = mu.student_id where mu.id = p_mid and mu.jenis = 'keluar';
  if not found then return null; end if;
  v_kode := coalesce(m.kode_validasi, public._kode_dokumen());
  select * into k from signatories where aktif and jabatan_tertulis ilike case when m.jenjang = 'sma' then 'Kepala SMA%' else 'Kepala%Wustha%' end order by urutan limit 1;
  select * into d from signatories where aktif and (sumber_jabatan = 'DIREKTUR' or jabatan_tertulis ilike 'Direktur%') order by urutan limit 1;
  v_isi := jsonb_build_object('nomor', m.nomor_surat, 'nama', m.nama_lengkap, 'nis', m.nis, 'nisn', m.nisn, 'tanggal', m.tanggal, 'tujuan', m.sekolah,
                              'alasan', m.alasan, 'jenjang', m.jenjang, 'tingkat', m.tingkat);
  insert into document_registry (kode, jenis, jenis_nama, nomor, perihal, subjek, kop_kode, status, sidik, ref_tabel, ref_id, diterbitkan_pada, diterbitkan_oleh, mode_ttd, isi)
  values (v_kode, 'pindah_santri', 'Surat Keterangan Pindah', m.nomor_surat, 'Pindah ke ' || m.sekolah || ' terhitung ' || to_char(m.tanggal, 'DD/MM/YYYY'),
          m.nama_lengkap || ' (NIS ' || m.nis || ')', coalesce(m.kop, case when m.jenjang = 'sma' then 'sma' else 'wustha' end), 'sah', public._sidik(v_isi),
          'student_mutations', p_mid, m.created_at, m.oleh, 'elektronik', v_isi)
  on conflict (ref_tabel, ref_id) where ref_id is not null do update set nomor = excluded.nomor, perihal = excluded.perihal, subjek = excluded.subjek, sidik = excluded.sidik, isi = excluded.isi
  returning id, kode into v_doc, v_kode;
  delete from document_signatures where document_id = v_doc;
  insert into document_signatures (document_id, urutan, posisi, employee_id, nama, jabatan, niy, status, waktu)
  values (v_doc, 1, 'kanan', k.employee_id, coalesce(k.nama, '-'), coalesce(k.jabatan_tertulis, case when m.jenjang = 'sma' then 'Kepala SMA' else 'Kepala Kesetaraan Wustha' end), k.niy, 'ditandatangani', m.created_at);
  if d.id is not null then
    insert into document_signatures (document_id, urutan, posisi, employee_id, nama, jabatan, niy, status, waktu)
    values (v_doc, 2, 'kiri', d.employee_id, d.nama, d.jabatan_tertulis, d.niy, 'ditandatangani', m.created_at);
  end if;
  update student_mutations set kode_validasi = v_kode, document_id = v_doc where id = p_mid;
  return v_kode;
end $$;
revoke execute on function public._daftar_surat_pindah(uuid) from public, anon, authenticated;

select pg_temp.tambal('mutasi_keluar_santri', 'returning id into v_mid;', E'returning id into v_mid;\n  perform public._daftar_surat_pindah(v_mid);', '_daftar_surat_pindah');
-- Surat pindah yang sudah terbit sebelumnya ikut didaftarkan
select public._daftar_surat_pindah(id) from public.student_mutations where jenis = 'keluar' and kode_validasi is null;

-- ---------------------------------------------------------------------
-- 4. HAK AKSES PENILAIAN TINGKAT 1–2
--    1 Lihat      : menu Penilaian (baca saja), rekap pengisian semua jenjang, nilai dan rapor semua kelas
--    2 Input/ubah : seperti Lihat + mengisi/mengoreksi nilai mapel guru mana pun selama periode penilaian dibuka
--    3 Kelola     : tetap (mengatur penilaian, mengelola nilai, mencetak rapor)
-- ---------------------------------------------------------------------
select pg_temp.tambal('boleh_lihat_nilai', 'public.is_admin() or public.boleh_kelola_nilai()',
  'public.is_admin() or public.boleh_kelola_nilai() or public.tingkat_fitur(''nilai'') >= 1', 'tingkat_fitur(''nilai'') >= 1');
select pg_temp.tambal('_boleh_lihat_kelompok_rapor', 'public.is_admin() or public.boleh_kelola_nilai()',
  'public.is_admin() or public.boleh_kelola_nilai() or public.tingkat_fitur(''nilai'') >= 1', 'tingkat_fitur(''nilai'') >= 1');
select pg_temp.tambal('rekap_penilaian', 'v_semua := public.is_admin() or public.boleh_kelola_nilai()',
  'v_semua := public.is_admin() or public.boleh_kelola_nilai() or public.tingkat_fitur(''nilai'') >= 1', 'tingkat_fitur(''nilai'') >= 1');
select pg_temp.tambal('_cek_isi_nilai', 'if i.employee_id is distinct from public.saya() then',
  'if i.employee_id is distinct from public.saya() and public.tingkat_fitur(''nilai'') < 2 then', 'tingkat_fitur(''nilai'') < 2');
select pg_temp.tambal('hak_penilaian', 'public.boleh_kelola_nilai() kelola,',
  'public.boleh_kelola_nilai() kelola, public.tingkat_fitur(''nilai'') >= 1 lihat, public.tingkat_fitur(''nilai'') >= 2 isi,', ' lihat, public.tingkat_fitur');
select pg_temp.tambal('hak_penilaian', '''kelola'', h.kelola,', '''kelola'', h.kelola, ''lihat'', h.lihat, ''isi'', h.isi,', '''lihat'', h.lihat');
select pg_temp.tambal('hak_penilaian', 'h.p_sma or h.p_wustha or h.p_tahfizh)', 'h.p_sma or h.p_wustha or h.p_tahfizh or h.lihat)', 'h.p_tahfizh or h.lihat');
update public.features set arti = jsonb_build_object(
  '1', 'Membuka menu Penilaian (baca saja): rekap pengisian, pengaturan rapor, serta nilai dan rapor semua kelas',
  '2', 'Seperti Lihat, ditambah mengisi atau mengoreksi nilai mapel guru mana pun selama periode penilaian dibuka',
  '3', 'Membuka menu Penilaian: mengatur penilaian, mengelola nilai, dan mencetak rapor')
 where kode = 'nilai';

-- ---------------------------------------------------------------------
-- PEMERIKSAAN — hasil yang benar: 6 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select '1. Mapel kelompok Takhassus dihitung ke beban kerja' as pemeriksaan,
       case when position('takhassus' in pg_get_functiondef('public.sinkron_jam_mengajar()'::regprocedure)) > 0
             and position('takhassus' in (select pg_get_constraintdef(oid) from pg_constraint where conname = 'subjects_kelompok_check')) > 0 then 'Sesuai' else 'Periksa' end as hasil
union all
select '2. Guru pengganti dapat mengisi jurnal',
       case when to_regprocedure('public.slot_pengganti(date)') is not null
             and position('_guru_aktif(v_saya)' in pg_get_functiondef('public.simpan_jurnal_mengajar(jsonb)'::regprocedure)) > 0
             and position('set pengganti_id' in pg_get_functiondef('public.simpan_jurnal_mengajar(jsonb)'::regprocedure)) > 0 then 'Sesuai' else 'Periksa' end
union all
select '3. Rekam Kepegawaian memisahkan pertemuan pengganti',
       case when position('pengganti_id is null' in pg_get_functiondef('public.rekam_kepegawaian(uuid,date,date)'::regprocedure)) > 0 then 'Sesuai' else 'Periksa' end
union all
select '4. Surat keterangan pindah terdaftar ber-QR',
       case when position('_daftar_surat_pindah' in pg_get_functiondef('public.mutasi_keluar_santri(uuid,date,text,text)'::regprocedure)) > 0
             and not exists (select 1 from public.student_mutations where jenis = 'keluar' and kode_validasi is null) then 'Sesuai' else 'Periksa' end
union all
select '5. Hak akses Penilaian tingkat 1–2 berpengaruh',
       case when position('tingkat_fitur(''nilai'') >= 1' in pg_get_functiondef('public.boleh_lihat_nilai(uuid)'::regprocedure)) > 0
             and position('tingkat_fitur(''nilai'') < 2' in pg_get_functiondef('public._cek_isi_nilai(uuid,smallint)'::regprocedure)) > 0
             and position('h.lihat' in pg_get_functiondef('public.hak_penilaian()'::regprocedure)) > 0 then 'Sesuai' else 'Periksa' end
union all
select '6. Arti tingkat Penilaian diperbarui',
       case when (select arti->>'1' from public.features where kode = 'nilai') not ilike '%belum berpengaruh%' then 'Sesuai' else 'Periksa' end;
