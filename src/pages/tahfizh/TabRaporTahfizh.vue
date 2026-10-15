<!-- SIMKA PRO | src/pages/tahfizh/TabRaporTahfizh.vue | v1.2 | Perbaikan: nama berkas PDF sesuai dokumen | 16/10/2026 -->
<script setup>
import { namaBerkas } from '@/lib/namaBerkas'
// Tahfizh → Rapor: catatan muhaffizh untuk rapor tahfizh per halaqah.
// Catatan disusun otomatis per santri dari bank kalimat (Penilaian → Kalimat rapor → Catatan muhaffizh) dan data santri:
// kehadiran halaqah, capaian target bulanan, penambahan hafalan, kelulusan ujian kenaikan juz, dan predikat UTAS; dapat disunting.
// v1.1: tombol Cetak rapor tahfizh untuk halaqah terpilih (F4, per santri).
// Pengisian terbuka bagi muhaffizh saat periode penilaian Tahfizh Dibuka; pengelola nilai kapan saja.
import { ref, computed, onMounted } from 'vue'
import { PhInfo, PhBookOpenText, PhPrinter } from '@phosphor-icons/vue'
import { useRapor } from '@/stores/rapor'
import { usePenilaian } from '@/stores/penilaian'
import { LABEL_SEMESTER } from '@/lib/nilai'
import { predikatDari, sebutanPredikat } from '@/lib/penilaian'
import { faktaMuhaffizh, susunCatatan, kalimatUntuk } from '@/lib/catatanRapor'
import DaftarCatatanRapor from '@/pages/penilaian/DaftarCatatanRapor.vue'
import LembarRapor from '@/components/cetak/rapor/LembarRapor.vue'
import RaporTahfizh from '@/pages/penilaian/cetak/RaporTahfizh.vue'
import { useUI } from '@/stores/ui'
import { penandaTahfizh } from '@/lib/tahfizh'

const rp = useRapor(); const pn = usePenilaian()
const semester = ref(null); const halaqah = ref([]); const pilih = ref(''); const B = ref(null); const galat = ref('')
async function muat(s) {
  galat.value = ''
  try {
    if (!pn.dimuat) await pn.muat()
    semester.value = s || semester.value || pn.ta?.semester || 1
    if (!halaqah.value.length) { halaqah.value = await rp.halaqahSaya(); pilih.value ||= halaqah.value[0]?.group_id || '' }
    B.value = pilih.value ? await rp.bahanHalaqah(pilih.value, semester.value) : null
  } catch (e) { galat.value = e.message }
}
onMounted(() => muat())
const ganti = () => { B.value = null; muat() }

