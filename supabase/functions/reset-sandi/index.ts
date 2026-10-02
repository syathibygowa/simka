// SIMKA PRO · Edge Function "reset-sandi"
// aksi "minta": pegawai memasukkan username → tautan reset (berlaku 30 menit) dikirim ke email.
// aksi "atur" : token dari tautan + sandi baru → sandi diganti.
import {
  acak, appUrl, audit, bacaBody, Galat, json, kirimEmail, klienAdmin, layani, sandiKuat, sha256, templatEmail,
} from "../_shared/mod.ts";

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
