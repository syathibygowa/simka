// SIMKA PRO | src/lib/laporanGrup.js | v1.1 | 14.4.0: laporan mengajar memuat tujuan, alat, sumber; laporan ekskul memuat jam latihan | 17/10/2026
// Menyusun teks laporan siap kirim ke grup WhatsApp bidang agar pimpinan dapat membaca ringkasan tanpa membuka SIMKA.
// Format mengikuti kebiasaan WhatsApp: *tebal*, _miring_, emoji sebagai penanda status.
//   laporanAbsensi  — wali kelas, muhaffizh, musyrif, pembina ekskul (ekskul ikut memuat jurnal latihan)
//   laporanSetoran  — muhaffizh: perkembangan hafalan satu sesi halaqah
//   laporanMengajar — guru mapel: jurnal mengajar satu hari
//   laporanMengajarPeriode / laporanEkskulPeriode — (14.4.0) rekap pekanan/bulanan guru mapel dan pembina ekskul
import { formatHari, formatPendek, formatJam, sekarang } from '@/lib/tanggal'
import { formatPosisi } from '@/lib/tahfizh'

/** Penanda kehadiran. Terlambat dan bolos dipisah agar terbaca jelas oleh kepala bidang. */
export const TANDA = {
  H: { e: '✅', n: 'Hadir' }, T: { e: '⏰', n: 'Terlambat' }, I: { e: '📝', n: 'Izin' },
  S: { e: '🤒', n: 'Sakit' }, A: { e: '❌', n: 'Tanpa keterangan' }, B: { e: '⚠️', n: 'Bolos' },
}
export const FORMAT_ABSENSI = [
  { k: 'tanda', n: 'Daftar bertanda', ket: 'Semua santri dalam satu daftar dengan tanda ✅ ❌' },
  { k: 'kelompok', n: 'Per kehadiran', ket: 'Dipisah: hadir, izin, sakit, tanpa keterangan' },
]
const JUDUL = {
  kelas: { lap: 'ABSENSI KELAS', kel: 'Kelas', peng: 'Wali kelas' },
  halaqah: { lap: 'ABSENSI HALAQAH', kel: 'Halaqah', peng: 'Muhaffizh' },
  asrama: { lap: 'ABSENSI ASRAMA', kel: 'Kamar', peng: 'Musyrif' },
  ekskul: { lap: 'KEGIATAN EKSKUL', kel: 'Ekskul', peng: 'Pembina' },
}
const persen = (a, b) => (b ? `${String(Math.round((a / b) * 1000) / 10).replace('.', ',')}%` : '–')
const kaki = () => { const s = sekarang(); return `_Dikirim melalui SIMKA PRO, ${formatPendek(s)} pukul ${formatJam(s)} WITA_` }
const baris = (label, isi) => (isi == null || isi === '' ? null : `${label}: ${isi}`)
// "Kamar Umar" → "Umar" karena label baris sudah "Kamar:" (juga Kelas, Halaqah, Ekskul)
const tanpaAwalan = (nama, label) => String(nama || '').replace(new RegExp(`^${label}\\s+`, 'i'), '') || nama
const gabung = (arr) => arr.filter((x) => x != null).join('\n').replace(/\n{3,}/g, '\n\n')

/**
 * @param {object} d { jenis, kelompok, pengasuh: [nama], tanggal, sesi, jam, tempat, anggota: [{ nama, kode, ket }], catatan, jurnal, format }
 */
