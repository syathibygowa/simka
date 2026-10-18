// SIMKA PRO | src/lib/demoKeuangan.js | v1.3 | 14.2.0: subsidi beririsan periode dan langsung menyesuaikan tagihan | 17/10/2026
// Meniru migrasi 7600–8000 agar menu Keuangan dapat dicoba tanpa Supabase. Semua nama fiktif.
// Hasil baca selalu salinan (seperti hasil server) agar tampilan menyegar setelah perubahan.
import { SANTRI_DEMO } from '@/lib/demoSantri'
import { hariIniISO } from '@/lib/tanggal'
import { namaBulan } from '@/lib/keuangan'

const salin = (x) => JSON.parse(JSON.stringify(x))
let urut = 1
const id = () => 'k' + urut++
const kode = () => { const h = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; let s = ''; for (let i = 0; i < 8; i++) s += h[(urut * 7 + i * 13 + s.length * 5) % h.length]; urut++; return s.slice(0, 4) + '-' + s.slice(4) }
const tambahHari = (iso, n) => { const d = new Date(iso + 'T00:00:00Z'); d.setUTCDate(d.getUTCDate() + n); return d.toISOString().slice(0, 10) }
const ROMAWI = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X', 'XI', 'XII']
const nomorDok = { kuitansi: 0, tagihan: 0 }
const nomor = (j, tgl) => `${j === 'kuitansi' ? 'KWT' : 'TGH'}.${String(++nomorDok[j]).padStart(3, '0')}/PPTQ-IAS/${ROMAWI[Number(tgl.slice(5, 7)) - 1]}/${tgl.slice(0, 4)}`
const BENDAHARA = { nama: 'Ust. Arief Muharief, S.E.', jabatan: 'Bendahara Pondok', niy: '2015070112' }

const D = { siap: false, santri: [], jenis: [], subsidi: [], tagihan: [], bayar: [], surat: [], pengaturan: {} }

function siapkan() {
  if (D.siap) return
  D.siap = true
  const hari = hariIniISO()
  D.pengaturan = { rekening: [{ bank: 'BSI', nomor: '7123456789', atas_nama: 'Pondok Pesantren Imam Asy-Syathiby', keterangan: 'SPP dan biaya rutin' },
    { bank: 'BRI', nomor: '0123-01-000456-30-1', atas_nama: 'Yayasan Imam Asy-Syathiby Gowa', keterangan: null }],
    jatuh_tempo_hari: 10, batas_surat_hari: 7, pengingat_hari: 3,
    catatan_kuitansi: 'Simpan kuitansi ini sebagai bukti pembayaran yang sah.',
    catatan_tagihan: 'Apabila sudah melakukan pembayaran, mohon abaikan surat ini dan kirimkan bukti transfer kepada Bendahara.' }
  D.santri = SANTRI_DEMO().map((s) => ({ id: s.id, nis: s.nis, nama: s.nama_lengkap, jk: s.jenis_kelamin, jenjang: s.jenjang, tingkat: s.tingkat, status: s.status,
    tahun_masuk: s.tahun_masuk, kelas: `${s.tingkat}${s.jenis_kelamin === 'L' ? 'A' : 'B'}`,
    kamar: s.jenis_kelamin === 'L' ? ['Kamar Umar', 'Kamar Ali', 'Kamar Utsman'][s.tingkat % 3] : ['Kamar Aisyah', 'Kamar Khadijah'][s.tingkat % 2],
    halaqah: s.jenis_kelamin === 'L' ? ['Halaqah Ust. Hasan', 'Halaqah Ust. Ahmad'][s.nis.charCodeAt(6) % 2] : 'Halaqah Ustzh. Nurul',
    kontak: s.kontak, wali: (() => { const k = s.kontak.filter((c) => c.no_hp).sort((a, b) => b.utama - a.utama)[0]; return k ? { nama: k.nama, hubungan: k.hubungan, no_hp: k.no_hp } : null })() }))
  const jenis = (kode, nama, siklus, nominal, extra = {}) => { const j = { id: id(), kode, nama, siklus, nominal, santri_baru: false, keterangan: null, aktif: true, urutan: D.jenis.length + 1, tarif: [], berlaku_jenjang: null, berlaku_tingkat: null, ...extra }; D.jenis.push(j); return j }
  const spp = jenis('SPP', 'SPP', 'bulanan', 750000, { keterangan: 'Sumbangan pembinaan pendidikan, makan, dan asrama', tarif: [{ id: id(), jenjang: 'sma', tingkat: null, jenis_kelamin: null, nominal: 850000 }, { id: id(), jenjang: null, tingkat: null, jenis_kelamin: 'P', nominal: 800000 }] })
  const du = jenis('DAFTAR_ULANG', 'Daftar ulang', 'tahunan', 1500000, { keterangan: 'Kitab, kegiatan, dan kesehatan satu tahun' })
  const pangkal = jenis('PANGKAL', 'Uang pangkal', 'sekali', 5000000, { santri_baru: true, keterangan: 'Santri baru' })
  jenis('SERAGAM', 'Seragam', 'sekali', 650000)
  jenis('KITAB_SMA', 'Kitab SMA', 'semesteran', 400000, { berlaku_jenjang: ['sma'], keterangan: 'Kitab per semester, khusus SMA' })
  const aktif = D.santri.filter((s) => s.status === 'aktif')
  D.subsidi.push({ id: id(), student_id: aktif[2].id, fee_type_id: spp.id, jenis: 'persen', nilai: 50, mulai: '2026-07-01', sampai: null, alasan: 'Santri yatim', aktif: true, created_at: '2026-07-10T08:00:00Z', oleh: 'Superadmin SIMKA' })
  D.subsidi.push({ id: id(), student_id: aktif[7].id, fee_type_id: null, jenis: 'nominal', nilai: 150000, mulai: '2026-07-01', sampai: '2027-06-30', alasan: 'Anak pegawai', aktif: true, created_at: '2026-07-10T08:00:00Z', oleh: 'Superadmin SIMKA' })
  D.subsidi.push({ id: id(), student_id: aktif[12].id, fee_type_id: spp.id, jenis: 'persen', nilai: 100, mulai: '2026-07-01', sampai: null, alasan: 'Beasiswa tahfizh 30 juz', aktif: true, created_at: '2026-07-10T08:00:00Z', oleh: 'Superadmin SIMKA' })
  const bulan = ['2026-07', '2026-08', '2026-09', '2026-10'].filter((b) => b <= hari.slice(0, 7))
  demo.buat({ fee_type_id: spp.id, bulan }, true)
  demo.buat({ fee_type_id: du.id, jatuh_tempo: '2026-08-15' }, true)
  demo.buat({ fee_type_id: pangkal.id, sasaran: { hanya_baru: true }, jatuh_tempo: '2026-08-31' }, true)
  // Pembayaran contoh: sebagian besar lunas sampai September, beberapa sebagian, beberapa menunggak
  aktif.forEach((s, i) => {
    if (i % 6 === 5) return
    const tg = D.tagihan.filter((b) => b.student_id === s.id && b.status !== 'lunas' && b.kunci_periode !== '2026-10')
    const total = tg.reduce((a, b) => a + b.nominal, 0)
    if (!total) return
    const jml = i % 4 === 3 ? Math.round(total * 0.6 / 1000) * 1000 : total
    const tgl = i % 5 === 0 ? hari : tambahHari(hari, -((i * 3) % 40) - 1)
    demo.bayar({ student_id: s.id, tanggal: tgl, cara: i % 3 ? 'transfer' : 'tunai', rekening_tujuan: i % 3 ? 'BSI 7123456789' : null, penyetor: s.wali?.nama || null, jumlah: jml }, true)
  })
  const menunggak = aktif.filter((s, i) => i % 6 === 5).slice(0, 2).map((s) => s.id)
  if (menunggak.length) demo.terbitkanSurat({ student_ids: menunggak, batas_bayar: tambahHari(hari, 7) })
}

