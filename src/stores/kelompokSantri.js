// SIMKA PRO | src/stores/kelompokSantri.js | v1.1 | Fase 4 – Tahap 4 Ekskul | 04/10/2026
// Kelompok santri (kelas, kamar, halaqah, ekskul, lainnya): daftar per tahun ajaran, anggota beserta riwayat,
// pengasuh, impor pembagian. Penulisan lewat fungsi SQL (tabel tidak dapat ditulis langsung).
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { dataKelompokDemo, ID_PEGAWAI_DEMO } from '@/lib/demoKelompok'
import { JADWAL_EKSKUL_DEMO } from '@/lib/demoAbsensi'
import { pesanGalat } from './lembaga'
import { useSesi } from './sesi'
import { useSantri } from './santri'
import { hariIniISO } from '@/lib/tanggal'

const URUT = ['kelas', 'kamar', 'halaqah', 'ekskul', 'lainnya']
const urutKelompok = (a, b) => URUT.indexOf(a.jenis) - URUT.indexOf(b.jenis) || (a.tingkat || 0) - (b.tingkat || 0)
  || (a.urutan || 0) - (b.urutan || 0) || a.nama.localeCompare(b.nama, 'id', { numeric: true })

export const useKelompokSantri = defineStore('kelompokSantri', {
  state: () => ({ daftar: [], tahunAjaran: [], taDipilih: '', memuat: false, galat: '', anggota: {}, jadwal: {} }),
  getters: {
    taAktif: (s) => s.tahunAjaran.find((t) => t.aktif) || null,
    taSekarang: (s) => s.tahunAjaran.find((t) => t.id === s.taDipilih) || s.tahunAjaran.find((t) => t.aktif) || null,
    dariTA: (s) => s.daftar.filter((g) => g.academic_year_id === (s.taDipilih || s.tahunAjaran.find((t) => t.aktif)?.id)),
  },
  actions: {
    async muat() {
      this.memuat = true; this.galat = ''
      try {
        if (MODE_DEMO) {
          const san = useSantri(); await san.muat()
          const d = dataKelompokDemo(san.daftar); this.tahunAjaran = d.ta
          this.hitungDemo(d)
          const pegawai = useSesi().peran === 'pegawai'
          this.daftar = d.kelompok.filter((g) => !pegawai || g.asuhan_saya).sort(urutKelompok)
          if (!this.taDipilih) this.taDipilih = d.ta[0].id
          return
        }
        const [ta, kl] = await Promise.all([
          supabase.from('academic_years').select('id, nama, mulai, selesai, aktif, terkunci').order('mulai', { ascending: false }),
          supabase.from('v_kelompok').select('*'),
        ])
        if (kl.error) { this.galat = 'Data kelompok gagal dimuat. Periksa koneksi lalu muat ulang.'; return }
        this.tahunAjaran = ta.data || []
        this.daftar = (kl.data || []).sort(urutKelompok)
        if (!this.taDipilih) this.taDipilih = this.taAktif?.id || this.tahunAjaran[0]?.id || ''
      } finally { this.memuat = false }
    },
    hitungDemo(d) {
      const san = useSantri()
      d.kelompok.forEach((g) => {
        const aktif = d.anggota.filter((a) => a.group_id === g.id && !a.selesai)
        const jk = (sid) => san.daftar.find((x) => x.id === sid)?.jenis_kelamin
        g.jumlah = aktif.length; g.jumlah_l = aktif.filter((a) => jk(a.student_id) === 'L').length; g.jumlah_p = aktif.filter((a) => jk(a.student_id) === 'P').length
        g.nama_naqib = san.daftar.find((x) => x.id === g.naqib_id)?.nama_lengkap || null
        g.asuhan_saya = useSesi().peran === 'pegawai' && g.pengasuh.some((p) => p.employee_id === ID_PEGAWAI_DEMO)
      })
    },
    cari(id) { return this.daftar.find((g) => g.id === id) },

    /** Anggota satu kelompok: { aktif: [...], riwayat: [...] } berisi baris group_members. */
    async muatAnggota(id) {
      if (MODE_DEMO) {
        const d = dataKelompokDemo([])
        const baris = d.anggota.filter((a) => a.group_id === id)
        this.anggota[id] = { aktif: baris.filter((a) => !a.selesai), riwayat: baris.filter((a) => a.selesai) }
        return
      }
      const { data, error } = await supabase.from('group_members').select('id, student_id, mulai, selesai, alasan_keluar')
        .eq('group_id', id).order('mulai', { ascending: false })
      if (error) throw new Error(pesanGalat(error))
      this.anggota[id] = { aktif: data.filter((a) => !a.selesai), riwayat: data.filter((a) => a.selesai) }
    },

    async simpan(isi) {
      if (MODE_DEMO) {
        const d = dataKelompokDemo([])
        if (d.kelompok.some((g) => g.id !== isi.id && g.jenis === isi.jenis && g.nama.toLowerCase() === isi.nama.trim().toLowerCase()))
          throw new Error('Nama kelompok sudah dipakai untuk jenis yang sama di tahun ajaran ini.')
        const tingkat = isi.jenis === 'kelas' ? Number(isi.tingkat) : null
        const data = { ...isi, nama: isi.nama.trim(), tingkat, jenjang: tingkat ? (tingkat >= 10 ? 'sma' : 'wustha') : null, jenis_kelamin: isi.jenis_kelamin || null }
        if (!isi.id) { Object.assign(data, { id: 'g' + Date.now(), academic_year_id: 'ta1', tahun_ajaran: '2026/2027', ta_aktif: true, aktif: true, pengasuh: [] }); d.kelompok.push(data) }
        else Object.assign(d.kelompok.find((g) => g.id === isi.id), data)
        await this.muat(); return data.id
      }
      const { data, error } = await supabase.rpc('simpan_kelompok_form', { p: { ...isi, academic_year_id: isi.academic_year_id || this.taSekarang?.id } })
      if (error) throw new Error(pesanGalat(error))
      await this.muat(); return data
    },

    async hapus(id) {
      if (MODE_DEMO) {
        const d = dataKelompokDemo([]); const ada = d.anggota.some((a) => a.group_id === id)
        if (ada) { d.kelompok.find((g) => g.id === id).aktif = false; d.anggota.filter((a) => a.group_id === id && !a.selesai).forEach((a) => { a.selesai = hariIniISO(); a.alasan_keluar = 'Kelompok dinonaktifkan' }) }
        else d.kelompok.splice(d.kelompok.findIndex((g) => g.id === id), 1)
        await this.muat(); useSantri().segarkanKelompokDemo(); return ada ? 'dinonaktifkan' : 'dihapus'
      }
      const { data, error } = await supabase.rpc('hapus_kelompok', { p_id: id })
      if (error) throw new Error(pesanGalat(error))
      await this.muat(); await useSantri().muat(true); return data
    },

    /** daftar: [{ employee_id, peran, mulai, sampai, catatan }] menggantikan pengasuh kelompok. */
    async aturPengasuh(id, daftar, namaPegawai = {}) {
      if (MODE_DEMO) {
        dataKelompokDemo([]).kelompok.find((g) => g.id === id).pengasuh = daftar.map((p) => ({ ...p, nama: namaPegawai[p.employee_id] || 'Pegawai', berlaku: true }))
        await this.muat(); return
      }
      const { error } = await supabase.rpc('atur_pengasuh', { p_group: id, p_daftar: daftar })
      if (error) throw new Error(pesanGalat(error))
      await this.muat()
    },

    /** Tambah/pindahkan santri ke kelompok → { ditambah, dipindah, sudah, dilewati: [{ id, pesan }] } */
    async tambahAnggota(id, ids, tanggal, alasan) {
      if (MODE_DEMO) {
        const d = dataKelompokDemo([]); const g = d.kelompok.find((x) => x.id === id); const san = useSantri()
        const h = { ditambah: 0, dipindah: 0, sudah: 0, dilewati: [] }
        for (const sid of ids) {
          const s = san.cari(sid)
          if (g.jenis_kelamin && s.jenis_kelamin !== g.jenis_kelamin) { h.dilewati.push({ id: sid, pesan: `${s.nama_lengkap} tidak sesuai jenis kelamin kelompok.` }); continue }
          if (g.jenis === 'kelas' && s.tingkat !== g.tingkat) { h.dilewati.push({ id: sid, pesan: `${s.nama_lengkap} tercatat kelas ${s.tingkat}.` }); continue }
          if (d.anggota.some((a) => a.group_id === id && a.student_id === sid && !a.selesai)) { h.sudah++; continue }
          let pindah = false
          if (['kelas', 'kamar', 'halaqah'].includes(g.jenis)) {
            d.anggota.filter((a) => a.student_id === sid && !a.selesai && d.kelompok.find((k) => k.id === a.group_id)?.jenis === g.jenis)
              .forEach((a) => { a.selesai = tanggal; a.alasan_keluar = `Pindah ke ${g.nama}${alasan ? ': ' + alasan : ''}`; pindah = true })
          }
          d.anggota.push({ id: 'm' + Date.now() + sid, group_id: id, student_id: sid, mulai: tanggal, selesai: null, alasan_keluar: null })
          pindah ? h.dipindah++ : h.ditambah++
        }
        san.segarkanKelompokDemo(); await this.muat(); await this.muatAnggota(id); return h
      }
      const { data, error } = await supabase.rpc('tambah_anggota', { p_group: id, p_santri: ids, p_tanggal: tanggal, p_alasan: alasan || null })
      if (error) throw new Error(pesanGalat(error))
      await Promise.all([this.muat(), this.muatAnggota(id), useSantri().muat(true)])
      return data
    },

    async keluarkan(id, ids, tanggal, alasan) {
      if (MODE_DEMO) {
        dataKelompokDemo([]).anggota.filter((a) => a.group_id === id && ids.includes(a.student_id) && !a.selesai)
          .forEach((a) => { a.selesai = tanggal; a.alasan_keluar = alasan || 'Dikeluarkan dari kelompok' })
        useSantri().segarkanKelompokDemo(); await this.muat(); await this.muatAnggota(id); return ids.length
      }
      const { data, error } = await supabase.rpc('keluarkan_anggota', { p_group: id, p_santri: ids, p_tanggal: tanggal, p_alasan: alasan || null })
      if (error) throw new Error(pesanGalat(error))
      await Promise.all([this.muat(), this.muatAnggota(id), useSantri().muat(true)])
      return data
    },

    /** Jadwal pertemuan semua ekskul yang terlihat: { [group_id]: [{ id, hari, jam_mulai, jam_selesai, tempat }] } */
    async muatJadwal() {
      if (MODE_DEMO) { this.jadwal = JSON.parse(JSON.stringify(JADWAL_EKSKUL_DEMO)); return }
      const { data, error } = await supabase.from('extracurricular_schedules').select('id, group_id, hari, jam_mulai, jam_selesai, tempat').eq('aktif', true).order('hari').order('jam_mulai')
      if (error) throw new Error(pesanGalat(error))
      const peta = {}; for (const j of data) (peta[j.group_id] ||= []).push({ ...j, jam_mulai: j.jam_mulai.slice(0, 5), jam_selesai: j.jam_selesai.slice(0, 5) })
      this.jadwal = peta
    },
    /** Ganti jadwal satu ekskul. Jadwal otomatis menjadi sesi presensi pembina/pelatihnya. */
    async simpanJadwal(group, baris) {
      if (MODE_DEMO) { JADWAL_EKSKUL_DEMO[group] = baris.map((b, i) => ({ ...b, id: b.id || `jb${Date.now()}${i}` })); this.jadwal[group] = JADWAL_EKSKUL_DEMO[group]; return }
      const { error } = await supabase.rpc('simpan_jadwal_ekskul', { p_group: group, p_jadwal: baris })
      if (error) throw new Error(pesanGalat(error))
      await this.muatJadwal()
    },

    /** Impor pembagian: baris [{ nis, kelas, kamar, halaqah, ekskul }] → hasil per baris. */
    async impor(baris) {
      if (MODE_DEMO) {
        const san = useSantri(); const d = dataKelompokDemo([]); const hasil = []
        for (const [i, b] of baris.entries()) {
          const s = san.daftar.find((x) => x.nis === b.nis)
          if (!s) { hasil.push({ baris: i + 1, ok: false, pesan: `NIS ${b.nis} belum terdaftar di Data Santri.` }); continue }
          const catatan = []
          for (const jenis of ['kelas', 'kamar', 'halaqah', 'ekskul']) {
            for (const nama of String(b[jenis] || '').split(jenis === 'ekskul' ? /\s*[,;]\s*/ : /\s*;\s*/).filter(Boolean)) {
              let g = d.kelompok.find((x) => x.jenis === jenis && x.nama.toLowerCase() === nama.toLowerCase())
              if (!g) { const id = await this.simpan({ jenis, nama, tingkat: jenis === 'kelas' ? (parseInt(nama, 10) || s.tingkat) : null, jenis_kelamin: ['kamar', 'halaqah'].includes(jenis) ? s.jenis_kelamin : '' }); g = d.kelompok.find((x) => x.id === id); catatan.push(`${jenis} ${nama} dibuat`) }
              const h = await this.tambahAnggota(g.id, [s.id], hariIniISO(), 'Impor pembagian')
              if (h.dilewati.length) catatan.push(`GAGAL ${jenis} ${nama}: ${h.dilewati[0].pesan}`)
            }
          }
          hasil.push({ baris: i + 1, ok: !catatan.some((c) => c.startsWith('GAGAL')), nama: s.nama_lengkap, pesan: catatan.join('; ') })
        }
        return hasil
      }
      const hasil = []
      for (let i = 0; i < baris.length; i += 100) {
        const { data, error } = await supabase.rpc('impor_pembagian', { p_baris: baris.slice(i, i + 100) })
        if (error) throw new Error(pesanGalat(error))
        hasil.push(...data.map((h) => ({ ...h, baris: h.baris + i })))
      }
      await Promise.all([this.muat(), useSantri().muat(true)])
      return hasil
    },
  },
})
