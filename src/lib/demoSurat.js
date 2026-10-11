// SIMKA PRO | src/lib/demoSurat.js | v1.1 | Fase 10 – Perbaikan: istilah bahasa Arab dicetak miring | 11/10/2026
// Data contoh mode demo: sebagian template isi awal (salinan dari migrasi 6800) dan konteks lembaga.
export const KONTEKS_DEMO = {
  lembaga: "Pondok Pesantren Tahfizhul Qur'an Imam Asy-Syathiby Wahdah Islamiyah Gowa",
  alamat: 'Jl. Poros Malino KM.04, Bontoramba, Kec. Somba Opu, Kabupaten Gowa, Sulawesi Selatan 92119',
  npsn: '70023617', nspp: '502373060054', kota: 'Gowa', tahun_ajaran: '2026/2027', hijriah_hari_ini: '28 Rabiul Akhir 1448 H',
}
export const PENANDA_DEMO = [
  { id: 'sg-dir', jabatan: 'Direktur', nama: 'Siswandi Safari, S.Pd.I., Lc., S.H., M.Ag.', niy: '1983020910201401', employee_id: 'e-dir' },
  { id: 'sg-smp', jabatan: 'Kepala Kesetaraan Wustha (SMP)', nama: 'Chamdar Nur, S.Pd.I., SH., Lc., M.Pd.', niy: '1983042805201401', employee_id: null },
  { id: 'sg-sma', jabatan: 'Kepala SMA', nama: 'H. Afrianto, Lc, M.H.', niy: '1994042801202001', employee_id: null },
]
const T = (o) => ({ id: 'tp-' + o.kode, kategori: 'umum', perihal_kode: 'NZ', format_nomor: 'surat', dk: 'D', kop_kode: 'pondok', bentuk: 'kiri', judul: null, subjudul: null,
  hal_bawaan: null, kepada_bawaan: null, opsi: {}, isian: [], penanda: [{ jabatan: 'Direktur' }], aktif: true, bawaan: true, ...o })
