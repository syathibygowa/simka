-- SIMKA PRO | supabase/migrations/20261011007200_gaji_potongan.sql | v1.0 | Fase 11 – Tahap 3 Potongan kehadiran, pinjaman, simpanan program | 11/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 11 · Migrasi 72: Potongan gaji (Blueprint Bagian 36)
--   * Potongan kehadiran per tugas (HANYA tunjangan fungsional; struktural dan kepegawaian tidak pernah dipotong):
--       potongan = tunjangan × sesi tidak terlaksana tanpa keterangan ÷ sesi wajib, dibulatkan (Ketentuan).
--       Dasar kehadiran: Guru mapel = jam terjadwal yang berjurnal; Wali kelas/Muhaffizh/Musyrif/Pembina ekskul = sesi
--       absensi kelompok asuhan (pengasuh utama) yang terisi, siapa pun pengisinya (pengganti tidak memotong yang digantikan);
--       Operator, staf, petugas khusus = presensi pada pola tugasnya. Hari berizin (pengajuan disetujui) tidak dihitung kecuali
--       sakelar izin/sakit/cuti aktif; dinas luar tidak pernah dipotong; terlambat dihitung hanya bila sakelarnya aktif.
--       Sakelar utama "potong_kehadiran" BAWAAN NONAKTIF: rincian tetap dihitung sebagai perkiraan di setiap baris gaji.
--   * Pinjaman pegawai: pokok, cicilan per bulan, mulai dipotong; sisa = pokok − pembayaran. Cicilan otomatis masuk periode;
--     pembayaran tercatat saat slip terbit (tahap penerbitan) atau dicatat manual (bayar di luar gaji).
--   * Simpanan program (umrah, kurban, dll.): dipotong tiap bulan dan disimpan yayasan atas nama pegawai; saldo per program;
--     setoran awal (saldo lama), pencairan, dan koreksi dicatat Bendahara.
--   * Semua potongan otomatis dapat diubah nominalnya (beralasan) di rincian periode dan bertahan saat hitung ulang.
-- Jalankan SETELAH migrasi 7100. Aman dijalankan ulang.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. TABEL
-- ---------------------------------------------------------------------
create table if not exists public.employee_loans (
  id           uuid primary key default gen_random_uuid(),
  employee_id  uuid not null references public.employees(id) on delete cascade,
  keterangan   text,
  pokok        numeric(12,0) not null check (pokok > 0),
  cicilan      numeric(12,0) not null check (cicilan > 0),
  tanggal      date not null default public.hari_ini(),
  mulai_potong date not null,
  status       text not null default 'aktif' check (status in ('aktif','lunas','batal')),
  catatan      text,
  dibuat_oleh  uuid references public.employees(id) on delete set null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index if not exists employee_loans_emp_idx on public.employee_loans (employee_id, status);

create table if not exists public.loan_payments (
  id          uuid primary key default gen_random_uuid(),
  loan_id     uuid not null references public.employee_loans(id) on delete cascade,
  period_id   uuid references public.payroll_periods(id) on delete set null,
  besaran     numeric(12,0) not null check (besaran > 0),
  tanggal     date not null default public.hari_ini(),
  keterangan  text,
  dicatat_oleh uuid references public.employees(id) on delete set null,
  created_at  timestamptz not null default now()
);
create index if not exists loan_payments_loan_idx on public.loan_payments (loan_id);

create table if not exists public.savings_programs (
  id             uuid primary key default gen_random_uuid(),
  nama           text not null unique check (length(trim(nama)) >= 3),
  keterangan     text,
  setoran_bawaan numeric(12,0) not null default 0 check (setoran_bawaan >= 0),
  aktif          boolean not null default true,
  urutan         int not null default 0,
  created_at     timestamptz not null default now()
);

create table if not exists public.savings_members (
  id          uuid primary key default gen_random_uuid(),
  program_id  uuid not null references public.savings_programs(id) on delete cascade,
  employee_id uuid not null references public.employees(id) on delete cascade,
  setoran     numeric(12,0) not null check (setoran >= 0),
  mulai       date not null,
  berhenti    date,
  aktif       boolean not null default true,
  catatan     text,
  created_at  timestamptz not null default now(),
  unique (program_id, employee_id)
);

create table if not exists public.savings_transactions (
  id          uuid primary key default gen_random_uuid(),
  program_id  uuid not null references public.savings_programs(id) on delete cascade,
  employee_id uuid not null references public.employees(id) on delete cascade,
  jenis       text not null check (jenis in ('setoran','setoran_awal','pencairan','koreksi')),
  besaran     numeric(12,0) not null,   -- positif; koreksi boleh negatif
  period_id   uuid references public.payroll_periods(id) on delete set null,
  tanggal     date not null default public.hari_ini(),
  keterangan  text,
  dicatat_oleh uuid references public.employees(id) on delete set null,
  created_at  timestamptz not null default now(),
  check (jenis = 'koreksi' or besaran > 0)
);
create index if not exists savings_tx_idx on public.savings_transactions (program_id, employee_id);

insert into public.savings_programs (nama, keterangan, urutan) values
  ('Umrah', 'Tabungan program umrah pegawai', 1), ('Kurban', 'Tabungan kurban Iduladha', 2)
on conflict (nama) do nothing;

alter table public.employee_loans enable row level security;
alter table public.loan_payments enable row level security;
alter table public.savings_programs enable row level security;
alter table public.savings_members enable row level security;
alter table public.savings_transactions enable row level security;
drop policy if exists baca on public.employee_loans;
create policy baca on public.employee_loans for select to authenticated using (public.boleh_lihat_gaji() or employee_id = public.saya());
drop policy if exists baca on public.loan_payments;
create policy baca on public.loan_payments for select to authenticated
  using (public.boleh_lihat_gaji() or exists (select 1 from employee_loans x where x.id = loan_id and x.employee_id = public.saya()));
drop policy if exists baca on public.savings_programs;
create policy baca on public.savings_programs for select to authenticated using (true);
drop policy if exists baca on public.savings_members;
create policy baca on public.savings_members for select to authenticated using (public.boleh_lihat_gaji() or employee_id = public.saya());
drop policy if exists baca on public.savings_transactions;
create policy baca on public.savings_transactions for select to authenticated using (public.boleh_lihat_gaji() or employee_id = public.saya());
grant select on public.employee_loans, public.loan_payments, public.savings_programs, public.savings_members, public.savings_transactions to authenticated;

-- ---------------------------------------------------------------------
-- 2. KEHADIRAN PER TUGAS
-- ---------------------------------------------------------------------
/** Tanggal berizin seorang pegawai dalam rentang (pengajuan disetujui) yang TIDAK dihitung sebagai sesi wajib,
 *  sesuai sakelar Ketentuan. Dinas luar selalu dianggap bertugas (tidak dipotong, tidak dikecualikan). */
create or replace function public._tanggal_berizin(p_emp uuid, p_mulai date, p_akhir date)
returns setof date language sql stable security definer set search_path = public as $$
  select distinct d::date from leave_requests r join leave_types t on t.id = r.leave_type_id
    cross join lateral generate_series(greatest(r.mulai, p_mulai), least(r.selesai, p_akhir), interval '1 day') d
  where r.employee_id = p_emp and r.status = 'disetujui' and r.mulai <= p_akhir and r.selesai >= p_mulai
    and case when t.kode = 'SAKIT' then not coalesce((public._pengaturan_gaji()->>'potong_sakit')::boolean, false)
             when t.kode = 'IZIN' then not coalesce((public._pengaturan_gaji()->>'potong_izin')::boolean, false)
             when t.kode like 'CUTI%' then not coalesce((public._pengaturan_gaji()->>'potong_cuti')::boolean, false)
             else false end
$$;

/** Rekap kehadiran satu tugas fungsional dalam periode (sampai hari ini):
 *  { sumber, wajib, terlaksana, berizin, tanpa }. null bila tugas tidak memiliki dasar kehadiran. */
create or replace function public._kehadiran_tugas(p_emp uuid, p_kode text, p_mulai date, p_akhir date)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_akhir date := least(p_akhir, public.hari_ini()); v_jenis text; v_pola uuid; v_wajib int := 0; v_isi int := 0; v_izin int := 0;
        v_telat boolean := coalesce((public._pengaturan_gaji()->>'potong_terlambat')::boolean, false);
begin
  if v_akhir < p_mulai then return jsonb_build_object('sumber', 'Belum berjalan', 'wajib', 0, 'terlaksana', 0, 'berizin', 0, 'tanpa', 0); end if;
  v_jenis := case p_kode when 'WALI_KELAS' then 'kelas' when 'MUHAFFIZH' then 'halaqah' when 'MUSYRIF' then 'kamar'
                         when 'PEMBINA_EKSKUL' then 'ekskul' when 'PELATIH_EKSKUL' then 'ekskul' end;
  if p_kode = 'GURU' then
    -- Jam terjadwal pada hari sekolah; terisi jurnal (terlaksana atau tidak terlaksana berketerangan)
    with hari as (select d::date tgl, extract(dow from d)::int dow from generate_series(p_mulai, v_akhir, interval '1 day') d
                  where extract(dow from d) <> 0 and not public.libur_tugas(d::date, 'sekolah')),
         slot as (select cs.assignment_id, cs.period_id, h.tgl from class_schedules cs join teaching_assignments t on t.id = cs.assignment_id
                  join academic_years a on a.id = t.academic_year_id and a.aktif join hari h on h.dow = cs.hari where cs.employee_id = p_emp)
    select count(*) filter (where s.tgl not in (select public._tanggal_berizin(p_emp, p_mulai, v_akhir))),
           count(*) filter (where s.tgl not in (select public._tanggal_berizin(p_emp, p_mulai, v_akhir)) and exists
             (select 1 from teaching_journals j where j.assignment_id = s.assignment_id and j.tanggal = s.tgl and j.period_id = s.period_id)),
           count(*) filter (where s.tgl in (select public._tanggal_berizin(p_emp, p_mulai, v_akhir)))
      into v_wajib, v_isi, v_izin from slot s;
    return jsonb_build_object('sumber', 'Jurnal mengajar', 'satuan', 'JP', 'wajib', v_wajib, 'terlaksana', v_isi, 'berizin', v_izin, 'tanpa', greatest(0, v_wajib - v_isi));
  elsif v_jenis is not null then
    -- Sesi absensi kelompok yang diasuh (pengasuh utama) pada tanggal pengasuhannya; terisi oleh siapa pun
    with sesi as (
      select k.group_id, d::date tgl, sk.kode from group_keepers k join student_groups g on g.id = k.group_id and g.jenis = v_jenis
        cross join lateral generate_series(greatest(p_mulai, coalesce(k.mulai, p_mulai)), least(v_akhir, coalesce(k.sampai, v_akhir)), interval '1 day') d
        cross join lateral public.sesi_kelompok(k.group_id, d::date) sk
      where k.employee_id = p_emp and k.peran = 'utama' and sk.selesai <= now())
    select count(*) filter (where s.tgl not in (select public._tanggal_berizin(p_emp, p_mulai, v_akhir))),
           count(*) filter (where s.tgl not in (select public._tanggal_berizin(p_emp, p_mulai, v_akhir)) and exists
             (select 1 from student_attendance_sessions sa where sa.group_id = s.group_id and sa.tanggal = s.tgl and sa.sesi = s.kode)),
           count(*) filter (where s.tgl in (select public._tanggal_berizin(p_emp, p_mulai, v_akhir)))
      into v_wajib, v_isi, v_izin from sesi s;
    return jsonb_build_object('sumber', case v_jenis when 'kelas' then 'Absensi kelas' when 'halaqah' then 'Absensi halaqah'
             when 'kamar' then 'Absensi asrama' else 'Absensi ekskul' end, 'satuan', 'sesi',
             'wajib', v_wajib, 'terlaksana', v_isi, 'berizin', v_izin, 'tanpa', greatest(0, v_wajib - v_isi));
  end if;
  -- Presensi pegawai pada pola tugas jabatan fungsional
  select pola_id into v_pola from functional_positions where kode = p_kode;
  if v_pola is null then return null; end if;
  select count(*) filter (where status in ('hadir','terlambat','dinas_luar','tanpa_keterangan','menunggu_verval')
                            or (status in ('izin','sakit','cuti') and a.tanggal not in (select public._tanggal_berizin(p_emp, p_mulai, v_akhir))
                                and coalesce((public._pengaturan_gaji()->>('potong_' || a.status))::boolean, false))),
         count(*) filter (where status in ('hadir','dinas_luar','menunggu_verval') or (status = 'terlambat' and not v_telat)),
         count(*) filter (where status in ('izin','sakit','cuti') and not coalesce((public._pengaturan_gaji()->>('potong_' || a.status))::boolean, false))
    into v_wajib, v_isi, v_izin
    from attendances a where a.employee_id = p_emp and a.pattern_id = v_pola and not a.opsional and a.tanggal between p_mulai and v_akhir;
  return jsonb_build_object('sumber', 'Presensi pegawai', 'satuan', 'sesi', 'wajib', v_wajib, 'terlaksana', v_isi, 'berizin', v_izin, 'tanpa', greatest(0, v_wajib - v_isi));
end $$;

/** Saldo simpanan seorang pegawai pada satu program (tanpa transaksi periode tertentu bila diberikan). */
create or replace function public._saldo_simpanan(p_program uuid, p_emp uuid, p_kecuali uuid default null)
returns numeric language sql stable security definer set search_path = public as $$
  select coalesce(sum(case jenis when 'pencairan' then -besaran else besaran end), 0)
    from savings_transactions where program_id = p_program and employee_id = p_emp and (p_kecuali is null or period_id is distinct from p_kecuali)
$$;

-- ---------------------------------------------------------------------
-- 3. KETENTUAN DAN PERHITUNGAN BARIS (diperbarui)
-- ---------------------------------------------------------------------
create or replace function public._pengaturan_gaji()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('slip_pegawai', false, 'ttd_direktur', false, 'pembulatan', 100,
           'potong_izin', false, 'potong_sakit', false, 'potong_cuti', false, 'potong_terlambat', false,
           'tanggal_gajian', 1, 'honorer_tunjangan_jabatan', true, 'info_beban_kerja', true, 'catatan_slip', '',
           'label_penyesuaian', 'Penyesuaian ketetapan yayasan', 'potong_kehadiran', false)
         || coalesce((select nilai from institution_settings where kunci = 'gaji'), '{}'::jsonb)
$$;

create or replace function public.simpan_pengaturan_gaji(p jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare v jsonb := public._pengaturan_gaji(); k text; v_bulat int; v_tgl int;
begin
  if not public.boleh_kelola_gaji() then raise exception 'Anda tidak berwenang mengatur ketentuan gaji.' using errcode = '42501'; end if;
  foreach k in array array['slip_pegawai','ttd_direktur','potong_izin','potong_sakit','potong_cuti','potong_terlambat',
                           'honorer_tunjangan_jabatan','info_beban_kerja','potong_kehadiran'] loop
    if p ? k then v := v || jsonb_build_object(k, coalesce((p->>k)::boolean, false)); end if;
  end loop;
  if p ? 'pembulatan' then
    v_bulat := coalesce((p->>'pembulatan')::int, 100);
    if v_bulat not in (1, 100, 500, 1000) then raise exception 'Pembulatan hanya 1, 100, 500, atau 1.000 rupiah.'; end if;
    v := v || jsonb_build_object('pembulatan', v_bulat);
  end if;
  if p ? 'tanggal_gajian' then
    v_tgl := coalesce((p->>'tanggal_gajian')::int, 1);
    if v_tgl < 1 or v_tgl > 28 then raise exception 'Tanggal gajian antara 1 dan 28.'; end if;
    v := v || jsonb_build_object('tanggal_gajian', v_tgl);
  end if;
  if p ? 'catatan_slip' then v := v || jsonb_build_object('catatan_slip', left(trim(coalesce(p->>'catatan_slip', '')), 300)); end if;
  if p ? 'label_penyesuaian' then
    v := v || jsonb_build_object('label_penyesuaian', coalesce(nullif(left(trim(coalesce(p->>'label_penyesuaian', '')), 60), ''), 'Penyesuaian ketetapan yayasan'));
  end if;
  insert into institution_settings (kunci, nilai, updated_by) values ('gaji', v, public.saya())
  on conflict (kunci) do update set nilai = excluded.nilai, updated_at = now(), updated_by = excluded.updated_by;
  return public._pengaturan_gaji();
end $$;

create or replace function public._hitung_baris(p_line uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
declare l payroll_lines; pr payroll_periods; e employees; k record; h record; v_ubah record; v_ubahan jsonb; v_hadir jsonb := '[]'::jsonb;
        v_set jsonb := public._pengaturan_gaji(); v_bulat int; v_kh jsonb; pj record; sm record; v_sisa numeric;
        v_tarif salary_rates; v_jam numeric; v_besar numeric; v_cat text[] := '{}'; v_data jsonb;
        d salary_decisions; v_dasar numeric; v_label text := public._pengaturan_gaji()->>'label_penyesuaian';
begin
  select * into l from payroll_lines where id = p_line;
  select * into pr from payroll_periods where id = l.period_id;
  select * into e from employees where id = l.employee_id;
  -- Simpan nilai komponen skema yang pernah diubah
  select coalesce(jsonb_agg(jsonb_build_object('kategori', i.kategori, 'kode', coalesce(i.kode, ''), 'besaran', i.besaran, 'jumlah', i.jumlah,
           'alasan', i.alasan, 'oleh', i.diubah_oleh, 'pada', i.diubah_pada)), '[]'::jsonb) into v_ubahan
    from payroll_items i where i.line_id = p_line and i.sumber = 'manual' and i.besaran_skema is not null;
  delete from payroll_items i where i.line_id = p_line and (i.sumber in ('skema','penetapan') or (i.sumber = 'manual' and i.besaran_skema is not null) or i.kategori = 'penyesuaian');

  -- Komponen skema
  for k in select * from public._komponen_skema(l.employee_id, pr.tanggal_akhir) loop
    if k.catatan is not null then v_cat := array_append(v_cat, k.catatan); continue; end if;
    select * into v_ubah from jsonb_to_recordset(v_ubahan) u(kategori text, kode text, besaran numeric, jumlah numeric, alasan text, oleh uuid, pada timestamptz)
      where u.kategori = k.kategori and u.kode = coalesce(k.kode, '');
    insert into payroll_items (line_id, jenis, kategori, kode, label, besaran_skema, besaran, sumber, alasan, urutan, diubah_oleh, diubah_pada)
    values (p_line, 'pendapatan', k.kategori, k.kode, k.label, k.besaran, coalesce(v_ubah.besaran, k.besaran),
            case when v_ubah.kategori is null then 'skema' else 'manual' end, v_ubah.alasan, k.urutan, v_ubah.oleh, v_ubah.pada);
  end loop;

  -- Honor per jam (honorer)
  if e.status_kepegawaian = 'honorer' then
    if e.kategori_honorer is null then v_cat := array_append(v_cat, 'Kategori honorer belum diisi; honor per jam tidak dihitung.');
    else
      for h in select * from public._jam_honor(l.employee_id, pr.tanggal_mulai, pr.tanggal_akhir) j
               where (j.kode = 'guru' and exists (select 1 from employee_functions ef join functional_positions fp on fp.id = ef.functional_position_id where ef.employee_id = e.id and fp.kode = 'GURU'))
                  or (j.kode = 'muhaffizh' and exists (select 1 from employee_functions ef join functional_positions fp on fp.id = ef.functional_position_id where ef.employee_id = e.id and fp.kode = 'MUHAFFIZH')) loop
        select * into v_tarif from public.tarif_berlaku(pr.tanggal_akhir) t where t.kategori = 'honorer_jam' and t.kunci = h.kode || '_' || e.kategori_honorer;
        if not found then v_cat := array_append(v_cat, ('Tarif honor ' || h.kode || ' ' || e.kategori_honorer || ' belum diatur.')); continue; end if;
        select * into v_ubah from jsonb_to_recordset(v_ubahan) u(kategori text, kode text, besaran numeric, jumlah numeric, alasan text, oleh uuid, pada timestamptz)
          where u.kategori = 'honor' and u.kode = h.kode;
        v_jam := coalesce(v_ubah.jumlah, h.jam);
        v_besar := round(v_jam * v_tarif.besaran);
        insert into payroll_items (line_id, jenis, kategori, kode, label, jumlah, tarif, besaran_skema, besaran, sumber, alasan, rincian, urutan, diubah_oleh, diubah_pada)
        values (p_line, 'pendapatan', 'honor', h.kode, case h.kode when 'guru' then 'Honor mengajar' else 'Honor halaqah' end, v_jam, v_tarif.besaran,
                round(h.jam * v_tarif.besaran), coalesce(v_ubah.besaran, v_besar), case when v_ubah.kategori is null then 'skema' else 'manual' end,
                v_ubah.alasan, h.rincian || jsonb_build_object('jam_otomatis', h.jam), 50, v_ubah.oleh, v_ubah.pada);
      end loop;
    end if;
  end if;

  -- Potongan kehadiran per tugas (hanya tunjangan fungsional). Rincian selalu dihitung (informasi);
  -- potongan dibuat hanya bila sakelar "potong_kehadiran" aktif. Nominal yang diubah Bendahara dipertahankan.
  v_bulat := greatest(1, coalesce((v_set->>'pembulatan')::int, 100));
  for k in select i.kode, i.label, i.besaran from payroll_items i where i.line_id = p_line and i.kategori = 'fungsional' and i.besaran > 0 order by i.urutan loop
    v_kh := public._kehadiran_tugas(l.employee_id, k.kode, pr.tanggal_mulai, pr.tanggal_akhir);
    if v_kh is null then continue; end if;
    v_kh := v_kh || jsonb_build_object('kode', k.kode, 'tugas', regexp_replace(k.label, '^Tunjangan ', ''), 'tunjangan', k.besaran,
              'perkiraan', case when (v_kh->>'wajib')::int > 0 then round(k.besaran * (v_kh->>'tanpa')::numeric / (v_kh->>'wajib')::numeric / v_bulat) * v_bulat else 0 end);
    v_hadir := v_hadir || v_kh;
    if coalesce((v_set->>'potong_kehadiran')::boolean, false) and (v_kh->>'perkiraan')::numeric > 0 then
      select * into v_ubah from jsonb_to_recordset(v_ubahan) u(kategori text, kode text, besaran numeric, jumlah numeric, alasan text, oleh uuid, pada timestamptz)
        where u.kategori = 'potongan_kehadiran' and u.kode = k.kode;
      insert into payroll_items (line_id, jenis, kategori, kode, label, jumlah, besaran_skema, besaran, sumber, alasan, rincian, urutan, diubah_oleh, diubah_pada)
      values (p_line, 'potongan', 'potongan_kehadiran', k.kode, 'Potongan kehadiran ' || (v_kh->>'tugas'), (v_kh->>'tanpa')::numeric,
              (v_kh->>'perkiraan')::numeric, coalesce(v_ubah.besaran, (v_kh->>'perkiraan')::numeric),
              case when v_ubah.kategori is null then 'skema' else 'manual' end, v_ubah.alasan, v_kh, 110, v_ubah.oleh, v_ubah.pada);
    end if;
  end loop;

  -- Cicilan pinjaman aktif (sebesar cicilan, paling banyak sisa pinjaman)
  for pj in select * from employee_loans where employee_id = l.employee_id and status = 'aktif' and mulai_potong <= pr.tanggal_akhir order by created_at loop
    v_sisa := pj.pokok - coalesce((select sum(besaran) from loan_payments where loan_id = pj.id and (period_id is null or period_id <> pr.id)), 0);
    if v_sisa <= 0 then continue; end if;
    select * into v_ubah from jsonb_to_recordset(v_ubahan) u(kategori text, kode text, besaran numeric, jumlah numeric, alasan text, oleh uuid, pada timestamptz)
      where u.kategori = 'pinjaman' and u.kode = pj.id::text;
    insert into payroll_items (line_id, jenis, kategori, kode, label, besaran_skema, besaran, sumber, alasan, rincian, urutan, diubah_oleh, diubah_pada)
    values (p_line, 'potongan', 'pinjaman', pj.id::text, 'Cicilan pinjaman' || coalesce(' – ' || nullif(pj.keterangan, ''), ''), least(pj.cicilan, v_sisa),
            coalesce(v_ubah.besaran, least(pj.cicilan, v_sisa)), case when v_ubah.kategori is null then 'skema' else 'manual' end, v_ubah.alasan,
            jsonb_build_object('pokok', pj.pokok, 'sisa_sebelum', v_sisa, 'cicilan', pj.cicilan), 120, v_ubah.oleh, v_ubah.pada);
  end loop;

  -- Setoran simpanan program (anggota aktif)
  for sm in select m.*, sp.nama from savings_members m join savings_programs sp on sp.id = m.program_id
             where m.employee_id = l.employee_id and m.aktif and sp.aktif and m.setoran > 0 and m.mulai <= pr.tanggal_akhir
               and (m.berhenti is null or m.berhenti >= pr.tanggal_mulai) order by sp.nama loop
    select * into v_ubah from jsonb_to_recordset(v_ubahan) u(kategori text, kode text, besaran numeric, jumlah numeric, alasan text, oleh uuid, pada timestamptz)
      where u.kategori = 'simpanan' and u.kode = sm.program_id::text;
    insert into payroll_items (line_id, jenis, kategori, kode, label, besaran_skema, besaran, sumber, alasan, rincian, urutan, diubah_oleh, diubah_pada)
    values (p_line, 'potongan', 'simpanan', sm.program_id::text, 'Simpanan ' || sm.nama, sm.setoran, coalesce(v_ubah.besaran, sm.setoran),
            case when v_ubah.kategori is null then 'skema' else 'manual' end, v_ubah.alasan,
            jsonb_build_object('saldo_sebelum', public._saldo_simpanan(sm.program_id, l.employee_id, pr.id)), 130, v_ubah.oleh, v_ubah.pada);
  end loop;

  -- Penyesuaian: target diterima (isi/impor) didahulukan, lalu penetapan yayasan yang berlaku
  select coalesce(sum(case when jenis = 'pendapatan' then besaran else -besaran end), 0) into v_dasar from payroll_items where line_id = p_line;
  if l.target_diterima is not null then
    if l.target_diterima - v_dasar <> 0 then
      insert into payroll_items (line_id, jenis, kategori, label, besaran, sumber, alasan, rincian, urutan)
      values (p_line, 'pendapatan', 'penyesuaian', v_label, l.target_diterima - v_dasar, 'manual', l.alasan_target,
              jsonb_build_object('dasar', 'Jumlah diterima ditetapkan', 'target_diterima', l.target_diterima), 95);
    end if;
  else
    select * into d from salary_decisions s where s.employee_id = l.employee_id and s.berlaku_mulai <= pr.tanggal_akhir
       and (s.berlaku_sampai is null or s.berlaku_sampai >= pr.tanggal_mulai) order by s.berlaku_mulai desc, s.created_at desc limit 1;
    if found then
      v_besar := case d.mode when 'selisih' then d.nilai
                 else d.nilai - coalesce((select sum(besaran) from payroll_items where line_id = p_line and jenis = 'pendapatan'), 0) end;
      if v_besar <> 0 then
        insert into payroll_items (line_id, jenis, kategori, label, besaran, sumber, alasan, rincian, urutan)
        values (p_line, 'pendapatan', 'penyesuaian', v_label, v_besar, 'penetapan', d.keterangan,
                jsonb_build_object('penetapan_id', d.id, 'mode', d.mode, 'nilai', d.nilai, 'dasar', d.dasar), 95);
      end if;
    end if;
  end if;

  v_data := public._data_gaji(l.employee_id, pr.tanggal_akhir);
  v_data := jsonb_set(v_data, '{catatan}', (v_data->'catatan') || to_jsonb(v_cat)) || jsonb_build_object('kehadiran', v_hadir);
  update payroll_lines set data = v_data where id = p_line;
  perform public._jumlahkan_baris(p_line);
end $$;

-- ---------------------------------------------------------------------
-- 4. PINJAMAN
-- ---------------------------------------------------------------------
create or replace function public.simpan_pinjaman(p jsonb)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v uuid := nullif(p->>'id', '')::uuid; v_pokok numeric := round((p->>'pokok')::numeric); v_cicil numeric := round((p->>'cicilan')::numeric);
begin
  perform public._wajib_kelola_gaji();
  if v_pokok is null or v_pokok <= 0 then raise exception 'Isi nilai pinjaman.'; end if;
  if v_cicil is null or v_cicil <= 0 then raise exception 'Isi cicilan per bulan.'; end if;
  if v_cicil > v_pokok then raise exception 'Cicilan tidak boleh melebihi nilai pinjaman.'; end if;
  if nullif(p->>'mulai_potong', '') is null then raise exception 'Isi bulan mulai dipotong.'; end if;
  if v is null then
    insert into employee_loans (employee_id, keterangan, pokok, cicilan, tanggal, mulai_potong, catatan, dibuat_oleh)
    values ((p->>'employee_id')::uuid, nullif(trim(p->>'keterangan'), ''), v_pokok, v_cicil, coalesce(nullif(p->>'tanggal', '')::date, public.hari_ini()),
            date_trunc('month', (p->>'mulai_potong')::date)::date, nullif(trim(p->>'catatan'), ''), public.saya()) returning id into v;
  else
    if v_pokok < coalesce((select sum(besaran) from loan_payments where loan_id = v), 0) then raise exception 'Nilai pinjaman lebih kecil dari yang sudah dibayar.'; end if;
    update employee_loans set keterangan = nullif(trim(p->>'keterangan'), ''), pokok = v_pokok, cicilan = v_cicil,
      tanggal = coalesce(nullif(p->>'tanggal', '')::date, tanggal), mulai_potong = date_trunc('month', (p->>'mulai_potong')::date)::date,
      catatan = nullif(trim(p->>'catatan'), ''), updated_at = now() where id = v and status = 'aktif';
    if not found then raise exception 'Pinjaman tidak ditemukan atau sudah tidak aktif.'; end if;
  end if;
  return v;
end $$;

/** Catat pembayaran pinjaman di luar gaji (tunai/transfer langsung ke Bendahara). Lunas otomatis bila sisa habis. */
create or replace function public.bayar_pinjaman(p_loan uuid, p_besaran numeric, p_tanggal date, p_keterangan text)
returns void language plpgsql volatile security definer set search_path = public as $$
declare v_sisa numeric;
begin
  perform public._wajib_kelola_gaji();
  select pokok - coalesce((select sum(besaran) from loan_payments where loan_id = p_loan), 0) into v_sisa from employee_loans where id = p_loan and status = 'aktif';
  if v_sisa is null then raise exception 'Pinjaman tidak ditemukan atau sudah tidak aktif.'; end if;
  if p_besaran is null or p_besaran <= 0 then raise exception 'Isi nominal pembayaran.'; end if;
  if p_besaran > v_sisa then raise exception 'Pembayaran melebihi sisa pinjaman (%).', to_char(v_sisa, 'FM999G999G999G999'); end if;
  insert into loan_payments (loan_id, besaran, tanggal, keterangan, dicatat_oleh)
  values (p_loan, round(p_besaran), coalesce(p_tanggal, public.hari_ini()), coalesce(nullif(trim(p_keterangan), ''), 'Pembayaran di luar gaji'), public.saya());
  if v_sisa - p_besaran <= 0 then update employee_loans set status = 'lunas', updated_at = now() where id = p_loan; end if;
end $$;

create or replace function public.batalkan_pinjaman(p_loan uuid, p_alasan text)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  perform public._wajib_kelola_gaji();
  if length(trim(coalesce(p_alasan, ''))) < 3 then raise exception 'Isi alasan pembatalan.'; end if;
  if exists (select 1 from loan_payments where loan_id = p_loan) then
    update employee_loans set status = 'lunas', catatan = trim(p_alasan), updated_at = now() where id = p_loan and status = 'aktif';  -- sudah ada pembayaran: ditutup
  else
    update employee_loans set status = 'batal', catatan = trim(p_alasan), updated_at = now() where id = p_loan and status = 'aktif';
  end if;
  if not found then raise exception 'Pinjaman tidak ditemukan atau sudah tidak aktif.'; end if;
end $$;

create or replace function public.daftar_pinjaman()
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if not public.boleh_lihat_gaji() then raise exception 'Anda tidak berwenang melihat data gaji.' using errcode = '42501'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'employee_id', x.employee_id, 'niy', e.niy, 'nama', e.nama_lengkap,
      'keterangan', x.keterangan, 'pokok', x.pokok, 'cicilan', x.cicilan, 'tanggal', x.tanggal, 'mulai_potong', x.mulai_potong, 'status', x.status,
      'catatan', x.catatan, 'dibayar', b.n, 'sisa', x.pokok - b.n,
      'riwayat', (select coalesce(jsonb_agg(jsonb_build_object('tanggal', y.tanggal, 'besaran', y.besaran, 'keterangan', y.keterangan,
                   'periode', (select to_char(make_date(pp.tahun, pp.bulan, 1), 'MM/YYYY') from payroll_periods pp where pp.id = y.period_id)) order by y.tanggal, y.created_at), '[]')
                  from loan_payments y where y.loan_id = x.id))
      order by (x.status = 'aktif') desc, e.nama_lengkap, x.tanggal desc)
    from employee_loans x join employees e on e.id = x.employee_id
    cross join lateral (select coalesce(sum(besaran), 0) n from loan_payments where loan_id = x.id) b), '[]'::jsonb);
