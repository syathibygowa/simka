-- SIMKA PRO | supabase/cek-akhir-fase9-v1.0.sql | v1.0 | Fase 9 – Pemeriksaan akhir Portal Wali (hanya membaca) | 15/10/2026
-- Jalankan di Supabase → SQL Editor → Run SETELAH migrasi 9700–10100. Tidak mengubah data apa pun.
-- Hasil yang benar: baris 1–10 "Sesuai"; baris 11–16 adalah kesiapan data (angka/keterangan untuk ditindaklanjuti).
with s as (select public._portal_set() v)
select 1 as no, 'Tabel portal wali (sesi, percobaan masuk, pengumuman, notifikasi HP) ber-RLS' as pemeriksaan,
       case when (select count(*) from pg_class where relname in ('guardian_sessions','guardian_login_attempts','guardian_announcements',
             'guardian_announcement_targets','guardian_push_subscriptions','guardian_push_queue') and relrowsecurity) = 6 then 'Sesuai' else 'Periksa' end as hasil
union all select 2, 'Tabel portal tidak dapat dibaca langsung tanpa login',
       case when not has_table_privilege('anon', 'public.guardian_sessions', 'select') and not has_table_privilege('anon', 'public.guardian_announcements', 'select')
            then 'Sesuai' else 'Periksa' end
union all select 3, 'Pintu portal tanpa login: masuk, keluar, data, baca pengumuman, notifikasi HP',
       case when has_function_privilege('anon', 'public.portal_masuk(text,date,text,text)', 'execute')
             and has_function_privilege('anon', 'public.portal_keluar(text)', 'execute')
             and has_function_privilege('anon', 'public.portal_data(text,text,jsonb)', 'execute')
             and has_function_privilege('anon', 'public.portal_baca_pengumuman(text,uuid)', 'execute')
             and has_function_privilege('anon', 'public.portal_daftar_dorong(text,text,text,text,text)', 'execute') then 'Sesuai' else 'Periksa' end
union all select 4, 'Fungsi pengelolaan tertutup bagi pengguna tanpa login',
       case when not has_function_privilege('anon', 'public.ringkasan_portal_wali()', 'execute')
             and not has_function_privilege('anon', 'public.simpan_pengumuman_wali(jsonb)', 'execute')
             and not has_function_privilege('anon', 'public._portal_keuangan(uuid,jsonb,jsonb)', 'execute') then 'Sesuai' else 'Periksa' end
union all select 5, 'Butir sensitif (riwayat sakit, keuangan) mengikuti sakelar superadmin',
       (select case when v->'butir' ? 'sakit' and v->'butir' ? 'keuangan' then 'Sesuai (sakit: ' || (v->'butir'->>'sakit') || ', keuangan: ' || (v->'butir'->>'keuangan') || ')' else 'Periksa' end from s)
union all select 6, 'Semua 14 butir informasi terdaftar',
       (select case when (select count(*) from jsonb_object_keys(v->'butir')) = 14 then 'Sesuai' else 'Periksa' end from s)
union all select 7, 'Bagian portal lengkap (beranda s.d. dokumen)',
       case when (select count(*) from pg_proc where pronamespace = 'public'::regnamespace and proname in ('_portal_beranda','_portal_kehadiran','_portal_perizinan',
             '_portal_kunjungan','_portal_titipan','_portal_sakit','_portal_hafalan','_portal_ujian','_portal_nilai','_portal_prestasi','_portal_keuangan',
             '_portal_pengumuman','_portal_dokumen','_portal_dokumen_buka')) = 14 then 'Sesuai' else 'Periksa' end
union all select 8, 'Sesi wali gugur otomatis bila nomor HP/data santri berubah',
       case when (select count(*) from pg_trigger where tgname = 'zz_cabut_sesi_wali') = 2 then 'Sesuai' else 'Periksa' end
union all select 9, 'Notifikasi HP wali ikut dikirim fungsi dorong',
       case when position('guardian_push_queue' in (select prosrc from pg_proc where proname = '_dorong_ambil')) > 0 then 'Sesuai' else 'Periksa' end
union all select 10, 'Jenis dokumen santri yang dapat diunduh wali',
       (select 'Sesuai (' || jsonb_array_length(v->'dokumen'->'surat') || ' jenis surat, ' || jsonb_array_length(v->'dokumen'->'tahfizh') || ' jenis dokumen tahfizh)' from s)
union all select 11, 'Portal Wali sedang', (select case when (v->>'aktif')::boolean then 'DIBUKA' else 'DITUTUP (buka di menu Portal Wali → Pengaturan)' end from s)
union all select 12, 'Santri aktif siap masuk portal (tanggal lahir + nomor HP lengkap)',
       (select count(*) filter (where s2.tanggal_lahir is not null and exists (select 1 from student_contacts c where c.student_id = s2.id and length(regexp_replace(coalesce(c.no_hp, ''), '\D', '', 'g')) >= 9))
               || ' dari ' || count(*) from students s2 where s2.status = 'aktif')
union all select 13, 'Sesi wali aktif / santri yang dipantau', (select count(*) || ' sesi / ' || count(distinct student_id) || ' santri' from guardian_sessions where dicabut_pada is null and kedaluwarsa > now())
union all select 14, 'Pengumuman untuk wali / perangkat wali berlangganan notifikasi HP',
       (select count(*) from guardian_announcements) || ' pengumuman / ' || (select count(*) from guardian_push_subscriptions) || ' perangkat'
union all select 15, 'Percobaan masuk gagal 24 jam terakhir', (select count(*)::text from guardian_login_attempts where not berhasil and waktu > now() - interval '24 hours')
union all select 16, 'Dokumen santri sah bertanda tangan elektronik (surat + tahfizh)',
       (select count(*) from outgoing_letters o join document_registry d on d.id = o.document_id and d.status = 'sah' and d.mode_ttd = 'elektronik' where o.status = 'terbit')
       || ' surat + ' || (select count(*) from tahfizh_documents x join document_registry d on d.id = x.document_id and d.status = 'sah' where x.status = 'terbit' and x.mode_ttd = 'elektronik') || ' dokumen tahfizh'
order by no;
