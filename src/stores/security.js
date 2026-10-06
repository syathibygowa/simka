// SIMKA PRO | src/stores/security.js | v1.0 | Fase 7 – Tahap 1 Security: gerbang | 06/10/2026
// Security di gerbang (Blueprint Bagian 24): hak, ketentuan, cari santri (status hijau/merah), daftar gerbang hari ini,
// catat keluar/kembali/ditolak dengan foto opsional, izin cepat, riwayat, ringkasan beranda, dan pembaruan langsung.
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { pesanGalat } from './lembaga'
import { useSesi } from './sesi'
import { useSantri } from './santri'
import { useIzin } from './izin'
import { dataKelompokDemo } from '@/lib/demoKelompok'
import { hariIniISO } from '@/lib/tanggal'

const rpc = async (nama, arg) => { const { data, error } = await supabase.rpc(nama, arg); if (error) throw new Error(pesanGalat(error)); return data }
const HAK_KOSONG = { gerbang: false, kelola: false, lihat: false, izin_cepat: false, puncak: false }
const tglWita = (iso) => new Date(new Date(iso).getTime() + 8 * 3600000).toISOString().slice(0, 10)

// ---------- Mode demo ----------
const LOG_DEMO = []
async function demoSantri() {
  const san = useSantri(); await san.muat(); const kel = dataKelompokDemo(san.daftar)
  const nama = (id, j) => kel.anggota.filter((a) => a.student_id === id && !a.selesai).map((a) => kel.kelompok.find((g) => g.id === a.group_id)).filter((g) => g?.jenis === j).map((g) => g.nama).join(', ') || null
  const izin = await useIzin().daftar('semua')
  return { san, nama, izin }
}
function statusDemo(id, izin, awal) {
  const now = Date.now(); const milik = izin.filter((x) => x.student_id === id)
  const luar = milik.find((x) => x.status === 'keluar')
  if (luar) return { s: now > new Date(luar.kembali_batas) ? { kode: 'terlambat', warna: 'merah', label: 'Terlambat kembali' } : { kode: 'di_luar', warna: 'biru', label: 'Sedang di luar pondok' }, p: luar }
  const ok = milik.filter((x) => x.status === 'disetujui' && new Date(x.kembali_batas) > now).sort((a, b) => a.keluar_pada.localeCompare(b.keluar_pada))[0]
  if (ok) return now >= new Date(ok.keluar_pada) - awal * 60000 ? { s: { kode: 'boleh', warna: 'hijau', label: 'Izin disetujui dan berlaku' }, p: ok } : { s: { kode: 'belum_waktunya', warna: 'merah', label: 'Izin belum berlaku' }, p: ok }
  const tunggu = milik.find((x) => ['diajukan', 'disetujui_bidang'].includes(x.status))
  if (tunggu) return { s: { kode: 'menunggu', warna: 'merah', label: 'Izin belum disetujui' }, p: tunggu }
  return { s: { kode: 'tidak_ada', warna: 'merah', label: 'Tidak ada izin' }, p: null }
}

