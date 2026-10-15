<!-- SIMKA PRO | src/pages/audit/AuditLog.vue | v2.0 | Perbaikan 13.6.0: khusus superadmin, kartu statistik kategori sebagai saringan | 15/10/2026 -->
<script setup>
// Audit log 30 hari terakhir, KHUSUS SUPERADMIN (server juga menolak akun lain).
// Kartu statistik per kategori aktivitas sekaligus menjadi saringan; saring tanggal, pelaku, dan jenis data;
// rincian perubahan per kolom; ekspor Excel; cetak F4 mendatar. Log lebih dari 3 bulan dihapus otomatis (pg_cron).
import { ref, computed, onMounted, watch } from 'vue'
import * as XLSX from 'xlsx'
import { PhPlusCircle, PhPencilSimpleLine, PhMinusCircle, PhLightning, PhMagnifyingGlass, PhEye, PhFileXls, PhArrowClockwise, PhInfo, PhListBullets, PhLockSimple } from '@phosphor-icons/vue'
import { KATEGORI_AUDIT, KATEGORI_LAIN, kategoriTabel, tabelKategori } from '@/lib/audit'
import { useAudit } from '@/stores/audit'
import { usePegawai } from '@/stores/pegawai'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { hariIniISO, formatPanjang, formatPendek, formatWaktu, formatJam } from '@/lib/tanggal'
import { tambahHari } from '@/lib/shift'
import InputTanggal from '@/components/InputTanggal.vue'
import LembarBawah from '@/components/LembarBawah.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'

const audit = useAudit(); const peg = usePegawai(); const sesi = useSesi(); const ui = useUI()
const semua = computed(() => sesi.isSuperadmin)
const mulai = ref(tambahHari(hariIniISO(), -6)); const akhir = ref(hariIniISO())
const pelaku = ref(''); const tabel = ref(''); const kategori = ref(''); const cari = ref(''); const pilih = ref(null); const pratinjau = ref(false)

