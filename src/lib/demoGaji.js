// SIMKA PRO | src/lib/demoGaji.js | v1.3 | Fase 11 – Tahap 5 Pengingat kenaikan, ringkasan Beranda, dan pembanding bulan lalu di mode demo | 11/10/2026
// Tiruan sederhana fungsi server periode gaji (migrasi 7100) agar tampilan dapat dicoba tanpa Supabase.
// Logika sama: komponen skema → honor (honorer) → komponen yang diubah dipertahankan → penyesuaian dari
// jumlah diterima yang ditetapkan atau penetapan yayasan.
import { petaTarif, hitungTunjangan } from './tunjangan'

const D = { periode: [], baris: {}, penetapan: [], pinjaman: [], minta: [], program: [{ id: 'sp1', nama: 'Umrah', keterangan: 'Tabungan program umrah pegawai', setoran_bawaan: 100000, aktif: true, anggota: [] }, { id: 'sp2', nama: 'Kurban', keterangan: 'Tabungan kurban Iduladha', setoran_bawaan: 50000, aktif: true, anggota: [] }], urut: 1 }
const saldo = (a) => a.riwayat.reduce((x, t) => x + (t.jenis === 'pencairan' ? -t.besaran : t.besaran), 0)
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
  // Perkiraan kehadiran tugas (contoh) dan potongan bila sakelar aktif
  const hadir = []
  for (const f of item.filter((i) => i.kategori === 'fungsional')) {
    const wajib = 24, tanpa = (p.nama_lengkap.length + f.label.length) % 4
    const perk = Math.round(f.besaran * tanpa / wajib / 100) * 100
    hadir.push({ kode: f.label, tugas: f.label.replace(/^Tunjangan /, ''), sumber: 'Absensi (contoh)', satuan: 'sesi', wajib, terlaksana: wajib - tanpa, berizin: 0, tanpa, tunjangan: f.besaran, perkiraan: perk })
    if (ctx.pengaturan.potong_kehadiran && perk) {
      const u = lama.find((x) => x.kategori === 'potongan_kehadiran' && x.kode === f.label)
      item.push({ id: u?.id || id(), jenis: 'potongan', kategori: 'potongan_kehadiran', kode: f.label, label: 'Potongan kehadiran ' + f.label.replace(/^Tunjangan /, ''), jumlah: tanpa,
        besaran_skema: perk, besaran: u ? u.besaran : perk, sumber: u ? 'manual' : 'skema', alasan: u?.alasan, urutan: 110, rincian: hadir[hadir.length - 1] })
    }
  }
  for (const pj of D.pinjaman.filter((x) => x.employee_id === p.id && x.status === 'aktif' && x.mulai_potong <= pr.tanggal_akhir)) {
    const sisa = pj.pokok - pj.riwayat.reduce((a, r) => a + r.besaran, 0); if (sisa <= 0) continue
    const u = lama.find((x) => x.kategori === 'pinjaman' && x.kode === pj.id)
    item.push({ id: u?.id || id(), jenis: 'potongan', kategori: 'pinjaman', kode: pj.id, label: 'Cicilan pinjaman' + (pj.keterangan ? ' – ' + pj.keterangan : ''),
      besaran_skema: Math.min(pj.cicilan, sisa), besaran: u ? u.besaran : Math.min(pj.cicilan, sisa), sumber: u ? 'manual' : 'skema', alasan: u?.alasan, urutan: 120, rincian: { sisa_sebelum: sisa } })
  }
  for (const pg of D.program.filter((x) => x.aktif)) for (const a of pg.anggota.filter((x) => x.employee_id === p.id && x.aktif && x.setoran > 0)) {
    const u = lama.find((x) => x.kategori === 'simpanan' && x.kode === pg.id)
    item.push({ id: u?.id || id(), jenis: 'potongan', kategori: 'simpanan', kode: pg.id, label: 'Simpanan ' + pg.nama, besaran_skema: a.setoran, besaran: u ? u.besaran : a.setoran,
      sumber: u ? 'manual' : 'skema', alasan: u?.alasan, urutan: 130, rincian: { saldo_sebelum: saldo(a) } })
  }
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
  l.data = dataPegawai(p, pr.tanggal_akhir); l.data.kehadiran = hadir; l.data.catatan.push(...h.catatan.filter((c) => /belum diatur|belum diisi/.test(c)))
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
const BULAN_D = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember']
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
  rincian(pid) {
    const pr = D.periode.find((x) => x.id === pid)
    const lalu = pr && D.periode.filter((x) => x.tahun * 12 + x.bulan < pr.tahun * 12 + pr.bulan).sort((a, b) => b.tahun - a.tahun || b.bulan - a.bulan)[0]
    const bl = (l) => { const x = lalu && D.baris[lalu.id].find((y) => y.employee_id === l.employee_id)
      return x ? { periode: `${BULAN_D[lalu.bulan - 1]} ${lalu.tahun}`, diterima: x.diterima, skema: x.total_skema, pendapatan: x.total_pendapatan, potongan: x.total_potongan } : null }
    return JSON.parse(JSON.stringify({ periode: pr, ttd: pr?.ttd || [], baris: [...(D.baris[pid] || [])].map((l) => ({ ...l, bulan_lalu: bl(l) })).sort((a, b) => a.data.nama.localeCompare(b.data.nama)) }))
  },
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
  ajukan(pid, peng) {
    const pr = D.periode.find((x) => x.id === pid); const w = new Date().toISOString()
    pr.ttd = [{ peran: 'bendahara', nama: 'Ust. Rizal Fahmi, S.E.', jabatan: 'Bendahara', niy: '2016010208', status: 'ditandatangani', waktu: w }]
    if (peng.ttd_direktur) pr.ttd.push({ peran: 'direktur', nama: 'Ust. Ahmad Fauzan, Lc., M.A.', jabatan: 'Direktur (Mudir)', niy: '2010010101', status: 'ditandatangani', waktu: w })
    D.baris[pid].forEach((l, i) => Object.assign(l, { nomor_slip: `SLIP.${String(i + 1).padStart(3, '0')}/PPTQ-IAS/${pr.bulan}/${pr.tahun}`, kode_validasi: 'DM' + String(i).padStart(2, '0') + '-7KQ2', diterbitkan_pada: w, revisi_ke: 0, riwayat: [] }))
    pr.status = 'terbit'; pr.diterbitkan_pada = w; return 'terbit'
  },
  tandatangani: () => 'terbit',
  tarik(pid) { D.periode.find((x) => x.id === pid).status = 'draf' },
  mulaiRevisi(lid, alasan) { const l = cariBaris(lid); l.riwayat = [...(l.riwayat || []), { revisi_ke: l.revisi_ke, kode: l.kode_validasi, diterima: l.diterima, alasan_revisi: alasan }]; l.revisi_ke++; l.dalam_revisi = true; l.alasan_revisi = alasan },
  terbitkanRevisi(lid) { const l = cariBaris(lid); l.dalam_revisi = false; l.kode_validasi = 'DR' + l.revisi_ke + '0-9HRX'; l.diterbitkan_pada = new Date().toISOString() },
  batalkanRevisi(lid) { const l = cariBaris(lid); l.dalam_revisi = false; l.revisi_ke--; l.riwayat.pop() },
  tutupSlip(lid) { cariBaris(lid).dibuka_pegawai = false },
  slip(lid) { const l = cariBaris(lid); const pr = D.periode.find((x) => x.id === l.period_id); return JSON.parse(JSON.stringify({ ...l, periode: pr, ttd: pr.ttd || [] })) },
  slipSaya(peng) {
    const daftar = []
    for (const pr of D.periode.filter((x) => x.status === 'terbit')) {
      const l = (D.baris[pr.id] || [])[0]; if (l && (peng.slip_pegawai || l.dibuka_pegawai)) daftar.push(demoGaji.slip(l.id))
    }
    return { slip: daftar, terbuka: peng.slip_pegawai || daftar.length > 0, pengaturan: peng, pinjaman: [], simpanan: [], permintaan: D.minta.map((x) => ({ ...x })) }
  },
  periodeSaya: () => D.periode.filter((x) => x.status === 'terbit').map((x) => ({ id: x.id, nama: `${['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'][x.bulan - 1]} ${x.tahun}` })),
  minta(pid, catatan) { D.minta.unshift({ id: id(), employee_id: 'p1', niy: '2019070101', nama: 'Ust. Hasan Basri, Lc.', period_id: pid, periode: demoGaji.periodeSaya().find((x) => x.id === pid)?.nama, catatan, status: 'menunggu', created_at: new Date().toISOString() }) },
  permintaan: () => JSON.parse(JSON.stringify(D.minta)),
  tanggapi(rid, aksi, catatan) {
    const r = D.minta.find((x) => x.id === rid); r.status = { buka: 'dibuka', cetak: 'dicetak', tolak: 'ditolak' }[aksi]; r.tanggapan = catatan
    if (aksi === 'buka') for (const pr of D.periode.filter((x) => x.status === 'terbit')) { const l = (D.baris[pr.id] || [])[0]; if (l) l.dibuka_pegawai = true }
  },
  pengingat(bulan, ctx) {
    const b = (bulan || new Date().toISOString().slice(0, 10)).slice(0, 7); const [th, bl] = b.split('-').map(Number)
    const tarif = petaTarif(ctx.tarif, b + '-28')
    const mk = ctx.pegawai.filter((p) => p.tmt_tugas && p.status_kepegawaian !== 'honorer' && Number(p.tmt_tugas.slice(5, 7)) === bl && th - Number(p.tmt_tugas.slice(0, 4)) >= 1 && th - Number(p.tmt_tugas.slice(0, 4)) <= 12)
      .map((p) => { const n = th - Number(p.tmt_tugas.slice(0, 4)); const lama = Number(tarif.masa_kerja?.[String(n - 1)]?.besaran || 0), baru = Number(tarif.masa_kerja?.[String(n)]?.besaran || 0)
        return { employee_id: p.id, niy: p.niy, nama: p.nama_lengkap, tmt: p.tmt_tugas, tanggal: `${b}-${p.tmt_tugas.slice(8, 10)}`, tahun_baru: n, tarif_lama: lama, tarif_baru: baru, selisih: baru - lama } })
    return { bulan: b + '-01', masa_kerja: mk, perubahan: [
      { employee_id: 'p2', niy: '2020071502', nama: 'Ustzh. Nurul Aini, S.Pd.', jenis: 'pendidikan', nilai_lama: 'S1', nilai_baru: 'S2', dicatat: new Date().toISOString(), oleh: 'Superadmin SIMKA' },
      { employee_id: 'p11', niy: '2020011511', nama: 'Ust. Ilham Saputra, S.Sos.', jenis: 'status_kepegawaian', nilai_lama: 'kontrak', nilai_baru: 'tetap', dicatat: new Date(Date.now() - 864e6).toISOString(), oleh: 'Superadmin SIMKA' }] }
  },
  ringkasanBeranda() {
    const pr = [...D.periode].sort((a, b) => b.tahun - a.tahun || b.bulan - a.bulan)[0]
    return { ttd_menunggu: 0, kelola: true, periode: pr ? { id: pr.id, nama: `${BULAN_D[pr.bulan - 1]} ${pr.tahun}`, status: pr.status } : null, periode_bulan_ini: !!pr,
      permintaan: D.minta.filter((x) => x.status === 'menunggu').length, naik_bulan_ini: 1, naik_bulan_depan: 2, perubahan: 2 }
  },
  hapusPenetapan(pid) { D.penetapan = D.penetapan.filter((x) => x.id !== pid) },
  pinjaman: () => JSON.parse(JSON.stringify(D.pinjaman.map((x) => { const n = x.riwayat.reduce((a, r) => a + r.besaran, 0); return { ...x, dibayar: n, sisa: x.pokok - n } }))),
  simpanPinjaman(isi, ctx) {
    const p = ctx.pegawai.find((x) => x.id === isi.employee_id)
    const i = D.pinjaman.findIndex((x) => x.id === isi.id)
    if (i >= 0) Object.assign(D.pinjaman[i], { ...isi, pokok: Number(isi.pokok), cicilan: Number(isi.cicilan) })
    else D.pinjaman.push({ ...isi, id: id(), pokok: Number(isi.pokok), cicilan: Number(isi.cicilan), niy: p?.niy, nama: p?.nama_lengkap, status: 'aktif', riwayat: [] })
  },
  bayarPinjaman(pid, besaran, tanggal, ket) {
    const x = D.pinjaman.find((y) => y.id === pid); x.riwayat.push({ tanggal: tanggal || new Date().toISOString().slice(0, 10), besaran: Number(besaran), keterangan: ket || 'Pembayaran di luar gaji' })
    if (x.pokok - x.riwayat.reduce((a, r) => a + r.besaran, 0) <= 0) x.status = 'lunas'
  },
  batalkanPinjaman(pid) { const x = D.pinjaman.find((y) => y.id === pid); x.status = x.riwayat.length ? 'lunas' : 'batal' },
  simpanan: () => JSON.parse(JSON.stringify(D.program.map((pg) => ({ ...pg, anggota: pg.anggota.map((a) => ({ ...a, saldo: saldo(a) })), saldo: pg.anggota.reduce((x, a) => x + saldo(a), 0) })))),
  simpanProgram(isi) { const i = D.program.findIndex((x) => x.id === isi.id); if (i >= 0) Object.assign(D.program[i], isi); else D.program.push({ ...isi, id: id(), aktif: true, anggota: [] }) },
  simpanAnggota(isi, ctx) {
    const pg = D.program.find((x) => x.id === isi.program_id); const p = ctx.pegawai.find((x) => x.id === isi.employee_id)
    const a = pg.anggota.find((x) => x.employee_id === isi.employee_id)
    if (a) Object.assign(a, { ...isi, setoran: Number(isi.setoran) }); else pg.anggota.push({ ...isi, setoran: Number(isi.setoran), aktif: isi.aktif !== false, niy: p?.niy, nama: p?.nama_lengkap, riwayat: [] })
  },
  catatTransaksi(isi) {
    const a = D.program.find((x) => x.id === isi.program_id).anggota.find((x) => x.employee_id === isi.employee_id)
    if (isi.jenis === 'pencairan' && Number(isi.besaran) > saldo(a)) throw new Error('Pencairan melebihi saldo.')
    a.riwayat.unshift({ tanggal: isi.tanggal || new Date().toISOString().slice(0, 10), jenis: isi.jenis, besaran: Number(isi.besaran), keterangan: isi.keterangan || 'Saldo awal' })
  },
}