export function laporanAbsensi(d) {
  const j = JUDUL[d.jenis] || JUDUL.kelas
  const n = d.anggota.length
  const hit = Object.fromEntries(Object.keys(TANDA).map((k) => [k, d.anggota.filter((a) => (a.kode || 'H') === k).length]))
  const hadir = n - hit.I - hit.S - hit.A          // sama dengan perhitungan SIMKA (terlambat dan bolos dihitung hadir di pondok)
  const ket = (a) => (a.ket ? ` – ${a.ket}` : '')
  const kepala = [
    `*LAPORAN ${j.lap}*`,
    baris(j.kel, tanpaAwalan(d.kelompok, j.kel)),
    baris(j.peng, (d.pengasuh || []).join(', ') || null),
    baris('Hari/tanggal', formatHari(d.tanggal)),
    baris('Sesi', [d.sesi, d.jam && `${d.jam} WITA`].filter(Boolean).join(', ')),
    baris('Tempat', d.tempat),
  ]
  // Jurnal latihan ekskul
  const jr = d.jurnal
  const jurnal = jr && (jr.materi || jr.kegiatan) ? [
    '', '*Kegiatan latihan*',
    baris('Jam latihan', jr.jam_mulai && jr.jam_selesai ? `${jr.jam_mulai}–${jr.jam_selesai} WITA` : null),
    baris('Materi', [jr.materi, jr.submateri].filter(Boolean).join(' – ')),
    baris('Uraian', jr.kegiatan),
    baris('Metode', (jr.metode || []).join(', ') || null),
    baris('Media', (jr.media || []).join(', ') || null),
    baris('Alat', (jr.alat || []).join(', ') || null),
    baris('Sumber', (jr.sumber || []).join(', ') || null),
    baris('Capaian', jr.capaian),
    baris('Kendala', jr.kendala),
    baris('Tindak lanjut', jr.tindak_lanjut),
    baris('Catatan', jr.catatan),
  ] : []

  let daftar = []
  if (d.format === 'kelompok') {
    const bagian = (kode, judul) => {
      const isi = d.anggota.filter((a) => kode.includes(a.kode || 'H'))
      if (!isi.length) return []
      return ['', `${TANDA[kode[0]].e} *${judul} (${isi.length})*`, ...isi.map((a, i) => `${i + 1}. ${a.nama}${(a.kode || 'H') === 'T' ? ' (terlambat)' : ''}${(a.kode || 'H') === 'H' || (a.kode || 'H') === 'T' ? '' : ket(a)}`)]
    }
    daftar = [...bagian(['H', 'T'], 'Hadir'), ...bagian(['I'], 'Izin'), ...bagian(['S'], 'Sakit'), ...bagian(['A'], 'Tanpa keterangan'), ...bagian(['B'], 'Bolos')]
  } else {
    daftar = ['', `*Daftar ${d.jenis === 'asrama' ? 'santri binaan' : 'anggota'} (${n})*`,
      ...d.anggota.map((a, i) => { const k = a.kode || 'H'; return `${i + 1}. ${TANDA[k].e} ${a.nama}${k === 'H' ? '' : ` (${TANDA[k].n.toLowerCase()})${ket(a)}`}` })]
  }
  const ringkas = ['', '*Ringkasan*',
    `Jumlah santri: ${n}`,
    `Hadir: ${hadir} (${persen(hadir, n)})${hit.T ? `, termasuk ${hit.T} terlambat` : ''}${hit.B ? `, ${hit.B} bolos` : ''}`,
    `Izin: ${hit.I}`, `Sakit: ${hit.S}`, `Tanpa keterangan: ${hit.A}`,
    baris('Catatan', d.catatan),
  ]
  return gabung([...kepala, ...jurnal, ...daftar, ...ringkas, '', kaki()])
}

/**
 * Perkembangan hafalan satu sesi halaqah.
 * @param {object} d { kelompok, pengasuh: [nama], tanggal, sesi, jam, santri: [{ nama, kehadiran, tidakSetor, sabaq_lama, sabaq, sabqi, manzil, juz_sedang, catatan, total_resmi }], catatan }
 */