const TABEL = {
  employees: 'Data pegawai', employee_functions: 'Jabatan fungsional pegawai', employee_structurals: 'Jabatan struktural pegawai',
  employee_schedules: 'Jadwal presensi pegawai', feature_grants: 'Hak akses fitur', admin_permissions: 'Izin admin',
  institution_settings: 'Pengaturan lembaga', letterheads: 'Kop surat', signatories: 'Penanda tangan', signer_rules: 'Aturan penanda tangan',
  org_units: 'Struktur organisasi', functional_positions: 'Jabatan fungsional', structural_positions: 'Jabatan struktural',
  doc_number_formats: 'Penomoran dokumen', letter_subject_codes: 'Kode perihal surat', holidays: 'Hari libur', holiday_calendars: 'Kalender libur',
  academic_years: 'Tahun ajaran', salary_rates: 'Tarif tunjangan', gps_points: 'Titik GPS', task_patterns: 'Pola tugas presensi',
  pattern_sessions: 'Sesi presensi', shift_rosters: 'Jadwal shift', shift_swaps: 'Tukar shift', announcements: 'Pengumuman',
  gaji: 'Gaji (periode, komponen, slip)', salary_decisions: 'Penetapan gaji yayasan', employee_loans: 'Pinjaman pegawai', loan_payments: 'Pembayaran pinjaman',
  savings_programs: 'Program simpanan', savings_members: 'Anggota simpanan', savings_transactions: 'Transaksi simpanan', employee_bank_accounts: 'Rekening gaji pegawai',
  payroll_slip_requests: 'Permintaan slip gaji', sensitive_access: 'Akses fitur sensitif', fee_types: 'Jenis biaya santri', fee_rates: 'Tarif biaya santri',
  fee_subsidies: 'Subsidi santri', bills: 'Tagihan santri', payments: 'Pembayaran santri', payment_items: 'Rincian pembayaran santri', billing_letters: 'Surat tagihan santri',
  students: 'Data santri', student_contacts: 'Kontak wali santri', student_groups: 'Kelompok santri', group_keepers: 'Pengasuh kelompok', group_members: 'Anggota kelompok',
  student_permits: 'Perizinan santri', student_achievements: 'Prestasi santri', student_cards: 'Kartu santri', gate_logs: 'Catatan gerbang', guest_logs: 'Buku tamu',
  parcels: 'Titipan', parent_visits: 'Kunjungan wali', clinic_staff: 'Petugas klinik', guardian_sessions: 'Sesi Portal Wali', guardian_login_attempts: 'Percobaan masuk Portal Wali',
  guardian_announcements: 'Pengumuman wali', teaching_assignments: 'Penugasan mengajar', grade_periods: 'Periode nilai', grade_columns: 'Kolom nilai', grade_finals: 'Nilai rapor',
  grade_change_requests: 'Permintaan ubah nilai', report_settings: 'Ketentuan rapor', report_notes: 'Catatan rapor', report_decisions: 'Keputusan kenaikan', student_tahfizh: 'Data tahfizh santri',
  tahfizh_exams: 'Ujian tahfizh', tahfizh_documents: 'Dokumen tahfizh', juz_proposals: 'Usulan ujian juz', juz_achievements: 'Capaian juz', monthly_achievements: 'Capaian bulanan',
  utas_results: 'Hasil UTAS', letter_templates: 'Templat surat', incoming_letters: 'Surat masuk', outgoing_letters: 'Surat keluar', letter_dispositions: 'Disposisi surat',
  wa_templates: 'Templat WA', employee_documents: 'Berkas pegawai', employee_data_requests: 'Permintaan ubah data pegawai', acting_assignments: 'Penunjukan Plt',
  employee_groups: 'Kelompok pegawai', employee_group_members: 'Anggota kelompok pegawai', employee_cards: 'Kartu pegawai', employee_workloads: 'Beban kerja pegawai',
  workload_components: 'Komponen beban kerja', journal_items: 'Butir jurnal harian', agendas: 'Agenda', holiday_periods: 'Masa libur santri', leave_types: 'Jenis cuti',
}
const AKSI = {
  tambah: { n: 'Menambah', i: PhPlusCircle, w: 'presensi' }, ubah: { n: 'Mengubah', i: PhPencilSimpleLine, w: 'pegawai' },
  hapus: { n: 'Menghapus', i: PhMinusCircle, w: 'beranda' },
}
const aksiDari = (a) => AKSI[a] || { n: a === 'impor_pegawai' ? 'Mengimpor' : a.replace(/_/g, ' '), i: PhLightning, w: 'tahfizh' }
const namaTabel = (t) => TABEL[t] || (t ? t.replace(/_/g, ' ') : 'Sistem')
const KOLOM = { nama_lengkap: 'Nama lengkap', status_akun: 'Status akun', status_keaktifan: 'Status keaktifan', peran: 'Peran', org_unit_id: 'Bidang/unit', no_hp: 'Nomor HP',
  jenis_kelamin: 'Jenis kelamin', tmt_tugas: 'TMT tugas', status_kepegawaian: 'Status kepegawaian', pendidikan_terakhir: 'Pendidikan', judul: 'Judul', isi: 'Isi', nama: 'Nama', nilai: 'Nilai', aktif: 'Aktif' }
const namaKolom = (k) => KOLOM[k] || k.replace(/_/g, ' ')

