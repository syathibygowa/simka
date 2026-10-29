// SIMKA PRO | src/stores/musyrif.js | v1.3 | 14.35.0: sesi asrama wajib/opsional, pengontrolan kamar, pengaturan butir kontrol | 30/10/2026
// Menu Musyrif: daftar kamar yang terlihat, sesi asrama hari ini, dan rincian absensi asrama per kamar
// (dasar dasbor dan rekap individu/kamar/pekan/bulan/rentang). Data hanya dibaca; pengisian tetap lewat Absensi Santri.
// v1.1: jurnal musyrif per kamar (tulis, ubah, hapus, tanggapan pimpinan).
// v1.2: ringkasan semua kamar (dasbor pemantauan admin/pimpinan).
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { pesanGalat } from './lembaga'
import { useSesi } from './sesi'
import { useSantri } from './santri'
import { dataKelompokDemo } from '@/lib/demoKelompok'
import { SESI_DEMO, SESI_ASRAMA_SEMUA_DEMO } from '@/lib/demoAbsensi'
import { hariIniISO } from '@/lib/tanggal'
import { tambahHari } from '@/lib/musyrif'

const rpc = async (nama, arg) => { const { data, error } = await supabase.rpc(nama, arg); if (error) throw new Error(pesanGalat(error)); return data }
const waktu = (tgl, j, menit = 0) => new Date(new Date(`${tgl}T${j}:00+08:00`).getTime() + menit * 60000)

const JURNAL_DEMO = {}
// 14.35.0: pengaturan dan pengontrolan contoh (mode demo)
const KONTROL_DEMO = { butir: [{ kode: 'KUNCI', teks: 'Kamar sudah terkunci', sesi: [] }, { kode: 'MASJID', teks: 'Santri sudah diarahkan ke masjid', sesi: ['SUBUH', 'MAGRIB'] },
  { kode: 'LISTRIK', teks: 'Alat kelistrikan sudah dipastikan mati', sesi: [] }, { kode: 'BERSIH', teks: 'Kamar sudah dibersihkan', sesi: ['PAGI', 'SORE'] }], catatan: {} }
const butirUntuk = (kode) => KONTROL_DEMO.butir.filter((b) => !b.sesi?.length || b.sesi.includes(kode))
/** Jurnal contoh per kamar (mode demo). */
function jurnalDemo(group) {
  if (JURNAL_DEMO[group]) return JURNAL_DEMO[group]
  const san = useSantri(); const d = dataKelompokDemo(san.daftar); const g = d.kelompok.find((x) => x.id === group)
  const anggota = d.anggota.filter((a) => a.group_id === group && !a.selesai).map((a) => san.cari(a.student_id)).filter(Boolean)
  const h = hariIniISO(); const penulis = g?.pengasuh[0]?.nama || 'Musyrif'
  const contoh = [
    [0, 'pagi', 'ibadah', 'Membangunkan santri untuk shalat Subuh berjamaah; semua santri hadir tepat waktu.', [], false],
    [0, 'malam', 'pembinaan', 'Muhasabah malam: adab terhadap guru dan teman sekamar.', [], false],
    [1, 'sore', 'kebersihan', 'Piket kebersihan kamar dan pemeriksaan lemari. Dua lemari belum rapi, sudah ditegur.', [0, 3], false],
    [1, 'malam', 'kejadian', 'Santri berselisih karena peminjaman barang tanpa izin; sudah didamaikan dan dinasihati.', [1, 4], true],
    [2, 'umum', 'kesehatan', 'Satu santri demam, sudah dirujuk ke klinik dan beristirahat di kamar.', [2], false],
  ]
  JURNAL_DEMO[group] = contoh.map(([hari, waktu, kategori, uraian, idx, penting], i) => ({ id: `jm-${group}-${i}`, tanggal: tambahHari(h, -hari), waktu, kategori, uraian,
    santri: idx.map((n) => anggota[n]).filter(Boolean).map((s) => ({ id: s.id, nama: s.nama_lengkap })), foto_id: null, penting,
    tanggapan: penting ? 'Jazakallah khairan, pantau terus dan laporkan bila berulang.' : null, ditanggapi_oleh: penting ? 'Ust. Muhammad Ikhsan, S.Pd.I.' : null,
    ditanggapi_pada: penting ? new Date().toISOString() : null, penulis, dibuat_oleh: g?.pengasuh[0]?.employee_id, created_at: new Date().toISOString(), boleh_ubah: true }))
  return JURNAL_DEMO[group]
}

