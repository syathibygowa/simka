// SIMKA PRO | src/stores/klinik.js | v1.1 | Fase 6 – Tahap 3 Jurnal musyrif dan klinik lanjutan | 06/10/2026
// Klinik: hak pengguna, ketentuan (jam layanan, batas waktu rujukan), petugas klinik putra/putri, daftar kasus
// (antrean, dirawat, riwayat, rujukan saya), rincian kasus, rujukan, pemeriksaan, pembatalan, dan penyelesaian.
// Penulisan hanya lewat fungsi SQL; catatan pemeriksaan rahasia disaring server.
// v1.1: surat keterangan sakit (buat, daftar, data cetak) dan kontak wali untuk tombol WA.
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { pesanGalat } from './lembaga'
import { useSesi } from './sesi'
import { useSantri } from './santri'
import { dataKlinikDemo } from '@/lib/demoKlinik'
import { PEGAWAI_DEMO } from '@/lib/demo'
import { TINDAK_LANJUT, klinikSantri } from '@/lib/klinik'
import { hariIniISO } from '@/lib/tanggal'

const rpc = async (nama, arg) => { const { data, error } = await supabase.rpc(nama, arg); if (error) throw new Error(pesanGalat(error)); return data }
const HAK_KOSONG = { atur: false, pimpinan: false, petugas: [], rujuk: false, lihat: false }
const tglWITA = (iso) => new Date(new Date(iso).getTime() + 8 * 3600000).toISOString().slice(0, 10)

