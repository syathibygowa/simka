// SIMKA PRO | src/stores/aturPresensi.js | v1.2 | 14.36.0: pola bawaan jabatan putri (pegawai perempuan) | 30/10/2026
// Data pengaturan presensi: titik GPS, pola tugas, sesi, jadwal pegawai, dan pengaturan umum.
// Hak (diperiksa server/RLS): titik dan pengaturan umum = superadmin; pola, sesi, jadwal = izin atur_presensi.
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { PRESENSI_DEMO } from '@/lib/demo'
import { pesanGalat } from './lembaga'
import { useSesi } from './sesi'
import { useOrganisasi } from './organisasi'
import { usePegawai } from './pegawai'
import { hariIniISO } from '@/lib/tanggal'
import { keMenit, jamTitik } from '@/lib/presensi'
import { useShift } from './shift'

const BAWAAN = { mulai_tanggal: null, jeda_minimal_pulang_menit: 15, batas_akurasi_m: 100, berlaku_cek_detik: 180, retensi_selfie_hari: 183, folder_selfie: 'SIMKA PRO/Presensi', pengingat_menit: 10 }
const idDemo = (awal) => `${awal}-${Date.now().toString(36)}${Math.random().toString(36).slice(2, 5)}`

async function jalankan(q) {
  const { data, error } = await q
  if (error) {
    const pesan = error.hint && error.message ? error.message : pesanGalat(error)
    throw new Error(pesan)
  }
  return data
}

