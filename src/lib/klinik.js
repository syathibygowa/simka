// SIMKA PRO | src/lib/klinik.js | v1.1 | Fase 6 – Tahap 2 Status otomatis dan perizinan santri | 06/10/2026
// Label baku Klinik: status kasus, tindak lanjut, sumber rujukan, klinik putra/putri.
import { PhHourglass, PhStethoscope, PhCheckCircle, PhXCircle, PhPersonSimpleWalk, PhBed, PhFirstAidKit, PhAmbulance, PhHouseLine } from '@phosphor-icons/vue'

export const KLINIK = { putra: 'Klinik Putra', putri: 'Klinik Putri' }
export const klinikSantri = (jk) => (jk === 'P' ? 'putri' : 'putra')

export const STATUS_KASUS = {
  menunggu:  { n: 'Menunggu pemeriksaan', p: 'Menunggu', w: 'pengajuan', ikon: PhHourglass },
  ditangani: { n: 'Sedang ditangani', p: 'Ditangani', w: 'agenda', ikon: PhStethoscope },
  selesai:   { n: 'Selesai', p: 'Selesai', w: 'presensi', ikon: PhCheckCircle },
  batal:     { n: 'Dibatalkan', p: 'Batal', w: 'hakakses', ikon: PhXCircle },
}

/** Tindak lanjut pemeriksaan (Blueprint Bagian 21). "sakit" = santri berstatus Sakit di absensi (Tahap 2). */
export const TINDAK_LANJUT = {
  kembali:   { n: 'Kembali beraktivitas', w: 'presensi', ikon: PhPersonSimpleWalk, sakit: false, ket: 'Tidak perlu istirahat; kasus ditutup.' },
  istirahat: { n: 'Istirahat di kamar', w: 'santri', ikon: PhBed, sakit: true, ket: 'Santri beristirahat di kamar; otomatis Sakit di absensi sampai dinyatakan sembuh.' },
  rawat:     { n: 'Rawat di klinik', w: 'klinik', ikon: PhFirstAidKit, sakit: true, ket: 'Santri dirawat di ruang klinik.' },
  rujuk:     { n: 'Rujuk ke RS/puskesmas', w: 'shift', ikon: PhAmbulance, sakit: true, ket: 'Tuliskan tujuan rujukan.' },
  pulang:    { n: 'Dipulangkan', w: 'pengumuman', ikon: PhHouseLine, sakit: true, ket: 'Pulang untuk pemulihan; otomatis menjadi usulan izin ke Kepala Bidang Kesantrian.' },
}
export const HASIL_KASUS = { sembuh: 'Sembuh', kembali: 'Kembali beraktivitas', batal: 'Dibatalkan' }

export const SUMBER_RUJUKAN = {
  pengasuh: 'Rujukan pengasuh', absensi: 'Dari absensi (Sakit)', lapor: 'Dari laporan', datang_sendiri: 'Datang sendiri', petugas: 'Dicatat petugas',
}

/** Label status satu kasus untuk kartu: menunggu → "Menunggu", ditangani → tindak lanjutnya. */
export function labelKasus(k) {
  if (k.status === 'ditangani' && k.tindak_lanjut) return { n: TINDAK_LANJUT[k.tindak_lanjut].n, w: TINDAK_LANJUT[k.tindak_lanjut].w }
  if (k.status === 'selesai') return { n: HASIL_KASUS[k.hasil] || 'Selesai', w: 'presensi' }
  return { n: STATUS_KASUS[k.status].p, w: STATUS_KASUS[k.status].w }
}

/** Sisa waktu menuju batas periksa, mis. "lewat 35 menit" / "sisa 1 jam 20 menit". */
export function sisaBatas(batas, kini = Date.now()) {
  if (!batas) return ''
  const m = Math.round((new Date(batas).getTime() - kini) / 60000)
  const teks = (x) => { const j = Math.floor(Math.abs(x) / 60); const mm = Math.abs(x) % 60; return [j && `${j} jam`, (mm || !j) && `${mm} menit`].filter(Boolean).join(' ') }
  return m < 0 ? `lewat ${teks(m)}` : `sisa ${teks(m)}`
}

export const PENGATURAN_KLINIK_BAWAAN = () => ({
  jam_layanan: [{ mulai: '07:30', selesai: '11:00' }, { mulai: '16:00', selesai: '19:00' }],
  batas_hari_ini_menit: 120, batas_besok_jam: '11:00', kontrol_bawaan_hari: 1, kop: 'pondok',
})
