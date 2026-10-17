-- SIMKA PRO | supabase/migrations/20261014009200_perbaikan_tahap_a.sql | v1.0 | Perbaikan Tahap A: presensi harian satu tanggal, hapus surat salah catat | 14/10/2026
-- A. presensi_harian (dipakai Data Presensi → Harian, Presensi saya, rincian verval):
--    sebelumnya presensi KEMARIN ikut tampil pada tanggal hari ini bila sesinya sama (mis. Halaqah subuh setiap hari),
--    karena penyaring "sesi lintas tengah malam" mencocokkan session_id semua jadwal hari ini. Kini presensi kemarin hanya
--    ikut bila sesinya memang sesi kemarin yang melewati tengah malam dan belum ditutup.
-- B. Hapus surat salah catat (Tata Usaha/pengelola persuratan dan superadmin), alasan wajib, tercatat di Audit Log:
--    * hapus_surat_masuk(id, alasan, rapikan): nomor agenda surat sesudahnya pada periode yang sama digeser naik
--      (rapikan = true, bawaan) sehingga buku agenda kembali berurutan; penghitung nomor ikut turun.
--    * hapus_surat_keluar(id, alasan, rapikan): draf/ditolak/dibatalkan dihapus langsung. Surat bernomor:
--      nomor terakhir → penghitung turun (nomor dipakai lagi); bukan terakhir → bila rapikan, nomor surat keluar
--      sesudahnya ikut bergeser (registri dokumen ikut diperbarui; surat yang sudah dikirim perlu dicetak ulang).
-- Aman dijalankan ulang.

