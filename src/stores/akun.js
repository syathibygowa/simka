// SIMKA PRO | src/stores/akun.js | v1.1 | Perbaikan: ganti sandi berulang terus-menerus | 05/10/2026
// Pendaftaran, verifikasi, kelola akun, peran admin, lupa sandi, dan ganti sandi.
// Semua aksi berwenang dijalankan oleh Edge Function (daftar, kelola-akun, reset-sandi).
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO, panggilFungsi } from '@/lib/supabase'
import { IZIN_ADMIN_DEMO } from '@/lib/demo'
import { usePegawai } from './pegawai'

const demo = (pesan, tambahan = {}) => new Promise((r) => setTimeout(() => r({ ok: true, pesan: `${pesan} (mode demo)`, ...tambahan }), 400))
async function fungsi(nama, isi) {
  const r = await panggilFungsi(nama, isi)
  if (!r.ok) throw new Error(r.pesan || r.galat || 'Permintaan gagal diproses.')
  return r
}

export const useAkun = defineStore('akun', {
  state: () => ({ izinTersedia: [], izinAdmin: {} }), // izinAdmin: { employee_id: [kode] }
  actions: {
    // ---------- Publik (tanpa login) ----------
    daftar(isi) { return MODE_DEMO ? demo('Pendaftaran terkirim, menunggu verifikasi admin.') : fungsi('daftar', isi) },
    mintaReset(username) { return MODE_DEMO ? demo('Bila username terdaftar, tautan atur ulang kata sandi telah dikirim ke email Anda.') : fungsi('reset-sandi', { aksi: 'minta', username }) },
    aturSandi(token, sandi) { return MODE_DEMO ? demo('Kata sandi berhasil diperbarui.') : fungsi('reset-sandi', { aksi: 'atur', token, sandi }) },

    // ---------- Pengguna masuk ----------
    async gantiSandi(sandi) {
      if (MODE_DEMO) return demo('Kata sandi diperbarui.')
      const { error } = await supabase.auth.updateUser({ password: sandi })
      if (error) throw new Error(/different/i.test(error.message) ? 'Kata sandi baru harus berbeda dari kata sandi lama.' : 'Kata sandi gagal diperbarui. Silakan coba lagi.')
      // Hapus penanda "wajib ganti sandi". Bila gagal, beri tahu pengguna (dulu galat ini diabaikan sehingga
      // pengguna diminta mengganti sandi terus-menerus setiap kali masuk).
      const { error: e2 } = await supabase.rpc('selesai_ganti_sandi')
      if (e2) throw new Error('Kata sandi baru sudah tersimpan, tetapi status akun gagal diperbarui. Coba simpan sekali lagi atau hubungi admin.')
      return { ok: true, pesan: 'Kata sandi diperbarui.' }
    },

    // ---------- Admin dan superadmin ----------
    async kelola(isi) {
      const peg = usePegawai()
      if (MODE_DEMO) {
        const p = peg.cari(isi.employee_id)
        const r = await demo('Perubahan disimpan', { sandi_sementara: 'Syathiby-7K2Q9M', pegawai: { nama: p?.nama_lengkap, username: p?.username || 'pegawai', no_hp: p?.no_hp } })
        if (p && isi.aksi === 'verifikasi') p.status_akun = isi.keputusan
        if (p && isi.aksi === 'status_akun') p.status_akun = isi.aktif ? 'aktif' : 'nonaktif'
        if (p && isi.aksi === 'buat') { p.status_akun = 'aktif'; p.username = isi.username; p.email = isi.email }
        if (p && isi.aksi === 'ubah_peran') { p.peran = isi.peran; this.izinAdmin[p.id] = isi.izin || [] }
        return r
      }
      const r = await fungsi('kelola-akun', isi)
      await peg.muat()
      if (isi.aksi === 'ubah_peran') await this.muatIzin()
      return r
    },

    async muatIzin() {
      if (MODE_DEMO) { this.izinTersedia = IZIN_ADMIN_DEMO; return }
      const [a, b] = await Promise.all([
        supabase.from('admin_capabilities').select('*').order('urutan'),
        supabase.from('admin_permissions').select('employee_id, kode'),
      ])
      this.izinTersedia = a.data || []
      const peta = {}; for (const r of b.data || []) (peta[r.employee_id] ||= []).push(r.kode)
      this.izinAdmin = peta
    },
  },
})
