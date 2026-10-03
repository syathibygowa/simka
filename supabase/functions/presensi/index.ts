// SIMKA PRO | supabase/functions/presensi/index.ts | v1.0 | Fase 2 – Tahap 2 Edge Function presensi | 03/10/2026
// Versi satu berkas (modul bersama sudah digabung) agar dapat ditempel di editor dashboard Supabase.
// Pengaturan fungsi di dashboard: Verify JWT = MENYALA.
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

// ===================== FUNGSI PRESENSI =====================
// Pintu tunggal pencatatan presensi pegawai (Bagian 9 dan 40 blueprint).
// Alur di aplikasi:
//   1. RPC periksa_presensi(lat, lng, akurasi) → cek_id, waktu server, titik, jarak (untuk watermark)
//   2. Pegawai mengambil selfie dari kamera langsung; aplikasi membubuhkan watermark
//   3. POST multipart ke fungsi ini: selfie + cek_id + permintaan_id (+ pilihan/alasan bila di luar area)
// Fungsi ini:
//   * memastikan pemanggil adalah pegawai aktif (dari token, bukan dari isian),
//   * menyimpan selfie ke antrian Supabase Storage (GAS memindah ke Drive tiap 5 menit),
//   * menghitung sidik berkas SHA-256 (deteksi selfie identik),
//   * memanggil catat_presensi() — waktu, jarak, dan sesi ditentukan database,
//   * membatalkan selfie bila pencatatan ditolak, dan tidak membuat data dobel saat dikirim ulang.

const BATAS_SELFIE_MIN = 3 * 1024;      // 3 KB
const BATAS_SELFIE_MAKS = 600 * 1024;   // 600 KB (selfie 720 px JPEG ±40–70 KB)
const KODE_STATUS: Record<string, number> = {
  AKUN_TIDAK_AKTIF: 403, CEK_TIDAK_DITEMUKAN: 409, CEK_SUDAH_DIPAKAI: 409, CEK_KEDALUWARSA: 409,
  SELFIE_WAJIB: 422, PILIHAN_WAJIB: 422, ALASAN_WAJIB: 422, TIDAK_ADA_SESI: 409, BUTUH_KONFIRMASI: 409,
  PERMINTAAN_TIDAK_SAH: 422,
};

/** Nama berkas rapi: spasi dan karakter khusus dihapus (sama dengan src/lib/penyimpanan.js). */
export function namaRapi(...bagian: (string | number | null | undefined)[]): string {
  return bagian.filter((b) => b !== null && b !== undefined && String(b) !== "")
    .map((b) => String(b).normalize("NFKD").replace(/[^A-Za-z0-9-]/g, "")).filter(Boolean).join("-");
}

/** Tanggal WITA (UTC+8, tanpa musim panas). */
export function wita(d: Date) {
  const w = new Date(d.getTime() + 8 * 3600 * 1000);
  const yyyy = String(w.getUTCFullYear());
  const mm = String(w.getUTCMonth() + 1).padStart(2, "0");
  const dd = String(w.getUTCDate()).padStart(2, "0");
  return { yyyy, mm, dd, iso: `${yyyy}-${mm}-${dd}`, ringkas: `${yyyy}${mm}${dd}` };
}

export function tambahHari(isoTanggal: string, hari: number): string {
  const d = new Date(isoTanggal + "T00:00:00Z");
  d.setUTCDate(d.getUTCDate() + hari);
  return d.toISOString().slice(0, 10);
}

