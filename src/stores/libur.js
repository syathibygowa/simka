// SIMKA PRO | src/stores/libur.js | v1.0 | Fase 7 – Tahap 3 Libur santri | 06/10/2026
// Penentuan libur santri (Blueprint Bagian 23): hak, syarat bawaan, periode, penilaian otomatis, ubah keputusan
// beralasan, pengesahan (izin libur otomatis ke gerbang), pembatalan, detail per santri. Mode demo memakai data tiruan.
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { pesanGalat } from './lembaga'
import { useSesi } from './sesi'
import { useSantri } from './santri'
import { dataKelompokDemo } from '@/lib/demoKelompok'
import { hariIniISO } from '@/lib/tanggal'

const rpc = async (nama, arg) => { const { data, error } = await supabase.rpc(nama, arg); if (error) throw new Error(pesanGalat(error)); return data }
const SYARAT_BAWAAN = { kelas_min: 85, halaqah_min: 85, asrama_min: 85, izin_maks: 2, terlambat_maks: null, hafalan_min_halaman: 0, margin: 5, abaikan_izin_sakit: true }

// ---------- Mode demo ----------
const PERIODE_DEMO = []; const HASIL_DEMO = {}
const ringkas = (id) => { const d = HASIL_DEMO[id] || []; return { jumlah: d.length, boleh: d.filter((x) => x.keputusan === 'boleh').length, tidak: d.filter((x) => x.keputusan === 'tidak').length,
  belum: d.filter((x) => !x.keputusan).length, pertimbangan: d.filter((x) => x.otomatis === 'pertimbangan').length, diubah: d.filter((x) => x.diubah).length, izin_dibuat: d.filter((x) => x.permit_id).length } }
async function nilaiDemo(h) {
  const san = useSantri(); await san.muat(); const kel = dataKelompokDemo(san.daftar)
  const nama = (id, j) => kel.anggota.filter((a) => a.student_id === id && !a.selesai).map((a) => kel.kelompok.find((g) => g.id === a.group_id)).filter((g) => g?.jenis === j).map((g) => g.nama).join(', ') || null
  const sy = h.syarat; const lama = HASIL_DEMO[h.id] || []
  HASIL_DEMO[h.id] = san.daftar.filter((s) => s.status === 'aktif' && (!h.jenjang.length || h.jenjang.includes(s.jenjang)) && (!h.jenis_kelamin || s.jenis_kelamin === h.jenis_kelamin)).map((s, i) => {
    const angka = (b) => Math.max(55, 100 - ((i * b) % 37)); const keg = { kelas: angka(7), halaqah: angka(11), asrama: angka(5) }
    const gagal = []; const timbang = []
    for (const k of ['kelas', 'halaqah', 'asrama']) {
      const min = sy[k + '_min']; if (min == null) continue
      if (keg[k] < min) (keg[k] >= min - sy.margin ? timbang : gagal).push(`${k[0].toUpperCase() + k.slice(1)} ${keg[k]}% (min ${min}%)`)
    }
    const izin = i % 4; if (sy.izin_maks != null && izin > sy.izin_maks) (izin === sy.izin_maks + 1 ? timbang : gagal).push(`Izin keluar ${izin} kali (maks ${sy.izin_maks})`)
    const otomatis = gagal.length ? 'tidak' : timbang.length ? 'pertimbangan' : 'boleh'
    const lalu = lama.find((x) => x.student_id === s.id)
    return { id: `${h.id}-${s.id}`, student_id: s.id, nama: s.nama_lengkap, nis: s.nis, jenis_kelamin: s.jenis_kelamin, jenjang: s.jenjang, kelas: nama(s.id, 'kelas'), kamar: nama(s.id, 'kamar'), halaqah: nama(s.id, 'halaqah'),
      otomatis, keputusan: lalu?.diubah ? lalu.keputusan : otomatis === 'pertimbangan' ? null : otomatis, diubah: !!lalu?.diubah, alasan_ubah: lalu?.alasan_ubah || null, pengubah: lalu?.pengubah || null,
      rincian: { kelas: { sesi: 40, persen: keg.kelas }, halaqah: { sesi: 52, persen: keg.halaqah }, asrama: { sesi: 60, persen: keg.asrama }, izin, terlambat: i % 5 === 0 ? 1 : 0, hafalan: 6 + (i % 9), gagal, timbang },
      permit_id: null, status_izin: null, wali: { nama: 'Orang tua ' + s.nama_lengkap.split(' ')[0], no_hp: '081234567890' } }
  })
}
function isiDemo() {
  if (PERIODE_DEMO.length) return
  const t = new Date(); const besok = new Date(t.getTime() + 2 * 86400000)
  const iso = (d, j) => `${d.toISOString().slice(0, 10)}T${j}:00+08:00`
  PERIODE_DEMO.push({ id: 'lb1', nama: 'Libur Bulanan Oktober 2026', jenis: 'bulanan', pulang_pada: iso(besok, '08:00'), kembali_batas: iso(new Date(besok.getTime() + 2 * 86400000), '17:00'),
    hitung_mulai: hariIniISO().slice(0, 8) + '01', hitung_selesai: hariIniISO(), jenjang: [], jenis_kelamin: null, syarat: { ...SYARAT_BAWAAN }, status: 'draf', catatan: null, pembuat: 'Superadmin SIMKA', pengesah: null })
}

