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
 * Script Properties (Project Settings → Script properties) — JANGAN ditulis di kode:
 *   SUPABASE_URL          https://xxxx.supabase.co
 *   SUPABASE_SERVICE_KEY  service_role key (rahasia)
 *   GAS_SECRET            rahasia bersama dengan Edge Function (sama dengan secret GAS_SECRET)
 *   DRIVE_ROOT_ID         ID folder Drive "SIMKA PRO"
 *   EMAIL_PERINGATAN      syathiby.gowa@gmail.com
 *
 * Pemasangan: jalankan pasangPemicu() satu kali, lalu Deploy → New deployment → Web app
 *   Execute as: Me · Who has access: Anyone. Salin URL Web app ke secret GAS_URL.
 */

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
      GmailApp.sendEmail(d.ke, d.subjek, 'Buka email ini dengan tampilan HTML.', {
        htmlBody: d.html, name: NAMA_PENGIRIM, noReply: false,
      });
      hasil = { ok: true, sisaKuota: MailApp.getRemainingDailyQuota() };
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

/** Uji cepat setelah Script Properties diisi. */
function ujiKoneksi() {
  Logger.log('Supabase: ' + JSON.stringify(sb_('/rest/v1/heartbeat?select=id&limit=1')));
  Logger.log('Folder Drive: ' + DriveApp.getFolderById(prop_('DRIVE_ROOT_ID')).getName());
  Logger.log('Sisa kuota email hari ini: ' + MailApp.getRemainingDailyQuota());
}