export function laporanSetoran(d) {
  const sn = d.santri
  const naik = sn.filter((s) => !s.tidakSetor && s.sabaq != null && s.sabaq > s.sabaq_lama)
  const sama = sn.filter((s) => !s.tidakSetor && !naik.includes(s))
  const tidak = sn.filter((s) => s.tidakSetor)
  const total = naik.reduce((t, s) => t + (s.sabaq - s.sabaq_lama), 0)
  const rinci = (s) => [s.sabqi != null && `sabqi ${formatPosisi(s.sabqi)}`, s.manzil != null && `manzil ${formatPosisi(s.manzil)}`].filter(Boolean).join(', ')
  return gabung([
    '*LAPORAN SETORAN HAFALAN*',
    baris('Halaqah', tanpaAwalan(d.kelompok, 'Halaqah')),
    baris('Muhaffizh', (d.pengasuh || []).join(', ') || null),
    baris('Hari/tanggal', formatHari(d.tanggal)),
    baris('Sesi', [d.sesi, d.jam && `${d.jam} WITA`].filter(Boolean).join(', ')),
    ...(naik.length ? ['', `📈 *Hafalan bertambah (${naik.length})*`, ...naik.map((s, i) =>
      `${i + 1}. ${s.nama} – sabaq ${formatPosisi(s.sabaq)} (+${s.sabaq - s.sabaq_lama} hal)${rinci(s) ? `; ${rinci(s)}` : ''}${s.catatan ? ` – ${s.catatan}` : ''}`)] : []),
    ...(sama.length ? ['', `➖ *Setor, posisi sabaq tetap (${sama.length})*`, ...sama.map((s, i) =>
      `${i + 1}. ${s.nama} – sabaq ${formatPosisi(s.sabaq_lama)}${rinci(s) ? `; ${rinci(s)}` : ''}${s.catatan ? ` – ${s.catatan}` : ''}`)] : []),
    ...(tidak.length ? ['', `🚫 *Tidak setor (${tidak.length})*`, ...tidak.map((s, i) => `${i + 1}. ${s.nama} (${(TANDA[s.kehadiran]?.n || 'tidak hadir').toLowerCase()})${s.catatan ? ` – ${s.catatan}` : ''}`)] : []),
    '', '*Ringkasan*',
    `Jumlah santri: ${sn.length}`,
    `Setor: ${sn.length - tidak.length} · bertambah ${naik.length} · tetap ${sama.length}`,
    `Tidak setor: ${tidak.length}`,
    `Total penambahan: +${total} halaman`,
    baris('Catatan', d.catatan),
    '', kaki(),
  ])
}

/**
 * Jurnal mengajar satu hari (guru mapel).
 * @param {object} d { guru, tanggal, pertemuan: [{ mapel, kelas, jp, jam, status, materi, metode, media, hadir, jumlah, tidakHadir: [{ nama, kode }], keterangan }] }
 */
export function laporanMengajar(d) {
  const p = d.pertemuan
  const ok = p.filter((x) => x.status !== 'tidak_terlaksana')
  const kodeN = (k) => ({ S: 'sakit', I: 'izin', A: 'alfa', B: 'bolos', T: 'terlambat' }[k] || k)
  return gabung([
    '*LAPORAN JURNAL MENGAJAR*',
    baris('Guru', d.guru),
    baris('Hari/tanggal', formatHari(d.tanggal)),
    ...p.flatMap((x, i) => ['',
      `${i + 1}. *${x.mapel} · Kelas ${x.kelas}*`,
      `   ${x.jp}${x.jam ? `, ${x.jam} WITA` : ''}`,
      ...(x.status === 'tidak_terlaksana' ? [`   ❌ Tidak terlaksana${x.keterangan ? `: ${x.keterangan}` : ''}`] : [
        x.materi ? `   Materi: ${x.materi}` : null,
        x.tujuan ? `   Tujuan: ${x.tujuan}` : null,
        x.metode?.length ? `   Metode: ${x.metode.join(', ')}` : null,
        x.media?.length ? `   Media: ${x.media.join(', ')}` : null,
        x.alat?.length ? `   Alat: ${x.alat.join(', ')}` : null,
        x.sumber?.length ? `   Sumber: ${x.sumber.join(', ')}` : null,
        x.jumlah != null ? `   Kehadiran: ${x.hadir}/${x.jumlah} santri${x.tidakHadir?.length ? ` (tidak hadir: ${x.tidakHadir.map((t) => `${t.nama} – ${kodeN(t.kode)}`).join('; ')})` : ' ✅'}` : null,
        x.keterangan ? `   Catatan: ${x.keterangan}` : null,
      ]),
    ]),
    '', '*Ringkasan*',
    `Pertemuan: ${p.length} · terlaksana ${ok.length}${p.length - ok.length ? ` · tidak terlaksana ${p.length - ok.length}` : ''}`,
    '', kaki(),
  ])
}

