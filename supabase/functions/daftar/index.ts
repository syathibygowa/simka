// SIMKA PRO · Edge Function "daftar"
// Pendaftaran mandiri pegawai. Akun dibuat dalam status "menunggu" dan baru dapat
// dipakai setelah diverifikasi admin/superadmin. Bila data hasil impor Excel dengan
// NIY atau email yang sama sudah ada (tanpa akun), pendaftaran ditautkan ke data tersebut.
import { bacaBody, Galat, json, klienAdmin, layani, sandiKuat } from "../_shared/mod.ts";

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
