// SIMKA PRO | src/stores/rapor.js | v1.3 | 14.9.3: data demo hanya santri aktif | 18/10/2026
// v1.1: dataRapor (rapor SMA/Wustha, leger, sampul), dataRaporTahfizh, simpanNilaiManual, simpanKeputusan.
// v1.2: dataRapor menambah foto_id dan prestasi (bertanda masuk rapor, dalam rentang semester) per santri (pelengkap_rapor).
// Isian pelengkap rapor oleh pengasuh kelompok:
//   Pengembangan diri (ekskul)  : pembina mengisi predikat A–D per santri (+ deskripsi khusus); acuan kehadiran ekskul
//   Rapor kelas (wali kelas)    : catatan wali kelas, kokurikuler SMA (dimensi 1–4) — bahan dari nilai, kehadiran, hafalan
//   Rapor halaqah (muhaffizh)   : catatan muhaffizh — bahan dari kehadiran halaqah, capaian bulanan, hafalan, UTAS
// Hak isi: pengasuh saat periode jenis rapor Dibuka; pengelola nilai kapan saja. Penulisan hanya lewat fungsi SQL.
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { dataKelompokDemo } from '@/lib/demoKelompok'
import { dataPenilaianDemo } from '@/lib/demoPenilaian'
import { dataTahfizhDemo, isiSantriDemo } from '@/lib/demoTahfizh'
import { pesanGalat } from './lembaga'
import { useSesi } from './sesi'
import { useSantri } from './santri'
import { usePrestasi } from './prestasi'

const rpc = async (nama, arg) => { const { data, error } = await supabase.rpc(nama, arg); if (error) throw new Error(pesanGalat(error)); return data }

// ---------- Data contoh ----------
const demo = { pd: {}, kok: {}, cat: {}, manual: {}, kep: {} }
const ACAK = (t) => { let h = 2166136261; for (const c of t) { h ^= c.charCodeAt(0); h = Math.imul(h, 16777619) } h ^= h >>> 13; h = Math.imul(h, 0x5bd1e995); return ((h ^ (h >>> 15)) >>> 0) / 4294967296 }
const antara = (t, a, b) => Math.round(a + ACAK(t) * (b - a))
function siapDemo() {
  const san = useSantri(); const kel = dataKelompokDemo(san.daftar); isiSantriDemo(san.daftar.filter((s) => s.status === 'aktif'))
  return { san, kel, pn: dataPenilaianDemo(), sesi: useSesi() }
}
const asuhanDemo = (g) => useSesi().peran !== 'pegawai' || (g.pengasuh || []).some((p) => p.employee_id === 'p1')
function cekDemo(g, smt, jenis) {
  const { pn, sesi } = siapDemo()
  if (sesi.isAdmin) return
  if (!asuhanDemo(g)) throw new Error('Hanya pengasuh kelompok ini (atau pengelola nilai) yang dapat mengisinya.')
  const p = pn.periode.find((x) => x.jenis === jenis && x.semester === smt)
  if (!p || p.status === 'disiapkan') throw new Error(`Periode penilaian ${jenis === 'sma' ? 'SMA' : jenis === 'wustha' ? 'Wustha' : 'Tahfizh'} semester ${smt} belum dibuka.`)
  if (p.status === 'ditutup') throw new Error('Periode penilaian sudah ditutup; perubahan melalui pengelola nilai.')
}
const bolehDemo = (g, smt, jenis) => { try { cekDemo(g, smt, jenis); return true } catch { return false } }
const anggotaDemo = (kel, san, gid) => kel.anggota.filter((a) => a.group_id === gid && !a.selesai).map((a) => san.daftar.find((s) => s.id === a.student_id)).filter(Boolean)
  .sort((a, b) => a.nama_lengkap.localeCompare(b.nama_lengkap, 'id'))
