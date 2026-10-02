// Penanda tangan dokumen (tabel signatories, diatur superadmin di menu Pengaturan).
import { supabase, MODE_DEMO } from './supabase'

const BAWAAN = { jabatan: 'Direktur', nama: 'Siswandi Safari, S.Pd.I., Lc., S.H., M.Ag.', niy: '1983020910201401' }

/** Ambil penanda tangan berdasarkan jabatan tertulis (bawaan: Direktur). */
export async function ambilPenandaTangan(jabatan = 'Direktur') {
  if (MODE_DEMO) return BAWAAN
  const { data } = await supabase.from('signatories').select('jabatan_tertulis, nama, niy')
    .eq('aktif', true).ilike('jabatan_tertulis', jabatan).order('urutan').limit(1).maybeSingle()
  return data ? { jabatan: data.jabatan_tertulis, nama: data.nama, niy: data.niy } : BAWAAN
}
