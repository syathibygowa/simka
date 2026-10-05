-- SIMKA PRO | supabase/migrations/20261006004700_musyrif.sql | v1.0 | Fase 6 – Tahap M1 Menu Musyrif | 06/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 6 · Migrasi 47: Menu Musyrif (kepengasuhan asrama) — dasbor dan rekap komprehensif
--   * absensi_asrama_rinci(kamar, mulai, selesai): seluruh sesi asrama satu kamar pada rentang tanggal beserta
--     status setiap santri per sesi (H/I/S/B/A/T) dan daftar sesi yang seharusnya ada (untuk "belum diisi").
--     Dasar rekap individu, per kamar, per pekan, per bulan, dan rentang bebas di aplikasi (tanpa menyimpan data baru).
--   * kamar_musyrif(): daftar kamar yang terlihat (asuhan sendiri; semua kamar bagi admin/pimpinan/pemantau absensi)
--     beserta musyrif/musyrifah, jumlah santri, dan tautan grup WA.
--   * Template WA baru: rekap_asrama (ke wali per santri), rekap_kamar (salin ke grup WA kamar/wali).
--     Dapat diubah di Pengaturan → Template WA.
-- Jalankan SETELAH migrasi 4600. Aman dijalankan ulang.
-- =====================================================================

/** Boleh memantau satu kamar: musyrif kamar itu, pemantau absensi (admin/pimpinan), atau hak fitur absensi asrama. */
create or replace function public.boleh_lihat_kamar(p_group uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.boleh_pantau_absensi() or public.tingkat_fitur('absensi_asrama') >= 1
      or p_group in (select public.kelompok_saya())
$$;

create or replace function public.kamar_musyrif()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(x order by (x->>'asuhan_saya')::boolean desc, x->>'nama'), '[]'::jsonb) from (
    select jsonb_build_object('id', g.id, 'nama', g.nama, 'jenis_kelamin', g.jenis_kelamin, 'keterangan', g.keterangan,
             'wa_wali', g.wa_wali, 'wa_internal', g.wa_internal,
             'asuhan_saya', g.id in (select public.kelompok_saya()),
             'jumlah', (select count(*) from group_members m join students s on s.id = m.student_id
                         where m.group_id = g.id and m.selesai is null and s.status = 'aktif'),
             'musyrif', coalesce((select jsonb_agg(jsonb_build_object('employee_id', e.id, 'nama', e.nama_lengkap, 'niy', e.niy,
                           'peran', k.peran, 'no_hp', e.no_hp) order by case k.peran when 'utama' then 0 when 'pendamping' then 1 else 2 end, e.nama_lengkap)
                         from group_keepers k join employees e on e.id = k.employee_id
                         where k.group_id = g.id and (k.mulai is null or k.mulai <= public.hari_ini())
                           and (k.sampai is null or k.sampai >= public.hari_ini())), '[]'::jsonb)) x
      from student_groups g join academic_years a on a.id = g.academic_year_id and a.aktif
     where g.jenis = 'kamar' and g.aktif and public.boleh_lihat_kamar(g.id)) q
$$;

/** Rincian absensi asrama satu kamar. Kembalian:
    { kamar, mulai, selesai,
      sesi: [{ id, tanggal, sesi, nama_sesi, jam_mulai, pengisi, terlambat, atas_nama }],
      isi:  [[session_id, student_id, kode, keterangan]]   (kode H bila tidak ada pengecualian),
      rencana: [{ tanggal, sesi, nama_sesi }]                (sesi yang seharusnya ada; yang tak berpasangan = tidak diisi),
      santri: [{ id, nis, nama, jenis_kelamin, status }] }  (anggota pada rentang, hanya yang terlihat) */
