<!-- SIMKA PRO | src/pages/audit/AuditLog.vue | v1.0 | Fase 3 – Tahap 1 Pengumuman, audit log, notifikasi HP | 04/10/2026 -->
<script setup>
// Audit log 30 hari terakhir. Pegawai melihat aktivitasnya sendiri; admin ber-izin "audit_log" dan
// superadmin melihat semua. Saring tanggal, pelaku, dan jenis data; rincian perubahan per kolom;
// ekspor Excel; cetak F4 mendatar. Log lebih dari 3 bulan dihapus otomatis (pg_cron).
import { ref, computed, onMounted, watch } from 'vue'
import * as XLSX from 'xlsx'
import { PhPlusCircle, PhPencilSimpleLine, PhMinusCircle, PhLightning, PhMagnifyingGlass, PhEye, PhFileXls, PhArrowClockwise, PhInfo } from '@phosphor-icons/vue'
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
const semua = computed(() => sesi.bolehAdmin('audit_log'))
const mulai = ref(tambahHari(hariIniISO(), -6)); const akhir = ref(hariIniISO())
const pelaku = ref(''); const tabel = ref(''); const cari = ref(''); const pilih = ref(null); const pratinjau = ref(false)

const TABEL = {
  employees: 'Data pegawai', employee_functions: 'Jabatan fungsional pegawai', employee_structurals: 'Jabatan struktural pegawai',
  employee_schedules: 'Jadwal presensi pegawai', feature_grants: 'Hak akses fitur', admin_permissions: 'Izin admin',
  institution_settings: 'Pengaturan lembaga', letterheads: 'Kop surat', signatories: 'Penanda tangan', signer_rules: 'Aturan penanda tangan',
  org_units: 'Struktur organisasi', functional_positions: 'Jabatan fungsional', structural_positions: 'Jabatan struktural',
  doc_number_formats: 'Penomoran dokumen', letter_subject_codes: 'Kode perihal surat', holidays: 'Hari libur', holiday_calendars: 'Kalender libur',
  academic_years: 'Tahun ajaran', salary_rates: 'Tarif tunjangan', gps_points: 'Titik GPS', task_patterns: 'Pola tugas presensi',
  pattern_sessions: 'Sesi presensi', shift_rosters: 'Jadwal shift', shift_swaps: 'Tukar shift', announcements: 'Pengumuman',
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

onMounted(async () => { if (semua.value && !peg.daftar.length) peg.muat(); muat() })
async function muat() {
  if (akhir.value < mulai.value) return ui.toast('Tanggal akhir tidak boleh sebelum tanggal mulai.', 'galat')
  try { await audit.muat({ mulai: mulai.value, akhir: akhir.value, pegawai: pelaku.value, tabel: tabel.value, batas: 1000 }) } catch (e) { ui.toast(e.message, 'galat') }
}
watch([mulai, akhir, pelaku, tabel], muat)
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
  <div class="w-audit">
    <div class="layar-saja">
      <p class="mb-3 flex gap-2 text-sm text-teks3"><PhInfo :size="18" class="mt-0.5 shrink-0" />
        {{ semua ? 'Menampilkan aktivitas seluruh pengguna' : 'Menampilkan aktivitas akun Anda' }} selama 30 hari terakhir. Log yang berumur lebih dari 3 bulan dihapus otomatis.</p>
      <div class="kartu mb-4 grid gap-3 p-4 sm:grid-cols-2 lg:grid-cols-4">
        <InputTanggal v-model="mulai" label="Dari tanggal" />
        <InputTanggal v-model="akhir" label="Sampai tanggal" />
        <div v-if="semua"><label class="label-isian" for="au-pelaku">Pelaku</label>
          <select id="au-pelaku" v-model="pelaku" class="isian"><option value="">Semua pegawai</option>
            <option v-for="p in peg.daftar.filter((x) => x.status_akun === 'aktif')" :key="p.id" :value="p.id">{{ p.nama_lengkap }}</option></select></div>
        <div><label class="label-isian" for="au-tabel">Jenis data</label>
          <select id="au-tabel" v-model="tabel" class="isian"><option value="">Semua jenis</option>
            <option v-for="(n, k) in TABEL" :key="k" :value="k">{{ n }}</option></select></div>
        <div :class="semua ? 'sm:col-span-2 lg:col-span-4' : 'sm:col-span-2'"><label class="label-isian" for="au-cari">Cari</label>
          <div class="relative"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-teks3" />
            <input id="au-cari" v-model="cari" class="isian pl-10" placeholder="Nama, aktivitas, atau isi perubahan" /></div></div>
      </div>
      <p v-if="mulai < batasAwal" class="mb-3 text-sm font-semibold text-teks2">Catatan: hanya 30 hari terakhir yang ditampilkan (sejak {{ formatPanjang(batasAwal) }}).</p>
      <div class="mb-3 flex flex-wrap items-center gap-2">
        <button class="tombol-garis" @click="pratinjau = true"><PhEye :size="20" weight="duotone" /> Pratinjau cetak</button>
        <button class="tombol-garis" @click="ekspor"><PhFileXls :size="20" weight="duotone" /> Ekspor Excel</button>
        <button class="tombol-garis" :disabled="audit.memuat" @click="muat"><PhArrowClockwise :size="20" /> Muat ulang</button>
        <span class="ml-auto text-sm font-semibold text-teks3">{{ tampil.length }} aktivitas</span>
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

    <DokumenCetak v-model:pratinjau="pratinjau" mendatar judul="Audit Log Aktivitas Pengguna" :subjudul="`${formatPanjang(mulai)} s.d. ${formatPanjang(akhir)} · ${namaPelaku}`" :pencetak="sesi.pengguna?.nama_lengkap">
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
