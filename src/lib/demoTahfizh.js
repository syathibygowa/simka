// SIMKA PRO | src/lib/demoTahfizh.js | v1.0 | Fase 5 – Tahap 1 Pengaturan tahfizh dan data hafalan awal | 05/10/2026
// Pengaturan dan data hafalan contoh untuk MODE DEMO (mengikuti isi awal migrasi 3800). Semua data fiktif.
const TA = 'ta1'
const BULAN = ['2026-07-01', '2026-08-01', '2026-09-01', '2026-10-01', '2026-11-01', '2026-12-01',
  '2027-01-01', '2027-02-01', '2027-03-01', '2027-04-01', '2027-05-01', '2027-06-01']

let data = null
export function dataTahfizhDemo() {
  if (data) return data
  const pengaturan = { academic_year_id: TA, kkm: 80, bobot_tajwid: 50, bobot_itqan: 50, batas_lonjakan_hal: 10, rekap_sangat_memuaskan: 90, rekap_memuaskan: 75, catatan: null }
  const predikat = [
    { huruf: 'A', nilai_min: 94, nilai_maks: 100, deskripsi_rapor: 'Mumtaz (Istimewa)', deskripsi_sertifikat: 'Pujian', catatan_akhir: 'Kemampuan ananda sangat baik, selamat atas pencapaiannya, semangat menghafal dan capaian hafalannya dipertahankan!' },
    { huruf: 'B', nilai_min: 87, nilai_maks: 93.99, deskripsi_rapor: 'Jayyid Jiddan (Sangat Baik)', deskripsi_sertifikat: 'Sangat Memuaskan', catatan_akhir: 'Selamat atas pencapaiannya, semangat menghafal dan capaian hafalannya ditingkatkan lagi!' },
    { huruf: 'C', nilai_min: 80, nilai_maks: 86.99, deskripsi_rapor: 'Jayyid (Baik)', deskripsi_sertifikat: 'Memuaskan', catatan_akhir: 'Semangat menghafal dan capaian hafalannya lebih ditingkatkan lagi!' },
    { huruf: 'D', nilai_min: 0, nilai_maks: 79.99, deskripsi_rapor: 'Maqbul (Cukup)', deskripsi_sertifikat: 'Cukup Memuaskan', catatan_akhir: 'Tingkatkan semangat menghafalnya!' },
  ].map((p, i) => ({ ...p, id: 'pr' + i, academic_year_id: TA, urutan: i + 1 }))
  const target = []
  for (const program of ['reguler', 'takhassus']) {
    for (let tingkat = 7; tingkat <= 12; tingkat++) {
      const tk = program === 'takhassus'
      target.push({ academic_year_id: TA, program, tingkat, pekan_hal: tk ? 10 : 5, bulan_hal: tk ? 40 : 20, semester_hal: tk ? 200 : 100, tahun_hal: tk ? 400 : 200 })
    }
  }
  const bulan = BULAN.map((b, i) => ({ academic_year_id: TA, bulan: b, semester: i < 6 ? 1 : 2, pekan_efektif: i === 0 ? 2 : 4, manual: false, hari_aktif: i === 0 ? 16 : 26 }))
  const penguji = [{ id: 'x1', jenis: 'kenaikan', employee_id: 'p12', aktif: true, catatan: 'Koordinator halaqah putra' }]
  data = { pengaturan, predikat, target, bulan, penguji, santri: {}, juz: {} }
  return data
}

/** Posisi dan juz contoh per santri (dibangun sekali dari urutan santri contoh). */
export function isiSantriDemo(daftarSantri) {
  const d = dataTahfizhDemo()
  if (Object.keys(d.santri).length) return d
  daftarSantri.forEach((s, i) => {
    if (i % 10 === 7) return // belum terdata
    const resmi = [0, 1, 2, 3, 5, 6, 8, 11, 15, 30][i % 10]
    const urutJuz = i % 3 === 0 ? [30, 29, 28, 27, 26, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25]
      : Array.from({ length: 30 }, (_, k) => k + 1)
    const juz = urutJuz.slice(0, resmi)
    const sabaq = Math.min(600, resmi * 20 + ((i * 7) % 18))
    d.santri[s.id] = {
      program: s.tingkat >= 10 && i % 4 === 0 ? 'takhassus' : 'reguler', sabaq_hal: sabaq, sabqi_hal: Math.max(0, sabaq - 15 - (i % 5)), manzil_hal: Math.max(0, Math.floor(sabaq / 2)),
      juz_sedang: resmi >= 30 || !sabaq ? null : urutJuz[resmi], posisi_pada: '2026-07-20T08:00:00+08:00', posisi_sumber: 'awal',
    }
    d.juz[s.id] = juz.map((j) => ({ juz: j, sumber: 'awal' }))
  })
  return d
}
