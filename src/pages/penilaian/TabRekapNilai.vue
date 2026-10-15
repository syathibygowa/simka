<!-- SIMKA PRO | src/pages/penilaian/TabRekapNilai.vue | v1.1 | Perbaikan 13.6.0: sub-tab bergaris bawah | 15/10/2026 -->
<script setup>
// Penilaian → Rekap: kemajuan pengisian rapor semester berjalan untuk pimpinan, pengatur penilaian, dan pengelola nilai
// (cakupan menurut jenjang yang menjadi hak). Per kelas: mapel lengkap, nilai terisi, sikap, catatan wali kelas,
// kokurikuler, pengembangan diri, keputusan akhir tahun (semester 2), UTAS final. Per guru: isian yang belum lengkap.
// Status periode (termasuk terkunci karena batas pengisian lewat), UTAS, ekskul. Dapat dicetak (F4 mendatar).
import { ref, computed, onMounted } from 'vue'
import { PhChartBar, PhNotePencil, PhBookOpenText, PhPencilLine, PhPrinter, PhChalkboardTeacher, PhMedal, PhCalendarCheck } from '@phosphor-icons/vue'
import { useUbahNilai } from '@/stores/ubahNilai'
import { usePenilaian } from '@/stores/penilaian'
import { useSesi } from '@/stores/sesi'
import { JENIS_RAPOR, STATUS_PERIODE } from '@/lib/penilaian'
import { LABEL_SEMESTER } from '@/lib/nilai'
import { formatPendek, formatPanjang, hariIniISO } from '@/lib/tanggal'
import KartuStatistik from '@/components/KartuStatistik.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'

