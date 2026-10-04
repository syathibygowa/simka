// SIMKA PRO | src/stores/kelompok.js | v1.0 | Fase 3 – Perbaikan P1 (kartu, kelompok, pengumuman) | 04/10/2026
// Kelompok pegawai bebas (Pengurus Harian, Pengurus Inti, panitia, tim) beserta anggotanya.
// Dibaca semua pegawai (untuk pilihan sasaran); diubah superadmin atau admin ber-izin kelola_kelompok.
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { pesanGalat } from './lembaga'

const DEMO = () => [
  { id: 'k1', nama: 'Pengurus Harian', singkatan: 'PH', keterangan: 'Pimpinan harian pondok', warna: 'beranda', aktif: true, urutan: 1,
    anggota: [{ employee_id: 'd-sa', peran: 'Ketua' }, { employee_id: 'p3', peran: 'Sekretaris' }, { employee_id: 'p1', peran: 'Anggota' }] },
  { id: 'k2', nama: 'Pengurus Inti', singkatan: 'PI', keterangan: 'Direktur, wakil direktur, dan kepala bidang', warna: 'pegawai', aktif: true, urutan: 2,
    anggota: [{ employee_id: 'p3', peran: 'Ketua' }, { employee_id: 'p2' }, { employee_id: 'p4' }, { employee_id: 'p5' }] },
  { id: 'k3', nama: 'Panitia Ujian Tahfizh', singkatan: '', keterangan: 'Semester ganjil 2026/2027', warna: 'tahfizh', aktif: true, urutan: 3, anggota: [{ employee_id: 'p1', peran: 'Ketua' }, { employee_id: 'd-pg' }] },
]

export const useKelompok = defineStore('kelompok', {
  state: () => ({ daftar: [], dimuat: false, memuat: false }),
  getters: {
    aktif: (s) => s.daftar.filter((k) => k.aktif),
    cari: (s) => (id) => s.daftar.find((k) => k.id === id),
  },
  actions: {
    async muat(paksa = false) {
      if (this.dimuat && !paksa) return
      this.memuat = true
      try {
        if (MODE_DEMO) { if (!this.daftar.length) this.daftar = DEMO() }
        else {
          const [g, m] = await Promise.all([
            supabase.from('employee_groups').select('*').order('urutan').order('nama'),
            supabase.from('employee_group_members').select('group_id, employee_id, peran, urutan').order('urutan'),
          ])
          if (g.error) throw new Error(pesanGalat(g.error))
          this.daftar = (g.data || []).map((k) => ({ ...k, anggota: (m.data || []).filter((x) => x.group_id === k.id) }))
        }
        this.dimuat = true
      } finally { this.memuat = false }
    },
    async simpan(k) {
      const isi = { nama: k.nama.trim(), singkatan: k.singkatan?.trim() || null, keterangan: k.keterangan?.trim() || null, warna: k.warna || 'pegawai', aktif: k.aktif !== false, urutan: Number(k.urutan) || 0 }
      if (MODE_DEMO) {
        if (k.id) Object.assign(this.cari(k.id), isi); else this.daftar.push({ ...isi, id: 'k' + Date.now(), anggota: [] })
        return k.id || this.daftar.at(-1).id
      }
      const q = k.id ? supabase.from('employee_groups').update(isi).eq('id', k.id).select('id').single() : supabase.from('employee_groups').insert(isi).select('id').single()
      const { data, error } = await q
      if (error) throw new Error(error.code === '23505' ? 'Nama kelompok sudah dipakai.' : pesanGalat(error))
      await this.muat(true)
      return data.id
    },
    async hapus(id) {
      if (!MODE_DEMO) { const { error } = await supabase.from('employee_groups').delete().eq('id', id); if (error) throw new Error(pesanGalat(error)) }
      this.daftar = this.daftar.filter((k) => k.id !== id)
    },
    /** Simpan seluruh anggota sekaligus: [{ employee_id, peran }] */
    async aturAnggota(id, anggota) {
      if (!MODE_DEMO) {
        const { error: e1 } = await supabase.from('employee_group_members').delete().eq('group_id', id)
        if (e1) throw new Error(pesanGalat(e1))
        if (anggota.length) {
          const { error } = await supabase.from('employee_group_members').insert(anggota.map((a, i) => ({ group_id: id, employee_id: a.employee_id, peran: a.peran?.trim() || null, urutan: i })))
          if (error) throw new Error(pesanGalat(error))
        }
      }
      this.cari(id).anggota = anggota.map((a, i) => ({ ...a, group_id: id, urutan: i }))
    },
  },
})
