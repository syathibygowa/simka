-- SIMKA PRO | supabase/migrations/20261017009900_portal_wali_akademik.sql | v1.0 | Fase 9 – Tahap 13.2.0 Hafalan, ujian, nilai rapor, prestasi, keuangan | 15/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 9 · Migrasi 99: data Portal Wali tahap 13.2.0 (Blueprint Bagian 26)
--   portal_data(token, bagian, p) menambah bagian:
--   * 'hafalan'  : program, posisi sabaq/sabqi/manzil, total juz resmi beserta daftar juz, capaian bulanan yang SUDAH DISAHKAN
--                  (12 bulan terakhir), dan riwayat setoran pada periode p (paling panjang satu semester).
--   * 'ujian'    : ujian kenaikan juz dan sertifikasi yang selesai dinilai, serta UTAS yang sudah final.
--   * 'nilai'    : nilai rapor per mapel HANYA untuk periode penilaian yang sudah DITUTUP (kelas yang pernah diikuti santri),
--                  dengan predikat, catatan wali kelas, kehadiran rapor (hari), pengembangan diri, dan keputusan akhir tahun.
--                  p = {group, semester} memilih periode; bawaan periode tertutup terbaru.
--   * 'prestasi' : prestasi santri yang tercatat.
--   * 'keuangan' : tagihan (belum lunas dan 12 bulan terakhir), pembayaran sah 12 bulan terakhir, total dan tunggakan.
--                  Hanya bila butir "Keuangan" dinyalakan superadmin (bawaan mati). Tanpa unduh kuitansi.
-- Jalankan SETELAH migrasi 9800. Aman dijalankan ulang.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. HAFALAN DAN UJIAN
-- ---------------------------------------------------------------------
create or replace function public._portal_hafalan(p_santri uuid, p_set jsonb, p jsonb)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare r record; t student_tahfizh; v_hq uuid;
begin
  select * into r from public._portal_rentang(p);
  select * into t from student_tahfizh where student_id = p_santri;
  select g.id into v_hq from group_members m join student_groups g on g.id = m.group_id and g.jenis = 'halaqah'
    join academic_years a on a.id = g.academic_year_id and a.aktif where m.student_id = p_santri and m.selesai is null limit 1;
  return jsonb_build_object(
    'mulai', r.mulai, 'selesai', r.selesai,
    'program', coalesce(t.program, 'reguler'),
    'sabaq_hal', coalesce(t.sabaq_hal, 0), 'sabqi_hal', coalesce(t.sabqi_hal, 0), 'manzil_hal', coalesce(t.manzil_hal, 0),
    'juz_sedang', t.juz_sedang, 'posisi_pada', t.posisi_pada,
    'halaqah', (select nama from student_groups where id = v_hq),
    'juz', coalesce((select jsonb_agg(jsonb_build_object('juz', j.juz, 'sumber', j.sumber, 'tanggal', j.tanggal) order by j.juz)
                       from juz_achievements j where j.student_id = p_santri), '[]'::jsonb),
    -- Capaian bulanan: hanya yang sudah disahkan validator (salinan beku)
    'bulanan', coalesce((select jsonb_agg(jsonb_build_object('bulan', b.bulan, 'status', b.status, 'tambah_hal', b.tambah_hal,
                                   'target_hal', b.target_hal, 'posisi_akhir_hal', b.posisi_akhir_hal, 'total_resmi', b.total_resmi,
                                   'alasan_murojaah', b.alasan_murojaah) order by b.bulan desc)
                           from monthly_achievements b
                          where b.student_id = p_santri and b.disahkan_pada is not null
                            and b.bulan >= (date_trunc('month', public.hari_ini()) - interval '11 months')::date), '[]'::jsonb),
    'setoran', coalesce((select jsonb_agg(jsonb_build_object('tanggal', l.tanggal, 'sesi', s.nama_sesi, 'jam', to_char(s.jam_mulai, 'HH24.MI'),
                                   'sabaq_hal', l.sabaq_hal, 'sabqi_hal', l.sabqi_hal, 'manzil_hal', l.manzil_hal, 'tambah_hal', l.tambah_hal,
                                   'catatan', nullif(trim(l.catatan), '')) order by l.tanggal desc, s.jam_mulai desc nulls last)
                           from memorization_logs l join memorization_sessions s on s.id = l.session_id
                          where l.student_id = p_santri and l.tanggal between r.mulai and r.selesai), '[]'::jsonb));
end $$;

