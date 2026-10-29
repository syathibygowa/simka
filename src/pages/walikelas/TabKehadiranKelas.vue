<!-- SIMKA PRO | src/pages/walikelas/TabKehadiranKelas.vue | v1.0 | 14.34.0: tab Kehadiran kelas — per jam pelajaran (harian) dan per pertemuan mapel | 30/10/2026 -->
<script setup>
// Wali Kelas → Kehadiran kelas. Rincian kehadiran santri di kelas dari absensi guru mapel (Jurnal mengajar):
//   Per jam pelajaran : satu hari, kolom JP 1, JP 2, … (HISBAT setiap jam pelajaran)
//   Per pertemuan     : satu mapel, kolom P1, P2, … (pertemuan yang tercatat), total dan persentase
import { ref, computed, onMounted, watch } from 'vue'
import { PhClock, PhCalendarDots } from '@phosphor-icons/vue'
import { useWaliKelas } from '@/stores/waliKelas'
import { useJadwal } from '@/stores/jadwal'
import KehadiranPerJP from '@/components/KehadiranPerJP.vue'
import KehadiranPerPertemuan from '@/components/KehadiranPerPertemuan.vue'

const wk = useWaliKelas(); const jd = useJadwal()
const MODE = [{ k: 'jp', n: 'Per jam pelajaran', ikon: PhClock, w: 'jadwal' }, { k: 'pertemuan', n: 'Per pertemuan mapel', ikon: PhCalendarDots, w: 'gurumapel' }]
const mode = ref('jp'); const tugas = ref('')
onMounted(() => jd.muat().catch(() => {}))
const tugasKelas = computed(() => jd.penugasan.filter((t) => t.group_id === wk.pilih)
  .map((t) => ({ id: t.id, n: `${jd.cariMapel(t.subject_id)?.nama || 'Mapel'} · ${t.nama_guru || ''}`, urut: jd.cariMapel(t.subject_id)?.urutan ?? 99 }))
  .sort((a, b) => a.urut - b.urut || a.n.localeCompare(b.n, 'id')))
watch(tugasKelas, (x) => { if (!x.some((t) => t.id === tugas.value)) tugas.value = x[0]?.id || '' }, { immediate: true })
const wali = computed(() => wk.kelasPilih?.wali?.[0] || {})
const ttd = computed(() => ({ jabatan: `Wali Kelas ${wk.kelasPilih?.nama || ''}`.trim(), nama: wali.value.nama || '', niy: wali.value.niy }))
</script>
<template>
  <div>
    <div class="mb-3 flex flex-wrap items-center gap-2">
      <div class="bilah-tab kecil" role="tablist" aria-label="Bentuk rincian kehadiran">
        <button v-for="m in MODE" :key="m.k" type="button" role="tab" :aria-selected="mode === m.k" :class="['tab-garis', 'w-' + m.w, mode === m.k && 'aktif']" @click="mode = m.k">
          <component :is="m.ikon" :size="18" weight="duotone" style="color: var(--c)" /> {{ m.n }}</button>
      </div>
      <div v-if="mode === 'pertemuan'" class="min-w-[240px] flex-1 sm:max-w-md"><label class="label-isian sr-only" for="kk-mapel">Mata pelajaran</label>
        <select id="kk-mapel" v-model="tugas" class="isian"><option v-if="!tugasKelas.length" value="" disabled>Belum ada mapel</option>
          <option v-for="t in tugasKelas" :key="t.id" :value="t.id">{{ t.n }}</option></select></div>
    </div>
    <KehadiranPerJP v-if="mode === 'jp'" :group-id="wk.pilih" :ttd-kanan="ttd" />
    <KehadiranPerPertemuan v-else-if="tugas" :key="tugas" :assignment-id="tugas" :ttd-kanan="ttd" />
    <p v-else class="kartu p-8 text-center text-sm text-teks3">Belum ada penugasan mengajar di kelas ini.</p>
  </div>
</template>
