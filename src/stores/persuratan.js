// SIMKA PRO | src/stores/persuratan.js | v1.4 | Perbaikan: hapus surat masuk/keluar salah catat dan rapikan nomor | 14/10/2026
// Persuratan: hak, ketentuan, surat masuk (catat, ubah, batal), disposisi berantai (beri, tarik, selesai), ringkasan, buku agenda;
// template surat (simpan, hapus) dan surat keluar (simpan draf, kirim ke TU, ajukan tanda tangan, batalkan, arsip, revisi);
// buku agenda surat keluar = inventaris semua surat (Persuratan + surat dari modul lain).
import { defineStore } from 'pinia'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { pesanGalat } from './lembaga'
import { useSesi } from './sesi'
import { hariIniISO } from '@/lib/tanggal'
import { tambahHari } from '@/lib/persuratan'
import { TEMPLATE_DEMO, KONTEKS_DEMO, PENANDA_DEMO, SANTRI_SURAT_DEMO } from '@/lib/demoSurat'

const rpc = async (nama, arg) => { const { data, error } = await supabase.rpc(nama, arg); if (error) throw new Error(pesanGalat(error)); return data }
const HAK_KOSONG = { kelola: false, superadmin: false, pimpinan: false, puncak: false, susun: false, tampil: false, pengaturan: { instruksi: [], batas_bawaan_hari: 3 } }
const INSTRUKSI = ['Tindak lanjuti', 'Pelajari dan laporkan', 'Hadiri/wakili', 'Koordinasikan', 'Siapkan jawaban', 'Untuk diketahui', 'Edarkan', 'Arsipkan']