create or replace function public._portal_ujian(p_santri uuid, p_set jsonb, p jsonb)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  return jsonb_build_object(
    'ujian', coalesce((select jsonb_agg(jsonb_build_object('jenis', x.jenis, 'juz', x.juz, 'jenjang', x.jenjang, 'ujian_ke', x.ujian_ke,
                          'tajwid', x.nilai_tajwid, 'itqan', x.nilai_itqan, 'nilai_akhir', x.nilai_akhir, 'huruf', x.huruf, 'predikat', x.predikat,
                          'hasil', x.hasil, 'diuji_pada', x.diuji_pada, 'catatan', nullif(trim(x.catatan_penguji), ''),
                          'penguji', (select e.nama_lengkap from employees e where e.id = x.penguji_id)) order by x.diuji_pada desc)
                         from tahfizh_exams x where x.student_id = p_santri and x.status = 'selesai'), '[]'::jsonb),
    'utas', coalesce((select jsonb_agg(jsonb_build_object('ta', a.nama, 'semester', u.semester, 'juz', u.juz, 'total_juz', u.total_juz,
                          'tajwid', u.tajwid, 'itqan', u.itqan, 'nilai_akhir', u.nilai_akhir, 'huruf', u.huruf, 'tuntas', u.tuntas,
                          'diuji_pada', u.diuji_pada,
                          'predikat', (select case when coalesce(rs.bahasa_predikat, 'arab') = 'arab' then coalesce(rp.sebutan_arab, rp.sebutan) else rp.sebutan end
                                         from report_predicates rp left join report_settings rs on rs.academic_year_id = u.academic_year_id and rs.jenis = 'tahfizh'
                                        where rp.academic_year_id = u.academic_year_id and rp.kelompok = 'utas'
                                          and u.nilai_akhir between rp.nilai_min and rp.nilai_maks limit 1))
                       order by a.mulai desc, u.semester desc)
                         from utas_results u join academic_years a on a.id = u.academic_year_id
                        where u.student_id = p_santri and u.status = 'final'), '[]'::jsonb));
end $$;

-- ---------------------------------------------------------------------
-- 2. NILAI RAPOR (hanya periode yang sudah ditutup)
-- ---------------------------------------------------------------------
create or replace function public._portal_nilai(p_santri uuid, p_set jsonb, p jsonb)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_pilihan jsonb; v_group uuid; v_smt smallint; g student_groups; v_ta academic_years; r record; v_per grade_periods;
begin
  -- Periode yang boleh dilihat: kelas yang pernah diikuti santri × semester yang periodenya sudah ditutup
  select coalesce(jsonb_agg(jsonb_build_object('group', x.gid, 'semester', x.semester, 'kelas', x.kelas, 'ta', x.ta, 'jenjang', x.jenjang)
                            order by x.ta_mulai desc, x.semester desc), '[]'::jsonb)
    into v_pilihan
    from (select distinct g2.id gid, gp.semester, g2.nama kelas, a.nama ta, a.mulai ta_mulai, g2.jenjang
            from group_members m join student_groups g2 on g2.id = m.group_id and g2.jenis = 'kelas' and g2.jenjang in ('sma','wustha')
            join academic_years a on a.id = g2.academic_year_id
            join grade_periods gp on gp.academic_year_id = g2.academic_year_id and gp.jenis = g2.jenjang and gp.status = 'ditutup'
           where m.student_id = p_santri) x;
  if jsonb_array_length(v_pilihan) = 0 then
    return jsonb_build_object('pilihan', v_pilihan, 'kosong', true);
  end if;
  -- Pilihan wali (harus termasuk daftar), bawaan yang terbaru
  select (e->>'group')::uuid, (e->>'semester')::smallint into v_group, v_smt
    from jsonb_array_elements(v_pilihan) e
   where (e->>'group') = coalesce(p->>'group', '') and (e->>'semester') = coalesce(p->>'semester', '') limit 1;
  if v_group is null then
    v_group := (v_pilihan->0->>'group')::uuid; v_smt := (v_pilihan->0->>'semester')::smallint;
  end if;
  select * into g from student_groups where id = v_group;
  select * into v_ta from academic_years where id = g.academic_year_id;
  select * into v_per from grade_periods where academic_year_id = g.academic_year_id and jenis = g.jenjang and semester = v_smt;
  select * into r from public.rentang_semester(g.academic_year_id, v_smt);
  return jsonb_build_object(
    'pilihan', v_pilihan, 'group', v_group, 'semester', v_smt, 'kelas', g.nama, 'jenjang', g.jenjang, 'tingkat', g.tingkat, 'ta', v_ta.nama,
    'tanggal_rapor', v_per.tanggal_rapor,
    'label_ambang', (select coalesce(s.label_ambang, 'KKM') from report_settings s where s.academic_year_id = g.academic_year_id and s.jenis = g.jenjang),
    'mapel', coalesce((
      select jsonb_agg(jsonb_build_object('urutan', m.urutan, 'kelompok', m.kelompok, 'nama', m.nama, 'kkm', m.kkm,
                         'nilai', n.nilai, 'keterampilan', n.keterampilan, 'deskripsi', n.deskripsi,
                         'predikat', (select rp.huruf from report_predicates rp where rp.academic_year_id = g.academic_year_id and rp.kelompok = g.jenjang
                                        and round(n.nilai) between rp.nilai_min and rp.nilai_maks limit 1),
                         'tuntas', case when n.nilai is null then null else n.nilai >= coalesce(m.kkm, 0) end)
                       order by m.urutan, m.nama)
        from report_subjects m
        left join (select * from public.nilai_rapor_kelas(v_group, v_smt) z where z.student_id = p_santri) n on n.report_subject_id = m.id
       where m.academic_year_id = g.academic_year_id and m.jenis = g.jenjang and m.tingkat = g.tingkat and m.aktif), '[]'::jsonb),
    'kehadiran', (select jsonb_build_object('hari', k.hari, 'hadir', k.hadir, 'sakit', k.sakit, 'izin', k.izin, 'absen', k.absen)
                    from public.kehadiran_harian(v_group, r.mulai, r.selesai) k where k.student_id = p_santri),
    'pd', coalesce((select jsonb_agg(jsonb_build_object('kegiatan', eg.nama, 'nilai', x.nilai, 'deskripsi', x.deskripsi) order by eg.nama)
                      from report_extracurricular x join student_groups eg on eg.id = x.group_id
                     where x.student_id = p_santri and x.academic_year_id = g.academic_year_id and x.semester = v_smt and x.nilai is not null), '[]'::jsonb),
    'catatan', (select n.teks from report_notes n where n.student_id = p_santri and n.academic_year_id = g.academic_year_id and n.semester = v_smt and n.jenis = 'wali'),
    'keputusan', case when v_smt = 2 then (select jsonb_build_object('keputusan', d.keputusan, 'ke_tingkat', d.ke_tingkat)
                   from report_decisions d where d.student_id = p_santri and d.academic_year_id = g.academic_year_id) end);