const emit = defineEmits(['permintaan'])
const un = useUbahNilai(); const pn = usePenilaian(); const sesi = useSesi()
const semester = ref(null); const R = ref(null); const galat = ref(''); const jenjang = ref('')
async function muat(s) { galat.value = ''; try { semester.value = s || semester.value || pn.ta?.semester || 1; R.value = await un.rekap(semester.value) } catch (e) { galat.value = e.message } }
onMounted(() => muat())
const kelas = computed(() => (R.value?.kelas || []).filter((k) => !jenjang.value || k.jenjang === jenjang.value))
const pct = (a, b) => (b ? Math.round((a / b) * 100) : 0)
const total = computed(() => kelas.value.reduce((t, k) => ({ isi: t.isi + k.nilai_terisi, target: t.target + k.nilai_target, santri: t.santri + k.santri, cat: t.cat + k.catatan }), { isi: 0, target: 0, santri: 0, cat: 0 }))
const statistik = computed(() => [
  { judul: 'Nilai mapel terisi', nilai: `${pct(total.value.isi, total.value.target)}%`, ikon: PhChartBar, warna: 'gurumapel', keterangan: `${total.value.isi.toLocaleString('id-ID')} dari ${total.value.target.toLocaleString('id-ID')} nilai rapor` },
  { judul: 'Catatan wali kelas', nilai: `${pct(total.value.cat, total.value.santri)}%`, ikon: PhNotePencil, warna: 'walikelas', keterangan: `${total.value.cat} dari ${total.value.santri} santri` },
  { judul: 'UTAS final', nilai: R.value?.utas ? `${R.value.utas.final}/${R.value.utas.peserta}` : '–', ikon: PhBookOpenText, warna: 'tahfizh', keterangan: R.value?.utas ? `${R.value.utas.dinilai} dinilai · ${R.value.utas.remedial} remedial` : 'Bukan cakupan Anda' },
  { judul: 'Permintaan ubah nilai', nilai: R.value?.permintaan_menunggu ?? 0, ikon: PhPencilLine, warna: 'pengajuan', keterangan: 'Menunggu keputusan pengelola nilai' },
])
const warnaPersen = (p) => (p >= 100 ? '#1E7D4F' : p >= 60 ? '#B7791F' : '#C53030')
const guruKurang = computed(() => (R.value?.guru || []).filter((g) => g.kurang > 0))
const pratinjau = ref(false)
</script>
<template>
  <div class="space-y-4">
    <div class="kartu flex flex-wrap items-center gap-3 p-4">
      <div class="bilah-tab kecil" role="tablist" aria-label="Semester">
        <button v-for="s in [1, 2]" :key="s" type="button" role="tab" :aria-selected="semester === s" @click="muat(s)"
          :class="['tab-garis', semester === s && 'aktif']">{{ LABEL_SEMESTER[s] }}</button>
      </div>
      <select v-if="(R?.jenis || []).filter((j) => j !== 'tahfizh').length > 1" v-model="jenjang" class="isian w-auto" aria-label="Saring jenjang">
        <option value="">Semua jenjang</option><option value="sma">SMA</option><option value="wustha">Wustha</option></select>
      <ul class="flex flex-1 flex-wrap gap-2">
        <li v-for="p in R?.periode || []" :key="p.jenis" :class="['lencana', 'w-' + STATUS_PERIODE[p.status_efektif].w]"><PhCalendarCheck :size="14" />
          {{ JENIS_RAPOR[p.jenis]?.pendek }}: {{ STATUS_PERIODE[p.status_efektif].n.toLowerCase() }}{{ p.status !== p.status_efektif ? ' (batas lewat)' : p.batas_isi && p.status_efektif === 'dibuka' ? ` s.d. ${formatPendek(p.batas_isi)}` : '' }}</li>
      </ul>
      <button class="tombol-garis min-h-[40px] px-3 text-sm" :disabled="!R" @click="pratinjau = true"><PhPrinter :size="18" weight="duotone" /> Cetak</button>
    </div>
    <div v-if="galat" class="kartu w-klinik p-5 text-sm font-semibold" style="color: var(--c)">Rekap gagal dimuat: {{ galat }}</div>
    <template v-else-if="R">
      <div class="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <KartuStatistik v-for="s in statistik" :key="s.judul" v-bind="s" />
      </div>
      <button v-if="R.permintaan_menunggu" class="tombol-garis w-pengajuan min-h-[40px] px-3 text-sm" @click="emit('permintaan')"><PhPencilLine :size="18" /> Tinjau {{ R.permintaan_menunggu }} permintaan ubah nilai</button>

      <!-- Per kelas -->
      <section class="kartu overflow-hidden">
        <p class="border-b border-garis bg-permukaan2 px-4 py-2 font-bold">Kemajuan per kelas</p>
        <div class="overflow-x-auto">
          <table class="w-full min-w-[760px] text-sm">
            <thead class="text-xs text-teks3"><tr class="text-left"><th class="px-3 py-2">Kelas</th><th class="px-2 py-2">Wali kelas</th><th class="px-2 py-2 text-center">Santri</th>
              <th class="px-2 py-2">Nilai mapel</th><th class="px-2 py-2 text-center">Mapel lengkap</th><th class="px-2 py-2 text-center">Sikap</th><th class="px-2 py-2 text-center">Catatan</th>
              <th class="px-2 py-2 text-center">Kokurikuler</th><th class="px-2 py-2 text-center">Peng. diri</th><th v-if="semester === 2" class="px-2 py-2 text-center">Keputusan</th><th class="px-2 py-2 text-center">UTAS final</th></tr></thead>
            <tbody class="divide-y divide-garis">
              <tr v-for="k in kelas" :key="k.group_id">
                <td class="px-3 py-2 font-semibold">{{ k.nama }} <span class="text-xs font-normal text-teks3">{{ JENIS_RAPOR[k.jenjang]?.pendek }}</span></td>
                <td class="px-2 py-2 text-xs text-teks2">{{ k.wali || '–' }}</td><td class="px-2 py-2 text-center tabular-nums">{{ k.santri }}</td>
                <td class="px-2 py-2"><div class="flex items-center gap-2"><div class="h-2 w-24 overflow-hidden rounded-full bg-permukaan2"><div class="h-full rounded-full" :style="{ width: pct(k.nilai_terisi, k.nilai_target) + '%', background: warnaPersen(pct(k.nilai_terisi, k.nilai_target)) }" /></div>
                  <span class="tabular-nums text-xs">{{ pct(k.nilai_terisi, k.nilai_target) }}%</span></div></td>
                <td class="px-2 py-2 text-center tabular-nums">{{ k.tugas_lengkap }}/{{ k.tugas }}</td>
                <td class="px-2 py-2 text-center tabular-nums">{{ pct(k.sikap, k.nilai_target) }}%</td>
                <td class="px-2 py-2 text-center tabular-nums" :class="k.catatan < k.santri ? 'text-merah font-semibold' : ''">{{ k.catatan }}/{{ k.santri }}</td>
                <td class="px-2 py-2 text-center tabular-nums">{{ k.jenjang === 'sma' ? `${k.kokurikuler}/${k.santri}` : '–' }}</td>
                <td class="px-2 py-2 text-center tabular-nums">{{ k.pd }}/{{ k.santri }}</td>
                <td v-if="semester === 2" class="px-2 py-2 text-center tabular-nums" :class="(k.keputusan ?? 0) < k.santri ? 'text-merah font-semibold' : ''">{{ k.keputusan ?? 0 }}/{{ k.santri }}</td>
                <td class="px-2 py-2 text-center tabular-nums">{{ k.utas_final }}/{{ k.santri }}</td>
              </tr>
            </tbody>
          </table>
        </div>
        <p v-if="!kelas.length" class="p-6 text-center text-sm text-teks3">Belum ada kelas pada cakupan Anda.</p>
      </section>

      <div class="grid gap-4 xl:grid-cols-2">
        <section class="kartu w-gurumapel p-4">
          <p class="mb-2 flex items-center gap-2 font-bold"><PhChalkboardTeacher :size="20" weight="duotone" style="color: var(--c)" /> Guru dengan nilai belum lengkap</p>
          <ul class="divide-y divide-garis">
            <li v-for="g in guruKurang" :key="g.employee_id" class="py-2">
              <p class="flex items-center gap-2 text-sm font-semibold"><span class="flex-1">{{ g.nama }}</span><span class="lencana w-klinik">{{ g.kurang }} nilai kosong</span></p>
              <p class="text-xs text-teks3">{{ (g.belum || []).map((b) => `${b.mapel} ${b.kelas} (${b.terisi}/${b.target})`).join(' · ') }}</p>
            </li>
          </ul>
          <p v-if="!guruKurang.length" class="py-4 text-center text-sm text-teks3">Semua guru sudah melengkapi nilai.</p>
        </section>
        <section class="kartu w-ekskul p-4">
          <p class="mb-2 flex items-center gap-2 font-bold"><PhMedal :size="20" weight="duotone" style="color: var(--c)" /> Nilai pengembangan diri per ekskul</p>
          <ul class="divide-y divide-garis">
            <li v-for="e in R.ekskul" :key="e.group_id" class="flex items-center gap-2 py-2 text-sm">
              <span class="min-w-0 flex-1"><b>{{ e.nama }}</b> <span class="text-xs text-teks3">· {{ e.pembina || 'pembina belum ditetapkan' }}</span></span>
              <span :class="['tabular-nums', e.terisi < e.santri ? 'font-semibold text-merah' : '']">{{ e.terisi }}/{{ e.santri }}</span></li>
          </ul>
          <p v-if="!R.ekskul.length" class="py-4 text-center text-sm text-teks3">Belum ada ekskul.</p>
        </section>
      </div>
    </template>
    <p v-else class="kartu p-6 text-center text-sm text-teks3">Memuat rekap…</p>

    <DokumenCetak kop="pondok" judul="Rekap Kemajuan Penilaian" :subjudul="`${LABEL_SEMESTER[semester] || ''} · keadaan ${formatPanjang(hariIniISO())}`" v-model:pratinjau="pratinjau" :pencetak="sesi.pengguna?.nama_lengkap" mendatar>
      <table class="tabel kecil"><colgroup><col style="width:4%"><col style="width:7%"><col style="width:17%"><col style="width:6%"><col style="width:10%"><col style="width:9%"><col style="width:8%"><col style="width:9%"><col style="width:9%"><col style="width:9%"><col style="width:12%"></colgroup>
        <thead><tr><th>No.</th><th>Kelas</th><th>Wali Kelas</th><th>Santri</th><th>Nilai Mapel Terisi</th><th>Mapel Lengkap</th><th>Sikap</th><th>Catatan Wali</th><th>Kokurikuler</th><th>Pengembangan Diri</th><th>{{ semester === 2 ? 'Keputusan / UTAS' : 'UTAS Final' }}</th></tr></thead>
        <tbody><tr v-for="(k, i) in kelas" :key="k.group_id"><td class="tengah">{{ i + 1 }}</td><td class="tengah">{{ k.nama }}</td><td>{{ k.wali || '–' }}</td><td class="tengah">{{ k.santri }}</td>
          <td class="tengah">{{ k.nilai_terisi }}/{{ k.nilai_target }} ({{ pct(k.nilai_terisi, k.nilai_target) }}%)</td><td class="tengah">{{ k.tugas_lengkap }}/{{ k.tugas }}</td>
          <td class="tengah">{{ pct(k.sikap, k.nilai_target) }}%</td><td class="tengah">{{ k.catatan }}/{{ k.santri }}</td><td class="tengah">{{ k.jenjang === 'sma' ? `${k.kokurikuler}/${k.santri}` : '–' }}</td>
          <td class="tengah">{{ k.pd }}/{{ k.santri }}</td><td class="tengah">{{ semester === 2 ? `${k.keputusan ?? 0} / ` : '' }}{{ k.utas_final }}/{{ k.santri }}</td></tr></tbody></table>
      <p v-if="guruKurang.length" style="margin: 8pt 0 3pt; font-weight: 700">Guru dengan nilai belum lengkap</p>
      <table v-if="guruKurang.length" class="tabel kecil"><colgroup><col style="width:4%"><col style="width:26%"><col style="width:10%"><col style="width:60%"></colgroup>
        <thead><tr><th>No.</th><th>Nama Guru</th><th>Nilai Kosong</th><th>Kelas–Mapel Belum Lengkap</th></tr></thead>
        <tbody><tr v-for="(g, i) in guruKurang" :key="g.employee_id"><td class="tengah">{{ i + 1 }}</td><td>{{ g.nama }}</td><td class="tengah">{{ g.kurang }}</td>
          <td>{{ (g.belum || []).map((b) => `${b.mapel} ${b.kelas} (${b.terisi}/${b.target})`).join('; ') }}</td></tr></tbody></table>
      <template #ttd><TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: 'Pimpinan', nama: '' }" :kanan="{ jabatan: 'Pengelola Penilaian', nama: sesi.pengguna?.nama_lengkap || '' }" /></template>
    </DokumenCetak>
  </div>
</template>