export const TEMPLATE_DEMO = [
  T({ kode: 'undangan', nama: 'Surat Undangan', perihal_kode: 'DW', dk: 'K', hal_bawaan: 'Undangan', urutan: 1,
    opsi: { salam: true, hamdalah: true, salam_penutup: true, tembusan: true, narahubung: true },
    isi: `Dengan memohon rahmat Allah _Subhanahu wa Ta'ala_, kami mengundang Bapak/Ibu/Saudara untuk menghadiri {acara} yang _insya Allah_ akan dilaksanakan pada:

Hari/tanggal : {hari_tanggal}
Waktu : {waktu} WITA s.d. selesai
Tempat : {tempat}
Agenda : {agenda}

Mengingat pentingnya acara tersebut, kami sangat mengharapkan kehadiran Bapak/Ibu/Saudara tepat waktu.

Demikian undangan ini kami sampaikan. Atas perhatian dan kehadirannya, kami ucapkan _jazakumullahu khairan_.`,
    isian: [{ kunci: 'acara', label: 'Nama acara', jenis: 'teks', wajib: true }, { kunci: 'hari_tanggal', label: 'Hari dan tanggal acara', jenis: 'hari_tanggal', wajib: true },
      { kunci: 'waktu', label: 'Waktu mulai', jenis: 'jam', wajib: true }, { kunci: 'tempat', label: 'Tempat', jenis: 'teks', wajib: true }, { kunci: 'agenda', label: 'Agenda', jenis: 'daftar', gaya: 'angka' }] }),
  T({ kode: 'perjalanan_dinas', nama: 'Surat Perjalanan Dinas', kategori: 'pegawai', perihal_kode: 'AM', bentuk: 'tengah', judul: 'SURAT PERINTAH PERJALANAN DINAS', hal_bawaan: 'Perjalanan Dinas', urutan: 10,
    isi: `| No. | Uraian | Keterangan |
|---|---|---|
| 1. | Pejabat pemberi tugas | {penanda.jabatan} |
| 2. | Nama pegawai yang diperintah | {pegawai.nama} |
| 3. | Jabatan | {pegawai.jabatan} |
| 4. | Maksud perjalanan dinas | {maksud} |
| 5. | Tempat tujuan | {tujuan} |
| 6. | Tanggal berangkat | {tanggal_berangkat} |
| 7. | Tanggal harus kembali | {tanggal_kembali} |

Demikian surat perintah perjalanan dinas ini dibuat untuk dilaksanakan dengan penuh tanggung jawab.`,
    isian: [{ kunci: 'pegawai', label: 'Pegawai yang diperintah', jenis: 'pegawai', wajib: true }, { kunci: 'maksud', label: 'Maksud perjalanan', jenis: 'panjang', wajib: true },
      { kunci: 'tujuan', label: 'Tempat tujuan', jenis: 'teks', wajib: true }, { kunci: 'tanggal_berangkat', label: 'Tanggal berangkat', jenis: 'tanggal', wajib: true },
      { kunci: 'tanggal_kembali', label: 'Tanggal kembali', jenis: 'tanggal', wajib: true }] }),
  T({ kode: 'surat_keputusan', nama: 'Surat Keputusan', perihal_kode: 'QR', format_nomor: 'sk', bentuk: 'tengah', judul: 'KEPUTUSAN DIREKTUR', subjudul: 'TENTANG\n{tentang}', hal_bawaan: 'Keputusan', urutan: 11,
    opsi: { basmalah: true, ditetapkan: true, tembusan: true },
    isi: `{penanda.jabatan} {lembaga}, setelah:

Menimbang : {menimbang}
Mengingat : {mengingat}

== *MEMUTUSKAN*

Menetapkan : {menetapkan}
Kesatu : {kesatu}
Kedua : Keputusan ini berlaku sejak tanggal ditetapkan dengan ketentuan apabila di kemudian hari terdapat kekeliruan akan diadakan perbaikan sebagaimana mestinya.`,
    isian: [{ kunci: 'tentang', label: 'Tentang', jenis: 'teks', wajib: true }, { kunci: 'menimbang', label: 'Menimbang', jenis: 'daftar', gaya: 'huruf', wajib: true },
      { kunci: 'mengingat', label: 'Mengingat', jenis: 'daftar', gaya: 'angka', wajib: true }, { kunci: 'menetapkan', label: 'Menetapkan', jenis: 'panjang', wajib: true },
      { kunci: 'kesatu', label: 'Diktum kesatu', jenis: 'panjang', wajib: true }] }),
  T({ kode: 'keterangan_aktif_santri', nama: 'Surat Keterangan Aktif Santri', kategori: 'santri', perihal_kode: 'IL', dk: 'K', bentuk: 'tengah', judul: 'SURAT KETERANGAN AKTIF', hal_bawaan: 'Keterangan Aktif Santri', urutan: 12,
    isi: `Yang bertanda tangan di bawah ini, {penanda.jabatan} {lembaga}, menerangkan bahwa:

Nama : {santri.nama}
NIS/NISN : {santri.nis} / {santri.nisn}
Tempat, tanggal lahir : {santri.ttl}
Jenis kelamin : {santri.jk}
Kelas : {santri.kelas} ({santri.jenjang})
Nama orang tua/wali : {santri.wali}

adalah benar santri {lembaga} yang masih aktif mengikuti kegiatan pendidikan pada Tahun Ajaran {tahun_ajaran}.

Surat keterangan ini diberikan untuk keperluan {keperluan}.

Demikian surat keterangan ini dibuat dengan sebenarnya untuk dipergunakan sebagaimana mestinya.`,
    isian: [{ kunci: 'santri', label: 'Santri', jenis: 'santri', wajib: true }, { kunci: 'keperluan', label: 'Keperluan', jenis: 'teks', wajib: true }] }),
]
export const SANTRI_SURAT_DEMO = [
  { id: 's-1', nama: 'Muhammad Fathir Al-Ghifari', nis: '2411001', nisn: '0112233445', jk: 'L', tempat_lahir: 'Makassar', tanggal_lahir: '2012-03-14', jenjang: 'wustha', tingkat: 8, kelas: '8A', wali: 'Ahmad Syarifuddin', alamat: 'Jl. Malino No. 12, Gowa' },
  { id: 's-2', nama: 'Aisyah Nur Rahmah', nis: '2311015', nisn: '0098877665', jk: 'P', tempat_lahir: 'Gowa', tanggal_lahir: '2010-07-02', jenjang: 'sma', tingkat: 10, kelas: '10B', wali: 'Hasanuddin', alamat: 'Sungguminasa, Gowa' },
]