onMounted(async () => { if (!semua.value) return; if (!peg.daftar.length) peg.muat(); muat() })
/** Jenis data yang dikirim ke server: satu jenis terpilih, atau semua jenis dalam kategori terpilih. */
const saringTabel = computed(() => {
  if (tabel.value) return [tabel.value]
  if (!kategori.value) return []
  const t = tabelKategori(kategori.value, audit.ringkasan)
  return t.length ? t : ['__tidak_ada__']
})
async function muat() {
  if (!semua.value) return
  if (akhir.value < mulai.value) return ui.toast('Tanggal akhir tidak boleh sebelum tanggal mulai.', 'galat')
  try { await audit.muat({ mulai: mulai.value, akhir: akhir.value, pegawai: pelaku.value, tabel: saringTabel.value, batas: 1000 }) } catch (e) { ui.toast(e.message, 'galat') }
}
watch([mulai, akhir, pelaku], muat)
watch(saringTabel, (b, l) => { if (JSON.stringify(b) !== JSON.stringify(l)) muat() })
function pilihKategori(k) { tabel.value = ''; kategori.value = kategori.value === k ? '' : k }

// ---------- Kartu statistik per kategori (jumlah dari ringkasan server, bukan dari daftar yang dibatasi) ----------
const statistik = computed(() => {
  const per = {}; let total = 0; const aksi = { tambah: 0, ubah: 0, hapus: 0, lain: 0 }
  for (const r of audit.ringkasan) {
    const k = kategoriTabel(r.tabel); per[k] = (per[k] || 0) + r.jumlah; total += r.jumlah
    aksi[aksi[r.aksi] !== undefined ? r.aksi : 'lain'] += r.jumlah
  }
  const kart = [...KATEGORI_AUDIT, KATEGORI_LAIN].map((k) => ({ ...k, jumlah: per[k.k] || 0 })).filter((k) => k.jumlah || k.k !== 'lain')
  return { total, aksi, kart }
})
const kategoriAktif = computed(() => [...KATEGORI_AUDIT, KATEGORI_LAIN].find((k) => k.k === kategori.value))
/** Pilihan jenis data: mengikuti kategori terpilih. */
const pilihanTabel = computed(() => Object.entries(TABEL).filter(([k]) => !kategori.value || kategoriTabel(k) === kategori.value))
const batasAwal = computed(() => tambahHari(hariIniISO(), -29))

const judulBaris = (r) => {
  if (r.aksi === 'impor_pegawai') return r.ringkasan || 'Impor data pegawai'
  const nama = r.data?.nama_lengkap?.baru ?? r.data?.nama_lengkap ?? r.data?.judul?.baru ?? r.data?.judul ?? r.data?.nama?.baru ?? r.data?.nama
  return `${aksiDari(r.aksi).n} ${namaTabel(r.tabel).toLowerCase()}${typeof nama === 'string' ? ': ' + nama : ''}`
}
/** Rincian perubahan: untuk "ubah" berupa {kolom: {lama, baru}}, selain itu data lengkap baris. */
const rincian = (r) => {
  if (!r?.data || typeof r.data !== 'object') return []
  if (r.aksi === 'ubah') return Object.entries(r.data).map(([k, v]) => ({ k: namaKolom(k), lama: tampilNilai(v?.lama), baru: tampilNilai(v?.baru) }))
  return Object.entries(r.data).filter(([k]) => !['id', 'created_at'].includes(k)).map(([k, v]) => ({ k: namaKolom(k), baru: tampilNilai(v) }))
}
function tampilNilai(v) {
  if (v == null || v === '') return '–'
  if (typeof v === 'boolean') return v ? 'Ya' : 'Tidak'
  if (typeof v === 'object') return JSON.stringify(v).slice(0, 160)
  if (/^\d{4}-\d{2}-\d{2}T/.test(v)) return formatWaktu(v)
  if (/^\d{4}-\d{2}-\d{2}$/.test(v)) return formatPendek(v)
  return String(v)
}
const tampil = computed(() => {
  const q = cari.value.toLowerCase().trim()
  return audit.daftar.filter((r) => !q || [judulBaris(r), r.pelaku, JSON.stringify(r.data || '')].join(' ').toLowerCase().includes(q))
})
const ringkasUbah = (r) => (r.aksi === 'ubah' && r.data ? Object.keys(r.data).map(namaKolom).slice(0, 4).join(', ') + (Object.keys(r.data).length > 4 ? ', …' : '') : '')

