-- SIMKA PRO | supabase/migrations/20261011007300_gaji_slip.sql | v1.0 | Fase 11 – Tahap 4 Penerbitan slip gaji, Slip saya, permintaan slip | 11/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 11 · Migrasi 73: Penerbitan slip gaji (Blueprint Bagian 36)
--   * Alur: periode draf → AJUKAN TERBIT (pengelola gaji) → tanda tangan elektronik Bendahara (wajib) dan Direktur (bila
--     Ketentuan "ttd_direktur" aktif; Plt Direktur boleh) → TERBIT. Pengaju yang juga pejabat langsung tercatat menandatangani.
--     Ditolak penanda tangan → kembali draf dengan alasan. Pengelola dapat menarik pengajuan.
--   * Saat terbit: setiap slip mendapat nomor (format "slip"), kode validasi, salinan beku di registri dokumen (Cek Keabsahan
--     menampilkan data ringkas TANPA nominal), cicilan pinjaman tercatat sebagai pembayaran, setoran simpanan tercatat sebagai
--     transaksi. Slip terkunci.
--   * Revisi slip: pengelola membuka revisi satu slip (beralasan), mengubah, lalu Bendahara menerbitkan revisinya: slip lama
--     "Direvisi" dan menunjuk slip pengganti; pembayaran pinjaman/setoran periode itu disesuaikan.
--   * Slip di akun pegawai: tampil bila Ketentuan "slip_pegawai" aktif, ATAU dibukakan Bendahara khusus untuk pegawai itu
--     (menanggapi permintaan slip). Permintaan slip dapat diajukan pegawai dari Profil walaupun menu Gaji tersembunyi.
--   * Slip tidak masuk inventaris buku agenda surat keluar (data sensitif); registri slip hanya terlihat pembaca gaji dan pemiliknya.
-- Jalankan SETELAH migrasi 7200. Aman dijalankan ulang.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. KOLOM DAN TABEL
-- ---------------------------------------------------------------------
alter table public.payroll_periods add column if not exists diajukan_pada timestamptz;
alter table public.payroll_periods add column if not exists diajukan_oleh uuid references public.employees(id) on delete set null;
alter table public.payroll_periods add column if not exists diterbitkan_pada timestamptz;
alter table public.payroll_periods add column if not exists alasan_tolak text;

alter table public.payroll_lines add column if not exists nomor_slip text;
alter table public.payroll_lines add column if not exists kode_validasi text;
alter table public.payroll_lines add column if not exists document_id uuid references public.document_registry(id) on delete set null;
alter table public.payroll_lines add column if not exists diterbitkan_pada timestamptz;
alter table public.payroll_lines add column if not exists dibuka_pegawai boolean not null default false;
alter table public.payroll_lines add column if not exists revisi_ke int not null default 0;
alter table public.payroll_lines add column if not exists dalam_revisi boolean not null default false;
alter table public.payroll_lines add column if not exists alasan_revisi text;
alter table public.payroll_lines add column if not exists riwayat jsonb not null default '[]'::jsonb;

create table if not exists public.payroll_signatures (
  id          uuid primary key default gen_random_uuid(),
  period_id   uuid not null references public.payroll_periods(id) on delete cascade,
  peran       text not null check (peran in ('bendahara','direktur')),
  urutan      int not null default 1,
  employee_id uuid references public.employees(id) on delete set null,
  nama        text,
  jabatan     text,
  niy         text,
  status      text not null default 'menunggu' check (status in ('menunggu','ditandatangani','ditolak')),
  waktu       timestamptz,
  catatan     text,
  unique (period_id, peran)
);

create table if not exists public.payroll_slip_requests (
  id              uuid primary key default gen_random_uuid(),
  employee_id     uuid not null references public.employees(id) on delete cascade,
  period_id       uuid references public.payroll_periods(id) on delete set null,
  catatan         text,
  status          text not null default 'menunggu' check (status in ('menunggu','dibuka','dicetak','ditolak')),
  ditanggapi_oleh uuid references public.employees(id) on delete set null,
  tanggapan       text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index if not exists payroll_slip_requests_emp_idx on public.payroll_slip_requests (employee_id, created_at desc);

alter table public.payroll_signatures enable row level security;
alter table public.payroll_slip_requests enable row level security;
drop policy if exists baca on public.payroll_signatures;
create policy baca on public.payroll_signatures for select to authenticated using (public.boleh_lihat_gaji() or employee_id = public.saya());
drop policy if exists baca on public.payroll_slip_requests;
create policy baca on public.payroll_slip_requests for select to authenticated using (public.boleh_lihat_gaji() or employee_id = public.saya());
grant select on public.payroll_signatures, public.payroll_slip_requests to authenticated;

-- ---------------------------------------------------------------------
-- 2. PEJABAT PENANDA TANGAN
-- ---------------------------------------------------------------------
/** Pegawai aktif yang berhak menandatangani slip sebagai bendahara/direktur (termasuk Plt yang berlaku hari ini). */
create or replace function public._pejabat_gaji(p_peran text)
returns setof uuid language sql stable security definer set search_path = public as $$
  select es.employee_id from employee_structurals es join structural_positions sp on sp.id = es.structural_position_id
    join employees e on e.id = es.employee_id
   where sp.kode = case p_peran when 'bendahara' then 'BENDAHARA' else 'DIREKTUR' end and e.status_keaktifan = 'aktif' and e.status_akun = 'aktif'
  union
  select a.employee_id from acting_assignments a join structural_positions sp on sp.id = a.structural_position_id
   where sp.kode = case p_peran when 'bendahara' then 'BENDAHARA' else 'DIREKTUR' end
     and (a.mulai is null or a.mulai <= public.hari_ini()) and (a.sampai is null or a.sampai >= public.hari_ini())
$$;

create or replace function public._ttd_periode(p_period uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('peran', s.peran, 'nama', s.nama, 'jabatan', s.jabatan, 'niy', s.niy, 'status', s.status,
           'waktu', s.waktu, 'catatan', s.catatan, 'saya', s.employee_id = public.saya()
                    or (s.status = 'menunggu' and public.saya() in (select public._pejabat_gaji(s.peran)))) order by s.urutan), '[]'::jsonb)
    from payroll_signatures s where s.period_id = p_period
$$;

/** Baris yang boleh diubah: periode masih draf, atau slip sedang dibuka untuk revisi. */
create or replace function public._wajib_baris_ubah(p_line uuid)
returns void language plpgsql stable security definer set search_path = public as $$
declare l payroll_lines;
begin
  select * into l from payroll_lines where id = p_line;
  if not found then raise exception 'Baris gaji tidak ditemukan.'; end if;
  if l.dalam_revisi then return; end if;
  perform public._wajib_periode_draf(l.period_id);
end $$;

