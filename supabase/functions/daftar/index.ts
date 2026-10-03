// SIMKA PRO | supabase/functions/daftar/index.ts | v1.0 | Tahap 4 | 03/10/2026
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

// ===================== FUNGSI DAFTAR =====================
// SIMKA PRO · Edge Function "daftar"
// Pendaftaran mandiri pegawai. Akun dibuat dalam status "menunggu" dan baru dapat
// dipakai setelah diverifikasi admin/superadmin. Bila data hasil impor Excel dengan
// NIY atau email yang sama sudah ada (tanpa akun), pendaftaran ditautkan ke data tersebut.

type Isian = {
  nama_lengkap: string; username: string; email: string; sandi: string;
  niy?: string; tempat_lahir?: string; tanggal_lahir?: string; jenis_kelamin?: "L" | "P";
  no_hp?: string; pendidikan_terakhir?: string; status_keluarga?: string; org_unit_id?: string;
  fungsional_ids?: string[]; struktural_id?: string | null;
};

layani(async (req) => {
  const d = await bacaBody<Isian>(req);
  const nama = (d.nama_lengkap ?? "").trim();
  const username = (d.username ?? "").trim().toLowerCase();
  const email = (d.email ?? "").trim().toLowerCase();

  if (nama.length < 3) throw new Galat("Nama lengkap minimal 3 huruf.");
  if (!/^[a-z0-9._]{4,30}$/.test(username)) {
    throw new Galat("Username 4–30 karakter, hanya huruf kecil, angka, titik, atau garis bawah.");
  }
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw new Galat("Alamat email tidak valid.");
  sandiKuat(d.sandi);
  if (!d.jenis_kelamin) throw new Galat("Jenis kelamin wajib dipilih.");
  if (d.no_hp && !/^[0-9+]{9,16}$/.test(d.no_hp)) throw new Galat("Nomor HP hanya berisi angka (9–16 digit).");
  const fungsional = Array.isArray(d.fungsional_ids) ? [...new Set(d.fungsional_ids)] : [];
  if (fungsional.length === 0) throw new Galat("Pilih minimal satu jabatan fungsional.");

  const admin = klienAdmin();

  // medis/security tidak boleh rangkap
  const { data: fp } = await admin.from("functional_positions").select("id, nama, tanpa_rangkap").in("id", fungsional);
  if ((fp ?? []).length !== fungsional.length) throw new Galat("Jabatan fungsional tidak dikenal.");
  if (fungsional.length > 1 && (fp ?? []).some((f) => f.tanpa_rangkap)) {
    throw new Galat("Tugas medis dan security tidak dapat dirangkap dengan tugas lain.");
  }

  // username/email unik
  const { data: dupU } = await admin.from("employees").select("id").ilike("username", username).maybeSingle();
  if (dupU) throw new Galat("Username sudah dipakai. Silakan pilih username lain.");
  const { data: dupE } = await admin.from("employees").select("id, user_id, status_akun").ilike("email", email).maybeSingle();
  if (dupE && dupE.user_id) throw new Galat("Email sudah terdaftar. Gunakan menu Lupa kata sandi bila lupa.");

  // tautkan ke data impor (tanpa akun) berdasarkan NIY atau email
  let target: { id: string } | null = null;
  if (dupE && !dupE.user_id && dupE.status_akun === "tanpa_akun") target = { id: dupE.id };
  if (!target && d.niy) {
    const { data: n } = await admin.from("employees").select("id, user_id, status_akun").eq("niy", d.niy.trim()).maybeSingle();
    if (n?.user_id) throw new Galat("NIY sudah memiliki akun. Hubungi admin bila ini keliru.");
    if (n && n.status_akun === "tanpa_akun") target = { id: n.id };
  }

  const { data: u, error: eu } = await admin.auth.admin.createUser({
    email, password: d.sandi, email_confirm: true, user_metadata: { nama_lengkap: nama, username },
  });
  if (eu || !u.user) {
    if (/already/i.test(eu?.message ?? "")) throw new Galat("Email sudah terdaftar.");
    throw new Galat("Akun tidak dapat dibuat. Silakan coba lagi.");
  }

  const biodata = {
    user_id: u.user.id, username, email, nama_lengkap: nama,
    tempat_lahir: d.tempat_lahir?.trim() || null, tanggal_lahir: d.tanggal_lahir || null,
    jenis_kelamin: d.jenis_kelamin, no_hp: d.no_hp || null,
    pendidikan_terakhir: d.pendidikan_terakhir || null, status_keluarga: d.status_keluarga || null,
    org_unit_id: d.org_unit_id || null, status_akun: "menunggu",
  };

  let empId: string;
  if (target) {
    const { error } = await admin.from("employees").update(biodata).eq("id", target.id);
    if (error) { await admin.auth.admin.deleteUser(u.user.id); throw new Galat("Data gagal disimpan."); }
    empId = target.id;
  } else {
    const { data: e, error } = await admin.from("employees")
      .insert({ ...biodata, niy: d.niy?.trim() || null }).select("id").single();
    if (error || !e) {
      await admin.auth.admin.deleteUser(u.user.id);
      throw new Galat(error?.code === "23505" ? "NIY sudah terdaftar." : "Data gagal disimpan.");
    }
    empId = e.id;
  }

  await admin.from("employee_functions").delete().eq("employee_id", empId);
  await admin.from("employee_functions").insert(fungsional.map((id) => ({ employee_id: empId, functional_position_id: id })));
  if (d.struktural_id) {
    await admin.from("employee_structurals").upsert({
      employee_id: empId, structural_position_id: d.struktural_id, org_unit_id: d.org_unit_id || null,
    });
  }

  return json({ ok: true, pesan: "Pendaftaran terkirim, menunggu verifikasi admin." });
});
