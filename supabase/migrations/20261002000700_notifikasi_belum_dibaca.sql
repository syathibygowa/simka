-- =====================================================================
-- SIMKA PRO · Fase 1 · Migrasi 7: Tandai notifikasi belum dibaca
-- Pegawai dapat mengembalikan notifikasi miliknya ke status "belum dibaca".
-- =====================================================================
create or replace function public.tandai_belum_dibaca(p_id uuid)
returns int language plpgsql volatile security definer set search_path = public as $$
declare n int;
begin
  update notifications set dibaca_pada = null
  where employee_id = public.saya() and id = p_id and dibaca_pada is not null;
  get diagnostics n = row_count; return n;
end $$;
revoke execute on function public.tandai_belum_dibaca(uuid) from public, anon;
grant execute on function public.tandai_belum_dibaca(uuid) to authenticated;
