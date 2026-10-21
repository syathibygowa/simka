// SIMKA PRO | src/stores/sesi.js | v1.35 | 14.19.0: sesi tetap masuk saat aplikasi dibuka ulang meski koneksi tersendat | 21/10/2026
// Sesi pengguna: masuk/keluar, data pegawai, peran sistem, dan hak akses fitur.
// v1.35: aplikasi tidak lagi meminta masuk ulang setiap dibuka. Sebelumnya galat sementara saat memuat data pegawai (sinyal lemah,
//        token sedang diperbarui) langsung memutus sesi (signOut) atau menampilkan halaman Masuk. Kini: data pegawai dicoba ulang,
//        sesi hanya diputus bila akun benar-benar tidak punya data pegawai; bila koneksi gagal, sesi tersimpan tetap ada
//        (sesiTertunda) dan dimuat ulang otomatis saat koneksi kembali, saat token diperbarui, atau lewat tombol Coba lagi.
import { muatTemplatWA } from '@/lib/wa'
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO, panggilFungsi } from '@/lib/supabase'
import { aturSelisihServer } from '@/lib/tanggal'
import { PENGGUNA_DEMO } from '@/lib/demo'
import { KATALOG_FITUR, PETA_IZIN } from '@/lib/hakAkses'

const TUGAS_DEMO = {
  pegawai: { pimpinan: false, struktural: [], fungsional: ['MUHAFFIZH', 'WALI_KELAS', 'GURU'], kelompok: ['kelas', 'halaqah', 'kamar'], mengajar: true, klinik: [], gerbang: false, penguji: true, pantauan: false, luas: {} },
}
const simpan = (k, v) => { try { v == null ? localStorage.removeItem(k) : localStorage.setItem(k, v) } catch { /* penyimpanan peramban tidak tersedia */ } }
const baca = (k) => { try { return localStorage.getItem(k) } catch { return null } }
const jeda = (ms) => new Promise((ok) => setTimeout(ok, ms))
// Sesi Supabase tersimpan di perangkat (kunci storageKey di lib/supabase.js) walau belum dapat diperbarui karena koneksi
const adaSesiTersimpan = () => { try { return !!JSON.parse(localStorage.getItem('simka.sesi') || 'null')?.refresh_token } catch { return false } }
let pendengarDipasang = false