-- =====================================================================
-- A. PRESENSI HARIAN SATU TANGGAL
-- =====================================================================
create or replace function public.presensi_harian(p_emp uuid default null, p_tanggal date default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_saya uuid := public.saya();
  v_emp uuid := coalesce(p_emp, v_saya);
  v_now timestamptz := now();
  v_hari date := coalesce(p_tanggal, (now() at time zone 'Asia/Makassar')::date);
  v_sesi jsonb;
begin
  if v_emp is null then
    raise exception 'Akun Anda belum aktif.' using hint = 'AKUN_TIDAK_AKTIF';
  end if;
  if v_emp is distinct from v_saya and not (public.is_admin() or public.pimpinan_dari(v_emp)) then
    raise exception 'Anda tidak berhak melihat presensi pegawai ini.' using hint = 'TANPA_IZIN';
  end if;

  with j as (
    select j.* from public.jadwal_pegawai(v_emp, v_hari) j
    union all
    select k.* from public.jadwal_pegawai(v_emp, v_hari - 1) k
     where v_hari = (v_now at time zone 'Asia/Makassar')::date and k.selesai > (v_hari::timestamp at time zone 'Asia/Makassar')
       and k.ditutup_pada > v_now
  ), gabung as (
    select coalesce(j.tanggal, a.tanggal) as tanggal,
           coalesce(j.session_id, a.session_id) as session_id,
           coalesce(j.nama_pola, a.nama_pola) as nama_pola,
           coalesce(j.nama_sesi, a.nama_sesi) as nama_sesi,
           j.jenis_pola, j.warna, j.label_datang, j.label_pulang,
           coalesce(j.mulai, a.jadwal_mulai) as mulai, coalesce(j.selesai, a.jadwal_selesai) as selesai,
           j.buka, j.batas_tepat, j.tutup, j.pulang_buka, j.batas_pulang,
           coalesce(j.wajib_pulang, a.wajib_pulang) as wajib_pulang,
           coalesce(j.opsional, a.opsional) as opsional,
           a.id as attendance_id, a.status, a.usulan_status, a.datang_pada, a.terlambat_menit,
           a.status_pulang, a.pulang_pada, a.cepat_pulang_menit, a.sumber, a.keterangan,
           case
             when a.id is not null and a.wajib_pulang and a.status_pulang = 'belum'
                  and v_now <= coalesce(j.batas_pulang, a.jadwal_selesai) then 'menunggu_pulang'
             when a.id is not null then 'selesai'
             when j.buka is not null and v_now < j.buka then 'akan_datang'
             when j.buka is not null and v_now <= j.tutup then 'terbuka'
             else 'terlewat'
           end as keadaan
      from j
      full join (select * from attendances
                  where employee_id = v_emp
                    and (tanggal = v_hari or (tanggal = v_hari - 1 and session_id in (select j2.session_id from j j2 where j2.tanggal = v_hari - 1)))) a
        on a.session_id = j.session_id and a.tanggal = j.tanggal
  )
  select coalesce(jsonb_agg(to_jsonb(g) order by g.mulai), '[]'::jsonb) into v_sesi from gabung g;

  return jsonb_build_object(
    'employee_id', v_emp,
    'tanggal', v_hari,
    'waktu', v_now,
    'jam', to_char(v_now at time zone 'Asia/Makassar', 'HH24:MI:SS'),
    'sesi', v_sesi);
end $$;

revoke execute on function public.presensi_harian(uuid, date) from public, anon;
grant execute on function public.presensi_harian(uuid, date) to authenticated;

-- =====================================================================
-- B. HAPUS SURAT SALAH CATAT DAN RAPIKAN NOMOR
-- =====================================================================
/** Bentuk teks nomor dari pola format (sama dengan ambil_nomor) untuk urut tertentu. */
create or replace function public._bentuk_nomor(p_format text, p_urut int, p_tanggal date, p_dk text, p_perihal text, p_kop text)
returns text language plpgsql stable security definer set search_path = public as $$
declare f doc_number_formats; h record; v_unit text; v text; romawi text[] := array['I','II','III','IV','V','VI','VII','VIII','IX','X','XI','XII'];
begin
  select * into f from doc_number_formats where kode = p_format;
  select * into h from public.hijriah(p_tanggal);
  select kode_unit into v_unit from letterheads where kode = coalesce(p_kop, 'pondok');
  v := f.pola;
  v := replace(v, '{DK}', coalesce(p_dk, 'D')); v := replace(v, '{URUT3}', lpad(p_urut::text, 3, '0')); v := replace(v, '{URUT}', p_urut::text);
  v := replace(v, '{PERIHAL}', coalesce(p_perihal, '')); v := replace(v, '{UNIT}', coalesce(v_unit, ''));
  v := replace(v, '{BLN_H_ROMAWI}', h.bulan_romawi); v := replace(v, '{THN_H}', h.tahun::text);
  v := replace(v, '{BLN_ROMAWI}', romawi[extract(month from p_tanggal)::int]); v := replace(v, '{BLN}', to_char(p_tanggal, 'MM')); v := replace(v, '{THN}', to_char(p_tanggal, 'YYYY'));
  return v;
end $$;
revoke execute on function public._bentuk_nomor(text,int,date,text,text,text) from public, anon, authenticated;

create or replace function public.hapus_surat_masuk(p_id uuid, p_alasan text, p_rapikan boolean default true)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare s incoming_letters%rowtype; r record; n int := 0; v_grup text;
begin
  if not (public.boleh_kelola_persuratan() or public.is_superadmin()) then raise exception 'Hanya Tata Usaha/pengelola persuratan yang dapat menghapus surat.' using errcode = '42501'; end if;
  if length(trim(coalesce(p_alasan, ''))) < 5 then raise exception 'Tuliskan alasan penghapusan (minimal 5 huruf).'; end if;
  select * into s from incoming_letters where id = p_id for update;
  if s.id is null then raise exception 'Surat tidak ditemukan.'; end if;
  select grup_urut into v_grup from doc_number_formats where kode = 'agenda_masuk';
  insert into audit_logs (employee_id, aksi, tabel, data_id, ringkasan, data)
  values (public.saya(), 'hapus', 'incoming_letters', p_id::text, 'Hapus surat masuk ' || s.nomor_agenda || ': ' || trim(p_alasan), to_jsonb(s));
  delete from incoming_letters where id = p_id;                 -- disposisi ikut terhapus
  delete from doc_numbers_issued where format_kode = 'agenda_masuk' and nomor = s.nomor_agenda;
  if p_rapikan then
    for r in select * from incoming_letters where periode = s.periode and urut_agenda > s.urut_agenda order by urut_agenda loop
      update incoming_letters set urut_agenda = r.urut_agenda - 1,
             nomor_agenda = public._bentuk_nomor('agenda_masuk', r.urut_agenda - 1, r.tanggal_terima, 'D', null, 'pondok') where id = r.id;
      update doc_numbers_issued set urut = r.urut_agenda - 1, nomor = public._bentuk_nomor('agenda_masuk', r.urut_agenda - 1, r.tanggal_terima, 'D', null, 'pondok')
       where format_kode = 'agenda_masuk' and nomor = r.nomor_agenda;
      n := n + 1;
    end loop;
  end if;
  -- Penghitung = nomor tertinggi yang masih ada (nomor kosong di akhir dipakai lagi)
  update doc_counters set nilai = coalesce((select max(urut_agenda) from incoming_letters where periode = s.periode), 0), updated_at = now()
   where grup_urut = v_grup and periode = s.periode;
  return jsonb_build_object('dihapus', s.nomor_agenda, 'digeser', n);
end $$;

create or replace function public.hapus_surat_keluar(p_id uuid, p_alasan text, p_rapikan boolean default true)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare o outgoing_letters%rowtype; d doc_numbers_issued%rowtype; v_grup text; r record; n int := 0; v_baru text; v_lepas int;
begin
  if not (public.boleh_kelola_persuratan() or public.is_superadmin()) then raise exception 'Hanya Tata Usaha/pengelola persuratan yang dapat menghapus surat.' using errcode = '42501'; end if;
  if length(trim(coalesce(p_alasan, ''))) < 5 then raise exception 'Tuliskan alasan penghapusan (minimal 5 huruf).'; end if;
  select * into o from outgoing_letters where id = p_id for update;
  if o.id is null then raise exception 'Surat tidak ditemukan.'; end if;
  insert into audit_logs (employee_id, aksi, tabel, data_id, ringkasan, data)
  values (public.saya(), 'hapus', 'outgoing_letters', p_id::text, 'Hapus surat keluar ' || coalesce(o.nomor, '(tanpa nomor)') || ': ' || trim(p_alasan), to_jsonb(o));
  update outgoing_letters set revisi_dari = null where revisi_dari = p_id;
  delete from outgoing_letters where id = p_id;
  if o.document_id is not null then delete from document_registry where id = o.document_id; end if;
  if o.nomor is null then return jsonb_build_object('dihapus', 'draf', 'digeser', 0); end if;

  select * into d from doc_numbers_issued where format_kode = o.format_nomor and nomor = o.nomor;
  select grup_urut into v_grup from doc_number_formats where kode = o.format_nomor;
  delete from doc_numbers_issued where id = d.id;
  if d.id is null then return jsonb_build_object('dihapus', o.nomor, 'digeser', 0); end if;

  if p_rapikan then
    -- Nomor sesudahnya yang bukan surat keluar (diambil di luar persuratan) tidak dapat dibentuk ulang: hentikan pergeseran
    if exists (select 1 from doc_numbers_issued x join doc_number_formats f on f.kode = x.format_kode
                where f.grup_urut = v_grup and x.periode = d.periode and x.urut > d.urut
                  and not exists (select 1 from outgoing_letters ol where ol.nomor = x.nomor and ol.format_nomor = x.format_kode)) then
      raise exception 'Nomor sesudahnya dipakai dokumen lain di luar Persuratan, sehingga nomor tidak dapat dirapikan. Hapus tanpa merapikan nomor.';
    end if;
    for r in select x.id xid, x.urut, ol.* from doc_numbers_issued x join doc_number_formats f on f.kode = x.format_kode
              join outgoing_letters ol on ol.nomor = x.nomor and ol.format_nomor = x.format_kode
             where f.grup_urut = v_grup and x.periode = d.periode and x.urut > d.urut order by x.urut loop
      v_baru := public._bentuk_nomor(r.format_nomor, r.urut - 1, r.tanggal_surat, r.dk, r.perihal_kode, r.kop_kode);
      update doc_numbers_issued set urut = r.urut - 1, nomor = v_baru where id = r.xid;
      update outgoing_letters set nomor = v_baru where id = r.id;
      if r.document_id is not null then update document_registry set nomor = v_baru where id = r.document_id; end if;
      n := n + 1;
    end loop;
  end if;
  select coalesce(max(x.urut), 0) into v_lepas from doc_numbers_issued x join doc_number_formats f on f.kode = x.format_kode where f.grup_urut = v_grup and x.periode = d.periode;
  update doc_counters set nilai = v_lepas, updated_at = now() where grup_urut = v_grup and periode = d.periode;
  return jsonb_build_object('dihapus', o.nomor, 'digeser', n);
end $$;

do $$ declare f text; begin
  foreach f in array array['hapus_surat_masuk(uuid,text,boolean)','hapus_surat_keluar(uuid,text,boolean)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- PEMERIKSAAN — hasil yang benar: 2 baris, semuanya "Sesuai"
select '1. Presensi harian hanya tanggal yang dipilih' as pemeriksaan,
       case when position('j2.tanggal = v_hari - 1' in pg_get_functiondef('public.presensi_harian(uuid,date)'::regprocedure)) > 0 then 'Sesuai' else 'Periksa' end as hasil
union all
select '2. Fungsi hapus surat masuk/keluar', case when (select count(*) from pg_proc where proname in ('hapus_surat_masuk','hapus_surat_keluar')) = 2 then 'Sesuai' else 'Periksa' end;
