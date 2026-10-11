// SIMKA PRO | src/lib/demoGaji.js | v1.0 | Fase 11 – Tahap 2 Mesin periode gaji untuk mode demo | 11/10/2026
// Tiruan sederhana fungsi server periode gaji (migrasi 7100) agar tampilan dapat dicoba tanpa Supabase.
// Logika sama: komponen skema → honor (honorer) → komponen yang diubah dipertahankan → penyesuaian dari
// jumlah diterima yang ditetapkan atau penetapan yayasan.
import { petaTarif, hitungTunjangan } from './tunjangan'

const D = { periode: [], baris: {}, penetapan: [], urut: 1 }
const id = () => 'dg' + D.urut++
const akhirBulan = (t, b) => new Date(Date.UTC(t, b, 0)).toISOString().slice(0, 10)

function dataPegawai(p, tgl) {
  const a = p.tmt_tugas ? new Date(p.tmt_tugas) : null; const b = new Date(tgl)
  let bln = a ? (b.getFullYear() - a.getFullYear()) * 12 + b.getMonth() - a.getMonth() - (b.getDate() < a.getDate() ? 1 : 0) : 0
  bln = Math.max(0, bln)
  const cat = []
  if (!p.rekening) cat.push('Rekening/cara bayar belum diisi.')
  return { niy: p.niy, nama: p.nama_lengkap, jk: p.jenis_kelamin, unit: p.nama_unit, status: p.status_kepegawaian, kategori_honorer: p.kategori_honorer,
    pendidikan: p.pendidikan_terakhir, tmt: p.tmt_tugas, masa_kerja_tahun: Math.floor(bln / 12), masa_kerja_bulan: bln % 12,
    jabatan_struktural: p.jabatan_struktural, jabatan_fungsional: p.jabatan_fungsional || [], rekening: p.rekening, catatan: cat }
}