export const useSecurity = defineStore('security', {
  state: () => ({ hak: { ...HAK_KOSONG }, hakDimuat: false, pengaturan: { toleransi_terlambat_menit: 0, keluar_lebih_awal_menit: 120 }, beranda: null, saluran: null, saluranBeranda: null }),
  actions: {
    async muatHak() {
      if (MODE_DEMO) {
        const p = useSesi().peran
        this.hak = p === 'superadmin' ? { gerbang: true, kelola: true, lihat: true, izin_cepat: true, puncak: true }
          : p === 'admin' ? { ...HAK_KOSONG, gerbang: true, kelola: true, lihat: true } : { ...HAK_KOSONG }
      } else this.hak = { ...HAK_KOSONG, ...((await rpc('hak_security')) || {}) }
      this.hakDimuat = true
      try { if (!MODE_DEMO) this.pengaturan = await rpc('pengaturan_security') } catch { /* bawaan */ }
      return this.hak
    },
    async simpanPengaturan(isi) {
      if (MODE_DEMO) { this.pengaturan = { ...this.pengaturan, ...isi }; return }
      this.pengaturan = await rpc('simpan_pengaturan_security', { p: isi })
    },

    /** Santri dalam bentuk gerbang (demo). */
    async _demoJson(id, d) {
      d = d || await demoSantri(); const s = d.san.cari(id); if (!s) return null
      const st = statusDemo(id, d.izin, this.pengaturan.keluar_lebih_awal_menit)
      return { student_id: s.id, nama: s.nama_lengkap, nis: s.nis, jenis_kelamin: s.jenis_kelamin, jenjang: s.jenjang, kelas: d.nama(id, 'kelas'), kamar: d.nama(id, 'kamar'),
        status: { ...st.s, permit_id: st.p?.id || null }, izin: st.p ? { ...st.p, disetujui_oleh: (st.p.keputusan || []).filter((k) => k.keputusan === 'setuju').map((k) => `${k.oleh} (${k.sebagai})`).join(', ') } : null }
    },

    async cari(q) {
      if (!MODE_DEMO) return (await rpc('cari_santri_gerbang', { p_q: q, p_batas: 30 })) || []
      const kata = q.toLowerCase().trim().split(/\s+/).filter(Boolean); if (!kata.length || kata.join('').length < 2) return []
      const d = await demoSantri()
      const cocok = d.san.daftar.filter((s) => s.status === 'aktif').filter((s) => { const t = `${s.nama_lengkap} ${s.nis} ${d.nama(s.id, 'kelas') || ''} ${d.nama(s.id, 'kamar') || ''}`.toLowerCase(); return kata.every((k) => t.includes(k)) })
      return Promise.all(cocok.slice(0, 30).map((s) => this._demoJson(s.id, d)))
    },
    async satu(id) { return MODE_DEMO ? this._demoJson(id) : rpc('santri_gerbang', { p_santri: id }) },

    async daftar() {
      if (!MODE_DEMO) return rpc('daftar_gerbang')
      const d = await demoSantri(); const id = [...new Set(d.izin.map((x) => x.student_id))]
      const semua = (await Promise.all(id.map((x) => this._demoJson(x, d)))).filter(Boolean)
      const hari = hariIniISO()
      return { siap: semua.filter((s) => s.status.kode === 'boleh' || (s.status.kode === 'belum_waktunya' && tglWita(s.izin.keluar_pada) <= hari)),
        di_luar: semua.filter((s) => ['di_luar', 'terlambat'].includes(s.status.kode)), log_hari_ini: LOG_DEMO.filter((l) => tglWita(l.waktu) === hari) }
    },
    async riwayat(mulai, selesai, jenis = '') {
      if (!MODE_DEMO) return (await rpc('riwayat_gerbang', { p_mulai: mulai, p_selesai: selesai, p_jenis: jenis || null })) || []
      return LOG_DEMO.filter((l) => tglWita(l.waktu) >= mulai && tglWita(l.waktu) <= selesai && (!jenis || l.jenis === jenis))
    },

    /** isi: { aksi, permit_id?, student_id?, foto_id?, penjemput?, catatan? } */
    async catat(isi) {
      if (!MODE_DEMO) return rpc('catat_gerbang', { p: isi })
      const iz = useIzin(); const d = await demoSantri(); const sid = isi.student_id || d.izin.find((x) => x.id === isi.permit_id)?.student_id
      const s = await this._demoJson(sid, d); const now = new Date().toISOString(); let menit = null
      if (isi.aksi === 'keluar') { if (s.status.kode !== 'boleh') throw new Error(`${s.nama} tidak dapat keluar: ${s.status.label.toLowerCase()}.`); await iz.catat(s.status.permit_id, 'keluar') }
      else if (isi.aksi === 'kembali') {
        if (!['di_luar', 'terlambat'].includes(s.status.kode)) throw new Error(`${s.nama} tidak tercatat sedang di luar pondok.`)
        menit = s.status.kode === 'terlambat' ? Math.floor((Date.now() - new Date(s.izin.kembali_batas)) / 60000) : null; await iz.catat(s.status.permit_id, 'kembali')
      } else if ((isi.catatan || '').trim().length < 5) throw new Error('Tuliskan alasan/keterangan penolakan (minimal 5 huruf).')
      LOG_DEMO.unshift({ id: 'gl' + Date.now(), jenis: isi.aksi, waktu: now, student_id: sid, nama: s.nama, nis: s.nis, kelas: s.kelas, kamar: s.kamar, jenis_kelamin: s.jenis_kelamin,
        petugas: useSesi().pengguna?.nama_lengkap, penjemput: isi.penjemput || s.izin?.penjemput || null, catatan: isi.catatan || null, terlambat_menit: menit, foto_id: null,
        alasan_izin: s.izin?.alasan || null, kembali_batas: s.izin?.kembali_batas || null, jenis_izin: s.izin?.jenis || null })
      return this._demoJson(sid)
    },
    async izinCepat(isi) {
      if (!MODE_DEMO) return rpc('izin_cepat', { p: isi })
      const iz = useIzin(); await iz.ajukan({ ...isi, peran: 'admin', keluar_pada: isi.keluar_pada || new Date().toISOString() })
      const d = await iz.daftar('menunggu'); const x = d.find((y) => y.student_id === isi.student_id); if (x) await iz.putuskan(x.id, 'setuju', 'Izin cepat')
      return this._demoJson(isi.student_id)
    },

    async muatBeranda() {
      try {
        if (!MODE_DEMO) { this.beranda = await rpc('ringkasan_security_beranda'); return }
        if (useSesi().peran === 'pegawai') { this.beranda = null; return }
        const d = await this.daftar(); const hari = d.log_hari_ini
        this.beranda = { petugas: true, siap: d.siap.length, di_luar: d.di_luar.length, terlambat: d.di_luar.filter((s) => s.status.kode === 'terlambat').length,
          keluar_hari_ini: hari.filter((l) => l.jenis === 'keluar').length, kembali_hari_ini: hari.filter((l) => l.jenis === 'kembali').length, ditolak_hari_ini: hari.filter((l) => l.jenis === 'ditolak').length }
      } catch { this.beranda = null }
    },
    dengarkanBeranda() {
      if (MODE_DEMO || this.saluranBeranda) return
      const muat = () => this.muatBeranda()
      this.saluranBeranda = supabase.channel('security-beranda')
        .on('postgres_changes', { event: '*', schema: 'public', table: 'student_permits' }, muat)
        .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'gate_logs' }, muat).subscribe()
    },
    dengarkan(fn) {
      if (MODE_DEMO || this.saluran) return
      this.saluran = supabase.channel('security-gerbang')
        .on('postgres_changes', { event: '*', schema: 'public', table: 'student_permits' }, () => fn())
        .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'gate_logs' }, () => fn()).subscribe()
    },
    berhenti() { if (this.saluran) { supabase.removeChannel(this.saluran); this.saluran = null } },
  },
})
