<!-- SIMKA PRO | src/pages/gurumapel/TabJadwalGuru.vue | v1.0 | Fase 4 – Menu Guru Mapel: jadwal mengajar pekanan | 12/10/2026 -->
<script setup>
// Jadwal mengajar pekanan seorang guru (Senin–Sabtu). Guru melihat jadwalnya sendiri; pemantau dapat memilih guru.
// Cetak jadwal tersedia di menu Roster → Jadwal guru (kertas F4).
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { PhPrinter } from '@phosphor-icons/vue'
import { useJadwal } from '@/stores/jadwal'
import { useKelompokSantri } from '@/stores/kelompokSantri'
import GridJadwal from '@/pages/jadwal/GridJadwal.vue'

const props = defineProps({ pemantau: Boolean, mengajar: Boolean })
const jd = useJadwal(); const kel = useKelompokSantri(); const router = useRouter()
const emp = ref('')
const guruList = computed(() => [...new Map(jd.penugasan.map((t) => [t.employee_id, { id: t.employee_id, nama: t.nama_guru }])).values()].sort((a, b) => String(a.nama).localeCompare(String(b.nama), 'id')))
onMounted(async () => { await Promise.all([kel.muat(), jd.muat()]); emp.value = props.mengajar ? jd.idSaya() : guruList.value[0]?.id || '' })
const jumlahJP = computed(() => jd.jadwal.filter((s) => s.employee_id === emp.value).length)
</script>
<template>
  <div>
    <div class="mb-3 flex flex-wrap items-end gap-2">
      <div v-if="pemantau" class="min-w-[220px] flex-1 sm:max-w-sm"><label class="label-isian" for="jg-guru">Guru</label>
        <select id="jg-guru" v-model="emp" class="isian"><option v-for="g in guruList" :key="g.id" :value="g.id">{{ g.nama }}</option></select></div>
      <p class="flex-1 self-center text-sm text-teks2">{{ jumlahJP }} jam pelajaran per pekan</p>
      <button class="tombol-garis" @click="router.push('/jadwal-pelajaran/guru')"><PhPrinter :size="20" weight="duotone" /> Cetak di Roster</button>
    </div>
    <div class="kartu p-3">
      <GridJadwal v-if="jd.dimuat && emp" mode="guru" :employee-id="emp" />
      <p v-else class="p-6 text-center text-sm text-teks3">{{ jd.dimuat ? 'Belum ada jadwal mengajar.' : 'Memuat jadwal…' }}</p>
    </div>
  </div>
</template>
