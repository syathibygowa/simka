// SIMKA PRO | src/lib/demoKlinik.js | v1.1 | Fase 6 – Tahap 3 Jurnal musyrif dan klinik lanjutan | 06/10/2026
// Data klinik contoh untuk MODE DEMO (semua fiktif). Disusun sekali dari daftar santri demo.
import { PENGATURAN_KLINIK_BAWAAN } from './klinik'

let D = null
const jamLalu = (j) => new Date(Date.now() - j * 3600000).toISOString()
const jamDepan = (j) => new Date(Date.now() + j * 3600000).toISOString()
const tglWITA = (iso) => new Date(new Date(iso).getTime() + 8 * 3600000).toISOString().slice(0, 10)

export function dataKlinikDemo(santri = []) {
  if (D) return D
  const aktif = santri.filter((s) => s.status === 'aktif')
  const putra = aktif.filter((s) => s.jenis_kelamin === 'L'); const putri = aktif.filter((s) => s.jenis_kelamin === 'P')
  D = {
    pengaturan: PENGATURAN_KLINIK_BAWAAN(),
    petugas: [
      { id: 'kp1', employee_id: 'p4', nama: 'Ustzh. Fatimah Az-Zahra, A.Md.Kep.', niy: '2021080104', jenis_kelamin: 'P', no_hp: '081342210004', klinik: 'putri', aktif: true, catatan: 'Isi awal dari jabatan Petugas kesehatan', punya_akun: true },
      { id: 'kp2', employee_id: 'p17', nama: 'Ustzh. Siti Rahmah, A.Md.Kep.', niy: '2023080117', jenis_kelamin: 'P', no_hp: '081342210017', klinik: 'putri', aktif: true, catatan: 'Isi awal dari jabatan Petugas kesehatan', punya_akun: true },
      { id: 'kp3', employee_id: 'p17', nama: 'Ustzh. Siti Rahmah, A.Md.Kep.', niy: '2023080117', jenis_kelamin: 'P', no_hp: '081342210017', klinik: 'putra', aktif: true, catatan: 'Membantu klinik putra sementara', punya_akun: true },
    ],
    kasus: [], rujukan: [], periksa: [], jejak: [],
  }
  const buat = (s, o) => {
    const id = 'kk' + (D.kasus.length + 1)
    D.kasus.push({ id, student_id: s.id, klinik: s.jenis_kelamin === 'P' ? 'putri' : 'putra', status: 'menunggu', tindak_lanjut: null, sumber: 'pengasuh',
      dibuka_oleh: 'p3', sakit_mulai: null, kontrol_pada: null, selesai_pada: null, hasil: null, catatan_selesai: null, ...o, id })
    D.rujukan.push({ case_id: id, student_id: s.id, sumber: o.sumber || 'pengasuh', keluhan: o.keluhan, waktu_periksa: o.waktu_periksa || 'hari_ini',
      batas_waktu: o.batas_waktu, dirujuk_pada: o.dibuka_pada, perujuk: o.perujuk || 'Ust. Muhammad Ikhsan, S.Pd.I.', dirujuk_oleh: o.perujuk_id || 'p3' })
    D.jejak.push({ case_id: id, jenis: 'rujukan', isi: `Dirujuk: ${o.keluhan}`, pada: o.dibuka_pada, oleh: o.perujuk || 'Ust. Muhammad Ikhsan, S.Pd.I.' })
    return id
  }
  const periksa = (id, s, v) => {
    D.periksa.push({ id: 'kv' + (D.periksa.length + 1), case_id: id, student_id: s.id, jenis: 'pemeriksaan', petugas: 'Ustzh. Siti Rahmah, A.Md.Kep.', ...v })
    D.jejak.push({ case_id: id, jenis: 'pemeriksaan', isi: `Pemeriksaan: ${v.tl}`, pada: v.waktu, oleh: 'Ustzh. Siti Rahmah, A.Md.Kep.' })
  }
  if (putra[1]) buat(putra[1], { keluhan: 'Demam sejak semalam, pusing', dibuka_pada: jamLalu(3), batas_waktu: jamLalu(1) })
  if (putra[4]) buat(putra[4], { keluhan: 'Sakit perut setelah makan malam', dibuka_pada: jamLalu(0.5), batas_waktu: jamDepan(1.5), perujuk: 'Ust. Hasan Basri, Lc.', perujuk_id: 'd-pg' })
  if (putri[2]) buat(putri[2], { keluhan: 'Batuk pilek, tenggorokan sakit', dibuka_pada: jamLalu(1), batas_waktu: jamDepan(1), perujuk: 'Ustzh. Nurul Aini, S.Pd.', perujuk_id: 'p2' })
  if (putri[5]) buat(putri[5], { keluhan: 'Kontrol luka di kaki', dibuka_pada: jamLalu(14), batas_waktu: jamDepan(5), waktu_periksa: 'besok', sumber: 'pengasuh' })
  if (putra[7]) {
    const id = buat(putra[7], { keluhan: 'Demam tinggi dan menggigil', dibuka_pada: jamLalu(26), batas_waktu: jamLalu(24) })
    periksa(id, putra[7], { waktu: jamLalu(25), keluhan: 'Demam 2 hari, menggigil', pemeriksaan: 'Suhu 38,7 °C; nadi 96×/menit', diagnosis: 'Febris (suspek ISPA)',
      tindakan: 'Kompres, banyak minum', obat: 'Parasetamol 500 mg 3×1, vitamin C', tindak_lanjut: 'rawat', tl: 'Rawat di klinik', kontrol_pada: jamDepan(2), catatan: 'Pantau suhu tiap 4 jam' })
    Object.assign(D.kasus.at(-1), { status: 'ditangani', tindak_lanjut: 'rawat', sakit_mulai: tglWITA(jamLalu(25)), kontrol_pada: jamDepan(2) })
  }
  if (putri[0]) {
    const id = buat(putri[0], { keluhan: 'Nyeri haid berat', dibuka_pada: jamLalu(5), batas_waktu: jamLalu(3), perujuk: 'Ustzh. Nurul Aini, S.Pd.', perujuk_id: 'p2' })
    periksa(id, putri[0], { waktu: jamLalu(4.5), keluhan: 'Nyeri perut bawah', pemeriksaan: 'TD 110/70', diagnosis: 'Dismenore', tindakan: 'Kompres hangat', obat: 'Asam mefenamat 500 mg bila nyeri',
      tindak_lanjut: 'istirahat', tl: 'Istirahat di kamar', kontrol_pada: null, catatan: '' })
    Object.assign(D.kasus.at(-1), { status: 'ditangani', tindak_lanjut: 'istirahat', sakit_mulai: tglWITA(jamLalu(4.5)) })
  }
  ;[[putra[2], 'Luka gores di tangan', 'kembali', 50], [putra[9], 'Sakit gigi', 'sembuh', 74], [putri[4], 'Pusing', 'sembuh', 120], [putra[3], 'Gatal-gatal', 'kembali', 170]]
    .forEach(([s, keluhan, hasil, j]) => {
      if (!s) return
      const id = buat(s, { keluhan, dibuka_pada: jamLalu(j), batas_waktu: jamLalu(j - 2), sumber: hasil === 'kembali' ? 'datang_sendiri' : 'pengasuh' })
      periksa(id, s, { waktu: jamLalu(j - 1), keluhan, pemeriksaan: 'Tanda vital normal', diagnosis: keluhan, tindakan: 'Penanganan ringan', obat: '', tindak_lanjut: hasil === 'kembali' ? 'kembali' : 'istirahat',
        tl: hasil === 'kembali' ? 'Kembali beraktivitas' : 'Istirahat di kamar', kontrol_pada: null, catatan: '' })
      Object.assign(D.kasus.at(-1), { status: 'selesai', hasil, tindak_lanjut: hasil === 'kembali' ? 'kembali' : 'istirahat', selesai_pada: jamLalu(j - 20) })
    })
  return D
}