-- ---------------------------------------------------------------------
-- 3. PENERBITAN
-- ---------------------------------------------------------------------
/** Terbitkan (atau terbitkan ulang hasil revisi) satu slip: nomor, kode validasi, registri, pembayaran pinjaman, setoran simpanan. */
create or replace function public._terbitkan_slip(p_line uuid, p_oleh uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
declare l payroll_lines; pr payroll_periods; v_kode text; v_nomor text; v_doc uuid; v_isi jsonb; i record; v_doc_lama uuid; v_sisa numeric;
begin
  select * into l from payroll_lines where id = p_line;
  select * into pr from payroll_periods where id = l.period_id;
  v_doc_lama := l.document_id;
  -- Nomor: tetap untuk revisi
  v_nomor := l.nomor_slip;
  if v_nomor is null then
    perform set_config('simka.nomor_sistem', '1', true);
    v_nomor := public.ambil_nomor('slip', pr.tanggal_akhir, 'D', null, 'pondok')->>'nomor';
    perform set_config('simka.nomor_sistem', '', true);
  end if;
  v_kode := public._kode_dokumen();
  v_isi := jsonb_build_object('periode', to_char(make_date(pr.tahun, pr.bulan, 1), 'YYYY-MM'), 'nomor', v_nomor, 'data', l.data,
             'pendapatan', l.total_pendapatan, 'potongan', l.total_potongan, 'diterima', l.diterima, 'revisi_ke', l.revisi_ke,
             'item', (select jsonb_agg(jsonb_build_object('jenis', jenis, 'label', label, 'besaran', besaran) order by jenis desc, urutan) from payroll_items where line_id = p_line));
  -- Registri: ref unik (payroll_lines, id) dipindah ke dokumen baru; dokumen lama menjadi Direvisi
  if v_doc_lama is not null then
    update document_registry set ref_tabel = 'payroll_lines_r' || greatest(0, l.revisi_ke - 1), status = 'direvisi' where id = v_doc_lama;
  end if;
  insert into document_registry (kode, jenis, jenis_nama, nomor, perihal, subjek, periode, kop_kode, status, sidik, ref_tabel, ref_id,
                                 diterbitkan_pada, diterbitkan_oleh, mode_ttd, tautan, isi)
  values (v_kode, 'slip_gaji', 'Slip Gaji', v_nomor || case when l.revisi_ke > 0 then ' (revisi ' || l.revisi_ke || ')' else '' end,
          'Slip gaji pegawai', l.data->>'nama', public.nama_bulan_periode(pr.tahun, pr.bulan), 'pondok', 'sah', public._sidik(v_isi),
          'payroll_lines', p_line, now(), p_oleh, 'elektronik', '/gaji/slip?slip=' || p_line, v_isi)
  returning id into v_doc;
  if v_doc_lama is not null then update document_registry set pengganti_id = v_doc where id = v_doc_lama; end if;
  insert into document_signatures (document_id, urutan, posisi, employee_id, nama, jabatan, niy, status, waktu)
  select v_doc, s.urutan, 'kiri', s.employee_id, s.nama, s.jabatan, s.niy, 'ditandatangani', coalesce(s.waktu, now())
    from payroll_signatures s where s.period_id = pr.id and s.status = 'ditandatangani';
  -- Pembayaran pinjaman dan setoran simpanan periode ini (dihapus dulu bila terbit ulang)
  delete from loan_payments where period_id = pr.id and loan_id in (select id from employee_loans where employee_id = l.employee_id);
  delete from savings_transactions where period_id = pr.id and employee_id = l.employee_id;
  for i in select * from payroll_items where line_id = p_line and jenis = 'potongan' and kategori in ('pinjaman','simpanan') and besaran > 0 loop
    if i.kategori = 'pinjaman' then
      insert into loan_payments (loan_id, period_id, besaran, tanggal, keterangan, dicatat_oleh)
      values (i.kode::uuid, pr.id, i.besaran, coalesce(pr.tanggal_bayar, pr.tanggal_akhir), 'Potongan gaji ' || public.nama_bulan_periode(pr.tahun, pr.bulan), p_oleh);
    else
      insert into savings_transactions (program_id, employee_id, jenis, besaran, period_id, tanggal, keterangan, dicatat_oleh)
      values (i.kode::uuid, l.employee_id, 'setoran', i.besaran, pr.id, coalesce(pr.tanggal_bayar, pr.tanggal_akhir), 'Potongan gaji ' || public.nama_bulan_periode(pr.tahun, pr.bulan), p_oleh);
    end if;
  end loop;
  -- Status pinjaman mengikuti sisa
  for i in select x.id, x.pokok - coalesce((select sum(besaran) from loan_payments where loan_id = x.id), 0) sisa
             from employee_loans x where x.employee_id = l.employee_id and x.status in ('aktif','lunas') loop
    update employee_loans set status = case when i.sisa <= 0 then 'lunas' else 'aktif' end, updated_at = now()
     where id = i.id and status <> case when i.sisa <= 0 then 'lunas' else 'aktif' end and status <> 'batal';
  end loop;
  update payroll_lines set nomor_slip = v_nomor, kode_validasi = v_kode, document_id = v_doc, diterbitkan_pada = now(), dalam_revisi = false where id = p_line;
end $$;

create or replace function public.nama_bulan_periode(p_tahun int, p_bulan int)
returns text language sql immutable as $$
  select (array['Januari','Februari','Maret','April','Mei','Juni','Juli','Agustus','September','Oktober','November','Desember'])[p_bulan] || ' ' || p_tahun
$$;

/** Slip tampil di akun pegawai? (Ketentuan aktif, atau slip itu dibukakan Bendahara) */
create or replace function public._slip_terbuka(l payroll_lines)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((public._pengaturan_gaji()->>'slip_pegawai')::boolean, false) or l.dibuka_pegawai
$$;

create or replace function public._terbitkan_periode(p_period uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
declare pr payroll_periods; l record; ln payroll_lines; v_oleh uuid;
begin
  select * into pr from payroll_periods where id = p_period;
  v_oleh := coalesce(pr.diajukan_oleh, public.saya());
  for l in select id from payroll_lines where period_id = p_period order by data->>'nama' loop perform public._terbitkan_slip(l.id, v_oleh); end loop;
  update payroll_periods set status = 'terbit', diterbitkan_pada = now(), updated_at = now() where id = p_period;
  if pr.diajukan_oleh is not null then
    perform public.kirim_notifikasi(pr.diajukan_oleh, 'Gaji ' || public.nama_bulan_periode(pr.tahun, pr.bulan) || ' terbit',
      'Semua slip sudah ditandatangani dan terkunci.', '/gaji/periode?periode=' || p_period, 'Receipt', 'hijau');
  end if;
  -- Pegawai dikabari hanya bila slip ditampilkan di akun pegawai
  for ln in select * from payroll_lines where period_id = p_period loop
    if public._slip_terbuka(ln) then
      perform public.kirim_notifikasi(ln.employee_id, 'Slip gaji ' || public.nama_bulan_periode(pr.tahun, pr.bulan) || ' terbit',
        'Ketuk untuk melihat dan mengunduh slip gaji Anda.', '/gaji/slip?slip=' || ln.id, 'Receipt', 'hijau');
    end if;
  end loop;
end $$;

/** Cek apakah semua tanda tangan lengkap; bila ya, terbitkan. */
create or replace function public._cek_ttd_periode(p_period uuid)
returns boolean language plpgsql volatile security definer set search_path = public as $$
begin
  if exists (select 1 from payroll_signatures where period_id = p_period and status <> 'ditandatangani') then return false; end if;
  perform public._terbitkan_periode(p_period);
  return true;
end $$;

create or replace function public._isi_ttd(p_period uuid, p_peran text, p_emp uuid)
returns void language sql volatile security definer set search_path = public as $$
  update payroll_signatures set status = 'ditandatangani', waktu = now(), employee_id = p_emp,
    nama = (select nama_lengkap from employees where id = p_emp), niy = (select niy from employees where id = p_emp),
    jabatan = case p_peran when 'bendahara' then 'Bendahara' else
      coalesce((select sp.nama from employee_structurals es join structural_positions sp on sp.id = es.structural_position_id
                 where es.employee_id = p_emp and sp.kode = 'DIREKTUR'), 'Plt. Direktur') end
  where period_id = p_period and peran = p_peran
$$;

/** Ajukan penerbitan periode: tanda tangan Bendahara (dan Direktur bila Ketentuan aktif). Hasil: 'terbit' atau 'diajukan'. */
create or replace function public.ajukan_periode_gaji(p_period uuid)
returns text language plpgsql volatile security definer set search_path = public as $$
declare pr payroll_periods; v_peran text; v_emp uuid;
begin
  perform public._wajib_kelola_gaji(); pr := public._wajib_periode_draf(p_period);
  if not exists (select 1 from payroll_lines where period_id = p_period) then raise exception 'Periode tidak memiliki pegawai.'; end if;
  if not exists (select 1 from public._pejabat_gaji('bendahara')) then
    raise exception 'Belum ada pegawai berakun aktif yang memegang jabatan struktural Bendahara. Tetapkan dulu di Data Pegawai.'; end if;
  if coalesce((public._pengaturan_gaji()->>'ttd_direktur')::boolean, false) and not exists (select 1 from public._pejabat_gaji('direktur')) then
    raise exception 'Ketentuan meminta tanda tangan Direktur, tetapi belum ada Direktur (atau Plt) berakun aktif.'; end if;
  delete from payroll_signatures where period_id = p_period;
  insert into payroll_signatures (period_id, peran, urutan, jabatan) values (p_period, 'bendahara', 1, 'Bendahara');
  if coalesce((public._pengaturan_gaji()->>'ttd_direktur')::boolean, false) then
    insert into payroll_signatures (period_id, peran, urutan, jabatan) values (p_period, 'direktur', 2, 'Direktur');
  end if;
  update payroll_periods set status = 'diajukan', diajukan_pada = now(), diajukan_oleh = public.saya(), alasan_tolak = null, updated_at = now() where id = p_period;
  -- Pengaju yang juga pejabat langsung menandatangani
  foreach v_peran in array array['bendahara','direktur'] loop
    if exists (select 1 from payroll_signatures where period_id = p_period and peran = v_peran) then
      if public.saya() in (select public._pejabat_gaji(v_peran)) then perform public._isi_ttd(p_period, v_peran, public.saya());
      else
        for v_emp in select public._pejabat_gaji(v_peran) loop
          perform public.kirim_notifikasi(v_emp, 'Tanda tangan gaji ' || public.nama_bulan_periode(pr.tahun, pr.bulan),
            'Daftar gaji menunggu tanda tangan elektronik Anda.', '/gaji/periode?periode=' || p_period, 'Signature', 'ungu');
        end loop;
      end if;
    end if;
  end loop;
  if public._cek_ttd_periode(p_period) then return 'terbit'; end if;
  return 'diajukan';
end $$;

/** Tanda tangani (setuju) atau tolak (beralasan) pengajuan penerbitan. */
create or replace function public.tandatangani_periode_gaji(p_period uuid, p_setuju boolean, p_catatan text default null)
returns text language plpgsql volatile security definer set search_path = public as $$
declare pr payroll_periods; s payroll_signatures; v_ada boolean := false;
begin
  select * into pr from payroll_periods where id = p_period;
  if pr.status <> 'diajukan' then raise exception 'Periode gaji ini tidak sedang menunggu tanda tangan.'; end if;
  for s in select * from payroll_signatures where period_id = p_period and status = 'menunggu' order by urutan loop
    if public.saya() in (select public._pejabat_gaji(s.peran)) then
      v_ada := true;
      if p_setuju then perform public._isi_ttd(p_period, s.peran, public.saya());
      else
        if length(trim(coalesce(p_catatan, ''))) < 3 then raise exception 'Alasan penolakan wajib diisi.'; end if;
        update payroll_signatures set status = 'menunggu', employee_id = null, nama = null, waktu = null where period_id = p_period;
        update payroll_periods set status = 'draf', alasan_tolak = trim(p_catatan), updated_at = now() where id = p_period;
        if pr.diajukan_oleh is not null then
          perform public.kirim_notifikasi(pr.diajukan_oleh, 'Gaji ' || public.nama_bulan_periode(pr.tahun, pr.bulan) || ' dikembalikan',
            trim(p_catatan), '/gaji/periode?periode=' || p_period, 'XCircle', 'merah');
        end if;
        delete from payroll_signatures where period_id = p_period;
        return 'ditolak';
      end if;
    end if;
  end loop;
  if not v_ada then raise exception 'Anda tidak termasuk penanda tangan yang sedang ditunggu.' using errcode = '42501'; end if;
  if public._cek_ttd_periode(p_period) then return 'terbit'; end if;
  return 'diajukan';
end $$;

create or replace function public.tarik_pengajuan_gaji(p_period uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  perform public._wajib_kelola_gaji();
  if (select status from payroll_periods where id = p_period) <> 'diajukan' then raise exception 'Periode tidak sedang diajukan.'; end if;
  delete from payroll_signatures where period_id = p_period;
  update payroll_periods set status = 'draf', updated_at = now() where id = p_period;
end $$;

-- ---------------------------------------------------------------------
-- 4. REVISI SLIP
-- ---------------------------------------------------------------------
create or replace function public.mulai_revisi_slip(p_line uuid, p_alasan text)
returns void language plpgsql volatile security definer set search_path = public as $$
declare l payroll_lines;
begin
  perform public._wajib_kelola_gaji();
  select * into l from payroll_lines where id = p_line;
  if l.id is null or l.document_id is null then raise exception 'Slip belum terbit.'; end if;
  if l.dalam_revisi then raise exception 'Slip ini sudah dibuka untuk revisi.'; end if;
  if length(trim(coalesce(p_alasan, ''))) < 3 then raise exception 'Alasan revisi wajib diisi.'; end if;
  update payroll_lines set dalam_revisi = true, alasan_revisi = trim(p_alasan),
    riwayat = riwayat || jsonb_build_object('revisi_ke', revisi_ke, 'kode', kode_validasi, 'diterima', diterima, 'pendapatan', total_pendapatan,
                                            'potongan', total_potongan, 'waktu', diterbitkan_pada, 'alasan_revisi', trim(p_alasan)),
    revisi_ke = revisi_ke + 1, updated_by = public.saya(), updated_at = now() where id = p_line;
end $$;

/** Terbitkan revisi slip. Hanya Bendahara (penanda tangan slip). */
create or replace function public.terbitkan_revisi_slip(p_line uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
declare l payroll_lines; pr payroll_periods;
begin
  select * into l from payroll_lines where id = p_line;
  if not coalesce(l.dalam_revisi, false) then raise exception 'Slip ini tidak sedang direvisi.'; end if;
  if public.saya() not in (select public._pejabat_gaji('bendahara')) then raise exception 'Revisi slip diterbitkan oleh Bendahara.' using errcode = '42501'; end if;
  select * into pr from payroll_periods where id = l.period_id;
  update payroll_signatures set employee_id = public.saya(), nama = (select nama_lengkap from employees where id = public.saya()),
    niy = (select niy from employees where id = public.saya()), waktu = now(), status = 'ditandatangani' where period_id = pr.id and peran = 'bendahara';
  perform public._terbitkan_slip(p_line, public.saya());
  if public._slip_terbuka((select x from payroll_lines x where x.id = p_line)) then
    perform public.kirim_notifikasi(l.employee_id, 'Slip gaji ' || public.nama_bulan_periode(pr.tahun, pr.bulan) || ' direvisi',
      coalesce(l.alasan_revisi, 'Slip gaji Anda diperbarui.'), '/gaji/slip?slip=' || p_line, 'Receipt', 'biru');
  end if;
end $$;

/** Batalkan revisi yang belum diterbitkan: nominal dikembalikan ke slip terbit terakhir (salinan beku registri). */
create or replace function public.batalkan_revisi_slip(p_line uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
declare l payroll_lines; d document_registry; i jsonb; v_urut int := 0;
begin
  perform public._wajib_kelola_gaji();
  select * into l from payroll_lines where id = p_line;
  if not coalesce(l.dalam_revisi, false) then raise exception 'Slip ini tidak sedang direvisi.'; end if;
  select * into d from document_registry where id = l.document_id;
  delete from payroll_items where line_id = p_line;
  for i in select x from jsonb_array_elements(coalesce(d.isi->'item', '[]')) x loop
    v_urut := v_urut + 1;
    insert into payroll_items (line_id, jenis, kategori, label, besaran, sumber, alasan, urutan)
    values (p_line, i->>'jenis', case when i->>'jenis' = 'potongan' then 'potongan_lain' else 'tambahan' end, i->>'label', (i->>'besaran')::numeric, 'manual', 'Dipulihkan dari slip terbit', v_urut);
  end loop;
  perform public._jumlahkan_baris(p_line);
  update payroll_lines set dalam_revisi = false, revisi_ke = revisi_ke - 1, alasan_revisi = null,
    riwayat = case when jsonb_array_length(riwayat) > 0 then riwayat - (jsonb_array_length(riwayat) - 1) else riwayat end where id = p_line;
end $$;

-- ---------------------------------------------------------------------
-- 5. SLIP DI AKUN PEGAWAI DAN PERMINTAAN SLIP
-- ---------------------------------------------------------------------
create or replace function public._slip_json(p_line uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('id', l.id, 'employee_id', l.employee_id, 'data', l.data, 'nomor_slip', l.nomor_slip, 'kode_validasi', l.kode_validasi,
    'revisi_ke', l.revisi_ke, 'diterbitkan_pada', l.diterbitkan_pada, 'total_pendapatan', l.total_pendapatan, 'total_potongan', l.total_potongan,
    'total_skema', l.total_skema, 'total_penyesuaian', l.total_penyesuaian, 'diterima', l.diterima, 'dalam_revisi', l.dalam_revisi,
    'status_dokumen', (select status from document_registry where id = l.document_id),
    'periode', jsonb_build_object('id', p.id, 'tahun', p.tahun, 'bulan', p.bulan, 'tanggal_bayar', p.tanggal_bayar, 'tanggal_akhir', p.tanggal_akhir, 'status', p.status),
    'ttd', public._ttd_periode(p.id),
    'item', coalesce((select jsonb_agg(jsonb_build_object('jenis', i.jenis, 'kategori', i.kategori, 'label', i.label, 'jumlah', i.jumlah, 'tarif', i.tarif,
              'besaran', i.besaran, 'alasan', case when i.kategori = 'penyesuaian' then i.alasan end, 'rincian', i.rincian) order by i.jenis desc, i.urutan, i.label)
              from payroll_items i where i.line_id = l.id), '[]'::jsonb))
  from payroll_lines l join payroll_periods p on p.id = l.period_id where l.id = p_line
$$;

/** Slip gaji milik akun yang sedang masuk (yang terbuka untuknya), beserta pinjaman dan simpanannya. */
create or replace function public.slip_saya()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_emp uuid := public.saya(); v_slip jsonb; v_buka boolean;
begin
  if v_emp is null then return '{}'::jsonb; end if;
  select coalesce(jsonb_agg(public._slip_json(l.id) order by p.tahun desc, p.bulan desc), '[]'::jsonb) into v_slip
    from payroll_lines l join payroll_periods p on p.id = l.period_id
   where l.employee_id = v_emp and p.status = 'terbit' and l.document_id is not null and public._slip_terbuka(l);
  v_buka := coalesce((public._pengaturan_gaji()->>'slip_pegawai')::boolean, false) or jsonb_array_length(v_slip) > 0;
  return jsonb_build_object('slip', v_slip, 'terbuka', v_buka, 'pengaturan', jsonb_build_object('ttd_direktur', public._pengaturan_gaji()->'ttd_direktur',
      'catatan_slip', public._pengaturan_gaji()->'catatan_slip', 'label_penyesuaian', public._pengaturan_gaji()->'label_penyesuaian'),
    'pinjaman', case when v_buka then coalesce((select jsonb_agg(jsonb_build_object('keterangan', x.keterangan, 'pokok', x.pokok, 'cicilan', x.cicilan,
        'status', x.status, 'dibayar', b.n, 'sisa', x.pokok - b.n) order by x.tanggal desc)
        from employee_loans x cross join lateral (select coalesce(sum(besaran), 0) n from loan_payments where loan_id = x.id) b
        where x.employee_id = v_emp and x.status <> 'batal'), '[]'::jsonb) else '[]'::jsonb end,
    'simpanan', case when v_buka then coalesce((select jsonb_agg(jsonb_build_object('program', sp.nama, 'setoran', m.setoran, 'aktif', m.aktif,
        'saldo', public._saldo_simpanan(sp.id, v_emp)) order by sp.urutan)
        from savings_members m join savings_programs sp on sp.id = m.program_id where m.employee_id = v_emp), '[]'::jsonb) else '[]'::jsonb end,
    'permintaan', coalesce((select jsonb_agg(jsonb_build_object('id', r.id, 'status', r.status, 'catatan', r.catatan, 'tanggapan', r.tanggapan,
        'periode', (select public.nama_bulan_periode(p.tahun, p.bulan) from payroll_periods p where p.id = r.period_id), 'created_at', r.created_at) order by r.created_at desc)
        from (select * from payroll_slip_requests where employee_id = v_emp order by created_at desc limit 10) r), '[]'::jsonb));
end $$;

/** Satu slip: pemiliknya (bila terbuka untuknya) atau pembaca gaji. */
create or replace function public.slip_gaji(p_line uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare l payroll_lines;
begin
  select * into l from payroll_lines where id = p_line;
  if l.id is null then raise exception 'Slip tidak ditemukan.'; end if;
  if not (public.boleh_lihat_gaji() or (l.employee_id = public.saya() and l.document_id is not null and public._slip_terbuka(l))) then
    raise exception 'Slip ini tidak dapat dibuka dari akun Anda. Silakan meminta kepada Bendahara.' using errcode = '42501'; end if;
  return public._slip_json(p_line);
end $$;

create or replace function public.minta_slip_gaji(p_period uuid, p_catatan text)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v uuid; v_emp uuid; v_nama text := (select nama_lengkap from employees where id = public.saya());
begin
  if public.saya() is null then raise exception 'Akun Anda belum aktif.'; end if;
  if exists (select 1 from payroll_slip_requests where employee_id = public.saya() and status = 'menunggu' and period_id is not distinct from p_period) then
    raise exception 'Permintaan Anda untuk periode ini masih menunggu tanggapan Bendahara.'; end if;
  insert into payroll_slip_requests (employee_id, period_id, catatan) values (public.saya(), p_period, nullif(trim(p_catatan), '')) returning id into v;
  for v_emp in select public._pejabat_gaji('bendahara') union select id from employees where peran = 'superadmin' and status_akun = 'aktif'
               union select ap.employee_id from admin_permissions ap where ap.kode = 'kelola_gaji' loop
    perform public.kirim_notifikasi(v_emp, 'Permintaan slip gaji', v_nama || coalesce(' – ' || (select public.nama_bulan_periode(tahun, bulan) from payroll_periods where id = p_period), '')
      || coalesce(': ' || nullif(trim(p_catatan), ''), ''), '/gaji/permintaan', 'Receipt', 'oranye');
  end loop;
  return v;
end $$;

/** Tanggapi permintaan: 'buka' (slip dibukakan di akun pegawai), 'cetak' (diberikan tercetak), 'tolak' (beralasan). */
create or replace function public.tanggapi_permintaan_slip(p_id uuid, p_aksi text, p_catatan text default null)
returns void language plpgsql volatile security definer set search_path = public as $$
declare r payroll_slip_requests; v_n int;
begin
  perform public._wajib_kelola_gaji();
  select * into r from payroll_slip_requests where id = p_id and status = 'menunggu';
  if not found then raise exception 'Permintaan tidak ditemukan atau sudah ditanggapi.'; end if;
  if p_aksi not in ('buka','cetak','tolak') then raise exception 'Tanggapan tidak dikenal.'; end if;
  if p_aksi = 'tolak' and length(trim(coalesce(p_catatan, ''))) < 3 then raise exception 'Alasan penolakan wajib diisi.'; end if;
  if p_aksi = 'buka' then
    update payroll_lines l set dibuka_pegawai = true from payroll_periods p
     where p.id = l.period_id and l.employee_id = r.employee_id and p.status = 'terbit' and l.document_id is not null
       and (r.period_id is null or l.period_id = r.period_id);
    get diagnostics v_n = row_count;
    if v_n = 0 then raise exception 'Belum ada slip terbit untuk pegawai ini%.', case when r.period_id is not null then ' pada periode tersebut' else '' end; end if;
  end if;
  update payroll_slip_requests set status = case p_aksi when 'buka' then 'dibuka' when 'cetak' then 'dicetak' else 'ditolak' end,
    ditanggapi_oleh = public.saya(), tanggapan = nullif(trim(p_catatan), ''), updated_at = now() where id = p_id;
  perform public.kirim_notifikasi(r.employee_id,
    case p_aksi when 'buka' then 'Slip gaji dapat dibuka' when 'cetak' then 'Slip gaji disiapkan Bendahara' else 'Permintaan slip gaji ditolak' end,
    coalesce(nullif(trim(p_catatan), ''), case p_aksi when 'buka' then 'Buka menu Gaji untuk melihat slip Anda.' when 'cetak' then 'Slip tercetak dapat diambil di Bendahara.' end),
    case p_aksi when 'buka' then '/gaji/slip' else '/profil' end, 'Receipt', case p_aksi when 'tolak' then 'merah' else 'hijau' end);
end $$;

/** Tutup kembali akses slip yang pernah dibukakan untuk seorang pegawai. */
create or replace function public.tutup_slip_pegawai(p_line uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  perform public._wajib_kelola_gaji();
  update payroll_lines set dibuka_pegawai = false where id = p_line;
end $$;

create or replace function public.daftar_permintaan_slip()
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if not public.boleh_lihat_gaji() then raise exception 'Anda tidak berwenang melihat data gaji.' using errcode = '42501'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', r.id, 'employee_id', r.employee_id, 'niy', e.niy, 'nama', e.nama_lengkap, 'period_id', r.period_id,
      'periode', (select public.nama_bulan_periode(p.tahun, p.bulan) from payroll_periods p where p.id = r.period_id), 'catatan', r.catatan, 'status', r.status,
      'tanggapan', r.tanggapan, 'ditanggapi_oleh', (select nama_lengkap from employees where id = r.ditanggapi_oleh), 'created_at', r.created_at)
      order by (r.status = 'menunggu') desc, r.created_at desc)
    from (select * from payroll_slip_requests order by created_at desc limit 300) r join employees e on e.id = r.employee_id), '[]'::jsonb);
end $$;

/** Periode terbit milik saya (untuk memilih periode saat meminta slip). Hanya bulan dan tahun. */
create or replace function public.periode_gaji_saya()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', p.id, 'nama', public.nama_bulan_periode(p.tahun, p.bulan)) order by p.tahun desc, p.bulan desc), '[]'::jsonb)
    from payroll_lines l join payroll_periods p on p.id = l.period_id where l.employee_id = public.saya() and p.status = 'terbit'
$$;

/** Ringkasan untuk penanda tangan yang bukan pembaca gaji (mis. Direktur): jumlah dan total per bidang, tanpa rincian per orang. */
create or replace function public.ringkasan_ttd_gaji(p_period uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare pr payroll_periods;
begin
  select * into pr from payroll_periods where id = p_period;
  if not (public.boleh_lihat_gaji() or exists (select 1 from payroll_signatures s where s.period_id = p_period
          and (s.employee_id = public.saya() or (s.status = 'menunggu' and public.saya() in (select public._pejabat_gaji(s.peran)))))) then
    raise exception 'Anda tidak berwenang melihat ringkasan gaji ini.' using errcode = '42501'; end if;
  return jsonb_build_object('periode', jsonb_build_object('id', pr.id, 'tahun', pr.tahun, 'bulan', pr.bulan, 'status', pr.status, 'tanggal_bayar', pr.tanggal_bayar,
      'diajukan_pada', pr.diajukan_pada, 'diajukan_oleh', (select nama_lengkap from employees where id = pr.diajukan_oleh)),
    'ttd', public._ttd_periode(p_period),
    'jumlah', (select jsonb_build_object('pegawai', count(*), 'skema', sum(total_skema), 'penyesuaian', sum(total_penyesuaian), 'pendapatan', sum(total_pendapatan),
               'potongan', sum(total_potongan), 'diterima', sum(diterima)) from payroll_lines where period_id = p_period),
    'per_unit', (select coalesce(jsonb_agg(jsonb_build_object('unit', u, 'pegawai', n, 'diterima', t) order by u), '[]'::jsonb) from
                 (select coalesce(data->>'unit', 'Tanpa unit') u, count(*) n, sum(diterima) t from payroll_lines where period_id = p_period group by 1) z));
end $$;

/** Periode yang menunggu (atau pernah memuat) tanda tangan akun ini, dengan ringkasan. */
create or replace function public.ttd_gaji_saya()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(public.ringkasan_ttd_gaji(p.id) order by p.tahun desc, p.bulan desc), '[]'::jsonb)
    from payroll_periods p
   where exists (select 1 from payroll_signatures s where s.period_id = p.id
                 and (s.employee_id = public.saya() or (s.status = 'menunggu' and p.status = 'diajukan' and public.saya() in (select public._pejabat_gaji(s.peran)))))
$$;

-- ---------------------------------------------------------------------
-- 6. HAK GAJI (diperbarui): slip terbuka, tanda tangan menunggu, permintaan
-- ---------------------------------------------------------------------
create or replace function public.hak_gaji()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_slip boolean; v_ttd int; v_minta int;
begin
  v_slip := public.saya() is not null and (coalesce((public._pengaturan_gaji()->>'slip_pegawai')::boolean, false)
            or exists (select 1 from payroll_lines where employee_id = public.saya() and dibuka_pegawai and document_id is not null));
  select count(*) into v_ttd from payroll_signatures s join payroll_periods p on p.id = s.period_id
   where p.status = 'diajukan' and s.status = 'menunggu' and public.saya() in (select public._pejabat_gaji(s.peran));
  v_minta := case when public.boleh_kelola_gaji() then (select count(*) from payroll_slip_requests where status = 'menunggu') else 0 end;
  return jsonb_build_object('kelola', public.boleh_kelola_gaji(), 'lihat', public.boleh_lihat_gaji(), 'superadmin', public.is_superadmin(),
    'bendahara', public.is_bendahara(), 'slip_saya', v_slip, 'ttd_menunggu', v_ttd, 'permintaan_menunggu', v_minta,
    'tampil', public.boleh_lihat_gaji() or v_slip or v_ttd > 0, 'pengaturan', public.pengaturan_gaji());
end $$;

-- ---------------------------------------------------------------------
-- 7. REGISTRI: slip hanya terlihat pembaca gaji dan pemiliknya
-- ---------------------------------------------------------------------
create or replace function public.boleh_lihat_dokumen(p_doc uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select case when (select jenis from document_registry where id = p_doc) = 'slip_gaji'
    then public.boleh_lihat_gaji()
         or exists (select 1 from document_registry d join payroll_lines l on l.id = d.ref_id
                  where d.id = p_doc and d.ref_tabel = 'payroll_lines' and l.employee_id = public.saya() and public._slip_terbuka(l))
    else public.is_admin()
      or exists (select 1 from document_registry d where d.id = p_doc and d.diterbitkan_oleh = public.saya())
      or exists (select 1 from document_signatures s where s.document_id = p_doc and s.employee_id = public.saya()) end
$$;

-- ---------------------------------------------------------------------
-- 8. FUNGSI BERBASIS BARIS (boleh untuk slip yang sedang direvisi), RINCIAN PERIODE, BUKU AGENDA (tanpa slip)
-- ---------------------------------------------------------------------
create or replace function public.hitung_ulang_baris_gaji(p_line uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  perform public._wajib_kelola_gaji();
  perform public._wajib_baris_ubah(p_line);
  perform public._hitung_baris(p_line);
end $$;

create or replace function public.ubah_item_gaji(p_item uuid, p_besaran numeric, p_jumlah numeric, p_alasan text)
returns void language plpgsql volatile security definer set search_path = public as $$
declare i payroll_items; v_line payroll_lines;
begin
  perform public._wajib_kelola_gaji();
  select * into i from payroll_items where id = p_item;
  if not found then raise exception 'Komponen gaji tidak ditemukan.'; end if;
  select * into v_line from payroll_lines where id = i.line_id;
  perform public._wajib_baris_ubah(v_line.id);
  if i.kategori = 'penyesuaian' then raise exception 'Penyesuaian dihitung otomatis. Ubah lewat "Atur jumlah diterima" atau penetapan yayasan.'; end if;
  if length(trim(coalesce(p_alasan, ''))) < 3 then raise exception 'Alasan perubahan wajib diisi.'; end if;
  if p_besaran is not null and p_besaran < 0 then raise exception 'Nominal tidak boleh negatif.'; end if;
  if i.kategori = 'honor' and p_jumlah is not null then
    if p_jumlah < 0 then raise exception 'Jumlah jam tidak boleh negatif.'; end if;
    update payroll_items set jumlah = p_jumlah, besaran = coalesce(p_besaran, round(p_jumlah * tarif)) where id = p_item;
  else
    if p_besaran is null then raise exception 'Isi nominal.'; end if;
    update payroll_items set besaran = p_besaran where id = p_item;
  end if;
  update payroll_items set sumber = case when sumber in ('skema','manual') and besaran_skema is not null then 'manual' else sumber end,
    alasan = trim(p_alasan), diubah_oleh = public.saya(), diubah_pada = now() where id = p_item;
  perform public._hitung_baris(i.line_id);   -- penyesuaian dari target/penetapan ikut menyesuaikan
end $$;

create or replace function public.kembalikan_item_gaji(p_item uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
declare i payroll_items;
begin
  perform public._wajib_kelola_gaji();
  select * into i from payroll_items where id = p_item;
  if not found then raise exception 'Komponen gaji tidak ditemukan.'; end if;
  perform public._wajib_baris_ubah(i.line_id);
  if i.besaran_skema is null then raise exception 'Komponen tambahan tidak memiliki nilai skema; hapus bila tidak dipakai.'; end if;
  update payroll_items set sumber = 'skema', besaran = besaran_skema, jumlah = coalesce((rincian->>'jam_otomatis')::numeric, jumlah),
    alasan = null, diubah_oleh = null, diubah_pada = null where id = p_item;
  perform public._hitung_baris(i.line_id);
end $$;

create or replace function public.tambah_item_gaji(p_line uuid, p jsonb)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v uuid; v_jenis text := coalesce(p->>'jenis', 'pendapatan'); v_besar numeric := round(coalesce((p->>'besaran')::numeric, 0));
begin
  perform public._wajib_kelola_gaji();
  perform public._wajib_baris_ubah(p_line);
  if v_jenis not in ('pendapatan','potongan') then raise exception 'Jenis hanya pendapatan atau potongan.'; end if;
  if length(trim(coalesce(p->>'label', ''))) < 3 then raise exception 'Isi nama komponen.'; end if;
  if v_besar <= 0 then raise exception 'Nominal harus lebih dari nol.'; end if;
  insert into payroll_items (line_id, jenis, kategori, label, besaran, sumber, alasan, urutan, diubah_oleh, diubah_pada)
  values (p_line, v_jenis, case v_jenis when 'pendapatan' then 'tambahan' else 'potongan_lain' end, trim(p->>'label'), v_besar, 'manual',
          nullif(trim(p->>'alasan'), ''), case v_jenis when 'pendapatan' then 96 else 199 end, public.saya(), now())
  returning id into v;
  perform public._hitung_baris(p_line);
  return v;
end $$;

create or replace function public.hapus_item_gaji(p_item uuid)
returns void language plpgsql volatile security definer set search_path = public as $$
declare i payroll_items;
begin
  perform public._wajib_kelola_gaji();
  select * into i from payroll_items where id = p_item;
  if not found then raise exception 'Komponen gaji tidak ditemukan.'; end if;
  perform public._wajib_baris_ubah(i.line_id);
  if i.kategori not in ('tambahan','potongan_lain') then raise exception 'Komponen skema tidak dihapus; ubah nominalnya menjadi Rp0 bila tidak diberikan.'; end if;
  delete from payroll_items where id = p_item;
  perform public._hitung_baris(i.line_id);
end $$;

create or replace function public.atur_diterima_gaji(p_line uuid, p_diterima numeric, p_alasan text)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  perform public._wajib_kelola_gaji();
  perform public._wajib_baris_ubah(p_line);
  if p_diterima is not null and p_diterima < 0 then raise exception 'Jumlah diterima tidak boleh negatif.'; end if;
  if p_diterima is not null and length(trim(coalesce(p_alasan, ''))) < 3 then raise exception 'Isi keterangan, mis. "Ketetapan Ketua Yayasan".'; end if;
  update payroll_lines set target_diterima = round(p_diterima), alasan_target = case when p_diterima is null then null else trim(p_alasan) end,
    updated_by = public.saya(), updated_at = now() where id = p_line;
  perform public._hitung_baris(p_line);
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
          'item', coalesce((select jsonb_agg(jsonb_build_object('id', i.id, 'jenis', i.jenis, 'kategori', i.kategori, 'kode', i.kode, 'label', i.label,
              'jumlah', i.jumlah, 'tarif', i.tarif, 'besaran_skema', i.besaran_skema, 'besaran', i.besaran, 'sumber', i.sumber, 'alasan', i.alasan,
              'rincian', i.rincian, 'diubah_oleh', (select nama_lengkap from employees where id = i.diubah_oleh), 'diubah_pada', i.diubah_pada)
              order by i.jenis desc, i.urutan, i.label) from payroll_items i where i.line_id = l.id), '[]'::jsonb))
        order by l.data->>'nama')
      from payroll_lines l where l.period_id = p.id), '[]'::jsonb))
    from payroll_periods p where p.id = p_period);
end $$;
create or replace function public.buku_agenda_keluar(p_mulai date, p_selesai date)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if not (public.boleh_kelola_persuratan() or public.saya() in (select public._puncak_surat())) then
    raise exception 'Buku agenda hanya dapat dibuka Tata Usaha dan pimpinan.' using errcode = '42501'; end if;
  if p_selesai < p_mulai then raise exception 'Rentang tanggal tidak sah.'; end if;
  if p_selesai - p_mulai > 400 then raise exception 'Rentang buku agenda paling lama satu tahun.'; end if;
  return coalesce((select jsonb_agg(x order by x->>'tanggal_surat', x->>'urut') from (
    -- a. Surat Tata Usaha (Persuratan)
    select jsonb_build_object('sumber', 'tu', 'sumber_nama', 'Persuratan', 'id', o.id, 'document_id', o.document_id, 'nomor', o.nomor,
      'tanggal_surat', o.tanggal_surat, 'jenis_nama', o.jenis_nama, 'perihal', o.perihal, 'kepada', o.kepada,
      'penanda', (select string_agg(p->>'nama', '; ') from jsonb_array_elements(o.penanda) p), 'mode_ttd', o.mode_ttd,
      'status', o.status, 'kode_validasi', d.kode, 'disusun_oleh', de.nama_lengkap, 'pemohon', (select nama_lengkap from employees where id = o.pemohon_id),
      'revisi_ke', o.revisi_ke, 'tautan', '/persuratan/keluar?surat=' || o.id, 'urut', coalesce(o.terbit_pada, o.created_at)::text) as x
      from outgoing_letters o left join document_registry d on d.id = o.document_id left join employees de on de.id = o.disusun_oleh
     where o.status in ('terbit','dicabut','direvisi') and o.tanggal_surat between p_mulai and p_selesai
    union all
    -- b. Dokumen bertanda tangan dari modul lain (registri dokumen)
    select jsonb_build_object('sumber', case when d.jenis = 'pengajuan_pegawai' then 'pengajuan' when d.jenis = 'surat_sakit' then 'klinik' else 'laporan' end,
      'sumber_nama', case when d.jenis = 'pengajuan_pegawai' then 'Pengajuan pegawai' when d.jenis = 'surat_sakit' then 'Klinik' else 'Dokumen resmi' end,
      'id', d.id, 'document_id', d.id, 'nomor', d.nomor, 'tanggal_surat', (d.diterbitkan_pada at time zone 'Asia/Makassar')::date,
      'jenis_nama', d.jenis_nama, 'perihal', coalesce(d.perihal, d.jenis_nama) || coalesce(' (' || d.periode || ')', ''), 'kepada', d.subjek,
      'penanda', (select string_agg(s.nama, '; ' order by s.urutan) from document_signatures s where s.document_id = d.id and s.jabatan is distinct from 'Pemohon'),
      'mode_ttd', coalesce(d.mode_ttd, 'elektronik'),
      'status', case d.status when 'sah' then 'terbit' else d.status end, 'kode_validasi', d.kode,
      'disusun_oleh', (select nama_lengkap from employees where id = d.diterbitkan_oleh), 'pemohon', null, 'revisi_ke', 0,
      'tautan', case when d.jenis = 'pengajuan_pegawai' then '/pengajuan/' || d.ref_id
                     when d.jenis = 'surat_sakit' then '/klinik/riwayat'
                     when d.tautan is not null then d.tautan || '?resmi=' || d.id
                     else '/rekap/dokumen' end,
      'urut', d.diterbitkan_pada::text)
      from document_registry d
     where d.jenis not in ('surat_keluar','slip_gaji') and d.status in ('sah','direvisi','dicabut')
       and (d.diterbitkan_pada at time zone 'Asia/Makassar')::date between p_mulai and p_selesai
    union all
    -- c. Surat keterangan pindah santri (mutasi keluar)
    select jsonb_build_object('sumber', 'santri', 'sumber_nama', 'Data santri', 'id', m.id, 'document_id', null, 'nomor', m.nomor_surat,
      'tanggal_surat', m.tanggal, 'jenis_nama', 'Surat Keterangan Pindah', 'perihal', 'Pindah ke ' || coalesce(m.sekolah, '–'),
      'kepada', s.nama_lengkap || coalesce(' (NIS ' || s.nis || ')', ''), 'penanda', null, 'mode_ttd', 'basah', 'status', 'terbit', 'kode_validasi', null,
      'disusun_oleh', (select nama_lengkap from employees where id = m.oleh), 'pemohon', null, 'revisi_ke', 0,
      'tautan', '/santri/' || m.student_id, 'urut', m.created_at::text)
      from student_mutations m join students s on s.id = m.student_id
     where m.jenis = 'keluar' and m.nomor_surat is not null and m.tanggal between p_mulai and p_selesai
  ) q), '[]'::jsonb);
end $$;

-- ---------------------------------------------------------------------
-- 9. HAK EKSEKUSI
-- ---------------------------------------------------------------------
do $$
declare f text;
begin
  foreach f in array array['ajukan_periode_gaji(uuid)','tandatangani_periode_gaji(uuid,boolean,text)','tarik_pengajuan_gaji(uuid)',
    'mulai_revisi_slip(uuid,text)','terbitkan_revisi_slip(uuid)','batalkan_revisi_slip(uuid)','slip_saya()','slip_gaji(uuid)',
    'minta_slip_gaji(uuid,text)','tanggapi_permintaan_slip(uuid,text,text)','tutup_slip_pegawai(uuid)','daftar_permintaan_slip()','periode_gaji_saya()',
    'ringkasan_ttd_gaji(uuid)','ttd_gaji_saya()','hak_gaji()','hitung_ulang_baris_gaji(uuid)','ubah_item_gaji(uuid,numeric,numeric,text)','kembalikan_item_gaji(uuid)',
    'tambah_item_gaji(uuid,jsonb)','hapus_item_gaji(uuid)','atur_diterima_gaji(uuid,numeric,text)','rincian_periode_gaji(uuid)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  foreach f in array array['_pejabat_gaji(text)','_ttd_periode(uuid)','_wajib_baris_ubah(uuid)','_terbitkan_slip(uuid,uuid)','_slip_terbuka(payroll_lines)',
    '_terbitkan_periode(uuid)','_cek_ttd_periode(uuid)','_isi_ttd(uuid,text,uuid)','_slip_json(uuid)'] loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN (hasil yang benar: baris 1–6 "Sesuai"; baris 7–8 keterangan data)
-- ---------------------------------------------------------------------
select '1. Kolom slip dan tabel tanda tangan/permintaan' as pemeriksaan,
       case when to_regclass('public.payroll_signatures') is not null and to_regclass('public.payroll_slip_requests') is not null
             and exists (select 1 from information_schema.columns where table_name = 'payroll_lines' and column_name = 'kode_validasi') then 'Sesuai' else 'Periksa' end as hasil
union all select '2. Tabel tertutup untuk tulis langsung', case when (select count(*) from pg_policies where tablename in ('payroll_signatures','payroll_slip_requests') and cmd <> 'SELECT') = 0
  then 'Sesuai' else 'Periksa' end
union all select '3. Fungsi penerbitan (ajukan, tanda tangan, tarik)', case when (select count(*) from pg_proc where proname in ('ajukan_periode_gaji','tandatangani_periode_gaji','tarik_pengajuan_gaji')) = 3 then 'Sesuai' else 'Periksa' end
union all select '4. Fungsi revisi dan slip saya', case when (select count(*) from pg_proc where proname in ('mulai_revisi_slip','terbitkan_revisi_slip','batalkan_revisi_slip','slip_saya','slip_gaji','minta_slip_gaji','tanggapi_permintaan_slip')) = 7 then 'Sesuai' else 'Periksa' end
union all select '5. Slip tidak masuk buku agenda surat keluar', case when pg_get_functiondef('public.buku_agenda_keluar(date,date)'::regprocedure) like '%slip_gaji%' then 'Sesuai' else 'Periksa' end
union all select '6. Registri slip hanya untuk pembaca gaji dan pemilik', case when pg_get_functiondef('public.boleh_lihat_dokumen(uuid)'::regprocedure) like '%slip_gaji%' then 'Sesuai' else 'Periksa' end
union all select '7. Bendahara penanda tangan slip', (select count(*) || ' pegawai berakun aktif' from public._pejabat_gaji('bendahara'))
union all select '8. Direktur (bila TTD Direktur diaktifkan)', (select count(*) || ' pegawai berakun aktif' from public._pejabat_gaji('direktur'));
