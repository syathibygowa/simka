// SIMKA PRO | src/stores/waliKelas.js | v1.0 | Fase 4 – Menu Wali Kelas | 12/10/2026
// Menu Wali Kelas: kelas yang terlihat (wali kelas: kelasnya; admin/pimpinan: semua kelas menurut cakupannya),
// sesi absensi kelas hari ini, rincian absensi kelas (bentuk sama dengan absensi asrama sehingga pengolahan lib/musyrif
// dapat dipakai), dan ringkasan semua kelas. Data hanya dibaca; pengisian tetap lewat Absensi Santri.
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { pesanGalat } from './lembaga'
import { useSesi } from './sesi'
import { useSantri } from './santri'
import { useJadwal } from './jadwal'
import { dataKelompokDemo } from '@/lib/demoKelompok'
import { SESI_DEMO } from '@/lib/demoAbsensi'
import { hariIniISO } from '@/lib/tanggal'
import { tambahHari } from '@/lib/musyrif'

const rpc = async (nama, arg) => { const { data, error } = await supabase.rpc(nama, arg); if (error) throw new Error(pesanGalat(error)); return data }
const waktu = (tgl, j, menit = 0) => new Date(new Date(`${tgl}T${j}:00+08:00`).getTime() + menit * 60000)
const minggu = (tgl) => new Date(`${tgl}T12:00:00+08:00`).getUTCDay() === 0

