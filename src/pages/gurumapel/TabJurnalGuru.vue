<!-- SIMKA PRO | src/pages/gurumapel/TabJurnalGuru.vue | v1.2 | 14.30.0: label saringan yang sudah jelas disembunyikan (hemat ruang) | 29/10/2026 -->
<script setup>
// Guru Mapel → Jurnal mengajar: laporan jurnal untuk dicetak/diunduh.
//   Per kelas dan mapel (disarankan untuk arsip kurikulum) · Per mapel (semua kelas yang diampu) · Semua yang diampu.
// Guru melihat jurnalnya sendiri; pemantau (admin, kurikulum, pimpinan jenjang) dapat memilih guru.
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute } from 'vue-router'
import { useJadwal } from '@/stores/jadwal'
import { useKelompokSantri } from '@/stores/kelompokSantri'
import { useSesi } from '@/stores/sesi'
import LaporanJurnalMengajar from '@/components/LaporanJurnalMengajar.vue'
import SaringCorong from '@/components/SaringCorong.vue'

const props = defineProps({ pemantau: Boolean, mengajar: Boolean })
const jd = useJadwal(); const kel = useKelompokSantri(); const sesi = useSesi()
const route = useRoute()
const emp = ref(''); const mode = ref(['tugas', 'mapel', 'semua'].includes(route.query.mode) ? route.query.mode : 'tugas'); const pilihTugas = ref(''); const pilihMapel = ref('')
const MODE = [{ k: 'tugas', n: 'Per kelas dan mapel' }, { k: 'mapel', n: 'Per mapel (semua kelas)' }, { k: 'semua', n: 'Semua yang diampu' }]
onMounted(async () => { await Promise.all([jd.muat(), kel.muat()]); emp.value = props.mengajar ? jd.idSaya() : guruList.value[0]?.id || '' })
const guruList = computed(() => [...new Map(jd.penugasan.map((t) => [t.employee_id, { id: t.employee_id, nama: t.nama_guru }])).values()].sort((a, b) => String(a.nama).localeCompare(String(b.nama), 'id')))
const tugasGuru = computed(() => jd.penugasan.filter((t) => t.employee_id === emp.value)
  .map((t) => ({ ...t, label: `${kel.cari(t.group_id)?.nama || 'Kelas'} · ${jd.cariMapel(t.subject_id)?.nama || 'Mapel'}` })).sort((a, b) => a.label.localeCompare(b.label, 'id', { numeric: true })))
const mapelGuru = computed(() => [...new Map(tugasGuru.value.map((t) => [t.subject_id, { id: t.subject_id, nama: jd.cariMapel(t.subject_id)?.nama || 'Mapel' }])).values()])
watch(tugasGuru, (x) => { if (!x.some((t) => t.id === pilihTugas.value)) pilihTugas.value = x[0]?.id || ''; if (!mapelGuru.value.some((m) => m.id === pilihMapel.value)) pilihMapel.value = mapelGuru.value[0]?.id || '' }, { immediate: true })
const cakupan = computed(() => (mode.value === 'tugas' ? { assignment_id: pilihTugas.value } : mode.value === 'mapel' ? { employee_id: emp.value, subject_id: pilihMapel.value } : { employee_id: emp.value }))
const siap = computed(() => !!emp.value && (mode.value !== 'tugas' || !!pilihTugas.value))
</script>
<template>
  <div>
    <SaringCorong class="mb-3" :ringkasan="[pemantau ? guruList.find((g) => g.id === emp)?.nama : '', MODE.find((m) => m.k === mode)?.n].filter(Boolean).join(' · ')" judul="Pilih laporan jurnal">
      <div v-if="pemantau"><label class="label-isian sr-only" for="jg-guru">Guru</label>
        <select id="jg-guru" v-model="emp" class="isian"><option v-for="g in guruList" :key="g.id" :value="g.id">{{ g.nama }}</option></select></div>
      <div><label class="label-isian" for="jg-mode">Bentuk laporan</label>
        <select id="jg-mode" v-model="mode" class="isian"><option v-for="m in MODE" :key="m.k" :value="m.k">{{ m.n }}</option></select></div>
      <div v-if="mode === 'tugas'"><label class="label-isian" for="jg-tugas">Kelas dan mapel</label>
        <select id="jg-tugas" v-model="pilihTugas" class="isian"><option v-for="t in tugasGuru" :key="t.id" :value="t.id">{{ t.label }}</option></select></div>
      <div v-else-if="mode === 'mapel'"><label class="label-isian sr-only" for="jg-mapel">Mata pelajaran</label>
        <select id="jg-mapel" v-model="pilihMapel" class="isian"><option v-for="m in mapelGuru" :key="m.id" :value="m.id">{{ m.nama }}</option></select></div>
    </SaringCorong>
    <p v-if="!tugasGuru.length" class="kartu p-8 text-center text-sm text-teks3">Belum ada penugasan mengajar.</p>
    <LaporanJurnalMengajar v-else-if="siap" :cakupan="cakupan" judul="Jurnal Mengajar" kanan="guru" :periode-awal="String(route.query.periode || 'bulan')" />
  </div>
</template>
