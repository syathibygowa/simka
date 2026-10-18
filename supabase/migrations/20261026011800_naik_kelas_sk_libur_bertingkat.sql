-- SIMKA PRO | supabase/migrations/20261026011800_naik_kelas_sk_libur_bertingkat.sql | v1.0 | 14.5.0: naik kelas per jenjang + SK Kenaikan Kelas lewat Persuratan; libur santri bertingkat | 18/10/2026
-- =====================================================================
-- A. NAIK KELAS PER JENJANG DAN SK KENAIKAN KELAS
--    * rencana_kenaikan(): usulan keputusan diambil dari keputusan rapor wali kelas (semester 2) bila ada
--      (sumber 'rapor'), selain itu otomatis (naik; kelas 12 lulus). Tetap dapat diubah di menu Naik Kelas.
--    * Template surat "SK Kenaikan Kelas" (format nomor SK, kode QR): diktum + LAMPIRAN daftar santri (tabel) yang tercetak
--      sesudah tanda tangan. Isian jenis baru "tabel" (data otomatis) pada mesin template surat.
--    * usul_sk_kenaikan({academic_year_id (draf TA baru), jenjang, signatory_id?, tanggal_rapat?}): menyusun SK satu jenjang
--      dari keputusan kenaikan pada draf tahun ajaran → surat keluar berstatus "Diperiksa TU" (nomor SK, tanda tangan
--      elektronik mengikuti alur Persuratan) → Tata Usaha diberi notifikasi. Riwayat di tabel promotion_decrees.
--    * daftar_sk_kenaikan(ta): SK per jenjang beserta status suratnya.
-- B. LIBUR SANTRI BERTINGKAT
--    * holiday_periods.mode: 'syarat' (seperti sebelumnya: boleh/tidak libur) | 'bertingkat' (SEMUA santri libur; lama libur
--      sesuai syarat yang terpenuhi). holiday_periods.tingkat = [{kode, nama, pulang_pada, kembali_batas, syarat}] berurutan
--      dari yang terbaik; tingkat terakhir = santri lainnya (tanpa syarat). Contoh: 3 hari / 2 hari / 1 hari, atau 2 hari / 2 hari.
--    * holiday_eligibility.tingkat_otomatis, tingkat (keputusan; dapat diubah dengan alasan). Izin libur dibuat dengan waktu
--      pulang/kembali sesuai tingkatnya; perubahan tingkat setelah disahkan memperbarui izin yang belum dipakai.
-- Jalankan SETELAH migrasi 11700. Aman dijalankan ulang.
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

-- =====================================================================
-- A. NAIK KELAS
-- =====================================================================
drop function if exists public.rencana_kenaikan();
create function public.rencana_kenaikan()
returns table (student_id uuid, nis text, nama text, jenis_kelamin text, jenjang text, tingkat smallint, rombel text, status text, usulan text,
               sumber_usulan text, catatan_rapor text)
language sql stable security definer set search_path = public as $$
  select s.id, s.nis, s.nama_lengkap, s.jenis_kelamin, s.jenjang, s.tingkat,
         (select g.nama from group_members m join student_groups g on g.id = m.group_id join academic_years a on a.id = g.academic_year_id and a.aktif
          where m.student_id = s.id and m.selesai is null and g.jenis = 'kelas' limit 1),
         s.status,
         coalesce(case d.keputusan when 'tidak_lulus' then 'tinggal' else d.keputusan end, case when s.tingkat >= 12 then 'lulus' else 'naik' end),
         case when d.keputusan is not null then 'rapor' else 'otomatis' end, d.catatan
  from students s
  left join report_decisions d on d.student_id = s.id and d.academic_year_id = (select id from academic_years where aktif limit 1)
  where s.status in ('aktif','nonaktif') and public.boleh_ganti_ta()
  order by s.jenjang, s.tingkat, s.nama_lengkap
$$;
revoke execute on function public.rencana_kenaikan() from public, anon;
grant execute on function public.rencana_kenaikan() to authenticated;

