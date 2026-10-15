-- SIMKA PRO | supabase/migrations/20261017010100_portal_wali_dokumen.sql | v1.0 | Fase 9 – Tahap 13.4.0 Dokumen santri di Portal Wali | 15/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 9 · Migrasi 101: Dokumen santri yang dapat diunduh wali (butir "Dokumen santri")
--   * Surat dari Persuratan yang sudah TERBIT dan SAH untuk santri itu, dengan template yang dipilih superadmin
--     (bawaan: Surat Keterangan Aktif Santri, Surat Keterangan Berkelakuan Baik/SKBB, SKL, Keterangan Prestasi,
--     Rekomendasi Sekolah).
--   * Dokumen tahfizh yang sudah terbit dan sah (bawaan: Suket Ujian Kenaikan Juz, Sertifikat Hafalan,
--     Sertifikat Tahfizhul Quran).
--   * Hanya dokumen bertanda tangan ELEKTRONIK yang dapat diunduh/dicetak dari portal (ber-QR Cek Keabsahan).
--     Dokumen bertanda tangan basah hanya tercantum dengan keterangan "ambil dokumen asli di Tata Usaha".
--   * Isi yang dicetak = salinan beku di registri dokumen (sama persis dengan dokumen resmi).
--   * Pengaturan portal_wali menambah kunci "dokumen" {surat:[kode template], tahfizh:[jenis]} yang dapat diubah superadmin.
-- Jalankan SETELAH migrasi 10000. Aman dijalankan ulang.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. PENGATURAN (nilai bawaan jenis dokumen)
-- ---------------------------------------------------------------------
create or replace function public._portal_set()
returns jsonb language sql stable security definer set search_path = public as $$
  with b as (select jsonb_build_object(
      'aktif', false, 'identitas', 'nis_nisn', 'lama_sesi_hari', 30, 'maks_salah', 5, 'kunci_menit', 15,
      'pesan_tutup', 'Portal Wali belum dibuka. Silakan hubungi pengasuh atau Tata Usaha pondok.',
      'butir', jsonb_build_object(
        'profil', true, 'pengasuh', true, 'kehadiran', true, 'perizinan', true, 'kunjungan', true, 'titipan', true,
        'sakit', false, 'hafalan', true, 'ujian', true, 'nilai', true, 'prestasi', true, 'dokumen', true,
        'keuangan', false, 'pengumuman', true),
      'dokumen', jsonb_build_object(
        'surat', jsonb_build_array('keterangan_aktif_santri','kelakuan_baik','keterangan_lulus','keterangan_prestasi','rekomendasi_sekolah'),
        'tahfizh', jsonb_build_array('suket_juz','sertifikat_hafalan','sertifikat_tahfizh'))) as v),
  s as (select coalesce((select nilai from institution_settings where kunci = 'portal_wali'), '{}'::jsonb) as v)
  select (b.v || (s.v - 'butir' - 'dokumen'))
         || jsonb_build_object('butir', (b.v->'butir') || coalesce(s.v->'butir', '{}'::jsonb))
         || jsonb_build_object('dokumen', (b.v->'dokumen') || coalesce(s.v->'dokumen', '{}'::jsonb))
    from b, s
$$;

