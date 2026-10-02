// Data contoh untuk MODE DEMO. Nama pegawai di bawah fiktif.
const menitLalu = (m) => new Date(Date.now() - m * 60000).toISOString()

export const PENGGUNA_DEMO = {
  superadmin: { id: 'd-sa', nama_lengkap: 'Superadmin SIMKA', username: 'superadmin', peran: 'superadmin', jabatan: 'Superadmin sistem', nama_unit: 'Pimpinan Pondok', jenis_kelamin: 'L' },
  admin:      { id: 'd-ad', nama_lengkap: 'Ust. Fadhil Rahman, S.Kom.', username: 'fadhil', peran: 'admin', jabatan: 'Operator, Admin kepegawaian', nama_unit: 'Bidang Umum', jenis_kelamin: 'L' },
  pegawai:    { id: 'd-pg', nama_lengkap: 'Ust. Hasan Basri, Lc.', username: 'hasanbasri', peran: 'pegawai', jabatan: 'Muhaffizh, Wali kelas', nama_unit: 'Bidang Tahfizh', jenis_kelamin: 'L' },
}

export const PEGAWAI_DEMO = [
  ['Ust. Hasan Basri, Lc.', '2019070101', 'L', 'Bidang Tahfizh', ['Muhaffizh', 'Wali kelas'], null, 'tetap', 'aktif', '2019-07-01'],
  ['Ustzh. Nurul Aini, S.Pd.', '2020071502', 'P', 'Bidang Kesetaraan Wustha', ['Guru mapel', 'Wali kelas'], null, 'tetap', 'aktif', '2020-07-15'],
  ['Ust. Muhammad Ikhsan, S.Pd.I.', '2018010303', 'L', 'Bidang Kesantrian', ['Musyrif'], 'Kepala Bidang', 'tetap', 'aktif', '2018-01-03'],
  ['Ustzh. Fatimah Az-Zahra, A.Md.Kep.', '2021080104', 'P', 'Unit Klinik', ['Petugas kesehatan'], null, 'kontrak', 'aktif', '2021-08-01'],
  ['Ust. Abdul Hakim', '2022020105', 'L', 'Unit Security', ['Petugas keamanan'], null, 'honorer', 'aktif', '2022-02-01'],
  ['Ust. Yusuf Maulana, S.Pd.', '2023071006', 'L', 'Bidang SMA', ['Guru mapel', 'Pembina ekskul'], null, 'kontrak', 'menunggu', '2023-07-10'],
  ['Ustzh. Khadijah Ramadhani, S.Ag.', '2017071507', 'P', 'Bidang Tahfizh', ['Muhaffizh'], 'Wakil Kepala Bidang', 'tetap', 'aktif', '2017-07-15'],
  ['Ust. Rizal Fahmi, S.E.', '2016010208', 'L', 'Pimpinan Pondok', ['Staf bidang'], 'Bendahara', 'tetap', 'aktif', '2016-01-02'],
  ['Ust. Ahmad Zaki', null, 'L', 'Bidang Sarana', ['Petugas sarpras'], null, 'honorer', 'tanpa_akun', '2024-03-01'],
  ['Ustzh. Aisyah Putri, S.Pd.', '2024071010', 'P', 'Bidang Bahasa', ['Guru mapel'], null, 'honorer', 'menunggu', '2024-07-10'],
  ['Ust. Ilham Saputra, S.Sos.', '2020011511', 'L', 'Bidang Media', ['Petugas media'], null, 'kontrak', 'aktif', '2020-01-15'],
  ['Ust. Syamsul Arifin, S.Pd.', '2019071512', 'L', 'Bidang Kesetaraan Wustha', ['Guru mapel', 'Musyrif'], null, 'tetap', 'aktif', '2019-07-15'],
].map(([nama_lengkap, niy, jenis_kelamin, nama_unit, jabatan_fungsional, jabatan_struktural, status_kepegawaian, status_akun, tmt_tugas], i) => ({
  id: `p${i + 1}`, nama_lengkap, niy, jenis_kelamin, nama_unit, jabatan_fungsional, jabatan_struktural,
  status_kepegawaian, status_akun, status_keaktifan: 'aktif', tmt_tugas,
}))

