// SIMKA PRO | src/stores/ubahNilai.js | v1.0 | Fase 12 – Tahap 6 Permintaan ubah nilai, rekap, ringkasan beranda | 13/10/2026
// Setelah periode penilaian ditutup (atau batas pengisian lewat), guru pengampu/penguji UTAS mengajukan permintaan ubah
// nilai beserta alasan; pengelola nilai menyetujui (nilai langsung diterapkan) atau menolak. Semua permintaan = riwayat.
// Juga: rekap penilaian untuk pimpinan dan ringkasan penilaian di beranda. Penulisan hanya lewat fungsi SQL.
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { pesanGalat } from './lembaga'
import { useSesi } from './sesi'

const rpc = async (nama, arg) => { const { data, error } = await supabase.rpc(nama, arg); if (error) throw new Error(pesanGalat(error)); return data }

// ---------- Data contoh ----------
const demo = {
  n: 2,
  daftar: [
    { id: 'gcr1', jenis: 'mapel', semester: 1, status: 'menunggu', perubahan: { nilai: { lama: 68, baru: 76 } }, alasan: 'Nilai remedial belum dimasukkan sebelum periode ditutup.',
      diajukan_pada: new Date(Date.now() - 3 * 3600e3).toISOString(), pengaju: 'Ust. Yusuf Maulana, S.Pd.', diputus_pada: null, pemutus: null, catatan_putusan: null,
      student_id: null, nis: '2615003', nama: 'Zaid Abdurrahman', jenis_kelamin: 'L', assignment_id: 'demo', utas_result_id: null, kelas: '10A', mapel: 'Matematika', mode: 'rekomendasi' },
    { id: 'gcr2', jenis: 'utas', semester: 1, status: 'disetujui', perubahan: { tajwid: { lama: 70, baru: 78 } }, alasan: 'Salah input nilai tajwid; sesuai berita acara ujian.',
      diajukan_pada: new Date(Date.now() - 50 * 3600e3).toISOString(), pengaju: 'Ust. Hasan Basri, Lc.', diputus_pada: new Date(Date.now() - 40 * 3600e3).toISOString(), pemutus: 'Superadmin SIMKA',
      catatan_putusan: 'Sesuai berita acara.', student_id: null, nis: '2514005', nama: 'Rasyid Ridha', jenis_kelamin: 'L', assignment_id: null, utas_result_id: 'u1', kelas: '8A', mapel: 'UTAS (tahfizh)', mode: null },
  ],
}
const kelolaDemo = () => { const s = useSesi(); return s.peran === 'superadmin' || (s.peran === 'admin' && s.izinAdmin.includes('kelola_nilai')) }

export const useUbahNilai = defineStore('ubahNilai', {
  state: () => ({ data: null, menunggu: 0, ringkas: null }),
  actions: {
    async muat(status = null, assignment = null) {
      if (MODE_DEMO) {
        const k = kelolaDemo()
        const daftar = demo.daftar.filter((d) => (!status || d.status === status) && (!assignment || d.assignment_id === assignment) && (k || d.pengaju === 'Ust. Hasan Basri, Lc.'))
          .map((d) => ({ ...d, boleh_putus: k && d.status === 'menunggu', boleh_batal: !k && d.status === 'menunggu' }))
        this.data = { kelola: k, panitia: k, menunggu: daftar.filter((d) => d.status === 'menunggu').length, daftar }
      } else this.data = await rpc('daftar_ubah_nilai', { p_status: status, p_assignment: assignment, p_ta: null })
      this.menunggu = this.data.menunggu || 0
      return this.data
    },
    /** p: { jenis:'mapel', assignment_id, semester, student_id, nilai?, keterampilan?, sikap?, deskripsi?, alasan } | { jenis:'utas', utas_result_id, tajwid?, itqan?, alasan } */
    async ajukan(p, info = {}) {
      if (MODE_DEMO) {
        if (!p.alasan || p.alasan.trim().length < 5) throw new Error('Alasan perubahan wajib diisi (minimal 5 huruf).')
        const perubahan = {}
        for (const k of ['nilai', 'keterampilan', 'sikap', 'deskripsi', 'tajwid', 'itqan']) if (k in p) perubahan[k] = { lama: info.lama?.[k] ?? null, baru: p[k] === '' ? null : p[k] }
        if (!Object.keys(perubahan).length) throw new Error('Tidak ada nilai yang berubah.')
        demo.daftar.unshift({ id: 'gcr' + ++demo.n, jenis: p.jenis || 'mapel', semester: p.semester || 1, status: 'menunggu', perubahan, alasan: p.alasan, diajukan_pada: new Date().toISOString(),
          pengaju: 'Ust. Hasan Basri, Lc.', diputus_pada: null, pemutus: null, catatan_putusan: null, nis: info.nis, nama: info.nama, jenis_kelamin: info.jenis_kelamin,
          assignment_id: p.assignment_id || null, utas_result_id: p.utas_result_id || null, kelas: info.kelas, mapel: info.mapel || 'UTAS (tahfizh)', mode: null })
        return
      }
      return rpc('ajukan_ubah_nilai', { p })
    },
    async batal(id) {
      if (MODE_DEMO) { const d = demo.daftar.find((x) => x.id === id); if (d) d.status = 'dibatalkan'; return }
      return rpc('batal_ubah_nilai', { p_id: id })
    },
    async putuskan(id, setuju, catatan = '') {
      if (MODE_DEMO) {
        if (!setuju && catatan.trim().length < 3) throw new Error('Tuliskan alasan penolakan.')
        const d = demo.daftar.find((x) => x.id === id); Object.assign(d, { status: setuju ? 'disetujui' : 'ditolak', diputus_pada: new Date().toISOString(), pemutus: useSesi().pengguna?.nama_lengkap, catatan_putusan: catatan || null }); return
      }
      return rpc('putuskan_ubah_nilai', { p_id: id, p_setuju: setuju, p_catatan: catatan || null })
    },
    async rekap(semester) {
      if (MODE_DEMO) return rekapDemo(semester)
      return rpc('rekap_penilaian', { p_semester: semester || null, p_ta: null })
    },
    async muatRingkas() {
      if (MODE_DEMO) {
        const s = useSesi()
        this.ringkas = { semester: 1, periode: [{ jenis: 'sma', status: 'dibuka', batas_isi: '2026-12-05' }, { jenis: 'wustha', status: 'dibuka', batas_isi: '2026-12-05' }, { jenis: 'tahfizh', status: 'disiapkan', batas_isi: null }],
          tugas: 4, tugas_lengkap: 1, nilai_kurang: 37, wali: s.peran === 'pegawai' ? [{ group_id: 'g-7a', nama: '7A', santri: 4, catatan: 1 }] : [], utas_draf: s.peran === 'pegawai' ? 3 : 0,
          pd_kurang: 0, permintaan_saya: s.peran === 'pegawai' ? 1 : 0, permintaan_menunggu: kelolaDemo() ? demo.daftar.filter((d) => d.status === 'menunggu').length : null, rekap: s.peran !== 'pegawai' }
        return this.ringkas
      }
      this.ringkas = await rpc('ringkas_penilaian_saya')
      return this.ringkas
    },
  },
})

