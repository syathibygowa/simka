// SIMKA PRO | src/lib/wa.js | v1.19 | 14.21.0: alamat resmi aplikasi, template WA minta tanda tangan dan ujian tahsin | 24/10/2026
// Tautan WhatsApp wa.me dari WA pribadi pegawai (Bagian 25). Isi pesan diambil dari template WA yang
// dikelola superadmin (Setelan → Template WA); bila belum dimuat, dipakai isi bawaan di bawah.
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { useLembaga } from '@/stores/lembaga'
import { useSesi } from '@/stores/sesi'
import { formatHari, formatJam, sekarang } from '@/lib/tanggal'
import { alamatAplikasi } from './alamat'

export function nomorWA(hp) {
  let n = String(hp || '').replace(/[^0-9]/g, '')
  if (n.startsWith('0')) n = '62' + n.slice(1)
  else if (n.startsWith('8')) n = '62' + n
  return n
}
export function tautanWA(hp, pesan) {
  return `https://wa.me/${nomorWA(hp)}?text=${encodeURIComponent(pesan)}`
}
// 14.21.0: alamat resmi (simka.digital), bukan alamat GitHub Pages
export { alamatAplikasi }

export const BAWAAN_WA = {
  aktivasi: "Assalamu'alaikum warahmatullahi wabarakatuh, {nama}.\n\nAkun SIMKA PRO Anda telah aktif. Silakan masuk di {alamat_aplikasi} dengan username *{username}* dan kata sandi yang Anda buat saat mendaftar.\n\nJazakumullahu khairan.\nAdmin SIMKA PRO Imam Asy-Syathiby",
  ditolak: "Assalamu'alaikum warahmatullahi wabarakatuh, {nama}.\n\nPendaftaran akun SIMKA PRO Anda belum dapat disetujui dengan catatan: {catatan}\n\nSilakan hubungi admin pondok untuk keterangan lebih lanjut.\nAdmin SIMKA PRO Imam Asy-Syathiby",
  sandi_sementara: "Assalamu'alaikum warahmatullahi wabarakatuh, {nama}.\n\nKata sandi sementara akun SIMKA PRO Anda:\nUsername: *{username}*\nKata sandi: *{sandi}*\n\nSilakan masuk di {alamat_aplikasi} lalu ganti kata sandi saat diminta. Jangan bagikan pesan ini kepada siapa pun.\nAdmin SIMKA PRO Imam Asy-Syathiby",
  undangan_agenda: "Assalamu'alaikum warahmatullahi wabarakatuh, {nama}.\n\nMengingatkan agenda *{judul}*\nHari/tanggal: {tanggal}\nWaktu: {waktu}\nTempat: {lokasi}\n\n{keterangan}\n\nJazakumullahu khairan.\n{pengirim}",
  umum: "Assalamu'alaikum warahmatullahi wabarakatuh, {nama}.\n\n{pesan}\n\nJazakumullahu khairan.\n{pengirim}",
  pengumuman: '{salam}, {nama}.\n\n*{judul}*\n{isi_singkat}\n\nSelengkapnya di SIMKA PRO: {tautan}\n\n{penutup}\n{pengirim}',
  berkas_baru: '{salam}, {nama}.\n\nAda {kategori} untuk Anda di menu Berkas Saya SIMKA PRO:\n*{judul}*\n\nSilakan dibuka di {tautan}\n\n{penutup}\n{pengirim}',
  pengajuan_status: '{salam}, {nama}.\n\nPengajuan {jenis} Anda ({tanggal}, {lama}) saat ini *{status}*.\n{alasan}\n\nRincian dan surat: {tautan}\n\n{penutup}\n{pengirim}',
  pengajuan_pengingat: '{salam}, {nama}.\n\nMohon maaf mengganggu. Ada pengajuan {jenis} dari {pemohon} ({tanggal}, {lama}) yang menunggu persetujuan Anda sebagai {jabatan}.\n\nSilakan diputuskan di SIMKA PRO: {tautan}\n\n{penutup}\n{pengirim}',
  wali_santri: '{salam}, Bapak/Ibu {nama_wali}.\n\nKami dari {nama_singkat} menyampaikan informasi terkait ananda *{nama_santri}* (NIS {nis}, {kelas}).\n\n{pesan}\n\n{penutup}\n{pengirim}\n{jabatan_pengirim}',
  absen_santri: '{salam}, Bapak/Ibu {nama_wali}.\n\nKami informasikan bahwa ananda *{nama_santri}* ({kelas}) tercatat *{status}* pada {kegiatan}, {tanggal}.\n{keterangan}\n\nMohon perhatian dan kerja samanya.\n{penutup}\n{pengirim}\n{jabatan_pengirim}',
  rekap_santri: '{salam}, Bapak/Ibu {nama_wali}.\n\nRekap kehadiran ananda *{nama_santri}* ({kelas}) periode {periode}:\n{rekap}\n\n{penutup}\n{pengirim}\n{jabatan_pengirim}',
  rekap_hafalan: '{salam}, Bapak/Ibu {nama_wali}.\n\nPerkembangan hafalan ananda *{nama_santri}* ({kelas}, {halaqah}):\n• Posisi hafalan: {posisi}\n• Hafalan resmi: {total_juz} juz\n• Capaian {periode}: {capaian}\n{keterangan}\n\nMohon doa dan dukungan Bapak/Ibu agar ananda istiqamah menjaga hafalannya.\n{penutup}\n{pengirim}\n{jabatan_pengirim}',
  penguji_ujian: '{salam}, {nama}.\n\nDaftar tunggu {jenis_ujian} ({jumlah} santri):\n{daftar}\n\nMohon berkenan mengambil dan menjadwalkan ujiannya di SIMKA PRO: {tautan}\n\n{penutup}\n{pengirim}',
  rekap_asrama: '{salam}, Bapak/Ibu {nama_wali}.\n\nRekap kehadiran asrama ananda *{nama_santri}* ({kamar}) periode {periode}:\n{rekap}\n\n{ketidakhadiran}\n\nMohon perhatian dan doanya.\n{penutup}\n{pengirim}\n{jabatan_pengirim}',
  rekap_kamar: '{salam}.\n\nRekap kehadiran asrama *{kamar}* periode {periode}:\n• Rata-rata kehadiran: {persen}\n• Sesi terlaksana: {jumlah_sesi}\n• Hadir penuh: {hadir_penuh}\n{rincian}\n\n{penutup}\n{pengirim}\n{jabatan_pengirim}',
  izin_santri: '{salam}, Bapak/Ibu {nama_wali}.\n\nKami informasikan izin {jenis_izin} ananda *{nama_santri}* ({kelas}) *{status}*.\n• Alasan: {alasan}\n• Keluar: {waktu_keluar}\n• Batas kembali: {batas_kembali}\n• Penjemput: {penjemput}\n\nMohon ananda diantar kembali ke pondok sebelum batas waktu.\n{penutup}\n{pengirim}\n{jabatan_pengirim}',
  izin_santri_minta: '{salam}, {nama}.\n\nMohon izin, kami mengajukan izin {jenis_izin} ananda *{nama_santri}* ({kelas}) yang menunggu persetujuan Antum sebagai {jabatan}:\n• Alasan: {alasan}\n• Keluar: {waktu_keluar}\n• Batas kembali: {batas_kembali}\n• Penjemput: {penjemput}\n{keterangan}\n\nMohon berkenan diputuskan di SIMKA PRO: {tautan}\n\n{penutup}\n{pengirim}\n{jabatan_pengirim}',
  izin_kolektif_minta: '{salam}, {nama}.\n\nMohon izin, kami mengajukan *izin kolektif {kegiatan}* untuk {jumlah} santri yang menunggu persetujuan Antum sebagai {jabatan}:\n• Tempat: {tempat}\n• Keluar: {waktu_keluar}\n• Batas kembali: {batas_kembali}\n• Pendamping: {pendamping}\n• Santri: {daftar}\n{keterangan}\n\nMohon berkenan diputuskan di SIMKA PRO: {tautan}\n\n{penutup}\n{pengirim}\n{jabatan_pengirim}',
  ttd_minta: '{salam}, {nama}.\n\nMohon izin, ada *{jenis_dokumen}* yang menunggu tanda tangan Antum sebagai {jabatan}:\n• Nomor: {nomor}\n• Perihal: {perihal}\n\nMohon berkenan ditandatangani di SIMKA PRO (menu Tanda tangan): {tautan}\n\n{penutup}\n{pengirim}',
  tahsin_ujian_minta: '{salam}, {nama}.\n\nMohon izin, ananda *{nama_santri}* ({kelas}, halaqah {halaqah}) telah menuntaskan tahapan tahsin dan diajukan untuk *ujian tahsin*.\n{catatan}\n\nMohon berkenan diuji (Makhraj dan Shifat) di SIMKA PRO: {tautan}\n\n{penutup}\n{pengirim}',
  izin_kolektif_wali: '{salam}, Bapak/Ibu {nama_wali}.\n\nKami informasikan ananda *{nama_santri}* ({kelas}) mengikuti *{kegiatan}* dan *{status}* izin keluar pondok bersama {jumlah} santri lainnya:\n• Tempat: {tempat}\n• Keluar: {waktu_keluar}\n• Batas kembali: {batas_kembali}\n• Pendamping: {pendamping}\n\nMohon doa Bapak/Ibu untuk kelancaran kegiatan ananda.\n{penutup}\n{pengirim}\n{jabatan_pengirim}',
  titipan_santri: '{salam}, Bapak/Ibu {nama_wali}.\n\nKami informasikan titipan untuk ananda *{nama_santri}* ({kelas}) {status_titipan}.\n• Barang: {barang}\n• Pengirim: {pengirim_titipan}\n• Diterima di pos: {waktu_terima}\n{pengambilan}\n\n{penutup}\n{pengirim}\n{jabatan_pengirim}',
  libur_santri: '{salam}, Bapak/Ibu {nama_wali}.\n\nKami informasikan bahwa pada *{periode_libur}* ananda *{nama_santri}* ({kelas}) *{status_libur}*.\n• Pulang: {waktu_pulang}\n• Batas kembali: {batas_kembali}\n{keterangan}\n\nMohon ananda dijemput dan diantar kembali tepat waktu.\n{penutup}\n{pengirim}\n{jabatan_pengirim}',
  tagihan_santri: '{salam}, Bapak/Ibu {nama_wali}.\n\nKami sampaikan tagihan ananda *{nama_santri}* (NIS {nis}, {kelas}):\n{rincian}\n\n*Jumlah: {total}*\nMohon dibayarkan paling lambat *{batas_bayar}*.\n\nPembayaran dapat ditransfer ke:\n{rekening}\n\nSurat tagihan resmi nomor {nomor}; keabsahan dapat diperiksa dengan kode {kode_validasi} di {tautan_cek}\n\nApabila sudah membayar, mohon kirimkan bukti transfer melalui nomor ini.\n{penutup}\n{pengirim}\n{jabatan_pengirim}',
  kuitansi_santri: '{salam}, Bapak/Ibu {nama_wali}.\n\nAlhamdulillah, pembayaran untuk ananda *{nama_santri}* ({kelas}) telah kami terima:\n{rincian}\n\n*Jumlah: {jumlah}*\nTanggal: {tanggal}\nKuitansi nomor {nomor} (kode validasi {kode_validasi}).\n{sisa}\n\nJazakumullahu khairan atas kerja samanya.\n{pengirim}\n{jabatan_pengirim}',
  tagihan_baru: '{salam}, Bapak/Ibu {nama_wali}.\n\nKami informasikan tagihan baru untuk ananda *{nama_santri}* ({kelas}):\n{rincian}\n\n*Jumlah: {total}*\nJatuh tempo: {batas_bayar}\n\nPembayaran dapat ditransfer ke:\n{rekening}\n\nMohon kirimkan bukti transfer melalui nomor ini.\n{penutup}\n{pengirim}\n{jabatan_pengirim}',
  pengingat_jatuh_tempo: '{salam}, Bapak/Ibu {nama_wali}.\n\nMengingatkan dengan hormat, tagihan ananda *{nama_santri}* ({kelas}) akan jatuh tempo pada *{batas_bayar}*:\n{rincian}\n\n*Jumlah: {total}*\n\nPembayaran dapat ditransfer ke:\n{rekening}\n\nApabila sudah membayar, mohon abaikan pesan ini.\n{penutup}\n{pengirim}\n{jabatan_pengirim}',
  tunggakan_santri: '{salam}, Bapak/Ibu {nama_wali}.\n\nMohon maaf mengganggu. Berdasarkan catatan kami, terdapat tagihan ananda *{nama_santri}* ({kelas}) yang telah melewati jatuh tempo:\n{rincian}\n\n*Jumlah: {total}*\n\nPembayaran dapat ditransfer ke:\n{rekening}\n\nApabila sudah membayar, mohon kirimkan bukti transfer melalui nomor ini. Bila ada kendala, silakan menghubungi kami.\n{penutup}\n{pengirim}\n{jabatan_pengirim}',
  ujian_rekomendasi: '{salam}, {nama}.\n\nMohon izin, kami merekomendasikan santri berikut untuk *{jenis_ujian}*:\n• Nama: *{nama_santri}*\n• Kelas: {kelas}\n• Halaqah: {halaqah}\n• Materi ujian: {materi}\n• Catatan: {catatan}\n\nMohon berkenan menjadwalkan ujiannya di SIMKA PRO (Tahfizh → Ujian): {tautan}\n\n{penutup}\n{pengirim}\n{jabatan_pengirim}',
  ujian_jadwal: '{salam}, {nama}.\n\nJadwal *{jenis_ujian}* santri berikut telah ditetapkan:\n• Nama: *{nama_santri}*\n• Kelas: {kelas}\n• Halaqah: {halaqah}\n• Materi ujian: {materi}\n• Jadwal: *{jadwal}*\n• Penguji: {penguji}\n\nMohon santri disiapkan dan hadir tepat waktu.\n{penutup}\n{pengirim}',
  ujian_hasil: '{salam}, {nama}.\n\nBerikut hasil *{jenis_ujian}*:\n• Nama: *{nama_santri}*\n• Kelas: {kelas}\n• Halaqah: {halaqah}\n• Muhaffizh: {muhaffizh}\n• Materi ujian: {materi}\n• Nilai: Tajwid {nilai_tajwid}, Itqan {nilai_itqan}, nilai akhir *{nilai_akhir}*, predikat {predikat}\n• Keterangan: *{keterangan_ujian}*\n• Catatan perbaikan: {catatan_perbaikan}\n\n{penutup}\n{pengirim}\n{jabatan_pengirim}',
  khataman_pengumuman: "{salam}.\n\n*Undangan Khataman Al-Qur'an 30 Juz*\n\nAlhamdulillah, ananda *{nama_santri}* ({kelas}, {halaqah}) telah menuntaskan hafalan Al-Qur'an 30 juz. Insya Allah khataman akan dilaksanakan pada:\n• Hari/tanggal: {tanggal}\n• Waktu: {waktu}\n• Tempat: {tempat}\n\nKami mengundang para asatidzah dan santri untuk hadir menyaksikan dan mendoakan. Semoga Allah memberkahi.\n\n{penutup}\n{pengirim}\n{jabatan_pengirim}",
  khataman_undangan_wali: "{salam}, Bapak/Ibu {nama_wali}.\n\nAlhamdulillah, dengan izin Allah ananda *{nama_santri}* ({kelas}) telah menuntaskan hafalan Al-Qur'an 30 juz. Kami mengundang Bapak/Ibu untuk hadir pada *Khataman Al-Qur'an* ananda:\n• Hari/tanggal: {tanggal}\n• Waktu: {waktu}\n• Tempat: {tempat}\n\nPada acara tersebut ananda menerima Sertifikat Penghargaan Khataman. Surat undangan resmi nomor {nomor} dapat diperiksa di: {tautan_cek}\n\n{penutup}\n{pengirim}\n{jabatan_pengirim}",
  khataman_muhaffizh: "{salam}, {nama}.\n\nUsulan khataman ananda *{nama_santri}* ({halaqah}) telah *disetujui* dengan jadwal:\n• Hari/tanggal: {tanggal}\n• Waktu: {waktu}\n• Tempat: {tempat}\n\nMohon undangan diteruskan kepada orang tua santri dan santri dipersiapkan. Undangan dan sertifikat dapat dicetak di SIMKA PRO (Tahfizh → Khataman): {tautan}\n\n{penutup}\n{pengirim}\n{jabatan_pengirim}",
  tahsin_perkembangan_wali: "{salam}, Bapak/Ibu {nama_wali}.\n\nKami sampaikan perkembangan *tahsin* (perbaikan bacaan Al-Qur'an) ananda *{nama_santri}* ({kelas}):\n• Tahap: {tahap}\n• Pertemuan: {pertemuan}\n• Catatan terakhir: {catatan}\n\nMohon doa dan dukungan Bapak/Ibu agar ananda segera lancar membaca dan mulai menghafal.\n\n{penutup}\n{pengirim}\n{jabatan_pengirim}",
  tahsin_lulus_wali: "{salam}, Bapak/Ibu {nama_wali}.\n\nAlhamdulillah, ananda *{nama_santri}* ({kelas}) telah *lulus tahsin* dan insya Allah mulai menghafal Al-Qur'an bersama halaqah {halaqah}.\n\nSemoga Allah memudahkan ananda menjadi penghafal Al-Qur'an. Mohon terus doakan dan motivasi ananda.\n\n{penutup}\n{pengirim}\n{jabatan_pengirim}",
  verval_presensi: '{salam}, {nama}.\n\nPresensi Anda pada sesi {sesi}, {tanggal} telah diverval dengan status *{status_presensi}*.\nCatatan: {catatan_verval}\n\n{penutup}\n{pengirim}',
}

