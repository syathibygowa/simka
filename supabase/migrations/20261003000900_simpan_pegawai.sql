-- SIMKA PRO | supabase/migrations/20261003000900_simpan_pegawai.sql | v1.0 | Fase 1 – Data pegawai | 03/10/2026
-- Menyimpan data pegawai beserta jabatannya dalam SATU transaksi (semua berhasil atau semua batal),
-- dan impor Excel per baris (baris yang gagal tidak membatalkan baris lain).
-- Hak: superadmin, atau admin dengan izin "kelola_pegawai". Aman dijalankan ulang.

create or replace function public.simpan_pegawai(p jsonb)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare
  v_id uuid := nullif(p->>'id', '')::uuid;
  v_fung uuid[] := coalesce((select array_agg(x::uuid) from jsonb_array_elements_text(p->'fungsional_ids') x), '{}');
  v_struk uuid := nullif(p->>'struktural_id', '')::uuid;
  v_tgl date := coalesce(nullif(p->>'tanggal_berlaku', '')::date, public.hari_ini());
begin
  if not public.admin_boleh('kelola_pegawai') then
    raise exception 'Anda tidak berwenang mengelola data pegawai.' using errcode = '42501';
  end if;
  if coalesce(trim(p->>'nama_lengkap'), '') = '' then
    raise exception 'Nama lengkap wajib diisi.' using errcode = '23514';
  end if;

  if v_id is null then
    insert into employees (nama_lengkap, niy, tempat_lahir, tanggal_lahir, jenis_kelamin, tmt_tugas,
      status_kepegawaian, kategori_honorer, pendidikan_terakhir, status_keluarga, no_hp, email,
      org_unit_id, level_muhaffizh, status_keaktifan)
    values (trim(p->>'nama_lengkap'), nullif(trim(p->>'niy'), ''), nullif(trim(p->>'tempat_lahir'), ''),
      nullif(p->>'tanggal_lahir', '')::date, nullif(p->>'jenis_kelamin', ''), nullif(p->>'tmt_tugas', '')::date,
      nullif(p->>'status_kepegawaian', ''), nullif(p->>'kategori_honorer', ''), nullif(p->>'pendidikan_terakhir', ''),
      nullif(p->>'status_keluarga', ''), nullif(regexp_replace(coalesce(p->>'no_hp', ''), '[^0-9+]', '', 'g'), ''),
      nullif(lower(trim(p->>'email')), ''), nullif(p->>'org_unit_id', '')::uuid, nullif(p->>'level_muhaffizh', ''),
      coalesce(nullif(p->>'status_keaktifan', ''), 'aktif'))
    returning id into v_id;
  else
    -- Hanya kolom yang dikirim yang diubah (sel Excel kosong tidak menghapus data lama)
    update employees set
      nama_lengkap        = trim(p->>'nama_lengkap'),
      niy                 = case when p ? 'niy' then nullif(trim(p->>'niy'), '') else niy end,
      tempat_lahir        = case when p ? 'tempat_lahir' then nullif(trim(p->>'tempat_lahir'), '') else tempat_lahir end,
      tanggal_lahir       = case when p ? 'tanggal_lahir' then nullif(p->>'tanggal_lahir', '')::date else tanggal_lahir end,
      jenis_kelamin       = case when p ? 'jenis_kelamin' then nullif(p->>'jenis_kelamin', '') else jenis_kelamin end,
      tmt_tugas           = case when p ? 'tmt_tugas' then nullif(p->>'tmt_tugas', '')::date else tmt_tugas end,
      status_kepegawaian  = case when p ? 'status_kepegawaian' then nullif(p->>'status_kepegawaian', '') else status_kepegawaian end,
      kategori_honorer    = case when p ? 'kategori_honorer' then nullif(p->>'kategori_honorer', '') else kategori_honorer end,
      pendidikan_terakhir = case when p ? 'pendidikan_terakhir' then nullif(p->>'pendidikan_terakhir', '') else pendidikan_terakhir end,
      status_keluarga     = case when p ? 'status_keluarga' then nullif(p->>'status_keluarga', '') else status_keluarga end,
      no_hp               = case when p ? 'no_hp' then nullif(regexp_replace(coalesce(p->>'no_hp', ''), '[^0-9+]', '', 'g'), '') else no_hp end,
      org_unit_id         = case when p ? 'org_unit_id' then nullif(p->>'org_unit_id', '')::uuid else org_unit_id end,
      level_muhaffizh     = case when p ? 'level_muhaffizh' then nullif(p->>'level_muhaffizh', '') else level_muhaffizh end,
      status_keaktifan    = coalesce(nullif(p->>'status_keaktifan', ''), status_keaktifan)
    where id = v_id;
    if not found then raise exception 'Data pegawai tidak ditemukan.'; end if;
  end if;

  -- Jabatan fungsional: hapus yang tidak dipilih dulu, baru tambah (agar aturan tidak rangkap terpenuhi)
  if p ? 'fungsional_ids' then
    delete from employee_functions where employee_id = v_id and not (functional_position_id = any(v_fung));
    insert into employee_functions (employee_id, functional_position_id)
    select v_id, f from unnest(v_fung) f
    where not exists (select 1 from employee_functions where employee_id = v_id and functional_position_id = f);
  end if;

  -- Jabatan struktural: hanya satu
  if p ? 'struktural_id' then
    if v_struk is null then
      delete from employee_structurals where employee_id = v_id;
    else
      insert into employee_structurals (employee_id, structural_position_id, org_unit_id, tmt)
      values (v_id, v_struk, nullif(p->>'unit_struktural_id', '')::uuid, v_tgl)
      on conflict (employee_id) do update set structural_position_id = excluded.structural_position_id,
        org_unit_id = excluded.org_unit_id, tmt = excluded.tmt
      where employee_structurals.structural_position_id is distinct from excluded.structural_position_id
         or employee_structurals.org_unit_id is distinct from excluded.org_unit_id;
    end if;
  end if;

  -- Tanggal berlaku (TMT) untuk riwayat yang tercatat dalam transaksi ini
  update employment_history set tanggal_berlaku = v_tgl
  where employee_id = v_id and created_at = now();

  return v_id;