// ---------------------------------------------------------------------------------------------- mode demo
const PIMPINAN_DEMO = [
  { id: 'e-dir', nama: 'Ust. Abdurrahman Hakim, Lc., M.Ag.', jabatan: 'Direktur (Mudir)', kode: 'DIREKTUR', bawaan: true },
  { id: 'e-wadir', nama: 'Ust. Muhammad Faisal, S.Pd.I., M.Pd.', jabatan: 'Wakil Direktur', kode: 'WAKIL_DIREKTUR', bawaan: false },
  { id: 'e-kst', nama: 'Ust. Muhammad Ikhsan, S.Pd.I.', jabatan: 'Kepala Bidang Kesantrian', kode: 'KEPALA_BIDANG', bawaan: false },
  { id: 'e-thf', nama: 'Ust. Hamzah Ridwan, Lc.', jabatan: 'Kepala Bidang Tahfizh', kode: 'KEPALA_BIDANG', bawaan: false },
]
const PEGAWAI_LAIN_DEMO = [
  { id: 'd-pg', nama: 'Ust. Hasan Basri, Lc.', jabatan: 'Muhaffizh', unit: 'Bidang Tahfizh' },
  { id: 'e-tu', nama: 'Ustzh. Rahmawati, S.E.', jabatan: 'Tata Usaha', unit: 'Unit Tata Usaha' },
  { id: 'e-ikh', nama: 'Ust. Ilham Saputra, S.Sos.', jabatan: 'Petugas media', unit: 'Bidang Media' },
  { id: 'e-syam', nama: 'Ust. Syamsul Arifin, S.Pd.', jabatan: 'Guru mapel', unit: 'Bidang Kesetaraan Wustha' },
]
const jam = (j) => new Date(Date.now() + j * 3600000).toISOString()
const hari = (n) => tambahHari(hariIniISO(), n)
let DEMO = null
function demo() {
  if (DEMO) return DEMO
  const s = (o) => ({ id: 'sm' + Math.random().toString(36).slice(2, 8), nomor_surat: null, tanggal_surat: null, alamat_pengirim: null, ringkasan: null, lampiran: null,
    sifat: 'biasa', cara: 'langsung', berkas_ids: [], tujuan_id: 'e-dir', status: 'diteruskan', catatan: null, catatan_selesai: null, dibaca_tujuan: null,
    dicatat_oleh: 'Ustzh. Rahmawati, S.E.', selesai_pada: null, ...o })
  const surat = [
    s({ nomor_agenda: '014/SM/IV/1448', urut_agenda: 14, tanggal_terima: hari(0), nomor_surat: 'B-1204/Kk.21.06/PP.00/10/2026', tanggal_surat: hari(-2), pengirim: 'Kantor Kementerian Agama Kabupaten Gowa',
      perihal: 'Undangan Rapat Koordinasi Pondok Pesantren se-Kabupaten Gowa', sifat: 'segera', lampiran: '1 lembar', created_at: jam(-2) }),
    s({ nomor_agenda: '013/SM/IV/1448', urut_agenda: 13, tanggal_terima: hari(-1), nomor_surat: '045/DPP-WI/X/2026', tanggal_surat: hari(-4), pengirim: 'DPP Wahdah Islamiyah',
      perihal: 'Pemberitahuan Daurah Tahfizh Nasional', sifat: 'penting', status: 'didisposisi', dibaca_tujuan: jam(-20), created_at: jam(-26) }),
    s({ nomor_agenda: '012/SM/IV/1448', urut_agenda: 12, tanggal_terima: hari(-3), nomor_surat: '12/PKM-BP/X/2026', tanggal_surat: hari(-4), pengirim: 'Puskesmas Bontonompo',
      perihal: 'Jadwal Imunisasi dan Pemeriksaan Kesehatan Santri', status: 'selesai', dibaca_tujuan: jam(-70), selesai_pada: jam(-12), created_at: jam(-72) }),
    s({ nomor_agenda: '011/SM/IV/1448', urut_agenda: 11, tanggal_terima: hari(-5), pengirim: 'Yayasan Pendidikan Mitra', perihal: 'Penawaran kerja sama beasiswa',
      sifat: 'rahasia', tujuan_id: 'e-dir', created_at: jam(-120) }),
    s({ nomor_agenda: '010/SM/IV/1448', urut_agenda: 10, tanggal_terima: hari(-6), pengirim: 'Toko Buku Al-Ikhlas', perihal: 'Brosur penawaran mushaf dan kitab',
      tujuan_id: null, status: 'diarsipkan', created_at: jam(-144) }),
  ]
  const d = (o) => ({ id: 'dp' + Math.random().toString(36).slice(2, 8), induk_id: null, instruksi: [], catatan: null, batas: null, status: 'baru', dibaca_pada: null,
    selesai_pada: null, laporan: null, ...o })
  const d1 = d({ letter_id: surat[1].id, dari_id: 'e-dir', kepada_id: 'e-thf', instruksi: ['Pelajari dan laporkan', 'Koordinasikan'], catatan: 'Siapkan 2 muhaffizh untuk ikut daurah.', batas: hari(3), status: 'dibaca', created_at: jam(-20), dibaca_pada: jam(-18) })
  const disposisi = [
    d1,
    d({ letter_id: surat[1].id, induk_id: d1.id, dari_id: 'e-thf', kepada_id: 'd-pg', instruksi: ['Tindak lanjuti'], catatan: 'Mohon kesediaan antum mengikuti daurah.', batas: hari(2), created_at: jam(-10) }),
    d({ letter_id: surat[2].id, dari_id: 'e-dir', kepada_id: 'e-kst', instruksi: ['Tindak lanjuti', 'Koordinasikan'], batas: hari(-1), status: 'selesai', created_at: jam(-60),
      dibaca_pada: jam(-58), selesai_pada: jam(-12), laporan: 'Jadwal imunisasi sudah dikoordinasikan dengan klinik putra dan putri; santri didata per kamar.' }),
  ]
  const k = (o) => ({ id: 'sk' + Math.random().toString(36).slice(2, 8), kop_kode: 'pondok', lampiran: '–', tembusan: [], narahubung: null, nomor: null, document_id: null,
    catatan: null, berkas_arsip_id: null, mode_ttd: 'elektronik', tanggal_hijriah: null, disusun_oleh: 'Ustzh. Rahmawati, S.E.', disusun_oleh_id: 'e-tu', terbit_pada: null, ...o })
  const tp = (kode) => TEMPLATE_DEMO.find((x) => x.kode === kode)
  const potret = (x) => ({ bentuk: x.bentuk, judul: x.judul, subjudul: x.subjudul, isi: x.isi, opsi: { ...x.opsi }, isian: x.isian })
  const keluar = [
    k({ template_id: tp('undangan').id, jenis_nama: 'Surat Undangan', kategori: 'umum', dk: 'K', perihal_kode: 'DW', format_nomor: 'surat', tanggal_surat: hari(-1),
      tanggal_hijriah: '27 Rabiul Akhir 1448 H', perihal: 'Undangan Rapat Wali Santri', kepada: 'Bapak/Ibu Wali Santri Kelas 7–9\nKesetaraan Wustha', status: 'terbit',
      nomor: 'K.003/DW/PPTQ-IAS/IV/1448', document_id: 'dk-1', terbit_pada: jam(-20), tembusan: ['Ketua Yayasan', 'Arsip'], narahubung: 'Ust. Fadhil (0812-3456-7890)',
      nilai: { acara: 'Rapat Wali Santri Semester Ganjil', hari_tanggal: hari(6), waktu: '08:30', tempat: 'Aula Pondok Putra', agenda: ['Laporan perkembangan santri', 'Program tahfizh semester ganjil', 'Tanya jawab'] },
      tampilan: potret(tp('undangan')), penanda: [{ posisi: 'kanan', signatory_id: 'sg-dir', employee_id: 'e-dir', nama: PENANDA_DEMO[0].nama, niy: PENANDA_DEMO[0].niy, jabatan: 'Direktur' }],
      kode_validasi: '7KQ2-M9XA', status_dokumen: 'sah', ttd: [{ urutan: 1, posisi: 'kanan', nama: PENANDA_DEMO[0].nama, jabatan: 'Direktur', status: 'ditandatangani', waktu: jam(-20) }] }),
    k({ template_id: tp('keterangan_aktif_santri').id, jenis_nama: 'Surat Keterangan Aktif Santri', kategori: 'santri', dk: 'K', perihal_kode: 'IL', format_nomor: 'surat', tanggal_surat: hari(0),
      perihal: 'Keterangan Aktif Santri', status: 'menunggu_ttd', document_id: 'dk-2', kode_validasi: 'P4HT-8WZC', status_dokumen: 'draf',
      nilai: { santri: SANTRI_SURAT_DEMO[0], keperluan: 'pengurusan beasiswa' }, tampilan: potret(tp('keterangan_aktif_santri')),
      penanda: [{ posisi: 'kanan', signatory_id: 'sg-dir', employee_id: 'e-dir', nama: PENANDA_DEMO[0].nama, niy: PENANDA_DEMO[0].niy, jabatan: 'Direktur' }],
      ttd: [{ urutan: 1, posisi: 'kanan', nama: PENANDA_DEMO[0].nama, jabatan: 'Direktur', status: 'menunggu', waktu: null }] }),
    k({ template_id: tp('perjalanan_dinas').id, jenis_nama: 'Surat Perjalanan Dinas', kategori: 'pegawai', dk: 'D', perihal_kode: 'AM', format_nomor: 'surat', tanggal_surat: hari(0),
      perihal: 'Perjalanan Dinas', status: 'diperiksa', disusun_oleh: 'Ust. Hamzah Ridwan, Lc.', disusun_oleh_id: 'e-thf', pemohon: 'Ust. Hamzah Ridwan, Lc.', pemohon_id: 'e-thf',
      nilai: { pegawai: { id: 'd-pg', nama: 'Ust. Hasan Basri, Lc.', niy: '2019070101', jabatan: 'Muhaffizh', unit: 'Bidang Tahfizh' }, maksud: 'Mengikuti Daurah Tahfizh Nasional', tujuan: 'Makassar', tanggal_berangkat: hari(4), tanggal_kembali: hari(6) },
      tampilan: potret(tp('perjalanan_dinas')), penanda: [{ posisi: 'kanan', signatory_id: 'sg-dir', employee_id: 'e-dir', nama: PENANDA_DEMO[0].nama, niy: PENANDA_DEMO[0].niy, jabatan: 'Direktur' }] }),
  ]
  DEMO = { surat, disposisi, keluar, templat: TEMPLATE_DEMO.map((x) => ({ ...x })), pengaturan: { instruksi: [...INSTRUKSI], batas_bawaan_hari: 3 } }
  return DEMO
}
const semuaOrang = () => [...PIMPINAN_DEMO, ...PEGAWAI_LAIN_DEMO]
const orang = (id) => semuaOrang().find((p) => p.id === id) || { nama: '–', jabatan: '' }
/** Identitas pengguna demo dipetakan ke pemeran surat: superadmin = Direktur, pegawai = Ust. Hasan Basri. */
const sayaDemo = () => ({ superadmin: 'e-dir', admin: 'e-tu', pegawai: 'd-pg' }[useSesi().peran] || 'd-pg')
function jsonDemo(s) {
  const D = demo(); const saya = sayaDemo(); const ds = D.disposisi.filter((x) => x.letter_id === s.id); const hi = hariIniISO()
  const sayaTerima = ds.filter((x) => x.kepada_id === saya && x.status !== 'selesai')
  return { ...s, jumlah_berkas: s.berkas_ids.length, tujuan: s.tujuan_id ? orang(s.tujuan_id).nama : null, tujuan_jabatan: s.tujuan_id ? orang(s.tujuan_id).jabatan : null,
    disposisi_ringkas: ds.filter((x) => !x.induk_id).map((x) => ({ kepada: orang(x.kepada_id).nama, status: x.status })),
    jumlah_disposisi: ds.length, disposisi_terbuka: ds.filter((x) => x.status !== 'selesai').length,
    lewat_batas: ds.some((x) => x.status !== 'selesai' && x.batas && x.batas < hi),
    peran_saya: s.tujuan_id === saya ? 'tujuan' : ds.some((x) => x.kepada_id === saya) ? 'penerima' : ds.some((x) => x.dari_id === saya) ? 'pemberi' : null,
    perlu_tindakan: (s.tujuan_id === saya && s.status === 'diteruskan') || sayaTerima.length > 0,
    batas_saya: sayaTerima.map((x) => x.batas).filter(Boolean).sort()[0] || null,
    baru_saya: (s.tujuan_id === saya && s.status === 'diteruskan' && !s.dibaca_tujuan) || sayaTerima.some((x) => x.status === 'baru') }
}
function cekSelesaiDemo(id) {
  const D = demo(); const s = D.surat.find((x) => x.id === id); const ds = D.disposisi.filter((x) => x.letter_id === id)
  if (s.status === 'didisposisi' && ds.length && ds.every((x) => x.status === 'selesai')) Object.assign(s, { status: 'selesai', selesai_pada: new Date().toISOString() })
}