export const useMusyrif = defineStore('musyrif', {
  state: () => ({ kamar: [], dimuat: false, pilih: '', saluran: null }),
  getters: {
    kamarPilih: (s) => s.kamar.find((k) => k.id === s.pilih) || null,
    asuhan: (s) => s.kamar.filter((k) => k.asuhan_saya),
  },
  actions: {
    async muatKamar(paksa = false) {
      if (this.dimuat && !paksa) return this.kamar
      if (MODE_DEMO) {
        const san = useSantri(); await san.muat(); const d = dataKelompokDemo(san.daftar); const peg = useSesi().peran === 'pegawai'
        this.kamar = d.kelompok.filter((g) => g.jenis === 'kamar' && g.aktif)
          .map((g) => ({ id: g.id, nama: g.nama, jenis_kelamin: g.jenis_kelamin, keterangan: g.keterangan, wa_wali: g.wa_wali || (g.id === 'g-kum' ? 'https://chat.whatsapp.com/contohKamarUmar' : null), wa_internal: g.wa_internal,
            asuhan_saya: g.pengasuh.some((p) => p.employee_id === 'p1') && peg,
            jumlah: d.anggota.filter((a) => a.group_id === g.id && !a.selesai).length,
            musyrif: g.pengasuh.map((p) => ({ employee_id: p.employee_id, nama: p.nama, niy: p.niy, peran: p.peran, no_hp: p.no_hp })) }))
          .filter((k) => !peg || k.asuhan_saya)
          .sort((a, b) => Number(b.asuhan_saya) - Number(a.asuhan_saya) || a.nama.localeCompare(b.nama, 'id'))
      } else this.kamar = (await rpc('kamar_musyrif')) || []
      if (!this.kamar.some((k) => k.id === this.pilih)) this.pilih = this.kamar[0]?.id || ''
      this.dimuat = true
      return this.kamar
    },

    /** Sesi asrama hari ini untuk satu kamar, dengan status terisi/terbuka/lewat/belum dibuka. */
    async sesiHariIni(group) {
      const tgl = hariIniISO(); const kini = new Date()
      let daftar
      if (MODE_DEMO) {
        daftar = SESI_DEMO.asrama.map((s) => {
          const selesai = waktu(tgl, s.jam_selesai, s.jam_selesai <= s.jam_mulai ? 1440 : 0)
          return { kode: s.kode, nama: s.nama, jam_mulai: s.jam_mulai, jam_selesai: s.jam_selesai, buka: waktu(tgl, s.jam_mulai, -s.buka).toISOString(),
            tutup: selesai.toISOString(), session_id: selesai < kini && (group.length + s.kode.length) % 9 !== 0 ? `sa-${group}-${tgl}-${s.kode}` : null }
        })
      } else daftar = (await rpc('sesi_kelompok', { p_group: group, p_tanggal: tgl })) || []
      return daftar.map((s) => ({ ...s, tanggal: tgl,
        status: s.session_id ? 'terisi' : kini < new Date(s.buka) ? 'belum_buka' : kini <= new Date(s.tutup) ? 'terbuka' : 'lewat' }))
    },

    async rinci(group, mulai, selesai) {
      if (!MODE_DEMO) return rpc('absensi_asrama_rinci', { p_group: group, p_mulai: mulai, p_selesai: selesai })
      const san = useSantri(); await san.muat(); const d = dataKelompokDemo(san.daftar); const g = d.kelompok.find((x) => x.id === group)
      const anggota = d.anggota.filter((a) => a.group_id === group && !a.selesai).map((a) => san.cari(a.student_id)).filter(Boolean)
        .sort((a, b) => a.nama_lengkap.localeCompare(b.nama_lengkap, 'id'))
      const hari = hariIniISO(); const kini = new Date(); const sesi = []; const isi = []; const rencana = []
      for (let t = mulai; t <= selesai && t <= hari; t = tambahHari(t, 1)) {
        const i = Math.round((new Date(`${hari}T00:00:00`) - new Date(`${t}T00:00:00`)) / 86400000)
        for (const s of SESI_DEMO.asrama) {
          if (waktu(t, s.jam_selesai, s.jam_selesai <= s.jam_mulai ? 1440 : 0) > kini) continue
          rencana.push({ tanggal: t, sesi: s.kode, nama_sesi: s.nama })
          if ((group.length + i + s.kode.length) % 9 === 0) continue
          const id = `sa-${group}-${t}-${s.kode}`
          sesi.push({ id, tanggal: t, sesi: s.kode, nama_sesi: s.nama, jam_mulai: s.jam_mulai + ':00', pengisi: g.pengasuh[0]?.nama, terlambat: i % 13 === 5, atas_nama: false })
          anggota.forEach((st, n) => {
            const kena = (n + i + s.kode.length) % 11 === 0 || (n === 2 && i % 4 === 1 && s.kode === 'PAGI')
            const kode = kena ? ['S', 'I', 'T', 'A', 'B'][(n + i) % 5] : 'H'
            isi.push([id, st.id, kode, kode === 'S' ? 'Demam, istirahat di kamar' : kode === 'I' ? 'Izin pulang keluarga' : null])
          })
        }
      }
      return { kamar: { id: g.id, nama: g.nama, jenis_kelamin: g.jenis_kelamin }, mulai, selesai, sesi, isi, rencana,
        santri: anggota.map((s) => ({ id: s.id, nis: s.nis, nama: s.nama_lengkap, jenis_kelamin: s.jenis_kelamin, status: s.status, aktif_di_kamar: true })) }
    },

    /** Ringkasan semua kamar yang terlihat pada rentang (dasbor pemantauan). */
    async ringkasan(mulai, selesai) {
      if (!MODE_DEMO) return (await rpc('ringkasan_asrama', { p_mulai: mulai, p_selesai: selesai })) || []
      await this.muatKamar(); const hasil = []
      for (const k of this.kamar) {
        const d = await this.rinci(k.id, mulai, selesai); const t = { I: 0, S: 0, A: 0, T: 0, n: 0 }
        for (const [, , kode] of d.isi) { t.n++; if (t[kode] != null) t[kode]++ }
        const j = jurnalDemo(k.id).filter((x) => x.tanggal >= mulai && x.tanggal <= selesai)
        hasil.push({ id: k.id, nama: k.nama, jenis_kelamin: k.jenis_kelamin, keterangan: k.keterangan, musyrif: k.musyrif.map((m) => m.nama).join(', '), santri: k.jumlah,
          sesi_rencana: d.rencana.length, sesi_terisi: d.sesi.length, anggota: t.n, hadir: t.n - t.I - t.S - t.A, izin: t.I, sakit: t.S, absen: t.A, terlambat: t.T,
          persen: t.n ? Math.round(((t.n - t.I - t.S - t.A) / t.n) * 1000) / 10 : null, hari_ini_terisi: d.sesi.filter((s) => s.tanggal === hariIniISO()).length,
          sakit_aktif: k.id === 'g-kum' ? 1 : 0, izin_aktif: k.id === 'g-kab' ? 1 : k.id === 'g-kum' ? 1 : 0, izin_terlambat: k.id === 'g-kum' ? 1 : 0,
          jurnal: j.length, jurnal_penting: j.filter((x) => x.penting).length, jurnal_terakhir: jurnalDemo(k.id)[0]?.tanggal || null })
      }
      return hasil
    },

    // ---------- Jurnal musyrif ----------
    async jurnal(group, mulai, selesai) {
      if (!MODE_DEMO) return (await rpc('daftar_jurnal_musyrif', { p_group: group, p_mulai: mulai, p_selesai: selesai })) || []
      return jurnalDemo(group).filter((j) => j.tanggal >= mulai && j.tanggal <= selesai).sort((a, b) => b.tanggal.localeCompare(a.tanggal))
    },
    async simpanJurnal(isi) {
      if (!MODE_DEMO) return rpc('simpan_jurnal_musyrif', { p: isi })
      const daftar = jurnalDemo(isi.group_id); const san = useSantri(); const nama = useSesi().pengguna?.nama_lengkap
      const santri = (isi.santri_ids || []).map((id) => ({ id, nama: san.cari(id)?.nama_lengkap || '–' }))
      const ada = isi.id && daftar.find((j) => j.id === isi.id)
      if (ada) Object.assign(ada, { ...isi, santri })
      else daftar.unshift({ ...isi, id: 'jm' + Date.now(), santri, penulis: nama, dibuat_oleh: useSesi().pengguna?.id, created_at: new Date().toISOString(), boleh_ubah: true, tanggapan: null })
    },
    async hapusJurnal(id, group) {
      if (!MODE_DEMO) return rpc('hapus_jurnal_musyrif', { p_id: id })
      const d = jurnalDemo(group); d.splice(d.findIndex((j) => j.id === id), 1)
    },
    async tanggapiJurnal(id, tanggapan, group) {
      if (!MODE_DEMO) return rpc('tanggapi_jurnal_musyrif', { p_id: id, p_tanggapan: tanggapan })
      Object.assign(jurnalDemo(group).find((j) => j.id === id), { tanggapan, ditanggapi_oleh: useSesi().pengguna?.nama_lengkap, ditanggapi_pada: new Date().toISOString() })
    },

    // ---------- 14.35.0: sesi asrama dan pengontrolan ----------
    /** Semua sesi asrama satu kamar pada satu tanggal: peran (wajib/opsional), absensi (bila diisi), pengontrolan. */
    async kontrolHari(group, tanggal) {
      if (!MODE_DEMO) return rpc('kontrol_asrama_hari', { p_group: group, p_tanggal: tanggal })
      const san = useSantri(); await san.muat(); const d = dataKelompokDemo(san.daftar); const g = d.kelompok.find((x) => x.id === group)
      const anggota = d.anggota.filter((a) => a.group_id === group && !a.selesai).map((a) => san.cari(a.student_id)).filter((x) => x && x.status !== 'nonaktif')
      const kini = new Date(); const hari = hariIniISO()
      const sesi = SESI_ASRAMA_SEMUA_DEMO.map((x, i) => {
        const selesai = waktu(tanggal, x.jam_selesai, x.jam_selesai <= x.jam_mulai ? 1440 : 0); const buka = waktu(tanggal, x.jam_mulai, -30)
        const lewat = selesai < kini; const kunci = `${group}|${tanggal}|${x.kode}`
        const isiAbsen = lewat && (x.mode === 'wajib' ? (group.length + i) % 7 !== 0 : x.kode === 'MAGRIB')
        const tidak = isiAbsen ? anggota.filter((_, n) => (n + i + tanggal.length) % 9 === 0).map((st, n) => ({ nama: st.nama_lengkap, kode: ['I', 'S', 'T', 'A'][(n + i) % 4], keterangan: null })) : []
        const n = (k) => tidak.filter((t) => t.kode === k).length
        if (!(kunci in KONTROL_DEMO.catatan) && lewat && (tanggal < hari || i < 3)) {
          KONTROL_DEMO.catatan[kunci] = { butir: butirUntuk(x.kode).map((b, j) => ({ kode: b.kode, teks: b.teks, ok: (i + j) % 5 !== 4 })), catatan: x.kode === 'MALAM' ? 'Dua santri masih murajaah di musala, sudah diarahkan tidur.' : null,
            waktu: selesai.toISOString(), oleh: g.pengasuh[0]?.nama }
        }
        return { kode: x.kode, nama: x.nama, jam_mulai: x.jam_mulai, jam_selesai: x.jam_selesai, mulai: waktu(tanggal, x.jam_mulai).toISOString(), selesai: selesai.toISOString(),
          buka: buka.toISOString(), tutup: new Date(selesai.getTime() + 45 * 60000).toISOString(), batas: new Date(selesai.getTime() + 45 * 60000).toISOString(), mode: x.mode, butir: butirUntuk(x.kode),
          absensi: isiAbsen ? { session_id: `sa-${kunci}`, jumlah_anggota: anggota.length, hadir: anggota.length - n('I') - n('S') - n('A'), izin: n('I'), sakit: n('S'), bolos: 0, absen: n('A'), terlambat: n('T'),
            diisi_pada: selesai.toISOString(), pengisi: g.pengasuh[0]?.nama, tidak } : null,
          kontrol: KONTROL_DEMO.catatan[kunci] || null }
      })
      return { tanggal, sekarang: kini.toISOString(), kamar: { id: g.id, nama: g.nama, jenis_kelamin: g.jenis_kelamin, wa_wali: g.wa_wali, wa_internal: g.wa_internal },
        pengasuh_saya: useSesi().peran === 'pegawai', boleh_atas_nama: useSesi().isAdmin, musyrif: g.pengasuh.map((p) => p.nama), jumlah_santri: anggota.length, sesi }
    },
    /** p: { group_id, tanggal, sesi, butir: [{ kode, ok }], catatan } */
    async simpanKontrol(p) {
      if (!MODE_DEMO) return rpc('simpan_kontrol_asrama', { p })
      KONTROL_DEMO.catatan[`${p.group_id}|${p.tanggal}|${p.sesi}`] = { butir: butirUntuk(p.sesi).map((b) => ({ kode: b.kode, teks: b.teks, ok: !!p.butir.find((x) => x.kode === b.kode)?.ok })),
        catatan: p.catatan?.trim() || null, waktu: new Date().toISOString(), oleh: useSesi().pengguna?.nama_lengkap }
    },
    async pengaturanKontrol() {
      if (!MODE_DEMO) return rpc('pengaturan_kontrol_asrama')
      return { pola: { kode: 'MUSYRIF', nama: 'Musyrif' }, boleh_atur: useSesi().isAdmin,
        sesi: SESI_ASRAMA_SEMUA_DEMO.map((x) => ({ kode: x.kode, nama: x.nama, jam_mulai: x.jam_mulai, jam_selesai: x.jam_selesai, hari: [0, 1, 2, 3, 4, 5, 6], opsional_pegawai: false, mode: x.mode })),
        butir: KONTROL_DEMO.butir.map((b) => ({ ...b, sesi: [...(b.sesi || [])] })) }
    },
    /** p: { mode: { KODE: 'wajib'|'opsional' }, butir: [{ kode?, teks, sesi: [] }] } */
    async simpanPengaturanKontrol(p) {
      if (!MODE_DEMO) return rpc('simpan_pengaturan_kontrol_asrama', { p })
      if (p.mode) {
        if (!Object.values(p.mode).includes('wajib')) throw new Error('Tetapkan minimal satu sesi asrama yang wajib absensi santri.')
        SESI_ASRAMA_SEMUA_DEMO.forEach((x) => { if (p.mode[x.kode]) x.mode = p.mode[x.kode] })
        SESI_DEMO.asrama = SESI_ASRAMA_SEMUA_DEMO.filter((x) => x.mode === 'wajib')
      }
      if (p.butir) {
        const b = p.butir.filter((x) => (x.teks || '').trim().length >= 3)
        if (!b.length || b.length > 30) throw new Error('Butir pengontrolan berisi 1 sampai 30 butir (minimal 3 huruf).')
        KONTROL_DEMO.butir = b.map((x, i) => ({ kode: x.kode || 'B' + Date.now().toString(36) + i, teks: x.teks.trim(), sesi: x.sesi || [] }))
      }
    },

    dengarkan(fn) {
      if (MODE_DEMO || this.saluran) return
      this.saluran = supabase.channel('musyrif-asrama').on('postgres_changes', { event: '*', schema: 'public', table: 'student_attendance_sessions' }, () => fn()).subscribe()
    },
    berhenti() { if (this.saluran) { supabase.removeChannel(this.saluran); this.saluran = null } },
  },
})
