// SIMKA PRO | supabase/functions/reset-sandi/index.ts | v1.0 | Tahap 4 | 03/10/2026
// Versi satu berkas (modul bersama sudah digabung) agar dapat ditempel di editor dashboard Supabase.
import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";

// ===================== MODUL BERSAMA =====================
// SIMKA PRO · modul bersama Edge Functions
// Rahasia dibaca dari Supabase Secrets (tidak pernah ada di repo):
//   SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY (otomatis tersedia)
//   GAS_URL, GAS_SECRET, APP_URL (dipasang manual: supabase secrets set ...)

export const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...cors, "Content-Type": "application/json; charset=utf-8" },
  });
}

/** Galat yang pesannya aman ditampilkan ke pengguna. */
export class Galat extends Error {
  constructor(pesan: string, public status = 400) {
    super(pesan);
  }
}

export function layani(handler: (req: Request) => Promise<Response>) {
  Deno.serve(async (req) => {
    if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
    if (req.method !== "POST") return json({ galat: "Metode tidak diizinkan." }, 405);
    try {
      return await handler(req);
    } catch (e) {
      if (e instanceof Galat) return json({ galat: e.message }, e.status);
      console.error(e);
      return json({ galat: "Terjadi kesalahan pada server. Silakan coba lagi." }, 500);
    }
  });
}

export const env = (k: string, wajib = true): string => {
  const v = Deno.env.get(k) ?? "";
  if (wajib && !v) throw new Error(`Secret ${k} belum dipasang.`);
  return v;
};

