-- SIMKA PRO | supabase/migrations/20261004003400_pengasuh_tupoksi.sql | v1.0 | Fase 4 – Perbaikan P2 (pengasuh sesuai tupoksi) | 04/10/2026
-- =====================================================================
-- SIMKA PRO · Fase 4 · Migrasi 34: Pengasuh kelompok sesuai tupoksi (masukan pemilik proyek)
--   * Kelas hanya diasuh pegawai berjabatan fungsional Wali kelas, kamar oleh Musyrif/Musyrifah, halaqah oleh
--     Muhaffizh/Muhaffizhah. Ekskul dan kelompok lainnya tidak terikat jabatan.
--   * Pemeriksaan di server (atur_pengasuh) dan pemeriksaan data lama (pengasuh yang belum sesuai).
-- Jalankan SETELAH migrasi 3300. Aman dijalankan ulang.
-- =====================================================================

create or replace function public.jabatan_pengasuh(p_jenis text)
returns text language sql immutable as $$
  select case p_jenis when 'kelas' then 'WALI_KELAS' when 'kamar' then 'MUSYRIF' when 'halaqah' then 'MUHAFFIZH' end
$$;
grant execute on function public.jabatan_pengasuh(text) to authenticated;

create or replace function public.atur_pengasuh(p_group uuid, p_daftar jsonb)
returns void language plpgsql volatile security definer set search_path = public as $$
declare v_kode text; v_kendala text; v_pesan text; r jsonb; v_jabatan text;
begin
  if not public.boleh_kelola_kelompok() then raise exception 'Anda tidak berwenang mengatur pengasuh kelompok.' using errcode = '42501'; end if;
  perform public._ta_boleh_ubah((select academic_year_id from student_groups where id = p_group));
  v_jabatan := public.jabatan_pengasuh((select jenis from student_groups where id = p_group));
  delete from group_keepers where group_id = p_group
    and employee_id not in (select (x->>'employee_id')::uuid from jsonb_array_elements(coalesce(p_daftar, '[]')) x);
  for r in select * from jsonb_array_elements(coalesce(p_daftar, '[]')) loop
    if not exists (select 1 from employees where id = (r->>'employee_id')::uuid and status_keaktifan = 'aktif') then
      raise exception 'Pengasuh harus pegawai aktif.';
    end if;
    -- Kelas, kamar, dan halaqah: pengasuh wajib memegang jabatan fungsional tupoksi terkait (ekskul dan lainnya bebas)
    if v_jabatan is not null and not exists (
        select 1 from employee_functions ef join functional_positions fp on fp.id = ef.functional_position_id
        where ef.employee_id = (r->>'employee_id')::uuid and fp.kode = v_jabatan) then
      raise exception '% belum ditugaskan sebagai %. Tetapkan jabatan fungsionalnya di Data Pegawai lebih dulu.',
        (select nama_lengkap from employees where id = (r->>'employee_id')::uuid),
        (select lower(nama) from functional_positions where kode = v_jabatan);
    end if;
    insert into group_keepers (group_id, employee_id, peran, mulai, sampai, catatan)
    values (p_group, (r->>'employee_id')::uuid, coalesce(nullif(r->>'peran', ''), 'utama'),
            nullif(r->>'mulai', '')::date, nullif(r->>'sampai', '')::date, nullif(trim(r->>'catatan'), ''))
    on conflict (group_id, employee_id) do update set peran = excluded.peran, mulai = excluded.mulai,
      sampai = excluded.sampai, catatan = excluded.catatan;
  end loop;
exception when others then
  get stacked diagnostics v_kode = returned_sqlstate, v_kendala = constraint_name, v_pesan = message_text;
  raise exception '%', public._pesan_kelompok(v_kode, coalesce(v_kendala, ''), v_pesan) using errcode = v_kode;
end $$;


revoke execute on function public.atur_pengasuh(uuid,jsonb) from public, anon;
grant execute on function public.atur_pengasuh(uuid,jsonb) to authenticated;

-- ---------------------------------------------------------------------
-- PEMERIKSAAN — hasil yang benar: baris 1–2 "Sesuai"; baris 3 jumlah pengasuh lama yang belum sesuai jabatan
-- (bila lebih dari 0, buka kelompok terkait lalu ganti pengasuhnya atau lengkapi jabatan di Data Pegawai)
-- ---------------------------------------------------------------------
select 'Pemetaan tupoksi pengasuh' as pemeriksaan,
       case when public.jabatan_pengasuh('kelas') = 'WALI_KELAS' and public.jabatan_pengasuh('ekskul') is null then 'Sesuai' else 'Periksa' end as hasil
union all
select 'Jabatan Wali kelas, Musyrif, Muhaffizh tersedia',
       case when (select count(*) from public.functional_positions where kode in ('WALI_KELAS','MUSYRIF','MUHAFFIZH')) = 3 then 'Sesuai' else 'Periksa' end
union all
select 'Pengasuh lama yang belum sesuai jabatan',
       (select count(*) from public.group_keepers k join public.student_groups g on g.id = k.group_id
        where public.jabatan_pengasuh(g.jenis) is not null and not exists (
          select 1 from public.employee_functions ef join public.functional_positions fp on fp.id = ef.functional_position_id
          where ef.employee_id = k.employee_id and fp.kode = public.jabatan_pengasuh(g.jenis)))::text || ' orang';
