<!-- SIMKA PRO | src/pages/pengaturan/TabKapasitas.vue | v1.0 | 14.12.0: kapasitas database, perkiraan, retensi data, dan perawatan | 18/10/2026 -->
<script setup>
// Kapasitas database (superadmin): ukuran dibanding batas paket Supabase, laju pertambahan per bulan, perkiraan bulan sampai batas,
// 15 tabel terbesar, riwayat ukuran harian, jadwal otomatis, pengaturan masa simpan (retensi), dan tombol "Rawat sekarang".
import { ref, computed, onMounted } from 'vue'
import { PhDatabase, PhGauge, PhTrendUp, PhHourglassMedium, PhBroom, PhFloppyDisk, PhClockClockwise, PhInfo } from '@phosphor-icons/vue'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { pesanGalat } from '@/stores/lembaga'
import { useUI } from '@/stores/ui'
import { formatPendek, hariIniISO } from '@/lib/tanggal'
import KartuStatistik from '@/components/KartuStatistik.vue'
import GrafikDeret from '@/components/grafik/GrafikDeret.vue'

const ui = useUI()
const d = ref(null); const f = ref(null); const memuat = ref(false); const proses = ref(false); const hasilRawat = ref(null)
const MB = 1024 * 1024
const mb = (b) => (b == null ? '–' : `${(b / MB).toLocaleString('id-ID', { maximumFractionDigits: b < 10 * MB ? 1 : 0 })} MB`)

// Nama tabel → keterangan
const NAMA = {
  'public.memorization_logs': 'Setoran hafalan santri', 'public.memorization_sessions': 'Sesi setoran', 'public.attendance_events': 'Rincian presensi (GPS, perangkat)',
  'public.attendances': 'Presensi pegawai', 'public.student_attendance_sessions': 'Sesi absensi santri', 'public.student_attendance_exceptions': 'Santri tidak hadir',
  'public.teaching_journals': 'Jurnal mengajar', 'public.journal_entries': 'Jurnal harian', 'public.journal_checks': 'Ceklist jurnal', 'public.grade_scores': 'Nilai',
  'public.notifications': 'Notifikasi', 'public.audit_logs': 'Audit log', 'cron.job_run_details': 'Riwayat jadwal otomatis', 'public.students': 'Data santri',
  'public.employees': 'Data pegawai', 'public.document_registry': 'Registri dokumen', 'public.monthly_achievements': 'Capaian bulanan', 'public.push_queue': 'Antrian notifikasi HP',
  'auth.users': 'Akun masuk', 'auth.audit_log_entries': 'Log masuk (Supabase Auth)', 'auth.refresh_tokens': 'Token sesi', 'auth.sessions': 'Sesi masuk', 'storage.objects': 'Berkas antrian',
  'public.dorm_journals': 'Jurnal musyrif', 'public.student_permits': 'Perizinan santri', 'public.gate_logs': 'Gerbang', 'public.clinic_cases': 'Klinik', 'public.bills': 'Tagihan', 'public.payments': 'Pembayaran',
}

