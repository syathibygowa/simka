-- SIMKA PRO | supabase/migrations/20261011007400_gaji_pengingat_laporan.sql | v1.0 | Fase 11 – Tahap 5 Pengingat kenaikan, perbandingan bulan lalu, ringkasan Beranda | 11/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 11 · Migrasi 74: Pengingat kenaikan dan laporan gaji (Blueprint Bagian 36)
--   * pengingat_kenaikan(bulan): pegawai yang naik tingkat masa kerja pada bulan itu (tahun penuh ke-1 s.d. 12 sejak TMT,
--     beserta tarif lama/baru dan selisihnya), dan perubahan data penentu gaji 60 hari terakhir dari riwayat kepegawaian
--     (status, pendidikan, level muhaffizh, kategori honorer, jabatan struktural/fungsional).
--   * pg_cron "pengingat-kenaikan-gaji": setiap tanggal 1 pukul 07.00 WITA, pengelola gaji (Bendahara, admin ber-izin
--     kelola_gaji, superadmin) menerima notifikasi jumlah pegawai yang naik masa kerja BULAN BERIKUTNYA.
--   * rincian_periode_gaji: setiap baris memuat ringkasan bulan sebelumnya ("naik/turun dari bulan lalu").
--   * ringkasan_gaji_beranda(): kartu "Untuk Anda" bagi pengelola gaji dan penanda tangan.
-- Jalankan SETELAH migrasi 7300. Aman dijalankan ulang.
-- =====================================================================

create or replace function public._naik_masa_kerja(p_bulan date)
returns table (employee_id uuid, niy text, nama text, tmt date, tanggal date, tahun_baru int, tarif_lama numeric, tarif_baru numeric)
language sql stable security definer set search_path = public as $$
  with b as (select date_trunc('month', p_bulan)::date awal, (date_trunc('month', p_bulan) + interval '1 month - 1 day')::date akhir)
  select e.id, e.niy, e.nama_lengkap, e.tmt_tugas,
         make_date(extract(year from b.awal)::int, extract(month from e.tmt_tugas)::int,
                   least(extract(day from e.tmt_tugas)::int, extract(day from b.akhir)::int)),
         (extract(year from b.awal) - extract(year from e.tmt_tugas))::int,
         coalesce((select t.besaran from public.tarif_berlaku(b.akhir) t where t.kategori = 'masa_kerja'
                    and t.kunci = ((extract(year from b.awal) - extract(year from e.tmt_tugas))::int - 1)::text), 0),
         coalesce((select t.besaran from public.tarif_berlaku(b.akhir) t where t.kategori = 'masa_kerja'
                    and t.kunci = ((extract(year from b.awal) - extract(year from e.tmt_tugas))::int)::text), 0)
    from employees e cross join b
   where e.status_keaktifan = 'aktif' and e.peran <> 'superadmin' and coalesce(e.status_kepegawaian, '') <> 'honorer'
     and e.tmt_tugas is not null and extract(month from e.tmt_tugas) = extract(month from b.awal)
     and (extract(year from b.awal) - extract(year from e.tmt_tugas)) between 1 and 12
$$;

