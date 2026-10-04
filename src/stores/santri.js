// SIMKA PRO | src/stores/santri.js | v1.0 | Fase 4 – Tahap 1 Data santri | 04/10/2026
// Data santri: daftar (sesuai cakupan RLS), simpan beserta kontak, impor Excel, status, mutasi keluar,
// riwayat, dan hapus (superadmin). Semua penulisan lewat fungsi SQL (tabel santri tidak dapat ditulis langsung).
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { SANTRI_DEMO, RIWAYAT_SANTRI_DEMO } from '@/lib/demoSantri'
import { pesanGalat } from './lembaga'
import { hariIniISO } from '@/lib/tanggal'

const urutNama = (a, b) => a.nama_lengkap.localeCompare(b.nama_lengkap, 'id')

export const useSantri = defineStore('santri', {
  state: () => ({ daftar: [], memuat: false, galat: '', riwayat: {}, dimuat: false, saluran: null }),
  getters: {
    aktif: (s) => s.daftar.filter((x) => x.status === 'aktif'),
  },
  actions: {
    async muat(paksa = false) {
      if (this.dimuat && !paksa) return
      this.memuat = true; this.galat = ''
      try {
        if (MODE_DEMO) { if (!this.daftar.length) this.daftar = SANTRI_DEMO().sort(urutNama); this.dimuat = true; return }
        const semua = []
        for (let dari = 0; ; dari += 1000) { // dimuat per 1000 baris
          const { data, error } = await supabase.from('v_santri').select('*').order('nama_lengkap').range(dari, dari + 999)
          if (error) { this.galat = 'Data santri gagal dimuat. Periksa koneksi lalu muat ulang.'; return }
          semua.push(...data); if (data.length < 1000) break
        }
        this.daftar = semua; this.dimuat = true
        this.dengarkan()
      } finally { this.memuat = false }
    },
    /** Perubahan dari perangkat lain (Realtime) memuat ulang baris terkait. */
    dengarkan() {
      if (MODE_DEMO || this.saluran) return
      this.saluran = supabase.channel('santri-berubah')
        .on('postgres_changes', { event: '*', schema: 'public', table: 'students' }, (e) => {
          const id = e.new?.id || e.old?.id
          if (e.eventType === 'DELETE') this.daftar = this.daftar.filter((x) => x.id !== id)
          else this.segarkan(id)
        }).subscribe()
    },
    async segarkan(id) {
      if (MODE_DEMO) return
      const { data } = await supabase.from('v_santri').select('*').eq('id', id).maybeSingle()
      const i = this.daftar.findIndex((x) => x.id === id)
      if (data) { if (i >= 0) this.daftar[i] = data; else { this.daftar.push(data); this.daftar.sort(urutNama) } }
      else if (i >= 0) this.daftar.splice(i, 1)
      delete this.riwayat[id]
    },
    cari(id) { return this.daftar.find((x) => x.id === id) },

    /** Simpan satu santri (baru/ubah) beserta kontak; mengembalikan id. */
    async simpan(isi) {
      if (MODE_DEMO) {
        const kontak = (isi.kontak || []).filter((k) => !k.hapus).map((k) => ({ ...k, utama: !!k.utama }))
        const data = { ...isi, kontak, tahun_masuk: 2000 + Number(isi.nis.slice(0, 2)), angkatan: Number(isi.nis.slice(2, 4)),
          nama_jenjang: isi.jenjang === 'sma' ? 'SMA' : 'Kesetaraan Wustha' }
        if (this.daftar.some((x) => x.nis === isi.nis && x.id !== isi.id)) throw new Error('NIS sudah dipakai santri lain.')
        if (!isi.id) { data.id = 's' + Date.now(); data.status = 'aktif'; data.status_sejak = hariIniISO(); this.daftar.push(data); this.daftar.sort(urutNama) }
        else { const i = this.daftar.findIndex((x) => x.id === isi.id); this.daftar[i] = { ...this.daftar[i], ...data } }
        delete this.riwayat[data.id]
        return data.id
      }
      const { data: id, error } = await supabase.rpc('simpan_santri_form', { p: isi })
      if (error) throw new Error(pesanGalat(error))
      await this.segarkan(id)
      return id
    },

    /** Impor banyak baris; hasil per baris { baris, ok, aksi, pesan }. */
    async impor(baris) {
      if (MODE_DEMO) {
        const hasil = []
        for (const [i, b] of baris.entries()) {
          const ada = this.daftar.find((x) => x.nis === b.nis)
          try {
            if (!ada && (!b.nama_lengkap || !b.jenis_kelamin || !b.tingkat)) throw new Error('Data wajib belum lengkap (NIS, nama, jenis kelamin, jenjang, kelas).')
            await this.simpan({ ...(ada || {}), ...b, id: ada?.id, kontak: [...(ada?.kontak || []).filter((k) => !(b.kontak || []).some((x) => x.hubungan === k.hubungan)), ...(b.kontak || [])] })
            hasil.push({ baris: i + 1, ok: true, aksi: ada ? 'diperbarui' : 'ditambah' })
          } catch (e) { hasil.push({ baris: i + 1, ok: false, pesan: e.message }) }
        }
        return hasil
      }
      const hasil = []
      for (let i = 0; i < baris.length; i += 100) { // dikirim per 100 baris
        const { data, error } = await supabase.rpc('impor_santri', { p_baris: baris.slice(i, i + 100) })
        if (error) throw new Error(pesanGalat(error))
        hasil.push(...data.map((h) => ({ ...h, baris: h.baris + i })))
      }
      await this.muat(true)
      return hasil
    },

    async muatRiwayat(id) {
      if (MODE_DEMO) { const s = this.cari(id); this.riwayat[id] = s ? RIWAYAT_SANTRI_DEMO(s) : { status: [], mutasi: [] }; return }
      const [st, mu] = await Promise.all([
        supabase.from('student_status_history').select('*, pegawai:oleh(nama_lengkap)').eq('student_id', id).order('created_at', { ascending: false }),
        supabase.from('student_mutations').select('*').eq('student_id', id).order('created_at', { ascending: false }),
      ])
      this.riwayat[id] = {
        status: (st.data || []).map((h) => ({ ...h, nama_oleh: h.pegawai?.nama_lengkap || null })),
        mutasi: mu.data || [],
      }
    },

    async ubahStatus(id, status, tanggal, alasan) {
      if (MODE_DEMO) {
        const s = this.cari(id); const lama = s.status
        s.status = status; s.status_sejak = tanggal
        this.riwayat[id] = this.riwayat[id] || { status: [], mutasi: [] }
        this.riwayat[id].status.unshift({ id: 'h' + Date.now(), status_lama: lama, status_baru: status, tanggal, alasan, nama_oleh: 'Anda (mode demo)' })
        return
      }
      const { error } = await supabase.rpc('ubah_status_santri', { p_id: id, p_status: status, p_tanggal: tanggal, p_alasan: alasan })
      if (error) throw new Error(pesanGalat(error))
      await this.segarkan(id); await this.muatRiwayat(id)
    },

    /** Mutasi keluar → { nomor } surat keterangan pindah. */
    async mutasiKeluar(id, tanggal, tujuan, alasan) {
      if (MODE_DEMO) {
        const s = this.cari(id); const nomor = `K.00${Math.floor(Math.random() * 9) + 1}/IL/${s.jenjang === 'sma' ? 'SMAS-IAS' : 'KW-IAS'}/IV/1448`
        await this.ubahStatus(id, 'mutasi_keluar', tanggal, `Mutasi keluar ke ${tujuan}: ${alasan}`)
        this.riwayat[id].mutasi.unshift({ id: 'm' + Date.now(), jenis: 'keluar', tanggal, sekolah: tujuan, alasan, tingkat: s.tingkat, jenjang: s.jenjang, nomor_surat: nomor, kop: s.jenjang })
        return { nomor }
      }
      const { data, error } = await supabase.rpc('mutasi_keluar_santri', { p_id: id, p_tanggal: tanggal, p_tujuan: tujuan, p_alasan: alasan })
      if (error) throw new Error(pesanGalat(error))
      await this.segarkan(id); await this.muatRiwayat(id)
      return data
    },

    async hapus(id) {
      if (!MODE_DEMO) {
        const { data, error } = await supabase.from('students').delete().eq('id', id).select('id')
        if (error) throw new Error(pesanGalat(error))
        if (!data?.length) throw new Error('Data santri ini tidak dapat dihapus. Hanya superadmin yang dapat menghapus data santri.')
      }
      this.daftar = this.daftar.filter((x) => x.id !== id)
    },
  },
})