export const useAturPresensi = defineStore('aturPresensi', {
  state: () => ({ titik: [], pola: [], sesi: [], jadwal: [], pengaturan: { ...BAWAAN }, izin: [], dimuat: false, memuat: false }),
  getters: {
    /** Superadmin selalu boleh; admin sesuai izin yang dicentang superadmin. */
    boleh: (s) => (kode) => useSesi().isSuperadmin || s.izin.includes(kode),
    polaUmum: (s) => s.pola.filter((p) => !p.employee_id).sort((a, b) => a.urutan - b.urutan || a.nama.localeCompare(b.nama)),
    sesiPola: (s) => (id) => s.sesi.filter((x) => x.pattern_id === id).sort((a, b) => a.urutan - b.urutan || String(a.jam_mulai).localeCompare(String(b.jam_mulai))),
    jadwalPegawai: (s) => (id) => s.jadwal.filter((j) => j.employee_id === id),
    cariPola: (s) => (id) => s.pola.find((p) => p.id === id),
    pemakaiPola: (s) => (id) => new Set(s.jadwal.filter((j) => j.pattern_id === id && j.aktif).map((j) => j.employee_id)).size,
  },
  actions: {
    async muat(paksa = false) {
      if (this.dimuat && !paksa) return
      this.memuat = true
      try {
        if (MODE_DEMO) {
          if (!this.dimuat) {
            const d = PRESENSI_DEMO()
            Object.assign(this, { titik: d.titik, pola: d.pola, sesi: d.sesi, pengaturan: { ...BAWAAN, ...d.pengaturan } })
            const org = useOrganisasi(); await org.muat()
            org.fungsional.forEach((f) => { f.pola_id = d.polaJabatan[f.id] || null })
            this.izin = useSesi().isSuperadmin ? ['atur_presensi', 'verval_presensi'] : ['atur_presensi']
            const peg = usePegawai(); if (!peg.daftar.length) await peg.muat()
            peg.daftar.forEach((p) => this.sinkronDemo(p.id))
          }
          return
        }
        const [titik, pola, sesi, jadwal, set, izin] = await Promise.all([
          jalankan(supabase.from('gps_points').select('*').order('urutan').order('nama')),
          jalankan(supabase.from('task_patterns').select('*').order('urutan')),
          jalankan(supabase.from('pattern_sessions').select('*').order('urutan')),
          jalankan(supabase.from('employee_schedules').select('*')),
          supabase.from('institution_settings').select('nilai').eq('kunci', 'presensi').maybeSingle(),
          supabase.rpc('izin_admin_saya'),
        ])
        Object.assign(this, { titik, pola, sesi, jadwal })
        this.pengaturan = { ...BAWAAN, ...(set.data?.nilai || {}) }
        this.izin = izin.data || []
      } finally { this.memuat = false; this.dimuat = true }
    },

    // ---------------- Titik GPS (superadmin) ----------------
    async simpanTitik(t) {
      const isi = { nama: t.nama.trim(), lat: Number(t.lat), lng: Number(t.lng), radius_m: Number(t.radius_m), aktif: !!t.aktif, urutan: Number(t.urutan || 0), catatan: t.catatan || null }
      if (MODE_DEMO) {
        const baris = { ...isi, id: t.id || idDemo('tk') }
        const i = this.titik.findIndex((x) => x.id === baris.id); if (i >= 0) this.titik[i] = baris; else this.titik.push(baris)
        return baris
      }
      const data = await jalankan(t.id ? supabase.from('gps_points').update(isi).eq('id', t.id).select().single() : supabase.from('gps_points').insert(isi).select().single())
      const i = this.titik.findIndex((x) => x.id === data.id); if (i >= 0) this.titik[i] = data; else this.titik.push(data)
      return data
    },
    async hapusTitik(id) {
      if (!MODE_DEMO) await jalankan(supabase.from('gps_points').delete().eq('id', id))
      this.titik = this.titik.filter((x) => x.id !== id)
    },

    // ---------------- Pola dan sesi (izin atur_presensi) ----------------
    async simpanPola(p) {
      const isi = { kode: p.kode, nama: p.nama.trim(), jenis: p.jenis, kalender: p.kalender || null, warna: p.warna || 'presensi', aktif: !!p.aktif, urutan: Number(p.urutan || 0), catatan: p.catatan || null, employee_id: p.employee_id || null }
      let data
      if (MODE_DEMO) data = { pola_struktural: false, ...this.pola.find((x) => x.id === p.id), ...isi, id: p.id || idDemo('pl') }
      else data = await jalankan(p.id ? supabase.from('task_patterns').update(isi).eq('id', p.id).select().single() : supabase.from('task_patterns').insert(isi).select().single())
      const i = this.pola.findIndex((x) => x.id === data.id); if (i >= 0) this.pola[i] = data; else this.pola.push(data)
      return data
    },
    async hapusPola(id) {
      if (!MODE_DEMO) await jalankan(supabase.from('task_patterns').delete().eq('id', id))
      this.pola = this.pola.filter((x) => x.id !== id)
      this.sesi = this.sesi.filter((x) => x.pattern_id !== id)
      this.jadwal = this.jadwal.filter((x) => x.pattern_id !== id)
      useOrganisasi().fungsional.forEach((f) => { if (f.pola_id === id) f.pola_id = null; if (f.pola_putri_id === id) f.pola_putri_id = null })
    },
    async simpanSesi(s) {
      const angka = ['buka_menit', 'toleransi_terlambat_menit', 'tutup_menit', 'pulang_buka_menit', 'toleransi_cepat_pulang_menit', 'batas_pulang_menit', 'urutan']
      const isi = { pattern_id: s.pattern_id, kode: s.kode, nama: s.nama.trim(), hari: [...s.hari].sort(), jam_mulai: s.jam_mulai, jam_selesai: s.jam_selesai,
        wajib_pulang: !!s.wajib_pulang, opsional: !!s.opsional, aktif: !!s.aktif, label_datang: s.label_datang || 'Datang', label_pulang: s.label_pulang || 'Pulang' }
      angka.forEach((k) => { isi[k] = Number(s[k] || 0) })
      let data
      if (MODE_DEMO) {
        const bentrok = this.sesi.find((x) => x.id !== s.id && x.pattern_id === s.pattern_id && x.kode === s.kode && x.aktif && isi.aktif && x.hari.some((h) => isi.hari.includes(h)))
        if (bentrok) throw new Error(`Sesi ${isi.nama} sudah memiliki jam pada sebagian hari yang dipilih. Pilih hari yang berbeda.`)
        data = { ...isi, id: s.id || idDemo('ss'), jam_mulai: isi.jam_mulai.slice(0, 5) + ':00', jam_selesai: isi.jam_selesai.slice(0, 5) + ':00' }
      } else data = await jalankan(s.id ? supabase.from('pattern_sessions').update(isi).eq('id', s.id).select().single() : supabase.from('pattern_sessions').insert(isi).select().single())
      const i = this.sesi.findIndex((x) => x.id === data.id); if (i >= 0) this.sesi[i] = data; else this.sesi.push(data)
      return data
    },
    async hapusSesi(id) {
      if (!MODE_DEMO) await jalankan(supabase.from('pattern_sessions').delete().eq('id', id))
      this.sesi = this.sesi.filter((x) => x.id !== id)
      this.jadwal.forEach((j) => { if (j.sesi_dipegang?.includes(id)) j.sesi_dipegang = j.sesi_dipegang.filter((x) => x !== id) })
    },
    /** Pola bawaan jabatan fungsional (server menyinkronkan jadwal semua pemegang jabatan). */
    async aturPolaJabatan(jabatanId, polaId, putri = false) {
      const org = useOrganisasi(); const kolom = putri ? 'pola_putri_id' : 'pola_id'
      if (MODE_DEMO) {
        const f = org.fungsional.find((x) => x.id === jabatanId); if (f) f[kolom] = polaId
        usePegawai().daftar.forEach((p) => this.sinkronDemo(p.id))
        return
      }
      await jalankan(supabase.rpc('atur_pola_jabatan', { p_jabatan: jabatanId, p_pola: polaId, p_putri: putri }))
      const f = org.fungsional.find((x) => x.id === jabatanId); if (f) f[kolom] = polaId
      this.jadwal = await jalankan(supabase.from('employee_schedules').select('*'))
    },

    // ---------------- Jadwal pegawai (izin atur_presensi) ----------------
    async simpanJadwal(j) {
      const isi = { employee_id: j.employee_id, pattern_id: j.pattern_id, sumber: j.sumber || 'manual', aktif: !!j.aktif,
        sesi_dipegang: j.sesi_dipegang?.length ? j.sesi_dipegang : null, catatan: j.catatan || null }
      let data
      if (MODE_DEMO) data = { ...isi, id: j.id || idDemo('js') }
      else data = await jalankan(j.id ? supabase.from('employee_schedules').update(isi).eq('id', j.id).select().single() : supabase.from('employee_schedules').insert(isi).select().single())
      const i = this.jadwal.findIndex((x) => x.id === data.id); if (i >= 0) this.jadwal[i] = data; else this.jadwal.push(data)
      return data
    },
    async hapusJadwal(id) {
      if (!MODE_DEMO) await jalankan(supabase.from('employee_schedules').delete().eq('id', id))
      this.jadwal = this.jadwal.filter((x) => x.id !== id)
    },
    async sinkronSemua() {
      if (MODE_DEMO) { usePegawai().daftar.forEach((p) => this.sinkronDemo(p.id)); return usePegawai().daftar.length }
      const n = await jalankan(supabase.rpc('sinkron_jadwal_semua'))
      this.jadwal = await jalankan(supabase.from('employee_schedules').select('*'))
      return n
    },
    /**
     * Jadwal kerja semua pegawai aktif selama 7 hari mulai `senin` (jam presensi yang dibaca sistem).
     * Hasil: { mulai, libur: [{ t, nama }], pegawai: [{ id, niy, nama, jk, unit_id, unit, pola: [], hari: [{ t, sesi: [...] }] }] }
     */
    async jadwalKerja(senin) {
      if (!MODE_DEMO) return jalankan(supabase.rpc('jadwal_kerja_pekan', { p_mulai: senin }))
      await this.muat()
      const peg = usePegawai(); const org = useOrganisasi(); const sh = useShift(); sh.siapkanDemo()
      const tgl = Array.from({ length: 7 }, (_, i) => { const d = new Date(senin + 'T00:00:00Z'); d.setUTCDate(d.getUTCDate() + i); return d.toISOString().slice(0, 10) })
      const jam = (m) => jamTitik(m).slice(0, 5)
      const pegawai = peg.daftar.filter((p) => (p.status_keaktifan || 'aktif') === 'aktif').map((p) => {
        const js = this.jadwal.filter((j) => j.employee_id === p.id && j.aktif).map((j) => ({ j, pola: this.cariPola(j.pattern_id) })).filter((x) => x.pola?.aktif)
        const hari = tgl.map((t) => {
          const dow = new Date(t + 'T00:00:00Z').getUTCDay(); const sesi = []
          for (const { j, pola } of js) {
            for (const x of this.sesiPola(pola.id).filter((x) => x.aktif && (!j.sesi_dipegang?.length || j.sesi_dipegang.includes(x.id)))) {
              const masuk = pola.jenis === 'shift'
                ? sh.demoRoster.some((r) => r.employee_id === p.id && r.tanggal === t && r.session_id === x.id)
                : (x.hari || []).includes(dow)
              if (!masuk) continue
              const m = keMenit(x.jam_mulai)
              sesi.push({ pola: pola.nama, jenis: pola.jenis, sesi: x.nama, warna: pola.warna, opsional: x.opsional, mulai: jam(m), selesai: jam(keMenit(x.jam_selesai)),
                buka: jam(m - (x.buka_menit ?? 30)), tepat: jam(m + (x.toleransi_terlambat_menit ?? 10)), tutup: jam(m + (x.tutup_menit ?? 120)), pulang: !!x.wajib_pulang, _m: m })
            }
          }
          return { t, sesi: sesi.sort((a, b) => a._m - b._m) }
        })
        return { id: p.id, niy: p.niy, nama: p.nama_lengkap, jk: p.jenis_kelamin, unit_id: p.org_unit_id, unit: org.units.find((u) => u.id === p.org_unit_id)?.nama || null,
          pola: [...new Set(js.map((x) => x.pola.nama))], hari }
      }).sort((a, b) => a.nama.localeCompare(b.nama))
      return { mulai: senin, libur: [], pegawai }
    },

    /** Mode demo: tiru fungsi server sinkron_jadwal(). */
    sinkronDemo(empId) {
      const org = useOrganisasi(); const p = usePegawai().cari(empId); if (!p) return
      const polaJab = [...new Set((p.fungsional_ids || []).map((id) => { const f = org.fungsional.find((x) => x.id === id); return p.jenis_kelamin === 'P' && f?.pola_putri_id ? f.pola_putri_id : f?.pola_id }).filter(Boolean))]
      this.jadwal = this.jadwal.filter((j) => !(j.employee_id === empId && ((j.sumber === 'jabatan' && !polaJab.includes(j.pattern_id)) || (j.sumber === 'struktural' && polaJab.length))))
      polaJab.forEach((pid) => { if (!this.jadwal.some((j) => j.employee_id === empId && j.pattern_id === pid)) this.jadwal.push({ id: idDemo('js'), employee_id: empId, pattern_id: pid, sumber: 'jabatan', aktif: true, sesi_dipegang: null, catatan: null }) })
      const str = this.pola.find((x) => x.pola_struktural)
      if (!polaJab.length && p.structural_position_id && str && !this.jadwal.some((j) => j.employee_id === empId && j.pattern_id === str.id)) {
        this.jadwal.push({ id: idDemo('js'), employee_id: empId, pattern_id: str.id, sumber: 'struktural', aktif: true, sesi_dipegang: null, catatan: null })
      }
    },
    /** Jadwal gabungan seorang pegawai pada rentang tanggal (dari server; mode demo dihitung di tampilan). */
    async pratinjau(empId, mulai = hariIniISO(), akhir = null) {
      if (MODE_DEMO) return null
      return await jalankan(supabase.rpc('pratinjau_jadwal', { p_emp: empId, p_mulai: mulai, p_akhir: akhir || mulai }))
    },

    // ---------------- Pengaturan umum (superadmin) ----------------
    async simpanPengaturan(nilai) {
      const isi = { ...this.pengaturan, ...nilai }
      if (!MODE_DEMO) await jalankan(supabase.from('institution_settings').upsert({ kunci: 'presensi', publik: false, nilai: isi }, { onConflict: 'kunci' }))
      this.pengaturan = isi
    },
  },
})