end $$;

-- ---------------------------------------------------------------------
-- 5. SIMPANAN PROGRAM
-- ---------------------------------------------------------------------
create or replace function public.simpan_program_simpanan(p jsonb)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v uuid := nullif(p->>'id', '')::uuid;
begin
  perform public._wajib_kelola_gaji();
  if length(trim(coalesce(p->>'nama', ''))) < 3 then raise exception 'Isi nama program.'; end if;
  if v is null then
    insert into savings_programs (nama, keterangan, setoran_bawaan, aktif, urutan)
    values (trim(p->>'nama'), nullif(trim(p->>'keterangan'), ''), coalesce(round((p->>'setoran_bawaan')::numeric), 0), coalesce((p->>'aktif')::boolean, true),
            coalesce((select max(urutan) + 1 from savings_programs), 1)) returning id into v;
  else
    update savings_programs set nama = trim(p->>'nama'), keterangan = nullif(trim(p->>'keterangan'), ''),
      setoran_bawaan = coalesce(round((p->>'setoran_bawaan')::numeric), 0), aktif = coalesce((p->>'aktif')::boolean, aktif) where id = v;
  end if;
  return v;
end $$;

/** Ikutkan/ubah keanggotaan pegawai pada program: { program_id, employee_id, setoran, mulai, berhenti?, aktif?, catatan? }. */
create or replace function public.simpan_anggota_simpanan(p jsonb)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  perform public._wajib_kelola_gaji();
  if coalesce(round((p->>'setoran')::numeric), -1) < 0 then raise exception 'Isi setoran per bulan.'; end if;
  insert into savings_members (program_id, employee_id, setoran, mulai, berhenti, aktif, catatan)
  values ((p->>'program_id')::uuid, (p->>'employee_id')::uuid, round((p->>'setoran')::numeric), date_trunc('month', coalesce(nullif(p->>'mulai', '')::date, public.hari_ini()))::date,
          nullif(p->>'berhenti', '')::date, coalesce((p->>'aktif')::boolean, true), nullif(trim(p->>'catatan'), ''))
  on conflict (program_id, employee_id) do update set setoran = excluded.setoran, mulai = excluded.mulai, berhenti = excluded.berhenti,
    aktif = excluded.aktif, catatan = excluded.catatan;
