// SIMKA PRO | src/stores/absensiSantri.js | v1.3 | Fase 6 – Tahap 4 Lapor ke bidang dan dasbor ringkasan | 06/10/2026
// Absensi santri HISBAT: sesi hari ini (pengasuh) atau semua kelompok (pantauan), detail sesi, simpan
// (hanya pengecualian), rekap per santri, dan riwayat ketidakhadiran. Penulisan lewat fungsi SQL.
// v1.2: detail() menyertakan "otomatis" — santri yang sedang sakit (Klinik → S) atau izin (Perizinan → I).
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { dataAbsensiDemo, sesiAbsensiDemo, hitung, sesiDemoUntuk } from '@/lib/demoAbsensi'
import { pesanGalat } from './lembaga'
import { useSesi } from './sesi'
import { useSantri } from './santri'
import { useKlinik } from './klinik'
import { useIzin } from './izin'

export const useAbsensiSantri = defineStore('absensiSantri', {
  state: () => ({ sesiHari: [], memuat: false, galat: '', saluran: null }),
  actions: {
    async muatSesi(tanggal, semua = false) {
      this.memuat = true; this.galat = ''
      try {
        if (MODE_DEMO) { await useSantri().muat(); this.sesiHari = sesiAbsensiDemo(tanggal, semua, useSesi().peran === 'pegawai'); return }
        const { data, error } = await supabase.rpc('sesi_absensi', { p_tanggal: tanggal, p_semua: semua })
        if (error) { this.galat = pesanGalat(error); this.sesiHari = []; return }
        this.sesiHari = data || []
      } finally { this.memuat = false }
    },
    /** Pantauan langsung: muat ulang saat ada sesi baru/terkoreksi di perangkat lain. */
    dengarkan(fn) {
      if (MODE_DEMO || this.saluran) return
      this.saluran = supabase.channel('absensi-santri')
        .on('postgres_changes', { event: '*', schema: 'public', table: 'student_attendance_sessions' }, () => fn())
        .subscribe()
    },
    berhenti() { if (this.saluran) { supabase.removeChannel(this.saluran); this.saluran = null } },

    async detail(group, tanggal, sesi) {
      if (MODE_DEMO) {
        const d = dataAbsensiDemo(); const g = d.kelompok.kelompok.find((x) => x.id === group); const san = useSantri(); await san.muat()
        const jenis = g.jenis === 'kamar' ? 'asrama' : g.jenis; const def = sesiDemoUntuk(g, tanggal).find((x) => x.kode === sesi)
        const info = sesiAbsensiDemo(tanggal, true, useSesi().peran === 'pegawai').find((x) => x.group_id === group && x.sesi === sesi)
        const sa = d.sesi[`${group}|${tanggal}|${sesi}`]
        const anggota = d.kelompok.anggota.filter((a) => a.group_id === group && !a.selesai).map((a) => san.cari(a.student_id)).filter(Boolean)
          .map((s) => ({ id: s.id, nis: s.nis, nama: s.nama_lengkap, jenis_kelamin: s.jenis_kelamin, status: s.status })).sort((a, b) => a.nama.localeCompare(b.nama, 'id'))
        const peg = useSesi().peran === 'pegawai'
        return { kelompok: { id: g.id, nama: g.nama, jenis: g.jenis, jenis_kelamin: g.jenis_kelamin, wa_wali: g.wa_wali, naqib_id: g.naqib_id },
          jenis, tanggal, sesi, nama_sesi: def.nama, jam_mulai: def.jam_mulai, jam_selesai: def.jam_selesai, buka: info.buka, tutup: info.tutup, batas: info.batas,
          sekarang: new Date().toISOString(), pengasuh_saya: peg && info.asuhan_saya, perlu_presensi: false, boleh_atas_nama: useSesi().bolehAdmin('absensi_atas_nama'),
          pengasuh: g.pengasuh.map((p) => ({ employee_id: p.employee_id, nama: p.nama, peran: p.peran })), anggota,
          sesi_tercatat: sa ? { id: sa.id, atas_nama: sa.atas_nama, diisi_terlambat: sa.diisi_terlambat, diisi_pada: sa.diisi_pada, pengampu: sa.pengampu, diinput_oleh: sa.diinput_oleh, catatan: sa.catatan } : null,
          pengecualian: sa?.pengecualian || [], log: sa?.log || [], tempat: def.tempat || null, jurnal: sa?.jurnal || null,
          otomatis: await this.otomatisDemo(anggota) }
      }
      const [{ data, error }, oto] = await Promise.all([
        supabase.rpc('detail_absensi', { p_group: group, p_tanggal: tanggal, p_sesi: sesi }),
        supabase.rpc('status_otomatis_sesi', { p_group: group, p_tanggal: tanggal, p_sesi: sesi }),
      ])
      if (error) throw new Error(pesanGalat(error))
      return { ...data, otomatis: oto.error ? [] : oto.data || [] }
    },
    /** Dasbor ekskul: ringkasan setiap ekskul (pertemuan terjadwal/terlaksana, kehadiran, jurnal materi). */
    async ringkasanEkskul(mulai, selesai) {
      if (!MODE_DEMO) { const { data, error } = await supabase.rpc('ringkasan_ekskul', { p_mulai: mulai, p_selesai: selesai }); if (error) throw new Error(pesanGalat(error)); return data || [] }
      await useSantri().muat(); const d = dataAbsensiDemo(); const peg = useSesi().peran === 'pegawai'
      return d.kelompok.kelompok.filter((g) => g.jenis === 'ekskul' && g.aktif && (!peg || g.pengasuh.some((p) => p.employee_id === 'p1'))).map((g) => {
        const ses = Object.values(d.sesi).filter((s) => s.group_id === g.id && s.tanggal >= mulai && s.tanggal <= selesai)
        const t = ses.reduce((a, s) => { const h = hitung(s); return { n: a.n + s.jumlah_anggota, h: a.h + h.jumlah_hadir, i: a.i + h.jumlah_izin, s: a.s + h.jumlah_sakit, a: a.a + h.jumlah_absen } }, { n: 0, h: 0, i: 0, s: 0, a: 0 })
        const akhir = Object.values(d.sesi).filter((s) => s.group_id === g.id).sort((a, b) => b.tanggal.localeCompare(a.tanggal))[0]
        return { id: g.id, nama: g.nama, keterangan: g.keterangan, pembina: g.pengasuh.map((p) => p.nama).join(', '),
          anggota_aktif: d.kelompok.anggota.filter((a) => a.group_id === g.id && !a.selesai).length, pertemuan_rencana: ses.length + (g.id === 'g-epn' ? 1 : 0), pertemuan_terlaksana: ses.length,
          anggota: t.n, hadir: t.h, izin: t.i, sakit: t.s, absen: t.a, persen: t.n ? Math.round((t.h / t.n) * 1000) / 10 : null, jurnal_terisi: ses.filter((s) => s.jurnal).length,
          terakhir: akhir ? { tanggal: akhir.tanggal, topik: akhir.jurnal?.topik || null } : null }
      })
    },
    /** Mode demo: santri sakit (kasus klinik ditangani) dan santri izin (disetujui/keluar) di antara anggota. */
    async otomatisDemo(anggota) {
      const ids = new Set(anggota.map((a) => a.id)); const hasil = []
      try {
        const kd = await useKlinik().demo()
        kd.kasus.filter((k) => k.status === 'ditangani' && ids.has(k.student_id)).forEach((k) => hasil.push({ student_id: k.student_id, kode: 'S', sumber: 'klinik',
          keterangan: 'Klinik: ' + ({ istirahat: 'istirahat di kamar', rawat: 'dirawat di klinik', rujuk: 'dirujuk ke RS/puskesmas', pulang: 'dipulangkan' }[k.tindak_lanjut] || 'sakit') }))
        const iz = await useIzin().daftar('aktif')
        iz.filter((x) => ids.has(x.student_id) && !hasil.some((h) => h.student_id === x.student_id) && new Date(x.keluar_pada) <= new Date())
          .forEach((x) => hasil.push({ student_id: x.student_id, kode: 'I', sumber: 'izin', keterangan: `Izin ${x.jenis} s.d. ${x.kembali_batas.slice(8, 10)}/${x.kembali_batas.slice(5, 7)}: ${x.alasan}` }))
      } catch { /* abaikan di demo */ }
      return hasil
    },

    async simpan(isi) {
      if (MODE_DEMO) {
        const d = dataAbsensiDemo(); const kunci = `${isi.group_id}|${isi.tanggal}|${isi.sesi}`; const lama = d.sesi[kunci]
        const g = d.kelompok.kelompok.find((x) => x.id === isi.group_id); const jenis = g.jenis === 'kamar' ? 'asrama' : g.jenis
        const anggota = d.kelompok.anggota.filter((a) => a.group_id === g.id && !a.selesai).length
        const nama = useSesi().pengguna?.nama_lengkap
        d.sesi[kunci] = { ...(lama || {}), id: lama?.id || 'sa' + Date.now(), group_id: isi.group_id, jenis, tanggal: isi.tanggal, sesi: isi.sesi,
          nama_sesi: sesiDemoUntuk(g, isi.tanggal).find((x) => x.kode === isi.sesi).nama, jumlah_anggota: anggota, pengecualian: isi.pengecualian, catatan: isi.catatan,
          jurnal: isi.jurnal ? { ...isi.jurnal } : lama?.jurnal || null,
          atas_nama: !!isi.atas_nama_id || lama?.atas_nama, diisi_pada: new Date().toISOString(), pengampu: lama?.pengampu || nama, diinput_oleh: nama,
          log: [{ waktu: new Date().toISOString(), aksi: lama ? 'koreksi' : 'isi', oleh: nama, perubahan: [] }, ...(lama?.log || [])] }
        Object.assign(d.sesi[kunci], hitung(d.sesi[kunci]))
        return d.sesi[kunci].id
      }
      const { data, error } = await supabase.rpc('simpan_absensi_santri', { p: isi })
      if (error) throw new Error(pesanGalat(error))
      return data
    },

    /** Baris rekap per santri per jenis. */
    async rekap(mulai, selesai, { group = null, jenis = null, santri = null } = {}) {
      if (MODE_DEMO) {
        await useSantri().muat()
        const d = dataAbsensiDemo(); const peta = {}
        for (const s of Object.values(d.sesi)) {
          if (s.tanggal < mulai || s.tanggal > selesai || (group && s.group_id !== group) || (jenis && s.jenis !== jenis)) continue
          for (const a of d.kelompok.anggota.filter((x) => x.group_id === s.group_id && !x.selesai)) {
            if (santri && a.student_id !== santri) continue
            const r = (peta[`${a.student_id}|${s.jenis}`] ||= { student_id: a.student_id, jenis: s.jenis, sesi: 0, hadir: 0, izin: 0, sakit: 0, bolos: 0, absen: 0, terlambat: 0 })
            const kd = s.pengecualian.find((x) => x.student_id === a.student_id)?.kode
            r.sesi++; if (!['I', 'S', 'A'].includes(kd)) r.hadir++
            if (kd) r[{ I: 'izin', S: 'sakit', B: 'bolos', A: 'absen', T: 'terlambat' }[kd]]++
          }
        }
        return Object.values(peta)
      }
      const { data, error } = await supabase.rpc('rekap_absensi_santri', { p_mulai: mulai, p_selesai: selesai, p_group: group, p_jenis: jenis, p_santri: santri })
      if (error) throw new Error(pesanGalat(error))
      return data || []
    },

    /** Pertemuan ekskul beserta jurnal materi (rekap). */
    async jurnalEkskul(group, mulai, selesai) {
      if (MODE_DEMO) {
        return Object.values(dataAbsensiDemo().sesi).filter((s) => s.group_id === group && s.tanggal >= mulai && s.tanggal <= selesai)
          .map((s) => ({ session_id: s.id, tanggal: s.tanggal, topik: s.jurnal?.topik, uraian: s.jurnal?.uraian, foto_id: null, pengampu: s.pengampu,
            jumlah_anggota: s.jumlah_anggota, ...hitung(s) })).sort((a, b) => a.tanggal.localeCompare(b.tanggal))
      }
      const { data, error } = await supabase.rpc('jurnal_ekskul', { p_group: group, p_mulai: mulai, p_selesai: selesai })
      if (error) throw new Error(pesanGalat(error))
      return data || []
    },

    async riwayat(santri, mulai, selesai) {
      if (MODE_DEMO) {
        await useSantri().muat()
        const d = dataAbsensiDemo()
        return Object.values(d.sesi).filter((s) => s.tanggal >= mulai && s.tanggal <= selesai).flatMap((s) => s.pengecualian.filter((x) => x.student_id === santri)
          .map((x) => ({ tanggal: s.tanggal, jenis: s.jenis, kelompok: d.kelompok.kelompok.find((g) => g.id === s.group_id)?.nama, nama_sesi: s.nama_sesi, kode: x.kode, keterangan: x.keterangan })))
          .sort((a, b) => b.tanggal.localeCompare(a.tanggal))
      }
      const { data, error } = await supabase.rpc('riwayat_absensi_santri', { p_santri: santri, p_mulai: mulai, p_selesai: selesai })
      if (error) throw new Error(pesanGalat(error))
      return data || []
    },
  },
})
