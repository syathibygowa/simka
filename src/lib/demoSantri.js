// SIMKA PRO | src/lib/demoSantri.js | v1.1 | Fase 4 – Perbaikan P1 (data santri lengkap) | 04/10/2026
// Data santri contoh untuk MODE DEMO. Semua nama fiktif.
const PUTRA = ['Ahmad Fauzan', 'Muhammad Rafi', 'Abdullah Hanif', 'Umar Al-Faruq', 'Hamzah Ramadhan', 'Zaid Abdurrahman', 'Ilham Akbar',
  'Fathir Alfarizi', 'Yahya Habibi', 'Salman Alfarisi', 'Bilal Hakim', 'Khalid Syahputra', 'Rasyid Ridha', 'Hasan Basyir']
const PUTRI = ['Aisyah Nurul Huda', 'Fatimah Azzahra', 'Khadijah Salsabila', 'Zainab Humaira', 'Maryam Hafizah', 'Hafshah Nabila',
  'Ruqayyah Aulia', 'Sumayyah Khairunnisa', 'Asma Az-Zahra', 'Nusaibah Rahmah']
const AYAH = ['Fauzi', 'Rahman', 'Hasanuddin', 'Syamsuddin', 'Abdul Rahim', 'Muhammad Arif', 'Baharuddin', 'Jamaluddin', 'Kamaruddin', 'Muhlis']
const IBU = ['Siti Aminah', 'Nurhayati', 'Hasnah', 'Rosmini', 'St. Hadijah', 'Nuraeni', 'Hamsiah', 'Masniah', 'Rahmawati', 'Suriani']
const KOTA = ['Gowa', 'Makassar', 'Maros', 'Takalar', 'Bulukumba', 'Bone', 'Jeneponto', 'Sinjai']

function buat() {
  const semua = []
  const tambah = (nama, jk, i) => {
    const tingkat = [7, 7, 8, 8, 9, 10, 10, 11, 12][i % 9]
    const jenjang = tingkat >= 10 ? 'sma' : 'wustha'
    const masuk = 2026 - (tingkat >= 10 ? tingkat - 10 : tingkat - 7)
    const angkatan = masuk - 2011
    const nis = `${String(masuk).slice(2)}${String(angkatan).padStart(2, '0')}${String(semua.filter((s) => s.nis.startsWith(`${String(masuk).slice(2)}${String(angkatan).padStart(2, '0')}`)).length + 1).padStart(3, '0')}`
    const lahir = `${masuk - 13 + (jenjang === 'sma' ? -3 : 0)}-${String((i % 12) + 1).padStart(2, '0')}-${String((i * 3) % 27 + 1).padStart(2, '0')}`
    const a = i % AYAH.length
    const kontak = [
      { hubungan: 'ayah', nama: AYAH[a], no_hp: `0812${String(3400000 + i * 7919).slice(0, 7)}`, pekerjaan: ['Wiraswasta', 'PNS', 'Petani', 'Guru', 'Pedagang'][i % 5], utama: !(i % 4 === 0 && i % 3 !== 0) },
      { hubungan: 'ibu', nama: IBU[a], no_hp: i % 3 ? `0853${String(6100000 + i * 6007).slice(0, 7)}` : null, pekerjaan: 'Ibu rumah tangga', utama: i % 4 === 0 && i % 3 !== 0 },
    ]
    const pindahan = i % 11 === 5
    semua.push({
      id: `s${semua.length + 1}`, nis, nisn: i % 5 === 3 ? null : `00${String(98765432 - i * 1371).padStart(8, '0')}`,
      nik: null, nama_lengkap: nama, nama_panggilan: nama.split(' ')[0], jenis_kelamin: jk,
      tempat_lahir: i % 13 === 7 ? null : KOTA[i % KOTA.length], tanggal_lahir: lahir, jenjang, tingkat, tahun_masuk: masuk, angkatan,
      tanggal_masuk: `${masuk}-07-13`, jalur_masuk: pindahan ? 'pindahan' : 'baru',
      asal_sekolah: pindahan ? 'SMP Negeri 2 Sungguminasa' : (jenjang === 'sma' ? 'SMP IT Wahdah' : 'SD Inpres Bontoramba'),
      hafalan_awal_juz: pindahan ? 2 : null, anak_ke: (i % 4) + 1, alamat: `Jl. Poros Malino No. ${i + 3}`, rt: String((i % 6) + 1).padStart(3, '0'), rw: String((i % 4) + 1).padStart(3, '0'),
      kelurahan: ['Bontoramba', 'Samata', 'Paccinongang', 'Romang Polong'][i % 4], kecamatan: i % 3 ? 'Somba Opu' : 'Pallangga', kota_kab: `Kabupaten ${KOTA[i % KOTA.length]}`,
      provinsi: 'Sulawesi Selatan', no_kk: i % 4 === 1 ? null : `7306${String(100000000000 + i * 7919).slice(0, 12)}`,
      status: i === 20 ? 'nonaktif' : i === 22 ? 'mutasi_keluar' : 'aktif', status_sejak: '2026-07-13', catatan: null,
      nama_jenjang: jenjang === 'sma' ? 'SMA' : 'Kesetaraan Wustha', kontak,
    })
  }
  PUTRA.forEach((n, i) => tambah(n, 'L', i))
  PUTRI.forEach((n, i) => tambah(n, 'P', i + PUTRA.length))
  return semua
}
export const SANTRI_DEMO = buat

export const RIWAYAT_SANTRI_DEMO = (s) => ({
  status: [
    { id: 'h1', status_lama: null, status_baru: 'aktif', tanggal: s.tanggal_masuk, alasan: s.jalur_masuk === 'pindahan' ? `Santri pindahan dari ${s.asal_sekolah}` : 'Santri baru', nama_oleh: 'Admin SIMKA' },
    ...(s.status !== 'aktif' ? [{ id: 'h2', status_lama: 'aktif', status_baru: s.status, tanggal: '2026-09-15', alasan: s.status === 'nonaktif' ? 'Dirawat di rumah karena sakit (contoh)' : 'Mutasi keluar ke Pondok Pesantren Darul Huffadz: ikut orang tua pindah tugas', nama_oleh: 'Ust. Fadhil Rahman, S.Kom.' }] : []),
  ],
  mutasi: [
    ...(s.jalur_masuk === 'pindahan' ? [{ id: 'm1', jenis: 'masuk', tanggal: s.tanggal_masuk, sekolah: s.asal_sekolah, tingkat: s.tingkat, jenjang: s.jenjang, hafalan_juz: s.hafalan_awal_juz }] : []),
    ...(s.status === 'mutasi_keluar' ? [{ id: 'm2', jenis: 'keluar', tanggal: '2026-09-15', sekolah: 'Pondok Pesantren Darul Huffadz', alasan: 'Ikut orang tua pindah tugas', tingkat: s.tingkat, jenjang: s.jenjang, nomor_surat: 'K.001/IL/KW-IAS/III/1448', kop: s.jenjang }] : []),
  ],
})