end $$;

/** Transaksi simpanan di luar slip: setoran awal (saldo lama), pencairan, koreksi (boleh negatif). */
create or replace function public.catat_transaksi_simpanan(p jsonb)
returns void language plpgsql volatile security definer set search_path = public as $$
declare v_jenis text := p->>'jenis'; v_besar numeric := round((p->>'besaran')::numeric); v_saldo numeric;
begin
  perform public._wajib_kelola_gaji();
  if v_jenis not in ('setoran_awal','pencairan','koreksi') then raise exception 'Jenis transaksi tidak dikenal.'; end if;
  if v_besar is null or (v_jenis <> 'koreksi' and v_besar <= 0) or v_besar = 0 then raise exception 'Isi nominal transaksi.'; end if;
  if length(trim(coalesce(p->>'keterangan', ''))) < 3 and v_jenis <> 'setoran_awal' then raise exception 'Isi keterangan.'; end if;
  v_saldo := public._saldo_simpanan((p->>'program_id')::uuid, (p->>'employee_id')::uuid);
  if v_jenis = 'pencairan' and v_besar > v_saldo then raise exception 'Pencairan melebihi saldo (%).', to_char(v_saldo, 'FM999G999G999G999'); end if;
  insert into savings_transactions (program_id, employee_id, jenis, besaran, tanggal, keterangan, dicatat_oleh)
  values ((p->>'program_id')::uuid, (p->>'employee_id')::uuid, v_jenis, v_besar, coalesce(nullif(p->>'tanggal', '')::date, public.hari_ini()),
          coalesce(nullif(trim(p->>'keterangan'), ''), 'Saldo awal'), public.saya());