const kelasDari = (kel, sid) => { const a = kel.anggota.find((x) => x.student_id === sid && kel.kelompok.find((k) => k.id === x.group_id)?.jenis === 'kelas'); return a ? kel.kelompok.find((k) => k.id === a.group_id)?.nama : null }
function hadirDemo(t, sesi) { const h = antara(t, Math.round(sesi * 0.72), sesi); const sisa = sesi - h; return { sesi, hadir: h, sakit: Math.ceil(sisa / 2), izin: Math.floor(sisa / 3), absen: sisa - Math.ceil(sisa / 2) - Math.floor(sisa / 3) } }
function utasDemo(t) { const n = antara(t + 'u', 62, 97); const p = dataPenilaianDemo().predikat.find((x) => x.kelompok === 'utas' && n >= x.nilai_min && n <= x.nilai_maks); return { nilai: n, huruf: p?.huruf, tuntas: n >= 80 } }


const AYAH = ['Abdul Rahman', 'Muhammad Yusuf', 'Hasanuddin', 'Syamsuddin', 'Ahmad Fauzi', 'Rusli', 'Baharuddin', 'Kamaruddin']
const IBU = ['Nurhayati', 'Hasnah', 'Sitti Aminah', 'Rahmawati', 'Nurjannah', 'Hadijah', 'Masita', 'Rosmiati']
function biodataDemo(s) {
  const i = Math.floor(ACAK(s.id + 'b') * 8)
  return { id: s.id, nis: s.nis, nisn: s.nisn || `00${s.nis}`.slice(-10), nama: s.nama_lengkap, panggilan: s.nama_panggilan || null, jenis_kelamin: s.jenis_kelamin,
    tempat_lahir: s.tempat_lahir || 'Gowa', tanggal_lahir: s.tanggal_lahir || null, agama: 'Islam', status_keluarga: 'Anak Kandung', anak_ke: 1 + (i % 3),
    alamat: s.alamat || 'Jl. Poros Malino, Bontoramba, Somba Opu, Gowa', telepon_rumah: null, asal_sekolah: s.asal_sekolah || 'SD Islam Terpadu Wahdah Islamiyah',
    diterima_tingkat: s.jenjang === 'sma' ? 10 : 7, tanggal_masuk: s.tanggal_masuk || '2025-07-14', jenjang: s.jenjang, tingkat: s.tingkat, status: s.status,
    ayah: { nama: AYAH[i], pekerjaan: 'Wiraswasta', no_hp: '081234567890', alamat: null }, ibu: { nama: IBU[i], pekerjaan: 'Ibu rumah tangga', no_hp: null, alamat: null }, wali: null,
    alamat_ortu: s.alamat || 'Jl. Poros Malino, Bontoramba, Somba Opu, Gowa' }
}
const TP_DEMO = { MTK: ['bilangan berpangkat', 'persamaan linear'], BIND: ['teks eksposisi', 'teks laporan hasil observasi'], BING: ['descriptive text', 'simple present tense'], PAI: ['berbuat baik kepada orang tua'] }
function rentangDemo(smt) { return smt === 1 ? { mulai: '2026-07-13', selesai: '2026-12-31' } : { mulai: '2027-01-01', selesai: '2027-06-30' } }
function tahfizhSantriDemo(s, smt, kel) {
  const t = s.id + 'h' + smt; const tz = dataTahfizhDemo(); const total = (tz.juz[s.id] || []).length; const r = rentangDemo(smt)
  const hqA = kel.anggota.find((a) => a.student_id === s.id && kel.kelompok.find((k) => k.id === a.group_id)?.jenis === 'halaqah'); const hq = hqA ? kel.kelompok.find((k) => k.id === hqA.group_id) : null
  const kA = kel.anggota.find((a) => a.student_id === s.id && kel.kelompok.find((k) => k.id === a.group_id)?.jenis === 'kelas'); const kls = kA ? kel.kelompok.find((k) => k.id === kA.group_id) : null
  let posisi = total * 20 + antara(t + 'p0', 0, 12); const bulanan = []
  for (let i = 0; i < 6; i++) { const b = smt === 1 ? `2026-${String(7 + i).padStart(2, '0')}-01` : `2027-${String(1 + i).padStart(2, '0')}-01`; if (b > new Date().toISOString().slice(0, 10)) break
    const tambah = antara(t + 'm' + i, 3, 22); posisi += tambah; bulanan.push({ bulan: b, posisi_akhir_hal: posisi, tambah_hal: tambah, target_hal: 10, status: tambah >= 10 ? 'tercapai' : 'tidak_tercapai', total_resmi: total }) }
  const u = utasDemo(s.id + smt); const juz = (tz.juz[s.id] || []).map((x) => x.juz).slice(-(s.jenjang === 'sma' ? 5 : 3))
  const kenaikan = antara(t + 'k', 0, 1) ? [{ juz: total + 1, tajwid: antara(t + 'kt', 75, 95), itqan: antara(t + 'ki', 75, 95), nilai: null, huruf: null, predikat: 'Sangat Baik', hasil: 'tuntas', diuji_pada: r.mulai.slice(0, 8) + '20' }] : []
  return { kelas: kls?.nama || null, halaqah: hq?.nama || null, hq, muhaffizh: hq?.pengasuh?.[0] ? { nama: hq.pengasuh[0].nama, niy: null } : null, kehadiran: hadirHariDemo(t, 150), bulanan, kenaikan, total_juz: total,
    utas: { juz, total_juz: total, tajwid: u.nilai + 3 > 100 ? 100 : u.nilai + 3, itqan: u.nilai - 3, nilai: u.nilai, huruf: u.huruf, tuntas: u.tuntas, status: 'final', diuji_pada: smt === 1 ? '2026-12-08' : '2027-06-07' },
    catatan: demo.cat[`${smt}|${s.id}|muhaffizh`] || null }
}
function hadirHariDemo(t, hari) { const k = hadirDemo(t, hari); return { hari, hadir: k.hadir, sakit: k.sakit, izin: k.izin, absen: k.absen } }