function ekspor() {
  const kolom = ['No.', 'Waktu', 'Pelaku', 'Aktivitas', 'Jenis data', 'Rincian']
  const data = tampil.value.map((r, i) => [i + 1, formatWaktu(r.created_at), r.pelaku, judulBaris(r), namaTabel(r.tabel),
    rincian(r).map((x) => (x.lama !== undefined ? `${x.k}: ${x.lama} → ${x.baru}` : `${x.k}: ${x.baru}`)).join('; ').slice(0, 30000)])
  const ws = XLSX.utils.aoa_to_sheet([kolom, ...data]); ws['!cols'] = [{ wch: 5 }, { wch: 17 }, { wch: 28 }, { wch: 46 }, { wch: 24 }, { wch: 80 }]
  const wb = XLSX.utils.book_new(); XLSX.utils.book_append_sheet(wb, ws, 'Audit log')
  XLSX.writeFile(wb, `Audit-Log-${formatPendek(mulai.value).replace(/\//g, '-')}_sd_${formatPendek(akhir.value).replace(/\//g, '-')}.xlsx`)
}
const namaPelaku = computed(() => (pelaku.value ? peg.cari(pelaku.value)?.nama_lengkap : semua.value ? 'Semua pegawai' : sesi.pengguna?.nama_lengkap))
</script>
<template>
  <div v-if="!semua" class="kartu w-audit mx-auto flex max-w-md flex-col items-center gap-2 p-8 text-center">
    <span class="chip-ikon h-14 w-14 rounded-2xl"><PhLockSimple :size="30" weight="duotone" /></span>
    <p class="font-bold">Audit log khusus superadmin</p>
    <p class="text-sm text-teks3">Catatan aktivitas seluruh akun hanya dapat dibuka oleh superadmin.</p>
  </div>
  <div v-else class="w-audit">
    <div class="layar-saja">
      <p class="mb-3 flex gap-2 text-sm text-teks3"><PhInfo :size="18" class="mt-0.5 shrink-0" />
        Aktivitas seluruh akun selama 30 hari terakhir. Audit log hanya dapat dibuka superadmin; log yang berumur lebih dari 3 bulan dihapus otomatis.</p>

      <!-- Kartu statistik kategori (ketuk untuk menyaring) -->
      <section class="mb-4 grid grid-cols-2 gap-3 sm:grid-cols-3 xl:grid-cols-5" aria-label="Kategori aktivitas">
        <button type="button" :class="['kartu-kat w-audit', !kategori && 'aktif']" :aria-pressed="!kategori" @click="pilihKategori('')">
          <span class="chip-padat"><PhListBullets :size="20" weight="fill" /></span>
          <span class="angka">{{ statistik.total.toLocaleString('id-ID') }}</span>
          <span class="judul">Semua aktivitas</span>
          <span class="ket">+{{ statistik.aksi.tambah }} · ubah {{ statistik.aksi.ubah }} · hapus {{ statistik.aksi.hapus }}</span>
        </button>
        <button v-for="k in statistik.kart" :key="k.k" type="button" :class="['kartu-kat', 'w-' + k.w, kategori === k.k && 'aktif', !k.jumlah && 'kosong']"
          :aria-pressed="kategori === k.k" @click="pilihKategori(k.k)">
          <span class="chip-padat"><component :is="k.ikon" :size="20" weight="fill" /></span>
          <span class="angka">{{ k.jumlah.toLocaleString('id-ID') }}</span>
          <span class="judul">{{ k.n }}</span>
          <span class="ket">{{ statistik.total ? Math.round((k.jumlah * 100) / statistik.total) : 0 }}% dari semua aktivitas</span>
        </button>
      </section>
      <div class="kartu mb-4 grid gap-3 p-4 sm:grid-cols-2 lg:grid-cols-4">
        <InputTanggal v-model="mulai" label="Dari tanggal" />
        <InputTanggal v-model="akhir" label="Sampai tanggal" />
        <div v-if="semua"><label class="label-isian" for="au-pelaku">Pelaku</label>
          <select id="au-pelaku" v-model="pelaku" class="isian"><option value="">Semua pegawai</option>
            <option v-for="p in peg.daftar.filter((x) => x.status_akun === 'aktif')" :key="p.id" :value="p.id">{{ p.nama_lengkap }}</option></select></div>
        <div><label class="label-isian" for="au-tabel">Jenis data</label>
          <select id="au-tabel" v-model="tabel" class="isian"><option value="">{{ kategoriAktif ? 'Semua jenis ' + kategoriAktif.n.toLowerCase() : 'Semua jenis' }}</option>
            <option v-for="[k, n] in pilihanTabel" :key="k" :value="k">{{ n }}</option></select></div>
        <div :class="semua ? 'sm:col-span-2 lg:col-span-4' : 'sm:col-span-2'"><label class="label-isian" for="au-cari">Cari</label>
          <div class="relative"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-teks3" />
            <input id="au-cari" v-model="cari" class="isian pl-10" placeholder="Nama, aktivitas, atau isi perubahan" /></div></div>
      </div>
      <p v-if="mulai < batasAwal" class="mb-3 text-sm font-semibold text-teks2">Catatan: hanya 30 hari terakhir yang ditampilkan (sejak {{ formatPanjang(batasAwal) }}).</p>
      <div class="mb-3 flex flex-wrap items-center gap-2">
        <button class="tombol-garis" @click="pratinjau = true"><PhEye :size="20" weight="duotone" /> Pratinjau cetak</button>
        <button class="tombol-garis" @click="ekspor"><PhFileXls :size="20" weight="duotone" /> Ekspor Excel</button>
        <button class="tombol-garis" :disabled="audit.memuat" @click="muat"><PhArrowClockwise :size="20" /> Muat ulang</button>
        <span class="ml-auto text-sm font-semibold text-teks3">{{ tampil.length }} aktivitas<template v-if="kategoriAktif"> · {{ kategoriAktif.n }}</template></span>
      </div>

      <p v-if="audit.memuat" class="py-8 text-center text-teks3">Memuat audit log…</p>
      <ul v-else class="kartu divide-y divide-garis">
        <li v-for="r in tampil" :key="r.id">
          <button type="button" class="flex w-full items-start gap-3 p-3.5 text-left hover:bg-permukaan2" @click="pilih = r">
            <span :class="['chip-ikon h-10 w-10 shrink-0', 'w-' + aksiDari(r.aksi).w]"><component :is="aksiDari(r.aksi).i" :size="22" weight="duotone" /></span>
            <span class="min-w-0 flex-1">
              <span class="block font-semibold leading-snug">{{ judulBaris(r) }}</span>
              <span v-if="ringkasUbah(r)" class="block truncate text-sm text-teks2">Kolom: {{ ringkasUbah(r) }}</span>
              <span class="block text-xs text-teks3">{{ r.pelaku }} · {{ formatPendek(r.created_at) }} pukul {{ formatJam(r.created_at) }}</span>
            </span>
          </button>
        </li>
        <li v-if="!tampil.length" class="p-8 text-center text-teks3">Tidak ada aktivitas pada rentang ini.</li>
      </ul>
    </div>

    <LembarBawah :model-value="!!pilih" @update:model-value="(v) => !v && (pilih = null)" judul="Rincian aktivitas">
      <div v-if="pilih" class="pb-2">
        <p class="font-bold">{{ judulBaris(pilih) }}</p>
        <p class="text-sm text-teks3">{{ pilih.pelaku }} · {{ formatWaktu(pilih.created_at) }} WITA · {{ namaTabel(pilih.tabel) }}</p>
        <div class="mt-3 overflow-x-auto rounded-xl border border-garis">
          <table class="w-full text-sm">
            <thead><tr class="border-b border-garis bg-permukaan2 text-left"><th class="p-2.5">Kolom</th><th v-if="pilih.aksi === 'ubah'" class="p-2.5">Sebelum</th><th class="p-2.5">{{ pilih.aksi === 'ubah' ? 'Sesudah' : 'Nilai' }}</th></tr></thead>
            <tbody>
              <tr v-for="x in rincian(pilih)" :key="x.k" class="border-b border-garis last:border-0 align-top">
                <td class="p-2.5 font-semibold">{{ x.k }}</td><td v-if="pilih.aksi === 'ubah'" class="break-all p-2.5 text-teks2">{{ x.lama }}</td><td class="break-all p-2.5">{{ x.baru }}</td></tr>
              <tr v-if="!rincian(pilih).length"><td colspan="3" class="p-3 text-teks3">{{ pilih.ringkasan || 'Tidak ada rincian.' }}</td></tr>
            </tbody>
          </table>
        </div>
      </div>
    </LembarBawah>

    <DokumenCetak v-model:pratinjau="pratinjau" mendatar judul="Audit Log Aktivitas Pengguna" :subjudul="`${formatPanjang(mulai)} s.d. ${formatPanjang(akhir)} · ${namaPelaku}${kategoriAktif ? ' · ' + kategoriAktif.n : ''}`" :pencetak="sesi.pengguna?.nama_lengkap">
      <table class="tabel">
        <colgroup><col style="width:4%"><col style="width:13%"><col style="width:18%"><col style="width:27%"><col style="width:38%"></colgroup>
        <thead><tr><th>No.</th><th>Waktu</th><th>Pelaku</th><th>Aktivitas</th><th>Rincian perubahan</th></tr></thead>
        <tbody><tr v-for="(r, i) in tampil" :key="r.id">
          <td class="tengah">{{ i + 1 }}</td><td>{{ formatWaktu(r.created_at) }}</td><td>{{ r.pelaku }}</td><td>{{ judulBaris(r) }}</td>
          <td>{{ rincian(r).slice(0, 6).map((x) => (x.lama !== undefined ? `${x.k}: ${x.lama} → ${x.baru}` : `${x.k}: ${x.baru}`)).join('; ') }}</td></tr></tbody>
      </table>
      <template #ttd>
        <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: 'Superadmin SIMKA PRO', nama: '' }" :kanan="{ jabatan: 'Pencetak', nama: sesi.pengguna?.nama_lengkap || '' }" />
      </template>
    </DokumenCetak>
  </div>