end $$;

create or replace function public.daftar_simpanan()
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if not public.boleh_lihat_gaji() then raise exception 'Anda tidak berwenang melihat data gaji.' using errcode = '42501'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', sp.id, 'nama', sp.nama, 'keterangan', sp.keterangan, 'setoran_bawaan', sp.setoran_bawaan,
      'aktif', sp.aktif, 'saldo', (select coalesce(sum(case jenis when 'pencairan' then -besaran else besaran end), 0) from savings_transactions where program_id = sp.id),
      'anggota', (select coalesce(jsonb_agg(jsonb_build_object('employee_id', m.employee_id, 'niy', e.niy, 'nama', e.nama_lengkap, 'setoran', m.setoran,
          'mulai', m.mulai, 'berhenti', m.berhenti, 'aktif', m.aktif, 'catatan', m.catatan, 'saldo', public._saldo_simpanan(sp.id, m.employee_id),
          'riwayat', (select coalesce(jsonb_agg(jsonb_build_object('tanggal', t.tanggal, 'jenis', t.jenis, 'besaran', t.besaran, 'keterangan', t.keterangan)
                      order by t.tanggal desc, t.created_at desc), '[]') from savings_transactions t where t.program_id = sp.id and t.employee_id = m.employee_id))
          order by e.nama_lengkap), '[]') from savings_members m join employees e on e.id = m.employee_id where m.program_id = sp.id))
      order by sp.urutan, sp.nama) from savings_programs sp), '[]'::jsonb);