const bahasa = computed(() => pn.ketentuan?.tahfizh?.bahasa_predikat || 'indonesia')
const sebutUtas = (u) => { if (u?.nilai == null) return null; const t = sebutanPredikat(predikatDari(u.nilai, pn.predikatKelompok('utas')), bahasa.value); return t && bahasa.value === 'arab' ? `_${t}_` : t }
const bank = computed(() => kalimatUntuk(pn.kalimat, 'catatan_muhaffizh', 'tahfizh'))
const santri = computed(() => (B.value?.santri || []).map((s) => {
  const f = faktaMuhaffizh(s, { sebutUtas })
  const fakta = [
    f.hadir != null && { n: `Hadir halaqah ${f.hadir}%`, w: f.hadir >= 90 ? 'presensi' : f.hadir >= 80 ? 'agenda' : 'klinik' },
    s.bulan_total > 0 && { n: `Target bulanan ${s.bulan_tercapai}/${s.bulan_total}`, w: f.rasio >= 0.75 ? 'presensi' : f.rasio >= 0.5 ? 'agenda' : 'klinik' },
    { n: `+${s.tambah_hal || 0} hal.${s.tambah_juz ? ` · +${s.tambah_juz} juz` : ''}`, w: 'tahfizh' },
    { n: `Hafalan ${s.total_juz} juz`, w: 'tahfizh' },
    s.kenaikan_lulus > 0 && { n: `Lulus kenaikan juz ${s.kenaikan_lulus}×`, w: 'pengajuan' },
    s.utas?.nilai != null && { n: `UTAS ${s.utas.nilai} ${sebutUtas(s.utas)?.replace(/_/g, '') || ''}`, w: s.utas.tuntas ? 'presensi' : 'klinik' },
  ].filter(Boolean)
  return { ...s, fakta, _f: f }
}))
const susun = (s, n) => susunCatatan(bank.value, s._f, `${s.id}|${semester.value}|m${n}`)
const ui = useUI(); const T = ref(null); const pratinjau = ref(false); const memuatCetak = ref(false); const kepalaTz = ref(null)
async function cetak() {
  memuatCetak.value = true
  try { T.value = await rp.dataRaporTahfizh(pilih.value, semester.value); if (!T.value.penanda?.nama) kepalaTz.value = await penandaTahfizh().catch(() => null); pratinjau.value = true }
  catch (e) { ui.toast(e.message, 'galat') } finally { memuatCetak.value = false }
}
async function simpan(isi) { await rp.simpanCatatan(pilih.value, semester.value, 'muhaffizh', isi); await muat() }
</script>
<template>
  <div class="w-rapor space-y-4">
    <div class="kartu flex flex-wrap items-center gap-3 p-4">
      <div class="grid grid-cols-2 gap-1 rounded-2xl bg-permukaan2 p-1" role="radiogroup" aria-label="Semester">
        <button v-for="s in [1, 2]" :key="s" type="button" role="radio" :aria-checked="semester === s" @click="muat(s)"
          :class="['min-h-[40px] rounded-xl px-3 text-sm font-semibold', semester === s ? 'bg-permukaan text-teks shadow-kartu' : 'text-teks2']">{{ LABEL_SEMESTER[s] }}</button>
      </div>
      <select v-if="halaqah.length > 1" v-model="pilih" class="isian w-auto max-w-full font-semibold" aria-label="Pilih halaqah" @change="ganti">
        <option v-for="h in halaqah" :key="h.group_id" :value="h.group_id">{{ h.nama }}{{ h.asuhan_saya ? ' (halaqah saya)' : '' }} · {{ h.santri }} santri</option></select>
      <p class="min-w-[200px] flex-1 text-xs text-teks3"><PhBookOpenText :size="14" class="inline" /> Catatan muhaffizh untuk rapor tahfizh<template v-if="B?.halaqah"> · {{ B.halaqah.nama }} · muhaffizh: {{ B.halaqah.muhaffizh || '–' }}</template> · Nilai UTAS diisi di Ujian → UTAS</p>
      <button class="tombol-garis min-h-[40px] px-3 text-sm" :disabled="!B || memuatCetak" @click="cetak"><PhPrinter :size="18" weight="duotone" /> {{ memuatCetak ? 'Memuat…' : 'Cetak rapor tahfizh' }}</button>
    </div>
    <div v-if="galat" class="kartu w-klinik p-5 text-sm font-semibold" style="color: var(--c)">Bahan rapor gagal dimuat: {{ galat }} Pastikan migrasi SQL 8500 sudah dijalankan.</div>
    <p v-else-if="!halaqah.length && semester" class="kartu p-6 text-center text-sm text-teks3">Belum ada halaqah yang dapat Anda isi catatannya.</p>
    <template v-else-if="B">
      <p v-if="!B.boleh" class="flex gap-2 rounded-2xl bg-permukaan2 p-3 text-sm text-teks2"><PhInfo :size="18" class="mt-0.5 shrink-0" />
        <span>Pengisian belum/tidak terbuka: periode penilaian Tahfizh {{ LABEL_SEMESTER[semester]?.toLowerCase() }} belum dibuka atau sudah ditutup (Penilaian → Periode), atau Anda bukan muhaffizh halaqah ini.</span></p>
      <DaftarCatatanRapor :key="pilih + semester" :santri="santri" :boleh="B.boleh" :susun="susun" :simpan="simpan" label="Catatan muhaffizh" :kosong-bank="!bank.length" />
    </template>
    <p v-else class="kartu p-6 text-center text-sm text-teks3">Memuat bahan rapor…</p>
    <LembarRapor v-model:pratinjau="pratinjau" :judul="`Rapor tahfizh · ${B?.halaqah?.nama || ''}`" :keterangan="LABEL_SEMESTER[semester]" :nama-berkas="namaBerkas(B?.halaqah?.nama, 'Rapor Tahfizh', LABEL_SEMESTER[semester])">
      <RaporTahfizh v-if="T" :D="T" :penanda="kepalaTz" />
    </LembarRapor>
  </div>
</template>
