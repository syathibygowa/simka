// SIMKA PRO | supabase/functions/dorong/index.ts | v1.0 | Fase 3 – Tahap 1 Pengumuman, audit log, notifikasi HP | 04/10/2026
// Notifikasi dorong ke HP (web push, standar VAPID). Satu berkas agar dapat ditempel di editor dashboard Supabase.
// Pengaturan fungsi di dashboard: Verify JWT = DIMATIKAN (fungsi memeriksa sendiri token internal).
//
// Aksi:
//   {"aksi":"kunci"}  → mengembalikan kunci publik VAPID; bila belum ada, kunci dibuat sekali lalu disimpan
//                       di skema privat database. Kunci publik memang boleh diketahui siapa saja.
//   {"aksi":"kirim"}  → dipanggil database (pg_net) setiap ada notifikasi baru; wajib header x-simka-token.
//                       Mengirim antrian push_queue ke semua HP pegawai yang berlangganan.
// Tidak ada secret baru: SUPABASE_URL dan SUPABASE_SERVICE_ROLE_KEY tersedia otomatis.
import { createClient } from "npm:@supabase/supabase-js@2";
import * as webpush from "jsr:@negrel/webpush@0.5.0";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (data: unknown, status = 200) =>
  new Response(JSON.stringify(data), { status, headers: { ...cors, "Content-Type": "application/json; charset=utf-8" } });

const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
  auth: { persistSession: false, autoRefreshToken: false },
});

const KONTAK = "mailto:syathiby.gowa@gmail.com";
let server: webpush.ApplicationServer | null = null;

/** Ambil (atau buat sekali) kunci VAPID dari database. */
async function siapkanKunci(): Promise<{ publik: string; rahasia: Record<string, unknown> }> {
  const { data, error } = await db.rpc("_dorong_rahasia");
  if (error) throw new Error("Gagal membaca pengaturan dorong: " + error.message);
  const r = (data ?? {}) as Record<string, any>;
  if (r.vapid?.publik) return { publik: r.vapid.publik, rahasia: r };

  const kunci = await webpush.generateVapidKeys({ extractable: true });
  const jwk = await webpush.exportVapidKeys(kunci);
  const publik = await webpush.exportApplicationServerKey(kunci);
  // Bila dua permintaan bersamaan membuat kunci, yang tersimpan pertama yang dipakai.
  const { data: tersimpan, error: e2 } = await db.rpc("_dorong_simpan_kunci", { p: { publik, jwk } });
  if (e2) throw new Error("Gagal menyimpan kunci dorong: " + e2.message);
  const { data: ulang } = await db.rpc("_dorong_rahasia");
  return { publik: tersimpan as string, rahasia: (ulang ?? {}) as Record<string, unknown> };
}

async function aplikasiServer(rahasia: Record<string, any>): Promise<webpush.ApplicationServer> {
  if (server) return server;
  const vapidKeys = await webpush.importVapidKeys(rahasia.vapid.jwk, { extractable: false });
  server = await webpush.ApplicationServer.new({ contactInformation: KONTAK, vapidKeys });
  return server;
}

type Baris = {
  antrian_id: number; endpoint: string; p256dh: string; auth: string;
  judul: string; isi: string | null; tautan: string | null; notif_id: string; penting: boolean;
};

async function kirimAntrian(rahasia: Record<string, any>) {
  const as = await aplikasiServer(rahasia);
  let total = 0, ok = 0, hilang = 0;
  for (let putaran = 0; putaran < 5; putaran++) {
    const { data, error } = await db.rpc("_dorong_ambil", { p_batas: 300 });
    if (error) throw new Error("Gagal mengambil antrian: " + error.message);
    const baris = (data ?? []) as Baris[];
    if (!baris.length) break;
    const antrian = new Set<number>(); const berhasil: string[] = []; const gugur: string[] = [];
    await Promise.all(baris.map(async (b) => {
      antrian.add(b.antrian_id);
      const pesan = JSON.stringify({ judul: b.judul, isi: b.isi ?? "", tautan: b.tautan ?? "/notifikasi", id: b.notif_id });
      try {
        await as.subscribe({ endpoint: b.endpoint, keys: { p256dh: b.p256dh, auth: b.auth } })
          .pushTextMessage(pesan, { urgency: b.penting ? webpush.Urgency.High : webpush.Urgency.Normal, ttl: 86400, topic: b.notif_id.replace(/-/g, "").slice(0, 32) });
        berhasil.push(b.endpoint);
      } catch (e) {
        const status = (e as any)?.response?.status;
        if (status === 404 || status === 410) gugur.push(b.endpoint);   // langganan sudah tidak berlaku
        else console.error("Dorong gagal", status ?? (e as Error).message);
      }
    }));
    await db.rpc("_dorong_selesai", { p_antrian: [...antrian], p_ok: berhasil, p_hilang: gugur });
    total += baris.length; ok += berhasil.length; hilang += gugur.length;
  }
  return { total, ok, hilang };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ galat: "Metode tidak diizinkan." }, 405);
  try {
    const isi = await req.json().catch(() => ({}));
    const { publik, rahasia } = await siapkanKunci();
    if (isi.aksi === "kunci") return json({ publik });

    const token = req.headers.get("x-simka-token") ?? "";
    if (!token || token !== (rahasia as any).dorong_token) return json({ galat: "Tidak berwenang." }, 401);
    return json({ status: "selesai", ...(await kirimAntrian(rahasia)) });
  } catch (e) {
    console.error(e);
    return json({ galat: "Terjadi kesalahan pada server dorong." }, 500);
  }
});