export const useRapor = defineStore('rapor', {
  state: () => ({ semester: 1 }),
  actions: {
    // ---------- Pengembangan diri ----------
    async ekskulSaya(smt) {
      if (MODE_DEMO) {
        await useSantri().muat()
        const { san, kel, sesi } = siapDemo()
        const daftar = kel.kelompok.filter((g) => g.jenis === 'ekskul' && g.aktif && (sesi.isAdmin || asuhanDemo(g) || sesi.tingkat('absensi_ekskul') >= 1)).map((g) => ({
          group_id: g.id, nama: g.nama, keterangan: g.keterangan, asuhan_saya: asuhanDemo(g) && sesi.peran === 'pegawai', pembina: (g.pengasuh || []).map((p) => p.nama).join(', '),
          santri: anggotaDemo(kel, san, g.id).length, terisi: Object.values(demo.pd).filter((x) => x.group_id === g.id && x.semester === smt && x.nilai).length }))
        return { semester: smt, daftar }
      }
      return rpc('ekskul_nilai_saya', { p_semester: smt })
    },
    async nilaiEkskul(groupId, smt) {
      if (MODE_DEMO) {
        await useSantri().muat()
        const { san, kel, pn } = siapDemo(); const g = kel.kelompok.find((x) => x.id === groupId)
        return { ekskul: { group_id: g.id, nama: g.nama, keterangan: g.keterangan }, semester: smt, boleh: { sma: bolehDemo(g, smt, 'sma'), wustha: bolehDemo(g, smt, 'wustha') },
          predikat: pn.predikat.filter((p) => p.kelompok === 'pd').map((p) => ({ huruf: p.huruf, sebutan: p.sebutan, deskripsi: p.deskripsi })),
          santri: anggotaDemo(kel, san, groupId).map((s) => { const k = hadirDemo(groupId + s.id, 14); const x = demo.pd[`${smt}|${groupId}|${s.id}`]
            return { id: s.id, nis: s.nis, nama: s.nama_lengkap, jenis_kelamin: s.jenis_kelamin, jenjang: s.jenjang, kelas: kelasDari(kel, s.id), sesi: k.sesi, hadir: k.hadir, nilai: x?.nilai || null, deskripsi: x?.deskripsi || null } }) }
      }
      return rpc('nilai_ekskul', { p_group: groupId, p_semester: smt })
    },
    /** isi: [{ student_id, nilai, deskripsi }] */
    async simpanEkskul(groupId, smt, isi) {
      if (MODE_DEMO) {
        await useSantri().muat()
        const { san, kel, pn } = siapDemo(); const g = kel.kelompok.find((x) => x.id === groupId); const huruf = pn.predikat.filter((p) => p.kelompok === 'pd').map((p) => p.huruf)
        for (const x of isi) {
          cekDemo(g, smt, san.daftar.find((s) => s.id === x.student_id)?.jenjang)
          if (x.nilai && !huruf.includes(String(x.nilai).toUpperCase())) throw new Error(`Nilai harus salah satu: ${huruf.join(', ')}.`)
          const k = `${smt}|${groupId}|${x.student_id}`
          if (!x.nilai && !x.deskripsi) delete demo.pd[k]; else demo.pd[k] = { group_id: groupId, semester: smt, student_id: x.student_id, nilai: x.nilai ? String(x.nilai).toUpperCase() : null, deskripsi: x.deskripsi || null }
        }
        return isi.length
      }
      return rpc('simpan_nilai_ekskul', { p_group: groupId, p_semester: smt, p: isi })
    },

    // ---------- Rapor kelas (wali kelas) ----------
    async bahanKelas(groupId, smt) {
      if (MODE_DEMO) {
        await useSantri().muat()
        const { san, kel, pn } = siapDemo(); const g = kel.kelompok.find((x) => x.id === groupId); const tz = dataTahfizhDemo()
        const ket = pn.ketentuan[g.jenjang]; const per = pn.periode.find((p) => p.jenis === g.jenjang && p.semester === smt)
        const mapel = pn.mapel.filter((m) => m.jenis === g.jenjang && m.tingkat === g.tingkat && m.sumber !== 'manual')
        return { kelas: { group_id: g.id, nama: g.nama, jenjang: g.jenjang, tingkat: g.tingkat }, semester: smt, boleh: bolehDemo(g, smt, g.jenjang),
          kokurikuler: { aktif: !!ket?.pakai_kokurikuler, dimensi: ket?.dimensi || [], tema: per?.tema_kokurikuler || null },
          santri: anggotaDemo(kel, san, groupId).map((s) => {
            const t = s.id + smt
            return { id: s.id, nis: s.nis, nama: s.nama_lengkap, panggilan: s.nama_panggilan || null, jenis_kelamin: s.jenis_kelamin, kehadiran: hadirDemo(t, 96),
              mapel: mapel.slice(0, 8).map((m) => ({ mapel: m.nama, nilai: antara(t + m.nama, 66, 98), kkm: m.kkm })),
              sikap: [antara(t + 's', 0, 3) ? 'A' : 'B'], tambah_juz: antara(t + 'j', 0, 2), total_juz: (tz.juz[s.id] || []).length, utas: utasDemo(t),
              pd: Object.values(demo.pd).filter((x) => x.student_id === s.id && x.semester === smt && x.nilai).map((x) => ({ kegiatan: kel.kelompok.find((k) => k.id === x.group_id)?.nama, nilai: x.nilai })),
              kokurikuler: demo.kok[`${smt}|${s.id}`] || null, catatan: demo.cat[`${smt}|${s.id}|wali`] || null }
          }) }
      }
      return rpc('bahan_rapor_kelas', { p_group: groupId, p_semester: smt })
    },
    /** isi: [{ student_id, dimensi: {nama: 1..4}, deskripsi }] */
    async simpanKokurikuler(groupId, smt, isi) {
      if (MODE_DEMO) {
        await useSantri().muat()
        const { kel } = siapDemo(); const g = kel.kelompok.find((x) => x.id === groupId); cekDemo(g, smt, g.jenjang)
        for (const x of isi) { if (Object.values(x.dimensi || {}).some((v) => !/^[1-4]$/.test(String(v)))) throw new Error('Nilai dimensi harus 1–4.'); demo.kok[`${smt}|${x.student_id}`] = { dimensi: { ...x.dimensi }, deskripsi: x.deskripsi || null } }
        return isi.length
      }
      return rpc('simpan_kokurikuler', { p_group: groupId, p_semester: smt, p: isi })
    },
    /** jenis: wali | muhaffizh; isi: [{ student_id, teks }] (teks kosong = hapus) */
    async simpanCatatan(groupId, smt, jenis, isi) {
      if (MODE_DEMO) {
        await useSantri().muat()
        const { kel } = siapDemo(); const g = kel.kelompok.find((x) => x.id === groupId); cekDemo(g, smt, jenis === 'muhaffizh' ? 'tahfizh' : g.jenjang)
        for (const x of isi) { const t = (x.teks || '').trim(); if (t && (t.length < 3 || t.length > 1000)) throw new Error('Catatan 3–1000 huruf.'); const k = `${smt}|${x.student_id}|${jenis}`; if (t) demo.cat[k] = t; else delete demo.cat[k] }
        return isi.length
      }
      return rpc('simpan_catatan_rapor', { p_group: groupId, p_semester: smt, p_jenis: jenis, p: isi })
    },

    // ---------- Rapor halaqah (muhaffizh) ----------
    async halaqahSaya() {
      if (MODE_DEMO) {
        await useSantri().muat()
        const { san, kel, sesi } = siapDemo()
        return kel.kelompok.filter((g) => g.jenis === 'halaqah' && g.aktif && (sesi.isAdmin || asuhanDemo(g))).map((g) => ({ group_id: g.id, nama: g.nama, jenis_kelamin: g.jenis_kelamin,
          asuhan_saya: asuhanDemo(g) && sesi.peran === 'pegawai', muhaffizh: (g.pengasuh || []).map((p) => p.nama).join(', '), santri: anggotaDemo(kel, san, g.id).length }))
      }
      return rpc('halaqah_rapor_saya')
    },
    async bahanHalaqah(groupId, smt) {
      if (MODE_DEMO) {
        await useSantri().muat()
        const { san, kel } = siapDemo(); const g = kel.kelompok.find((x) => x.id === groupId); const tz = dataTahfizhDemo()
        return { halaqah: { group_id: g.id, nama: g.nama, jenis_kelamin: g.jenis_kelamin, muhaffizh: (g.pengasuh || []).map((p) => p.nama).join(', ') }, semester: smt, boleh: bolehDemo(g, smt, 'tahfizh'),
          santri: anggotaDemo(kel, san, groupId).map((s) => { const t = s.id + 'h' + smt; const bt = 6; const tc = antara(t + 'b', 2, 6)
            return { id: s.id, nis: s.nis, nama: s.nama_lengkap, panggilan: s.nama_panggilan || null, jenis_kelamin: s.jenis_kelamin, jenjang: s.jenjang, kehadiran: hadirDemo(t, 210),
              tambah_hal: antara(t + 'p', 4, 40), bulan_tercapai: tc, bulan_total: bt, tambah_juz: antara(t + 'j', 0, 2), total_juz: (tz.juz[s.id] || []).length, kenaikan_lulus: antara(t + 'k', 0, 1),
              utas: utasDemo(s.id + smt), catatan: demo.cat[`${smt}|${s.id}|muhaffizh`] || null } }) }
      }
      return rpc('bahan_rapor_halaqah', { p_group: groupId, p_semester: smt })
    },
    // ---------- Cetak rapor ----------
    /** Data rapor kelas + pelengkap (foto santri, prestasi semester). Pelengkap gagal → rapor tetap tampil tanpanya. */
    async dataRapor(groupId, smt) {
      const D = await this.dataRaporDasar(groupId, smt)
      try {
        let p
        if (MODE_DEMO) {
          const r = D.rentang || {}; const semua = await usePrestasi().daftar({ mulai: r.mulai || null, selesai: r.selesai || null })
          p = (D.santri || []).map((s) => ({ id: s.id, foto_id: useSantri().cari(s.id)?.foto_id || null,
            prestasi: semua.filter((x) => x.student_id === s.id && x.masuk_rapor) }))
        } else p = (await rpc('pelengkap_rapor', { p_group: groupId, p_semester: smt })) || []
        const peta = new Map(p.map((x) => [x.id, x]))
        for (const s of D.santri || []) { const x = peta.get(s.id); s.foto_id = x?.foto_id || null; s.prestasi = x?.prestasi || [] }
      } catch { /* rapor tetap dapat dicetak tanpa foto dan prestasi */ }
      return D
    },
    async dataRaporDasar(groupId, smt) {
      if (MODE_DEMO) {
        await useSantri().muat()
        const b = await this.bahanKelas(groupId, smt); const { san, kel, pn } = siapDemo(); const g = kel.kelompok.find((x) => x.id === groupId)
        const ket = pn.ketentuan[g.jenjang]; const mapel = pn.mapel.filter((m) => m.jenis === g.jenjang && m.tingkat === g.tingkat && m.aktif).sort((a, c) => a.urutan - c.urutan)
        return { kelas: { group_id: g.id, nama: g.nama, keterangan: g.keterangan, jenjang: g.jenjang, tingkat: g.tingkat, jenis_kelamin: g.jenis_kelamin },
          ta: { id: 'ta1', nama: '2026/2027' }, semester: smt, rentang: rentangDemo(smt), boleh: b.boleh,
          periode: pn.periode.find((p) => p.jenis === g.jenjang && p.semester === smt), ketentuan: ket, penanda: ket.penanda,
          wali: (g.pengasuh || []).map((p) => ({ nama: p.nama, niy: p.niy || '1990010120150101', peran: p.peran })),
          predikat: pn.predikat.filter((p) => [g.jenjang, 'pd', 'sikap', 'utas'].includes(p.kelompok)),
          kalimat_hadir: pn.kalimat.filter((k) => k.kategori === 'kehadiran' && (!k.jenis || k.jenis === g.jenjang)).map((k) => ({ min: k.min_nilai, teks: k.teks })),
          mapel: mapel.map((m) => ({ id: m.id, urutan: m.urutan, kelompok: m.kelompok, nama: m.nama, singkatan: m.singkatan, kkm: m.kkm, sumber: m.sumber,
            sumber_mapel: (m.sumber_mapel || []).map((x) => x.nama).join(' + '), guru: null })),
          santri: b.santri.map((x) => {
            const s = san.daftar.find((y) => y.id === x.id); const t = x.id + smt; const tz = tahfizhSantriDemo(s, smt, kel)
            const nilai = {}
            for (const m of mapel) {
              if (m.sumber === 'manual') { const v = demo.manual[`${smt}|${m.id}|${x.id}`]; if (v) nilai[m.id] = { nilai: v.nilai, keterampilan: v.keterampilan, deskripsi: v.deskripsi } }
              else if (m.sumber === 'tahfizh') nilai[m.id] = { nilai: tz.utas.nilai, keterampilan: tz.utas.nilai }
              else if ((m.sumber_mapel || []).length) { const n = antara(t + m.nama, 66, 98); nilai[m.id] = { nilai: n, keterampilan: g.jenjang === 'wustha' ? Math.min(100, n + antara(t + m.nama + 'k', -4, 4)) : n, sikap: antara(t + m.nama + 's', 0, 3) ? 'A' : 'B', tp: TP_DEMO[m.sumber_mapel[0].kode] || ['materi pokok semester ini'] } }
            }
            return { ...biodataDemo(s), kehadiran: { hari: x.kehadiran.sesi, hadir: x.kehadiran.hadir, sakit: x.kehadiran.sakit, izin: x.kehadiran.izin, absen: x.kehadiran.absen }, nilai,
              pd: (x.pd || []).map((p) => ({ ...p, deskripsi: null })), kokurikuler: x.kokurikuler, catatan: x.catatan,
              keputusan: smt === 2 ? demo.kep[x.id] || null : null, tahfizh: { total_juz: tz.total_juz, utas: tz.utas } }
          }) }
      }
      return rpc('data_rapor', { p_group: groupId, p_semester: smt })
    },
    async dataRaporTahfizh(groupId, smt) {
      if (MODE_DEMO) {
        await useSantri().muat()
        const { san, kel, pn } = siapDemo(); const g = kel.kelompok.find((x) => x.id === groupId)
        return { kelompok: { group_id: g.id, nama: g.nama, jenis: g.jenis, jenjang: g.jenjang, tingkat: g.tingkat }, ta: { id: 'ta1', nama: '2026/2027' }, semester: smt, rentang: rentangDemo(smt),
          periode: pn.periode.find((p) => p.jenis === 'tahfizh' && p.semester === smt), ketentuan: pn.ketentuan.tahfizh,
          fase: { sma: pn.ketentuan.sma.fase, wustha: pn.ketentuan.wustha.fase }, penanda: null, predikat: pn.predikat.filter((p) => p.kelompok === 'utas'),
          kalimat_hadir: pn.kalimat.filter((k) => k.kategori === 'kehadiran_halaqah').map((k) => ({ min: k.min_nilai, teks: k.teks })),
          santri: anggotaDemo(kel, san, groupId).map((s) => { const x = tahfizhSantriDemo(s, smt, kel); delete x.hq; return { ...biodataDemo(s), ...x } }) }
      }
      return rpc('data_rapor_tahfizh', { p_group: groupId, p_semester: smt })
    },
    /** isi: [{ student_id, report_subject_id, nilai, keterampilan?, deskripsi? }] */
    async simpanNilaiManual(groupId, smt, isi) {
      if (MODE_DEMO) {
        await useSantri().muat()
        const { kel } = siapDemo(); const g = kel.kelompok.find((x) => x.id === groupId); cekDemo(g, smt, g.jenjang)
        for (const x of isi) { if ([x.nilai, x.keterampilan].some((v) => v !== '' && v != null && !(Number(v) >= 0 && Number(v) <= 100))) throw new Error('Nilai harus 0–100.')
          const k = `${smt}|${x.report_subject_id}|${x.student_id}`; if ((x.nilai === '' || x.nilai == null) && !x.deskripsi) delete demo.manual[k]
          else demo.manual[k] = { nilai: x.nilai === '' ? null : Number(x.nilai), keterampilan: x.keterampilan === '' || x.keterampilan == null ? null : Number(x.keterampilan), deskripsi: x.deskripsi || null } }
        return isi.length
      }
      return rpc('simpan_nilai_manual', { p_group: groupId, p_semester: smt, p: isi })
    },
    /** isi: [{ student_id, keputusan: naik|tinggal|lulus|tidak_lulus|'', catatan? }] — semester 2 */
    async simpanKeputusan(groupId, isi) {
      if (MODE_DEMO) {
        await useSantri().muat()
        const { kel } = siapDemo(); const g = kel.kelompok.find((x) => x.id === groupId); cekDemo(g, 2, g.jenjang)
        for (const x of isi) { if (!x.keputusan) delete demo.kep[x.student_id]; else demo.kep[x.student_id] = { keputusan: x.keputusan, ke_tingkat: x.keputusan === 'naik' ? g.tingkat + 1 : x.keputusan === 'tinggal' ? g.tingkat : null, catatan: x.catatan || null } }
        return isi.length
      }
      return rpc('simpan_keputusan_rapor', { p_group: groupId, p: isi })
    },
  },
})
