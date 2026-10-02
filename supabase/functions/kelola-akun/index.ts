// SIMKA PRO · Edge Function "kelola-akun"
// Aksi admin/superadmin terhadap akun pegawai:
//   verifikasi    – aktifkan atau tolak pendaftaran (izin admin: verval_akun)
//   buat          – superadmin membuatkan akun (sandi sementara, wajib ganti saat masuk pertama)
//   reset_manual  – admin mengatur sandi sementara (izin admin: kelola_pegawai)
//   ubah_peran    – superadmin menjadikan admin/pegawai beserta daftar izin admin
//   status_akun   – nonaktifkan atau aktifkan kembali akun
import {
  appUrl, audit, bacaBody, bolehAdmin, Galat, json, kirimEmail, klienAdmin, layani, pemanggil,
  sandiSementara, templatEmail,
} from "../_shared/mod.ts";

type Body = {
  aksi: "verifikasi" | "buat" | "reset_manual" | "ubah_peran" | "status_akun";
  employee_id?: string; keputusan?: "aktif" | "ditolak"; catatan?: string;
  fungsional_ids?: string[]; struktural_id?: string | null; org_unit_id?: string | null;
  username?: string; email?: string; nama_lengkap?: string; jenis_kelamin?: "L" | "P"; no_hp?: string;
  peran?: "admin" | "pegawai"; izin?: string[]; aktif?: boolean;
};

async function aturJabatan(admin: ReturnType<typeof klienAdmin>, id: string, b: Body) {
  if (Array.isArray(b.fungsional_ids)) {
    const ids = [...new Set(b.fungsional_ids)];
    if (ids.length === 0) throw new Galat("Minimal satu jabatan fungsional.");
    const { data: fp } = await admin.from("functional_positions").select("id, tanpa_rangkap").in("id", ids);
    if (ids.length > 1 && (fp ?? []).some((f) => f.tanpa_rangkap)) {
      throw new Galat("Tugas medis dan security tidak dapat dirangkap dengan tugas lain.");
    }
    await admin.from("employee_functions").delete().eq("employee_id", id);
    await admin.from("employee_functions").insert(ids.map((f) => ({ employee_id: id, functional_position_id: f })));
  }
  if (b.struktural_id !== undefined) {
    if (b.struktural_id) {
      await admin.from("employee_structurals").upsert({
        employee_id: id, structural_position_id: b.struktural_id, org_unit_id: b.org_unit_id ?? null,
      });
    } else {
      await admin.from("employee_structurals").delete().eq("employee_id", id);
    }
  }
}

