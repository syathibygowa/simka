// SIMKA PRO | src/lib/keuangan.js | v1.1 | Fase 13 – Pelengkap: siklus semesteran, kamar/halaqah, WA tagihan baru dan pengingat | 11/10/2026
// Konstanta tampilan, pengelompokan laporan, dan isian pesan WA keuangan santri.
import { BULAN, formatPanjang, formatPendek } from '@/lib/tanggal'
import { rupiah, angka, terbilang, bacaRupiah } from '@/lib/gaji'
import { pesanWA } from '@/lib/wa'
import { alamatCek } from '@/lib/dokumen'

export { rupiah, angka, terbilang, bacaRupiah }

export const SIKLUS = {
  bulanan: { n: 'Bulanan', w: 'agenda', ket: 'Ditagih setiap bulan (mis. SPP, makan, asrama)' },
  semesteran: { n: 'Semesteran', w: 'shift', ket: 'Ditagih setiap semester ganjil/genap (mis. ujian, kitab per semester)' },
  tahunan: { n: 'Tahunan', w: 'santri', ket: 'Ditagih sekali setiap tahun ajaran (mis. daftar ulang)' },
  sekali: { n: 'Sekali', w: 'pengajuan', ket: 'Ditagih satu kali (mis. uang pangkal, seragam)' },
}
export const STATUS_TAGIHAN = {
  belum: { n: 'Belum bayar', w: 'klinik' },
  sebagian: { n: 'Sebagian', w: 'tahfizh' },
  lunas: { n: 'Lunas', w: 'presensi' },
  batal: { n: 'Dibatalkan', w: 'hakakses' },
}
export const CARA_BAYAR = { tunai: 'Tunai', transfer: 'Transfer' }
export const JENJANG = { wustha: 'Kesetaraan Wustha', sma: 'SMA' }
export const JENJANG_SINGKAT = { wustha: 'Wustha', sma: 'SMA' }
export const TINGKAT = { wustha: [7, 8, 9], sma: [10, 11, 12] }

/** Nama periode bulanan "2026-10" → "Oktober 2026". */
export const namaBulan = (k) => (k && /^\d{4}-\d{2}$/.test(k) ? `${BULAN[Number(k.slice(5)) - 1]} ${k.slice(0, 4)}` : k || '')
/** Daftar bulan (YYYY-MM) dari awal tahun ajaran (Juli) sampai Juni berikutnya. */
export function bulanTahunAjaran(namaTA) {
  const t = Number(String(namaTA || '').slice(0, 4)) || new Date().getFullYear()
  return Array.from({ length: 12 }, (_, i) => { const b = (6 + i) % 12; const th = t + (6 + i >= 12 ? 1 : 0); return `${th}-${String(b + 1).padStart(2, '0')}` })
}
export const kelasSantri = (s) => s?.kelas || (s?.tingkat ? `Tingkat ${s.tingkat}` : '–')
export const labelSantri = (s) => `${s.nama} · ${s.nis}${s.kelas ? ' · ' + s.kelas : ''}`

/** Kelompokkan baris tunggakan (posisi_tunggakan) menurut kunci. */
export function kelompokTunggakan(baris, cakupan) {
  const kunci = {
    santri: (r) => r.student_id, kelas: (r) => r.kelas || `${JENJANG_SINGKAT[r.jenjang]} tingkat ${r.tingkat}`,
    kamar: (r) => r.kamar || 'Belum berkamar', halaqah: (r) => r.halaqah || 'Belum berhalaqah',
    jenis: (r) => r.jenis, jenjang: (r) => JENJANG[r.jenjang] || r.jenjang,
  }[cakupan]
  const m = new Map()
  for (const r of baris) {
    const k = kunci(r)
    const x = m.get(k) || { kunci: k, nama: cakupan === 'santri' ? r.nama : k, nis: r.nis, kelas: r.kelas, jenjang: r.jenjang, wali: r.wali, student_id: r.student_id,
      santri: new Set(), tagihan: 0, sisa: 0, nominal: 0, tertua: r.jatuh_tempo, hari: 0, isi: [] }
    x.santri.add(r.student_id); x.tagihan++; x.sisa += Number(r.sisa); x.nominal += Number(r.nominal)
    if (r.jatuh_tempo < x.tertua) x.tertua = r.jatuh_tempo
    x.hari = Math.max(x.hari, Number(r.hari_lewat) || 0); x.isi.push(r)
    m.set(k, x)
  }
  return [...m.values()].map((x) => ({ ...x, jumlahSantri: x.santri.size })).sort((a, b) => b.sisa - a.sisa || String(a.nama).localeCompare(b.nama))
}