function demo() {
  const hari = Array.from({ length: 45 }, (_, i) => { const t = new Date(Date.now() - (44 - i) * 864e5); return { tanggal: t.toISOString().slice(0, 10), bytes: Math.round((52 + i * 0.36) * MB) } })
  const tabel = [['public.memorization_logs', 14.2, 61000], ['cron.job_run_details', 9.8, 52000], ['public.attendance_events', 8.9, 11800], ['public.audit_logs', 6.1, 38000], ['public.attendances', 3.2, 6100],
    ['auth.audit_log_entries', 2.4, 9100], ['public.teaching_journals', 2.1, 3900], ['public.notifications', 1.9, 14000], ['public.journal_entries', 1.6, 7600], ['public.student_attendance_sessions', 1.4, 5200]]
    .map(([t, m, n]) => ({ tabel: t, bytes: Math.round(m * MB), baris: n }))
  return { ukuran: 68 * MB, batas: 500 * MB, persen: 13.6, laju_bulan: 10.8 * MB, bulan_tersisa: 40, sejak: hari[0].tanggal, riwayat: hari, tabel,
    retensi: { audit_bulan: 3, notifikasi_bulan: 6, rincian_presensi_bulan: null, batas_mb: 500 },
    jadwal: [{ nama: 'rawat-database', jadwal: '0 18 * * *' }, { nama: 'tugas-berkala', jadwal: '*/5 * * * *' }, { nama: 'pengingat-disposisi', jadwal: '0 23 * * *' }] }
}
async function muat() {
  memuat.value = true
  try {
    if (MODE_DEMO) d.value = demo()
    else { const { data, error } = await supabase.rpc('kapasitas_database'); if (error) throw new Error(pesanGalat(error)); d.value = data }
    const r = d.value.retensi || {}
    f.value = { audit_bulan: r.audit_bulan ?? 3, notifikasi_bulan: r.notifikasi_bulan ?? 6, rincian_presensi_bulan: r.rincian_presensi_bulan ?? '', batas_mb: r.batas_mb ?? 500 }
  } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false }
}
onMounted(muat)

const warnaPakai = computed(() => (!d.value ? 'presensi' : d.value.persen >= 85 ? 'klinik' : d.value.persen >= 65 ? 'tahfizh' : 'presensi'))
const statistik = computed(() => {
  const x = d.value || {}
  const sisa = x.bulan_tersisa
  return [
    { judul: 'Ukuran database', nilai: mb(x.ukuran), ikon: PhDatabase, warna: 'audit', ket: `Batas paket ${mb(x.batas)}` },
    { judul: 'Terpakai', nilai: x.persen != null ? `${String(x.persen).replace('.', ',')}%` : '–', ikon: PhGauge, warna: warnaPakai.value, ket: x.persen >= 85 ? 'Segera rawat atau naikkan paket' : 'Masih lega' },
    { judul: 'Pertambahan per bulan', nilai: x.laju_bulan != null ? mb(x.laju_bulan) : '–', ikon: PhTrendUp, warna: 'jadwal', ket: x.laju_bulan != null ? `Dihitung sejak ${formatPendek(x.sejak)}` : 'Perlu catatan ≥ 14 hari' },
    { judul: 'Perkiraan sampai batas', nilai: sisa == null ? '–' : sisa >= 120 ? '> 10 tahun' : sisa >= 24 ? `± ${Math.floor(sisa / 12)} tahun` : `± ${sisa} bulan`, ikon: PhHourglassMedium, warna: sisa != null && sisa < 12 ? 'klinik' : 'libursantri', ket: 'Bila laju tetap seperti sekarang' },
  ]
})
const maksTabel = computed(() => Math.max(1, ...(d.value?.tabel || []).map((t) => t.bytes)))
const grafik = computed(() => {
  const semua = (d.value?.riwayat || []).slice(-90); const langkah = Math.max(1, Math.ceil(semua.length / 12))
  const r = semua.filter((_, i) => (semua.length - 1 - i) % langkah === 0)   // ±12 titik, selalu termasuk hari terakhir
  return { label: r.map((x) => formatPendek(x.tanggal).slice(0, 5)), seri: [{ n: 'Ukuran database (MB)', nilai: r.map((x) => Math.round((x.bytes / MB) * 10) / 10) }] }
})