/** 14.4.0: laporan jurnal mengajar satu periode (pekan/bulan) — per kelas × mapel: keterlaksanaan, materi, kehadiran. */
export function laporanMengajarPeriode(d) {
  const per = new Map()
  for (const x of d.pertemuan) { const k = `${x.kelas}|${x.mapel}`; if (!per.has(k)) per.set(k, []); per.get(k).push(x) }
  const blok = [...per.entries()].flatMap(([k, xs], i) => {
    const [kelas, mapel] = k.split('|'); const ok = xs.filter((x) => x.status === 'terlaksana')
    const ab = ok.filter((x) => x.jumlah_anggota); const h = ab.reduce((n, x) => n + x.jumlah_hadir, 0); const a = ab.reduce((n, x) => n + x.jumlah_anggota, 0)
    const sering = {}; for (const x of ok) for (const t of x.tidak_hadir || []) if (t.kode !== 'T') sering[t.nama] = (sering[t.nama] || 0) + 1
    const top = Object.entries(sering).sort((p, q) => q[1] - p[1]).slice(0, 5)
    return ['', `${i + 1}. *${mapel} · Kelas ${kelas}*`,
      `   Terlaksana ${ok.length}/${xs.length} pertemuan (${ok.reduce((n, x) => n + x.jp, 0)} JP)`,
      ...ok.map((x) => `   • ${formatPendek(x.tanggal)}: ${[x.bab, x.subbab].filter(Boolean).join(' – ') || x.materi || '–'}`),
      ...xs.filter((x) => x.status !== 'terlaksana').map((x) => `   ❌ ${formatPendek(x.tanggal)} tidak terlaksana${x.keterangan ? ': ' + x.keterangan : ''}`),
      a ? `   Kehadiran santri: ${persen(h, a)}` : null,
      top.length ? `   Sering tidak hadir: ${top.map(([n, c]) => `${n} (${c}×)`).join(', ')}` : null]
  })
  const semua = d.pertemuan.filter((x) => x.status === 'terlaksana')
  return gabung([
    '*LAPORAN JURNAL MENGAJAR*',
    baris('Guru', d.guru),
    baris('Periode', `${formatPendek(d.mulai)} s.d. ${formatPendek(d.selesai)}`),
    ...blok,
    '', '*Ringkasan*',
    `Pertemuan terlaksana: ${semua.length}/${d.pertemuan.length} · ${semua.reduce((n, x) => n + x.jp, 0)} JP`,
    '', kaki(),
  ])
}

/** 14.4.0: laporan kegiatan ekskul satu periode — pertemuan, materi, kehadiran anggota. */
export function laporanEkskulPeriode(d) {
  const ok = d.jurnal
  const h = ok.reduce((n, x) => n + (x.jumlah_hadir || 0), 0); const a = ok.reduce((n, x) => n + (x.jumlah_anggota || 0), 0)
  return gabung([
    '*LAPORAN KEGIATAN EKSKUL*',
    baris('Ekskul', d.ekskul),
    baris('Pembina', d.pembina),
    baris('Periode', `${formatPendek(d.mulai)} s.d. ${formatPendek(d.selesai)}`),
    '', `*Pertemuan (${ok.length})*`,
    ...ok.map((x, i) => {
      const r = x.rincian || {}
      return gabung([`${i + 1}. ${formatHari(x.tanggal)}${r.jam_mulai && r.jam_selesai ? `, ${r.jam_mulai}–${r.jam_selesai}` : ''}`,
        `   Materi: ${[r.materi, r.submateri].filter(Boolean).join(' – ') || x.topik || '–'}`,
        r.capaian ? `   Capaian: ${r.capaian}` : null,
        x.jumlah_anggota ? `   Hadir: ${x.jumlah_hadir}/${x.jumlah_anggota}` : null])
    }),
    '', '*Ringkasan*',
    a ? `Kehadiran anggota rata-rata: ${persen(h, a)}` : null,
    d.perhatian?.length ? `Perlu perhatian (kehadiran rendah): ${d.perhatian.join(', ')}` : null,
    '', kaki(),
  ])
}