end $$;

-- ---------------------------------------------------------------------
-- 3. PRESTASI DAN KEUANGAN
-- ---------------------------------------------------------------------
create or replace function public._portal_prestasi(p_santri uuid, p_set jsonb, p jsonb)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('prestasi', coalesce((select jsonb_agg(jsonb_build_object('tanggal', a.tanggal, 'bidang', a.bidang, 'tingkat', a.tingkat,
            'nama_kegiatan', a.nama_kegiatan, 'capaian', a.capaian, 'penyelenggara', a.penyelenggara, 'keterangan', a.keterangan) order by a.tanggal desc)
           from student_achievements a where a.student_id = p_santri), '[]'::jsonb))
$$;

create or replace function public._portal_keuangan(p_santri uuid, p_set jsonb, p jsonb)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_hari date := public.hari_ini(); v_batas date := (public.hari_ini() - interval '12 months')::date;
begin
  return jsonb_build_object(
    'ringkas', (select jsonb_build_object(
        'tagihan', coalesce(sum(b.nominal), 0), 'dibayar', coalesce(sum(b.dibayar), 0),
        'sisa', coalesce(sum(b.nominal - b.dibayar), 0),
        'tunggakan', coalesce(sum(b.nominal - b.dibayar) filter (where b.jatuh_tempo < v_hari), 0),
        'jumlah_tunggak', count(*) filter (where b.jatuh_tempo < v_hari and b.nominal > b.dibayar))
       from bills b where b.student_id = p_santri and b.status in ('belum','sebagian')),
    'tagihan', coalesce((select jsonb_agg(jsonb_build_object('nama', b.nama, 'tanggal_tagih', b.tanggal_tagih, 'jatuh_tempo', b.jatuh_tempo,
                           'standar', b.standar, 'potongan', b.potongan, 'nominal', b.nominal, 'dibayar', b.dibayar, 'status', b.status,
                           'lewat', b.status in ('belum','sebagian') and b.jatuh_tempo < v_hari) order by b.jatuh_tempo desc, b.nama)
                          from bills b where b.student_id = p_santri and b.status <> 'batal'
                           and (b.status in ('belum','sebagian') or b.tanggal_tagih >= v_batas)), '[]'::jsonb),
    'pembayaran', coalesce((select jsonb_agg(jsonb_build_object('tanggal', y.tanggal, 'nomor', y.nomor, 'jumlah', y.jumlah, 'cara', y.cara,
                           'riwayat', y.riwayat) order by y.tanggal desc, y.created_at desc)
                          from payments y where y.student_id = p_santri and y.status = 'sah' and y.tanggal >= v_batas), '[]'::jsonb),
    'rekening', (select nilai->'rekening' from institution_settings where kunci = 'keuangan'));