export async function sha256Hex(data: Uint8Array<ArrayBuffer>): Promise<string> {
  const h = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(h)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

/** Pastikan berkas benar-benar JPEG (bukan hanya berlabel JPEG). */
export function apakahJpeg(b: Uint8Array): boolean {
  return b.length > 4 && b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff;
}

/** Label berkas dari hasil presensi: Datang, Pulang, Hadir, Keluar, Kembali (digabung bila lebih dari satu). */
export function labelDariHasil(hasil: Array<{ label?: string }> | null | undefined): string {
  const unik = [...new Set((hasil ?? []).map((h) => namaRapi(h.label ?? "")).filter(Boolean))];
  return unik.length ? unik.join("") : "Presensi";
}

function ipPemanggil(req: Request): string {
  const f = req.headers.get("x-forwarded-for") ?? "";
  return (f.split(",")[0] || req.headers.get("x-real-ip") || "").trim().slice(0, 60);
}

async function hapusSelfie(admin: SupabaseClient, idObjek: string | null, kunci: string | null) {
  try {
    if (idObjek) await admin.from("storage_objects").delete().eq("id", idObjek);
    if (kunci) await admin.storage.from("antrian").remove([kunci]);
  } catch (e) {
    console.error("Gagal membersihkan selfie:", e);
  }
}

layani(async (req) => {
  const admin = klienAdmin();
  const p = await pemanggil(req, admin);

  // ---------- Baca isian ----------
  let form: FormData;
  try {
    form = await req.formData();
  } catch {
    throw new Galat("Format permintaan tidak valid. Muat ulang aplikasi lalu coba lagi.");
  }
  const teks = (k: string) => {
    const v = form.get(k);
    return typeof v === "string" ? v.trim() : "";
  };
  const cekId = teks("cek_id");
  const permintaanId = teks("permintaan_id");
  const pilihan = teks("pilihan") || null;
  const alasan = teks("alasan") || null;
  const konfirmasiCepat = ["1", "true"].includes(teks("konfirmasi_cepat"));
  const perangkatId = teks("perangkat_id").slice(0, 80) || null;
  const perangkatInfo = (teks("perangkat_info") || req.headers.get("user-agent") || "").slice(0, 300);

  if (!/^[0-9a-f-]{36}$/i.test(cekId)) {
    return json({ galat: "Pemeriksaan lokasi tidak ditemukan. Silakan ulangi presensi.", kode: "CEK_TIDAK_DITEMUKAN" }, 409);
  }
  if (!/^[A-Za-z0-9_-]{8,80}$/.test(permintaanId)) {
    return json({ galat: "Permintaan tidak sah. Muat ulang aplikasi lalu coba lagi.", kode: "PERMINTAAN_TIDAK_SAH" }, 422);
  }
  if (pilihan && !["hadir", "izin", "sakit"].includes(pilihan)) {
    return json({ galat: "Pilihan presensi tidak sah.", kode: "PILIHAN_WAJIB" }, 422);
  }

  // ---------- Kiriman ulang (tekan ganda / sinyal putus): kembalikan hasil lama ----------
  const { data: lama } = await admin.from("attendance_events")
    .select("id, waktu, di_area, hasil").eq("employee_id", p.id).eq("permintaan_id", permintaanId).maybeSingle();
  if (lama) {
    return json({ ok: true, ulang: true, event_id: lama.id, waktu: lama.waktu, di_area: lama.di_area, hasil: lama.hasil });
  }

  // ---------- Cek lokasi harus milik pemanggil ----------
  const { data: cek } = await admin.from("attendance_checks")
    .select("id, employee_id").eq("id", cekId).maybeSingle();
  if (!cek || cek.employee_id !== p.id) {
    return json({ galat: "Pemeriksaan lokasi tidak ditemukan. Silakan ulangi presensi.", kode: "CEK_TIDAK_DITEMUKAN" }, 409);
  }

  // ---------- Selfie ----------
  const berkas = form.get("selfie");
  if (!(berkas instanceof File)) return json({ galat: "Selfie wajib diambil pada setiap presensi.", kode: "SELFIE_WAJIB" }, 422);
  if (berkas.size < BATAS_SELFIE_MIN) return json({ galat: "Selfie tidak terbaca. Silakan ambil ulang.", kode: "SELFIE_WAJIB" }, 422);
  if (berkas.size > BATAS_SELFIE_MAKS) {
    return json({ galat: "Ukuran selfie terlalu besar. Muat ulang aplikasi lalu coba lagi.", kode: "SELFIE_WAJIB" }, 422);
  }
  const bita = new Uint8Array(await berkas.arrayBuffer());
  if (!apakahJpeg(bita)) return json({ galat: "Selfie harus berupa foto JPEG dari kamera.", kode: "SELFIE_WAJIB" }, 422);
  const sidik = await sha256Hex(bita);

  // Pengaturan (folder dan masa simpan selfie)
  const { data: set } = await admin.from("institution_settings").select("nilai").eq("kunci", "presensi").maybeSingle();
  const folderDasar = String(set?.nilai?.folder_selfie ?? "SIMKA PRO/Presensi");
  const retensi = Number(set?.nilai?.retensi_selfie_hari ?? 183);

  const t = wita(new Date());
  const { data: emp } = await admin.from("employees").select("nama_lengkap, niy").eq("id", p.id).single();
  const { count: jumlahHariIni } = await admin.from("attendance_events")
    .select("id", { count: "exact", head: true }).eq("employee_id", p.id).eq("tanggal", t.iso);
  const urut = String((jumlahHariIni ?? 0) + 1).padStart(3, "0");
  const namaDasar = namaRapi(String(emp?.nama_lengkap ?? p.nama_lengkap).replace(/\s+/g, ""), emp?.niy ?? "");
  const kunci = `${p.id}/${Date.now()}-${crypto.randomUUID().slice(0, 8)}-presensi.jpg`;

  const { error: eUnggah } = await admin.storage.from("antrian")
    .upload(kunci, bita, { contentType: "image/jpeg", upsert: false });
  if (eUnggah) {
    console.error("Unggah selfie gagal:", eUnggah);
    return json({ galat: "Selfie gagal dikirim. Periksa sinyal lalu tekan Coba lagi.", kode: "UNGGAH_GAGAL" }, 503);
  }

  const { data: obj, error: eObj } = await admin.from("storage_objects").insert({
    penyedia: "supabase", bucket: "antrian", kunci,
    nama_berkas: `${namaDasar}-Absen-${t.ringkas}-Presensi-${urut}.jpg`, mime: "image/jpeg",
    ukuran: bita.length, kategori: "selfie_presensi", folder_tujuan: `${folderDasar}/${t.yyyy}/${t.mm}`,
    status: "antri", hapus_setelah: tambahHari(t.iso, retensi), pemilik_id: p.id,
  }).select("id").single();
  if (eObj || !obj) {
    console.error("Catat berkas gagal:", eObj);
    await hapusSelfie(admin, null, kunci);
    return json({ galat: "Selfie gagal disimpan. Silakan coba lagi.", kode: "UNGGAH_GAGAL" }, 503);
  }

  // ---------- Catat presensi (waktu, jarak, dan sesi ditentukan database) ----------
  const { data: hasil, error: eCatat } = await admin.rpc("catat_presensi", {
    p_emp: p.id, p_cek: cekId, p_pilihan: pilihan, p_alasan: alasan, p_selfie: obj.id, p_hash: sidik,
    p_perangkat: perangkatId, p_info: perangkatInfo, p_ip: ipPemanggil(req), p_permintaan: permintaanId,
    p_konfirmasi_cepat: konfirmasiCepat,
  });

  if (eCatat) {
    await hapusSelfie(admin, obj.id, kunci);
    const kode = eCatat.hint ?? "";
    if (KODE_STATUS[kode]) return json({ galat: eCatat.message, kode }, KODE_STATUS[kode]);
    console.error("catat_presensi gagal:", eCatat);
    return json({ galat: "Presensi gagal dicatat. Silakan coba lagi.", kode: "GAGAL" }, 500);
  }

  if (hasil?.ulang) {
    // Permintaan yang sama sudah tercatat lebih dulu: selfie kedua tidak diperlukan
    await hapusSelfie(admin, obj.id, kunci);
    return json(hasil);
  }

  // Nama berkas akhir sesuai blueprint, contoh AhmadFauzi-1234-Absen-20261002-Datang-001.jpg
  const namaAkhir = `${namaDasar}-Absen-${t.ringkas}-${labelDariHasil(hasil?.hasil)}-${urut}.jpg`;
  await admin.from("storage_objects").update({ nama_berkas: namaAkhir }).eq("id", obj.id);

  return json({ ...hasil, berkas: namaAkhir });
});