create or replace function public.absensi_asrama_rinci(p_group uuid, p_mulai date, p_selesai date)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare g student_groups%rowtype; v_akhir date := least(p_selesai, public.hari_ini());
begin
  select * into g from student_groups where id = p_group;
  if g.id is null or g.jenis <> 'kamar' then raise exception 'Kamar tidak ditemukan.'; end if;
  if p_mulai is null or p_selesai is null or p_selesai < p_mulai then raise exception 'Rentang tanggal tidak sah.'; end if;
  if p_selesai - p_mulai > 400 then raise exception 'Rentang paling panjang 400 hari.'; end if;
  if not public.boleh_lihat_kamar(p_group) then raise exception 'Anda tidak berwenang melihat absensi kamar ini.' using errcode = '42501'; end if;

  return jsonb_build_object(
    'kamar', jsonb_build_object('id', g.id, 'nama', g.nama, 'jenis_kelamin', g.jenis_kelamin),
    'mulai', p_mulai, 'selesai', p_selesai,
    'sesi', coalesce((select jsonb_agg(jsonb_build_object('id', sa.id, 'tanggal', sa.tanggal, 'sesi', sa.sesi, 'nama_sesi', sa.nama_sesi,
              'jam_mulai', sa.jam_mulai, 'pengisi', e.nama_lengkap, 'terlambat', sa.diisi_terlambat, 'atas_nama', sa.atas_nama)
              order by sa.tanggal, sa.jam_mulai)
            from student_attendance_sessions sa left join employees e on e.id = coalesce(sa.diinput_oleh, sa.pengampu_id)
           where sa.group_id = p_group and sa.jenis = 'asrama' and sa.tanggal between p_mulai and p_selesai), '[]'::jsonb),
    'isi', coalesce((select jsonb_agg(jsonb_build_array(sa.id, a.sid, coalesce(x.kode, 'H'), x.keterangan))
            from student_attendance_sessions sa
            cross join lateral (select y as sid from public._anggota_pada(sa.group_id, sa.tanggal) y) a
            left join student_attendance_exceptions x on x.session_id = sa.id and x.student_id = a.sid
           where sa.group_id = p_group and sa.jenis = 'asrama' and sa.tanggal between p_mulai and p_selesai
             and a.sid in (select public.santri_terlihat())), '[]'::jsonb),
    'rencana', coalesce((select jsonb_agg(jsonb_build_object('tanggal', d::date, 'sesi', ss.kode, 'nama_sesi', ss.nama) order by d, ss.urutan)
            from generate_series(p_mulai, v_akhir, interval '1 day') d
            cross join lateral public.sesi_santri_tanggal('asrama', d::date) ss
           where ss.selesai <= now() and v_akhir >= p_mulai), '[]'::jsonb),
    'santri', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'nis', s.nis, 'nama', s.nama_lengkap, 'jenis_kelamin', s.jenis_kelamin,
              'status', s.status, 'aktif_di_kamar', t.aktif) order by s.nama_lengkap)
            from (select m.student_id, bool_or(m.selesai is null) as aktif from group_members m
                   where m.group_id = p_group and m.mulai <= p_selesai and (m.selesai is null or m.selesai >= p_mulai)
                   group by m.student_id) t
            join students s on s.id = t.student_id
           where s.id in (select public.santri_terlihat())), '[]'::jsonb));
end $$;

-- ---------------------------------------------------------------------
-- TEMPLATE WA
-- ---------------------------------------------------------------------
insert into public.wa_templates (kode, nama, isi, variabel, keterangan) values
  ('rekap_asrama', 'Rekap kehadiran asrama ke wali',
   E'{salam}, Bapak/Ibu {nama_wali}.\n\nRekap kehadiran asrama ananda *{nama_santri}* ({kamar}) periode {periode}:\n{rekap}\n\n{ketidakhadiran}\n\nMohon perhatian dan doanya.\n{penutup}\n{pengirim}\n{jabatan_pengirim}',
   '{nama_wali,nama_santri,kamar,periode,rekap,ketidakhadiran,pengirim}', 'Menu Musyrif → Rekap: rekap kehadiran asrama per santri ke orang tua/wali.'),
  ('rekap_kamar', 'Rekap kehadiran kamar untuk grup WA',
   E'{salam}.\n\nRekap kehadiran asrama *{kamar}* periode {periode}:\n• Rata-rata kehadiran: {persen}\n• Sesi terlaksana: {jumlah_sesi}\n• Hadir penuh: {hadir_penuh}\n{rincian}\n\n{penutup}\n{pengirim}\n{jabatan_pengirim}',
   '{kamar,periode,persen,jumlah_sesi,hadir_penuh,rincian,pengirim}', 'Menu Musyrif → Rekap: salin rekap kamar lalu tempel di grup WA kamar/wali.')
on conflict (kode) do nothing;

do $$
declare f text;
begin
  foreach f in array array['boleh_lihat_kamar(uuid)','kamar_musyrif()','absensi_asrama_rinci(uuid,date,date)']
  loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN — hasil yang benar: 3 baris, semuanya "Sesuai"
-- ---------------------------------------------------------------------
select '1. Fungsi menu Musyrif (3)' as pemeriksaan,
       case when (select count(*) from pg_proc where pronamespace = 'public'::regnamespace
         and proname in ('boleh_lihat_kamar','kamar_musyrif','absensi_asrama_rinci')) = 3 then 'Sesuai' else 'Periksa' end as hasil
union all
select '2. Template WA rekap_asrama dan rekap_kamar', case when (select count(*) from public.wa_templates where kode in ('rekap_asrama','rekap_kamar')) = 2 then 'Sesuai' else 'Periksa' end
union all
select '3. Migrasi 4600 (Klinik) sudah terpasang', case when exists (select 1 from pg_proc where proname = 'buat_rujukan') then 'Sesuai' else 'Periksa: jalankan 4600 dulu' end;