// ---------------------------------------------------------------------------------------------- toko
export const usePersuratan = defineStore('persuratan', {
  state: () => ({ hak: { ...HAK_KOSONG }, hakDimuat: false, pimpinan: [], pegawai: [], pegawaiLengkap: [], templat: [], konteks: null, penandaTangan: [], saluran: null }),
  getters: {
    pengaturan: (s) => s.hak.pengaturan || HAK_KOSONG.pengaturan,
    /** Buku agenda dan daftar semua surat: pengelola dan pimpinan puncak. */
    bolehAgenda: (s) => s.hak.kelola || s.hak.puncak,
  },
  actions: {
    async muatHak() {
      if (MODE_DEMO) {
        const p = useSesi().peran; const D = demo()
        this.hak = { kelola: p !== 'pegawai', superadmin: p === 'superadmin', pimpinan: p === 'superadmin', puncak: p === 'superadmin', susun: p !== 'pegawai', tampil: true, pengaturan: D.pengaturan }
      } else this.hak = { ...HAK_KOSONG, ...((await rpc('hak_persuratan')) || {}) }
      this.hakDimuat = true; return this.hak
    },
    async muatPimpinan() {
      if (this.pimpinan.length) return this.pimpinan
      this.pimpinan = MODE_DEMO ? PIMPINAN_DEMO.map((p) => ({ ...p })) : (await rpc('pimpinan_penerima_surat')) || []
      return this.pimpinan
    },
    async muatPegawai() {
      if (this.pegawai.length) return this.pegawai
      this.pegawai = MODE_DEMO ? [...PIMPINAN_DEMO.map((p) => ({ ...p, pimpinan: true, unit: null })), ...PEGAWAI_LAIN_DEMO.map((p) => ({ ...p, pimpinan: false }))].filter((p) => p.id !== sayaDemo())
        : ((await rpc('pegawai_disposisi')) || []).filter((p) => p.id !== useSesi().pengguna?.id)
      return this.pegawai
    },
    async simpanPengaturan(p) {
      if (MODE_DEMO) { Object.assign(demo().pengaturan, p); this.hak.pengaturan = { ...demo().pengaturan }; return }
      this.hak.pengaturan = await rpc('simpan_pengaturan_persuratan', { p })
    },
    /** cakupan: masuk | untuk_saya */
    async daftar(cakupan, mulai = null, selesai = null) {
      if (!MODE_DEMO) return (await rpc('daftar_surat_masuk', { p_cakupan: cakupan, p_mulai: mulai, p_selesai: selesai })) || []
      const D = demo(); const saya = sayaDemo()
      const terlibat = (s) => s.tujuan_id === saya || D.disposisi.some((x) => x.letter_id === s.id && (x.kepada_id === saya || x.dari_id === saya))
      const dalam = (s) => (!mulai || s.tanggal_terima >= mulai) && (!selesai || s.tanggal_terima <= selesai)
      const rows = D.surat.filter((s) => cakupan === 'untuk_saya' ? s.status !== 'batal' && terlibat(s) && (jsonDemo(s).perlu_tindakan || dalam(s)) : dalam(s)
        && (this.hak.kelola || terlibat(s) || (this.hak.puncak && s.sifat !== 'rahasia'))).map(jsonDemo)
      return rows.sort((a, b) => (cakupan === 'untuk_saya' ? Number(b.perlu_tindakan) - Number(a.perlu_tindakan) : 0) || b.tanggal_terima.localeCompare(a.tanggal_terima) || b.urut_agenda - a.urut_agenda)
    },
    async rincian(id) {
      if (!MODE_DEMO) return rpc('rincian_surat_masuk', { p_id: id })
      const D = demo(); const s = D.surat.find((x) => x.id === id); if (!s) throw new Error('Surat tidak ditemukan.')
      const saya = sayaDemo(); const kelola = this.hak.kelola
      for (const x of D.disposisi) if (x.letter_id === id && x.kepada_id === saya && x.status === 'baru') Object.assign(x, { status: 'dibaca', dibaca_pada: new Date().toISOString() })
      if (s.tujuan_id === saya && !s.dibaca_tujuan) s.dibaca_tujuan = new Date().toISOString()
      const ds = D.disposisi.filter((x) => x.letter_id === id); const tanpaDisp = !ds.length; const hi = hariIniISO()
      return { ...jsonDemo(s), berkas_ids: s.berkas_ids,
        disposisi: ds.map((x) => ({ ...x, dari: orang(x.dari_id).nama, dari_jabatan: orang(x.dari_id).jabatan, kepada: orang(x.kepada_id).nama, kepada_jabatan: orang(x.kepada_id).jabatan,
          lewat: x.status !== 'selesai' && x.batas && x.batas < hi, saya_penerima: x.kepada_id === saya, saya_pemberi: x.dari_id === saya,
          boleh_tarik: x.dari_id === saya && x.status !== 'selesai' && !ds.some((c) => c.induk_id === x.id) })),
        boleh: { ubah: kelola && ['diteruskan', 'diarsipkan'].includes(s.status) && tanpaDisp, batal: kelola && ['diteruskan', 'diarsipkan'].includes(s.status) && tanpaDisp,
          disposisi: ['diteruskan', 'didisposisi'].includes(s.status) && s.tujuan_id === saya, tutup: s.status === 'diteruskan' && s.tujuan_id === saya,
          cetak: kelola || s.tujuan_id === saya } }
    },
    async catat(isi) {
      if (!MODE_DEMO) return rpc('catat_surat_masuk', { p: isi })
      const D = demo(); const urut = Math.max(...D.surat.map((s) => s.urut_agenda)) + 1; const no = `${String(urut).padStart(3, '0')}/SM/IV/1448`
      const arsip = !!isi.arsip
      D.surat.unshift({ ...isi, id: 'sm' + Date.now(), nomor_agenda: no, urut_agenda: urut, berkas_ids: [], tujuan_id: arsip ? null : isi.tujuan_id, status: arsip ? 'diarsipkan' : 'diteruskan',
        dibaca_tujuan: null, dicatat_oleh: useSesi().pengguna?.nama_lengkap, created_at: new Date().toISOString(), selesai_pada: null, catatan_selesai: null })
      return { id: D.surat[0].id, nomor_agenda: no }
    },
    async ubah(isi) {
      if (!MODE_DEMO) return rpc('ubah_surat_masuk', { p: isi })
      const s = demo().surat.find((x) => x.id === isi.id); const arsip = !!isi.arsip
      Object.assign(s, { ...isi, berkas_ids: s.berkas_ids, tujuan_id: arsip ? null : isi.tujuan_id, status: arsip ? 'diarsipkan' : 'diteruskan' })
    },
    async batal(id, alasan) {
      if (!MODE_DEMO) return rpc('batalkan_surat_masuk', { p_id: id, p_alasan: alasan })
      Object.assign(demo().surat.find((x) => x.id === id), { status: 'batal', catatan_selesai: alasan })
    },
    /** Hapus surat masuk salah catat; rapikan = nomor agenda sesudahnya digeser naik. */
    async hapusMasuk(id, alasan, rapikan = true) {
      if (!MODE_DEMO) return rpc('hapus_surat_masuk', { p_id: id, p_alasan: alasan, p_rapikan: rapikan })
      const D = demo(); D.surat = D.surat.filter((x) => x.id !== id); return { digeser: 0 }
    },
    async tutup(id, catatan) {
      if (!MODE_DEMO) return rpc('selesaikan_surat_masuk', { p_id: id, p_catatan: catatan || null })
      Object.assign(demo().surat.find((x) => x.id === id), { status: 'selesai', catatan_selesai: catatan || 'Cukup diketahui', selesai_pada: new Date().toISOString() })
    },
    async disposisi(isi) {
      if (!MODE_DEMO) return rpc('beri_disposisi', { p: isi })
      const D = demo(); const saya = sayaDemo()
      for (const k of isi.kepada) D.disposisi.push({ id: 'dp' + Math.random().toString(36).slice(2, 8), letter_id: isi.surat_id, induk_id: isi.induk_id || null, dari_id: saya, kepada_id: k,
        instruksi: isi.instruksi, catatan: isi.catatan || null, batas: isi.batas || null, status: 'baru', dibaca_pada: null, selesai_pada: null, laporan: null, created_at: new Date().toISOString() })
      D.surat.find((x) => x.id === isi.surat_id).status = 'didisposisi'
      return isi.kepada.length
    },
    async tarik(id) {
      if (!MODE_DEMO) return rpc('tarik_disposisi', { p_id: id })
      const D = demo(); const x = D.disposisi.find((d) => d.id === id); D.disposisi = D.disposisi.filter((d) => d.id !== id)
      if (!D.disposisi.some((d) => d.letter_id === x.letter_id)) D.surat.find((s) => s.id === x.letter_id).status = 'diteruskan'
    },
    async selesaiDisposisi(id, laporan) {
      if (!MODE_DEMO) return rpc('selesaikan_disposisi', { p_id: id, p_laporan: laporan })
      const D = demo(); const x = D.disposisi.find((d) => d.id === id)
      if (D.disposisi.some((c) => c.induk_id === id && c.status !== 'selesai')) throw new Error('Masih ada disposisi lanjutan dari Anda yang belum selesai.')
      Object.assign(x, { status: 'selesai', laporan, selesai_pada: new Date().toISOString() }); cekSelesaiDemo(x.letter_id)
    },
    async ringkasan() {
      if (!MODE_DEMO) return (await rpc('ringkasan_persuratan')) || {}
      const D = demo(); const saya = sayaDemo(); const hi = hariIniISO(); const bulan = hi.slice(0, 7)
      return { perlu_tindakan_saya: D.surat.filter((s) => s.tujuan_id === saya && s.status === 'diteruskan').length + D.disposisi.filter((x) => x.kepada_id === saya && x.status !== 'selesai').length,
        lewat_batas_saya: D.disposisi.filter((x) => x.kepada_id === saya && x.status !== 'selesai' && x.batas && x.batas < hi).length,
        masuk_bulan_ini: D.surat.filter((s) => s.tanggal_terima.slice(0, 7) === bulan && s.status !== 'batal').length,
        menunggu_disposisi: D.surat.filter((s) => s.status === 'diteruskan').length, berjalan: D.surat.filter((s) => s.status === 'didisposisi').length,
        lewat_batas: new Set(D.disposisi.filter((x) => x.status !== 'selesai' && x.batas && x.batas < hi).map((x) => x.letter_id)).size,
        selesai_bulan_ini: D.surat.filter((s) => s.status === 'selesai').length, kelola: this.hak.kelola,
        keluar_diperiksa: this.hak.kelola ? D.keluar.filter((o) => o.status === 'diperiksa').length : 0, keluar_menunggu_ttd: D.keluar.filter((o) => o.status === 'menunggu_ttd').length,
        keluar_terbit_bulan_ini: D.keluar.filter((o) => o.status === 'terbit').length,
        ttd_saya: D.keluar.filter((o) => o.status === 'menunggu_ttd' && o.penanda.some((p) => p.employee_id === saya)).length }
    },
    async bukuAgenda(mulai, selesai) {
      if (!MODE_DEMO) return (await rpc('buku_agenda_masuk', { p_mulai: mulai, p_selesai: selesai })) || []
      const D = demo()
      return D.surat.filter((s) => s.tanggal_terima >= mulai && s.tanggal_terima <= selesai).map((s) => ({ ...s, tujuan: s.tujuan_id ? orang(s.tujuan_id).nama : null,
        disposisi: D.disposisi.filter((x) => x.letter_id === s.id && !x.induk_id).map((x) => orang(x.kepada_id).nama).join('; ') || null }))
        .sort((a, b) => a.tanggal_terima.localeCompare(b.tanggal_terima) || a.urut_agenda - b.urut_agenda)
    },

    // ------------------------------------------------------------------ template dan surat keluar
    async muatTemplat() {
      if (MODE_DEMO) { this.templat = demo().templat.map((x) => ({ ...x })); return this.templat }
      const { data, error } = await supabase.from('letter_templates').select('*').order('urutan').order('nama')
      if (error) throw new Error(pesanGalat(error))
      this.templat = data || []; return this.templat
    },
    async simpanTemplat(p) {
      if (MODE_DEMO) {
        const D = demo(); const i = D.templat.findIndex((x) => x.id === p.id)
        if (i >= 0) Object.assign(D.templat[i], p); else D.templat.push({ ...p, id: 'tp-' + Date.now(), bawaan: false, urutan: 99 })
        return this.muatTemplat()
      }
      await rpc('simpan_template_surat', { p }); return this.muatTemplat()
    },
    async hapusTemplat(id) {
      if (MODE_DEMO) { const D = demo(); D.templat = D.templat.filter((x) => x.id !== id); await this.muatTemplat(); return 'hapus' }
      const h = await rpc('hapus_template_surat', { p_id: id }); await this.muatTemplat(); return h
    },
    async muatKonteks() {
      if (this.konteks) return this.konteks
      this.konteks = MODE_DEMO ? { ...KONTEKS_DEMO, hari_ini: hariIniISO() } : (await rpc('konteks_surat')) || {}
      return this.konteks
    },
    async muatPenandaTangan() {
      this.penandaTangan = MODE_DEMO ? PENANDA_DEMO.map((x) => ({ ...x })) : (await rpc('penanda_tangan_surat')) || []
      return this.penandaTangan
    },
    async muatPegawaiLengkap() {
      if (this.pegawaiLengkap.length) return this.pegawaiLengkap
      this.pegawaiLengkap = MODE_DEMO ? [...PIMPINAN_DEMO, ...PEGAWAI_LAIN_DEMO].map((p) => ({ ...p, niy: p.niy || '20190701' + p.id.length }))
        : (await rpc('pegawai_disposisi')) || []
      return this.pegawaiLengkap
    },
    async cariSantri(q) {
      if (!MODE_DEMO) return (await rpc('santri_untuk_surat', { p_cari: q })) || []
      const t = q.toLowerCase().trim(); return SANTRI_SURAT_DEMO.filter((s) => `${s.nama} ${s.nis}`.toLowerCase().includes(t))
    },
    async daftarKeluar(mulai = null, selesai = null) {
      if (!MODE_DEMO) return (await rpc('daftar_surat_keluar', { p_mulai: mulai, p_selesai: selesai })) || []
      const urut = { diperiksa: 0, menunggu_ttd: 1, ditolak: 2, draf: 3 }
      return demo().keluar.map((o) => ({ ...o, saya_penyusun: o.disusun_oleh_id === sayaDemo(), menunggu_saya: o.status === 'menunggu_ttd' && o.penanda.some((p) => p.employee_id === sayaDemo()) }))
        .sort((a, b) => (urut[a.status] ?? 4) - (urut[b.status] ?? 4) || b.tanggal_surat.localeCompare(a.tanggal_surat))
    },
    async rincianKeluar({ id = null, doc = null } = {}) {
      if (!MODE_DEMO) return rpc('rincian_surat_keluar', { p_id: id, p_doc: doc })
      const o = demo().keluar.find((x) => x.id === id || (doc && x.document_id === doc)); if (!o) throw new Error('Surat tidak ditemukan.')
      const kelola = this.hak.kelola; const saya = sayaDemo(); const penyusun = o.disusun_oleh_id === saya
      const tunggu = o.status === 'menunggu_ttd' && o.penanda.some((p) => p.employee_id === saya)
      return { ...o, saya_penyusun: penyusun, menunggu_saya: tunggu,
        dokumen: o.document_id ? { id: o.document_id, kode: o.kode_validasi, status: o.status_dokumen, mode_ttd: o.mode_ttd, nomor: o.nomor, penanda: o.ttd || [] } : null,
        boleh: { ubah: (['draf', 'ditolak'].includes(o.status) && (penyusun || kelola)) || (o.status === 'diperiksa' && kelola),
          kirim_tu: ['draf', 'ditolak'].includes(o.status) && penyusun && !kelola, ajukan: kelola && ['draf', 'diperiksa', 'ditolak'].includes(o.status),
          batal: ['draf', 'diperiksa', 'ditolak', 'menunggu_ttd'].includes(o.status) && (penyusun || kelola), arsip: kelola && o.status === 'terbit',
          revisi: kelola && o.status === 'terbit', tanda_tangan: tunggu },
        revisi_dari_nomor: demo().keluar.find((x) => x.id === o.revisi_dari)?.nomor || null,
        pengganti: (() => { const x = demo().keluar.find((y) => y.revisi_dari === o.id && y.status !== 'dibatalkan'); return x ? { id: x.id, status: x.status, nomor: x.nomor, revisi_ke: x.revisi_ke } : null })() }
    },
    async simpanKeluar(p) {
      if (!MODE_DEMO) return rpc('simpan_surat_keluar', { p })
      const D = demo(); const t = D.templat.find((x) => x.id === p.template_id); const sg = (x) => PENANDA_DEMO.find((g) => g.id === x.signatory_id)
      const penanda = p.penanda.map((x, i) => ({ ...x, posisi: p.penanda.length === 1 ? 'kanan' : i ? 'kanan' : 'kiri', nama: x.nama || sg(x)?.nama, niy: x.niy || sg(x)?.niy, employee_id: x.employee_id || sg(x)?.employee_id }))
      const pem = p.pemohon_id ? this.pegawaiLengkap.find((x) => x.id === p.pemohon_id) : null
      const isi = { ...p, penanda, pemohon: pem?.nama || null, jenis_nama: t.nama, kategori: t.kategori, perihal_kode: t.perihal_kode, format_nomor: t.format_nomor }
      const o = D.keluar.find((x) => x.id === p.id)
      if (o) { Object.assign(o, isi, { status: o.status === 'ditolak' ? 'draf' : o.status }); return o.id }
      const baru = { ...isi, id: 'sk' + Date.now(), status: 'draf', nomor: null, document_id: null, disusun_oleh: useSesi().pengguna?.nama_lengkap, disusun_oleh_id: sayaDemo(), mode_ttd: 'elektronik', terbit_pada: null }
      D.keluar.unshift(baru); return baru.id
    },
    async kirimKeTu(id) {
      if (!MODE_DEMO) return rpc('kirim_surat_ke_tu', { p_id: id })
      demo().keluar.find((x) => x.id === id).status = 'diperiksa'
    },
    async ajukanKeluar(id, mode, isi) {
      if (!MODE_DEMO) return rpc('ajukan_surat_keluar', { p_id: id, p_mode: mode, p_isi: isi })
      const o = demo().keluar.find((x) => x.id === id); const n = demo().keluar.filter((x) => x.nomor).length + 1
      const basah = mode === 'basah'
      Object.assign(o, { mode_ttd: mode, document_id: 'dk-' + Date.now(), kode_validasi: 'D3MO-' + String(n).padStart(4, '7'), tanggal_hijriah: KONTEKS_DEMO.hijriah_hari_ini,
        status: basah ? 'terbit' : 'menunggu_ttd', status_dokumen: basah ? 'sah' : 'draf', nomor: o.nomor || (basah ? `${o.dk}.00${n}/${o.perihal_kode}/PPTQ-IAS/IV/1448` : null),
        ttd: o.penanda.map((p, i) => ({ urutan: i + 1, posisi: p.posisi, nama: p.nama, jabatan: p.jabatan, status: basah ? 'ditandatangani' : 'menunggu', catatan: basah ? 'basah' : null })) })
      if (basah) this._gantiRevisiDemo(o)
      return { status: o.status, nomor: o.nomor, kode: o.kode_validasi }
    },
    _gantiRevisiDemo(o) {
      const lama = o.revisi_dari && demo().keluar.find((x) => x.id === o.revisi_dari)
      if (lama && lama.status === 'terbit') Object.assign(lama, { status: 'direvisi', status_dokumen: 'direvisi', catatan: `Diganti revisi ke-${o.revisi_ke}: ${o.alasan_revisi}` })
    },
    /** Revisi surat terbit (Tata Usaha): draf salinan; nomor lama dipakai kecuali nomorBaru. Mengembalikan id draf revisi. */
    async revisiKeluar(id, alasan, nomorBaru = false) {
      if (!MODE_DEMO) return rpc('revisi_surat_keluar', { p_id: id, p_alasan: alasan, p_nomor_baru: nomorBaru })
      const D = demo(); const o = D.keluar.find((x) => x.id === id)
      const ada = D.keluar.find((x) => x.revisi_dari === id && ['draf', 'diperiksa', 'menunggu_ttd', 'ditolak'].includes(x.status)); if (ada) return ada.id
      const baru = { ...o, id: 'sk' + Date.now(), status: 'draf', document_id: null, kode_validasi: null, status_dokumen: null, ttd: null, berkas_arsip_id: null, terbit_pada: null,
        nomor: nomorBaru ? null : o.nomor, tanggal_surat: nomorBaru ? hariIniISO() : o.tanggal_surat, catatan: 'Revisi: ' + alasan,
        revisi_dari: o.id, revisi_ke: (o.revisi_ke || 0) + 1, alasan_revisi: alasan, disusun_oleh: useSesi().pengguna?.nama_lengkap, disusun_oleh_id: sayaDemo() }
      D.keluar.unshift(baru); return baru.id
    },
    async tandatanganiKeluar(docId, setuju, catatan = null) {
      if (!MODE_DEMO) return rpc('tandatangani_dokumen', { p_id: docId, p_setuju: setuju, p_catatan: catatan })
      const o = demo().keluar.find((x) => x.document_id === docId); const n = demo().keluar.filter((x) => x.nomor).length + 1
      if (!setuju) { Object.assign(o, { status: 'ditolak', status_dokumen: 'ditolak', catatan }); return { status: 'ditolak' } }
      o.ttd.forEach((t) => Object.assign(t, { status: 'ditandatangani', waktu: new Date().toISOString() }))
      Object.assign(o, { status: 'terbit', status_dokumen: 'sah', nomor: o.nomor || `${o.dk}.00${n}/${o.perihal_kode}/PPTQ-IAS/IV/1448`, terbit_pada: new Date().toISOString(), tanggal_hijriah: o.tanggal_hijriah || KONTEKS_DEMO.hijriah_hari_ini })
      this._gantiRevisiDemo(o)
      return { status: 'sah', kode: o.kode_validasi }
    },
    async batalKeluar(id, alasan) {
      if (!MODE_DEMO) return rpc('batalkan_surat_keluar', { p_id: id, p_alasan: alasan })
      Object.assign(demo().keluar.find((x) => x.id === id), { status: 'dibatalkan', catatan: alasan })
    },
    /** Hapus surat keluar salah catat; rapikan = nomor surat sesudahnya ikut bergeser. */
    async hapusKeluar(id, alasan, rapikan = true) {
      if (!MODE_DEMO) return rpc('hapus_surat_keluar', { p_id: id, p_alasan: alasan, p_rapikan: rapikan })
      const D = demo(); D.keluar = D.keluar.filter((x) => x.id !== id); return { digeser: 0 }
    },
    async arsipKeluar(id, berkasId) {
      if (!MODE_DEMO) return rpc('simpan_arsip_surat_keluar', { p_id: id, p_berkas: berkasId })
      demo().keluar.find((x) => x.id === id).berkas_arsip_id = 'demo'
    },
    async bukuAgendaKeluar(mulai, selesai) {
      if (!MODE_DEMO) return (await rpc('buku_agenda_keluar', { p_mulai: mulai, p_selesai: selesai })) || []
      const tu = demo().keluar.filter((o) => ['terbit', 'dicabut', 'direvisi'].includes(o.status) && o.tanggal_surat >= mulai && o.tanggal_surat <= selesai)
        .map((o) => ({ ...o, sumber: 'tu', sumber_nama: 'Persuratan', penanda: o.penanda.map((p) => p.nama).join('; '), tautan: '/persuratan/keluar?surat=' + o.id }))
      const lain = [
        { sumber: 'pengajuan', sumber_nama: 'Pengajuan pegawai', id: 'rg-1', nomor: 'D.014/PPTQ-IAS/IV/1448', tanggal_surat: hari(-2), jenis_nama: 'Surat Izin', perihal: 'Izin 2 hari, keperluan keluarga',
          kepada: 'Ust. Hasan Basri, Lc.', penanda: 'Ust. Muhammad Ikhsan, S.Pd.I.; Ust. Abdurrahman Hakim, Lc., M.Ag.', mode_ttd: 'elektronik', status: 'terbit', kode_validasi: 'K7PW-3HQA', tautan: '/pengajuan' },
        { sumber: 'klinik', sumber_nama: 'Klinik', id: 'rg-2', nomor: 'SKS.021/PPTQ-IAS/IV/1448', tanggal_surat: hari(-1), jenis_nama: 'Surat Keterangan Sakit', perihal: 'Istirahat sakit 2 hari',
          kepada: 'Muhammad Fathir Al-Ghifari (NIS 2411001)', penanda: 'Petugas Klinik', mode_ttd: 'elektronik', status: 'terbit', kode_validasi: 'M4TR-9XZB', tautan: '/klinik/riwayat' },
        { sumber: 'santri', sumber_nama: 'Data santri', id: 'mt-1', nomor: 'K.009/IL/PPTQ-IAS/IV/1448', tanggal_surat: hari(-3), jenis_nama: 'Surat Keterangan Pindah', perihal: 'Pindah ke MTs Negeri 1 Gowa',
          kepada: 'Aisyah Nur Rahmah (NIS 2311015)', penanda: null, mode_ttd: 'basah', status: 'terbit', kode_validasi: null, tautan: '/santri' },
        { sumber: 'laporan', sumber_nama: 'Dokumen resmi', id: 'rg-3', nomor: null, tanggal_surat: hari(0), jenis_nama: 'Laporan kehadiran pegawai', perihal: 'Rekap kehadiran pegawai (September 2026)',
          kepada: 'Semua unit', penanda: 'Ust. Abdurrahman Hakim, Lc., M.Ag.', mode_ttd: 'elektronik', status: 'terbit', kode_validasi: 'P2LD-8NCE', tautan: '/rekap/pegawai' },
      ].filter((x) => x.tanggal_surat >= mulai && x.tanggal_surat <= selesai)
      return [...tu, ...lain].sort((a, b) => a.tanggal_surat.localeCompare(b.tanggal_surat))
    },
    dengarkan(fn) {
      if (MODE_DEMO || this.saluran) return
      this.saluran = supabase.channel('persuratan')
        .on('postgres_changes', { event: '*', schema: 'public', table: 'incoming_letters' }, () => fn())
        .on('postgres_changes', { event: '*', schema: 'public', table: 'letter_dispositions' }, () => fn())
        .on('postgres_changes', { event: '*', schema: 'public', table: 'outgoing_letters' }, () => fn()).subscribe()
    },
    berhenti() { if (this.saluran) { supabase.removeChannel(this.saluran); this.saluran = null } },
  },
})
