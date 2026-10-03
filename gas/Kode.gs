// SIMKA PRO | gas/Kode.gs | v1.2 | Fase 2 – Tahap 6 Verval dan koreksi | 03/10/2026
/**
 * SIMKA PRO · Jembatan Google Apps Script (Gmail pondok: syathiby.gowa@gmail.com)
 * ---------------------------------------------------------------------------
 * Fungsi:
 *   1. doPost            : menerima permintaan kirim email dari Edge Function (dengan rahasia)
 *   2. pemindahBerkas    : tiap 5 menit memindah berkas antrian Supabase Storage → Google Drive
 *   3. heartbeatHarian   : menulis heartbeat ke Supabase + pemeriksaan kesehatan
 *   4. retensiHarian     : membuang foto yang melewati masa simpan (selfie 6 bulan, dll.)
 *   5. backupMingguan    : menyalin tabel penting ke Google Sheets
 *
 * Script Properties (Project Settings → Script properties):
 *   SUPABASE_SERVICE_KEY  service_role key (RAHASIA) → satu-satunya yang diisi manual
 *   SUPABASE_URL, GAS_SECRET, DRIVE_ROOT_ID, EMAIL_PERINGATAN → diisi otomatis oleh aturAwal()
 *
 * Urutan pemasangan (v1.1):
 *   1. Isi SUPABASE_SERVICE_KEY di Script properties.
 *   2. Jalankan aturAwal()     → membuat folder Drive "SIMKA PRO" dan GAS_SECRET.
 *   3. Jalankan ujiKoneksi()   → memeriksa Supabase, Drive, dan kuota email.
 *   4. Jalankan ujiEmail()     → mengirim email uji ke EMAIL_PERINGATAN.
 *   5. Jalankan pasangPemicu() → memasang 4 jadwal otomatis.
 *   6. Deploy → New deployment → Web app (Execute as: Me, Who has access: Anyone).
 *      Salin URL Web app ke Supabase secret GAS_URL; salin GAS_SECRET ke secret GAS_SECRET.
 *
 * Perubahan v1.1: email memakai MailApp (izin lebih sempit), tambah aturAwal() dan ujiEmail().
 * Perubahan v1.2: aksi 'ambil_berkas' agar admin dapat melihat selfie di Drive lewat Edge Function "berkas".
 *   Setelah menempel kode ini: Deploy → Manage deployments → ikon pensil → Version: New version → Deploy
 *   (URL Web app tetap sama, tidak perlu mengubah secret GAS_URL).
 */

// Nilai publik (bukan rahasia)
const SUPABASE_URL_BAWAAN = 'https://xtvoxjnivpugzztoevjh.supabase.co';
const EMAIL_PERINGATAN_BAWAAN = 'syathiby.gowa@gmail.com';
const NAMA_FOLDER_DRIVE = 'SIMKA PRO';

const NAMA_PENGIRIM = 'SIMKA PRO Imam Asy-Syathiby';
const TABEL_BACKUP = ['employees', 'employee_functions', 'employee_structurals', 'employment_history',
  'org_units', 'functional_positions', 'structural_positions', 'feature_grants', 'admin_permissions',
  'institution_settings', 'letterheads', 'signatories', 'signer_rules', 'holidays', 'academic_years',
  'doc_number_formats', 'doc_counters', 'doc_numbers_issued', 'storage_objects'];
const SIMPAN_BACKUP = 8; // jumlah berkas backup mingguan yang disimpan

function prop_(k) {
  const v = PropertiesService.getScriptProperties().getProperty(k);
  if (!v) throw new Error('Script property ' + k + ' belum diisi.');
  return v;
}

// ---------------------------------------------------------------------------
// REST Supabase (service role)
// ---------------------------------------------------------------------------
function sb_(path, opsi) {
  opsi = opsi || {};
  const key = prop_('SUPABASE_SERVICE_KEY');
  const res = UrlFetchApp.fetch(prop_('SUPABASE_URL') + path, {
    method: opsi.method || 'get',
    contentType: 'application/json',
    headers: Object.assign({ apikey: key, Authorization: 'Bearer ' + key, Prefer: 'return=representation' }, opsi.headers || {}),
    payload: opsi.body ? JSON.stringify(opsi.body) : undefined,
    muteHttpExceptions: true,
  });
  const kode = res.getResponseCode();
  if (kode >= 300) throw new Error('Supabase ' + kode + ': ' + res.getContentText().slice(0, 300));
  const teks = res.getContentText();
  return teks ? JSON.parse(teks) : null;
}