create or replace function public.simpan_pengaturan_portal_wali(p jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare lama jsonb := public._portal_set(); baru jsonb; b jsonb := '{}'::jsonb; kk text; v_surat jsonb; v_tahfizh jsonb;
begin
  if not public.is_superadmin() then raise exception 'Hanya superadmin yang dapat mengubah pengaturan Portal Wali.' using errcode = '42501'; end if;
  for kk in select jsonb_object_keys(lama->'butir') loop
    b := b || jsonb_build_object(kk, coalesce((p->'butir'->>kk)::boolean, (lama->'butir'->>kk)::boolean, false));
  end loop;
  -- Jenis dokumen: hanya kode template yang ada dan jenis dokumen tahfizh yang dikenal
  v_surat := case when p->'dokumen' ? 'surat' then coalesce((select jsonb_agg(distinct x) from jsonb_array_elements_text(p->'dokumen'->'surat') x
                                                              where x in (select kode from letter_templates)), '[]'::jsonb)
                  else lama->'dokumen'->'surat' end;
  v_tahfizh := case when p->'dokumen' ? 'tahfizh' then coalesce((select jsonb_agg(distinct x) from jsonb_array_elements_text(p->'dokumen'->'tahfizh') x
                                                              where x in ('suket_juz','sertifikat_hafalan','sertifikat_tahfizh')), '[]'::jsonb)
                  else lama->'dokumen'->'tahfizh' end;
  baru := jsonb_build_object(
    'aktif', coalesce((p->>'aktif')::boolean, (lama->>'aktif')::boolean, false),
    'identitas', case when coalesce(p->>'identitas', lama->>'identitas') = 'nisn' then 'nisn' else 'nis_nisn' end,
    'lama_sesi_hari', greatest(1, least(180, coalesce((p->>'lama_sesi_hari')::int, (lama->>'lama_sesi_hari')::int, 30))),
    'maks_salah', greatest(3, least(10, coalesce((p->>'maks_salah')::int, (lama->>'maks_salah')::int, 5))),
    'kunci_menit', greatest(5, least(120, coalesce((p->>'kunci_menit')::int, (lama->>'kunci_menit')::int, 15))),
    'pesan_tutup', left(coalesce(nullif(trim(p->>'pesan_tutup'), ''), lama->>'pesan_tutup'), 300),
    'butir', b,
    'dokumen', jsonb_build_object('surat', v_surat, 'tahfizh', v_tahfizh));
  insert into institution_settings (kunci, nilai, updated_by) values ('portal_wali', baru, public.saya())
  on conflict (kunci) do update set nilai = excluded.nilai, updated_by = excluded.updated_by;
  return baru || jsonb_build_object('boleh_ubah', true);
end $$;

/** Daftar template surat santri untuk pilihan di Pengaturan Portal Wali. */
create or replace function public.pilihan_dokumen_portal_wali()
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform public._wajib_boleh_portal();
  return jsonb_build_object(
    'surat', coalesce((select jsonb_agg(jsonb_build_object('kode', t.kode, 'nama', t.nama, 'kategori', t.kategori) order by (t.kategori = 'santri') desc, t.urutan, t.nama)
                        from letter_templates t where t.aktif), '[]'::jsonb),
    'tahfizh', jsonb_build_array(
      jsonb_build_object('kode', 'suket_juz', 'nama', 'Surat Keterangan Ujian Kenaikan Juz'),
      jsonb_build_object('kode', 'sertifikat_hafalan', 'nama', 'Sertifikat Hafalan'),
      jsonb_build_object('kode', 'sertifikat_tahfizh', 'nama', 'Sertifikat Tahfizhul Quran')));
end $$;

-- ---------------------------------------------------------------------
-- 2. DOKUMEN SANTRI
-- ---------------------------------------------------------------------
/** Surat Persuratan milik santri: salah satu isian bertipe santri berisi id santri itu. */
create or replace function public._surat_milik_santri(p_nilai jsonb, p_santri uuid)
returns boolean language sql immutable as $$
  select exists (select 1 from jsonb_each(coalesce(p_nilai, '{}'::jsonb)) e
                  where jsonb_typeof(e.value) = 'object' and e.value->>'id' = p_santri::text)
$$;

create or replace function public._portal_dokumen(p_santri uuid, p_set jsonb, p jsonb)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_surat text[]; v_tahfizh text[];
begin
  select coalesce(array_agg(x), '{}') into v_surat from jsonb_array_elements_text(coalesce(p_set->'dokumen'->'surat', '[]')) x;
  select coalesce(array_agg(x), '{}') into v_tahfizh from jsonb_array_elements_text(coalesce(p_set->'dokumen'->'tahfizh', '[]')) x;
  return jsonb_build_object('dokumen', coalesce((
    select jsonb_agg(z order by z->>'tanggal' desc) from (
      select jsonb_build_object('sumber', 'surat', 'id', o.id, 'nama', o.jenis_nama, 'nomor', coalesce(o.nomor, d.nomor), 'tanggal', o.tanggal_surat,
                                'perihal', o.perihal, 'mode_ttd', d.mode_ttd, 'kode', case when d.mode_ttd = 'elektronik' then d.kode end,
                                'unduh', d.mode_ttd = 'elektronik') z
        from outgoing_letters o
        join letter_templates t on t.id = o.template_id
        join document_registry d on d.id = o.document_id and d.status = 'sah'
       where o.status = 'terbit' and t.kode = any (v_surat) and public._surat_milik_santri(o.nilai, p_santri)
      union all
      select jsonb_build_object('sumber', 'tahfizh', 'id', x.id,
                                'nama', case x.jenis when 'suket_juz' then 'Surat Keterangan Ujian Kenaikan Juz' when 'sertifikat_hafalan' then 'Sertifikat Hafalan'
                                                     else 'Sertifikat Tahfizhul Quran' end,
                                'nomor', x.nomor, 'tanggal', x.tanggal, 'perihal', null, 'mode_ttd', x.mode_ttd,
                                'kode', case when x.mode_ttd = 'elektronik' then g.kode end, 'unduh', x.mode_ttd = 'elektronik')
        from tahfizh_documents x join document_registry g on g.id = x.document_id and g.status = 'sah'
       where x.student_id = p_santri and x.status = 'terbit' and x.jenis = any (v_tahfizh)) q(z)), '[]'::jsonb));
end $$;

/** Isi satu dokumen untuk dicetak di portal (salinan beku). Hanya dokumen elektronik milik santri sesi ini. */
create or replace function public._portal_dokumen_buka(p_santri uuid, p_set jsonb, p jsonb)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_id uuid; o outgoing_letters; d document_registry; x tahfizh_documents; v_daftar jsonb;
begin
  begin v_id := nullif(p->>'id', '')::uuid; exception when others then v_id := null; end;
  -- Dokumen harus termasuk daftar yang boleh dilihat santri ini (jenis yang dinyalakan, sah, elektronik)
  v_daftar := public._portal_dokumen(p_santri, p_set, '{}'::jsonb)->'dokumen';
  if v_id is null or not exists (select 1 from jsonb_array_elements(v_daftar) e where e->>'id' = v_id::text and (e->>'unduh')::boolean) then
    return jsonb_build_object('galat', 'Dokumen tidak ditemukan atau tidak dapat diunduh dari portal.');
  end if;
  if p->>'sumber' = 'tahfizh' then
    select * into x from tahfizh_documents where id = v_id;
    select * into d from document_registry where id = x.document_id;
    return jsonb_build_object('sumber', 'tahfizh', 'dok', jsonb_build_object(
      'id', x.id, 'jenis', x.jenis, 'nomor', x.nomor, 'tanggal', x.tanggal, 'tanggal_hijriah', x.tanggal_hijriah, 'data', x.data,
      'mode_ttd', x.mode_ttd, 'status', x.status, 'kode', d.kode, 'status_dokumen', d.status,
      'ttd', coalesce((select jsonb_agg(jsonb_build_object('urutan', s.urutan, 'nama', s.nama, 'jabatan', s.jabatan, 'niy', s.niy, 'status', s.status,
                        'waktu', s.waktu, 'basah', s.catatan = 'basah') order by s.urutan) from document_signatures s where s.document_id = d.id), '[]'::jsonb)));
  end if;
  select * into o from outgoing_letters where id = v_id;
  select * into d from document_registry where id = o.document_id;
  return jsonb_build_object('sumber', 'surat', 'surat', jsonb_build_object(
    'id', o.id, 'jenis_nama', o.jenis_nama, 'nomor', coalesce(o.nomor, d.nomor), 'kop_kode', o.kop_kode, 'tanggal_surat', o.tanggal_surat,
    'mode_ttd', o.mode_ttd, 'isi', d.isi, 'kode', d.kode, 'status', d.status,
    'ttd', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'posisi', s.posisi, 'urutan', s.urutan, 'nama', s.nama, 'jabatan', s.jabatan,
                       'niy', s.niy, 'status', s.status, 'waktu', s.waktu, 'catatan', s.catatan) order by s.urutan)
                     from document_signatures s where s.document_id = d.id), '[]'::jsonb)));