end $$;

-- Pesan galat yang mudah dipahami untuk impor
create or replace function public._pesan_pegawai(p_kode text, p_kendala text, p_pesan text)
returns text language sql immutable as $$
  select case
    when p_kode = '23505' and p_kendala like '%niy%' then 'NIY sudah dipakai pegawai lain.'
    when p_kode = '23505' and p_kendala like '%email%' then 'Email sudah dipakai pegawai lain.'
    when p_kendala = 'employees_status_kepegawaian_check' then 'Status kepegawaian harus Tetap, Kontrak, atau Honorer.'
    when p_kendala = 'employees_kategori_honorer_check' then 'Kategori honorer harus Lama atau Baru.'
    when p_kendala = 'employees_pendidikan_terakhir_check' then 'Pendidikan harus SD, SMP, SMA, S1, S1-LN, S2, atau S3.'
    when p_kendala = 'employees_status_keluarga_check' then 'Status keluarga harus Menikah, Belum menikah, atau Cerai.'
    when p_kendala = 'employees_jenis_kelamin_check' then 'Jenis kelamin harus L atau P.'
    when p_kendala = 'employees_no_hp_check' then 'Nomor HP harus 9–16 angka.'
    when p_kendala = 'employees_level_muhaffizh_check' then 'Level muhaffizh harus Pemula, Terampil, atau Mahir.'
    when p_kendala = 'employees_nama_lengkap_check' then 'Nama lengkap minimal 3 huruf.'
    when p_kode = '22007' or p_kode = '22008' then 'Format tanggal tidak sah.'
    else p_pesan end
$$;

-- Impor Excel: p_baris = [{...isian simpan_pegawai...}], baris dengan NIY yang sudah ada diperbarui
create or replace function public.impor_pegawai(p_baris jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare r jsonb; i int := 0; v_id uuid; v_ada uuid; hasil jsonb := '[]'::jsonb; v_kode text; v_kendala text; v_pesan text;
begin
  if not public.admin_boleh('kelola_pegawai') then
    raise exception 'Anda tidak berwenang mengimpor data pegawai.' using errcode = '42501';
  end if;
  if jsonb_array_length(p_baris) > 500 then
    raise exception 'Maksimal 500 baris sekali impor.';
  end if;
  for r in select * from jsonb_array_elements(p_baris) loop
    i := i + 1;
    begin
      v_ada := (select id from employees where niy is not null and niy = nullif(trim(r->>'niy'), ''));
      if v_ada is not null then r := r || jsonb_build_object('id', v_ada); end if;
      v_id := public.simpan_pegawai(r);
      hasil := hasil || jsonb_build_object('baris', i, 'ok', true, 'id', v_id,
                                           'aksi', case when v_ada is null then 'ditambah' else 'diperbarui' end);
    exception when others then
      get stacked diagnostics v_kode = returned_sqlstate, v_kendala = constraint_name, v_pesan = message_text;
      hasil := hasil || jsonb_build_object('baris', i, 'ok', false,
                                           'pesan', public._pesan_pegawai(v_kode, coalesce(v_kendala, ''), v_pesan));
    end;
  end loop;
  perform public.catat_audit('impor_pegawai', 'employees', null,
    'Impor Excel pegawai: ' || jsonb_array_length(p_baris) || ' baris', null);
  return hasil;
end $$;

revoke execute on function public.simpan_pegawai(jsonb) from public, anon;
grant execute on function public.simpan_pegawai(jsonb) to authenticated;
revoke execute on function public.impor_pegawai(jsonb) from public, anon;
grant execute on function public.impor_pegawai(jsonb) to authenticated;

-- Pemeriksaan: harus tampil 2 baris (impor_pegawai dan simpan_pegawai)
select proname as fungsi_terpasang from pg_proc
where proname in ('simpan_pegawai', 'impor_pegawai') order by proname;