function rekapDemo(smt) {
  const k = (nama, jenjang, tingkat, santri, tugas, lengkap, terisi, target, catatan, extra = {}) => ({ group_id: 'g-' + nama, nama, jenjang, tingkat, wali: 'Ust. Hasan Basri, Lc.', santri, tugas,
    tugas_lengkap: lengkap, nilai_terisi: terisi, nilai_target: target, sikap: Math.round(terisi * 0.6), catatan, kokurikuler: jenjang === 'sma' ? Math.round(catatan * 0.8) : 0, pd: Math.max(0, santri - 1),
    keputusan: smt === 2 ? 0 : null, utas_final: Math.round(santri / 2), ...extra })
  return { ta: 'ta1', semester: smt || 1, jenis: ['sma', 'wustha', 'tahfizh'],
    periode: [{ jenis: 'sma', status: 'dibuka', status_efektif: 'dibuka', batas_isi: '2026-12-05', tanggal_rapor: '2026-12-19' },
      { jenis: 'tahfizh', status: 'disiapkan', status_efektif: 'disiapkan', batas_isi: null, tanggal_rapor: '2026-12-19' },
      { jenis: 'wustha', status: 'dibuka', status_efektif: 'ditutup', batas_isi: '2026-10-10', tanggal_rapor: '2026-12-19' }],
    permintaan_menunggu: demo.daftar.filter((d) => d.status === 'menunggu').length,
    kelas: [k('7A', 'wustha', 7, 4, 12, 9, 41, 48, 4), k('7B', 'wustha', 7, 3, 12, 12, 36, 36, 3), k('8A', 'wustha', 8, 5, 12, 6, 44, 60, 2), k('9A', 'wustha', 9, 2, 12, 3, 12, 24, 0),
      k('10A', 'sma', 10, 5, 15, 8, 58, 75, 5), k('11A', 'sma', 11, 4, 15, 15, 60, 60, 4), k('12A', 'sma', 12, 3, 15, 2, 15, 45, 1)],
    guru: [{ employee_id: 'p6', nama: 'Ust. Yusuf Maulana, S.Pd.', tugas: 6, terisi: 14, target: 30, kurang: 16, belum: [{ assignment_id: 'a1', mapel: 'Matematika', kelas: '12A', terisi: 0, target: 3 }, { assignment_id: 'a2', mapel: 'Fisika', kelas: '10A', terisi: 2, target: 5 }] },
      { employee_id: 'p2', nama: 'Ustzh. Nurul Aini, S.Pd.', tugas: 5, terisi: 20, target: 28, kurang: 8, belum: [{ assignment_id: 'a3', mapel: 'Bahasa Indonesia', kelas: '9A', terisi: 0, target: 2 }] },
      { employee_id: 'p1', nama: 'Ust. Hasan Basri, Lc.', tugas: 4, terisi: 18, target: 18, kurang: 0, belum: null }],
    utas: { peserta: 26, dinilai: 19, final: 14, remedial: 3 },
    ekskul: [{ group_id: 'g-epn', nama: 'Panahan', pembina: 'Ust. Yusuf Maulana, S.Pd.', santri: 8, terisi: 8 }, { group_id: 'g-epr', nama: 'Pramuka', pembina: null, santri: 6, terisi: 0 }] }
}
