<!-- SIMKA PRO | src/pages/gurumapel/TabKehadiranGuru.vue | v1.2 | 14.36.0: Rekap per mapel disaring per kelas saja; Per pertemuan per kelas · mapel | 30/10/2026 -->
<script setup>
// Guru Mapel → Kehadiran santri: rekap kehadiran santri pada mapel yang diampu (dari absensi di jurnal mengajar).
// Pemantau (admin/pimpinan/kurikulum) dapat memilih penugasan mana pun, atau "Semua mapel" di satu kelas.
import { ref, computed, onMounted, watch } from 'vue'
import { PhChartBar, PhCalendarDots } from '@phosphor-icons/vue'
import { useJadwal } from '@/stores/jadwal'
import { useKelompokSantri } from '@/stores/kelompokSantri'
import { useSesi } from '@/stores/sesi'
import RekapKehadiranMapel from '@/components/RekapKehadiranMapel.vue'
import KehadiranPerPertemuan from '@/components/KehadiranPerPertemuan.vue'

const props = defineProps({ pemantau: Boolean })
const jd = useJadwal(); const kel = useKelompokSantri(); const sesi = useSesi()
const pilih = ref('')
onMounted(async () => { await Promise.all([jd.muat(), kel.muat()]); if (!pilih.value) pilih.value = pilihan.value[0]?.v || '' })
const idSaya = computed(() => sesi.pengguna?.id)
const namaKelas = (g) => kel.cari(g)?.nama || 'Kelas'
const tugasTerlihat = computed(() => jd.penugasan.filter((x) => props.pemantau || x.employee_id === idSaya.value || jd.penugasan.every((y) => y.employee_id !== idSaya.value)))
const urutKelas = (a, b) => namaKelas(a).localeCompare(namaKelas(b), 'id', { numeric: true })
/** 14.36.0: Rekap per mapel disaring per kelas saja (seluruh mapel yang terlihat di kelas itu); Per pertemuan memilih kelas · mapel. */
const daftarKelas = computed(() => [...new Set(tugasTerlihat.value.map((x) => x.group_id))].sort(urutKelas)
  .map((g) => ({ v: 'g:' + g, n: `Kelas ${namaKelas(g)}`, kelas: namaKelas(g) })))
const daftar = computed(() => {
  const per = {}
  for (const x of tugasTerlihat.value) (per[x.group_id] ||= []).push(x)
  return Object.keys(per).sort(urutKelas).flatMap((g) => per[g].map((x) => ({ v: 't:' + x.id, n: `${namaKelas(g)} · ${jd.cariMapel(x.subject_id)?.nama || 'Mapel'}${props.pemantau ? ' · ' + (x.nama_guru || '') : ''}`,
    kelas: namaKelas(g), guru: x.nama_guru, niy: x.niy_guru })))
})
const MODE = [{ k: 'rekap', n: 'Rekap per mapel', ikon: PhChartBar, w: 'rekap' }, { k: 'pertemuan', n: 'Per pertemuan', ikon: PhCalendarDots, w: 'gurumapel' }]
const mode = ref('rekap')
const pilihan = computed(() => (mode.value === 'pertemuan' ? daftar.value : daftarKelas.value))
watch([mode, pilihan], () => { if (!pilihan.value.some((x) => x.v === pilih.value)) pilih.value = pilihan.value[0]?.v || '' })
const terpilih = computed(() => pilihan.value.find((x) => x.v === pilih.value))
</script>
<template>
  <div>
    <div class="mb-3 flex flex-wrap items-center gap-2">
      <div class="bilah-tab kecil" role="tablist" aria-label="Bentuk kehadiran">
        <button v-for="m in MODE" :key="m.k" type="button" role="tab" :aria-selected="mode === m.k" :class="['tab-garis', 'w-' + m.w, mode === m.k && 'aktif']" @click="mode = m.k">
          <component :is="m.ikon" :size="18" weight="duotone" style="color: var(--c)" /> {{ m.n }}</button>
      </div>
      <div class="min-w-[240px] flex-1 md:max-w-xl"><label class="label-isian sr-only" for="kg-pilih">{{ mode === 'rekap' ? 'Kelas' : 'Kelas dan mata pelajaran' }}</label>
        <select id="kg-pilih" v-model="pilih" class="isian"><option v-for="x in pilihan" :key="x.v" :value="x.v">{{ x.n }}</option></select></div>
    </div>
    <p v-if="!daftar.length" class="kartu p-8 text-center text-sm text-teks3">Belum ada penugasan mengajar.</p>
    <KehadiranPerPertemuan v-else-if="mode === 'pertemuan' && terpilih && pilih.startsWith('t:')" :key="'p' + pilih" :assignment-id="pilih.slice(2)"
      :ttd-kanan="{ jabatan: 'Guru Mata Pelajaran', nama: terpilih.guru || sesi.pengguna?.nama_lengkap, niy: terpilih.niy }" />
    <RekapKehadiranMapel v-else-if="mode === 'rekap' && terpilih" :key="pilih" :group-id="pilih.slice(2)"
      :ttd-kanan="props.pemantau ? { jabatan: 'Pembuat laporan', nama: sesi.pengguna?.nama_lengkap, niy: sesi.pengguna?.niy } : { jabatan: 'Guru Mata Pelajaran', nama: sesi.pengguna?.nama_lengkap, niy: sesi.pengguna?.niy }" />
  </div>
</template>
