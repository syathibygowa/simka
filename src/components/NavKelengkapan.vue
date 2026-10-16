<!-- SIMKA PRO | src/components/NavKelengkapan.vue | v1.0 | Perbaikan 13.9.0: navigasi Kelengkapan Data Santri (kembali, sebelumnya, berikutnya) | 16/10/2026 -->
<script setup>
// Bilah navigasi saat membuka santri dari halaman Kelengkapan Data Santri (?dari=kelengkapan):
//   • Kembali ke daftar kelengkapan (saringan dan posisi gulir dipulihkan di halaman tersebut),
//   • Santri ke-n dari N, tombol Sebelumnya/Berikutnya mengikuti urutan daftar,
//   • Data yang masih kosong untuk santri ini (dihitung ulang langsung dari data terbaru).
import { computed, watch } from 'vue'
import { useRouter } from 'vue-router'
import { PhArrowLeft, PhCaretLeft, PhCaretRight, PhCheckCircle, PhWarningCircle } from '@phosphor-icons/vue'
import { useSantri } from '@/stores/santri'
import { periksaSantri, KOLOM_BAWAAN } from '@/lib/kelengkapanSantri'

const props = defineProps({ id: { type: String, required: true } })
const router = useRouter(); const san = useSantri()
const urutan = (() => { try { return JSON.parse(sessionStorage.getItem('simka.kelengkapan.urutan')) || {} } catch { return {} } })()
const ids = urutan.ids || []
const posisi = computed(() => ids.indexOf(props.id))
const santri = computed(() => san.cari(props.id))
const hasil = computed(() => (santri.value ? periksaSantri(santri.value, urutan.kolom || KOLOM_BAWAAN) : null))
// Foto dan kelompok tidak diisi di formulir ini
const diLuarForm = computed(() => (hasil.value?.kurang || []).filter((c) => ['foto', 'kelas', 'kamar', 'halaqah', 'ekskul'].includes(c.k)))
// Santri yang sedang dibuka menjadi penanda "terakhir" saat kembali ke daftar kelengkapan
watch(() => props.id, (id) => {
  try { const k = JSON.parse(sessionStorage.getItem('simka.kelengkapan.keadaan')) || {}; k.terakhir = id; sessionStorage.setItem('simka.kelengkapan.keadaan', JSON.stringify(k)) } catch { /* abaikan */ }
}, { immediate: true })
const ke = (i) => { const id = ids[i]; if (id) router.replace({ path: urutan.ubah === false ? `/santri/${id}` : `/santri/${id}/ubah`, query: { dari: 'kelengkapan' } }) }
</script>
<template>
  <div class="nav-kelengkapan kartu w-santri layar-saja mx-auto mb-4 max-w-4xl p-3">
    <div class="flex flex-wrap items-center gap-2">
      <button type="button" class="tombol-garis min-h-[40px] px-3 text-sm" @click="router.push('/santri/kelengkapan')"><PhArrowLeft :size="18" /> Kelengkapan data</button>
      <span class="flex-1" />
      <template v-if="posisi >= 0">
        <span class="text-sm tabular-nums text-teks2">Santri <b class="text-teks">{{ posisi + 1 }}</b> dari {{ ids.length }}</span>
        <button type="button" class="tombol-garis min-h-[40px] px-3 text-sm" :disabled="posisi <= 0" aria-label="Santri sebelumnya" @click="ke(posisi - 1)"><PhCaretLeft :size="18" weight="bold" /> <span class="hidden sm:inline">Sebelumnya</span></button>
        <button type="button" class="tombol-utama min-h-[40px] px-3 text-sm" :disabled="posisi >= ids.length - 1" aria-label="Santri berikutnya" @click="ke(posisi + 1)"><span class="hidden sm:inline">Berikutnya</span> <PhCaretRight :size="18" weight="bold" /></button>
      </template>
    </div>
    <div v-if="hasil" class="mt-2.5 flex flex-wrap items-center gap-1.5 text-sm">
      <template v-if="hasil.kurang.length">
        <PhWarningCircle :size="18" weight="duotone" class="text-merah" /><span class="font-semibold">Belum diisi ({{ hasil.persen }}% lengkap):</span>
        <span v-for="c in hasil.kurang" :key="c.k" class="lencana w-klinik">{{ c.n }}</span>
      </template>
      <span v-else class="flex items-center gap-1.5 font-semibold text-[#1E7D4F] dark:text-[#6FD19A]"><PhCheckCircle :size="18" weight="fill" /> Data santri ini sudah lengkap.</span>
    </div>
    <p v-if="diLuarForm.length" class="mt-1.5 text-xs text-teks3">{{ diLuarForm.map((c) => c.n).join(', ') }} diisi di tempat lain: foto di Biodata santri, rombel/kamar/halaqah/ekskul di menu Kelompok Santri.</p>
  </div>
</template>