function hitung(l, ctx) {
  const pr = D.periode.find((x) => x.id === l.period_id)
  const p = ctx.pegawai.find((x) => x.id === l.employee_id)
  const tarif = petaTarif(ctx.tarif, pr.tanggal_akhir)
  const lama = l.item.filter((i) => i.sumber === 'manual' && i.besaran_skema != null)
  const tetap = l.item.filter((i) => i.besaran_skema == null && i.kategori !== 'penyesuaian')
  const h = hitungTunjangan(p, tarif, ctx.org, pr.tanggal_akhir, { honorerJabatan: ctx.pengaturan.honorer_tunjangan_jabatan !== false })
  const item = []
  const URUT = { struktural: 10, fungsional: 20, pendidikan: 60, masa_kerja: 70, kepegawaian: 80, kesehatan: 81, level_muhaffizh: 90 }
  for (const r of h.rincian) {
    const label = { struktural: `Tunjangan jabatan ${r.label}`, fungsional: `Tunjangan ${r.label}`, pendidikan: `Tunjangan pendidikan ${r.label}`,
      masa_kerja: `Tunjangan masa kerja ${r.label}`, kepegawaian: 'Tunjangan kepegawaian', kesehatan: 'Tunjangan kesehatan', level_muhaffizh: `Tunjangan ${r.label.toLowerCase()}` }[r.kategori] || r.label
    const u = lama.find((x) => x.kategori === r.kategori && x.label === label)
    item.push({ id: u?.id || id(), jenis: 'pendapatan', kategori: r.kategori, label, besaran_skema: r.besaran, besaran: u ? u.besaran : r.besaran,
      sumber: u ? 'manual' : 'skema', alasan: u?.alasan || null, urutan: URUT[r.kategori] || 50, diubah_oleh: u?.diubah_oleh, diubah_pada: u?.diubah_pada })
  }
  if (p.status_kepegawaian === 'honorer' && (p.jabatan_fungsional || []).some((j) => /guru/i.test(j))) {
    const tr = tarif.honorer_jam?.['guru_' + (p.kategori_honorer || 'baru')]; const u = lama.find((x) => x.kategori === 'honor')
    const jam = u?.jumlah ?? 48
    if (tr) item.push({ id: u?.id || id(), jenis: 'pendapatan', kategori: 'honor', kode: 'guru', label: 'Honor mengajar', jumlah: jam, tarif: Number(tr.besaran),
      besaran_skema: 48 * tr.besaran, besaran: u ? u.besaran : jam * tr.besaran, sumber: u ? 'manual' : 'skema', alasan: u?.alasan, urutan: 50,
      rincian: { sumber: 'Jurnal mengajar', jp_terlaksana: 48, jam_otomatis: 48 } })
  }
  item.push(...tetap)
  const dasar = item.reduce((a, i) => a + (i.jenis === 'pendapatan' ? i.besaran : -i.besaran), 0)
  const label = ctx.pengaturan.label_penyesuaian || 'Penyesuaian ketetapan yayasan'
  if (l.target_diterima != null) {
    if (l.target_diterima - dasar) item.push({ id: id(), jenis: 'pendapatan', kategori: 'penyesuaian', label, besaran: l.target_diterima - dasar, sumber: 'manual', alasan: l.alasan_target, urutan: 95 })
  } else {
    const d = D.penetapan.filter((x) => x.employee_id === l.employee_id && x.berlaku_mulai <= pr.tanggal_akhir && (!x.berlaku_sampai || x.berlaku_sampai >= pr.tanggal_mulai))
      .sort((a, b) => b.berlaku_mulai.localeCompare(a.berlaku_mulai))[0]
    if (d) {
      const pend = item.filter((i) => i.jenis === 'pendapatan').reduce((a, i) => a + i.besaran, 0)
      const v = d.mode === 'selisih' ? d.nilai : d.nilai - pend
      if (v) item.push({ id: id(), jenis: 'pendapatan', kategori: 'penyesuaian', label, besaran: v, sumber: 'penetapan', alasan: d.keterangan, urutan: 95, rincian: { mode: d.mode, nilai: d.nilai } })
    }
  }
  item.sort((a, b) => (a.jenis === b.jenis ? a.urutan - b.urutan : a.jenis === 'pendapatan' ? -1 : 1))
  l.item = item
  l.data = dataPegawai(p, pr.tanggal_akhir); l.data.catatan.push(...h.catatan.filter((c) => /belum diatur|belum diisi/.test(c)))
  l.total_skema = item.filter((i) => i.jenis === 'pendapatan' && !['penyesuaian', 'tambahan'].includes(i.kategori)).reduce((a, i) => a + (i.besaran_skema || 0), 0)
  l.total_penyesuaian = item.filter((i) => i.kategori === 'penyesuaian').reduce((a, i) => a + i.besaran, 0)
  l.total_pendapatan = item.filter((i) => i.jenis === 'pendapatan').reduce((a, i) => a + i.besaran, 0)
  l.total_potongan = item.filter((i) => i.jenis === 'potongan').reduce((a, i) => a + i.besaran, 0)
  l.diterima = l.total_pendapatan - l.total_potongan
}

const ringkas = (pr) => {
  const b = D.baris[pr.id] || []; const s = (k) => b.reduce((a, x) => a + x[k], 0)
  return { ...pr, pegawai: b.length, total_skema: s('total_skema'), total_penyesuaian: s('total_penyesuaian'), total_pendapatan: s('total_pendapatan'),
    total_potongan: s('total_potongan'), total_diterima: s('diterima'), data_kurang: b.filter((x) => x.data.catatan.length).length }
}
const cariBaris = (lineId) => Object.values(D.baris).flat().find((l) => l.id === lineId)
const cariItem = (itemId) => { for (const l of Object.values(D.baris).flat()) { const i = l.item.find((x) => x.id === itemId); if (i) return { l, i } } return {} }
const draf = (periodId) => { if (D.periode.find((x) => x.id === periodId)?.status !== 'draf') throw new Error('Periode gaji sudah tidak dapat diubah.') }