export function klienAdmin(): SupabaseClient {
  return createClient(env("SUPABASE_URL"), env("SUPABASE_SERVICE_ROLE_KEY"), {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

export function klienAnon(): SupabaseClient {
  return createClient(env("SUPABASE_URL"), env("SUPABASE_ANON_KEY"), {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

export type Pegawai = {
  id: string;
  user_id: string | null;
  username: string | null;
  email: string | null;
  nama_lengkap: string;
  peran: "superadmin" | "admin" | "pegawai";
  status_akun: string;
  no_hp: string | null;
};

/** Ambil pegawai pemanggil dari token JWT; wajib akun aktif. */
export async function pemanggil(req: Request, admin: SupabaseClient): Promise<Pegawai> {
  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  if (!token) throw new Galat("Sesi tidak ditemukan. Silakan masuk kembali.", 401);
  const { data, error } = await admin.auth.getUser(token);
  if (error || !data.user) throw new Galat("Sesi berakhir. Silakan masuk kembali.", 401);
  const { data: p } = await admin.from("employees").select("*").eq("user_id", data.user.id).maybeSingle();
  if (!p || p.status_akun !== "aktif") throw new Galat("Akun Anda belum aktif.", 403);
  return p as Pegawai;
}

export async function bolehAdmin(admin: SupabaseClient, p: Pegawai, izin: string): Promise<boolean> {
  if (p.peran === "superadmin") return true;
  if (p.peran !== "admin") return false;
  const { data } = await admin.from("admin_permissions").select("kode")
    .eq("employee_id", p.id).eq("kode", izin).maybeSingle();
  return !!data;
}

export async function audit(admin: SupabaseClient, pelaku: string | null, aksi: string,
  ringkasan: string, data?: unknown, tabel = "employees", dataId?: string) {
  await admin.from("audit_logs").insert({
    employee_id: pelaku, aksi, tabel, data_id: dataId ?? null, ringkasan, data: data ?? null,
  });
}

/** Kirim email lewat jembatan Google Apps Script (Gmail pondok). Gagal kirim tidak menggagalkan proses. */
export async function kirimEmail(ke: string, subjek: string, html: string): Promise<boolean> {
  const url = Deno.env.get("GAS_URL");
  const rahasia = Deno.env.get("GAS_SECRET");
  if (!url || !rahasia) {
    console.warn("GAS_URL/GAS_SECRET belum dipasang; email tidak terkirim.");
    return false;
  }
  try {
    const r = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "text/plain;charset=utf-8" },
      body: JSON.stringify({ rahasia, aksi: "email", ke, subjek, html }),
      redirect: "follow",
    });
    const t = await r.json().catch(() => ({}));
    return !!t.ok;
  } catch (e) {
    console.error("Email gagal:", e);
    return false;
  }
}

export function templatEmail(judul: string, isi: string, tombol?: { teks: string; url: string }): string {
  const btn = tombol
    ? `<p style="margin:28px 0"><a href="${tombol.url}" style="background:#C7332F;background-image:linear-gradient(90deg,#C7332F,#F39A4E);color:#fff;padding:12px 22px;border-radius:10px;text-decoration:none;font-weight:600">${tombol.teks}</a></p>`
    : "";
  return `<div style="font-family:Arial,Helvetica,sans-serif;max-width:560px;margin:auto;color:#1F1416">
  <div style="background:linear-gradient(90deg,#C7332F,#F39A4E);color:#fff;padding:18px 22px;border-radius:12px 12px 0 0">
    <div style="font-size:18px;font-weight:700">SIMKA PRO</div>
    <div style="font-size:12px;opacity:.9">Pondok Pesantren Tahfizhul Qur'an Imam Asy-Syathiby Wahdah Islamiyah Gowa</div>
  </div>
  <div style="border:1px solid #f0d9cc;border-top:0;padding:22px;border-radius:0 0 12px 12px;line-height:1.6">
    <h2 style="font-size:17px;margin:0 0 12px">${judul}</h2>${isi}${btn}
    <p style="font-size:12px;color:#7a6a6c;margin-top:28px">Email ini dikirim otomatis oleh SIMKA PRO. Mohon tidak membalas email ini.</p>
  </div></div>`;
}

export async function bacaBody<T>(req: Request): Promise<T> {
  try {
    return await req.json() as T;
  } catch {
    throw new Galat("Format permintaan tidak valid.");
  }
}

export function sandiKuat(s: string) {
  if (typeof s !== "string" || s.length < 8) throw new Galat("Kata sandi minimal 8 karakter.");
  if (!/[A-Za-z]/.test(s) || !/[0-9]/.test(s)) throw new Galat("Kata sandi harus memuat huruf dan angka.");
}

export async function sha256(teks: string): Promise<string> {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(teks));
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

export function acak(panjang = 32): string {
  const b = new Uint8Array(panjang);
  crypto.getRandomValues(b);
  return [...b].map((x) => x.toString(16).padStart(2, "0")).join("");
}

/** Sandi sementara mudah dibaca, contoh: Syathiby-7K2Q9M */
export function sandiSementara(): string {
  const huruf = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
  const b = new Uint8Array(6);
  crypto.getRandomValues(b);
  return "Syathiby-" + [...b].map((x) => huruf[x % huruf.length]).join("");
}

export const appUrl = () => (Deno.env.get("APP_URL") ?? "").replace(/\/$/, "");

// ===================== FUNGSI RESET-SANDI =====================
// SIMKA PRO · Edge Function "reset-sandi"
// aksi "minta": pegawai memasukkan username → tautan reset (berlaku 30 menit) dikirim ke email.
// aksi "atur" : token dari tautan + sandi baru → sandi diganti.

const BERLAKU_MENIT = 30;

layani(async (req) => {
  const b = await bacaBody<{ aksi: "minta" | "atur"; username?: string; token?: string; sandi?: string }>(req);
  const admin = klienAdmin();

  if (b.aksi === "minta") {
    const umum = json({ ok: true, pesan: "Bila username terdaftar, tautan atur ulang kata sandi telah dikirim ke email Anda. Periksa juga folder Spam." });
    if (!b.username) throw new Galat("Username wajib diisi.");
    const { data: p } = await admin.from("employees").select("id, email, nama_lengkap, status_akun")
      .ilike("username", b.username.trim()).maybeSingle();
    if (!p || !p.email || p.status_akun !== "aktif") return umum;

    // batasi: maksimal 3 permintaan per jam
    const sejam = new Date(Date.now() - 3600_000).toISOString();
    const { count } = await admin.from("password_reset_tokens").select("id", { count: "exact", head: true })
      .eq("employee_id", p.id).gte("created_at", sejam);
    if ((count ?? 0) >= 3) throw new Galat("Permintaan terlalu sering. Coba lagi dalam satu jam.", 429);

    const token = acak(32);
    await admin.from("password_reset_tokens").insert({
      employee_id: p.id, token_hash: await sha256(token),
      kedaluwarsa: new Date(Date.now() + BERLAKU_MENIT * 60_000).toISOString(),
    });
    const url = `${appUrl()}/#/atur-sandi?token=${token}`;
    await kirimEmail(p.email, "Atur ulang kata sandi SIMKA PRO", templatEmail(
      "Atur ulang kata sandi",
      `<p>Assalamu'alaikum warahmatullahi wabarakatuh, ${p.nama_lengkap}.</p>
       <p>Kami menerima permintaan untuk mengatur ulang kata sandi akun SIMKA PRO Anda.
       Tautan berikut berlaku selama ${BERLAKU_MENIT} menit dan hanya dapat dipakai satu kali.</p>
       <p>Bila Anda tidak merasa meminta, abaikan email ini; kata sandi Anda tetap aman.</p>`,
      { teks: "Atur kata sandi baru", url },
    ));
    await audit(admin, p.id, "minta_reset_sandi", "Meminta tautan atur ulang kata sandi");
    return umum;
  }

  if (b.aksi === "atur") {
    if (!b.token || !b.sandi) throw new Galat("Data tidak lengkap.");
    sandiKuat(b.sandi);
    const { data: t } = await admin.from("password_reset_tokens")
      .select("id, employee_id, kedaluwarsa, dipakai_pada").eq("token_hash", await sha256(b.token)).maybeSingle();
    if (!t || t.dipakai_pada) throw new Galat("Tautan tidak valid atau sudah dipakai.");
    if (new Date(t.kedaluwarsa) < new Date()) throw new Galat("Tautan sudah kedaluwarsa. Silakan minta tautan baru.");
    const { data: p } = await admin.from("employees").select("user_id").eq("id", t.employee_id).single();
    const { error } = await admin.auth.admin.updateUserById(p!.user_id, { password: b.sandi });
    if (error) throw new Galat("Kata sandi gagal diperbarui.");
    await admin.from("password_reset_tokens").update({ dipakai_pada: new Date().toISOString() }).eq("id", t.id);
    await admin.from("employees").update({ wajib_ganti_sandi: false }).eq("id", t.employee_id);
    await audit(admin, t.employee_id, "reset_sandi", "Kata sandi diatur ulang melalui email");
    return json({ ok: true, pesan: "Kata sandi berhasil diperbarui. Silakan masuk dengan kata sandi baru." });
  }

  throw new Galat("Aksi tidak dikenal.");
});