function sbBlob_(bucket, kunci) {
  const key = prop_('SUPABASE_SERVICE_KEY');
  const res = UrlFetchApp.fetch(prop_('SUPABASE_URL') + '/storage/v1/object/' + bucket + '/' + encodeURI(kunci), {
    headers: { apikey: key, Authorization: 'Bearer ' + key }, muteHttpExceptions: true,
  });
  if (res.getResponseCode() !== 200) throw new Error('Unduh berkas gagal (' + res.getResponseCode() + ')');
  return res.getBlob();
}

function sbHapusBlob_(bucket, kunci) {
  const key = prop_('SUPABASE_SERVICE_KEY');
  UrlFetchApp.fetch(prop_('SUPABASE_URL') + '/storage/v1/object/' + bucket, {
    method: 'delete', contentType: 'application/json',
    headers: { apikey: key, Authorization: 'Bearer ' + key },
    payload: JSON.stringify({ prefixes: [kunci] }), muteHttpExceptions: true,
  });
}

// ---------------------------------------------------------------------------
// 1. Web app: email
// ---------------------------------------------------------------------------
function doPost(e) {
  let hasil;
  try {
    const d = JSON.parse(e.postData.contents);
    if (d.rahasia !== prop_('GAS_SECRET')) {
      hasil = { ok: false, galat: 'Tidak berwenang' };
    } else if (d.aksi === 'email') {
      if (!d.ke || !d.subjek) throw new Error('Penerima dan subjek wajib diisi');
      MailApp.sendEmail({ to: d.ke, subject: d.subjek, htmlBody: d.html,
        body: 'Buka email ini dengan tampilan HTML.', name: NAMA_PENGIRIM });
      hasil = { ok: true, sisaKuota: MailApp.getRemainingDailyQuota() };
    } else if (d.aksi === 'ambil_berkas') {
      hasil = ambilBerkas_(d.id);
    } else if (d.aksi === 'ping') {
      hasil = { ok: true, waktu: new Date().toISOString(), sisaKuota: MailApp.getRemainingDailyQuota() };
    } else {
      hasil = { ok: false, galat: 'Aksi tidak dikenal' };
    }
  } catch (err) {
    hasil = { ok: false, galat: String(err) };
  }
  return ContentService.createTextOutput(JSON.stringify(hasil)).setMimeType(ContentService.MimeType.JSON);
}

/** Ambil satu berkas di dalam folder SIMKA PRO sebagai base64 (maks. 5 MB). */
function ambilBerkas_(id) {
  if (!id) throw new Error('ID berkas wajib diisi');
  const berkas = DriveApp.getFileById(id);
  // Pastikan berkas berada di bawah folder SIMKA PRO (maks. 6 tingkat)
  const akar = prop_('DRIVE_ROOT_ID');
  let ok = false; let induk = berkas.getParents(); let tingkat = 0;
  while (induk.hasNext() && tingkat < 6 && !ok) {
    const f = induk.next();
    if (f.getId() === akar) { ok = true; break; }
    induk = f.getParents(); tingkat++;
  }
  if (!ok) throw new Error('Berkas di luar folder SIMKA PRO');
  const blob = berkas.getBlob();
  const bita = blob.getBytes();
  if (bita.length > 5 * 1024 * 1024) throw new Error('Berkas terlalu besar untuk ditampilkan');
  return { ok: true, mime: blob.getContentType(), nama: berkas.getName(), data: Utilities.base64Encode(bita) };
}

function doGet() {
  return ContentService.createTextOutput(JSON.stringify({ ok: true, layanan: 'SIMKA PRO GAS' }))
    .setMimeType(ContentService.MimeType.JSON);
}

// ---------------------------------------------------------------------------
// 2. Pemindah berkas (tiap 5 menit)
// ---------------------------------------------------------------------------
function folderJalur_(jalur) {
  // jalur contoh: "SIMKA PRO/Presensi/2026/10" → dibuat di bawah DRIVE_ROOT_ID
  let folder = DriveApp.getFolderById(prop_('DRIVE_ROOT_ID'));
  const bagian = String(jalur || 'SIMKA PRO/Lainnya').split('/').filter(Boolean);
  if (bagian[0] === 'SIMKA PRO') bagian.shift();
  bagian.forEach(function (nama) {
    const it = folder.getFoldersByName(nama);
    folder = it.hasNext() ? it.next() : folder.createFolder(nama);
  });
  return folder;
}