export const demoGaji = {
  daftar: () => JSON.parse(JSON.stringify(D.periode.map(ringkas))).sort((a, b) => b.tahun - a.tahun || b.bulan - a.bulan),
  buat(t, b, bayar, ctx) {
    if (D.periode.some((x) => x.tahun === t && x.bulan === b)) throw new Error('Periode gaji ini sudah ada.')
    const akhir = akhirBulan(t, b)
    const pr = { id: id(), tahun: t, bulan: b, tanggal_mulai: `${t}-${String(b).padStart(2, '0')}-01`, tanggal_akhir: akhir, status: 'draf',
      tanggal_bayar: bayar || akhirBulan(b === 12 ? t + 1 : t, b === 12 ? 1 : b + 1).slice(0, 8) + String(ctx.pengaturan.tanggal_gajian || 1).padStart(2, '0'), dihitung_pada: new Date().toISOString() }
    D.periode.push(pr)
    D.baris[pr.id] = ctx.pegawai.map((p) => { const l = { id: id(), period_id: pr.id, employee_id: p.id, item: [], target_diterima: null }; hitung(l, ctx); return l })
    return pr.id
  },
  // Salinan baru setiap dibaca (seperti hasil server) agar tampilan menyegar
  rincian: (pid) => JSON.parse(JSON.stringify({ periode: D.periode.find((x) => x.id === pid), baris: [...(D.baris[pid] || [])].sort((a, b) => a.data.nama.localeCompare(b.data.nama)) })),
  hitungUlang(pid, ctx) { draf(pid); for (const l of D.baris[pid]) hitung(l, ctx); D.periode.find((x) => x.id === pid).dihitung_pada = new Date().toISOString() },
  ubahPeriode(pid, isi) { draf(pid); Object.assign(D.periode.find((x) => x.id === pid), isi) },
  hapusPeriode(pid) { draf(pid); D.periode = D.periode.filter((x) => x.id !== pid); delete D.baris[pid] },
  hapusBaris(lineId) { const l = cariBaris(lineId); draf(l.period_id); D.baris[l.period_id] = D.baris[l.period_id].filter((x) => x.id !== lineId) },
  ubahItem(itemId, besaran, jumlah, alasan, ctx) {
    const { l, i } = cariItem(itemId); draf(l.period_id)
    if (i.kategori === 'honor' && jumlah != null) { i.jumlah = jumlah; i.besaran = besaran ?? Math.round(jumlah * i.tarif) } else i.besaran = besaran
    if (i.besaran_skema != null) i.sumber = 'manual'
    Object.assign(i, { alasan, diubah_oleh: 'Anda', diubah_pada: new Date().toISOString() }); hitung(l, ctx)
  },
  kembalikan(itemId, ctx) { const { l, i } = cariItem(itemId); l.item = l.item.filter((x) => x !== i); hitung(l, ctx) },
  tambahItem(lineId, isi, ctx) {
    const l = cariBaris(lineId); draf(l.period_id)
    l.item.push({ id: id(), jenis: isi.jenis, kategori: isi.jenis === 'pendapatan' ? 'tambahan' : 'potongan_lain', label: isi.label, besaran: Number(isi.besaran),
      sumber: 'manual', alasan: isi.alasan, urutan: isi.jenis === 'pendapatan' ? 96 : 199, diubah_oleh: 'Anda', diubah_pada: new Date().toISOString() })
    hitung(l, ctx)
  },
  hapusItem(itemId, ctx) { const { l, i } = cariItem(itemId); l.item = l.item.filter((x) => x !== i); hitung(l, ctx) },
  aturDiterima(lineId, nilai, alasan, ctx) { const l = cariBaris(lineId); draf(l.period_id); l.target_diterima = nilai; l.alasan_target = alasan; hitung(l, ctx) },
  imporDiterima(pid, baris, ctx) {
    draf(pid); let n = 0; const gagal = []
    baris.forEach((r, i) => {
      const l = D.baris[pid].find((x) => x.data.niy === String(r.niy))
      if (!l) { gagal.push({ baris: i + 1, pesan: `NIY ${r.niy} tidak ditemukan.` }); return }
      l.target_diterima = Number(String(r.diterima).replace(/[^0-9]/g, '')); l.alasan_target = r.keterangan || 'Impor data gaji diterima'; hitung(l, ctx); n++
    })
    return { disimpan: n, gagal }
  },
  penetapan: () => D.penetapan.map((d) => ({ ...d })),
  simpanPenetapan(isi, ctx) {
    const p = ctx.pegawai.find((x) => x.id === isi.employee_id)
    const baru = { ...isi, nilai: Number(isi.nilai), niy: p?.niy, nama: p?.nama_lengkap, aktif: true, dibuat_oleh: 'Anda', created_at: new Date().toISOString() }
    const i = D.penetapan.findIndex((x) => x.id === isi.id); if (i >= 0) D.penetapan[i] = { ...D.penetapan[i], ...baru }; else D.penetapan.push({ ...baru, id: id() })
  },
  hapusPenetapan(pid) { D.penetapan = D.penetapan.filter((x) => x.id !== pid) },
}