async function simpan() {
  const p = { audit_bulan: Number(f.value.audit_bulan), notifikasi_bulan: Number(f.value.notifikasi_bulan), rincian_presensi_bulan: f.value.rincian_presensi_bulan === '' ? null : Number(f.value.rincian_presensi_bulan), batas_mb: Number(f.value.batas_mb) }
  proses.value = true
  try {
    if (!MODE_DEMO) { const { error } = await supabase.rpc('simpan_retensi', { p }); if (error) throw new Error(pesanGalat(error)) } else d.value.retensi = p
    ui.toast('Masa simpan data disimpan. Berlaku pada perawatan berikutnya (02.00 WITA) atau tekan "Rawat sekarang".'); await muat()
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
async function rawat() {
  if (!(await ui.konfirmasi({ judul: 'Rawat database sekarang?', pesan: 'Data lama dibersihkan sesuai masa simpan: riwayat jadwal otomatis > 7 hari, audit log, notifikasi dibaca, dan (bila diatur) rincian presensi. Rekap kehadiran, hafalan, nilai, dan data utama tidak tersentuh.', ya: 'Rawat sekarang' }))) return
  proses.value = true
  try {
    if (MODE_DEMO) hasilRawat.value = { riwayat_cron: 51200, audit: 0, notifikasi: 140, rincian_presensi: 0, token: 2 }
    else { const { data, error } = await supabase.rpc('rawat_database'); if (error) throw new Error(pesanGalat(error)); hasilRawat.value = data }
    ui.toast('Perawatan selesai.'); await muat()
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
const n = (x) => (x < 0 ? 'tidak dapat diakses' : Number(x || 0).toLocaleString('id-ID'))
</script>
<template>
  <div class="w-audit max-w-5xl space-y-4">
    <div class="-mx-4 flex snap-x gap-3 overflow-x-auto px-4 pb-1 sm:mx-0 sm:grid sm:grid-cols-4 sm:overflow-visible sm:px-0">
      <KartuStatistik v-for="s in statistik" :key="s.judul" class="w-[44%] shrink-0 snap-start sm:w-auto" :judul="s.judul" :nilai="memuat ? '…' : s.nilai" :ikon="s.ikon" :warna="s.warna" :keterangan="s.ket" />
    </div>

    <section v-if="d" class="kartu p-4 sm:p-5">
      <div class="flex items-center justify-between text-sm"><b>Pemakaian {{ mb(d.ukuran) }} dari {{ mb(d.batas) }}</b><span class="tabular-nums text-teks3">{{ String(d.persen).replace('.', ',') }}%</span></div>
      <div class="mt-2 h-3 overflow-hidden rounded-full bg-garis" role="img" :aria-label="`Terpakai ${d.persen} persen`">
        <div :class="['h-full rounded-full', 'w-' + warnaPakai]" :style="`width: ${Math.min(100, d.persen)}%; background: var(--c)`" /></div>
      <p class="mt-2 flex items-start gap-1.5 text-xs text-teks2"><PhInfo :size="16" class="mt-0.5 shrink-0" />
        Ruang dari data yang dibersihkan dipakai ulang oleh database, sehingga ukuran tidak langsung turun tetapi berhenti bertambah untuk sementara.</p>
      <div v-if="grafik.label.length > 1" class="mt-4 max-w-3xl"><GrafikDeret :label="grafik.label" :seri="grafik.seri" jenis="garis" satuan="MB" judul="Ukuran database harian" /></div>
      <p v-else class="mt-3 text-xs text-teks3">Grafik dan perkiraan muncul setelah ukuran database tercatat beberapa hari (dicatat otomatis setiap 02.00 WITA).</p>
    </section>

    <div class="grid gap-4 lg:grid-cols-2">
      <section v-if="d" class="kartu p-4 sm:p-5">
        <h3 class="judul-bagian mb-3 flex items-center gap-2"><PhDatabase :size="20" weight="duotone" style="color: var(--c)" /> Tabel terbesar</h3>
        <ul class="space-y-2">
          <li v-for="t in d.tabel" :key="t.tabel" class="text-sm">
            <div class="flex items-center justify-between gap-2"><span class="min-w-0 truncate"><b>{{ NAMA[t.tabel] || t.tabel.replace('public.', '') }}</b>
              <span class="text-xs text-teks3"> · {{ Number(t.baris).toLocaleString('id-ID') }} baris</span></span><span class="shrink-0 tabular-nums">{{ mb(t.bytes) }}</span></div>
            <div class="mt-1 h-1.5 overflow-hidden rounded-full bg-garis"><div class="h-full rounded-full" :style="`width: ${(t.bytes / maksTabel) * 100}%; background: var(--c)`" /></div>
          </li>
        </ul>
      </section>

      <section v-if="f" class="kartu p-4 sm:p-5">
        <h3 class="judul-bagian mb-1 flex items-center gap-2"><PhClockClockwise :size="20" weight="duotone" style="color: var(--c)" /> Masa simpan data</h3>
        <p class="mb-3 text-xs text-teks2">Dibersihkan otomatis setiap hari pukul 02.00 WITA. Data utama (santri, pegawai, kehadiran, hafalan, nilai, keuangan, surat) <b>tidak pernah</b> dihapus otomatis; semuanya juga tersalin di backup bulanan Google Drive.</p>
        <div class="grid gap-3 sm:grid-cols-2">
          <div><label class="label-isian" for="rt-audit">Audit log (bulan)</label>
            <select id="rt-audit" v-model.number="f.audit_bulan" class="isian"><option v-for="b in [1, 3, 6, 12, 24]" :key="b" :value="b">{{ b }} bulan</option></select></div>
          <div><label class="label-isian" for="rt-notif">Notifikasi sudah dibaca (bulan)</label>
            <select id="rt-notif" v-model.number="f.notifikasi_bulan" class="isian"><option v-for="b in [1, 3, 6, 12, 24]" :key="b" :value="b">{{ b }} bulan</option></select></div>
          <div><label class="label-isian" for="rt-rinci">Rincian presensi (GPS, perangkat)</label>
            <select id="rt-rinci" v-model="f.rincian_presensi_bulan" class="isian"><option value="">Simpan selamanya</option><option v-for="b in [12, 24, 36]" :key="b" :value="b">{{ b }} bulan</option></select></div>
          <div><label class="label-isian" for="rt-batas">Batas paket Supabase (MB)</label>
            <select id="rt-batas" v-model.number="f.batas_mb" class="isian"><option :value="500">500 MB (Free)</option><option :value="8192">8 GB (Pro)</option></select></div>
        </div>
        <p class="mt-2 text-xs text-teks3">Riwayat jadwal otomatis selalu disimpan 7 hari. Rincian presensi yang dihapus tidak mengubah rekap kehadiran (jam datang/pulang, status, terlambat).</p>
        <div class="mt-4 flex flex-wrap gap-2">
          <button class="tombol-utama" :disabled="proses" @click="simpan"><PhFloppyDisk :size="20" weight="duotone" /> Simpan</button>
          <button class="tombol-garis" :disabled="proses" @click="rawat"><PhBroom :size="20" weight="duotone" style="color: var(--c)" /> Rawat sekarang</button>
        </div>
        <p v-if="hasilRawat" class="mt-3 rounded-xl bg-permukaan2 p-3 text-xs">Dibersihkan: riwayat jadwal {{ n(hasilRawat.riwayat_cron) }}, audit log {{ n(hasilRawat.audit) }}, notifikasi {{ n(hasilRawat.notifikasi) }},
          rincian presensi {{ n(hasilRawat.rincian_presensi) }}, token {{ n(hasilRawat.token) }} baris.</p>
        <details v-if="d?.jadwal?.length" class="mt-3 text-xs text-teks3"><summary class="cursor-pointer">Jadwal otomatis di server ({{ d.jadwal.length }})</summary>
          <ul class="mt-1 space-y-0.5"><li v-for="j in d.jadwal" :key="j.nama"><code>{{ j.nama }}</code> · {{ j.jadwal }} (UTC)</li></ul></details>
        <p class="mt-2 text-xs text-teks3">Data per {{ formatPendek(hariIniISO()) }}.</p>
      </section>
    </div>
  </div>
</template>