function pemindahBerkas() {
  const kunci = LockService.getScriptLock();
  if (!kunci.tryLock(10000)) return;
  try {
    const antre = sb_('/rest/v1/storage_objects?status=eq.antri&percobaan=lt.5&order=created_at.asc&limit=25');
    antre.forEach(function (b) {
      try {
        const blob = sbBlob_(b.bucket, b.kunci).setName(b.nama_berkas);
        const berkas = folderJalur_(b.folder_tujuan).createFile(blob);
        sb_('/rest/v1/storage_objects?id=eq.' + b.id, { method: 'patch', body: {
          penyedia: 'gdrive', kunci: berkas.getId(), bucket: null, status: 'tersimpan',
          dipindah_pada: new Date().toISOString(), galat: null } });
        sbHapusBlob_(b.bucket, b.kunci);
      } catch (err) {
        sb_('/rest/v1/storage_objects?id=eq.' + b.id, { method: 'patch', body: {
          percobaan: (b.percobaan || 0) + 1, galat: String(err).slice(0, 300),
          status: (b.percobaan || 0) + 1 >= 5 ? 'gagal' : 'antri' } });
      }
    });
    PropertiesService.getScriptProperties().setProperty('PEMINDAH_TERAKHIR', new Date().toISOString());
  } finally {
    kunci.releaseLock();
  }
}

// ---------------------------------------------------------------------------
// 3. Heartbeat dan pemeriksaan kesehatan (harian, dini hari)
// ---------------------------------------------------------------------------
function heartbeatHarian() {
  const masalah = [];
  try {
    sb_('/rest/v1/heartbeat', { method: 'post', body: { sumber: 'gas-harian', catatan: 'Heartbeat harian GAS' } });
  } catch (err) { masalah.push('Heartbeat Supabase gagal: ' + err); }

  const terakhir = PropertiesService.getScriptProperties().getProperty('PEMINDAH_TERAKHIR');
  if (!terakhir || (Date.now() - new Date(terakhir).getTime()) > 60 * 60 * 1000) {
    masalah.push('Pemindah berkas tidak berjalan lebih dari 1 jam (terakhir: ' + (terakhir || 'belum pernah') + ').');
  }
  try {
    const gagal = sb_('/rest/v1/storage_objects?status=eq.gagal&select=id', { headers: { Prefer: 'count=exact' } });
    if (gagal && gagal.length) masalah.push(gagal.length + ' berkas gagal dipindah ke Drive.');
  } catch (err) { masalah.push('Pemeriksaan antrian gagal: ' + err); }
  if (ScriptApp.getProjectTriggers().length < 4) masalah.push('Jumlah pemicu GAS kurang dari 4. Jalankan pasangPemicu().');

  if (masalah.length) {
    MailApp.sendEmail(prop_('EMAIL_PERINGATAN'), '[SIMKA PRO] Peringatan pemeriksaan kesehatan',
      'Pemeriksaan kesehatan harian menemukan masalah:\n\n- ' + masalah.join('\n- ') +
      '\n\nWaktu: ' + Utilities.formatDate(new Date(), 'Asia/Makassar', 'dd/MM/yyyy HH:mm') + ' WITA');
  }
}

// ---------------------------------------------------------------------------
// 4. Retensi berkas (harian)
// ---------------------------------------------------------------------------
function retensiHarian() {
  const hariIni = Utilities.formatDate(new Date(), 'Asia/Makassar', 'yyyy-MM-dd');
  const daftar = sb_('/rest/v1/storage_objects?penyedia=eq.gdrive&status=eq.tersimpan&hapus_setelah=lte.' +
    hariIni + '&limit=200');
  daftar.forEach(function (b) {
    try {
      DriveApp.getFileById(b.kunci).setTrashed(true);
    } catch (err) { /* berkas sudah tidak ada */ }
    sb_('/rest/v1/storage_objects?id=eq.' + b.id, { method: 'patch', body: { status: 'dihapus' } });
  });
}

// ---------------------------------------------------------------------------
// 5. Backup mingguan ke Google Sheets
// ---------------------------------------------------------------------------
function backupMingguan() {
  const folder = folderJalur_('SIMKA PRO/Backup');
  const nama = 'Backup SIMKA PRO ' + Utilities.formatDate(new Date(), 'Asia/Makassar', 'yyyy-MM-dd');
  const ss = SpreadsheetApp.create(nama);
  DriveApp.getFileById(ss.getId()).moveTo(folder);

  TABEL_BACKUP.forEach(function (tabel, i) {
    let baris = [], dari = 0;
    while (true) {
      const potong = sb_('/rest/v1/' + tabel + '?select=*', { headers: { Range: dari + '-' + (dari + 999) } });
      baris = baris.concat(potong);
      if (potong.length < 1000) break;
      dari += 1000;
    }
    const sheet = i === 0 ? ss.getSheets()[0].setName(tabel) : ss.insertSheet(tabel);
    if (!baris.length) { sheet.getRange(1, 1).setValue('(kosong)'); return; }
    const kolom = Object.keys(baris[0]);
    const nilai = [kolom].concat(baris.map(function (r) {
      return kolom.map(function (k) {
        const v = r[k];
        return v === null ? '' : (typeof v === 'object' ? JSON.stringify(v) : v);
      });
    }));
    sheet.getRange(1, 1, nilai.length, kolom.length).setValues(nilai);
    sheet.setFrozenRows(1);
  });

  // simpan 8 backup terakhir
  const semua = [];
  const it = folder.getFiles();
  while (it.hasNext()) { const f = it.next(); if (f.getName().indexOf('Backup SIMKA PRO') === 0) semua.push(f); }
  semua.sort(function (a, b) { return b.getDateCreated() - a.getDateCreated(); });
  semua.slice(SIMPAN_BACKUP).forEach(function (f) { f.setTrashed(true); });
  sb_('/rest/v1/heartbeat', { method: 'post', body: { sumber: 'gas-backup', catatan: nama } });
}

