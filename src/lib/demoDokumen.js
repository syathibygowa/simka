// SIMKA PRO | src/lib/demoDokumen.js | v1.0 | Fase 8 – Tahap 1 Registri dokumen dan Cek Keabsahan | 10/10/2026
// Data contoh registri dokumen untuk mode demo (pratinjau tampilan tanpa server).
const jam = (h) => new Date(Date.now() - h * 3600000).toISOString()
export const DOKUMEN_DEMO = [
  { id: 'dk1', kode: '7KQ2-M9XA', jenis: 'pengajuan_pegawai', jenis_nama: 'Surat Izin', nomor: 'D.014/AM/PPTQ-IAS/IV/1448', perihal: 'Izin 2 hari, 13/10/2026 s.d. 14/10/2026',
    subjek: 'Ust. Hasan Basri, Lc.', status: 'sah', diterbitkan_pada: jam(20), ref_tabel: 'leave_requests', jumlah_cek: 2, terakhir_dicek: jam(3),
    penanda: [{ nama: 'Ust. Muhammad Ikhsan, S.Pd.I.', jabatan: 'Kepala Bidang Tahfizh', status: 'ditandatangani', waktu: jam(22), posisi: 'kiri' },
      { nama: 'Siswandi Safari, S.Pd.I., Lc., S.H., M.Ag.', jabatan: 'Direktur', status: 'ditandatangani', waktu: jam(20), posisi: 'kiri' },
      { nama: 'Ust. Hasan Basri, Lc.', jabatan: 'Pemohon', status: 'ditandatangani', waktu: jam(30), posisi: 'kanan' }] },
  { id: 'dk2', kode: 'P4TZ-8QWE', jenis: 'surat_sakit', jenis_nama: 'Surat Keterangan Sakit', nomor: 'SKS.007/KLINIK/IV/1448', perihal: 'Istirahat sakit 09/10/2026 s.d. 11/10/2026',
    subjek: 'Muhammad Rizki (NIS 2511003)', status: 'sah', diterbitkan_pada: jam(40), ref_tabel: 'clinic_letters', jumlah_cek: 0,
    penanda: [{ nama: 'Ustzh. Fatimah Az-Zahra, A.Md.Kep.', jabatan: 'Petugas Klinik', status: 'ditandatangani', waktu: jam(40), posisi: 'kanan' }] },
  { id: 'dk3', kode: 'N6GT-4YH2', jenis: 'pengajuan_pegawai', jenis_nama: 'Surat Cuti tahunan', nomor: 'D.009/AM/PPTQ-IAS/IV/1448', perihal: 'Cuti tahunan 3 hari, 01/10/2026 s.d. 03/10/2026',
    subjek: 'Ustzh. Nurul Aini, S.Pd.', status: 'dicabut', diterbitkan_pada: jam(260), dicabut_pada: jam(200), alasan_cabut: 'Pengajuan dibatalkan', ref_tabel: 'leave_requests', jumlah_cek: 1,
    penanda: [{ nama: 'Siswandi Safari, S.Pd.I., Lc., S.H., M.Ag.', jabatan: 'Direktur', status: 'ditandatangani', waktu: jam(260), posisi: 'kiri' }] },
]
