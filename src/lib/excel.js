// Impor/ekspor Excel dengan SheetJS
import * as XLSX from 'xlsx';
import { tglPendek, dariPendek } from './tanggal';

/** Unduh templat dengan baris judul, contoh, dan lembar petunjuk. */
export function unduhTemplat(namaBerkas, kolom, contoh = [], petunjuk = []) {
  const wb = XLSX.utils.book_new();
  const ws = XLSX.utils.aoa_to_sheet([kolom.map((k) => k.judul), ...contoh.map((c) => kolom.map((k) => c[k.kunci] ?? ''))]);
  ws['!cols'] = kolom.map((k) => ({ wch: Math.max(12, k.judul.length + 2) }));
  XLSX.utils.book_append_sheet(wb, ws, 'Data');
  if (petunjuk.length) {
    const wp = XLSX.utils.aoa_to_sheet([['Petunjuk pengisian'], ...petunjuk.map((p) => [p])]);
    wp['!cols'] = [{ wch: 110 }];
    XLSX.utils.book_append_sheet(wb, wp, 'Petunjuk');
  }
  XLSX.writeFile(wb, namaBerkas);
}

/** Baca berkas Excel/CSV → array objek berdasarkan judul kolom (kunci = kolom.kunci). */
export async function bacaExcel(file, kolom) {
  const wb = XLSX.read(await file.arrayBuffer(), { cellDates: true });
  const ws = wb.Sheets[wb.SheetNames[0]];
  const mentah = XLSX.utils.sheet_to_json(ws, { defval: '', raw: true });
  const peta = Object.fromEntries(kolom.map((k) => [k.judul.toLowerCase().trim(), k.kunci]));
  return mentah.map((r) => {
    const o = {};
    for (const [j, v] of Object.entries(r)) {
      const k = peta[j.toLowerCase().trim()];
      if (k) o[k] = v instanceof Date ? isoDariDate(v) : String(v).trim();
    }
    return o;
  }).filter((o) => Object.values(o).some((v) => v !== ''));
}

const isoDariDate = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;

/** Terima "dd/mm/yyyy", ISO, atau angka seri Excel → ISO. */
export function normalTanggal(v) {
  if (!v) return null;
  if (/^\d{4}-\d{2}-\d{2}$/.test(v)) return v;
  if (/^\d{4,5}$/.test(v)) { const d = XLSX.SSF.parse_date_code(+v); return d ? `${d.y}-${String(d.m).padStart(2, '0')}-${String(d.d).padStart(2, '0')}` : null; }
  return dariPendek(v);
}

/** Ekspor tabel ke .xlsx; kolom: [{judul, kunci, format?, tanggal?:true}] */
export function eksporExcel(namaBerkas, kolom, baris, judulLembar = 'Data') {
  const data = baris.map((b, i) => kolom.map((k) => {
    const v = k.format ? k.format(b[k.kunci], b, i) : b[k.kunci];
    return k.tanggal ? tglPendek(v) : (Array.isArray(v) ? v.join(', ') : v ?? '');
  }));
  const ws = XLSX.utils.aoa_to_sheet([kolom.map((k) => k.judul), ...data]);
  ws['!cols'] = kolom.map((k, i) => ({ wch: Math.min(45, Math.max(k.judul.length, ...data.slice(0, 200).map((r) => String(r[i] ?? '').length)) + 2) }));
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, judulLembar.slice(0, 31));
  XLSX.writeFile(wb, namaBerkas);
}
