<!-- SIMKA PRO | src/components/KartuPersuratanBeranda.vue | v1.0 | Fase 10 – Penutup: statistik persuratan di Beranda | 11/10/2026 -->
<script setup>
// Kartu statistik langsung persuratan di Beranda (Tata Usaha, pengelola persuratan, pimpinan penyusun surat):
// perlu tindakan saya, tanda tangan surat menunggu saya, surat masuk menunggu disposisi, disposisi lewat batas,
// draf diperiksa TU, surat menunggu tanda tangan, surat keluar terbit bulan ini, dan surat masuk bulan ini.
// Diperbarui otomatis (Realtime) saat surat masuk, disposisi, atau surat keluar berubah.
import { ref, computed, onMounted, onBeforeUnmount } from 'vue'
import { PhTray, PhPenNib, PhHourglass, PhSiren, PhNotePencil, PhSignature, PhPaperPlaneTilt, PhEnvelopeSimpleOpen } from '@phosphor-icons/vue'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { usePersuratan } from '@/stores/persuratan'
import { useSesi } from '@/stores/sesi'
import KartuStatistik from './KartuStatistik.vue'

const ps = usePersuratan(); const sesi = useSesi()
const d = ref(null); let saluran = null; let jeda = null
async function muat() {
  if (!sesi.persuratan) return
  try { if (MODE_DEMO && !ps.hak.tampil) await ps.muatHak(); d.value = await ps.ringkasan() } catch { d.value = null }
}
const segera = () => { clearTimeout(jeda); jeda = setTimeout(muat, 600) }
onMounted(() => {
  muat()
  if (MODE_DEMO || !sesi.persuratan) return
  saluran = supabase.channel('beranda-persuratan')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'incoming_letters' }, segera)
    .on('postgres_changes', { event: '*', schema: 'public', table: 'letter_dispositions' }, segera)
    .on('postgres_changes', { event: '*', schema: 'public', table: 'outgoing_letters' }, segera).subscribe()
})
onBeforeUnmount(() => { clearTimeout(jeda); if (saluran) supabase.removeChannel(saluran) })

const kartu = computed(() => {
  const x = d.value; if (!x) return []
  const k = [
    { j: 'Perlu tindakan saya', v: x.perlu_tindakan_saya, i: PhTray, w: 'tatausaha', ke: '/persuratan/untuk-saya', ket: x.lewat_batas_saya ? `${x.lewat_batas_saya} lewat batas` : 'Surat dan disposisi' },
    { j: 'Tanda tangan surat', v: x.ttd_saya, i: PhPenNib, w: 'hakakses', ke: '/rekap/tandatangan', ket: 'Menunggu tanda tangan Anda' },
  ]
  if (x.kelola) k.push({ j: 'Draf perlu diperiksa', v: x.keluar_diperiksa, i: PhNotePencil, w: 'pengajuan', ke: '/persuratan/keluar', ket: 'Dari pimpinan ke Tata Usaha' })
  k.push(
    { j: 'Menunggu disposisi', v: x.menunggu_disposisi, i: PhHourglass, w: 'shift', ke: '/persuratan/masuk', ket: `${x.berjalan || 0} disposisi berjalan` },
    { j: 'Disposisi lewat batas', v: x.lewat_batas, i: PhSiren, w: 'klinik', ke: '/persuratan/masuk', ket: x.lewat_batas ? 'Segera ditindaklanjuti' : 'Semua tepat waktu' },
    { j: 'Surat menunggu TTD', v: x.keluar_menunggu_ttd, i: PhSignature, w: 'verifikasi', ke: '/persuratan/keluar', ket: 'Surat keluar diajukan' },
    { j: 'Surat keluar bulan ini', v: x.keluar_terbit_bulan_ini, i: PhPaperPlaneTilt, w: 'presensi', ke: '/persuratan/agenda', ket: 'Terbit dan bernomor' },
    { j: 'Surat masuk bulan ini', v: x.masuk_bulan_ini, i: PhEnvelopeSimpleOpen, w: 'agenda', ke: '/persuratan/agenda', ket: `${x.selesai_bulan_ini || 0} selesai` },
  )
  return k
})
</script>
<template>
  <section v-if="kartu.length">
    <div class="mb-3 flex items-center justify-between gap-2">
      <h2 class="judul-bagian">Persuratan</h2>
      <router-link to="/persuratan" class="text-sm font-semibold text-merah">Buka Persuratan</router-link>
    </div>
    <div class="grid grid-cols-2 gap-3 sm:gap-4 lg:grid-cols-3 xl:grid-cols-4">
      <KartuStatistik v-for="x in kartu" :key="x.j" :judul="x.j" :nilai="x.v ?? 0" :ikon="x.i" :warna="x.w" :ke="x.ke" :keterangan="x.ket" />
    </div>
  </section>
</template>
