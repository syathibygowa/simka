// SIMKA PRO | src/lib/disiplin.js | v1.0 | 14.6.0: konstanta Kedisiplinan Santri (tingkat pelanggaran, SP santri, keadaan) | 18/10/2026
// Pelanggaran dicatat TANPA poin; tingkat (ringan/sedang/berat) mengikuti kategori di ketentuan. Surat Peringatan santri
// SP-1/SP-2/SP-3 diusulkan Bidang Kesantrian, diproses Tata Usaha, ditandatangani Direktur. SP-3 = dikembalikan kepada orang tua.
import { formatPanjang } from './tanggal'

export const TINGKAT_PELANGGARAN = {
  ringan: { n: 'Ringan', w: 'tahfizh' },
  sedang: { n: 'Sedang', w: 'laporan' },
  berat: { n: 'Berat', w: 'disiplin' },
}
export const TINGKAT_SP_SANTRI = {
  1: { singkat: 'SP-1', nama: 'Surat Peringatan Pertama', w: 'tahfizh' },
  2: { singkat: 'SP-2', nama: 'Surat Peringatan Kedua', w: 'laporan' },
  3: { singkat: 'SP-3', nama: 'Surat Peringatan Ketiga', w: 'disiplin' },
}
export const KEADAAN_SP_SANTRI = {
  diusulkan: { n: 'Diproses Tata Usaha', w: 'shift' },
  aktif: { n: 'Aktif', w: 'disiplin' },
  berakhir: { n: 'Berakhir', w: 'presensi' },
  batal: { n: 'Dibatalkan', w: 'sistem' },
  dicabut: { n: 'Dicabut', w: 'hakakses' },
}
export const HAK_DISIPLIN_KOSONG = { lihat_semua: false, catat: false, catat_semua: false, usul: false, kelola: false, tu: false, kesantrian: false, pimpinan: false, tampil: false }

export const SET_DISIPLIN_BAWAAN = {
  kategori: [
    ['Terlambat mengikuti kegiatan pondok', 'ringan'], ['Berpakaian tidak sesuai ketentuan', 'ringan'], ['Tidak menjaga kebersihan kamar atau lingkungan', 'ringan'],
    ['Membuat gaduh pada jam belajar atau istirahat', 'ringan'], ['Tidak mengikuti kegiatan tanpa izin', 'sedang'], ['Keluar lingkungan pondok tanpa izin', 'sedang'],
    ['Membawa atau menggunakan telepon genggam/barang elektronik tanpa izin', 'sedang'], ['Berkata kasar atau tidak beradab', 'sedang'], ['Merusak fasilitas pondok', 'sedang'],
    ['Terlambat kembali dari izin atau libur', 'sedang'], ['Berkelahi atau melakukan kekerasan', 'berat'], ['Perundungan (bullying)', 'berat'], ['Mencuri', 'berat'], ['Merokok', 'berat'],
    ['Berhubungan dengan lawan jenis yang bukan mahram', 'berat'], ['Melawan atau tidak menghormati ustadz/ustadzah', 'berat'], ['Meninggalkan pondok tanpa izin (kabur)', 'berat'], ['Lainnya', 'ringan'],
  ].map(([nama, tingkat]) => ({ nama, tingkat })),
  sanksi: {
    1: ['Pembinaan dan nasihat oleh wali kelas dan musyrif', 'Membuat surat pernyataan tidak mengulangi pelanggaran', 'Tugas kebersihan atau tambahan hafalan selama satu pekan'],
    2: ['Pemanggilan orang tua/wali santri ke pondok', 'Pencabutan hak izin keluar pondok selama satu bulan', 'Pembinaan khusus oleh Bidang Kesantrian'],
    3: ['Santri dikembalikan kepada orang tua/wali (dikeluarkan dari pondok)'],
  },
  masa_bulan: { 1: 3, 2: 6, 3: 6 }, penanda: { 1: null, 2: null, 3: null },
  harapan: 'memperbaiki akhlak dan kedisiplinannya serta menaati tata tertib pondok',
  tembusan: ['Ketua Yayasan', 'Kepala Bidang Kesantrian', 'Wali kelas santri', 'Arsip'],
  ambang: { ringan: 5, sedang: 3, berat: 1 }, jendela_hari: 180, beri_tahu_pengasuh: true, sp3_keluar: true,
}

/** Tingkat kategori dari ketentuan (bawaan ringan). */
export const tingkatKategori = (set, nama) => (set?.kategori || []).find((k) => k.nama.toLowerCase() === String(nama || '').toLowerCase())?.tingkat || 'ringan'

/** Ringkasan pelanggaran terbuka: "3 sedang, 1 berat". */
export function teksTerbuka(t) {
  if (!t || !t.jumlah) return 'Tidak ada'
  return ['berat', 'sedang', 'ringan'].filter((k) => t[k] > 0).map((k) => `${t[k]} ${k}`).join(', ')
}

/** Pesan WA bawaan kepada orang tua/wali tentang SP yang terbit. */
export function pesanSPWali(sp, lembaga = {}) {
  const nama = TINGKAT_SP_SANTRI[sp.tingkat]
  return `Assalamu'alaikum warahmatullahi wabarakatuh, Bapak/Ibu ${sp.wali || 'orang tua/wali'}.\n\n`
    + `Dengan hormat, kami dari ${lembaga.nama_singkat || 'Pondok Pesantren Imam Asy-Syathiby'} menyampaikan bahwa ananda *${sp.nama}* (NIS ${sp.nis}${sp.kelas ? ', ' + sp.kelas : ''}) `
    + `menerima *${nama.nama} (${nama.singkat})* Nomor ${sp.nomor || '–'} tanggal ${formatPanjang(sp.tanggal_surat)}.\n\n`
    + `Pelanggaran:\n${(sp.kategori || []).map((k, i) => `${i + 1}. ${k}`).join('\n')}\n\n`
    + `Sanksi:\n${(sp.sanksi || []).map((k, i) => `${String.fromCharCode(97 + i)}. ${k}`).join('\n')}\n\n`
    + (sp.tingkat === 3
      ? 'Bapak/Ibu dimohon datang ke pondok untuk menjemput ananda serta menyelesaikan administrasi di Tata Usaha.'
      : 'Kami memohon kerja sama Bapak/Ibu untuk turut membina ananda. Surat asli dapat diambil di Tata Usaha atau diserahkan saat pemanggilan.')
    + '\n\nJazakumullahu khairan.\nBidang Kesantrian'
}