/** Daftar pengingat kenaikan untuk bulan tertentu (bawaan bulan berjalan). */
create or replace function public.pengingat_kenaikan(p_bulan date default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_bulan date := date_trunc('month', coalesce(p_bulan, public.hari_ini()))::date;
begin
  if not public.boleh_lihat_gaji() then raise exception 'Anda tidak berwenang melihat data gaji.' using errcode = '42501'; end if;
  return jsonb_build_object('bulan', v_bulan,
    'masa_kerja', coalesce((select jsonb_agg(jsonb_build_object('employee_id', n.employee_id, 'niy', n.niy, 'nama', n.nama, 'tmt', n.tmt, 'tanggal', n.tanggal,
        'tahun_baru', n.tahun_baru, 'tarif_lama', n.tarif_lama, 'tarif_baru', n.tarif_baru, 'selisih', n.tarif_baru - n.tarif_lama) order by n.tanggal, n.nama)
        from public._naik_masa_kerja(v_bulan) n), '[]'::jsonb),
    'perubahan', coalesce((select jsonb_agg(jsonb_build_object('employee_id', h.employee_id, 'niy', e.niy, 'nama', e.nama_lengkap, 'jenis', h.jenis,
        'nilai_lama', h.nilai_lama, 'nilai_baru', h.nilai_baru, 'tanggal_berlaku', h.tanggal_berlaku, 'dicatat', h.created_at,
        'oleh', (select nama_lengkap from employees where id = h.dicatat_oleh)) order by h.created_at desc)
        from employment_history h join employees e on e.id = h.employee_id
       where h.jenis in ('status_kepegawaian','pendidikan','level_muhaffizh','kategori_honorer','jabatan_struktural','jabatan_fungsional')
         and h.created_at >= now() - interval '60 days' and e.peran <> 'superadmin'), '[]'::jsonb));
end $$;

/** Notifikasi bulanan (pg_cron harian 23.00 UTC = 07.00 WITA; hanya bekerja pada tanggal 1 WITA). */
create or replace function public.pengingat_gaji_bulanan()
returns void language plpgsql volatile security definer set search_path = public as $$
declare v_depan date := (date_trunc('month', public.hari_ini()) + interval '1 month')::date; v_n int; v_emp uuid;
begin
  if extract(day from public.hari_ini()) <> 1 then return; end if;
  select count(*) into v_n from public._naik_masa_kerja(v_depan);
  if v_n = 0 then return; end if;
  for v_emp in select public._pejabat_gaji('bendahara') union select id from employees where peran = 'superadmin' and status_akun = 'aktif'
               union select ap.employee_id from admin_permissions ap where ap.kode = 'kelola_gaji' loop
    perform public.kirim_notifikasi(v_emp, v_n || ' pegawai naik masa kerja bulan depan',
      'Tunjangan masa kerja ' || public.nama_bulan_periode(extract(year from v_depan)::int, extract(month from v_depan)::int) || ' bertambah otomatis. Periksa daftarnya.',
      '/tunjangan/pengingat', 'TrendUp', 'hijau');
  end loop;
end $$;

do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    perform cron.unschedule('pengingat-kenaikan-gaji') where exists (select 1 from cron.job where jobname = 'pengingat-kenaikan-gaji');
    perform cron.schedule('pengingat-kenaikan-gaji', '0 23 * * *', 'select public.pengingat_gaji_bulanan()');
  end if;
end $$;

/** Ringkasan untuk kartu "Untuk Anda" di Beranda (pengelola gaji dan penanda tangan). */
create or replace function public.ringkasan_gaji_beranda()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_p payroll_periods; v_ttd int;
begin
  select count(*) into v_ttd from payroll_signatures s join payroll_periods p on p.id = s.period_id
   where p.status = 'diajukan' and s.status = 'menunggu' and public.saya() in (select public._pejabat_gaji(s.peran));
  if not public.boleh_lihat_gaji() then return jsonb_build_object('ttd_menunggu', v_ttd); end if;
  select * into v_p from payroll_periods where status <> 'batal' order by tahun desc, bulan desc limit 1;
  return jsonb_build_object('ttd_menunggu', v_ttd, 'kelola', public.boleh_kelola_gaji(),
    'periode', case when v_p.id is null then null else jsonb_build_object('id', v_p.id, 'nama', public.nama_bulan_periode(v_p.tahun, v_p.bulan), 'status', v_p.status) end,
    'periode_bulan_ini', exists (select 1 from payroll_periods where tahun = extract(year from public.hari_ini()) and bulan = extract(month from public.hari_ini())),
    'permintaan', (select count(*) from payroll_slip_requests where status = 'menunggu'),
    'naik_bulan_ini', (select count(*) from public._naik_masa_kerja(public.hari_ini())),
    'naik_bulan_depan', (select count(*) from public._naik_masa_kerja((date_trunc('month', public.hari_ini()) + interval '1 month')::date)),
    'perubahan', (select count(*) from employment_history where jenis in ('status_kepegawaian','pendidikan','level_muhaffizh','kategori_honorer','jabatan_struktural','jabatan_fungsional')
                    and created_at >= now() - interval '30 days'));
end $$;

create or replace function public.rincian_periode_gaji(p_period uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if not public.boleh_lihat_gaji() then raise exception 'Anda tidak berwenang melihat data gaji.' using errcode = '42501'; end if;
  return (select jsonb_build_object('periode', to_jsonb(p) - 'dibuat_oleh', 'ttd', public._ttd_periode(p.id), 'baris', coalesce((
      select jsonb_agg(jsonb_build_object('id', l.id, 'employee_id', l.employee_id, 'data', l.data, 'target_diterima', l.target_diterima,
          'alasan_target', l.alasan_target, 'total_skema', l.total_skema, 'total_penyesuaian', l.total_penyesuaian,
          'total_pendapatan', l.total_pendapatan, 'total_potongan', l.total_potongan, 'diterima', l.diterima, 'catatan', l.catatan,
          'nomor_slip', l.nomor_slip, 'kode_validasi', l.kode_validasi, 'revisi_ke', l.revisi_ke, 'dalam_revisi', l.dalam_revisi, 'alasan_revisi', l.alasan_revisi,
          'riwayat', l.riwayat, 'dibuka_pegawai', l.dibuka_pegawai, 'diterbitkan_pada', l.diterbitkan_pada, 'document_id', l.document_id,
          'bulan_lalu', (select jsonb_build_object('periode', public.nama_bulan_periode(p2.tahun, p2.bulan), 'diterima', l2.diterima, 'skema', l2.total_skema,
                           'pendapatan', l2.total_pendapatan, 'potongan', l2.total_potongan)
                         from payroll_lines l2 join payroll_periods p2 on p2.id = l2.period_id
                        where l2.employee_id = l.employee_id and p2.status <> 'batal' and (p2.tahun * 12 + p2.bulan) < (p.tahun * 12 + p.bulan)
                        order by p2.tahun desc, p2.bulan desc limit 1),
          'item', coalesce((select jsonb_agg(jsonb_build_object('id', i.id, 'jenis', i.jenis, 'kategori', i.kategori, 'kode', i.kode, 'label', i.label,
              'jumlah', i.jumlah, 'tarif', i.tarif, 'besaran_skema', i.besaran_skema, 'besaran', i.besaran, 'sumber', i.sumber, 'alasan', i.alasan,
              'rincian', i.rincian, 'diubah_oleh', (select nama_lengkap from employees where id = i.diubah_oleh), 'diubah_pada', i.diubah_pada)
              order by i.jenis desc, i.urutan, i.label) from payroll_items i where i.line_id = l.id), '[]'::jsonb))
        order by l.data->>'nama')
      from payroll_lines l where l.period_id = p.id), '[]'::jsonb))
    from payroll_periods p where p.id = p_period);
end $$;

do $$
declare f text;
begin
  foreach f in array array['pengingat_kenaikan(date)','ringkasan_gaji_beranda()','rincian_periode_gaji(uuid)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  foreach f in array array['_naik_masa_kerja(date)','pengingat_gaji_bulanan()'] loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
  end loop;
end $$;

-- PEMERIKSAAN (hasil yang benar: baris 1–3 "Sesuai"; baris 4 keterangan data)
select '1. Fungsi pengingat kenaikan' as pemeriksaan,
       case when (select count(*) from pg_proc where proname in ('pengingat_kenaikan','_naik_masa_kerja','pengingat_gaji_bulanan','ringkasan_gaji_beranda')) = 4 then 'Sesuai' else 'Periksa' end as hasil
union all select '2. Pengingat bulanan terjadwal', case when exists (select 1 from cron.job where jobname = 'pengingat-kenaikan-gaji') then 'Sesuai' else 'Periksa' end
union all select '3. Rincian periode memuat bulan lalu', case when pg_get_functiondef('public.rincian_periode_gaji(uuid)'::regprocedure) like '%bulan_lalu%' then 'Sesuai' else 'Periksa' end
union all select '4. Naik masa kerja bulan ini', (select count(*) || ' pegawai' from public._naik_masa_kerja(public.hari_ini()));