end $$;

-- ---------------------------------------------------------------------
-- 3. PINTU PORTAL (13.4.0)
-- ---------------------------------------------------------------------
create or replace function public.portal_data(p_token text, p_bagian text, p jsonb default '{}'::jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare v_set jsonb := public._portal_set(); gs guardian_sessions; v_butir text; hasil jsonb;
begin
  if not coalesce((v_set->>'aktif')::boolean, false) then
    return jsonb_build_object('tutup', true, 'pesan', v_set->>'pesan_tutup');
  end if;
  gs := public._portal_sesi(p_token);
  if gs.id is null then return jsonb_build_object('sesi_berakhir', true); end if;
  v_butir := case when p_bagian in ('kehadiran','perizinan','kunjungan','titipan','sakit','hafalan','ujian','nilai','prestasi','keuangan','pengumuman') then p_bagian
                  when p_bagian in ('dokumen','dokumen_buka') then 'dokumen' end;
  if v_butir is not null and not public._portal_butir(v_set, v_butir) then
    return jsonb_build_object('nonaktif', true, 'butir', v_set->'butir');
  end if;
  p := coalesce(p, '{}'::jsonb);
  case coalesce(p_bagian, '')
    when 'beranda' then
      hasil := public._portal_beranda(gs.student_id, v_set, gs.hubungan);
      if public._portal_butir(v_set, 'pengumuman') then
        hasil := hasil || jsonb_build_object('pengumuman_baru', (
          select count(*) from guardian_announcement_targets t join guardian_announcements a on a.id = t.announcement_id
           where t.student_id = gs.student_id and t.dibaca_pada is null and (a.tampil_sampai is null or a.tampil_sampai >= public.hari_ini())));
      end if;
      return hasil;
    when 'kehadiran'    then return public._portal_kehadiran(gs.student_id, v_set, p);
    when 'perizinan'    then return public._portal_perizinan(gs.student_id, v_set, p);
    when 'kunjungan'    then return public._portal_kunjungan(gs.student_id, v_set, p);
    when 'titipan'      then return public._portal_titipan(gs.student_id, v_set, p);
    when 'sakit'        then return public._portal_sakit(gs.student_id, v_set, p);
    when 'hafalan'      then return public._portal_hafalan(gs.student_id, v_set, p);
    when 'ujian'        then return public._portal_ujian(gs.student_id, v_set, p);
    when 'nilai'        then return public._portal_nilai(gs.student_id, v_set, p);
    when 'prestasi'     then return public._portal_prestasi(gs.student_id, v_set, p);
    when 'keuangan'     then return public._portal_keuangan(gs.student_id, v_set, p);
    when 'pengumuman'   then return public._portal_pengumuman(gs.student_id, v_set, p);
    when 'dokumen'      then return public._portal_dokumen(gs.student_id, v_set, p);
    when 'dokumen_buka' then return public._portal_dokumen_buka(gs.student_id, v_set, p);
    else return jsonb_build_object('galat', 'Bagian portal tidak dikenal.');
  end case;
end $$;

do $$ declare f text; begin
  foreach f in array array['_portal_set()','_surat_milik_santri(jsonb,uuid)','_portal_dokumen(uuid,jsonb,jsonb)','_portal_dokumen_buka(uuid,jsonb,jsonb)'] loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
  end loop;
  execute 'revoke execute on function public.portal_data(text,text,jsonb) from public';
  execute 'grant execute on function public.portal_data(text,text,jsonb) to anon, authenticated';
  foreach f in array array['simpan_pengaturan_portal_wali(jsonb)','pilihan_dokumen_portal_wali()'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- PEMERIKSAAN — hasil yang benar: 3 baris "Sesuai"
select '1. Jenis dokumen santri bawaan di pengaturan Portal Wali' as pemeriksaan,
       case when jsonb_array_length(public._portal_set()->'dokumen'->'surat') >= 1 and jsonb_array_length(public._portal_set()->'dokumen'->'tahfizh') = 3
            then 'Sesuai' else 'Periksa' end as hasil
union all
select '2. Fungsi dokumen portal tertutup bagi pengguna tanpa login',
       case when not has_function_privilege('anon', 'public._portal_dokumen_buka(uuid,jsonb,jsonb)', 'execute')
             and has_function_privilege('anon', 'public.portal_data(text,text,jsonb)', 'execute') then 'Sesuai' else 'Periksa' end
union all
select '3. Template SKL, SKBB, dan Keterangan Aktif tersedia',
       case when (select count(*) from letter_templates where kode in ('keterangan_aktif_santri','kelakuan_baik','keterangan_lulus')) = 3 then 'Sesuai' else 'Periksa (template belum ada)' end;