const s = (sid) => D.santri.find((x) => x.id === sid)
const j = (fid) => D.jenis.find((x) => x.id === fid)
const ringkas = (sid) => { const x = s(sid); return x && { id: x.id, nis: x.nis, nama: x.nama, jk: x.jk, jenjang: x.jenjang, tingkat: x.tingkat, status: x.status, kelas: x.kelas, wali: x.wali } }
const nilaiTarif = (r) => (r.tingkat ? 4 : 0) + (r.jenjang ? 2 : 0) + (r.jenis_kelamin ? 1 : 0)
/** Tarif paling khusus: kelas > jenjang > putra/putri (k = { jenjang, tingkat } pada periode tagihan). */
const tarif = (f, st, k = st) => f.tarif.filter((r) => (!r.tingkat || r.tingkat === k.tingkat) && (!r.jenjang || r.jenjang === k.jenjang) && (!r.jenis_kelamin || r.jenis_kelamin === st.jk))
  .sort((a, b) => nilaiTarif(b) - nilaiTarif(a))[0]?.nominal ?? f.nominal
const TA_AKTIF = 2026
const tahunTA = (iso) => Number(iso.slice(0, 4)) - (Number(iso.slice(5, 7)) < 7 ? 1 : 0)
/** Kelas santri pada periode acuan (dihitung mundur); null bila belum masuk. */
function kelasPada(st, acuan) {
  const ta = tahunTA(acuan); const sel = Math.max(TA_AKTIF - ta, 0)
  if (st.tahun_masuk && st.tahun_masuk > ta) return null
  if (!sel) return { jenjang: st.jenjang, tingkat: st.tingkat }
  const t = st.tingkat - sel; return t < 7 ? null : { jenjang: t >= 10 ? 'sma' : 'wustha', tingkat: t }
}
const akhirPeriode = (f, acuan) => (f.siklus === 'bulanan' ? tambahHari(tambahBulan(acuan.slice(0, 7) + '-01', 1), -1) : f.siklus === 'semesteran' ? tambahHari(tambahBulan(acuan, 6), -1)
  : f.siklus === 'tahunan' ? tambahHari(tambahBulan(acuan, 12), -1) : acuan)