layani(async (req) => {
  const admin = klienAdmin();
  const saya = await pemanggil(req, admin);
  const b = await bacaBody<Body>(req);
  const ambil = async (id?: string) => {
    if (!id) throw new Galat("Pegawai belum dipilih.");
    const { data } = await admin.from("employees").select("*").eq("id", id).maybeSingle();
    if (!data) throw new Galat("Data pegawai tidak ditemukan.", 404);
    return data;
  };

  switch (b.aksi) {
    case "verifikasi": {
      if (!(await bolehAdmin(admin, saya, "verval_akun"))) throw new Galat("Anda tidak berwenang memverifikasi akun.", 403);
      const p = await ambil(b.employee_id);
      if (p.status_akun !== "menunggu") throw new Galat("Akun ini tidak sedang menunggu verifikasi.");
      if (b.keputusan === "ditolak" && !b.catatan?.trim()) throw new Galat("Alasan penolakan wajib diisi.");
      await aturJabatan(admin, p.id, b);
      const ubah: Record<string, unknown> = {
        status_akun: b.keputusan === "aktif" ? "aktif" : "ditolak",
        catatan_verifikasi: b.catatan?.trim() || null,
        diverifikasi_oleh: saya.id, diverifikasi_pada: new Date().toISOString(),
      };
      if (b.org_unit_id !== undefined) ubah.org_unit_id = b.org_unit_id;
      await admin.from("employees").update(ubah).eq("id", p.id);
      if (b.keputusan === "aktif") {
        await kirimEmail(p.email, "Akun SIMKA PRO Anda telah aktif", templatEmail("Akun Anda telah aktif",
          `<p>Assalamu'alaikum warahmatullahi wabarakatuh, ${p.nama_lengkap}.</p>
           <p>Pendaftaran Anda telah diverifikasi. Silakan masuk memakai username <b>${p.username}</b>
           dan kata sandi yang Anda buat saat mendaftar.</p>`,
          { teks: "Masuk ke SIMKA PRO", url: `${appUrl()}/#/masuk` }));
      } else {
        await kirimEmail(p.email, "Pendaftaran SIMKA PRO belum dapat disetujui", templatEmail("Pendaftaran belum disetujui",
          `<p>${p.nama_lengkap}, pendaftaran Anda belum dapat disetujui dengan catatan:</p>
           <p style="background:#FFF4EC;padding:10px 14px;border-radius:8px">${b.catatan}</p>
           <p>Silakan hubungi admin pondok untuk keterangan lebih lanjut.</p>`));
      }
      await audit(admin, saya.id, "verifikasi_akun", `${b.keputusan === "aktif" ? "Mengaktifkan" : "Menolak"} akun ${p.nama_lengkap}`, { catatan: b.catatan }, "employees", p.id);
      return json({ ok: true, pesan: b.keputusan === "aktif" ? "Akun diaktifkan dan email aktivasi dikirim." : "Pendaftaran ditolak." ,
        pegawai: { nama: p.nama_lengkap, username: p.username, no_hp: p.no_hp } });
    }

    case "buat": {
      if (saya.peran !== "superadmin") throw new Galat("Hanya superadmin yang dapat membuatkan akun.", 403);
      const username = (b.username ?? "").trim().toLowerCase();
      const email = (b.email ?? "").trim().toLowerCase();
      if (!/^[a-z0-9._]{4,30}$/.test(username)) throw new Galat("Username 4–30 karakter: huruf kecil, angka, titik, garis bawah.");
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw new Galat("Alamat email tidak valid.");
      const { data: du } = await admin.from("employees").select("id").ilike("username", username).maybeSingle();
      if (du) throw new Galat("Username sudah dipakai.");
      const sandi = sandiSementara();
      const { data: u, error } = await admin.auth.admin.createUser({ email, password: sandi, email_confirm: true });
      if (error || !u.user) throw new Galat(/already/i.test(error?.message ?? "") ? "Email sudah terdaftar." : "Akun gagal dibuat.");

      let id = b.employee_id;
      if (id) {
        const p = await ambil(id);
        if (p.user_id) { await admin.auth.admin.deleteUser(u.user.id); throw new Galat("Pegawai ini sudah memiliki akun."); }
        await admin.from("employees").update({ user_id: u.user.id, username, email, status_akun: "aktif",
          wajib_ganti_sandi: true, diverifikasi_oleh: saya.id, diverifikasi_pada: new Date().toISOString() }).eq("id", id);
      } else {
        if (!b.nama_lengkap?.trim()) { await admin.auth.admin.deleteUser(u.user.id); throw new Galat("Nama lengkap wajib diisi."); }
        const { data: e, error: ee } = await admin.from("employees").insert({
          user_id: u.user.id, username, email, nama_lengkap: b.nama_lengkap.trim(), jenis_kelamin: b.jenis_kelamin ?? null,
          no_hp: b.no_hp || null, org_unit_id: b.org_unit_id ?? null, status_akun: "aktif", wajib_ganti_sandi: true,
          diverifikasi_oleh: saya.id, diverifikasi_pada: new Date().toISOString(),
        }).select("id").single();
        if (ee || !e) { await admin.auth.admin.deleteUser(u.user.id); throw new Galat("Data pegawai gagal disimpan."); }
        id = e.id;
      }
      await aturJabatan(admin, id!, b);
      await kirimEmail(email, "Akun SIMKA PRO Anda", templatEmail("Akun Anda telah dibuat",
        `<p>Akun SIMKA PRO Anda telah dibuat oleh superadmin.</p>
         <p>Username: <b>${username}</b><br>Kata sandi sementara: <b>${sandi}</b></p>
         <p>Anda wajib mengganti kata sandi saat masuk pertama kali.</p>`,
        { teks: "Masuk ke SIMKA PRO", url: `${appUrl()}/#/masuk` }));
      await audit(admin, saya.id, "buat_akun", `Membuatkan akun ${username}`, null, "employees", id);
      return json({ ok: true, employee_id: id, sandi_sementara: sandi, pesan: "Akun dibuat. Sampaikan sandi sementara kepada pegawai." });
    }

    case "reset_manual": {
      if (!(await bolehAdmin(admin, saya, "kelola_pegawai"))) throw new Galat("Anda tidak berwenang mereset kata sandi.", 403);
      const p = await ambil(b.employee_id);
      if (!p.user_id) throw new Galat("Pegawai ini belum memiliki akun.");
      if (p.peran === "superadmin" && saya.peran !== "superadmin") throw new Galat("Sandi superadmin tidak dapat direset admin.", 403);
      const sandi = sandiSementara();
      const { error } = await admin.auth.admin.updateUserById(p.user_id, { password: sandi });
      if (error) throw new Galat("Kata sandi gagal direset.");
      await admin.from("employees").update({ wajib_ganti_sandi: true }).eq("id", p.id);
      await audit(admin, saya.id, "reset_sandi_manual", `Mereset kata sandi ${p.nama_lengkap}`, null, "employees", p.id);
      return json({ ok: true, sandi_sementara: sandi, pegawai: { nama: p.nama_lengkap, username: p.username, no_hp: p.no_hp },
        pesan: "Kata sandi sementara dibuat. Pegawai wajib menggantinya saat masuk." });
    }

    case "ubah_peran": {
      if (saya.peran !== "superadmin") throw new Galat("Hanya superadmin yang dapat mengatur peran.", 403);
      const p = await ambil(b.employee_id);
      if (p.peran === "superadmin") throw new Galat("Peran superadmin tidak dapat diubah.");
      if (!["admin", "pegawai"].includes(b.peran ?? "")) throw new Galat("Peran tidak dikenal.");
      if (p.status_akun !== "aktif") throw new Galat("Hanya akun aktif yang dapat dijadikan admin.");
      await admin.from("employees").update({ peran: b.peran }).eq("id", p.id);
      await admin.from("admin_permissions").delete().eq("employee_id", p.id);
      if (b.peran === "admin" && b.izin?.length) {
        await admin.from("admin_permissions").insert(b.izin.map((kode) => ({ employee_id: p.id, kode })));
      }
      await admin.rpc("kirim_notifikasi", {
        p_employee: p.id, p_judul: b.peran === "admin" ? "Anda ditetapkan sebagai admin" : "Peran admin Anda dicabut",
        p_isi: b.peran === "admin" ? "Menu admin kini tersedia di akun Anda." : null, p_tautan: "/beranda",
        p_ikon: "ShieldCheck", p_warna: "mawar",
      });
      await audit(admin, saya.id, "ubah_peran", `Mengubah peran ${p.nama_lengkap} menjadi ${b.peran}`, { izin: b.izin }, "employees", p.id);
      return json({ ok: true, pesan: "Peran berhasil diperbarui." });
    }

    case "status_akun": {
      if (!(await bolehAdmin(admin, saya, "kelola_pegawai"))) throw new Galat("Anda tidak berwenang.", 403);
      const p = await ambil(b.employee_id);
      if (p.peran === "superadmin") throw new Galat("Akun superadmin tidak dapat dinonaktifkan.");
      if (!p.user_id) throw new Galat("Pegawai ini belum memiliki akun.");
      await admin.auth.admin.updateUserById(p.user_id, { ban_duration: b.aktif ? "none" : "876000h" });
      await admin.from("employees").update({ status_akun: b.aktif ? "aktif" : "nonaktif" }).eq("id", p.id);
      await audit(admin, saya.id, b.aktif ? "aktifkan_akun" : "nonaktifkan_akun", `${b.aktif ? "Mengaktifkan" : "Menonaktifkan"} akun ${p.nama_lengkap}`, null, "employees", p.id);
      return json({ ok: true, pesan: b.aktif ? "Akun diaktifkan kembali." : "Akun dinonaktifkan." });
    }
  }
  throw new Galat("Aksi tidak dikenal.");
});