// ---------------------------------------------------------------------------
// Pemasangan pemicu (jalankan satu kali)
// ---------------------------------------------------------------------------
function pasangPemicu() {
  ScriptApp.getProjectTriggers().forEach(function (t) { ScriptApp.deleteTrigger(t); });
  ScriptApp.newTrigger('pemindahBerkas').timeBased().everyMinutes(5).create();
  ScriptApp.newTrigger('heartbeatHarian').timeBased().atHour(2).everyDays(1).inTimezone('Asia/Makassar').create();
  ScriptApp.newTrigger('retensiHarian').timeBased().atHour(3).everyDays(1).inTimezone('Asia/Makassar').create();
  ScriptApp.newTrigger('backupMingguan').timeBased().onWeekDay(ScriptApp.WeekDay.SUNDAY).atHour(1)
    .inTimezone('Asia/Makassar').create();
  Logger.log('Pemicu terpasang: ' + ScriptApp.getProjectTriggers().length);
}

/** Langkah 2: isi otomatis properti selain service key, buat folder Drive dan GAS_SECRET. */
function aturAwal() {
  const p = PropertiesService.getScriptProperties();
  if (!p.getProperty('SUPABASE_SERVICE_KEY')) {
    throw new Error('Isi dulu SUPABASE_SERVICE_KEY di Project Settings → Script properties.');
  }
  p.setProperty('SUPABASE_URL', SUPABASE_URL_BAWAAN);
  if (!p.getProperty('EMAIL_PERINGATAN')) p.setProperty('EMAIL_PERINGATAN', EMAIL_PERINGATAN_BAWAAN);

  if (!p.getProperty('DRIVE_ROOT_ID')) {
    const it = DriveApp.getRootFolder().getFoldersByName(NAMA_FOLDER_DRIVE);
    const folder = it.hasNext() ? it.next() : DriveApp.getRootFolder().createFolder(NAMA_FOLDER_DRIVE);
    p.setProperty('DRIVE_ROOT_ID', folder.getId());
  }
  if (!p.getProperty('GAS_SECRET')) {
    p.setProperty('GAS_SECRET', (Utilities.getUuid() + Utilities.getUuid()).replace(/-/g, ''));
  }
  Logger.log('Folder Drive  : ' + DriveApp.getFolderById(p.getProperty('DRIVE_ROOT_ID')).getUrl());
  Logger.log('GAS_SECRET    : ' + p.getProperty('GAS_SECRET'));
  Logger.log('Salin GAS_SECRET di atas ke Supabase → Edge Functions → Secrets (nama: GAS_SECRET).');
}

/** Langkah 4: kirim email uji ke EMAIL_PERINGATAN. */
function ujiEmail() {
  MailApp.sendEmail({
    to: prop_('EMAIL_PERINGATAN'), subject: '[SIMKA PRO] Email uji',
    htmlBody: '<p>Assalamu\'alaikum. Jembatan email SIMKA PRO sudah berfungsi.</p><p>Waktu: ' +
      Utilities.formatDate(new Date(), 'Asia/Makassar', 'dd/MM/yyyy HH:mm') + ' WITA</p>',
    name: NAMA_PENGIRIM,
  });
  Logger.log('Email uji terkirim ke ' + prop_('EMAIL_PERINGATAN') + '. Sisa kuota: ' + MailApp.getRemainingDailyQuota());
}

/** Langkah 3: uji cepat setelah aturAwal(). */
function ujiKoneksi() {
  Logger.log('Supabase: ' + JSON.stringify(sb_('/rest/v1/heartbeat?select=id&limit=1')));
  Logger.log('Folder Drive: ' + DriveApp.getFolderById(prop_('DRIVE_ROOT_ID')).getName());
  Logger.log('Sisa kuota email hari ini: ' + MailApp.getRemainingDailyQuota());
}
