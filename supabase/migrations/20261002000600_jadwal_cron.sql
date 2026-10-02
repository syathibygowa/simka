-- =====================================================================
-- SIMKA PRO · Fase 1 · Migrasi 6: Jadwal otomatis (pg_cron)
-- Aktifkan dulu ekstensi pg_cron di Dashboard Supabase → Database → Extensions.
-- Waktu cron dalam UTC (WITA = UTC+8).
-- =====================================================================
create extension if not exists pg_cron;

-- Harian 02.00 WITA: hapus audit log lebih dari 3 bulan
select cron.schedule('hapus-audit-3-bulan', '0 18 * * *',
  $$ delete from public.audit_logs where created_at < now() - interval '3 months' $$);

-- Harian 02.10 WITA: bersihkan token reset kedaluwarsa dan notifikasi dibaca > 6 bulan
select cron.schedule('bersihkan-token-notifikasi', '10 18 * * *', $$
  delete from public.password_reset_tokens where kedaluwarsa < now() - interval '1 day';
  delete from public.notifications where dibaca_pada is not null and created_at < now() - interval '6 months';
$$);

-- Harian 02.20 WITA: heartbeat internal (cadangan selain heartbeat GAS)
select cron.schedule('heartbeat-internal', '20 18 * * *',
  $$ insert into public.heartbeat (sumber, catatan) values ('pg_cron', 'heartbeat internal harian') $$);
