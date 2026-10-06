// SIMKA PRO | src/stores/security.js | v1.2 | Fase 7 – Tahap 5 Penutup fase | 06/10/2026
// Security di gerbang (Blueprint Bagian 24): hak, ketentuan, cari santri (status hijau/merah), daftar gerbang hari ini,
// catat keluar/kembali/ditolak dengan foto opsional, izin cepat, riwayat, titipan (foto terima dan ambil wajib), buku tamu,
// kunjungan orang tua, ringkasan beranda, dan pembaruan langsung.
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { pesanGalat } from './lembaga'
import { useSesi } from './sesi'
import { useSantri } from './santri'
import { useIzin } from './izin'
import { dataKelompokDemo } from '@/lib/demoKelompok'
import { hariIniISO } from '@/lib/tanggal'

const rpc = async (nama, arg) => { const { data, error } = await supabase.rpc(nama, arg); if (error) throw new Error(pesanGalat(error)); return data }
const HAK_KOSONG = { gerbang: false, kelola: false, lihat: false, izin_cepat: false, puncak: false, pengasuh: false }
const tglWita = (iso) => new Date(new Date(iso).getTime() + 8 * 3600000).toISOString().slice(0, 10)

// ---------- Mode demo ----------
const LOG_DEMO = []
const TITIPAN_DEMO = []; const TAMU_DEMO = []; const KUNJUNGAN_DEMO = []
const jamLalu = (j) => new Date(Date.now() - j * 3600000).toISOString()
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
  state: () => ({ hak: { ...HAK_KOSONG }, hakDimuat: false, pengaturan: { toleransi_terlambat_menit: 0, keluar_lebih_awal_menit: 120, pengingat_titipan_hari: 2, jadwal_kunjungan_aktif: false, hari_kunjungan: [0, 6], jam_kunjungan_mulai: '08:00', jam_kunjungan_selesai: '17:00' }, beranda: null, saluran: null, saluranBeranda: null }),
  actions: {
    async muatHak() {
      if (MODE_DEMO) {
        const p = useSesi().peran
        this.hak = p === 'superadmin' ? { gerbang: true, kelola: true, lihat: true, izin_cepat: true, puncak: true, pengasuh: false }
          : p === 'admin' ? { ...HAK_KOSONG, gerbang: true, kelola: true, lihat: true } : { ...HAK_KOSONG, pengasuh: true }
        await this._isiDemo()
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

    // ---------- Data demo titipan/tamu/kunjungan ----------
    async _isiDemo() {
      if (TITIPAN_DEMO.length) return
      const d = await demoSantri(); const s = d.san.daftar.filter((x) => x.status === 'aktif')
      const info = (x) => ({ student_id: x.id, nama: x.nama_lengkap, nis: x.nis, jenis_kelamin: x.jenis_kelamin, kelas: d.nama(x.id, 'kelas'), kamar: d.nama(x.id, 'kamar') })
      if (s[2]) TITIPAN_DEMO.push({ id: 'tp1', ...info(s[2]), jenis: 'paket', uraian: 'Kardus berisi makanan ringan dan buku', nominal: null, pengirim: 'Ibu Hasanah', hp_pengirim: '081234567890', ekspedisi: 'JNE',
        status: 'di_pos', diterima_pada: jamLalu(5), penerima: 'Satpam Andi', foto_terima_id: null, diambil_pada: null, pengambil_jenis: null, pengambil_nama: null, penyerah: null, foto_ambil_id: null, catatan: null, lama_jam: 5 })
      if (s[4]) TITIPAN_DEMO.push({ id: 'tp2', ...info(s[4]), jenis: 'uang', uraian: 'Uang saku bulan Oktober', nominal: 250000, pengirim: 'Bapak Ridwan', hp_pengirim: null, ekspedisi: null,
        status: 'di_pos', diterima_pada: jamLalu(60), penerima: 'Satpam Andi', foto_terima_id: null, diambil_pada: null, pengambil_jenis: null, pengambil_nama: null, penyerah: null, foto_ambil_id: null, catatan: null, lama_jam: 60 })
      if (s[1]) TITIPAN_DEMO.push({ id: 'tp3', ...info(s[1]), jenis: 'pakaian', uraian: 'Dua stel pakaian dan sarung', nominal: null, pengirim: 'Ibu Aminah', hp_pengirim: null, ekspedisi: 'Diantar langsung',
        status: 'diambil', diterima_pada: jamLalu(28), penerima: 'Satpam Andi', foto_terima_id: null, diambil_pada: jamLalu(26), pengambil_jenis: 'santri', pengambil_nama: s[1].nama_lengkap, penyerah: 'Satpam Budi', foto_ambil_id: null, catatan: null, lama_jam: 2 })
      TAMU_DEMO.push({ id: 'tm1', nama: 'Drs. H. Abdul Rahman', instansi: 'Kemenag Kab. Gowa', hp: '081355500011', keperluan: 'Monitoring pendidikan pesantren', ditemui_id: null, ditemui: 'Direktur (Mudir)',
        jumlah_orang: 2, kendaraan: 'DD 1234 AB', masuk_pada: jamLalu(1), keluar_pada: null, foto_id: null, catatan: null, petugas_masuk: 'Satpam Andi', petugas_keluar: null })
      TAMU_DEMO.push({ id: 'tm2', nama: 'Kurir JNT', instansi: 'J&T Express', hp: null, keperluan: 'Mengantar paket', ditemui_id: null, ditemui: 'Pos Security',
        jumlah_orang: 1, kendaraan: null, masuk_pada: jamLalu(4), keluar_pada: jamLalu(3.9), foto_id: null, catatan: null, petugas_masuk: 'Satpam Andi', petugas_keluar: 'Satpam Andi' })
      if (s[3]) KUNJUNGAN_DEMO.push({ id: 'kj1', ...info(s[3]), pengunjung: 'Bapak Syamsuddin', hubungan: 'Ayah', hp: '085255500022', jumlah_orang: 3, datang_pada: jamLalu(0.5), pulang_pada: null,
        luar_jadwal: false, foto_id: null, catatan: null, petugas_datang: 'Satpam Andi', petugas_pulang: null })
    },
    _rentang(daftar, kolom, cakupan, mulai, selesai, aktif) {
      return daftar.filter((x) => (cakupan === aktif.k ? aktif.f(x) : tglWita(x[kolom]) >= mulai && tglWita(x[kolom]) <= selesai))
    },

    // ---------- Titipan ----------
    async daftarTitipan(cakupan, mulai, selesai) {
      if (!MODE_DEMO) return (await rpc('daftar_titipan', { p_cakupan: cakupan, p_mulai: mulai || null, p_selesai: selesai || null })) || []
      await this._isiDemo(); return this._rentang(TITIPAN_DEMO, 'diterima_pada', cakupan, mulai, selesai, { k: 'di_pos', f: (x) => x.status === 'di_pos' })
    },
    async terimaTitipan(isi) {
      if (!MODE_DEMO) return rpc('terima_titipan', { p: isi })
      const s = await this._demoJson(isi.student_id)
      const x = { id: 'tp' + Date.now(), student_id: s.student_id, nama: s.nama, nis: s.nis, jenis_kelamin: s.jenis_kelamin, kelas: s.kelas, kamar: s.kamar, ...isi, status: 'di_pos', diterima_pada: new Date().toISOString(),
        penerima: useSesi().pengguna?.nama_lengkap, diambil_pada: null, pengambil_jenis: null, pengambil_nama: null, penyerah: null, foto_ambil_id: null, lama_jam: 0 }
      TITIPAN_DEMO.unshift(x); return x
    },
    async ambilTitipan(id, isi) {
      if (!MODE_DEMO) return rpc('ambil_titipan', { p_id: id, p: isi })
      const x = TITIPAN_DEMO.find((t) => t.id === id); Object.assign(x, { ...isi, status: 'diambil', diambil_pada: new Date().toISOString(), penyerah: useSesi().pengguna?.nama_lengkap }); return x
    },
    async tutupTitipan(id, status, alasan, foto = null) {
      if (!MODE_DEMO) return rpc('tutup_titipan', { p_id: id, p_status: status, p_alasan: alasan, p_foto: foto })
      const x = TITIPAN_DEMO.find((t) => t.id === id); Object.assign(x, { status, diambil_pada: new Date().toISOString(), catatan: alasan, pengambil_nama: status === 'dikembalikan' ? x.pengirim : null }); return x
    },

    // ---------- Buku tamu ----------
    async daftarTamu(cakupan, mulai, selesai) {
      if (!MODE_DEMO) return (await rpc('daftar_tamu', { p_cakupan: cakupan, p_mulai: mulai || null, p_selesai: selesai || null })) || []
      await this._isiDemo(); return this._rentang(TAMU_DEMO, 'masuk_pada', cakupan, mulai, selesai, { k: 'di_dalam', f: (x) => !x.keluar_pada })
    },
    async cariPegawai(q) {
      if (!MODE_DEMO) return (await rpc('pegawai_tujuan_tamu', { p_q: q })) || []
      return [{ id: 'p-dir', nama: 'Siswandi Safari, S.Pd.I., Lc., S.H., M.Ag.', jabatan: 'Direktur (Mudir)' }, { id: 'p-kes', nama: 'Ust. Muhammad Ikhsan, S.Pd.I.', jabatan: 'Kepala Bidang Kesantrian' },
        { id: 'p1', nama: 'Hasan Basri, S.Pd.', jabatan: 'Guru mapel, Wali kelas' }].filter((p) => p.nama.toLowerCase().includes(q.toLowerCase()))
    },
    async tamuMasuk(isi) {
      if (!MODE_DEMO) return rpc('tamu_masuk', { p: isi })
      const x = { id: 'tm' + Date.now(), ...isi, ditemui: isi.ditemui_nama || isi.ditemui_teks, masuk_pada: new Date().toISOString(), keluar_pada: null, petugas_masuk: useSesi().pengguna?.nama_lengkap, petugas_keluar: null }
      TAMU_DEMO.unshift(x); return x
    },
    async tamuKeluar(id) {
      if (!MODE_DEMO) return rpc('tamu_keluar', { p_id: id })
      const x = TAMU_DEMO.find((t) => t.id === id); Object.assign(x, { keluar_pada: new Date().toISOString(), petugas_keluar: useSesi().pengguna?.nama_lengkap }); return x
    },

    // ---------- Kunjungan ----------
    async daftarKunjungan(cakupan, mulai, selesai) {
      if (!MODE_DEMO) return (await rpc('daftar_kunjungan', { p_cakupan: cakupan, p_mulai: mulai || null, p_selesai: selesai || null })) || []
      await this._isiDemo(); return this._rentang(KUNJUNGAN_DEMO, 'datang_pada', cakupan, mulai, selesai, { k: 'berlangsung', f: (x) => !x.pulang_pada })
    },
    async kunjunganDatang(isi) {
      if (!MODE_DEMO) return rpc('kunjungan_datang', { p: isi })
      if (KUNJUNGAN_DEMO.some((k) => k.student_id === isi.student_id && !k.pulang_pada)) throw new Error('Santri ini masih tercatat sedang dikunjungi.')
      const s = await this._demoJson(isi.student_id)
      const x = { id: 'kj' + Date.now(), student_id: s.student_id, nama: s.nama, nis: s.nis, jenis_kelamin: s.jenis_kelamin, kelas: s.kelas, kamar: s.kamar, ...isi, datang_pada: new Date().toISOString(), pulang_pada: null,
        luar_jadwal: false, petugas_datang: useSesi().pengguna?.nama_lengkap, petugas_pulang: null }
      KUNJUNGAN_DEMO.unshift(x); return x
    },
    async kunjunganPulang(id) {
      if (!MODE_DEMO) return rpc('kunjungan_pulang', { p_id: id })
      const x = KUNJUNGAN_DEMO.find((t) => t.id === id); Object.assign(x, { pulang_pada: new Date().toISOString(), petugas_pulang: useSesi().pengguna?.nama_lengkap }); return x
    },

    /** Riwayat Security satu santri untuk profil santri terpadu. */
    async riwayatSantri(id) {
      if (!MODE_DEMO) return rpc('riwayat_security_santri', { p_santri: id })
      await this._isiDemo()
      return { gerbang: LOG_DEMO.filter((l) => l.student_id === id), titipan: TITIPAN_DEMO.filter((t) => t.student_id === id), kunjungan: KUNJUNGAN_DEMO.filter((k) => k.student_id === id),
        libur: [], ringkasan: { keluar: LOG_DEMO.filter((l) => l.student_id === id && l.jenis === 'keluar').length, terlambat: 0, ditolak: 0, titipan_di_pos: TITIPAN_DEMO.filter((t) => t.student_id === id && t.status === 'di_pos').length } }
    },

    async muatBeranda() {
      try {
        if (!MODE_DEMO) { this.beranda = await rpc('ringkasan_security_beranda'); return }
        if (useSesi().peran === 'pegawai') { this.beranda = null; return }
        const d = await this.daftar(); const hari = d.log_hari_ini
        this.beranda = { petugas: true, siap: d.siap.length, di_luar: d.di_luar.length, terlambat: d.di_luar.filter((s) => s.status.kode === 'terlambat').length,
          keluar_hari_ini: hari.filter((l) => l.jenis === 'keluar').length, kembali_hari_ini: hari.filter((l) => l.jenis === 'kembali').length, ditolak_hari_ini: hari.filter((l) => l.jenis === 'ditolak').length }
        await this._isiDemo(); const h = hariIniISO()
        Object.assign(this.beranda, { titipan_di_pos: TITIPAN_DEMO.filter((t) => t.status === 'di_pos').length, titipan_lama: TITIPAN_DEMO.filter((t) => t.status === 'di_pos' && t.lama_jam >= 48).length,
          titipan_hari_ini: TITIPAN_DEMO.filter((t) => tglWita(t.diterima_pada) === h).length, diambil_hari_ini: TITIPAN_DEMO.filter((t) => t.diambil_pada && tglWita(t.diambil_pada) === h).length,
          tamu_di_dalam: TAMU_DEMO.filter((t) => !t.keluar_pada).length, tamu_hari_ini: TAMU_DEMO.filter((t) => tglWita(t.masuk_pada) === h).length,
          kunjungan_berlangsung: KUNJUNGAN_DEMO.filter((k) => !k.pulang_pada).length, kunjungan_hari_ini: KUNJUNGAN_DEMO.filter((k) => tglWita(k.datang_pada) === h).length })
      } catch { this.beranda = null }
    },
    dengarkanBeranda() {
      if (MODE_DEMO || this.saluranBeranda) return
      const muat = () => this.muatBeranda()
      this.saluranBeranda = supabase.channel('security-beranda')
        .on('postgres_changes', { event: '*', schema: 'public', table: 'student_permits' }, muat)
        .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'gate_logs' }, muat)
        .on('postgres_changes', { event: '*', schema: 'public', table: 'parcels' }, muat)
        .on('postgres_changes', { event: '*', schema: 'public', table: 'guest_logs' }, muat)
        .on('postgres_changes', { event: '*', schema: 'public', table: 'parent_visits' }, muat).subscribe()
    },
    dengarkan(fn) {
      if (MODE_DEMO || this.saluran) return
      this.saluran = supabase.channel('security-gerbang')
        .on('postgres_changes', { event: '*', schema: 'public', table: 'parcels' }, () => fn())
        .on('postgres_changes', { event: '*', schema: 'public', table: 'guest_logs' }, () => fn())
        .on('postgres_changes', { event: '*', schema: 'public', table: 'parent_visits' }, () => fn())
        .on('postgres_changes', { event: '*', schema: 'public', table: 'student_permits' }, () => fn())
        .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'gate_logs' }, () => fn()).subscribe()
    },
    berhenti() { if (this.saluran) { supabase.removeChannel(this.saluran); this.saluran = null } },
  },
})