export const useLibur = defineStore('libur', {
  state: () => ({ hak: { kelola: false, sahkan: false, lihat: false, pengasuh: false }, hakDimuat: false, syarat: { ...SYARAT_BAWAAN } }),
  actions: {
    async muatHak() {
      if (MODE_DEMO) {
        const p = useSesi().peran
        this.hak = p === 'pegawai' ? { kelola: false, sahkan: false, lihat: false, pengasuh: true } : { kelola: true, sahkan: p === 'superadmin', lihat: true, pengasuh: false }
        isiDemo()
      } else {
        this.hak = { ...this.hak, ...((await rpc('hak_libur')) || {}) }
        try { this.syarat = await rpc('syarat_libur_bawaan') } catch { /* bawaan */ }
      }
      this.hakDimuat = true
    },
    async simpanSyarat(isi) { if (MODE_DEMO) { this.syarat = { ...this.syarat, ...isi }; return } this.syarat = await rpc('simpan_syarat_libur', { p: isi }) },
    async daftar() {
      if (!MODE_DEMO) return (await rpc('daftar_periode_libur')) || []
      isiDemo(); return PERIODE_DEMO.map((h) => ({ ...h, ringkasan: ringkas(h.id), selesai: h.status === 'disahkan' && new Date(h.kembali_batas) < new Date() }))
    },
    async detail(id) {
      if (!MODE_DEMO) return rpc('detail_libur', { p_id: id })
      const h = PERIODE_DEMO.find((x) => x.id === id); return { ...h, ringkasan: ringkas(id), santri: HASIL_DEMO[id] || [] }
    },
    async simpanPeriode(isi) {
      if (!MODE_DEMO) return rpc('simpan_periode_libur', { p: isi })
      if (isi.id) { Object.assign(PERIODE_DEMO.find((x) => x.id === isi.id), isi, { status: 'draf' }); return isi.id }
      const id = 'lb' + Date.now(); PERIODE_DEMO.unshift({ ...isi, id, status: 'draf', pembuat: useSesi().pengguna?.nama_lengkap }); return id
    },
    async nilai(id) {
      if (!MODE_DEMO) return rpc('nilai_libur', { p_id: id })
      const h = PERIODE_DEMO.find((x) => x.id === id); await nilaiDemo(h); h.status = 'dinilai'; return ringkas(id)
    },
    async ubah(idHasil, keputusan, alasan) {
      if (!MODE_DEMO) return rpc('ubah_keputusan_libur', { p_id: idHasil, p_keputusan: keputusan, p_alasan: alasan })
      for (const [pid, d] of Object.entries(HASIL_DEMO)) {
        const x = d.find((y) => y.id === idHasil); if (!x) continue
        if ((keputusan !== x.otomatis || x.diubah) && (alasan || '').trim().length < 5) throw new Error('Tuliskan alasan perubahan keputusan (minimal 5 huruf).')
        Object.assign(x, { keputusan, diubah: keputusan !== x.otomatis || x.otomatis === 'pertimbangan', alasan_ubah: alasan, pengubah: useSesi().pengguna?.nama_lengkap })
        if (PERIODE_DEMO.find((h) => h.id === pid)?.status === 'disahkan') x.permit_id = keputusan === 'boleh' ? 'izin-' + x.id : null
        return ringkas(pid)
      }
    },
    async sahkan(id) {
      if (!MODE_DEMO) return rpc('sahkan_libur', { p_id: id })
      const r = ringkas(id); if (r.belum) throw new Error(`Masih ada ${r.belum} santri berstatus perlu pertimbangan yang belum diputuskan.`)
      const h = PERIODE_DEMO.find((x) => x.id === id); Object.assign(h, { status: 'disahkan', pengesah: useSesi().pengguna?.nama_lengkap, disahkan_pada: new Date().toISOString() })
      for (const x of HASIL_DEMO[id]) if (x.keputusan === 'boleh') { x.permit_id = 'izin-' + x.id; x.status_izin = 'disetujui' }
      return ringkas(id)
    },
    async batalkan(id, alasan) {
      if (!MODE_DEMO) return rpc('batalkan_libur', { p_id: id, p_alasan: alasan })
      if ((alasan || '').trim().length < 5) throw new Error('Tuliskan alasan pembatalan (minimal 5 huruf).')
      PERIODE_DEMO.find((x) => x.id === id).status = 'batal'
    },
  },
})