end $$;

-- ---------------------------------------------------------------------
-- 4. PINTU PORTAL (13.2.0)
-- ---------------------------------------------------------------------
create or replace function public.portal_data(p_token text, p_bagian text, p jsonb default '{}'::jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare v_set jsonb := public._portal_set(); gs guardian_sessions; v_butir text;
begin
  if not coalesce((v_set->>'aktif')::boolean, false) then
    return jsonb_build_object('tutup', true, 'pesan', v_set->>'pesan_tutup');
  end if;
  gs := public._portal_sesi(p_token);
  if gs.id is null then return jsonb_build_object('sesi_berakhir', true); end if;
  -- Butir informasi yang harus dinyalakan untuk setiap bagian (nama bagian = kode butir)
  v_butir := case when p_bagian in ('kehadiran','perizinan','kunjungan','titipan','sakit','hafalan','ujian','nilai','prestasi','keuangan')
                  then p_bagian end;
  if v_butir is not null and not public._portal_butir(v_set, v_butir) then
    return jsonb_build_object('nonaktif', true, 'butir', v_set->'butir');
  end if;
  p := coalesce(p, '{}'::jsonb);
  case coalesce(p_bagian, '')
    when 'beranda'   then return public._portal_beranda(gs.student_id, v_set, gs.hubungan);
    when 'kehadiran' then return public._portal_kehadiran(gs.student_id, v_set, p);
    when 'perizinan' then return public._portal_perizinan(gs.student_id, v_set, p);
    when 'kunjungan' then return public._portal_kunjungan(gs.student_id, v_set, p);
    when 'titipan'   then return public._portal_titipan(gs.student_id, v_set, p);
    when 'sakit'     then return public._portal_sakit(gs.student_id, v_set, p);
    when 'hafalan'   then return public._portal_hafalan(gs.student_id, v_set, p);
    when 'ujian'     then return public._portal_ujian(gs.student_id, v_set, p);
    when 'nilai'     then return public._portal_nilai(gs.student_id, v_set, p);
    when 'prestasi'  then return public._portal_prestasi(gs.student_id, v_set, p);
    when 'keuangan'  then return public._portal_keuangan(gs.student_id, v_set, p);
    else return jsonb_build_object('galat', 'Bagian portal tidak dikenal.');
  end case;
end $$;

do $$ declare f text; begin
  foreach f in array array['_portal_hafalan(uuid,jsonb,jsonb)','_portal_ujian(uuid,jsonb,jsonb)','_portal_nilai(uuid,jsonb,jsonb)',
                           '_portal_prestasi(uuid,jsonb,jsonb)','_portal_keuangan(uuid,jsonb,jsonb)'] loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
  end loop;
  execute 'revoke execute on function public.portal_data(text,text,jsonb) from public';
  execute 'grant execute on function public.portal_data(text,text,jsonb) to anon, authenticated';
end $$;

-- PEMERIKSAAN — hasil yang benar: 3 baris "Sesuai"
select '1. Bagian portal hafalan, ujian, nilai, prestasi, keuangan' as pemeriksaan,
       case when (select count(*) from pg_proc where pronamespace = 'public'::regnamespace and proname in
             ('_portal_hafalan','_portal_ujian','_portal_nilai','_portal_prestasi','_portal_keuangan')) = 5 then 'Sesuai' else 'Periksa' end as hasil
union all
select '2. Pembantu portal tertutup bagi pengguna tanpa login',
       case when not has_function_privilege('anon', 'public._portal_keuangan(uuid,jsonb,jsonb)', 'execute')
             and has_function_privilege('anon', 'public.portal_data(text,text,jsonb)', 'execute') then 'Sesuai' else 'Periksa' end
union all
select '3. Keuangan tetap mengikuti sakelar superadmin (bawaan mati)',
       case when (select nilai->'butir' ? 'keuangan' from institution_settings where kunci = 'portal_wali') then 'Sesuai' else 'Periksa' end;
