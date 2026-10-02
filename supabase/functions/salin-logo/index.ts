// SIMKA PRO · Edge Function "salin-logo"
// Logo/kop yang ditempel dari tautan internet disalin ke bucket "publik",
// agar tidak hilang bila tautan asal berubah dan dapat dimasukkan ke PDF. (Bagian 34)
import { audit, bacaBody, Galat, json, klienAdmin, layani, pemanggil } from "../_shared/mod.ts";

const MAKS = 1024 * 1024; // 1 MB
const JENIS: Record<string, string> = { "image/png": "png", "image/jpeg": "jpg", "image/webp": "webp", "image/svg+xml": "svg" };

layani(async (req) => {
  const admin = klienAdmin();
  const saya = await pemanggil(req, admin);
  if (saya.peran !== "superadmin") throw new Galat("Hanya superadmin yang dapat mengatur logo dan kop.", 403);

  const { url, nama } = await bacaBody<{ url: string; nama: string }>(req);
  if (!/^https:\/\//i.test(url ?? "")) throw new Galat("Tautan harus diawali https://");
  const slug = (nama ?? "logo").toLowerCase().replace(/[^a-z0-9-]+/g, "-").slice(0, 40);

  const r = await fetch(url, { redirect: "follow" });
  if (!r.ok) throw new Galat("Gambar tidak dapat diunduh dari tautan tersebut.");
  const tipe = (r.headers.get("content-type") ?? "").split(";")[0].trim();
  if (!JENIS[tipe]) throw new Galat("Berkas bukan gambar PNG, JPG, WEBP, atau SVG.");
  const buf = new Uint8Array(await r.arrayBuffer());
  if (buf.byteLength > MAKS) throw new Galat("Ukuran gambar melebihi 1 MB.");

  const path = `logo/${slug}-${Date.now()}.${JENIS[tipe]}`;
  const { error } = await admin.storage.from("publik").upload(path, buf, { contentType: tipe, upsert: true });
  if (error) throw new Galat("Gambar gagal disimpan.");
  const { data: pub } = admin.storage.from("publik").getPublicUrl(path);

  await admin.from("storage_objects").insert({
    penyedia: "supabase", bucket: "publik", kunci: path, nama_berkas: path.split("/").pop(),
    mime: tipe, ukuran: buf.byteLength, kategori: "logo", status: "tersimpan", publik: true, pemilik_id: saya.id,
  });
  await audit(admin, saya.id, "salin_logo", `Menyalin logo dari ${url}`, { path }, "storage_objects");
  return json({ ok: true, url: pub.publicUrl });
});
