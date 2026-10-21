// SIMKA PRO | src/lib/persuratan.js | v1.1 | 14.19.0: bagian penerbit/penerima surat (Yayasan, Pondok, Wustha, SMA) | 21/10/2026
// Label baku persuratan (Blueprint Bagian 35): sifat, status, cara diterima, status disposisi.
import {
  PhEnvelopeSimple, PhWarningOctagon, PhLightning, PhLockKey, PhPaperPlaneTilt, PhStamp, PhCheckCircle, PhArchive, PhProhibit,
  PhEnvelopeOpen, PhCircleDashed, PhEye,
} from '@phosphor-icons/vue'

export const SIFAT_SURAT = {
  biasa:   { n: 'Biasa',   w: 'pegawai',   ikon: PhEnvelopeSimple },
  penting: { n: 'Penting', w: 'tatausaha', ikon: PhWarningOctagon },
  segera:  { n: 'Segera',  w: 'klinik',    ikon: PhLightning },
  rahasia: { n: 'Rahasia', w: 'pengumuman', ikon: PhLockKey },
}
export const STATUS_SURAT = {
  diteruskan:  { n: 'Menunggu disposisi', w: 'pengajuan', ikon: PhPaperPlaneTilt },
  didisposisi: { n: 'Didisposisi',        w: 'shift',     ikon: PhStamp },
  selesai:     { n: 'Selesai',            w: 'presensi',  ikon: PhCheckCircle },
  diarsipkan:  { n: 'Diarsipkan',         w: 'hakakses',  ikon: PhArchive },
  batal:       { n: 'Dibatalkan',         w: 'sistem',    ikon: PhProhibit },
}
export const STATUS_DISPOSISI = {
  baru:    { n: 'Belum dibaca', w: 'pengajuan', ikon: PhCircleDashed },
  dibaca:  { n: 'Dibaca',       w: 'agenda',    ikon: PhEye },
  selesai: { n: 'Selesai',      w: 'presensi',  ikon: PhCheckCircle },
}
export const CARA_TERIMA = [
  { k: 'langsung', n: 'Diantar langsung' }, { k: 'pos', n: 'Pos/ekspedisi' }, { k: 'email', n: 'Surel (email)' },
  { k: 'wa', n: 'WhatsApp' }, { k: 'lainnya', n: 'Lainnya' },
]
export const namaCara = (k) => CARA_TERIMA.find((c) => c.k === k)?.n || k
export const IKON_SURAT_MASUK = PhEnvelopeOpen

/** Susun disposisi datar menjadi pohon (induk → anak) dengan kedalaman untuk tampilan berjenjang. */
export function pohonDisposisi(daftar = []) {
  const anak = (id) => daftar.filter((d) => (d.induk_id || null) === id)
  const hasil = []
  const jalan = (id, tingkat) => { for (const d of anak(id)) { hasil.push({ ...d, tingkat }); jalan(d.id, tingkat + 1) } }
  jalan(null, 0)
  return hasil
}

/** Tanggal yyyy-mm-dd ditambah n hari. */
export function tambahHari(iso, n) {
  const d = new Date(`${iso}T00:00:00`); d.setDate(d.getDate() + Number(n || 0))
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

// ---------- 14.19.0: bagian (kop) surat ----------
// Empat bagian yang menerbitkan dan menerima surat, masing-masing dengan kop dan urutan nomor sendiri.
export const WARNA_BAGIAN = { yayasan: 'pengumuman', pondok: 'beranda', wustha: 'walikelas', sma: 'rapor' }
/** Daftar bagian dari kop surat aktif: [{ k, n, w }]. */
export const daftarBagian = (letterheads = []) => letterheads.filter((x) => x.aktif !== false)
  .sort((a, b) => (a.urutan ?? 0) - (b.urutan ?? 0)).map((x) => ({ k: x.kode, n: (x.nama || x.kode).replace(/^Kop\s+/i, ''), w: WARNA_BAGIAN[x.kode] || 'tatausaha' }))
/** Nama pendek bagian dari kode kop. */
export const namaBagian = (letterheads, kode) => daftarBagian(letterheads).find((b) => b.k === (kode || 'pondok'))?.n || kode || 'Pondok'