</template>
<style scoped>
.kartu-kat { position: relative; display: flex; flex-direction: column; align-items: flex-start; gap: .125rem; padding: .875rem 1rem; text-align: left;
  border-radius: 1.25rem; border: 1px solid color-mix(in srgb, var(--c) 35%, rgb(var(--garis)));
  background: linear-gradient(155deg, color-mix(in srgb, var(--c) 18%, rgb(var(--permukaan))) 0%, color-mix(in srgb, var(--c) 5%, rgb(var(--permukaan))) 80%);
  transition: transform .15s, box-shadow .15s; }
.kartu-kat:hover { transform: translateY(-2px); }
.kartu-kat.aktif { border-color: var(--c); box-shadow: 0 0 0 2px var(--c); }
.kartu-kat.kosong { opacity: .62; }
.kartu-kat .chip-padat { display: grid; place-items: center; width: 2.25rem; height: 2.25rem; margin-bottom: .375rem; border-radius: .75rem; color: #fff; background: var(--c); }
:global(.dark) .kartu-kat .chip-padat { color: rgb(var(--latar)); }
.kartu-kat .angka { font-size: 1.6rem; font-weight: 800; line-height: 1.1; color: rgb(var(--teks)); font-variant-numeric: tabular-nums; }
.kartu-kat .judul { font-size: .875rem; font-weight: 700; color: rgb(var(--teks)); }
.kartu-kat .ket { font-size: .75rem; color: rgb(var(--teks-2)); }
</style>
