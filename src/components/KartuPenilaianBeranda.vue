<!-- SIMKA PRO | src/components/KartuPenilaianBeranda.vue | v1.0 | Fase 12 – Tahap 6 Ringkasan penilaian di beranda | 13/10/2026 -->
<script setup>
// Kartu penilaian di beranda: apa yang perlu dikerjakan pengguna pada semester berjalan.
//   Guru mapel : kelas–mapel lengkap dan jumlah nilai rapor yang masih kosong
//   Wali kelas : catatan wali kelas terisi
//   Penguji    : nilai UTAS yang belum dikirim (draf);  Pembina ekskul: nilai pengembangan diri yang belum diisi
//   Pengelola  : permintaan ubah nilai menunggu;  Pimpinan: tautan rekap
// Status periode (dibuka sampai batas pengisian / ditutup) tampil sebagai keterangan. Kartu tidak tampil bila tidak relevan.
import { computed, onMounted } from 'vue'
import { PhChalkboardTeacher, PhNotePencil, PhBookOpenText, PhMedal, PhPencilLine, PhChartBar } from '@phosphor-icons/vue'
import { useUbahNilai } from '@/stores/ubahNilai'
import { STATUS_PERIODE, JENIS_RAPOR } from '@/lib/penilaian'
import { formatPendek } from '@/lib/tanggal'
import KartuStatistik from './KartuStatistik.vue'

const un = useUbahNilai()
onMounted(() => un.muatRingkas().catch(() => {}))
const r = computed(() => un.ringkas)
const periode = computed(() => (r.value?.periode || []).filter((p) => p.status !== 'disiapkan').map((p) => `${JENIS_RAPOR[p.jenis]?.pendek} ${STATUS_PERIODE[p.status].n.toLowerCase()}${p.status === 'dibuka' && p.batas_isi ? ` s.d. ${formatPendek(p.batas_isi)}` : ''}`).join(' · '))
const wali = computed(() => (r.value?.wali || []).reduce((t, w) => ({ santri: t.santri + w.santri, catatan: t.catatan + w.catatan }), { santri: 0, catatan: 0 }))
const kartu = computed(() => {
  const d = r.value; if (!d) return []
  return [
    d.tugas > 0 && { judul: 'Nilai mapel saya', nilai: `${d.tugas_lengkap}/${d.tugas}`, ikon: PhChalkboardTeacher, warna: 'gurumapel', ke: '/guru-mapel/nilai',
      keterangan: d.nilai_kurang ? `${d.nilai_kurang} nilai rapor masih kosong` : 'Semua kelas–mapel lengkap' },
    (d.wali || []).length > 0 && { judul: 'Catatan wali kelas', nilai: `${wali.value.catatan}/${wali.value.santri}`, ikon: PhNotePencil, warna: 'walikelas', ke: '/wali-kelas/rapor',
      keterangan: `Kelas ${(d.wali || []).map((w) => w.nama).join(', ')}` },
    d.utas_draf > 0 && { judul: 'UTAS belum dikirim', nilai: d.utas_draf, ikon: PhBookOpenText, warna: 'tahfizh', ke: '/tahfizh/ujian', keterangan: 'Peserta yang Anda uji (draf)' },
    d.pd_kurang > 0 && { judul: 'Pengembangan diri', nilai: d.pd_kurang, ikon: PhMedal, warna: 'ekskul', ke: '/ekskul/nilai', keterangan: 'Santri binaan belum dinilai' },
    d.permintaan_menunggu != null && { judul: 'Permintaan ubah nilai', nilai: d.permintaan_menunggu, ikon: PhPencilLine, warna: 'pengajuan', ke: '/penilaian/permintaan', keterangan: 'Menunggu keputusan Anda' },
    d.permintaan_menunggu == null && d.permintaan_saya > 0 && { judul: 'Permintaan saya', nilai: d.permintaan_saya, ikon: PhPencilLine, warna: 'pengajuan', keterangan: 'Ubah nilai menunggu keputusan' },
    d.rekap && { judul: 'Rekap penilaian', nilai: 'Lihat', ikon: PhChartBar, warna: 'laporan', ke: '/penilaian/rekap', keterangan: 'Kemajuan pengisian rapor' },
  ].filter(Boolean)
})
</script>
<template>
  <section v-if="kartu.length">
    <div class="mb-3 flex flex-wrap items-center justify-between gap-2">
      <h2 class="judul-bagian">Penilaian semester {{ r.semester }}</h2>
      <p v-if="periode" class="text-xs text-teks3">{{ periode }}</p>
    </div>
    <div class="grid grid-cols-2 gap-3 sm:gap-4 lg:grid-cols-3 xl:grid-cols-4">
      <KartuStatistik v-for="k in kartu" :key="k.judul" v-bind="k" />
    </div>
  </section>
</template>