end $$;

-- ---------------------------------------------------------------------
-- 6. HAK EKSEKUSI
-- ---------------------------------------------------------------------
do $$
declare f text;
begin
  foreach f in array array['simpan_pengaturan_gaji(jsonb)','simpan_pinjaman(jsonb)','bayar_pinjaman(uuid,numeric,date,text)','batalkan_pinjaman(uuid,text)',
    'daftar_pinjaman()','simpan_program_simpanan(jsonb)','simpan_anggota_simpanan(jsonb)','catat_transaksi_simpanan(jsonb)','daftar_simpanan()'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  foreach f in array array['_pengaturan_gaji()','_hitung_baris(uuid)','_tanggal_berizin(uuid,date,date)','_kehadiran_tugas(uuid,text,date,date)',
    '_saldo_simpanan(uuid,uuid,uuid)'] loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN (hasil yang benar: baris 1–5 "Sesuai"; baris 6 keterangan)
-- ---------------------------------------------------------------------
select '1. Tabel pinjaman dan simpanan (5)' as pemeriksaan,
       case when (select count(*) from pg_class where relname in ('employee_loans','loan_payments','savings_programs','savings_members','savings_transactions') and relrowsecurity) = 5
            then 'Sesuai' else 'Periksa' end as hasil
union all select '2. Tabel tertutup untuk tulis langsung', case when (select count(*) from pg_policies where tablename in
  ('employee_loans','loan_payments','savings_programs','savings_members','savings_transactions') and cmd <> 'SELECT') = 0 then 'Sesuai' else 'Periksa' end
union all select '3. Fungsi kehadiran per tugas', case when exists (select 1 from pg_proc where proname = '_kehadiran_tugas') then 'Sesuai' else 'Periksa' end
union all select '4. Perhitungan baris memuat potongan', case when pg_get_functiondef('public._hitung_baris(uuid)'::regprocedure) like '%employee_loans%' then 'Sesuai' else 'Periksa' end
union all select '5. Sakelar potongan kehadiran (bawaan nonaktif)', case when (public._pengaturan_gaji()->>'potong_kehadiran')::boolean = false then 'Sesuai' else 'Diaktifkan (sesuai pilihan)' end
union all select '6. Program simpanan', (select string_agg(nama, ', ' order by urutan) from savings_programs);