export const useKlinik = defineStore('klinik', {
  state: () => ({ hak: { ...HAK_KOSONG }, hakDimuat: false, pengaturan: null, petugas: [], saluran: null }),
  getters: {
    /** Pengguna melihat catatan pemeriksaan (petugas, pengelola, pimpinan). */
    tenagaKlinik: (s) => s.hak.atur || s.hak.pimpinan || s.hak.petugas.length > 0,
    bolehPeriksa: (s) => (klinik) => s.hak.atur || s.hak.petugas.includes(klinik),
  },
  actions: {
    async muatHak() {
      if (MODE_DEMO) {
        const sesi = useSesi(); const p = sesi.peran
        const atur = p === 'superadmin' || (p === 'admin' && sesi.izinAdmin.includes('kelola_klinik'))
        this.hak = { ...HAK_KOSONG, atur, rujuk: true, lihat: true }
      } else this.hak = { ...HAK_KOSONG, ...((await rpc('hak_klinik')) || {}) }
      this.hakDimuat = true
      return this.hak
    },
    async demo() { const san = useSantri(); await san.muat(); return dataKlinikDemo(san.daftar) },

    // ---------- Ketentuan dan petugas ----------
    async muatPengaturan() {
      if (MODE_DEMO) { const d = await this.demo(); this.pengaturan = JSON.parse(JSON.stringify(d.pengaturan)); this.petugas = d.petugas.map((x) => ({ ...x })); return }
      const [p, t] = await Promise.all([rpc('pengaturan_klinik'), rpc('daftar_petugas_klinik')])
      this.pengaturan = p; this.petugas = t || []
    },
    async simpanPengaturan(isi) {
      if (MODE_DEMO) { const d = await this.demo(); Object.assign(d.pengaturan, JSON.parse(JSON.stringify(isi))); d.pengaturan.jam_layanan?.sort((a, b) => a.mulai.localeCompare(b.mulai)); return this.muatPengaturan() }
      this.pengaturan = await rpc('simpan_pengaturan_klinik', { p: isi })
    },
    async calonPetugas() {
      if (MODE_DEMO) return PEGAWAI_DEMO.filter((p) => p.status_akun === 'aktif').map((p) => ({ id: p.id, nama: p.nama_lengkap, niy: p.niy, jenis_kelamin: p.jenis_kelamin, medis: (p.jabatan_fungsional || []).includes('Petugas kesehatan') }))
      return (await rpc('calon_petugas_klinik')) || []
    },
    async simpanPetugas(employeeId, klinik, aktif = true, catatan = '') {
      if (MODE_DEMO) {
        const d = await this.demo(); const ada = d.petugas.find((x) => x.employee_id === employeeId && x.klinik === klinik)
        const p = PEGAWAI_DEMO.find((x) => x.id === employeeId)
        if (ada) Object.assign(ada, { aktif, catatan })
        else d.petugas.push({ id: 'kp' + Date.now(), employee_id: employeeId, nama: p?.nama_lengkap, niy: p?.niy, jenis_kelamin: p?.jenis_kelamin, no_hp: p?.no_hp, klinik, aktif, catatan, punya_akun: true })
        return this.muatPengaturan()
      }
      await rpc('simpan_petugas_klinik', { p_employee: employeeId, p_klinik: klinik, p_aktif: aktif, p_catatan: catatan || null })
      await this.muatPengaturan()
    },
    async hapusPetugas(id) {
      if (MODE_DEMO) { const d = await this.demo(); d.petugas = d.petugas.filter((x) => x.id !== id); return this.muatPengaturan() }
      await rpc('hapus_petugas_klinik', { p_id: id }); await this.muatPengaturan()
    },

    // ---------- Daftar dan rincian ----------
    /** cakupan: antrean | dirawat | riwayat | rujukan_saya */
    async daftar(cakupan, mulai = null, selesai = null, klinik = null) {
      if (!MODE_DEMO) return (await rpc('daftar_klinik', { p_cakupan: cakupan, p_mulai: mulai, p_selesai: selesai, p_klinik: klinik })) || []
      const d = await this.demo(); const san = useSantri(); const sesi = useSesi()
      const terlihat = new Set(san.daftar.map((s) => s.id)); const detail = this.tenagaKlinik || sesi.peran !== 'pegawai'
      const m = mulai || hariIniISO().slice(0, 8) + '01'; const s2 = selesai || hariIniISO()
      return d.kasus.filter((k) => !klinik || k.klinik === klinik).map((k) => {
        const s = san.daftar.find((x) => x.id === k.student_id) || {}; const r = d.rujukan.filter((x) => x.case_id === k.id)
        const v = d.periksa.filter((x) => x.case_id === k.id).at(-1)
        const kel = (j) => (s.kelompok || []).filter((g) => g.jenis === j).map((g) => g.nama).join(', ') || null
        const lewat = k.status === 'menunggu' && new Date(r[0]?.batas_waktu) < new Date()
        return { ...k, nama: s.nama_lengkap, nis: s.nis, jenis_kelamin: s.jenis_kelamin, tingkat: s.tingkat, jenjang: s.jenjang, kelas: kel('kelas'), kamar: kel('kamar'),
          batas_waktu: r[0]?.batas_waktu, waktu_periksa: r[0]?.waktu_periksa, perujuk: r[0]?.perujuk, jumlah_rujukan: r.length, lewat_batas: lewat,
          detail, boleh_periksa: detail && sesi.peran !== 'pegawai', boleh_batal: k.status === 'menunggu' && (detail || r.some((x) => x.dirujuk_oleh === 'd-pg')),
          pemeriksaan_terakhir: detail && v ? { waktu: v.waktu, diagnosis: v.diagnosis, tindakan: v.tindakan, obat: v.obat, petugas: v.petugas, rujuk_ke: v.rujuk_ke } : null,
          urut: lewat ? '0' : k.status === 'menunggu' ? '1' : '2', _r: r }
      }).filter((k) => {
        const tgl = tglWITA(k.dibuka_pada)
        if (cakupan === 'antrean') return detail && k.status === 'menunggu'
        if (cakupan === 'dirawat') return detail && k.status === 'ditangani'
        if (cakupan === 'riwayat') return detail && tgl >= m && tgl <= s2
        return terlihat.has(k.student_id) && (['menunggu', 'ditangani'].includes(k.status) || (tgl >= m && tgl <= s2))
          && (sesi.peran !== 'pegawai' || k._r.some((x) => x.dirujuk_oleh === 'd-pg') || terlihat.has(k.student_id))
      }).sort((a, b) => a.urut.localeCompare(b.urut) || b.dibuka_pada.localeCompare(a.dibuka_pada))
    },
    async detail(id) {
      if (!MODE_DEMO) return rpc('detail_kasus_klinik', { p_case: id })
      const d = await this.demo(); const k = d.kasus.find((x) => x.id === id); const s = useSantri().daftar.find((x) => x.id === k.student_id) || {}
      const det = this.tenagaKlinik || useSesi().peran !== 'pegawai'
      const kel = (j) => (s.kelompok || []).filter((g) => g.jenis === j).map((g) => g.nama).join(', ') || null
      return {
        kasus: { ...k, nama: s.nama_lengkap, nis: s.nis, jenis_kelamin: s.jenis_kelamin, kelas: kel('kelas'), kamar: kel('kamar'), halaqah: kel('halaqah'), tanggal_lahir: s.tanggal_lahir },
        detail: det, boleh_periksa: det && useSesi().peran !== 'pegawai',
        rujukan: d.rujukan.filter((x) => x.case_id === id),
        pemeriksaan: det ? d.periksa.filter((x) => x.case_id === id) : null,
        jejak: det ? d.jejak.filter((x) => x.case_id === id) : null,
        riwayat_santri: d.kasus.filter((x) => x.student_id === k.student_id && x.id !== id),
      }
    },
    async cariSantri(q = '') {
      if (!MODE_DEMO) return (await rpc('cari_santri_klinik', { p_cari: q })) || []
      const d = await this.demo(); const t = q.toLowerCase().trim()
      return useSantri().daftar.filter((s) => s.status === 'aktif' && (!t || `${s.nama_lengkap} ${s.nis}`.toLowerCase().includes(t))).slice(0, 40).map((s) => ({
        id: s.id, nama: s.nama_lengkap, nis: s.nis, jenis_kelamin: s.jenis_kelamin,
        kelas: (s.kelompok || []).filter((g) => g.jenis === 'kelas').map((g) => g.nama).join(', ') || null,
        kamar: (s.kelompok || []).filter((g) => g.jenis === 'kamar').map((g) => g.nama).join(', ') || null,
        kasus_terbuka: d.kasus.find((k) => k.student_id === s.id && ['menunggu', 'ditangani'].includes(k.status))?.status || null,
      }))
    },

    // ---------- Tindakan ----------
    async rujuk(santriId, keluhan, kapan = 'hari_ini', catatan = '') {
      if (!MODE_DEMO) return rpc('buat_rujukan', { p_santri: santriId, p_keluhan: keluhan, p_kapan: kapan, p_catatan: catatan || null })
      const d = await this.demo(); const s = useSantri().daftar.find((x) => x.id === santriId); const nama = useSesi().pengguna?.nama_lengkap
      const pada = new Date().toISOString(); const batas = new Date(Date.now() + (kapan === 'besok' ? 20 : 2) * 3600000).toISOString()
      let k = d.kasus.find((x) => x.student_id === santriId && ['menunggu', 'ditangani'].includes(x.status)); const baru = !k
      if (!k) { k = { id: 'kk' + Date.now(), student_id: santriId, klinik: klinikSantri(s.jenis_kelamin), status: 'menunggu', tindak_lanjut: null, keluhan, sumber: 'pengasuh', dibuka_pada: pada }; d.kasus.unshift(k) }
      d.rujukan.push({ case_id: k.id, student_id: santriId, sumber: 'pengasuh', keluhan, waktu_periksa: kapan, batas_waktu: batas, dirujuk_pada: pada, perujuk: nama, dirujuk_oleh: useSesi().pengguna?.id })
      d.jejak.push({ case_id: k.id, jenis: 'rujukan', isi: `Dirujuk oleh ${nama}: ${keluhan}`, pada, oleh: nama })
      return { case_id: k.id, baru, klinik: k.klinik, batas_waktu: batas }
    },
    async periksa(isi) {
      if (!MODE_DEMO) return rpc('simpan_pemeriksaan', { p: isi })
      const d = await this.demo(); const pada = new Date().toISOString(); const nama = useSesi().pengguna?.nama_lengkap
      let k = isi.case_id && d.kasus.find((x) => x.id === isi.case_id)
      if (!k) {
        k = d.kasus.find((x) => x.student_id === isi.student_id && ['menunggu', 'ditangani'].includes(x.status))
        if (!k) { const s = useSantri().daftar.find((x) => x.id === isi.student_id); k = { id: 'kk' + Date.now(), student_id: isi.student_id, klinik: klinikSantri(s.jenis_kelamin), status: 'menunggu', keluhan: isi.keluhan || 'Datang ke klinik', sumber: 'datang_sendiri', dibuka_pada: pada }; d.kasus.unshift(k); d.rujukan.push({ case_id: k.id, sumber: 'datang_sendiri', keluhan: k.keluhan, waktu_periksa: 'hari_ini', batas_waktu: pada, dirujuk_pada: pada, perujuk: nama }) }
      }
      const jenis = d.periksa.some((x) => x.case_id === k.id) ? 'kontrol' : 'pemeriksaan'
      d.periksa.push({ ...isi, id: 'kv' + Date.now(), case_id: k.id, student_id: k.student_id, jenis, waktu: pada, petugas: nama })
      const tl = TINDAK_LANJUT[isi.tindak_lanjut].n
      d.jejak.push({ case_id: k.id, jenis: 'pemeriksaan', isi: `${jenis === 'kontrol' ? 'Kontrol' : 'Pemeriksaan'}: ${tl}`, pada, oleh: nama })
      if (isi.tindak_lanjut === 'kembali') Object.assign(k, { status: 'selesai', hasil: 'kembali', tindak_lanjut: 'kembali', kontrol_pada: null, selesai_pada: pada })
      else Object.assign(k, { status: 'ditangani', tindak_lanjut: isi.tindak_lanjut, kontrol_pada: isi.kontrol_pada || null, sakit_mulai: k.sakit_mulai || hariIniISO() })
      return { case_id: k.id, status: k.status }
    },
    async batalkan(id, alasan) {
      if (!MODE_DEMO) return rpc('batalkan_kasus_klinik', { p_case: id, p_alasan: alasan })
      const d = await this.demo(); const k = d.kasus.find((x) => x.id === id)
      Object.assign(k, { status: 'batal', hasil: 'batal', selesai_pada: new Date().toISOString(), catatan_selesai: alasan })
      d.jejak.push({ case_id: id, jenis: 'batal', isi: 'Dibatalkan: ' + alasan, pada: new Date().toISOString(), oleh: useSesi().pengguna?.nama_lengkap })
    },
    async selesaikan(id, catatan) {
      if (!MODE_DEMO) return rpc('selesaikan_kasus_klinik', { p_case: id, p_catatan: catatan || null })
      const d = await this.demo(); const k = d.kasus.find((x) => x.id === id)
      Object.assign(k, { status: 'selesai', hasil: 'sembuh', kontrol_pada: null, selesai_pada: new Date().toISOString(), catatan_selesai: catatan })
      d.jejak.push({ case_id: id, jenis: 'selesai', isi: 'Dinyatakan sembuh' + (catatan ? ': ' + catatan : ''), pada: new Date().toISOString(), oleh: useSesi().pengguna?.nama_lengkap })
    },

    // ---------- Surat keterangan sakit dan kontak wali ----------
    async daftarSurat(caseId) {
      if (!MODE_DEMO) return (await rpc('daftar_surat_sakit', { p_case: caseId })) || []
      const d = await this.demo(); return (d.surat || []).filter((x) => x.case_id === caseId)
    },
    async surat(id) {
      if (!MODE_DEMO) return rpc('surat_sakit', { p_id: id })
      const d = await this.demo(); return (d.surat || []).find((x) => x.id === id)
    },
    async buatSurat(isi) {
      if (!MODE_DEMO) return rpc('buat_surat_sakit', { p: isi })
      const d = await this.demo(); d.surat ||= []
      const k = d.kasus.find((x) => x.id === isi.case_id); const s = useSantri().daftar.find((x) => x.id === k.student_id) || {}
      const v = d.periksa.filter((x) => x.case_id === k.id)
      const kel = (j) => (s.kelompok || []).filter((g) => g.jenis === j).map((g) => g.nama).join(', ') || null
      const x = { id: 'ks' + Date.now(), case_id: k.id, nomor: `SKS.${String(d.surat.length + 1).padStart(3, '0')}/PPTQ-IAS/X/2026`, kode_validasi: 'K7QM-2X4P', tanggal: hariIniISO(),
        istirahat_mulai: isi.istirahat_mulai, istirahat_sampai: isi.istirahat_sampai, keperluan: isi.keperluan || null, diagnosis: isi.cantumkan_diagnosis ? isi.diagnosis || null : null,
        nama: s.nama_lengkap, nis: s.nis, jenis_kelamin: s.jenis_kelamin, tempat_lahir: s.tempat_lahir, tanggal_lahir: s.tanggal_lahir, jenjang: s.jenjang, tingkat: s.tingkat,
        kelas: kel('kelas'), kamar: kel('kamar'), keluhan: k.keluhan, klinik: k.klinik, tindak_lanjut: k.tindak_lanjut, diperiksa_pada: v[0]?.waktu || new Date().toISOString(),
        petugas: useSesi().pengguna?.nama_lengkap, petugas_niy: useSesi().pengguna?.niy || null, created_at: new Date().toISOString() }
      d.surat.unshift(x); return x
    },
    async kontakWali(caseId) {
      if (!MODE_DEMO) return rpc('kontak_wali_klinik', { p_case: caseId })
      return { nama: 'Bapak Ahmad', no_hp: '081234567890', hubungan: 'ayah' }
    },

    // ---------- Pembaruan langsung ----------
    dengarkan(fn) {
      if (MODE_DEMO || this.saluran) return
      this.saluran = supabase.channel('klinik-kasus').on('postgres_changes', { event: '*', schema: 'public', table: 'clinic_cases' }, () => fn()).subscribe()
    },
    berhenti() { if (this.saluran) { supabase.removeChannel(this.saluran); this.saluran = null } },
  },
})