export const NOTIFIKASI_DEMO = {
  superadmin: [
    { judul: 'Pendaftaran pegawai baru', isi: 'Ustzh. Aisyah Putri, S.Pd. menunggu verifikasi akun.', tautan: '/pegawai/p10', ikon: 'UserPlus', warna: 'biru', menit: 6 },
    { judul: 'Pendaftaran pegawai baru', isi: 'Ust. Yusuf Maulana, S.Pd. menunggu verifikasi akun.', tautan: '/pegawai/p6', ikon: 'UserPlus', warna: 'biru', menit: 52 },
    { judul: 'Periksa kop surat', isi: 'Empat kop resmi sudah terpasang. Lakukan cetak uji F4 sebelum dipakai.', tautan: '/pengaturan', ikon: 'Printer', warna: 'emas', menit: 180, dibaca: true },
    { judul: 'Pemindahan berkas ke Drive berjalan', isi: 'Antrian berkas kosong. Semua berkas sudah tersimpan di Google Drive.', tautan: '/', ikon: 'CloudArrowUp', warna: 'hijau', menit: 1500, dibaca: true },
  ],
  admin: [
    { judul: 'Pendaftaran pegawai baru', isi: 'Ustzh. Aisyah Putri, S.Pd. menunggu verifikasi akun.', tautan: '/pegawai/p10', ikon: 'UserPlus', warna: 'biru', menit: 6 },
    { judul: 'Pendaftaran pegawai baru', isi: 'Ust. Yusuf Maulana, S.Pd. menunggu verifikasi akun.', tautan: '/pegawai/p6', ikon: 'UserPlus', warna: 'biru', menit: 52 },
    { judul: 'Data pegawai belum lengkap', isi: 'Ust. Ahmad Zaki belum memiliki NIY dan akun.', tautan: '/pegawai/p9', ikon: 'WarningCircle', warna: 'jingga', menit: 240, dibaca: true },
  ],
  pegawai: [
    { judul: 'Akun Anda telah aktif', isi: 'Selamat bergabung di SIMKA PRO. Lengkapi profil Anda bila masih ada data yang kosong.', tautan: '/profil', ikon: 'CheckCircle', warna: 'hijau', menit: 30 },
    { judul: 'Presensi GPS segera hadir', isi: 'Fitur presensi dengan selfie dibuka pada Fase 2.', tautan: '/presensi', ikon: 'Fingerprint', warna: 'teal', menit: 1440, dibaca: true },
  ],
}

export const notifikasiDemo = (peran) =>
  (NOTIFIKASI_DEMO[peran] || []).map((n, i) => ({
    id: `n${peran}${i}`, judul: n.judul, isi: n.isi, tautan: n.tautan, ikon: n.ikon, warna: n.warna,
    created_at: menitLalu(n.menit), dibaca_pada: n.dibaca ? menitLalu(n.menit - 1) : null,
  }))

export function statistikDemo() {
  const p = PEGAWAI_DEMO
  const perBidang = {}
  p.forEach((x) => { const b = x.nama_unit.replace('Unit Klinik', 'Bidang Kesantrian').replace('Unit Security', 'Bidang Kesantrian'); perBidang[b] = (perBidang[b] || 0) + 1 })
  return {
    pegawai_aktif: 98, akun_aktif: 86,
    menunggu_verifikasi: p.filter((x) => x.status_akun === 'menunggu').length,
    tanpa_akun: 10, laki_laki: 61, perempuan: 37, bidang_aktif: 8, admin: 3,
    per_status: { tetap: 52, kontrak: 27, honorer: 19 },
    per_bidang: [
      { bidang: 'Bidang Tahfizh', jumlah: 24 }, { bidang: 'Bidang Kesetaraan Wustha', jumlah: 18 },
      { bidang: 'Bidang SMA', jumlah: 15 }, { bidang: 'Bidang Kesantrian', jumlah: 21 },
      { bidang: 'Bidang Sarana', jumlah: 6 }, { bidang: 'Bidang Media', jumlah: 4 },
      { bidang: 'Bidang Bahasa', jumlah: 5 }, { bidang: 'Bidang Umum', jumlah: 5 },
    ],
    audit_hari_ini: 37, heartbeat_terakhir: menitLalu(310), berkas_antri: 3, berkas_gagal: 0,
    notifikasi_belum_dibaca: 0,
  }
}