export const useSesi = defineStore('sesi', {
  state: () => ({ pengguna: null, fitur: {}, izinAdmin: [], siap: false, sesiTertunda: false, galatSesi: '', wajibGantiSandi: false, punyaShift: false, fotoUrl: '', kelompokSaya: [], tugas: {}, persuratan: false, gaji: false, gajiLihat: false, keuangan: false, penilaian: false, pengujiUtas: false, beban: { saya: false, atur: false, rekap: false } }),
  getters: {
    masuk: (s) => !!s.pengguna,
    peran: (s) => s.pengguna?.peran ?? 'pegawai',
    isSuperadmin: (s) => s.pengguna?.peran === 'superadmin',
    isAdmin: (s) => ['admin', 'superadmin'].includes(s.pengguna?.peran),
    /** Ciri pengguna untuk menyaring menu (lib/menu.js). */
    ciriMenu: (s) => ({ peran: s.pengguna?.peran ?? 'pegawai', penilaian: s.penilaian, pengujiUtas: s.pengujiUtas, gaji: s.gaji, gajiLihat: s.gajiLihat, keuangan: s.keuangan, persuratan: s.persuratan, struktural: !!s.pengguna?.jabatan_struktural, shift: s.punyaShift, izin: s.izinAdmin, fitur: s.fitur, kelompok: s.kelompokSaya.length > 0, jenisKelompok: [...new Set(s.kelompokSaya.map((k) => k.jenis))], mengajar: !!s.tugas?.mengajar, pimpinan: !!s.tugas?.pimpinan, penguji: !!s.tugas?.penguji, beban: s.beban, luas: s.tugas?.luas || {} }),
    /** Pimpinan (Kepala Bidang, Direktur, Wadir, Yayasan, termasuk Plt): beranda berstatistik dan fungsi kontrol. */
    pimpinanTinggi: (s) => !!s.tugas?.pimpinan,
    namaPendek: (s) => (s.pengguna?.nama_lengkap ?? '').replace(/^(Ust\.|Ustzh\.)\s*/, '').split(',')[0],
    inisial: (s) => (s.pengguna?.nama_lengkap ?? '?').replace(/^(Ust\.|Ustzh\.)\s*/, '').split(/\s+/).slice(0, 2).map((k) => k[0]).join('').toUpperCase(),
  },
  actions: {
    async mulai() {
      if (MODE_DEMO) {
        const p = baca('simka.demo.peran')
        if (p && PENGGUNA_DEMO[p]) this.masukDemo(p)
        this.siap = true
        return
      }
      // Jam server tidak ditunggu (bila koneksi lambat, jam peranti dipakai sementara)
      supabase.rpc('waktu_server').then(({ data }) => { if (data?.iso) aturSelisihServer(data.iso) }, () => {})
      // Layar pembuka paling lama 8 detik. Bila koneksi lambat (token sedang diperbarui atau data akun belum termuat), pemuatan
      // dilanjutkan di latar dan halaman Masuk menampilkan "Anda masih masuk"; begitu selesai, aplikasi terbuka sendiri.
      const LAMBAT = 'lambat'; const tenggat = jeda(8000).then(() => LAMBAT)
      const muat = (async () => {
        const { data: { session } } = await supabase.auth.getSession()
        if (!session) return adaSesiTersimpan() ? 'tertunda' : 'keluar'
        await this.muatPegawai(session.user)
        return 'ok'
      })().catch((e) => { this.tandaiTertunda(e); return 'galat' })
      const hasil = await Promise.race([muat, tenggat])
      if (hasil === 'tertunda') this.tandaiTertunda(new Error('Koneksi ke server belum tersedia.'))
      if (hasil === LAMBAT && !this.pengguna && adaSesiTersimpan()) { this.sesiTertunda = true; this.galatSesi = 'Koneksi lambat, data akun masih dimuat.' }
      this.pasangPendengar()
      this.siap = true
    },

    /** Sesi tersimpan tetapi data pegawai belum termuat karena koneksi/server; halaman Masuk menampilkan tombol Coba lagi. */
    tandaiTertunda(e) {
      if (e?.tanpaPegawai) return
      this.sesiTertunda = !this.pengguna && adaSesiTersimpan(); this.galatSesi = e?.message || ''
    },

    /** Coba lagi memuat sesi tersimpan (tombol di halaman Masuk, saat online, atau saat token diperbarui). */
    async cobaLagi() {
      if (MODE_DEMO || this.pengguna) return !!this.pengguna
      try {
        let { data: { session } } = await supabase.auth.getSession()
        if (!session && adaSesiTersimpan()) ({ data: { session } } = await supabase.auth.refreshSession())
        if (!session) { this.sesiTertunda = adaSesiTersimpan(); return false }
        await this.muatPegawai(session.user)
        this.sesiTertunda = false; this.galatSesi = ''
        return true
      } catch (e) { this.tandaiTertunda(e); return false }
    },

    pasangPendengar() {
      if (pendengarDipasang || MODE_DEMO) return
      pendengarDipasang = true
      supabase.auth.onAuthStateChange((ev, s) => {
        if (ev === 'SIGNED_OUT') { this.$reset(); this.siap = true }
        else if (['TOKEN_REFRESHED', 'SIGNED_IN'].includes(ev) && s && !this.pengguna && this.sesiTertunda) setTimeout(() => this.cobaLagi(), 0)
      })
      window.addEventListener('online', () => { if (this.sesiTertunda) this.cobaLagi() })
      document.addEventListener('visibilitychange', () => { if (document.visibilityState === 'visible' && this.sesiTertunda) this.cobaLagi() })
    },

    async muatPegawai(userAwal = null) {
      // Identitas akun dari sesi tersimpan (tanpa panggilan jaringan); getUser hanya bila sesi belum ada
      let user = userAwal
      if (!user) { const { data: { session } = {} } = await supabase.auth.getSession(); user = session?.user || null }
      if (!user) { const { data } = await supabase.auth.getUser(); user = data?.user || null }
      if (!user) return
      // Galat sementara (sinyal lemah, server sibuk, token sedang diperbarui): dicoba sekali lagi, sesi TIDAK diputus.
      // (Pustaka Supabase sendiri sudah mengulang galat 503/520 dengan jeda, jadi pengulangan di sini cukup satu kali.)
      let data = null; let error = null
      for (let i = 0; i < 2; i++) {
        ({ data, error } = await supabase.from('v_pegawai').select('*').eq('user_id', user.id).maybeSingle())
        if (!error) break
        if (i === 0) await jeda(800)
      }
      if (error) { const e = new Error('Data akun belum dapat dimuat karena koneksi atau server. Coba lagi sebentar.'); e.sementara = true; throw e }
      // Hanya bila akun benar-benar tidak punya data pegawai, sesi diputus
      if (!data) { await supabase.auth.signOut(); const e = new Error('Data pegawai untuk akun ini tidak ditemukan.'); e.tanpaPegawai = true; throw e }
      this.sesiTertunda = false; this.galatSesi = ''
      const jabatan = [data.jabatan_struktural, ...(data.jabatan_fungsional || [])].filter(Boolean).join(', ')
        || (data.peran === 'superadmin' ? 'Pengelola sistem' : data.peran === 'admin' ? 'Admin' : 'Pegawai')
      this.pengguna = { ...data, jabatan }
      this.wajibGantiSandi = data.wajib_ganti_sandi
      this.muatFoto()
      const { data: fitur } = await supabase.rpc('fitur_saya')
      this.fitur = fitur || {}
      // Izin admin efektif (dicentang superadmin atau didapat dari hak fitur di Hak Akses) untuk menampilkan menu/tombol;
      // keamanan tetap diperiksa server. Sejak 14.0.0 dimuat untuk semua pegawai.
      try { const { data: izin } = await supabase.rpc('izin_admin_saya'); this.izinAdmin = izin || [] } catch { this.izinAdmin = [] }
      // Template WA dibaca semua pegawai (pengasuh mengirim rekap ke wali dengan template yang diatur superadmin)
      muatTemplatWA()
      // Pegawai yang memegang pola shift melihat menu Jadwal Shift
      try {
        const { data: sh } = await supabase.from('employee_schedules').select('id, task_patterns!inner(jenis)')
          .eq('employee_id', data.id).eq('aktif', true).eq('task_patterns.jenis', 'shift').limit(1)
        this.punyaShift = !!sh?.length
      } catch { this.punyaShift = false }
      // Tupoksi akun: pimpinan atau bukan, jabatan fungsional, kelompok asuhan, petugas klinik/gerbang, cakupan luas per fitur
      try { const { data: tg } = await supabase.rpc('profil_tugas_saya'); this.tugas = tg || {} } catch { this.tugas = {} }
      // Persuratan: menu tampil bagi Tata Usaha, pimpinan penerima surat, dan penerima disposisi
      try { const { data: hp } = await supabase.rpc('hak_persuratan'); this.persuratan = !!hp?.tampil } catch { this.persuratan = false }
      // Gaji: pengelola/pembaca gaji, atau semua pegawai bila slip ditampilkan di akun pegawai (Ketentuan gaji)
      try { const { data: hg } = await supabase.rpc('hak_gaji'); this.gaji = !!hg?.tampil; this.gajiLihat = !!hg?.lihat } catch { this.gaji = false; this.gajiLihat = false }
      // Keuangan santri: hanya superadmin dan pegawai yang ditunjuk superadmin
      try { const { data: hk } = await supabase.rpc('hak_keuangan'); this.keuangan = !!hk?.lihat } catch { this.keuangan = false }
      // Penilaian: pengatur penilaian (per jenis rapor), pengelola nilai, dan pimpinan bidang SMA/Wustha/Tahfizh
      try { const { data: hn } = await supabase.rpc('hak_penilaian'); this.penilaian = !!hn?.menu } catch { this.penilaian = false }
      // Penguji UTAS (bukan muhaffizh pun) melihat menu Tahfizh → Ujian → UTAS
      try { const { data: hu } = await supabase.rpc('hak_utas'); this.pengujiUtas = !!hu?.penguji } catch { this.pengujiUtas = false }
      // Beban kerja: tampil di akun pegawai bila diizinkan admin; rekap untuk admin, pengatur beban kerja, dan pimpinan
      try { const { data: hb } = await supabase.rpc('hak_beban'); this.beban = { saya: !!hb?.saya, atur: !!hb?.atur, rekap: !!hb?.rekap } } catch { this.beban = { saya: false, atur: false, rekap: false } }
      // Kelompok santri yang sedang diasuh (wali kelas, musyrif, muhaffizh, pembina)
      try {
        const { data: kel } = await supabase.from('v_kelompok').select('id, jenis, nama').eq('asuhan_saya', true)
        this.kelompokSaya = kel || []
      } catch { this.kelompokSaya = [] }
    },

    /** Masuk dengan username + kata sandi (melalui Edge Function "masuk"). */
    async masukDengan(username, sandi) {
      if (MODE_DEMO) throw new Error('Mode demo: pilih peran di bawah untuk mencoba tampilan.')
      const r = await panggilFungsi('masuk', { username, sandi })
      if (r.status !== 'aktif') throw new Error(r.pesan || r.galat || 'Tidak dapat masuk.')
      await supabase.auth.setSession(r.session)
      await this.muatPegawai()
      return r
    },

    masukDemo(peran) {
      // Hak fitur demo: bawaan Semua pegawai, ditambah hak jabatan muhaffizh/wali kelas untuk akun pegawai
      const fitur = Object.fromEntries(KATALOG_FITUR.filter((f) => f.bawaan?.semua).map((f) => [f.kode, f.bawaan.semua]))
      if (peran === 'pegawai') Object.assign(fitur, { absensi_kelas: 2, tahfizh: 2, nilai: 2, jadwal_mengajar: 2 })
      this.fitur = fitur
      this.pengguna = { ...PENGGUNA_DEMO[peran] }; this.izinAdmin = peran === 'admin' ? ['verval_akun', 'kelola_pengumuman', 'kelola_pegawai', 'verval_presensi', 'atur_presensi', 'kalender', 'lihat_pengajuan', 'atur_pengajuan', 'verval_jurnal', 'atur_jurnal', 'kelola_berkas', 'cetak_kartu', 'kelola_agenda', 'kelola_kelompok', 'atur_beban_kerja', 'kelola_santri', 'kelompok_santri', 'absensi_atas_nama', 'atur_jadwal', 'atur_tahfizh', 'validasi_tahfizh', 'kelola_klinik', 'atur_penilaian', 'kelola_nilai'] : PETA_IZIN.filter((i) => Number(fitur[i.fitur] ?? 0) >= i.min).map((i) => i.kode); this.kelompokSaya = peran === 'pegawai' ? [{ id: 'g-7a', jenis: 'kelas', nama: '7A' }, { id: 'g-hhb', jenis: 'halaqah', nama: 'Halaqah Ust. Hasan' }, { id: 'g-kum', jenis: 'kamar', nama: 'Kamar Umar' }] : []; this.tugas = TUGAS_DEMO[peran] || {}; this.persuratan = true; this.gaji = peran !== 'pegawai'; this.gajiLihat = peran !== 'pegawai'; this.keuangan = peran === 'superadmin'; this.penilaian = peran !== 'pegawai'; this.beban = { saya: true, atur: peran !== 'pegawai', rekap: peran !== 'pegawai' }; simpan('simka.demo.peran', peran) },

    async keluar() {
      if (!MODE_DEMO) await supabase.auth.signOut()
      simpan('simka.demo.peran', null)
      this.$reset(); this.siap = true
    },

    /** Tingkat akses fitur: 0 tidak ada, 1 lihat, 2 input/ubah, 3 kelola. Superadmin selalu 3. */
    /** Foto profil akun (juga dipakai di kartu pegawai). Alamat sementara diambil dari penyimpanan. */
    async muatFoto() {
      this.fotoUrl = ''
      if (!this.pengguna?.foto_id || MODE_DEMO) return
      try { const { alamatBerkas } = await import('@/lib/penyimpanan'); this.fotoUrl = await alamatBerkas(this.pengguna.foto_id) } catch { this.fotoUrl = '' }
    },
    setelFoto(id, url) { if (this.pengguna) this.pengguna.foto_id = id; this.fotoUrl = url || '' },

    /** Izin admin efektif (superadmin selalu; admin yang dicentang; pegawai yang mendapatnya dari Hak Akses). */
    bolehAdmin(kode) { return this.isSuperadmin || this.izinAdmin.includes(kode) },

    /** Cakupan luas sebuah fitur (melihat semua kelompok, bukan hanya asuhan). Hak dari jabatan fungsional tidak termasuk. */
    luas(kode) { return this.isAdmin || !!this.tugas?.luas?.[kode] },

    tingkat(kode) {
      if (this.isSuperadmin) return 3
      return Number(this.fitur?.[kode] ?? 0)
    },
  },
})