function tambahBulan(iso, n) { const d = new Date(iso + 'T00:00:00Z'); d.setUTCMonth(d.getUTCMonth() + n); return d.toISOString().slice(0, 10) }
function potongan(st, f, acuan, std) {
  let p = 0; const a = []; const akhir = akhirPeriode(f, acuan)
  for (const x of D.subsidi.filter((y) => y.student_id === st.id && y.aktif && (!y.fee_type_id || y.fee_type_id === f.id) && y.mulai <= akhir && (!y.sampai || y.sampai >= acuan))) {
    p += x.jenis === 'persen' ? Math.round(std * x.nilai / 100) : x.nilai
    a.push(`${x.alasan} (${x.jenis === 'persen' ? x.nilai + '%' : 'Rp' + x.nilai.toLocaleString('id-ID')})`)
  }
  return { potongan: Math.min(p, std), alasan: a.join('; ') || null }
}
/** Seperti _terapkan_subsidi: hitung ulang tagihan belum lunas (atau lunas karena subsidi), tidak di bawah yang sudah dibayar. */
function terapkanSubsidi(sid) {
  const st = D.santri.find((x) => x.id === sid); if (!st) return
  for (const b of D.tagihan.filter((x) => x.student_id === sid && !x.potongan_manual && (['belum', 'sebagian'].includes(x.status) || (x.status === 'lunas' && x.potongan > 0)))) {
    const f = D.jenis.find((x) => x.id === b.fee_type_id); const pt = potongan(st, f, b.tanggal_tagih, b.standar)
    b.potongan = Math.min(pt.potongan, b.standar - b.dibayar); b.alasan_potongan = pt.alasan; b.nominal = b.standar - b.potongan
    b.status = b.dibayar >= b.nominal ? 'lunas' : b.dibayar > 0 ? 'sebagian' : 'belum'
  }
}
function periode(f, p) {
  const hari = hariIniISO(); const tempo = p.jatuh_tempo || null
  if (f.siklus === 'bulanan') {
    if (!p.bulan?.length) throw new Error('Pilih paling sedikit satu bulan tagihan.')
    return p.bulan.map((b) => ({ kunci: b, label: `${f.nama} ${namaBulan(b)}`, acuan: b + '-01', tempo: (p.bulan.length === 1 && tempo) || `${b}-${String(D.pengaturan.jatuh_tempo_hari).padStart(2, '0')}` }))
  }
  const ta = p.tahun_ajaran || `${TA_AKTIF}/${TA_AKTIF + 1}`; const lalu = Number(ta.slice(0, 4)) < TA_AKTIF; const awal = lalu ? `${ta.slice(0, 4)}-07-01` : '2026-07-13'
  if (f.siklus === 'semesteran') { const sem = Number(p.semester) || 1; const ac = sem === 1 ? awal : `${Number(ta.slice(0, 4)) + 1}-01-${awal.slice(8)}`
    return [{ kunci: `${ta}-S${sem}`, label: `${f.nama} Semester ${sem === 1 ? 'Ganjil' : 'Genap'} ${ta}`, acuan: ac, tempo: tempo || tambahHari(lalu ? ac : sem === 1 ? hari : ac, 30) }] }
  if (f.siklus === 'tahunan') return [{ kunci: ta, label: `${f.nama} ${ta}`, acuan: awal, tempo: tempo || tambahHari(lalu ? awal : hari, 30) }]
  return [{ kunci: 'sekali', label: f.nama, acuan: hari, tempo: tempo || tambahHari(hari, 30) }]
}
const grup = (gid, st) => { const [jn, ...n] = String(gid).split(':'); return st[jn] === n.join(':') }
/** Sasaran pada satu periode: [{ st, k: kelas saat itu }] */
function sasaran(p, acuan = hariIniISO()) {
  const x = p.sasaran || {}; const f = j(p.fee_type_id) || {}
  return D.santri.filter((st) => st.status === 'aktif' && (!x.group_id || grup(x.group_id, st)) && (!x.student_ids?.length || x.student_ids.includes(st.id)))
    .map((st) => ({ st, k: kelasPada(st, acuan) })).filter(({ st, k }) => k && (!f.berlaku_jenjang?.length || f.berlaku_jenjang.includes(k.jenjang))
      && (!f.berlaku_tingkat?.length || f.berlaku_tingkat.map(Number).includes(k.tingkat)) && (!f.berlaku_jk || st.jk === f.berlaku_jk)
      && (!x.jenjang || k.jenjang === x.jenjang) && (!x.tingkat?.length || x.tingkat.map(Number).includes(k.tingkat)) && (!x.jk || st.jk === x.jk)
      && (!x.hanya_baru || st.tahun_masuk === tahunTA(acuan)))
}
const segarkan = (b) => { b.status = b.status === 'batal' ? 'batal' : b.dibayar >= b.nominal ? 'lunas' : b.dibayar > 0 ? 'sebagian' : 'belum' }
const barisTagihan = (b) => { const st = s(b.student_id); const f = j(b.fee_type_id)
  return { id: b.id, student_id: st.id, nis: st.nis, nama: st.nama, jk: st.jk, jenjang: st.jenjang, tingkat: st.tingkat, kelas: st.kelas, wali: st.wali, fee_type_id: f.id, jenis: f.nama, siklus: f.siklus,
    kunci_periode: b.kunci_periode, tagihan: b.nama, tanggal_tagih: b.tanggal_tagih, jatuh_tempo: b.jatuh_tempo, standar: b.standar, potongan: b.potongan, alasan_potongan: b.alasan_potongan,
    nominal: b.nominal, dibayar: b.dibayar, sisa: b.nominal - b.dibayar, status: b.status, catatan: b.catatan, lewat: ['belum', 'sebagian'].includes(b.status) && b.jatuh_tempo < hariIniISO() } }
const barisBayar = (py) => { const st = s(py.student_id)
  return { ...py, nis: st.nis, nama: st.nama, jk: st.jk, jenjang: st.jenjang, tingkat: st.tingkat, kelas: st.kelas, wali: st.wali,
    rincian: py.items.map((i) => { const b = D.tagihan.find((x) => x.id === i.bill_id); return { bill_id: b.id, tagihan: b.nama, jenis: j(b.fee_type_id).nama, fee_type_id: b.fee_type_id, jumlah: i.jumlah, sisa: i.sisa } }) } }
const terbuka = (b) => ['belum', 'sebagian'].includes(b.status)

