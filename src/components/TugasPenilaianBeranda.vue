<!-- SIMKA PRO | src/components/TugasPenilaianBeranda.vue | v1.0 | Fase 12 – Tahap 6 Pengingat penilaian di beranda pegawai | 13/10/2026 -->
<script setup>
// Pengingat penilaian di "Untuk Anda" (beranda pegawai fungsional, tanpa kartu statistik): hanya tampil bila ada yang perlu
// dikerjakan pada semester berjalan — nilai rapor kosong (guru mapel), catatan wali kelas, UTAS belum dikirim (penguji),
// nilai pengembangan diri (pembina), permintaan ubah nilai (pengelola). Batas pengisian ditampilkan bila ada.
import { computed, onMounted } from 'vue'
import { PhChalkboardTeacher, PhNotePencil, PhBookOpenText, PhMedal, PhPencilLine, PhCaretRight } from '@phosphor-icons/vue'
import { useUbahNilai } from '@/stores/ubahNilai'
import { formatPendek } from '@/lib/tanggal'

const un = useUbahNilai()
onMounted(() => un.muatRingkas().catch(() => {}))
const r = computed(() => un.ringkas)
const batas = computed(() => { const b = (r.value?.periode || []).filter((p) => p.status === 'dibuka' && p.batas_isi).map((p) => p.batas_isi).sort()[0]; return b ? ` · batas ${formatPendek(b)}` : '' })
const dibuka = computed(() => (r.value?.periode || []).some((p) => p.status === 'dibuka'))
const item = computed(() => {
  const d = r.value; if (!d) return []
  const wali = (d.wali || []).reduce((t, w) => ({ s: t.s + w.santri, c: t.c + w.catatan }), { s: 0, c: 0 })
  return [
    dibuka.value && d.nilai_kurang > 0 && { ke: '/guru-mapel/nilai', ikon: PhChalkboardTeacher, w: 'gurumapel', judul: `${d.nilai_kurang} nilai rapor belum diisi`, ket: `${d.tugas - d.tugas_lengkap} dari ${d.tugas} kelas–mapel belum lengkap${batas.value}` },
    dibuka.value && wali.s > wali.c && { ke: '/wali-kelas/rapor', ikon: PhNotePencil, w: 'walikelas', judul: `${wali.s - wali.c} catatan wali kelas belum diisi`, ket: `Kelas ${(d.wali || []).map((x) => x.nama).join(', ')}${batas.value}` },
    d.utas_draf > 0 && { ke: '/tahfizh/ujian', ikon: PhBookOpenText, w: 'tahfizh', judul: `${d.utas_draf} nilai UTAS belum dikirim`, ket: 'Peserta yang Anda uji masih berstatus draf' },
    dibuka.value && d.pd_kurang > 0 && { ke: '/ekskul/nilai', ikon: PhMedal, w: 'ekskul', judul: `${d.pd_kurang} santri binaan belum dinilai`, ket: `Nilai pengembangan diri (ekskul)${batas.value}` },
    d.permintaan_menunggu > 0 && { ke: '/penilaian/permintaan', ikon: PhPencilLine, w: 'pengajuan', judul: `${d.permintaan_menunggu} permintaan ubah nilai`, ket: 'Menunggu keputusan Anda' },
  ].filter(Boolean)
})
</script>
<template>
  <div v-if="item.length">
    <router-link v-for="x in item" :key="x.judul" :to="x.ke" :class="['kartu mb-3 flex items-center gap-3 border-l-4 border-l-[color:var(--c)] p-4 hover:-translate-y-0.5 hover:shadow-apung', 'w-' + x.w]">
      <span class="chip-ikon h-11 w-11 shrink-0"><component :is="x.ikon" :size="24" weight="duotone" /></span>
      <span class="min-w-0 flex-1"><span class="block font-bold">{{ x.judul }}</span><span class="block truncate text-sm text-teks2">{{ x.ket }}</span></span>
      <PhCaretRight :size="18" class="text-teks3" />
    </router-link>
  </div>
</template>
