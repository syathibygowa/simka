<!-- SIMKA PRO | src/pages/gurumapel/TabKehadiranGuru.vue | v1.0 | 14.3.0: kehadiran santri per mapel bagi guru mapel | 17/10/2026 -->
<script setup>
// Guru Mapel → Kehadiran santri: rekap kehadiran santri pada mapel yang diampu (dari absensi di jurnal mengajar).
// Pemantau (admin/pimpinan/kurikulum) dapat memilih penugasan mana pun, atau "Semua mapel" di satu kelas.
import { ref, computed, onMounted } from 'vue'
import { useJadwal } from '@/stores/jadwal'
import { useKelompokSantri } from '@/stores/kelompokSantri'
import { useSesi } from '@/stores/sesi'
import RekapKehadiranMapel from '@/components/RekapKehadiranMapel.vue'

const props = defineProps({ pemantau: Boolean })
const jd = useJadwal(); const kel = useKelompokSantri(); const sesi = useSesi()
const pilih = ref('')
onMounted(async () => { await Promise.all([jd.muat(), kel.muat()]); if (!pilih.value) pilih.value = daftar.value[0]?.v || '' })
const idSaya = computed(() => sesi.pengguna?.id)
const namaKelas = (g) => kel.cari(g)?.nama || 'Kelas'
const daftar = computed(() => {
  const t = jd.penugasan.filter((x) => props.pemantau || x.employee_id === idSaya.value || jd.penugasan.every((y) => y.employee_id !== idSaya.value))
  const per = {}
  for (const x of t) (per[x.group_id] ||= []).push(x)
  return Object.entries(per).sort((a, b) => namaKelas(a[0]).localeCompare(namaKelas(b[0]), 'id', { numeric: true })).flatMap(([g, xs]) => [
    ...(props.pemantau ? [{ v: 'g:' + g, n: `${namaKelas(g)} · semua mapel`, kelas: namaKelas(g) }] : []),
    ...xs.map((x) => ({ v: 't:' + x.id, n: `${namaKelas(g)} · ${jd.cariMapel(x.subject_id)?.nama || 'Mapel'}${props.pemantau ? ' · ' + (x.nama_guru || '') : ''}`, kelas: namaKelas(g), guru: x.nama_guru, niy: x.niy_guru })),
  ])
})
const terpilih = computed(() => daftar.value.find((x) => x.v === pilih.value))
</script>
<template>
  <div>
    <div class="mb-3"><label class="label-isian" for="kg-pilih">Kelas dan mata pelajaran</label>
      <select id="kg-pilih" v-model="pilih" class="isian md:max-w-xl"><option v-for="x in daftar" :key="x.v" :value="x.v">{{ x.n }}</option></select></div>
    <p v-if="!daftar.length" class="kartu p-8 text-center text-sm text-teks3">Belum ada penugasan mengajar.</p>
    <RekapKehadiranMapel v-else-if="terpilih" :key="pilih" :group-id="pilih.startsWith('g:') ? pilih.slice(2) : ''" :assignment-id="pilih.startsWith('t:') ? pilih.slice(2) : ''"
      :ttd-kanan="pilih.startsWith('t:') ? { jabatan: 'Guru Mata Pelajaran', nama: terpilih.guru || sesi.pengguna?.nama_lengkap, niy: terpilih.niy } : { jabatan: 'Pembuat laporan', nama: sesi.pengguna?.nama_lengkap, niy: sesi.pengguna?.niy }" />
  </div>
</template>