let simpanan = {}
/** Muat template WA dari database (dipanggil saat admin/superadmin masuk). */
export async function muatTemplatWA() {
  if (MODE_DEMO) return
  const { data } = await supabase.from('wa_templates').select('kode, isi, aktif')
  simpanan = Object.fromEntries((data || []).filter((t) => t.aktif).map((t) => [t.kode, t.isi]))
}
export const setelTemplatWA = (kode, isi) => { simpanan[kode] = isi }

/**
 * Katalog isian template WA. "umum" terisi otomatis di setiap pesan (lembaga, waktu, pengirim);
 * kelompok lain diisi oleh menu yang mengirim pesan (pengumuman, agenda, pengajuan, berkas, presensi, akun).
 */
export const ISIAN_WA = [
  { grup: 'Umum (terisi otomatis)', isian: [
    ['salam', "Assalamu'alaikum warahmatullahi wabarakatuh"], ['penutup', 'Jazakumullahu khairan.'],
    ['nama_lembaga', 'Nama lengkap pondok'], ['nama_singkat', 'Nama singkat pondok'], ['alamat_lembaga', 'Alamat pondok'],
    ['telepon_lembaga', 'Telepon pondok'], ['kota', 'Kota surat (Gowa)'], ['hari_ini', 'Hari dan tanggal hari ini'],
    ['jam_sekarang', 'Jam saat ini (WITA)'], ['pengirim', 'Nama pengirim pesan'], ['jabatan_pengirim', 'Jabatan/peran pengirim'],
    ['alamat_aplikasi', 'Alamat SIMKA PRO'],
  ] },
  { grup: 'Penerima (pegawai)', isian: [
    ['nama', 'Nama lengkap penerima'], ['niy', 'NIY penerima'], ['jabatan', 'Jabatan penerima'], ['unit', 'Bidang/unit penerima'], ['username', 'Username akun'],
  ] },
  { grup: 'Akun', isian: [['sandi', 'Kata sandi sementara'], ['catatan', 'Catatan verifikasi/penolakan']] },
  { grup: 'Pengumuman dan berkas', isian: [
    ['judul', 'Judul pengumuman/berkas/agenda'], ['isi_singkat', 'Cuplikan isi pengumuman'], ['kategori', 'Kategori berkas'], ['tautan', 'Tautan terkait (halaman di SIMKA PRO, Zoom, Drive)'],
  ] },
  { grup: 'Agenda', isian: [['tanggal', 'Hari/tanggal agenda'], ['waktu', 'Jam agenda'], ['lokasi', 'Tempat'], ['keterangan', 'Keterangan agenda'], ['pengingat', 'Keterangan pengingat (mis. besok)']] },
  { grup: 'Pengajuan', isian: [['pemohon', 'Nama pemohon'], ['jenis', 'Jenis pengajuan'], ['lama', 'Lama (hari)'], ['nomor', 'Nomor surat'], ['status', 'Status pengajuan'], ['alasan', 'Alasan/catatan']] },
  { grup: 'Presensi', isian: [['sesi', 'Nama sesi presensi'], ['status_presensi', 'Status presensi'], ['catatan_verval', 'Catatan verval admin']] },
  { grup: 'Santri dan wali', isian: [['nama_wali', 'Nama orang tua/wali penerima'], ['hubungan', 'Hubungan (Ayah/Ibu/Wali)'], ['nama_santri', 'Nama santri'], ['nis', 'NIS santri'], ['kelas', 'Kelas santri'],
    ['kegiatan', 'Kegiatan absensi (mis. halaqah subuh)'], ['periode', 'Periode rekap'], ['rekap', 'Ringkasan kehadiran per kegiatan']] },
  { grup: 'Tahfizh', isian: [['halaqah', 'Nama halaqah santri'], ['posisi', 'Posisi hafalan (juz dan halaman)'], ['total_juz', 'Jumlah juz hafalan resmi'],
    ['capaian', 'Capaian periode (penambahan dan status)'], ['jenis_ujian', 'Jenis ujian (kenaikan juz/sertifikasi)'], ['jumlah', 'Jumlah santri'], ['daftar', 'Daftar santri menunggu ujian'],
    ['materi', 'Materi ujian (juz/jenjang sertifikasi)'], ['jadwal', 'Jadwal ujian'], ['penguji', 'Nama penguji'], ['muhaffizh', 'Nama muhaffizh halaqah'], ['catatan', 'Catatan rekomendasi'],
    ['nilai_tajwid', 'Nilai tajwid'], ['nilai_itqan', 'Nilai itqan'], ['nilai_akhir', 'Nilai akhir ujian'], ['predikat', 'Huruf dan predikat'], ['keterangan_ujian', 'Lulus/Perbaikan/Tidak lulus'], ['catatan_perbaikan', 'Catatan perbaikan dari penguji'], ['tempat', 'Tempat khataman'], ['tahap', 'Tahap tahsin'], ['pertemuan', 'Jumlah pertemuan tahsin']] },
  { grup: 'Asrama (Musyrif)', isian: [['kamar', 'Nama kamar'], ['ketidakhadiran', 'Rincian tanggal ketidakhadiran santri'], ['persen', 'Rata-rata kehadiran kamar'],
    ['jumlah_sesi', 'Jumlah sesi terlaksana'], ['hadir_penuh', 'Jumlah santri hadir penuh'], ['rincian', 'Rincian per santri (salin grup)']] },
  { grup: 'Perizinan santri', isian: [['jenis_izin', 'Jenis izin (pulang/keluar)'], ['waktu_keluar', 'Waktu keluar'],
    ['batas_kembali', 'Batas kembali'], ['penjemput', 'Nama dan hubungan penjemput'], ['kegiatan', 'Kegiatan izin kolektif (mis. lomba)'],
    ['pendamping', 'Pendamping izin kolektif'], ['daftar', 'Daftar santri izin kolektif'], ['jumlah', 'Jumlah santri']] },
  { grup: 'Tanda tangan dokumen', isian: [['jenis_dokumen', 'Jenis dokumen'], ['nomor', 'Nomor dokumen'], ['perihal', 'Perihal/isi singkat'], ['jabatan', 'Jabatan penanda tangan']] },
  { grup: 'Security (titipan)', isian: [['status_titipan', 'Status titipan (diterima/diserahkan)'], ['barang', 'Jenis dan uraian barang'], ['pengirim_titipan', 'Pengirim titipan'],
    ['waktu_terima', 'Waktu titipan diterima di pos'], ['pengambilan', 'Keterangan pengambilan (nama dan waktu)']] },
  { grup: 'Libur santri', isian: [['periode_libur', 'Nama periode libur'], ['status_libur', 'Keputusan libur ananda'], ['waktu_pulang', 'Waktu pulang']] },
  { grup: 'Keuangan santri', isian: [['rincian', 'Rincian tagihan/pembayaran (satu baris per tagihan)'], ['total', 'Jumlah tagihan'], ['jumlah', 'Jumlah dibayar'],
    ['batas_bayar', 'Batas pembayaran'], ['rekening', 'Rekening lembaga'], ['nomor', 'Nomor kuitansi/surat tagihan'], ['kode_validasi', 'Kode validasi dokumen'],
    ['tautan_cek', 'Tautan Cek Keabsahan'], ['sisa', 'Keterangan sisa tagihan'], ['tanggal', 'Tanggal pembayaran']] },
  { grup: 'Bebas', isian: [['pesan', 'Isi pesan bebas']] },
]

