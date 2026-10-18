// SIMKA PRO | src/stores/tahfizh.js | v1.7 | 14.9.1: nilai ujian dengan keterangan dan catatan perbaikan; data WA ujian (demo) | 18/10/2026
// Tahfizh: hak pengguna, pengaturan per tahun ajaran (KKM, bobot, target, predikat, pekan efektif), penguji,
// daftar santri beserta program, posisi hafalan, dan capaian juz resmi. Penulisan hanya lewat fungsi SQL.
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { dataTahfizhDemo, isiSantriDemo } from '@/lib/demoTahfizh'
import { PEGAWAI_DEMO } from '@/lib/demo'
import { pesanGalat } from './lembaga'
import { useSesi } from './sesi'
import { useSantri } from './santri'
import { useKelompokSantri } from './kelompokSantri'
import { useAbsensiSantri } from './absensiSantri'
import { setoranDemo, capaianDemo, ujianDemo } from '@/lib/demoTahfizh'
import { hitungNilai } from '@/lib/tahfizh'
import { PENGATURAN_SERTIFIKAT } from '@/lib/dokumenTahfizh'
import { hariIniISO } from '@/lib/tanggal'

// ---------- Mode demo: dokumen tahfizh ----------
let DOK_DEMO = null; let SET_DEMO = null
const kodeDemoDok = () => { const a = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; let k = ''; for (let i = 0; i < 8; i++) k += a[Math.floor(Math.random() * a.length)]; return k.slice(0, 4) + '-' + k.slice(4) }
const KEPALA_DEMO = { nama: 'Ust. Abdurrahman Hafizh, Lc.', niy: '1988031220150101', jabatan: 'Kepala Bidang Tahfizh', pengantar: 'Mengetahui,' }
const DIREKTUR_DEMO = { nama: 'Siswandi Safari, S.Pd.I., Lc., S.H., M.Ag.', niy: '1983020910201401', jabatan: 'Direktur' }
let urutDemo = 0
function dokDemoBaru(jenis, s, x = {}, mode = 'elektronik') {
  const sesi = useSesi(); urutDemo++
  const ttd = (jenis === 'sertifikat_tahfizh' ? [DIREKTUR_DEMO] : [KEPALA_DEMO, { nama: x.penguji || sesi.pengguna?.nama_lengkap, niy: '2019070101', jabatan: 'Penguji' }])
    .map((t, i) => ({ urutan: i + 1, ...t, status: mode === 'basah' || (i === 1) ? 'ditandatangani' : 'menunggu', waktu: mode === 'basah' ? null : i === 1 ? new Date().toISOString() : null, basah: mode === 'basah' }))
  const pref = { suket_juz: 'SKJ', sertifikat_hafalan: 'SH', sertifikat_tahfizh: 'K' }[jenis]
  return { id: 'dt' + Date.now() + urutDemo, jenis, student_id: s.student_id, exam_id: x.exam_id || null, nomor: `${pref}.${String(urutDemo).padStart(3, '0')}/PPTQ-IAS/V/1448`, tanggal: x.tanggal || hariIniISO(),
    tanggal_hijriah: '4 Jumadil Awal 1448', mode_ttd: mode, status: 'terbit', kode: kodeDemoDok(), status_dokumen: ttd.every((t) => t.status === 'ditandatangani') ? 'sah' : 'draf',
    diterbitkan_oleh: sesi.pengguna?.nama_lengkap, created_at: new Date().toISOString(), ttd, boleh_cabut: true,
    data: { nama: s.nama, nis: s.nis, nisn: '0057135022', jenis_kelamin: s.jenis_kelamin, tempat_lahir: 'Makassar', tanggal_lahir: '2009-12-06', jenjang: s.jenjang, tingkat: s.tingkat,
      kelas: s.kelas, halaqah: s.halaqah, total_juz: x.total_juz ?? s.total_resmi, penanda: ttd, ...x } }
}
function dokDemo(tz) {
  if (DOK_DEMO) return DOK_DEMO
  const s12 = tz.santri.find((s) => s.tingkat === 12) || tz.santri[0]; const s8 = tz.santri.find((s) => s.tingkat === 8) || tz.santri[1] || s12
  DOK_DEMO = s12 ? [
    { ...dokDemoBaru('sertifikat_tahfizh', s12, { total_juz: 15, tanggal_hafal: '2026-06-09', tanggal_hafal_hijriah: '23 Zulhijah 1447', predikat: 'ISTIMEWA (MUMTAZ)', pengaturan: PENGATURAN_SERTIFIKAT }, 'basah') },
    { ...dokDemoBaru('suket_juz', s8, { juz: [6], tanggal_ujian: hariIniISO(), nilai_tajwid: 92, nilai_itqan: 88, nilai_akhir: 90, huruf: 'B', predikat: 'Jayyid Jiddan (Sangat Baik)', kkm: 80, ujian_ke: 1, penguji: 'Ust. Muhammad Ikhsan, S.Pd.I.', total_juz: 6 }) },
    { ...dokDemoBaru('sertifikat_hafalan', s12, { juz: [], jenjang_juz: 10, tanggal_ujian: hariIniISO(), nilai_tajwid: 96, nilai_itqan: 95, nilai_akhir: 95.5, huruf: 'A', predikat: 'Mumtaz (Istimewa)', predikat_sertifikat: 'Pujian', kkm: 80, penguji: 'Ust. Muhammad Ikhsan, S.Pd.I.' }, 'basah') },
  ] : []
  return DOK_DEMO
}
const hariIniBulan = () => { const d = new Date(); return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-01` }

const rpc = async (nama, arg) => { const { data, error } = await supabase.rpc(nama, arg); if (error) throw new Error(pesanGalat(error)); return data }
const HAK_KOSONG = { atur: false, validasi: false, pimpinan: false, muhaffizh: false, penguji_kenaikan: false, penguji_sertifikasi: false, dokumen: false, lihat: false }

export const useTahfizh = defineStore('tahfizh', {
  state: () => ({
    hak: { ...HAK_KOSONG }, hakDimuat: false,
    taId: '', pengaturan: null, predikat: [], target: [], bulan: [], penguji: { kenaikan: [], sertifikasi: [] },
    santri: [], memuat: false, galat: '', sesiSetoran: [], memuatSetoran: false, saluran: null, saluranUjian: null, beranda: null, saluranBeranda: null,
  }),
  getters: {
    targetUntuk: (s) => (program, tingkat) => s.target.find((t) => t.program === program && t.tingkat === Number(tingkat)) || null,
    pekanSemester: (s) => (smt) => s.bulan.filter((b) => b.semester === smt).reduce((n, b) => n + Number(b.pekan_efektif || 0), 0),
  },
  actions: {
    async muatHak() {
      const sesi = useSesi()
      if (MODE_DEMO) {
        const p = sesi.peran
        this.hak = p === 'superadmin' ? { ...HAK_KOSONG, atur: true, validasi: true, dokumen: true, lihat: true }
          : p === 'admin' ? { ...HAK_KOSONG, atur: sesi.izinAdmin.includes('atur_tahfizh'), validasi: sesi.izinAdmin.includes('validasi_tahfizh'), dokumen: sesi.izinAdmin.some((x) => ['atur_tahfizh', 'validasi_tahfizh', 'kelola_persuratan'].includes(x)), lihat: true }
            : { ...HAK_KOSONG, muhaffizh: true, penguji_kenaikan: true, lihat: true }
        this.hakDimuat = true; return this.hak
      }
      this.hak = { ...HAK_KOSONG, ...((await rpc('hak_tahfizh')) || {}) }
      this.hakDimuat = true
      return this.hak
    },

    // ---------- Pengaturan ----------
    async muatPengaturan(taId) {
      const kel = useKelompokSantri(); if (!kel.tahunAjaran.length) await kel.muat()
      this.taId = taId || kel.taSekarang?.id || ''
      if (MODE_DEMO) {
        const d = dataTahfizhDemo()
        Object.assign(this, { pengaturan: { ...d.pengaturan }, predikat: d.predikat.map((x) => ({ ...x })), target: d.target.map((x) => ({ ...x })), bulan: d.bulan.map((x) => ({ ...x })) })
        const nama = (id) => PEGAWAI_DEMO.find((p) => p.id === id)
        const susun = (jenis) => d.penguji.filter((x) => x.jenis === jenis).map((x) => {
          const p = nama(x.employee_id); return { ...x, nama: p?.nama_lengkap, niy: p?.niy, no_hp: p?.no_hp, jabatan: x.catatan || 'Penguji', bawaan: false }
        })
        this.penguji = { kenaikan: susun('kenaikan'), sertifikasi: susun('sertifikasi') }
        return
      }
      if (!this.taId) return
      const [s, p, t, b, k1, k2] = await Promise.all([
        supabase.from('tahfizh_settings').select('*').eq('academic_year_id', this.taId).maybeSingle(),
        supabase.from('predicate_ranges').select('*').eq('academic_year_id', this.taId).order('urutan'),
        supabase.from('tahfizh_targets').select('*').eq('academic_year_id', this.taId).order('program').order('tingkat'),
        supabase.from('tahfizh_months').select('*').eq('academic_year_id', this.taId).order('bulan'),
        supabase.rpc('penguji_tahfizh', { p_jenis: 'kenaikan' }),
        supabase.rpc('penguji_tahfizh', { p_jenis: 'sertifikasi' }),
      ])
      for (const r of [s, p, t, b, k1, k2]) if (r.error) throw new Error(pesanGalat(r.error))
      this.pengaturan = s.data
      this.predikat = p.data.map((x) => ({ ...x, nilai_min: Number(x.nilai_min), nilai_maks: Number(x.nilai_maks) }))
      this.target = t.data; this.bulan = b.data
      this.penguji = { kenaikan: k1.data || [], sertifikasi: k2.data || [] }
    },
    async simpanPengaturan(isi) {
      if (MODE_DEMO) {
        const d = dataTahfizhDemo()
        if (isi.umum) Object.assign(d.pengaturan, isi.umum)
        if (isi.predikat) d.predikat = isi.predikat.map((x, i) => ({ ...x, id: 'pr' + i, urutan: i + 1 }))
        if (isi.target) isi.target.forEach((x) => Object.assign(d.target.find((t) => t.program === x.program && t.tingkat === x.tingkat), x))
        if (isi.bulan) isi.bulan.forEach((x) => { const b = d.bulan.find((y) => y.bulan === x.bulan); Object.assign(b, x); if (!x.manual) b.pekan_efektif = Math.min(5, Math.floor(b.hari_aktif / 6)) })
        return this.muatPengaturan(this.taId)
      }
      await rpc('simpan_pengaturan_tahfizh', { p_ta: this.taId, p: isi })
      await this.muatPengaturan(this.taId)
    },
    async simpanPenguji(jenis, employeeId, aktif = true, catatan = '') {
      if (MODE_DEMO) {
        const d = dataTahfizhDemo(); const ada = d.penguji.find((x) => x.jenis === jenis && x.employee_id === employeeId)
        if (ada) Object.assign(ada, { aktif, catatan }); else d.penguji.push({ id: 'x' + Date.now(), jenis, employee_id: employeeId, aktif, catatan })
        return this.muatPengaturan(this.taId)
      }
      await rpc('simpan_penguji', { p_jenis: jenis, p_employee: employeeId, p_aktif: aktif, p_catatan: catatan || null })
      await this.muatPengaturan(this.taId)
    },
    async hapusPenguji(id) {
      if (MODE_DEMO) { const d = dataTahfizhDemo(); d.penguji = d.penguji.filter((x) => x.id !== id); return this.muatPengaturan(this.taId) }
      await rpc('hapus_penguji', { p_id: id }); await this.muatPengaturan(this.taId)
    },

    // ---------- Santri ----------
    async muatSantri() {
      this.memuat = true; this.galat = ''
      try {
        if (MODE_DEMO) {
          const san = useSantri(); const kel = useKelompokSantri(); await san.muat(); await kel.muat()
          const aktif = san.daftar.filter((s) => ['aktif', 'nonaktif'].includes(s.status))
          const d = isiSantriDemo(aktif)
          const terlihat = useSesi().peran === 'pegawai' ? aktif.filter((s) => (s.kelompok || []).some((k) => k.id === 'g-hhb')) : aktif
          this.santri = terlihat.map((s) => {
            const t = d.santri[s.id] || {}; const j = d.juz[s.id] || []
            const hq = (s.kelompok || []).find((k) => k.jenis === 'halaqah'); const kl = (s.kelompok || []).find((k) => k.jenis === 'kelas')
            return { student_id: s.id, nis: s.nis, nama: s.nama_lengkap, jenis_kelamin: s.jenis_kelamin, jenjang: s.jenjang, tingkat: s.tingkat, status: s.status,
              kelas: kl?.nama || null, halaqah_id: hq?.id || null, halaqah: hq?.nama || null, program: t.program || 'reguler',
              sabaq_hal: t.sabaq_hal || 0, sabqi_hal: t.sabqi_hal || 0, manzil_hal: t.manzil_hal || 0, juz_sedang: t.juz_sedang || null,
              posisi_pada: t.posisi_pada || null, posisi_sumber: t.posisi_sumber || null,
              juz_resmi: j.map((x) => x.juz).sort((a, b) => a - b), juz_awal: j.filter((x) => x.sumber === 'awal').map((x) => x.juz).sort((a, b) => a - b), total_resmi: j.length }
          })
          return
        }
        this.santri = (await rpc('daftar_tahfizh', { p_group: null })) || []
      } catch (e) { this.galat = e.message || 'Data tahfizh gagal dimuat.' } finally { this.memuat = false }
    },
    cariSantri(id) { return this.santri.find((s) => s.student_id === id) },
    async aturProgram(ids, program) {
      if (MODE_DEMO) { const d = dataTahfizhDemo(); ids.forEach((id) => { d.santri[id] = { ...(d.santri[id] || {}), program } }); await this.muatSantri(); return ids.length }
      const n = await rpc('atur_program_tahfizh', { p_santri: ids, p_program: program }); await this.muatSantri(); return n
    },
    async simpanHafalanAwal(id, isi) {
      if (MODE_DEMO) {
        const d = dataTahfizhDemo(); const lama = d.juz[id] || []
        d.santri[id] = { ...(d.santri[id] || {}), ...isi, posisi_pada: new Date().toISOString(), posisi_sumber: 'awal' }; delete d.santri[id].juz
        if (isi.juz) { const tetap = lama.filter((x) => x.sumber !== 'awal'); d.juz[id] = [...tetap, ...isi.juz.filter((j) => !tetap.some((x) => x.juz === j)).map((j) => ({ juz: j, sumber: 'awal' }))] }
        await this.muatSantri(); return
      }
      await rpc('simpan_hafalan_awal', { p_santri: id, p: isi }); await this.muatSantri()
    },
    // ---------- Setoran per sesi halaqah ----------
    async muatStatusSetoran(tanggal, semua = false) {
      this.memuatSetoran = true; this.galat = ''
      try {
        if (MODE_DEMO) {
          const abs = useAbsensiSantri(); await abs.muatSesi(tanggal, semua)
          const peta = setoranDemo()
          this.sesiSetoran = abs.sesiHari.filter((x) => x.jenis === 'halaqah').map((x) => {
            const m = peta[`${x.group_id}|${x.tanggal}|${x.sesi}`]
            const logs = m ? Object.values(m.logs) : []
            return { ...x, absensi: x.status === 'terisi' ? 'terisi' : x.status, status: m ? 'terisi' : x.status === 'terisi' ? 'terbuka' : x.status,
              jumlah_bertambah: m ? logs.filter((l) => l.sabaq_hal != null && l.sabaq_hal > l.sabaq_lama).length : null,
              total_tambah_hal: m ? logs.reduce((n, l) => n + Math.max(0, (l.sabaq_hal ?? l.sabaq_lama) - l.sabaq_lama), 0) : null,
              jumlah_janggal: m ? logs.filter((l) => l.janggal?.length).length : null, jumlah_tidak_setor: m ? m.tidak_setor : null, diisi_pada: m?.diisi_pada || null }
          })
          return
        }
        this.sesiSetoran = (await rpc('status_setoran', { p_tanggal: tanggal, p_semua: semua })) || []
      } catch (e) { this.galat = e.message; this.sesiSetoran = [] } finally { this.memuatSetoran = false }
    },
    dengarkanSetoran(fn) {
      if (MODE_DEMO || this.saluran) return
      this.saluran = supabase.channel('setoran-tahfizh')
        .on('postgres_changes', { event: '*', schema: 'public', table: 'memorization_sessions' }, () => fn()).subscribe()
    },
    berhentiSetoran() { if (this.saluran) { supabase.removeChannel(this.saluran); this.saluran = null } },
    async detailSetoran(group, tanggal, sesi, absensi = null) {
      if (MODE_DEMO) {
        const abs = useAbsensiSantri(); const a = absensi || await abs.detail(group, tanggal, sesi)
        await this.muatSantri()
        const m = setoranDemo()[`${group}|${tanggal}|${sesi}`]
        const kode = Object.fromEntries((a.pengecualian || []).map((x) => [x.student_id, x.kode]))
        return { session_id: m ? 'ms-demo' : null, absensi_tersimpan: !!a.sesi_tercatat, catatan: m?.catatan || '', diisi_pada: m?.diisi_pada || null,
          diinput_oleh: m ? useSesi().pengguna?.nama_lengkap : null, diisi_terlambat: false, atas_nama: false, batas_lonjakan_hal: dataTahfizhDemo().pengaturan.batas_lonjakan_hal,
          boleh_isi: !!a.sesi_tercatat && (a.pengasuh_saya || a.boleh_atas_nama),
          santri: a.anggota.map((x) => {
            const t = this.cariSantri(x.id) || {}; const l = m?.logs[x.id]
            return { id: x.id, nis: x.nis, nama: x.nama, jenis_kelamin: x.jenis_kelamin, program: t.program || 'reguler', kehadiran: kode[x.id] || 'H',
              sabaq_lama: l ? l.sabaq_lama : t.sabaq_hal || 0, sabqi_lama: l ? l.sabqi_lama : t.sabqi_hal || 0, manzil_lama: l ? l.manzil_lama : t.manzil_hal || 0,
              juz_sedang: l?.juz_sedang ?? t.juz_sedang ?? null, sabaq_hal: l?.sabaq_hal ?? null, sabqi_hal: l?.sabqi_hal ?? null, manzil_hal: l?.manzil_hal ?? null,
              tambah_hal: l ? Math.max(0, (l.sabaq_hal ?? l.sabaq_lama) - l.sabaq_lama) : 0, janggal: l?.janggal || [], catatan: l?.catatan || null, total_resmi: t.total_resmi || 0 }
          }) }
      }
      return rpc('detail_setoran', { p_group: group, p_tanggal: tanggal, p_sesi: sesi })
    },
    async simpanSetoran(isi, detail) {
      if (MODE_DEMO) {
        const peta = setoranDemo(); const logs = {}
        for (const b of isi.baris) {
          const s = detail.santri.find((x) => x.id === b.student_id)
          logs[b.student_id] = { ...b, sabaq_lama: s.sabaq_lama, sabqi_lama: s.sabqi_lama, manzil_lama: s.manzil_lama, janggal: [] }
          const d = dataTahfizhDemo(); d.santri[b.student_id] = { ...(d.santri[b.student_id] || {}), sabaq_hal: b.sabaq_hal ?? s.sabaq_lama, sabqi_hal: b.sabqi_hal ?? s.sabqi_lama,
            manzil_hal: b.manzil_hal ?? s.manzil_lama, juz_sedang: b.juz_sedang ?? s.juz_sedang, posisi_pada: new Date().toISOString(), posisi_sumber: 'setoran' }
        }
        peta[`${isi.group_id}|${isi.tanggal}|${isi.sesi}`] = { logs, catatan: isi.catatan, diisi_pada: new Date().toISOString(), tidak_setor: detail.santri.filter((x) => ['I', 'S', 'B', 'A'].includes(x.kehadiran)).length }
        return { id: 'ms-demo', janggal: [] }
      }
      const h = await rpc('simpan_setoran', { p: isi }); this.santri = []; return h
    },
    async riwayatSetoran(santri, mulai, selesai) {
      if (MODE_DEMO) {
        const hasil = []
        for (const [k, m] of Object.entries(setoranDemo())) {
          const [, tanggal, sesi] = k.split('|'); const l = m.logs[santri]
          hasil.push({ tanggal, sesi, nama_sesi: { SUBUH: 'Halaqah subuh', SORE: 'Halaqah sore', MALAM: 'Halaqah malam' }[sesi] || sesi, halaqah: '', kehadiran: 'H',
            sabaq_lama: l?.sabaq_lama ?? null, sabaq_hal: l?.sabaq_hal ?? null, sabqi_lama: l?.sabqi_lama ?? null, sabqi_hal: l?.sabqi_hal ?? null,
            manzil_lama: l?.manzil_lama ?? null, manzil_hal: l?.manzil_hal ?? null, tambah_hal: l ? Math.max(0, (l.sabaq_hal ?? l.sabaq_lama) - l.sabaq_lama) : 0,
            juz_sedang: l?.juz_sedang ?? null, janggal: [], catatan: l?.catatan ?? null, pengampu: 'Ust. Hasan Basri' })
        }
        return hasil.sort((a, b) => b.tanggal.localeCompare(a.tanggal))
      }
      return (await rpc('riwayat_setoran', { p_santri: santri, p_mulai: mulai, p_selesai: selesai })) || []
    },

    // ---------- Capaian bulanan dan usulan juz ----------
    async capaianBulanan(bulan, group = null) {
      if (MODE_DEMO) {
        await this.muatSantri(); if (!this.target.length) await this.muatPengaturan()
        const c = capaianDemo(); const b = this.bulan.find((x) => x.bulan === bulan); const pekan = b ? b.pekan_efektif : 4
        return this.santri.filter((s) => !group || s.halaqah_id === group).map((s, i) => {
          const m = c.bulan[`${s.student_id}|${bulan}`] || {}; const tambah = (i * 7) % 31; const t = this.targetUntuk(s.program, s.tingkat)
          const target = (t?.pekan_hal || 5) * pekan; const sesi = i % 9 === 4 ? 0 : 20 + (i % 6)
          const ot = s.total_resmi >= 30 ? 'khatam' : m.murojaah ? 'murojaah' : !sesi ? 'tidak_terdata' : tambah >= target ? 'tercapai' : 'tidak_tercapai'
          return { student_id: s.student_id, nis: s.nis, nama: s.nama, jenis_kelamin: s.jenis_kelamin, tingkat: s.tingkat, kelas: s.kelas, halaqah_id: s.halaqah_id, halaqah: s.halaqah,
            program: s.program, posisi_awal_hal: Math.max(0, s.sabaq_hal - tambah), posisi_akhir_hal: s.sabaq_hal, tambah_hal: tambah, target_hal: target, pekan_efektif: pekan,
            sesi_terdata: sesi, total_resmi: s.total_resmi, status_otomatis: ot, status: m.status || ot, murojaah: !!m.murojaah, alasan_murojaah: m.alasan || null,
            disahkan: !!m.status, disahkan_pada: m.pada || null, disahkan_oleh: m.status ? useSesi().pengguna?.nama_lengkap : null, muhaffizh_saya: useSesi().peran === 'pegawai' }
        })
      }
      return (await rpc('capaian_bulanan', { p_bulan: bulan, p_group: group })) || []
    },
    async tandaiMurojaah(ids, bulan, aktif, alasan) {
      if (MODE_DEMO) { const c = capaianDemo(); ids.forEach((id) => { c.bulan[`${id}|${bulan}`] = { ...(c.bulan[`${id}|${bulan}`] || {}), murojaah: aktif, alasan } }); return ids.length }
      return rpc('tandai_murojaah', { p_santri: ids, p_bulan: bulan, p_aktif: aktif, p_alasan: alasan || null })
    },
    async sahkanCapaian(bulan, group, baris) {
      if (MODE_DEMO) { const c = capaianDemo(); baris.filter((r) => !r.disahkan).forEach((r) => { c.bulan[`${r.student_id}|${bulan}`] = { ...(c.bulan[`${r.student_id}|${bulan}`] || {}), status: r.status_otomatis, pada: new Date().toISOString() } }); return baris.length }
      return rpc('sahkan_capaian_bulan', { p_bulan: bulan, p_group: group || null })
    },
    async batalSahkanCapaian(bulan, group, baris) {
      if (MODE_DEMO) { const c = capaianDemo(); baris.forEach((r) => { const m = c.bulan[`${r.student_id}|${bulan}`]; if (m) { delete m.status; delete m.pada } }); return baris.length }
      return rpc('batal_sahkan_capaian', { p_bulan: bulan, p_group: group || null })
    },
    async daftarUsulan(status = null) {
      if (MODE_DEMO) return capaianDemo().usulan.filter((u) => !status || u.status === status)
      return (await rpc('daftar_usulan_juz', { p_status: status })) || []
    },
    async usulkanJuz(id, juz, catatan) {
      if (MODE_DEMO) {
        const s = this.cariSantri(id); const c = capaianDemo()
        juz.forEach((j) => c.usulan.unshift({ id: 'u' + Date.now() + j, student_id: id, nis: s.nis, nama: s.nama, halaqah: s.halaqah, juz: j, sumber: 'ceklist', status: 'menunggu',
          catatan, catatan_validator: null, diusulkan_oleh: useSesi().pengguna?.nama_lengkap, diusulkan_pada: new Date().toISOString(), diputuskan_oleh: null, diputuskan_pada: null, total_resmi: s.total_resmi }))
        return juz.length
      }
      return rpc('usulkan_juz', { p_santri: id, p_juz: juz, p_catatan: catatan || null })
    },
    async putuskanUsulan(ids, setuju, catatan) {
      if (MODE_DEMO) {
        const c = capaianDemo(); const d = dataTahfizhDemo()
        c.usulan.filter((u) => ids.includes(u.id)).forEach((u) => {
          Object.assign(u, { status: setuju ? 'disetujui' : 'dikembalikan', catatan_validator: catatan || null, diputuskan_oleh: useSesi().pengguna?.nama_lengkap, diputuskan_pada: new Date().toISOString() })
          if (setuju) d.juz[u.student_id] = [...(d.juz[u.student_id] || []), { juz: u.juz, sumber: 'validasi' }]
        })
        await this.muatSantri(); return ids.length
      }
      const n = await rpc('putuskan_usulan_juz', { p_ids: ids, p_setuju: setuju, p_catatan: catatan || null }); await this.muatSantri(); return n
    },

    // ---------- Ujian kenaikan juz dan sertifikasi ----------
    async daftarUjian(jenis = null, status = null) {
      if (MODE_DEMO) return ujianDemo().filter((u) => (!jenis || u.jenis === jenis) && (!status || u.status === status || (status === 'aktif' && ['menunggu', 'dijadwalkan'].includes(u.status))))
      return (await rpc('daftar_ujian', { p_jenis: jenis, p_status: status })) || []
    },
    dengarkanUjian(fn) {
      if (MODE_DEMO || this.saluranUjian) return
      this.saluranUjian = supabase.channel('ujian-tahfizh').on('postgres_changes', { event: '*', schema: 'public', table: 'tahfizh_exams' }, () => fn()).subscribe()
    },
    berhentiUjian() { if (this.saluranUjian) { supabase.removeChannel(this.saluranUjian); this.saluranUjian = null } },
    async rekomendasikanUjian(id, jenis, juz, jenjang, catatan) {
      if (MODE_DEMO) {
        const s = this.cariSantri(id); const nama = useSesi().pengguna?.nama_lengkap
        if (ujianDemo().some((u) => u.student_id === id && u.jenis === jenis && ['menunggu', 'dijadwalkan'].includes(u.status))) throw new Error(`${s.nama} masih memiliki ujian yang belum selesai.`)
        ujianDemo().unshift({ id: 'uj' + Date.now(), jenis, student_id: id, nis: s.nis, nama: s.nama, jenis_kelamin: s.jenis_kelamin, kelas: s.kelas, halaqah: s.halaqah, juz, jenjang,
          status: 'menunggu', ujian_ke: 1, direkomendasikan_oleh: nama, direkomendasikan_pada: new Date().toISOString(), catatan_rekomendasi: catatan, penguji_id: null, penguji: null,
          jadwal: null, total_resmi: s.total_resmi, penguji_saya: false, boleh_nilai: useSesi().peran !== 'pegawai', muhaffizh_saya: useSesi().peran === 'pegawai',
          muhaffizh: 'Ust. Hasanuddin, S.Q.', hp_muhaffizh: '081234500001', hp_perekomendasi: '081234500001', hp_penguji: null, keterangan: null, catatan_perbaikan: null })
        return
      }
      return rpc('rekomendasikan_ujian', { p_santri: id, p_jenis: jenis, p_juz: juz, p_jenjang: jenjang, p_catatan: catatan || null })
    },
    async ambilUjian(id, jadwal) {
      if (MODE_DEMO) { const u = ujianDemo().find((x) => x.id === id); Object.assign(u, { status: 'dijadwalkan', penguji: useSesi().pengguna?.nama_lengkap, penguji_saya: true, jadwal: jadwal || null }); return }
      return rpc('ambil_ujian', { p_id: id, p_jadwal: jadwal || null })
    },
    async tetapkanPenguji(id, employeeId, jadwal) {
      if (MODE_DEMO) { const u = ujianDemo().find((x) => x.id === id); const p = [...this.penguji.kenaikan, ...this.penguji.sertifikasi].find((x) => x.employee_id === employeeId); Object.assign(u, { status: 'dijadwalkan', penguji: p?.nama, penguji_id: employeeId, jadwal: jadwal || null }); return }
      return rpc('tetapkan_penguji_ujian', { p_id: id, p_employee: employeeId, p_jadwal: jadwal || null })
    },
    async nilaiUjian(id, tajwid, itqan, catatan, keterangan = null, perbaikan = '') {
      if (MODE_DEMO) {
        if (!this.pengaturan) await this.muatPengaturan()
        const u = ujianDemo().find((x) => x.id === id); const h = hitungNilai(tajwid, itqan, this.pengaturan, this.predikat)
        if (h.hasil === 'remidi' && !String(perbaikan || '').trim()) throw new Error('Tuliskan catatan perbaikan untuk santri yang belum lulus.')
        const ket = h.hasil === 'tuntas' ? 'lulus' : keterangan === 'tidak_lulus' ? 'tidak_lulus' : 'perbaikan'
        Object.assign(u, { status: 'selesai', nilai_tajwid: tajwid, nilai_itqan: itqan, nilai_akhir: h.akhir, huruf: h.huruf, predikat: h.predikat, hasil: h.hasil, kkm: this.pengaturan.kkm, keterangan: ket, catatan_perbaikan: String(perbaikan || '').trim() || null,
          catatan_penguji: catatan, diuji_pada: new Date().toISOString(), penguji: u.penguji || useSesi().pengguna?.nama_lengkap, boleh_nilai: false })
        if (u.jenis === 'kenaikan' && h.hasil === 'tuntas') u.juz.forEach((j) => capaianDemo().usulan.unshift({ id: 'u' + Date.now() + j, student_id: u.student_id, nis: u.nis, nama: u.nama, halaqah: u.halaqah, juz: j, sumber: 'ujian', status: 'menunggu', catatan: `Ujian kenaikan juz: nilai ${h.akhir} (${h.huruf})`, diusulkan_oleh: u.penguji, diusulkan_pada: new Date().toISOString(), total_resmi: u.total_resmi }))
        return { nilai_akhir: h.akhir, huruf: h.huruf, predikat: h.predikat, hasil: h.hasil, keterangan: ket }
      }
      return rpc('nilai_ujian', { p_id: id, p_tajwid: tajwid, p_itqan: itqan, p_catatan: catatan || null, p_keterangan: keterangan || null, p_perbaikan: String(perbaikan || '').trim() || null })
    },
    async batalkanUjian(id, alasan) {
      if (MODE_DEMO) { Object.assign(ujianDemo().find((x) => x.id === id), { status: 'dibatalkan', alasan_batal: alasan, boleh_nilai: false }); return }
      return rpc('batalkan_ujian', { p_id: id, p_alasan: alasan })
    },

    // ---------- Dokumen tahfizh (Tahap D) ----------
    async daftarDokumen({ mulai = null, selesai = null, id = null } = {}) {
      if (MODE_DEMO) { if (!this.santri.length) await this.muatSantri(); return dokDemo(this).filter((d) => (!id || d.id === id) && (id || ((!mulai || d.tanggal >= mulai) && (!selesai || d.tanggal <= selesai)))).map((d) => JSON.parse(JSON.stringify(d))) }
      return (await rpc('daftar_dokumen_tahfizh', { p_mulai: mulai, p_selesai: selesai, p_id: id })) || []
    },
    /** p: { jenis, exam_id?, student_id?, tanggal?, mode, predikat?, tanggal_hafal? } → { id, nomor, kode, status } */
    async terbitkanDokumen(p) {
      if (MODE_DEMO) {
        if (!this.santri.length) await this.muatSantri()
        const d = dokDemo(this)
        if (p.jenis === 'sertifikat_tahfizh') {
          const s = this.cariSantri(p.student_id); if (d.some((x) => x.student_id === p.student_id && x.jenis === p.jenis && x.status === 'terbit')) throw new Error('Sertifikat Tahfizhul Quran santri ini sudah terbit.')
          if (!String(p.predikat || '').trim()) throw new Error('Isi predikat sertifikat, misalnya Istimewa (Mumtaz).')
          const x = dokDemoBaru(p.jenis, s, { total_juz: s.total_resmi, tanggal_hafal: p.tanggal_hafal, tanggal_hafal_hijriah: '–', predikat: p.predikat.toUpperCase(), pengaturan: await this.pengaturanSertifikat(), tanggal: p.tanggal }, p.mode)
          d.unshift(x); return { id: x.id, nomor: x.nomor, kode: x.kode, status: x.status_dokumen }
        }
        const u = ujianDemo().find((x) => x.id === p.exam_id); const s = this.cariSantri(u.student_id) || { student_id: u.student_id, nama: u.nama, nis: u.nis, kelas: u.kelas, halaqah: u.halaqah }
        if (d.some((x) => x.exam_id === u.id && x.jenis === p.jenis && x.status === 'terbit')) throw new Error('Dokumen untuk ujian ini sudah terbit. Cetak ulang dari daftar dokumen.')
        const x = dokDemoBaru(p.jenis, s, { exam_id: u.id, juz: u.juz, jenjang_juz: u.jenjang, tanggal_ujian: (u.diuji_pada || '').slice(0, 10), nilai_tajwid: u.nilai_tajwid, nilai_itqan: u.nilai_itqan,
          nilai_akhir: u.nilai_akhir, huruf: u.huruf, predikat: u.predikat, kkm: u.kkm, penguji: u.penguji, tanggal: p.tanggal }, p.mode)
        d.unshift(x); return { id: x.id, nomor: x.nomor, kode: x.kode, status: x.status_dokumen }
      }
      return await rpc('terbitkan_dokumen_tahfizh', { p })
    },
    async cabutDokumen(id, alasan) {
      if (MODE_DEMO) { const d = dokDemo(this).find((x) => x.id === id); if ((alasan || '').trim().length < 5) throw new Error('Tuliskan alasan pencabutan (minimal 5 huruf).'); Object.assign(d, { status: 'dicabut', status_dokumen: 'dicabut', alasan_cabut: alasan, boleh_cabut: false }); return }
      await rpc('cabut_dokumen_tahfizh', { p_id: id, p_alasan: alasan })
    },
    /** Santri kelas 9 dan 12 (aktif/lulus) beserta jumlah juz resmi dan status Sertifikat Tahfizhul Quran. */
    async calonSertifikat() {
      if (MODE_DEMO) {
        if (!this.santri.length) await this.muatSantri(); const d = dokDemo(this)
        return this.santri.filter((s) => [9, 12].includes(s.tingkat)).map((s) => ({ student_id: s.student_id, nama: s.nama, nis: s.nis, jenis_kelamin: s.jenis_kelamin, jenjang: s.jenjang, tingkat: s.tingkat,
          status: s.status, kelas: s.kelas, total_juz: s.total_resmi, tanggal_hafal: null, predikat: s.total_resmi >= 10 ? 'Mumtaz (Istimewa)' : null,
          dokumen_id: d.find((x) => x.student_id === s.student_id && x.jenis === 'sertifikat_tahfizh' && x.status === 'terbit')?.id || null }))
      }
      return (await rpc('calon_sertifikat_tahfizh')) || []
    },
    async pengaturanSertifikat() {
      if (MODE_DEMO) return { ...PENGATURAN_SERTIFIKAT, ...(SET_DEMO || {}) }
      return { ...PENGATURAN_SERTIFIKAT, ...((await rpc('pengaturan_sertifikat_tahfizh')) || {}) }
    },
    async simpanPengaturanSertifikat(p) {
      if (MODE_DEMO) { SET_DEMO = { ...(SET_DEMO || {}), ...p }; return }
      await rpc('simpan_pengaturan_sertifikat_tahfizh', { p })
    },

    // ---------- Data laporan ----------
    async dataLaporan(bulan) {
      if (MODE_DEMO) {
        const kel = useKelompokSantri(); const san = useSantri(); await kel.muat(); await san.muat()
        const c = await this.capaianBulanan(bulan, null)
        return c.map((r) => {
          const t = this.cariSantri(r.student_id) || {}; const g = kel.cari(r.halaqah_id); const sn = san.cari(r.student_id)
          const step = Math.round(r.tambah_hal / 4)
          return { ...r, jenjang: t.jenjang, muhaffizh: (g?.pengasuh || []).find((p) => p.peran === 'utama')?.nama || null, naqib: g?.naqib_id === r.student_id,
            kamar: (sn?.kelompok || []).find((k) => k.jenis === 'kamar')?.nama || null, juz_resmi: t.juz_resmi || [],
            pekan: [1, 2, 3, 4, 5].map((k) => (k === 5 ? null : Math.min(r.posisi_akhir_hal, r.posisi_awal_hal + step * k))) }
        })
      }
      return (await rpc('data_laporan_tahfizh', { p_bulan: bulan })) || []
    },
    async kepatuhanSetoran(bulan) {
      if (MODE_DEMO) {
        const kel = useKelompokSantri(); await kel.muat()
        return kel.daftar.filter((g) => g.jenis === 'halaqah').map((g, i) => ({ halaqah_id: g.id, halaqah: g.nama, muhaffizh: (g.pengasuh || []).find((p) => p.peran === 'utama')?.nama,
          jumlah_santri: g.jumlah_anggota || 0, seharusnya: [18, 18, 18, 18, 9], terisi: i % 2 ? [18, 18, 12, 18, 9] : [18, 18, 18, 18, 9] }))
      }
      return (await rpc('kepatuhan_setoran', { p_bulan: bulan })) || []
    },
    async kehadiranHalaqah(bulan) {
      if (MODE_DEMO) { const kel = useKelompokSantri(); await kel.muat(); return kel.daftar.filter((g) => g.jenis === 'halaqah').map((g, i) => ({ halaqah_id: g.id, persen: 92.5 - i * 3.1 })) }
      return (await rpc('kehadiran_halaqah', { p_bulan: bulan })) || []
    },

    // ---------- Beranda dan profil santri ----------
    async muatBeranda() {
      if (MODE_DEMO) {
        await this.muatSantri(); const s = this.santri
        this.beranda = { santri: s.length, rata_juz: Math.round((s.reduce((t, x) => t + x.total_resmi, 0) / (s.length || 1)) * 10) / 10, khatam: s.filter((x) => x.total_resmi >= 30).length,
          setoran_terisi: 1, setoran_dibuka: 2, setoran_total: 6, ujian_menunggu: ujianDemo().filter((u) => u.status !== 'selesai').length, ujian_untuk_saya: 0,
          usulan_menunggu: capaianDemo().usulan.filter((u) => u.status === 'menunggu').length, tercapai: 5, tidak_tercapai: 13, terdata: 20, cakupan_semua: useSesi().peran !== 'pegawai' }
        return this.beranda
      }
      try { this.beranda = await rpc('ringkasan_tahfizh_beranda') } catch { this.beranda = null }
      return this.beranda
    },
    dengarkanBeranda() {
      if (MODE_DEMO || this.saluranBeranda) return
      let tunda = null; const segar = () => { clearTimeout(tunda); tunda = setTimeout(() => this.muatBeranda(), 1500) }
      this.saluranBeranda = supabase.channel('beranda-tahfizh')
        .on('postgres_changes', { event: '*', schema: 'public', table: 'memorization_sessions' }, segar)
        .on('postgres_changes', { event: '*', schema: 'public', table: 'tahfizh_exams' }, segar).subscribe()
    },
    async hafalanSantri(id) {
      if (MODE_DEMO) {
        await this.muatSantri(); const t = this.cariSantri(id)
        if (!t) return null
        const c = (await this.capaianBulanan(hariIniBulan(), null)).find((r) => r.student_id === id) || null
        return { program: t.program, sabaq_hal: t.sabaq_hal, sabqi_hal: t.sabqi_hal, manzil_hal: t.manzil_hal, juz_sedang: t.juz_sedang, posisi_pada: t.posisi_pada, posisi_sumber: t.posisi_sumber,
          halaqah: t.halaqah, muhaffizh: 'Ust. Hasan Basri, Lc.', juz: t.juz_resmi.map((j) => ({ juz: j, sumber: t.juz_awal.includes(j) ? 'awal' : 'validasi' })),
          usulan: capaianDemo().usulan.filter((u) => u.student_id === id && u.status === 'menunggu').map((u) => u.juz), jenjang_sertifikasi: t.total_resmi >= 30 ? 30 : Math.floor(t.total_resmi / 5) * 5,
          ujian: ujianDemo().filter((u) => u.student_id === id), bulan_ini: c }
      }
      return rpc('hafalan_santri', { p_santri: id })
    },

    async imporHafalanAwal(baris) {
      if (MODE_DEMO) return baris.map((b, i) => ({ baris: i + 1, ok: false, pesan: 'Mode demo: impor tidak disimpan.' }))
      const h = await rpc('impor_hafalan_awal', { p_baris: baris }); await this.muatSantri(); return h
    },
  },
})
