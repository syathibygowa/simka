// Adapter penyimpanan berkas (Bagian 39 & 41).
// Database menyimpan PENYEDIA + KUNCI berkas, bukan tautan Drive langsung.
// Alur: kompres di HP → unggah ke bucket "antrian" → catat storage_objects(status antri)
//       → GAS memindah ke Google Drive setiap 5 menit → penyedia berubah menjadi gdrive.
import { supabase } from './supabase';
import { useSesi } from '@/stores/sesi';
const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL;
const idSaya = () => useSesi().pengguna?.id;

/** Nama berkas rapi: spasi dan karakter khusus dihapus. */
export function namaRapi(...bagian) {
  return bagian.filter(Boolean).map((b) => String(b).normalize('NFKD').replace(/[^A-Za-z0-9-]/g, '')).join('-');
}

/** Kompres gambar ke JPEG (maks sisi panjang, kualitas). Opsional rasio potong (3:4 untuk foto profil). */
export async function kompresGambar(file, { maks = 720, kualitas = 0.6, rasio = null } = {}) {
  const bmp = await createImageBitmap(file);
  let sx = 0, sy = 0, sw = bmp.width, sh = bmp.height;
  if (rasio) {
    const target = rasio[0] / rasio[1];
    if (sw / sh > target) { const w = sh * target; sx = (sw - w) / 2; sw = w; } else { const h = sw / target; sy = (sh - h) / 2; sh = h; }
  }
  const skala = Math.min(1, maks / Math.max(sw, sh));
  const c = document.createElement('canvas');
  c.width = Math.round(sw * skala); c.height = Math.round(sh * skala);
  c.getContext('2d').drawImage(bmp, sx, sy, sw, sh, 0, 0, c.width, c.height);
  return await new Promise((r) => c.toBlob(r, 'image/jpeg', kualitas));
}

/**
 * Unggah ke antrian Drive.
 * @param {Blob} blob
 * @param {{nama:string, kategori:string, folder:string, retensiHari?:number}} o
 *   folder contoh: 'SIMKA PRO/Pengajuan/2026/10'
 */
export async function unggahKeDrive(blob, o) {
  const pemilik = idSaya();
  if (!pemilik) throw new Error('Sesi tidak ditemukan.');
  const kunci = `${pemilik}/${Date.now()}-${o.nama}`;
  const { error } = await supabase.storage.from('antrian').upload(kunci, blob, { contentType: blob.type, upsert: false });
  if (error) throw error;
  const hapus = o.retensiHari ? new Date(Date.now() + o.retensiHari * 86400000).toISOString().slice(0, 10) : null;
  const { data, error: e2 } = await supabase.from('storage_objects').insert({
    penyedia: 'supabase', bucket: 'antrian', kunci, nama_berkas: o.nama, mime: blob.type, ukuran: blob.size,
    kategori: o.kategori, folder_tujuan: o.folder, status: 'antri', hapus_setelah: hapus, pemilik_id: pemilik,
  }).select('id').single();
  if (e2) throw e2;
  return data.id;
}

/** Unggah langsung ke Supabase Storage (logo/kop: bucket publik; foto profil: bucket profil). */
export async function unggahSupabase(blob, { bucket, path, kategori, publik = false }) {
  const { error } = await supabase.storage.from(bucket).upload(path, blob, { contentType: blob.type, upsert: true });
  if (error) throw error;
  const { data, error: e2 } = await supabase.from('storage_objects').insert({
    penyedia: 'supabase', bucket, kunci: path, nama_berkas: path.split('/').pop(), mime: blob.type,
    ukuran: blob.size, kategori, status: 'tersimpan', publik, pemilik_id: idSaya(),
  }).select('id').single();
  if (e2) throw e2;
  return { id: data.id, url: publik ? `${SUPABASE_URL}/storage/v1/object/public/${bucket}/${path}` : null };
}

/** Alamat untuk menampilkan berkas berdasarkan penyedianya. */
export async function alamatBerkas(id) {
  if (!id) return null;
  const { data: o } = await supabase.from('storage_objects').select('*').eq('id', id).maybeSingle();
  if (!o) return null;
  if (o.penyedia === 'supabase') {
    if (o.publik) return `${SUPABASE_URL}/storage/v1/object/public/${o.bucket}/${o.kunci}`;
    const { data } = await supabase.storage.from(o.bucket).createSignedUrl(o.kunci, 600);
    return data?.signedUrl || null;
  }
  // gdrive: tautan sementara dilayani GAS setelah hak akses diperiksa (Fase 3, berkas pegawai)
  return null;
}

/** Alamat aset statis aplikasi (kop bawaan /kop/*.jpg) atau URL penuh. */
export function alamatAset(u) {
  if (!u) return '';
  if (/^(https?:|data:|blob:)/.test(u)) return u;
  return new URL(u, document.baseURI).href;
}