/** Isian umum yang selalu tersedia. */
export function isianUmum() {
  let l = {}; let p = null
  try { l = useLembaga().identitas || {}; p = useSesi().pengguna } catch { /* di luar aplikasi */ }
  const kini = sekarang()
  return {
    salam: "Assalamu'alaikum warahmatullahi wabarakatuh", penutup: 'Jazakumullahu khairan.',
    nama_lembaga: l.nama_lengkap, nama_singkat: l.nama_singkat, alamat_lembaga: l.alamat, telepon_lembaga: l.telepon, kota: l.kota_surat || 'Gowa',
    hari_ini: formatHari(kini), jam_sekarang: formatJam(kini) + ' WITA',
    pengirim: p?.nama_lengkap, jabatan_pengirim: p?.jabatan_struktural || p?.jabatan_fungsional || (p?.peran === 'superadmin' ? 'Superadmin SIMKA PRO' : p?.peran === 'admin' ? 'Admin SIMKA PRO' : ''),
    alamat_aplikasi: alamatAplikasi(),
  }
}

/** Ganti {isian} dengan data; isian kosong diganti "-" dan baris yang hanya berisi isian kosong dibuang. */
export function isiTemplat(isi, data = {}) {
  const d = { ...isianUmum(), ...Object.fromEntries(Object.entries(data).filter(([, v]) => v != null && v !== '')) }
  return String(isi || '')
    .split('\n')
    .filter((baris) => !/^\s*\{(\w+)\}\s*$/.test(baris) || d[baris.trim().slice(1, -1)])
    .join('\n')
    .replace(/\{(\w+)\}/g, (_, k) => (d[k] == null || d[k] === '' ? '-' : String(d[k])))
    .replace(/\n{3,}/g, '\n\n')
}
/** Tautan halaman SIMKA PRO, mis. halamanAplikasi('/berkas/123'). */
export const halamanAplikasi = (jalur) => `${alamatAplikasi()}#${jalur}`

/** Pesan WA menurut kode template. */
export const pesanWA = (kode, data) => isiTemplat(simpanan[kode] ?? BAWAAN_WA[kode] ?? '{pesan}', data)

// Kompatibel dengan pemanggilan lama (Verifikasi Akun)
export const TEMPLAT_WA = {
  aktivasi: (p) => pesanWA('aktivasi', p),
  ditolak: (p) => pesanWA('ditolak', p),
  sandiSementara: (p) => pesanWA('sandi_sementara', p),
}
