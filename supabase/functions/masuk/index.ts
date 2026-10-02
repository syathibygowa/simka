// SIMKA PRO · Edge Function "masuk"
// Login memakai username + kata sandi. Username dicocokkan ke email di server,
// sehingga email pegawai tidak pernah terbuka ke publik.
import { audit, bacaBody, Galat, json, klienAdmin, klienAnon, layani } from "../_shared/mod.ts";

layani(async (req) => {
  const { username, sandi } = await bacaBody<{ username: string; sandi: string }>(req);
  if (!username || !sandi) throw new Galat("Username dan kata sandi wajib diisi.");

  const admin = klienAdmin();
  const { data: p } = await admin.from("employees")
    .select("id, email, status_akun, status_keaktifan, wajib_ganti_sandi, catatan_verifikasi")
    .ilike("username", username.trim()).maybeSingle();

  const salah = new Galat("Username atau kata sandi salah.", 401);
  if (!p || !p.email) throw salah;

  const { data, error } = await klienAnon().auth.signInWithPassword({ email: p.email, password: sandi });
  if (error || !data.session) {
    await audit(admin, p.id, "gagal_masuk", "Percobaan masuk gagal");
    throw salah;
  }

  // Sandi benar, periksa status akun
  if (p.status_akun === "menunggu") {
    return json({ status: "menunggu", pesan: "Pendaftaran Anda sedang menunggu verifikasi admin." }, 403);
  }
  if (p.status_akun === "ditolak") {
    return json({ status: "ditolak", pesan: "Pendaftaran Anda ditolak. " + (p.catatan_verifikasi ?? "") }, 403);
  }
  if (p.status_akun !== "aktif" || ["nonaktif", "keluar"].includes(p.status_keaktifan)) {
    return json({ status: "nonaktif", pesan: "Akun Anda tidak aktif. Hubungi admin pondok." }, 403);
  }

  await audit(admin, p.id, "masuk", "Masuk ke aplikasi");
  return json({
    status: "aktif",
    wajib_ganti_sandi: p.wajib_ganti_sandi,
    session: { access_token: data.session.access_token, refresh_token: data.session.refresh_token },
  });
});
