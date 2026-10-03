-- SIMKA PRO | supabase/migrations/20261003000800_organisasi_tanpa_putaran.sql | v1.0 | Fase 1 – Struktur organisasi | 03/10/2026
-- Menjaga pohon bidang/unit tetap sah saat dipindah dari menu Struktur Organisasi:
--   1. Unit tidak boleh dipindah ke bawah dirinya sendiri atau ke bawah turunannya (putaran).
--   2. Hanya satu simpul puncak (Pimpinan Pondok) dan simpul puncak tidak boleh dipindah.
-- Aman dijalankan ulang.

create or replace function public.tg_org_units_jaga()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.parent_id is null and new.jenis <> 'pimpinan' then
    raise exception 'Bidang atau unit harus berada di bawah induk.' using errcode = '23514';
  end if;
  if new.jenis = 'pimpinan' and new.parent_id is not null then
    raise exception 'Pimpinan Pondok adalah puncak struktur dan tidak dapat dipindah.' using errcode = '23514';
  end if;
  if tg_op = 'UPDATE' and new.parent_id is not null
     and new.parent_id in (select public.unit_turunan(new.id)) then
    raise exception 'Unit tidak dapat dipindah ke bawah dirinya sendiri atau turunannya.' using errcode = '23514';
  end if;
  return new;
end $$;

drop trigger if exists aa_jaga_pohon on public.org_units;
create trigger aa_jaga_pohon before insert or update on public.org_units
  for each row execute function public.tg_org_units_jaga();

-- Pemeriksaan: harus tampil 1 baris bertuliskan "Penjaga pohon terpasang"
select 'Penjaga pohon terpasang' as hasil
from pg_trigger where tgname = 'aa_jaga_pohon';