export const useWaliKelas = defineStore('waliKelas', {
  state: () => ({ kelas: [], dimuat: false, pilih: '', saluran: null }),
  getters: {
    kelasPilih: (s) => s.kelas.find((k) => k.id === s.pilih) || null,
    asuhan: (s) => s.kelas.filter((k) => k.asuhan_saya),
  },
  actions: {
    async muatKelas(paksa = false) {
      if (this.dimuat && !paksa) return this.kelas
      if (MODE_DEMO) {
        const san = useSantri(); await san.muat(); const d = dataKelompokDemo(san.daftar); const peg = useSesi().peran === 'pegawai'
        const jd = useJadwal(); await jd.muat()
        this.kelas = d.kelompok.filter((g) => g.jenis === 'kelas' && g.aktif).map((g) => {
          const anggota = d.anggota.filter((a) => a.group_id === g.id && !a.selesai).map((a) => san.cari(a.student_id)).filter(Boolean)
          return { id: g.id, nama: g.nama, jenjang: g.jenjang, tingkat: g.tingkat, jenis_kelamin: g.jenis_kelamin, keterangan: g.keterangan, wa_wali: g.wa_wali, wa_internal: g.wa_internal,
            asuhan_saya: peg && g.pengasuh.some((p) => p.employee_id === 'p1'), jumlah: anggota.length,
            putra: anggota.filter((s) => s.jenis_kelamin === 'L').length, putri: anggota.filter((s) => s.jenis_kelamin === 'P').length,
            wali: g.pengasuh.map((p) => ({ employee_id: p.employee_id, nama: p.nama, niy: p.niy, peran: p.peran, no_hp: p.no_hp })),
            mapel: jd.penugasan.filter((t) => t.group_id === g.id).length }
        }).filter((k) => !peg || k.asuhan_saya)
          .sort((a, b) => Number(b.asuhan_saya) - Number(a.asuhan_saya) || a.tingkat - b.tingkat || a.nama.localeCompare(b.nama, 'id'))
      } else this.kelas = (await rpc('kelas_walas')) || []
      if (!this.kelas.some((k) => k.id === this.pilih)) this.pilih = this.kelas[0]?.id || ''
      this.dimuat = true
      return this.kelas
    },

    /** Sesi absensi kelas hari ini untuk satu kelas (terisi/terbuka/lewat/belum dibuka). */
    async sesiHariIni(group) {
      const tgl = hariIniISO(); const kini = new Date()
      let daftar
      if (MODE_DEMO) {
        daftar = minggu(tgl) ? [] : SESI_DEMO.kelas.map((s) => ({ kode: s.kode, nama: s.nama, jam_mulai: s.jam_mulai, jam_selesai: s.jam_selesai,
          buka: waktu(tgl, s.jam_mulai, -s.buka).toISOString(), tutup: waktu(tgl, s.jam_selesai, 60).toISOString(),
          session_id: waktu(tgl, s.jam_selesai) < kini && group !== 'g-8a' ? `sk-${group}-${tgl}` : null }))
      } else daftar = (await rpc('sesi_kelompok', { p_group: group, p_tanggal: tgl })) || []
      return daftar.map((s) => ({ ...s, tanggal: tgl,
        status: s.session_id ? 'terisi' : kini < new Date(s.buka) ? 'belum_buka' : kini <= new Date(s.tutup) ? 'terbuka' : 'lewat' }))
    },

    /** Rincian absensi kelas (sesi, isi [sesi, santri, kode, ket], rencana, santri). */
    async rinci(group, mulai, selesai) {
      if (!MODE_DEMO) return rpc('absensi_kelas_rinci', { p_group: group, p_mulai: mulai, p_selesai: selesai })
      const san = useSantri(); await san.muat(); const d = dataKelompokDemo(san.daftar); const g = d.kelompok.find((x) => x.id === group)
      const anggota = d.anggota.filter((a) => a.group_id === group && !a.selesai).map((a) => san.cari(a.student_id)).filter(Boolean)
        .sort((a, b) => a.nama_lengkap.localeCompare(b.nama_lengkap, 'id'))
      const hari = hariIniISO(); const kini = new Date(); const sesi = []; const isi = []; const rencana = []
      for (let t = mulai; t <= selesai && t <= hari; t = tambahHari(t, 1)) {
        if (minggu(t)) continue
        const i = Math.round((new Date(`${hari}T00:00:00`) - new Date(`${t}T00:00:00`)) / 86400000)
        for (const s of SESI_DEMO.kelas) {
          if (waktu(t, s.jam_selesai) > kini) continue
          rencana.push({ tanggal: t, sesi: s.kode, nama_sesi: s.nama })
          if ((group.length + i) % 8 === 0) continue
          const id = `sk-${group}-${t}`
          sesi.push({ id, tanggal: t, sesi: s.kode, nama_sesi: s.nama, jam_mulai: s.jam_mulai + ':00', pengisi: g.pengasuh[0]?.nama, terlambat: i % 11 === 4, atas_nama: false })
          anggota.forEach((st, n) => {
            const kena = (n + i * 3 + group.length) % 13 === 0
            const kode = kena ? ['S', 'I', 'T', 'A', 'B'][(n + i) % 5] : 'H'
            isi.push([id, st.id, kode, kode === 'S' ? 'Demam' : kode === 'I' ? 'Izin keperluan keluarga' : null])
          })
        }
      }
      return { kelas: { id: g.id, nama: g.nama, jenjang: g.jenjang, tingkat: g.tingkat }, mulai, selesai, sesi, isi, rencana,
        santri: anggota.map((s) => ({ id: s.id, nis: s.nis, nama: s.nama_lengkap, jenis_kelamin: s.jenis_kelamin, status: s.status, aktif_di_kamar: true })) }
    },

    /** Ringkasan semua kelas yang terlihat pada rentang (dasbor pemantauan). */
    async ringkasan(mulai, selesai) {
      if (!MODE_DEMO) return (await rpc('ringkasan_kelas', { p_mulai: mulai, p_selesai: selesai })) || []
      await this.muatKelas(); const jd = useJadwal(); const hasil = []; const hari = hariIniISO()
      const slot = await jd.slot(mulai < tambahHari(hari, -61) ? tambahHari(hari, -61) : mulai, hari)
      for (const k of this.kelas) {
        const d = await this.rinci(k.id, mulai, selesai); const t = { I: 0, S: 0, A: 0, T: 0, B: 0, n: 0 }
        for (const [, , kode] of d.isi) { t.n++; if (t[kode] != null) t[kode]++ }
        const sl = slot.filter((x) => x.group_id === k.id && x.tanggal <= selesai); const lewat = sl.filter((x) => x.lewat); const hi = sl.filter((x) => x.tanggal === hari)
        hasil.push({ id: k.id, nama: k.nama, jenjang: k.jenjang, tingkat: k.tingkat, jenis_kelamin: k.jenis_kelamin, wali: k.wali.map((w) => w.nama).join(', '), santri: k.jumlah,
          sesi_rencana: d.rencana.length, sesi_terisi: d.sesi.length, anggota: t.n, hadir: t.n - t.I - t.S - t.A, izin: t.I, sakit: t.S, absen: t.A, bolos: t.B, terlambat: t.T,
          persen: t.n ? Math.round(((t.n - t.I - t.S - t.A) / t.n) * 1000) / 10 : null, hari_ini_wajib: !minggu(hari), hari_ini_terisi: d.sesi.some((s) => s.tanggal === hari),
          sakit_aktif: k.id === 'g-7a' ? 1 : 0, izin_aktif: k.id === 'g-8a' ? 1 : 0,
          jp_terjadwal: lewat.length, jp_terlaksana: lewat.filter((x) => x.status === 'terlaksana').length, jp_tidak: lewat.filter((x) => x.status === 'tidak_terlaksana').length,
          jp_kosong: lewat.filter((x) => x.status === 'belum').length, jp_hari_ini: hi.length, jp_hari_ini_isi: hi.filter((x) => x.status !== 'belum').length })
      }
      return hasil
    },

    dengarkan(fn) {
      if (MODE_DEMO || this.saluran) return
      this.saluran = supabase.channel('wali-kelas').on('postgres_changes', { event: '*', schema: 'public', table: 'student_attendance_sessions' }, () => fn())
        .on('postgres_changes', { event: '*', schema: 'public', table: 'teaching_journals' }, () => fn()).subscribe()
    },
    berhenti() { if (this.saluran) { supabase.removeChannel(this.saluran); this.saluran = null } },
  },
})