export const demo = {
  hak: () => { siapkan(); return { kelola: true, lihat: true, superadmin: true, penanda_tangan: true, jabatan_ttd: BENDAHARA.jabatan, ada_penanda_tangan: true, pengaturan: salin(D.pengaturan) } },
  simpanPengaturan(p) { siapkan(); Object.assign(D.pengaturan, salin(p)); return salin(D.pengaturan) },
  jenis() { siapkan(); return salin(D.jenis.map((f) => ({ ...f, jumlah_tagihan: D.tagihan.filter((b) => b.fee_type_id === f.id && b.status !== 'batal').length }))) },
  simpanJenis(p) {
    siapkan()
    if (!['sekali', 'semesteran', 'tahunan', 'bulanan'].includes(p.siklus)) throw new Error('Pilih siklus: bulanan, semesteran, tahunan, atau sekali.')
    const x = { ...salin(p), kode: String(p.kode || '').toUpperCase(), nominal: Number(p.nominal) || 0, berlaku_jk: p.berlaku_jk || null, tarif: (p.tarif || []).filter((r) => r.jenjang || r.tingkat || r.jenis_kelamin).map((r) => ({ id: id(), jenjang: r.jenjang || null, tingkat: r.tingkat ? Number(r.tingkat) : null, jenis_kelamin: r.jenis_kelamin || null, nominal: Number(r.nominal) || 0 })) }
    const i = D.jenis.findIndex((f) => f.id === p.id)
    if (i >= 0) Object.assign(D.jenis[i], x); else D.jenis.push({ ...x, id: id(), aktif: p.aktif ?? true, urutan: D.jenis.length + 1 })
  },
  kelompok() {
    siapkan(); const m = new Map()
    for (const st of D.santri.filter((x) => x.status === 'aktif')) for (const jn of ['kelas', 'kamar', 'halaqah']) {
      const k = `${jn}:${st[jn]}`; const x = m.get(k) || { id: k, jenis: jn, nama: st[jn], jenjang: jn === 'kelas' ? st.jenjang : null, tingkat: jn === 'kelas' ? st.tingkat : null, anggota: 0 }; x.anggota++; m.set(k, x) }
    return salin([...m.values()].sort((a, b) => ['kelas', 'kamar', 'halaqah'].indexOf(a.jenis) - ['kelas', 'kamar', 'halaqah'].indexOf(b.jenis) || (a.tingkat || 0) - (b.tingkat || 0) || a.nama.localeCompare(b.nama)))
  },
  hapusJenis(fid) { if (D.tagihan.some((b) => b.fee_type_id === fid)) { j(fid).aktif = false; return 'dinonaktifkan' } D.jenis = D.jenis.filter((f) => f.id !== fid); return 'dihapus' },
  subsidi() { siapkan(); const h = hariIniISO(); return salin(D.subsidi.map((x) => { const st = s(x.student_id); return { ...x, nis: st.nis, nama: st.nama, jk: st.jk, jenjang: st.jenjang, tingkat: st.tingkat, kelas: st.kelas,
    jenis_biaya: x.fee_type_id ? j(x.fee_type_id)?.nama : null, berlaku: x.aktif && x.mulai <= h && (!x.sampai || x.sampai >= h) } }).sort((a, b) => a.nama.localeCompare(b.nama))) },
  simpanSubsidi(p) { const x = { ...salin(p), nilai: Number(p.nilai), fee_type_id: p.fee_type_id || null, sampai: p.sampai || null, aktif: p.aktif ?? true }
    const i = D.subsidi.findIndex((y) => y.id === p.id); if (i >= 0) Object.assign(D.subsidi[i], x); else D.subsidi.push({ ...x, id: id(), created_at: new Date().toISOString(), oleh: 'Superadmin SIMKA' })
    terapkanSubsidi(x.student_id) },
  hapusSubsidi(sid) { const x = D.subsidi.find((y) => y.id === sid); D.subsidi = D.subsidi.filter((y) => y.id !== sid); if (x) terapkanSubsidi(x.student_id) },
  pratinjau(p) {
    siapkan(); const f = j(p.fee_type_id); if (!f) throw new Error('Pilih jenis biaya.')
    const per = periode(f, p)
    const baris = []
    for (const x of per) for (const { st, k } of sasaran(p, x.acuan)) { const std = tarif(f, st, k); const pt = potongan(st, f, x.acuan, std)
      baris.push({ student_id: st.id, nis: st.nis, nama: st.nama, jk: st.jk, jenjang: k.jenjang, tingkat: k.tingkat, tingkat_kini: st.tingkat, kelas: st.kelas, kunci: x.kunci, label: x.label, standar: std,
        potongan: pt.potongan, alasan_potongan: pt.alasan, nominal: std - pt.potongan, ada: D.tagihan.some((b) => b.student_id === st.id && b.fee_type_id === f.id && b.kunci_periode === x.kunci && b.status !== 'batal') }) }
    return salin({ periode: per.map((x) => ({ kunci: x.kunci, label: x.label, jatuh_tempo: x.tempo })), baris: baris.sort((a, b) => a.nama.localeCompare(b.nama) || a.kunci.localeCompare(b.kunci)) })
  },
  buat(p, awal = false) {
    if (!awal) siapkan()
    const f = j(p.fee_type_id); let dibuat = 0, dilewati = 0, nominal = 0
    for (const x of periode(f, p)) for (const { st, k } of sasaran(p, x.acuan)) {
      if (D.tagihan.some((b) => b.student_id === st.id && b.fee_type_id === f.id && b.kunci_periode === x.kunci && b.status !== 'batal')) { dilewati++; continue }
      const std = tarif(f, st, k); const pt = potongan(st, f, x.acuan, std)
      const b = { id: id(), student_id: st.id, fee_type_id: f.id, kunci_periode: x.kunci, nama: x.label, tanggal_tagih: x.acuan < hariIniISO() ? x.acuan : hariIniISO(), jatuh_tempo: x.tempo,
        standar: std, potongan: pt.potongan, alasan_potongan: pt.alasan, nominal: std - pt.potongan, dibayar: 0, status: 'belum', catatan: p.catatan || null }
      segarkan(b); D.tagihan.push(b); dibuat++; nominal += b.nominal
    }
    return { dibuat, dilewati, nominal }
  },
  tagihan(p = {}) {
    siapkan(); const h = hariIniISO()
    return salin(D.tagihan.filter((b) => (!p.fee_type_id || b.fee_type_id === p.fee_type_id) && (!p.kunci_periode || b.kunci_periode === p.kunci_periode) && (!p.student_id || b.student_id === p.student_id)
      && (!p.status ? b.status !== 'batal' : p.status === 'tunggak' ? terbuka(b) : p.status === 'lewat' ? terbuka(b) && b.jatuh_tempo < h
        : p.status === 'segera' ? terbuka(b) && b.jatuh_tempo >= h && b.jatuh_tempo <= tambahHari(h, 7) : b.status === p.status)
      && (!p.kunci?.length || p.kunci.includes(b.kunci_periode)) && (!p.group_id || grup(p.group_id, s(b.student_id)))
      && (!p.jenjang || s(b.student_id).jenjang === p.jenjang) && (!p.q || s(b.student_id).nama.toLowerCase().includes(p.q.toLowerCase()) || s(b.student_id).nis.startsWith(p.q)))
      .map(barisTagihan).sort((a, b) => a.nama.localeCompare(b.nama) || a.jatuh_tempo.localeCompare(b.jatuh_tempo)))
  },
  ubahTagihan(bid, p) { const b = D.tagihan.find((x) => x.id === bid); if (!p.alasan || p.alasan.length < 3) throw new Error('Tulis alasan perubahan tagihan.')
    if (p.standar != null) b.standar = Number(p.standar); if (p.potongan != null && Number(p.potongan) !== b.potongan) { b.potongan = Number(p.potongan); b.potongan_manual = true } if ('alasan_potongan' in p) b.alasan_potongan = p.alasan_potongan || null
    if (p.jatuh_tempo) b.jatuh_tempo = p.jatuh_tempo; b.nominal = Math.max(b.standar - b.potongan, 0)
    if (b.nominal < b.dibayar) throw new Error('Tagihan tidak boleh lebih kecil dari jumlah yang sudah dibayar.'); b.catatan = [b.catatan, p.alasan].filter(Boolean).join('\n'); segarkan(b) },
  batalTagihan(bid, alasan) { const b = D.tagihan.find((x) => x.id === bid); if (b.dibayar > 0) throw new Error('Tagihan ini sudah dibayar. Batalkan pembayarannya dulu.'); b.status = 'batal'; b.alasan_batal = alasan },
  bayar(p, awal = false) {
    if (!awal) siapkan()
    const st = s(p.student_id); let alok = []
    if (p.alokasi?.length) alok = p.alokasi.filter((a) => Number(a.jumlah) > 0).map((a) => { const b = D.tagihan.find((x) => x.id === a.bill_id)
      if (Number(a.jumlah) > b.nominal - b.dibayar) throw new Error(`Jumlah melebihi sisa tagihan ${b.nama}.`); return { b, jumlah: Number(a.jumlah) } })
    else { let sisa = Number(p.jumlah) || 0; if (sisa <= 0) throw new Error('Isi jumlah pembayaran.')
      for (const b of D.tagihan.filter((x) => x.student_id === st.id && terbuka(x)).sort((a, c) => a.jatuh_tempo.localeCompare(c.jatuh_tempo))) { if (sisa <= 0) break
        const v = Math.min(sisa, b.nominal - b.dibayar); alok.push({ b, jumlah: v }); sisa -= v }
      if (sisa > 0) throw new Error(`Jumlah melebihi seluruh sisa tagihan santri ini; kelebihan Rp${sisa.toLocaleString('id-ID')}.`) }
    const total = alok.reduce((a, x) => a + x.jumlah, 0); if (!total) throw new Error('Tidak ada tagihan yang dibayar.')
    const tgl = p.tanggal || hariIniISO()
    const py = { id: id(), student_id: st.id, tanggal: tgl, cara: p.cara, rekening_tujuan: p.rekening_tujuan || null, penyetor: p.penyetor || null, keterangan: p.keterangan || null,
      jumlah: total, bukti_id: null, nomor: p.riwayat ? null : nomor('kuitansi', tgl), kode_validasi: p.riwayat ? null : kode(), riwayat: !!p.riwayat, status: 'sah', created_at: new Date().toISOString(), dicatat: BENDAHARA.nama, items: [] }
    if (p.riwayat && !py.keterangan) py.keterangan = 'Catatan pembayaran lama'
    for (const x of alok) { x.b.dibayar += x.jumlah; segarkan(x.b); py.items.push({ bill_id: x.b.id, jumlah: x.jumlah, sisa: x.b.nominal - x.b.dibayar }) }
    D.bayar.push(py)
    return { id: py.id, nomor: py.nomor, kode_validasi: py.kode_validasi, jumlah: total }
  },
  /** Impor catatan lama (meniru impor_riwayat_keuangan). */
  imporRiwayat(p) {
    siapkan(); const hasil = []; const h = hariIniISO(); const salinan = p.uji ? salin({ t: D.tagihan, b: D.bayar }) : null
    p.baris.forEach((r, i) => {
      const st = D.santri.find((x) => x.nis === String(r.nis || '').trim()); let label = r.periode
      try {
        if (!st) throw new Error(`NIS ${r.nis || '(kosong)'} tidak ditemukan.`)
        const f = D.jenis.find((x) => x.kode === String(r.kode || '').trim().toUpperCase()); if (!f) throw new Error(`Kode biaya ${r.kode || '(kosong)'} tidak dikenal.`)
        const per = String(r.periode || '').trim().toLowerCase(); let kunci, acuan, tempo
        if (f.siklus === 'bulanan') { const z1 = per.match(/^(\d{4})-(\d{1,2})$/); const z2 = per.match(/^(\d{1,2})[/-](\d{4})$/)
          const a = z1 ? [z1[1], z1[2]] : z2 ? [z2[2], z2[1]] : null
          if (!a || Number(a[1]) < 1 || Number(a[1]) > 12) throw new Error(`Periode bulanan "${r.periode}" tidak sah; tulis 2025-07 atau 07/2025.`)
          kunci = `${a[0]}-${String(a[1]).padStart(2, '0')}`; acuan = kunci + '-01'; label = `${f.nama} ${namaBulan(kunci)}`; tempo = `${kunci}-${String(D.pengaturan.jatuh_tempo_hari).padStart(2, '0')}` }
        else if (f.siklus === 'tahunan') { if (!/^\d{4}\/\d{4}$/.test(per)) throw new Error(`Periode tahunan "${r.periode}" tidak sah; tulis 2024/2025.`); kunci = per; acuan = per.slice(0, 4) + '-07-01'; label = `${f.nama} ${per}`; tempo = tambahHari(acuan, 30) }
        else if (f.siklus === 'semesteran') { const z = per.match(/^(\d{4}\/\d{4})[ -]*(s1|s2|1|2|ganjil|genap)$/); if (!z) throw new Error(`Periode semesteran "${r.periode}" tidak sah; tulis 2024/2025-S1.`)
          const sm = ['s1', '1', 'ganjil'].includes(z[2]) ? 1 : 2; kunci = `${z[1]}-S${sm}`; acuan = sm === 1 ? z[1].slice(0, 4) + '-07-01' : z[1].slice(5) + '-01-01'
          label = `${f.nama} Semester ${sm === 1 ? 'Ganjil' : 'Genap'} ${z[1]}`; tempo = tambahHari(acuan, 30) }
        else { kunci = 'sekali'; acuan = r.tanggal_bayar || h; label = f.nama; tempo = acuan }
        if (acuan > h) throw new Error(`Periode ${r.periode} belum tiba.`)
        let b = D.tagihan.find((x) => x.student_id === st.id && x.fee_type_id === f.id && x.kunci_periode === kunci && x.status !== 'batal'); let hs; let ket
        if (!b) { const k = kelasPada(st, acuan); if (!k && f.siklus !== 'sekali') throw new Error(`${st.nama} belum menjadi santri pada periode ${r.periode}.`)
          const std = r.nominal !== '' && r.nominal != null ? Number(r.nominal) : tarif(f, st, k || st); const pt = r.nominal !== '' && r.nominal != null ? { potongan: 0, alasan: null } : potongan(st, f, acuan, std)
          b = { id: id(), student_id: st.id, fee_type_id: f.id, kunci_periode: kunci, nama: label, tanggal_tagih: acuan, jatuh_tempo: tempo, standar: std, potongan: pt.potongan, alasan_potongan: pt.alasan, nominal: std - pt.potongan, dibayar: 0, status: 'belum', catatan: 'Impor catatan lama' }
          segarkan(b); D.tagihan.push(b); hs = 'dibuat'; ket = `Tagihan Rp${b.nominal.toLocaleString('id-ID')} dibuat` }
        else { hs = 'ada'; ket = `Tagihan sudah ada (Rp${b.nominal.toLocaleString('id-ID')})` }
        const bayar = Number(r.dibayar) || 0
        if (bayar > 0) { if (bayar > b.nominal - b.dibayar) throw new Error(`Dibayar Rp${bayar.toLocaleString('id-ID')} melebihi sisa tagihan Rp${(b.nominal - b.dibayar).toLocaleString('id-ID')}.`)
          const tgl = r.tanggal_bayar || (tempo < h ? tempo : h)
          demo.bayar({ student_id: st.id, tanggal: tgl, cara: /^trans/i.test(r.cara || '') ? 'transfer' : 'tunai', riwayat: true, keterangan: r.keterangan || 'Impor catatan pembayaran lama', alokasi: [{ bill_id: b.id, jumlah: bayar }] })
          if (hs === 'ada') hs = 'dibayar'; ket += `; pembayaran Rp${bayar.toLocaleString('id-ID')} dicatat` }
        hasil.push({ baris: i + 1, nis: st.nis, nama: st.nama, tagihan: label, hasil: hs, ket })
      } catch (e) { hasil.push({ baris: i + 1, nis: st?.nis || r.nis, nama: st?.nama || null, tagihan: label, hasil: 'galat', ket: e.message }) }
    })
    if (salinan) { D.tagihan.splice(0, D.tagihan.length, ...salinan.t); D.bayar.splice(0, D.bayar.length, ...salinan.b) }
    return salin(hasil)
  },
  batalBayar(pid, alasan) { const py = D.bayar.find((x) => x.id === pid); if (py.status === 'batal') throw new Error('Pembayaran sudah dibatalkan.')
    for (const i of py.items) { const b = D.tagihan.find((x) => x.id === i.bill_id); b.dibayar -= i.jumlah; segarkan(b) } py.status = 'batal'; py.alasan_batal = alasan },
  pembayaran(p = {}) {
    siapkan()
    return salin(D.bayar.filter((x) => (!p.mulai || x.tanggal >= p.mulai) && (!p.akhir || x.tanggal <= p.akhir) && (!p.student_id || x.student_id === p.student_id) && (!p.cara || x.cara === p.cara) && (!p.status || x.status === p.status))
      .map(barisBayar).sort((a, b) => b.tanggal.localeCompare(a.tanggal) || b.created_at.localeCompare(a.created_at)))
  },
  kuitansi(ids) { siapkan(); return salin(D.bayar.filter((x) => ids.includes(x.id)).map((py) => ({ ...py, santri: ringkas(py.student_id),
    rincian: py.items.map((i) => { const b = D.tagihan.find((x) => x.id === i.bill_id); return { tagihan: b.nama, jatuh_tempo: b.jatuh_tempo, nominal: b.nominal, jumlah: i.jumlah, sisa: i.sisa } }),
    sisa_total: D.tagihan.filter((b) => b.student_id === py.student_id && terbuka(b)).reduce((a, b) => a + b.nominal - b.dibayar, 0),
    ttd: { ...BENDAHARA, waktu: py.created_at } }))) },
  terbitkanSurat(p) {
    siapkan(); const h = hariIniISO(); const batas = p.batas_bayar || tambahHari(h, D.pengaturan.batas_surat_hari || 7); const sampai = p.tempo_sampai || batas; const hasil = []
    for (const sid of p.student_ids || []) {
      const rinci = D.tagihan.filter((b) => b.student_id === sid && terbuka(b) && b.jatuh_tempo <= sampai).sort((a, b) => a.jatuh_tempo.localeCompare(b.jatuh_tempo))
        .map((b) => ({ bill_id: b.id, tagihan: b.nama, jatuh_tempo: b.jatuh_tempo, nominal: b.nominal, dibayar: b.dibayar, sisa: b.nominal - b.dibayar, lewat: b.jatuh_tempo < h }))
      const total = rinci.reduce((a, x) => a + x.sisa, 0); if (!total) continue
      const l = { id: id(), student_id: sid, nomor: nomor('tagihan', h), tanggal: h, batas_bayar: batas, rincian: rinci, total, catatan: p.catatan || null, kode_validasi: kode(), status: 'sah',
        dikirim_pada: null, created_at: new Date().toISOString() }
      D.surat.push(l); hasil.push({ id: l.id, student_id: sid, nomor: l.nomor, kode_validasi: l.kode_validasi, total })
    }
    return salin(hasil)
  },
  surat(ids) { siapkan(); return salin(D.surat.filter((l) => ids.includes(l.id)).map((l) => ({ ...l, santri: ringkas(l.student_id), ttd: { ...BENDAHARA, waktu: l.created_at } }))) },
  kirimSurat(lid) { const l = D.surat.find((x) => x.id === lid); if (l) l.dikirim_pada = new Date().toISOString() },
  cabutSurat(lid) { D.surat.find((x) => x.id === lid).status = 'dicabut' },
  santri(p = {}) {
    siapkan(); const h = hariIniISO()
    return salin(D.santri.map((st) => { const tg = D.tagihan.filter((b) => b.student_id === st.id && b.status !== 'batal'); const tb = tg.filter(terbuka)
      return { id: st.id, nis: st.nis, nama: st.nama, jk: st.jk, jenjang: st.jenjang, tingkat: st.tingkat, status: st.status, kelas: st.kelas, wali: st.wali,
        tagihan: tg.reduce((a, b) => a + b.nominal, 0), dibayar: tg.reduce((a, b) => a + b.dibayar, 0), sisa: tb.reduce((a, b) => a + b.nominal - b.dibayar, 0),
        lewat: tb.filter((b) => b.jatuh_tempo < h).reduce((a, b) => a + b.nominal - b.dibayar, 0), jumlah_terbuka: tb.length, tempo_tertua: tb.map((b) => b.jatuh_tempo).sort()[0] || null,
        subsidi: D.subsidi.filter((x) => x.student_id === st.id && x.aktif).length, surat_terakhir: D.surat.filter((l) => l.student_id === st.id && l.status === 'sah').map((l) => l.tanggal).sort().pop() || null } })
      .filter((r) => (r.status === 'aktif' || r.sisa > 0) && (!p.jenjang || r.jenjang === p.jenjang) && (!p.group_id || grup(p.group_id, s(r.id))) && (!p.q || r.nama.toLowerCase().includes(p.q.toLowerCase()) || r.nis.startsWith(p.q))
        && (p.status === 'tunggak' ? r.sisa > 0 : p.status === 'lewat' ? r.lewat > 0 : p.status === 'lunas' ? r.tagihan > 0 && !r.sisa : true))
      .sort((a, b) => a.nama.localeCompare(b.nama)))
  },
  rincianSantri(sid) {
    siapkan(); const st = s(sid); const h = hariIniISO()
    return salin({ santri: ringkas(sid), kontak: st.kontak.map((k) => ({ hubungan: k.hubungan, nama: k.nama, no_hp: k.no_hp, utama: k.utama })),
      tagihan: demo.tagihan({ student_id: sid }), pembayaran: demo.pembayaran({ student_id: sid }),
      subsidi: D.subsidi.filter((x) => x.student_id === sid).map((x) => ({ ...x, jenis_biaya: x.fee_type_id ? j(x.fee_type_id)?.nama : null, berlaku: x.aktif && x.mulai <= h && (!x.sampai || x.sampai >= h) })),
      surat: D.surat.filter((l) => l.student_id === sid).map((l) => ({ id: l.id, nomor: l.nomor, tanggal: l.tanggal, batas_bayar: l.batas_bayar, total: l.total, status: l.status, kode_validasi: l.kode_validasi, dikirim_pada: l.dikirim_pada })).reverse() })
  },
  posisi(tgl) {
    siapkan(); const t = tgl || hariIniISO()
    return salin(D.tagihan.filter((b) => b.status !== 'batal' && b.jatuh_tempo <= t).map((b) => {
      const bayar = D.bayar.filter((py) => py.status === 'sah' && py.tanggal <= t).flatMap((py) => py.items).filter((i) => i.bill_id === b.id).reduce((a, i) => a + i.jumlah, 0)
      const st = s(b.student_id)
      return { bill_id: b.id, student_id: st.id, nis: st.nis, nama: st.nama, jk: st.jk, jenjang: st.jenjang, tingkat: st.tingkat, kelas: st.kelas, kamar: st.kamar, halaqah: st.halaqah, wali: st.wali, status_santri: st.status,
        fee_type_id: b.fee_type_id, jenis: j(b.fee_type_id).nama, tagihan: b.nama, jatuh_tempo: b.jatuh_tempo, nominal: b.nominal, dibayar: bayar, sisa: b.nominal - bayar,
        hari_lewat: Math.round((new Date(t) - new Date(b.jatuh_tempo)) / 864e5) }
    }).filter((r) => r.sisa > 0).sort((a, b) => a.nama.localeCompare(b.nama) || a.jatuh_tempo.localeCompare(b.jatuh_tempo)))
  },
  ringkasan() {
    siapkan(); const h = hariIniISO(); const pekan = tambahHari(h, 7); const aktif = D.tagihan.filter((b) => b.status !== 'batal'); const tb = aktif.filter(terbuka)
    const sah = D.bayar.filter((py) => py.status === 'sah'); const jumlah = (a) => a.reduce((x, y) => x + y, 0)
    const bulan = Array.from({ length: 6 }, (_, i) => { const d = new Date(h.slice(0, 7) + '-01T00:00:00Z'); d.setUTCMonth(d.getUTCMonth() - 5 + i); return d.toISOString().slice(0, 7) })
    return salin({ tagihan: jumlah(aktif.map((b) => b.nominal)), dibayar: jumlah(aktif.map((b) => b.dibayar)), sisa: jumlah(tb.map((b) => b.nominal - b.dibayar)),
      lewat: jumlah(tb.filter((b) => b.jatuh_tempo < h).map((b) => b.nominal - b.dibayar)), santri_menunggak: new Set(tb.filter((b) => b.jatuh_tempo < h).map((b) => b.student_id)).size,
      tempo_pekan: tb.filter((b) => b.jatuh_tempo >= h && b.jatuh_tempo <= pekan).length, tempo_pekan_nominal: jumlah(tb.filter((b) => b.jatuh_tempo >= h && b.jatuh_tempo <= pekan).map((b) => b.nominal - b.dibayar)),
      masuk_hari_ini: jumlah(sah.filter((py) => py.tanggal === h).map((py) => py.jumlah)), transaksi_hari_ini: sah.filter((py) => py.tanggal === h).length,
      masuk_bulan_ini: jumlah(sah.filter((py) => py.tanggal.slice(0, 7) === h.slice(0, 7)).map((py) => py.jumlah)), transaksi_bulan_ini: sah.filter((py) => py.tanggal.slice(0, 7) === h.slice(0, 7)).length,
      per_jenis: D.jenis.map((f) => { const b = aktif.filter((x) => x.fee_type_id === f.id); return { fee_type_id: f.id, jenis: f.nama, siklus: f.siklus, tagihan: jumlah(b.map((x) => x.nominal)), dibayar: jumlah(b.map((x) => x.dibayar)), sisa: jumlah(b.filter(terbuka).map((x) => x.nominal - x.dibayar)) } }).filter((x) => x.tagihan > 0),
      per_bulan: bulan.map((m) => ({ bulan: m, masuk: jumlah(sah.filter((py) => py.tanggal.slice(0, 7) === m).map((py) => py.jumlah)) })),
      tempo_terdekat: tb.filter((b) => b.jatuh_tempo >= h).sort((a, b) => a.jatuh_tempo.localeCompare(b.jatuh_tempo)).slice(0, 8).map((b) => ({ bill_id: b.id, student_id: b.student_id, nama: s(b.student_id).nama, nis: s(b.student_id).nis, kelas: s(b.student_id).kelas, tagihan: b.nama, jatuh_tempo: b.jatuh_tempo, sisa: b.nominal - b.dibayar })),
      ada_penanda_tangan: true, jenis_biaya: D.jenis.filter((f) => f.aktif).length })
  },
  beranda() { const r = demo.ringkasan(); return { masuk_hari_ini: r.masuk_hari_ini, transaksi_hari_ini: r.transaksi_hari_ini, santri_menunggak: r.santri_menunggak, tempo_pekan: r.tempo_pekan, ada_penanda_tangan: true } },
}