/** Rincian tagihan untuk pesan WA (satu baris per tagihan). */
export const rincianWA = (tagihan) => (tagihan || []).map((t) => `• ${t.tagihan || t.nama}: ${rupiah(t.sisa ?? t.jumlah)}${t.lewat ? ' (lewat jatuh tempo)' : ''}`).join('\n')
export const rekeningWA = (rek) => (rek || []).map((r) => `• ${r.bank} ${r.nomor} a.n. ${r.atas_nama}`).join('\n') || '• (rekening lembaga belum diatur)'

export const tanggalPanjang = formatPanjang
export const tanggalPendek = formatPendek

// ---------- Pesan WA ke wali (template dapat disunting di Setelan → Template WA) ----------
const HUB = { ayah: 'Ayah', ibu: 'Ibu', wali: 'Wali' }
const penerima = (s) => ({ nama_wali: s?.wali?.nama || 'Orang tua/wali', hubungan: HUB[s?.wali?.hubungan] || '', nama_santri: s?.nama, nis: s?.nis, kelas: kelasSantri(s) })

/** Surat tagihan (hasil suratTagihan) → pesan WA. */
export const pesanTagihan = (l, peng) => pesanWA('tagihan_santri', { ...penerima(l.santri), rincian: rincianWA(l.rincian), total: rupiah(l.total),
  batas_bayar: formatPanjang(l.batas_bayar), rekening: rekeningWA(peng?.rekening), nomor: l.nomor, kode_validasi: l.kode_validasi, tautan_cek: alamatCek(l.kode_validasi) })
/** Kuitansi (hasil kuitansi) → pesan konfirmasi pembayaran. */
export const pesanKuitansi = (k) => pesanWA('kuitansi_santri', { ...penerima(k.santri), rincian: (k.rincian || []).map((r) => `• ${r.tagihan}: ${rupiah(r.jumlah)}${Number(r.sisa) ? ` (sisa ${rupiah(r.sisa)})` : ' (lunas)'}`).join('\n'),
  jumlah: rupiah(k.jumlah), tanggal: formatPanjang(k.tanggal), nomor: k.nomor, kode_validasi: k.kode_validasi,
  sisa: Number(k.sisa_total) ? `Sisa seluruh tagihan ananda: ${rupiah(k.sisa_total)}.` : 'Seluruh tagihan ananda saat ini sudah lunas.' })
/** Tagihan baru satu santri (baris daftar_tagihan) → pesan pemberitahuan. */
export const pesanTagihanBaru = (santri, baris, peng) => pesanWA('tagihan_baru', { ...penerima(santri), rincian: rincianWA(baris.map((b) => ({ ...b, lewat: false }))),
  total: rupiah(baris.reduce((a, b) => a + Number(b.sisa), 0)), batas_bayar: formatPanjang(baris.map((b) => b.jatuh_tempo).sort()[0]), rekening: rekeningWA(peng?.rekening) })
/** Pengingat menjelang jatuh tempo satu santri → pesan. */
export const pesanPengingat = (santri, baris, peng) => pesanWA('pengingat_jatuh_tempo', { ...penerima(santri), rincian: rincianWA(baris.map((b) => ({ ...b, lewat: false }))),
  total: rupiah(baris.reduce((a, b) => a + Number(b.sisa), 0)), batas_bayar: formatPanjang(baris.map((b) => b.jatuh_tempo).sort()[0]), rekening: rekeningWA(peng?.rekening) })
/** Kelompokkan baris tagihan per santri (untuk daftar kirim WA). */
export function perSantri(baris) {
  const m = new Map()
  for (const b of baris) { const x = m.get(b.student_id) || { id: b.student_id, nama: b.nama, nis: b.nis, kelas: b.kelas, wali: b.wali, isi: [] }; x.isi.push(b); m.set(b.student_id, x) }
  return [...m.values()]
}
/** Tunggakan satu santri (baris posisi_tunggakan atau tagihan terbuka) → pesan pemberitahuan. */
export const pesanTunggakan = (santri, baris, peng) => pesanWA('tunggakan_santri', { ...penerima(santri), rincian: rincianWA(baris.map((b) => ({ ...b, lewat: false }))),
  total: rupiah(baris.reduce((a, b) => a + Number(b.sisa), 0)), rekening: rekeningWA(peng?.rekening) })