-- Isian surat jenis "tabel" (data otomatis) diizinkan pada template
select pg_temp.tambal('simpan_template_surat', '''pegawai'',''santri'',''daftar'',''daftar_pegawai'')',
  '''pegawai'',''santri'',''daftar'',''daftar_pegawai'',''tabel'')', '''daftar_pegawai'',''tabel''');

-- Template SK Kenaikan Kelas (isi awal; dapat disunting Tata Usaha di Persuratan → Template)
insert into public.letter_templates (kode, nama, kategori, perihal_kode, format_nomor, dk, kop_kode, bentuk, judul, subjudul, hal_bawaan, kepada_bawaan,
                                     opsi, isi, isian, penanda, aktif, bawaan, urutan)
values ('sk_kenaikan_kelas', 'SK Kenaikan Kelas', 'santri', 'QR', 'sk', 'D', 'pondok', 'tengah', 'KEPUTUSAN {penanda.jabatan}',
  E'TENTANG\nKENAIKAN KELAS SANTRI {jenjang}\nTAHUN AJARAN {tahun_ajaran}', 'Kenaikan Kelas Santri', null,
  jsonb_build_object('basmalah', true, 'tembusan', true, 'ditetapkan', true,
    'lampiran_isi', E'== *LAMPIRAN*\n== Keputusan {penanda.jabatan} Nomor {nomor}\n== tentang Kenaikan Kelas Santri {jenjang} Tahun Ajaran {tahun_ajaran}\n\n{lampiran}'),
$t${penanda.jabatan} {lembaga}, setelah:

Menimbang : {menimbang}
Mengingat : {mengingat}
Memperhatikan : {memperhatikan}

== *MEMUTUSKAN*

Menetapkan : Keputusan {penanda.jabatan} tentang Kenaikan Kelas Santri {jenjang} Tahun Ajaran {tahun_ajaran}.
Kesatu : Menetapkan kenaikan kelas, tinggal kelas, dan kelulusan santri {jenjang} Tahun Ajaran {tahun_ajaran} sebagaimana tercantum dalam lampiran keputusan ini.
Kedua : Jumlah santri: {rekap}.
Ketiga : Santri yang tinggal kelas mengikuti pembinaan akademik dan kepesantrenan pada tahun ajaran berikutnya.
Keempat : Keputusan ini berlaku sejak tanggal ditetapkan dengan ketentuan apabila di kemudian hari terdapat kekeliruan akan diadakan perbaikan sebagaimana mestinya.$t$,
  '[{"kunci":"jenjang","label":"Jenjang","jenis":"teks","wajib":true},
    {"kunci":"tahun_ajaran","label":"Tahun ajaran","jenis":"teks","wajib":true},
    {"kunci":"menimbang","label":"Menimbang","jenis":"daftar","gaya":"huruf","wajib":true},
    {"kunci":"mengingat","label":"Mengingat","jenis":"daftar","gaya":"angka","wajib":true},
    {"kunci":"memperhatikan","label":"Memperhatikan","jenis":"teks","wajib":true},
    {"kunci":"rekap","label":"Rekapitulasi","jenis":"teks","wajib":true},
    {"kunci":"lampiran","label":"Daftar santri (lampiran)","jenis":"tabel","wajib":true}]'::jsonb,
  '[{"jabatan":"Direktur"}]'::jsonb, true, true, 30)
on conflict (kode) do nothing;

create table if not exists public.promotion_decrees (
  id                uuid primary key default gen_random_uuid(),
  academic_year_id  uuid not null references public.academic_years(id) on delete cascade,   -- draf tahun ajaran BARU
  jenjang           text not null check (jenjang in ('wustha','sma')),
  letter_id         uuid references public.outgoing_letters(id) on delete set null,
  jumlah            int not null default 0,
  dibuat_oleh       uuid references public.employees(id) on delete set null,
  created_at        timestamptz not null default now()
);
create index if not exists promotion_decrees_ta_idx on public.promotion_decrees (academic_year_id, jenjang);
alter table public.promotion_decrees enable row level security;
drop policy if exists baca on public.promotion_decrees;
create policy baca on public.promotion_decrees for select to authenticated using (public.boleh_ganti_ta() or public.boleh_kelola_persuratan());
grant select on public.promotion_decrees to authenticated;

/** Penanda tangan bawaan SK satu jenjang: Kepala SMA/Wustha bila terdaftar di Setelan → Penanda tangan, selain itu Direktur. */
create or replace function public._penanda_sk_jenjang(p_jenjang text)
returns uuid language sql stable security definer set search_path = public as $$
  select coalesce(
    (select id from signatories where aktif and jabatan_tertulis ilike 'kepala%' and
            (case p_jenjang when 'sma' then jabatan_tertulis ilike '%sma%' else (jabatan_tertulis ilike '%wustha%' or jabatan_tertulis ilike '%smp%' or jabatan_tertulis ilike '%mts%') end)
      order by urutan limit 1),
    (select id from signatories where aktif and (sumber_jabatan = 'DIREKTUR' or jabatan_tertulis ilike 'direktur%') order by (sumber_jabatan = 'DIREKTUR') desc nulls last, urutan limit 1))
$$;

/** Usulkan SK Kenaikan Kelas satu jenjang ke Persuratan (TU memberi nomor dan mengajukan tanda tangan). */
create or replace function public.usul_sk_kenaikan(p jsonb)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v_ta academic_years; v_lama academic_years; v_j text := p->>'jenjang'; t letter_templates; v_pen jsonb; v_sig uuid; v_surat uuid;
  v_baris jsonb; v_n int; v_naik int; v_tinggal int; v_lulus int; v_label text; v_saya text; v_rapat text;
begin
  if not public.boleh_ganti_ta() then raise exception 'SK Kenaikan Kelas disusun oleh pengelola Naik Kelas.' using errcode = '42501'; end if;
  if v_j not in ('wustha','sma') then raise exception 'Pilih jenjang Wustha atau SMA.'; end if;
  select * into v_ta from academic_years where id = (p->>'academic_year_id')::uuid;
  if v_ta.id is null or v_ta.aktif then raise exception 'SK disusun dari draf tahun ajaran baru yang belum diaktifkan.'; end if;
  select * into v_lama from academic_years where aktif limit 1;
  if exists (select 1 from promotion_decrees d join outgoing_letters o on o.id = d.letter_id
              where d.academic_year_id = v_ta.id and d.jenjang = v_j and o.status not in ('dibatalkan','ditolak','dicabut')) then
    raise exception 'SK Kenaikan Kelas % untuk tahun ajaran ini sudah diusulkan. Batalkan suratnya di Persuratan bila ingin menyusun ulang.', case v_j when 'sma' then 'SMA' else 'Wustha' end;
  end if;
  select * into t from letter_templates where kode = 'sk_kenaikan_kelas';
  if t.id is null or not t.aktif then raise exception 'Template SK Kenaikan Kelas nonaktif. Aktifkan di Persuratan → Template.'; end if;
  v_label := case v_j when 'sma' then 'SMA' else 'Kesetaraan Wustha' end;
  -- Lampiran: urut kelas asal lalu nama
  select count(*), count(*) filter (where pr.aksi = 'naik'), count(*) filter (where pr.aksi = 'tinggal'), count(*) filter (where pr.aksi = 'lulus'),
         coalesce(jsonb_agg(jsonb_build_array(null, s.nis, s.nama_lengkap, s.jenis_kelamin,
           coalesce((select g.nama from group_members m join student_groups g on g.id = m.group_id
                      where m.student_id = s.id and g.academic_year_id = v_lama.id and g.jenis = 'kelas' order by m.selesai nulls first limit 1), 'Kelas ' || pr.tingkat_lama),
           case pr.aksi when 'naik' then case when pr.jenjang_baru <> pr.jenjang_lama then 'Lulus, melanjutkan' else 'Naik kelas' end
                        when 'tinggal' then 'Tinggal kelas' else 'Lulus' end,
           case pr.aksi when 'naik' then 'Kelas ' || pr.tingkat_baru || case when pr.jenjang_baru <> pr.jenjang_lama then ' ' || upper(pr.jenjang_baru) else '' end
                        when 'tinggal' then 'Kelas ' || pr.tingkat_lama else '–' end)
           order by pr.tingkat_lama, s.nama_lengkap), '[]'::jsonb)
    into v_n, v_naik, v_tinggal, v_lulus, v_baris
    from promotions pr join students s on s.id = pr.student_id
   where pr.academic_year_id = v_ta.id and pr.jenjang_lama = v_j;
  if v_n = 0 then raise exception 'Belum ada keputusan kenaikan santri % pada draf tahun ajaran ini.', v_label; end if;
  -- Nomor urut kolom pertama
  select jsonb_agg(jsonb_set(x, '{0}', to_jsonb(i::text || '.')) order by i) into v_baris from jsonb_array_elements(v_baris) with ordinality q(x, i);
  v_sig := coalesce(nullif(p->>'signatory_id', '')::uuid, public._penanda_sk_jenjang(v_j));
  if v_sig is null then raise exception 'Penanda tangan SK belum diatur di Setelan → Penanda tangan.'; end if;
  v_pen := public._penanda_sah(jsonb_build_array(jsonb_build_object('signatory_id', v_sig, 'jabatan', (select jabatan_tertulis from signatories where id = v_sig))));
  v_rapat := coalesce(nullif(trim(p->>'memperhatikan'), ''), 'Hasil rapat dewan guru tentang kenaikan kelas' ||
               coalesce(' tanggal ' || public._tgl_panjang(nullif(p->>'tanggal_rapat', '')::date), '') || '.');
  insert into outgoing_letters (template_id, jenis_nama, kategori, kop_kode, dk, perihal_kode, format_nomor, tanggal_surat, perihal, kepada, lampiran, tembusan,
                                nilai, tampilan, penanda, status, disusun_oleh, pemohon_id, catatan)
  values (t.id, t.nama, t.kategori, t.kop_kode, t.dk, t.perihal_kode, t.format_nomor, public.hari_ini(),
          'Kenaikan Kelas Santri ' || v_label || ' Tahun Ajaran ' || coalesce(v_lama.nama, ''), null, '1 (satu) berkas',
          array['Yayasan', 'Wali kelas ' || v_label, 'Arsip'],
          jsonb_build_object('jenjang', v_label, 'tahun_ajaran', coalesce(v_lama.nama, ''),
            'menimbang', jsonb_build_array(
              'bahwa telah dilaksanakan penilaian hasil belajar santri pada akhir Tahun Ajaran ' || coalesce(v_lama.nama, '') || ';',
              'bahwa kenaikan kelas santri ditetapkan berdasarkan hasil penilaian akademik, kepesantrenan, kehadiran, dan sikap;',
              'bahwa berdasarkan pertimbangan sebagaimana dimaksud huruf a dan b, perlu menetapkan Keputusan tentang Kenaikan Kelas Santri ' || v_label || '.'),
            'mengingat', jsonb_build_array('Undang-Undang Nomor 20 Tahun 2003 tentang Sistem Pendidikan Nasional;',
              'Undang-Undang Nomor 18 Tahun 2019 tentang Pesantren;', 'Pedoman Akademik ' || coalesce((select nilai->>'nama_lembaga' from institution_settings where kunci = 'identitas'), 'Pondok') || '.'),
            'memperhatikan', v_rapat,
            'rekap', v_n || ' santri, terdiri atas ' || v_naik || ' naik kelas/melanjutkan, ' || v_tinggal || ' tinggal kelas, dan ' || v_lulus || ' lulus',
            'lampiran', jsonb_build_object('kolom', jsonb_build_array('No.', 'NIS', 'Nama santri', 'L/P', 'Kelas asal', 'Keputusan', 'Ke kelas'), 'baris', v_baris)),
          jsonb_build_object('bentuk', t.bentuk, 'judul', t.judul, 'subjudul', t.subjudul, 'isi', t.isi, 'opsi', t.opsi, 'isian', t.isian),
          v_pen, 'diperiksa', public.saya(), public.saya(), 'Usulan dari menu Naik Kelas')
  returning id into v_surat;
  insert into promotion_decrees (academic_year_id, jenjang, letter_id, jumlah, dibuat_oleh) values (v_ta.id, v_j, v_surat, v_n, public.saya());
  select nama_lengkap into v_saya from employees where id = public.saya();
  insert into notifications (employee_id, judul, isi, tautan, ikon, warna)
  select x, 'SK Kenaikan Kelas ' || v_label || ' perlu diproses', coalesce(v_saya, 'Pengelola') || ' mengusulkan SK Kenaikan Kelas ' || v_label || ' (' || v_n || ' santri).',
         '/persuratan/keluar?surat=' || v_surat, 'Certificate', 'biru'
    from public._pengelola_surat() x where x is distinct from public.saya();
  return v_surat;
end $$;

create or replace function public.daftar_sk_kenaikan(p_ta uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', d.id, 'jenjang', d.jenjang, 'letter_id', d.letter_id, 'jumlah', d.jumlah, 'created_at', d.created_at,
           'status', o.status, 'nomor', o.nomor, 'tanggal_surat', o.tanggal_surat, 'terbit_pada', o.terbit_pada) order by d.created_at desc), '[]'::jsonb)
    from promotion_decrees d left join outgoing_letters o on o.id = d.letter_id
   where d.academic_year_id = p_ta and (public.boleh_ganti_ta() or public.boleh_kelola_persuratan())
$$;

-- =====================================================================
-- B. LIBUR SANTRI BERTINGKAT
-- =====================================================================
alter table public.holiday_periods add column if not exists mode text not null default 'syarat';
alter table public.holiday_periods drop constraint if exists hp_mode;
alter table public.holiday_periods add constraint hp_mode check (mode in ('syarat','bertingkat'));
alter table public.holiday_periods add column if not exists tingkat jsonb not null default '[]'::jsonb;
alter table public.holiday_eligibility add column if not exists tingkat_otomatis text;
alter table public.holiday_eligibility add column if not exists tingkat text;

/** Tingkat libur: rapikan dan periksa. Hasil: array tingkat terurut dengan pulang_pada/kembali_batas (timestamptz) dan syarat bersih. */
create or replace function public._tingkat_libur_bersih(p jsonb)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare e jsonb; hasil jsonb := '[]'::jsonb; i int := 0; v_p timestamptz; v_k timestamptz; v_kode text; n int := jsonb_array_length(coalesce(p, '[]'));
begin
  if jsonb_typeof(coalesce(p, '[]')) <> 'array' or n < 2 then raise exception 'Libur bertingkat memerlukan sedikitnya dua tingkat.'; end if;
  if n > 6 then raise exception 'Paling banyak enam tingkat libur.'; end if;
  for e in select * from jsonb_array_elements(p) loop
    i := i + 1;
    v_p := (e->>'pulang_pada')::timestamptz; v_k := (e->>'kembali_batas')::timestamptz;
    if length(trim(coalesce(e->>'nama', ''))) < 2 then raise exception 'Isi nama tingkat libur ke-%.', i; end if;
    if v_p is null or v_k is null or v_k <= v_p then raise exception 'Tingkat "%": batas kembali harus setelah waktu pulang.', e->>'nama'; end if;
    v_kode := chr(64 + i);
    hasil := hasil || jsonb_build_array(jsonb_build_object('kode', v_kode, 'nama', trim(e->>'nama'), 'pulang_pada', v_p, 'kembali_batas', v_k,
      'syarat', case when i < n then public._syarat_libur_bersih(coalesce(e->'syarat', '{}'::jsonb)) - 'margin' else '{}'::jsonb end));
  end loop;
  return hasil;
end $$;

-- Simpan periode: mode dan tingkat. Untuk mode bertingkat, waktu pulang/kembali periode = paling awal/paling akhir dari semua tingkat.
create or replace function public.simpan_periode_libur(p jsonb)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v_id uuid := nullif(p->>'id', '')::uuid; v_status text; v_pulang timestamptz := (p->>'pulang_pada')::timestamptz;
        v_kembali timestamptz := (p->>'kembali_batas')::timestamptz; v_mode text := coalesce(nullif(p->>'mode', ''), 'syarat'); v_tingkat jsonb := '[]'::jsonb;
begin
  if not public.boleh_kelola_libur() then raise exception 'Anda tidak berwenang mengelola libur santri.' using errcode = '42501'; end if;
  if length(trim(coalesce(p->>'nama', ''))) < 3 then raise exception 'Isi nama periode libur.'; end if;
  if v_mode not in ('syarat','bertingkat') then raise exception 'Cara penentuan libur tidak dikenal.'; end if;
  if v_mode = 'bertingkat' then
    v_tingkat := public._tingkat_libur_bersih(p->'tingkat');
    select min((x->>'pulang_pada')::timestamptz), max((x->>'kembali_batas')::timestamptz) into v_pulang, v_kembali from jsonb_array_elements(v_tingkat) x;
  end if;
  if v_pulang is null or v_kembali is null or v_kembali <= v_pulang then raise exception 'Batas kembali harus setelah waktu pulang.'; end if;
  if (p->>'hitung_mulai')::date is null or (p->>'hitung_selesai')::date < (p->>'hitung_mulai')::date then raise exception 'Rentang hitung tidak valid.'; end if;
  if v_id is not null then
    select status into v_status from holiday_periods where id = v_id;
    if v_status is null then raise exception 'Periode tidak ditemukan.'; end if;
    if v_status in ('disahkan','batal') then raise exception 'Periode yang sudah disahkan atau dibatalkan tidak dapat diubah.'; end if;
    update holiday_periods set nama = trim(p->>'nama'), jenis = coalesce(nullif(p->>'jenis', ''), 'bulanan'), pulang_pada = v_pulang, kembali_batas = v_kembali,
           hitung_mulai = (p->>'hitung_mulai')::date, hitung_selesai = (p->>'hitung_selesai')::date,
           jenjang = coalesce(array(select jsonb_array_elements_text(coalesce(p->'jenjang', '[]'::jsonb))), '{}'),
           jenis_kelamin = nullif(p->>'jenis_kelamin', ''), syarat = public._syarat_libur_bersih(coalesce(p->'syarat', '{}'::jsonb)),
           catatan = nullif(trim(coalesce(p->>'catatan', '')), ''), status = 'draf', mode = v_mode, tingkat = v_tingkat
     where id = v_id;
  else
    insert into holiday_periods (nama, jenis, pulang_pada, kembali_batas, hitung_mulai, hitung_selesai, jenjang, jenis_kelamin, syarat, catatan, dibuat_oleh, mode, tingkat)
    values (trim(p->>'nama'), coalesce(nullif(p->>'jenis', ''), 'bulanan'), v_pulang, v_kembali, (p->>'hitung_mulai')::date, (p->>'hitung_selesai')::date,
            coalesce(array(select jsonb_array_elements_text(coalesce(p->'jenjang', '[]'::jsonb))), '{}'), nullif(p->>'jenis_kelamin', ''),
            public._syarat_libur_bersih(coalesce(p->'syarat', public.syarat_libur_bawaan())), nullif(trim(coalesce(p->>'catatan', '')), ''), public.saya(), v_mode, v_tingkat)
    returning id into v_id;
  end if;
  return v_id;
end $$;

/** Apakah angka penilaian santri (rincian) memenuhi syarat satu tingkat (tanpa rentang pertimbangan). */
create or replace function public._penuhi_syarat_libur(r jsonb, sy jsonb)
returns boolean language sql immutable as $$
  select (nullif(sy->>'kelas_min', '') is null or (r->'kelas'->>'persen') is null or (r->'kelas'->>'persen')::numeric >= (sy->>'kelas_min')::numeric)
     and (nullif(sy->>'halaqah_min', '') is null or (r->'halaqah'->>'persen') is null or (r->'halaqah'->>'persen')::numeric >= (sy->>'halaqah_min')::numeric)
     and (nullif(sy->>'asrama_min', '') is null or (r->'asrama'->>'persen') is null or (r->'asrama'->>'persen')::numeric >= (sy->>'asrama_min')::numeric)
     and (nullif(sy->>'izin_maks', '') is null or coalesce((r->>'izin')::int, 0) <= (sy->>'izin_maks')::int)
     and (nullif(sy->>'terlambat_maks', '') is null or coalesce((r->>'terlambat')::int, 0) <= (sy->>'terlambat_maks')::int)
     and (coalesce(nullif(sy->>'hafalan_min_halaman', '')::numeric, 0) = 0 or coalesce((r->>'hafalan')::numeric, 0) >= (sy->>'hafalan_min_halaman')::numeric)
$$;

/** Tetapkan tingkat otomatis setelah penilaian (mode bertingkat): tingkat terbaik yang syaratnya terpenuhi; semua santri libur. */
create or replace function public._tingkatkan_libur(p_id uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
declare h holiday_periods%rowtype; e record; v_t text; x jsonb; v_gagal jsonb;
begin
  select * into h from holiday_periods where id = p_id;
  if h.mode <> 'bertingkat' then return; end if;
  for e in select * from holiday_eligibility where period_id = p_id loop
    v_t := null; v_gagal := '[]'::jsonb;
    for x in select * from jsonb_array_elements(h.tingkat) loop
      if x->'syarat' = '{}'::jsonb or public._penuhi_syarat_libur(e.rincian, x->'syarat') then v_t := x->>'kode'; exit; end if;
      v_gagal := v_gagal || to_jsonb((x->>'nama') || ': belum memenuhi syarat');
    end loop;
    v_t := coalesce(v_t, h.tingkat->-1->>'kode');
    update holiday_eligibility set tingkat_otomatis = v_t, tingkat = case when diubah and tingkat is not null then tingkat else v_t end,
           otomatis = 'boleh', keputusan = 'boleh', rincian = (rincian - 'gagal' - 'timbang') || jsonb_build_object('gagal', '[]'::jsonb, 'timbang', '[]'::jsonb, 'tingkat_catatan', v_gagal)
     where id = e.id;
  end loop;
end $$;

select pg_temp.tambal('nilai_libur', E'  update holiday_periods set status = ''dinilai'', dinilai_pada = now() where id = p_id;\n  return public.ringkasan_periode_libur(p_id);',
  E'  update holiday_periods set status = ''dinilai'', dinilai_pada = now() where id = p_id;\n  perform public._tingkatkan_libur(p_id);\n  return public.ringkasan_periode_libur(p_id);', '_tingkatkan_libur');

-- Ringkasan: jumlah per tingkat
create or replace function public.ringkasan_periode_libur(p_id uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('jumlah', count(*), 'boleh', count(*) filter (where keputusan = 'boleh'), 'tidak', count(*) filter (where keputusan = 'tidak'),
    'belum', count(*) filter (where keputusan is null), 'pertimbangan', count(*) filter (where otomatis = 'pertimbangan'),
    'diubah', count(*) filter (where diubah), 'izin_dibuat', count(*) filter (where permit_id is not null),
    'tingkat', coalesce((select jsonb_object_agg(t, n) from (select tingkat t, count(*) n from holiday_eligibility where period_id = p_id and tingkat is not null group by tingkat) q), '{}'::jsonb))
    from holiday_eligibility where period_id = p_id
$$;

/** Waktu pulang/kembali satu santri: dari tingkatnya (mode bertingkat) atau dari periode. */
create or replace function public._waktu_libur(p_elig uuid)
returns table (pulang_pada timestamptz, kembali_batas timestamptz, nama_tingkat text)
language sql stable security definer set search_path = public as $$
  select coalesce((x->>'pulang_pada')::timestamptz, h.pulang_pada), coalesce((x->>'kembali_batas')::timestamptz, h.kembali_batas), x->>'nama'
    from holiday_eligibility e join holiday_periods h on h.id = e.period_id
    left join lateral (select y from jsonb_array_elements(case when h.mode = 'bertingkat' then h.tingkat else '[]'::jsonb end) y where y->>'kode' = e.tingkat limit 1) t(x) on true
   where e.id = p_elig
$$;

/** Buat/batalkan/sesuaikan izin libur satu santri (versi 11800: waktu mengikuti tingkat libur). */
create or replace function public._selaraskan_izin_libur(p_elig uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
declare e holiday_eligibility%rowtype; h holiday_periods%rowtype; v_pid uuid; v_lama int; v_sebagai text; w record; pm student_permits;
begin
  select * into e from holiday_eligibility where id = p_elig for update;
  select * into h from holiday_periods where id = e.period_id;
  select * into w from public._waktu_libur(p_elig);
  v_lama := greatest(1, ceil(extract(epoch from (w.kembali_batas - w.pulang_pada)) / 86400.0)::int);
  if e.keputusan = 'boleh' and e.permit_id is not null then
    select * into pm from student_permits where id = e.permit_id;
    -- Tingkat berubah setelah disahkan: izin yang belum dipakai keluar ikut disesuaikan
    if pm.status = 'disetujui' and (pm.keluar_pada is distinct from w.pulang_pada or pm.kembali_batas is distinct from w.kembali_batas) then
      update student_permits set keluar_pada = w.pulang_pada, kembali_batas = w.kembali_batas, lama_hari = v_lama,
             alasan = h.nama || coalesce(' – ' || w.nama_tingkat, ''),
             catatan = trim(coalesce(catatan || E'\n', '') || 'Waktu libur disesuaikan dengan tingkat ' || coalesce(w.nama_tingkat, '-') || '.')
       where id = pm.id;
    end if;
  end if;
  if e.keputusan = 'boleh' and (e.permit_id is null or not exists (select 1 from student_permits where id = e.permit_id and status in ('disetujui','keluar','kembali'))) then
    if exists (select 1 from student_permits where student_id = e.student_id and status = 'keluar') then
      update holiday_eligibility set rincian = rincian || '{"catatan_izin": "Santri sedang di luar dengan izin lain saat disahkan."}' where id = e.id;
      return;
    end if;
    insert into student_permits (student_id, jenis, alasan, keluar_pada, kembali_batas, lama_hari, sumber, pengusul_id, peran_pengusul, unit_kode, perlu_pimpinan, status, catatan)
    values (e.student_id, 'libur', h.nama || coalesce(' – ' || w.nama_tingkat, ''), w.pulang_pada, w.kembali_batas, v_lama, 'libur', coalesce(h.disahkan_oleh, public.saya()), 'pimpinan',
            'KESANTRIAN', false, 'disetujui', 'Izin libur otomatis dari periode ' || h.nama)
    returning id into v_pid;
    v_sebagai := case when h.disahkan_oleh in (select public._pimpinan_puncak()) then 'Direktur/Wakil Direktur'
                      when h.disahkan_oleh in (select public._pejabat_unit('KESANTRIAN', 30)) then 'Kepala Bidang Kesantrian' else 'Pengesah libur' end;
    insert into student_permit_approvals (permit_id, tingkat, keputusan, oleh, sebagai, catatan) values (v_pid, 1, 'setuju', h.disahkan_oleh, v_sebagai, 'Pengesahan libur');
    update holiday_eligibility set permit_id = v_pid where id = e.id;
  elsif e.keputusan is distinct from 'boleh' and e.permit_id is not null then
    update student_permits set status = 'dibatalkan', catatan = trim(coalesce(catatan || E'\n', '') || 'Keputusan libur diubah menjadi tidak libur.')
     where id = e.permit_id and status = 'disetujui';
  end if;
end $$;

/** Ubah tingkat libur satu santri (mode bertingkat; alasan wajib bila berbeda dari otomatis). */
create or replace function public.ubah_tingkat_libur(p_id uuid, p_tingkat text, p_alasan text)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare e holiday_eligibility%rowtype; h holiday_periods%rowtype;
begin
  if not public.boleh_kelola_libur() then raise exception 'Anda tidak berwenang mengubah tingkat libur.' using errcode = '42501'; end if;
  select * into e from holiday_eligibility where id = p_id for update;
  if e.id is null then raise exception 'Data santri pada periode ini tidak ditemukan.'; end if;
  select * into h from holiday_periods where id = e.period_id;
  if h.mode <> 'bertingkat' then raise exception 'Periode ini tidak memakai libur bertingkat.'; end if;
  if h.status = 'batal' then raise exception 'Periode sudah dibatalkan.'; end if;
  if not exists (select 1 from jsonb_array_elements(h.tingkat) x where x->>'kode' = p_tingkat) then raise exception 'Tingkat libur tidak dikenal.'; end if;
  if (p_tingkat is distinct from e.tingkat_otomatis or h.status = 'disahkan') and length(trim(coalesce(p_alasan, ''))) < 5 then
    raise exception 'Tuliskan alasan perubahan (minimal 5 huruf).';
  end if;
  if h.status = 'disahkan' and not public.boleh_sahkan_libur() then
    raise exception 'Setelah disahkan, perubahan hanya oleh Kepala Bidang Kesantrian, Direktur/Wadir, Plt, atau superadmin.' using errcode = '42501';
  end if;
  if h.status = 'disahkan' and exists (select 1 from student_permits where id = e.permit_id and status in ('keluar','kembali')) then
    raise exception 'Santri ini sudah keluar dengan izin libur; tingkat tidak dapat diubah.';
  end if;
  update holiday_eligibility set tingkat = p_tingkat, keputusan = 'boleh', diubah = p_tingkat is distinct from tingkat_otomatis,
         alasan_ubah = nullif(trim(coalesce(p_alasan, '')), ''), diubah_oleh = public.saya(), diubah_pada = now() where id = p_id;
  if h.status = 'disahkan' then perform public._selaraskan_izin_libur(p_id); end if;
  return public.ringkasan_periode_libur(e.period_id);
end $$;

-- Detail: tingkat per santri
select pg_temp.tambal('detail_libur', '''otomatis'', e.otomatis, ''keputusan'', e.keputusan,',
  '''otomatis'', e.otomatis, ''keputusan'', e.keputusan, ''tingkat'', e.tingkat, ''tingkat_otomatis'', e.tingkat_otomatis,', 'e.tingkat_otomatis');

-- Hak eksekusi
do $$
declare f text;
begin
  foreach f in array array['_penanda_sk_jenjang(text)', '_tingkat_libur_bersih(jsonb)', '_penuhi_syarat_libur(jsonb,jsonb)', '_tingkatkan_libur(uuid)', '_waktu_libur(uuid)'] loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
  end loop;
  foreach f in array array['usul_sk_kenaikan(jsonb)', 'daftar_sk_kenaikan(uuid)', 'ubah_tingkat_libur(uuid,text,text)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- =====================================================================
-- PEMERIKSAAN — hasil yang benar: 6 baris, semuanya "Sesuai"
-- =====================================================================
select '1. Usulan kenaikan mengikuti keputusan rapor' as pemeriksaan,
       case when position('report_decisions' in pg_get_functiondef('public.rencana_kenaikan()'::regprocedure)) > 0 then 'Sesuai' else 'Periksa' end as hasil
union all
select '2. Template SK Kenaikan Kelas tersedia',
       case when exists (select 1 from public.letter_templates where kode = 'sk_kenaikan_kelas') then 'Sesuai' else 'Periksa' end
union all
select '3. SK Kenaikan Kelas diusulkan ke Persuratan per jenjang',
       case when to_regprocedure('public.usul_sk_kenaikan(jsonb)') is not null and to_regclass('public.promotion_decrees') is not null then 'Sesuai' else 'Periksa' end
union all
select '4. Template surat mengenal isian tabel',
       case when position('''tabel''' in pg_get_functiondef('public.simpan_template_surat(jsonb)'::regprocedure)) > 0 then 'Sesuai' else 'Periksa' end
union all
select '5. Libur bertingkat (mode dan tingkat periode)',
       case when exists (select 1 from information_schema.columns where table_name = 'holiday_periods' and column_name = 'tingkat')
             and position('_tingkatkan_libur' in pg_get_functiondef('public.nilai_libur(uuid)'::regprocedure)) > 0 then 'Sesuai' else 'Periksa' end
union all
select '6. Izin libur mengikuti waktu tingkat',
       case when position('_waktu_libur' in pg_get_functiondef('public._selaraskan_izin_libur(uuid)'::regprocedure)) > 0 then 'Sesuai' else 'Periksa' end;
