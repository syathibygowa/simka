<!-- SIMKA PRO | src/pages/beranda/RingkasanPimpinan.vue | v1.0 | Fase 3 – Tahap 6 Dashboard per peran | 04/10/2026 -->
<script setup>
// Kartu beranda pimpinan (P2: Kepala Bidang/Unit, Direktur/Wadir, Yayasan, termasuk Plt): antrean persetujuan,
// kehadiran dan pengisian jurnal anggota unit hari ini, serta anggota yang sedang izin/sakit/cuti/dinas luar.
import { computed } from 'vue'
import { PhStamp, PhUsersThree, PhNotebook, PhUserMinus } from '@phosphor-icons/vue'
import { formatPendek } from '@/lib/tanggal'
import KartuStatistik from '@/components/KartuStatistik.vue'

const props = defineProps({ d: { type: Object, default: () => ({}) } })
const pJurnal = computed(() => (props.d.jurnal_wajib ? Math.round((100 * props.d.jurnal_terisi) / props.d.jurnal_wajib) : null))
</script>
<template>
  <div class="space-y-3">
    <div class="grid grid-cols-2 gap-3 sm:gap-4 lg:grid-cols-4">
      <KartuStatistik judul="Menunggu persetujuan Anda" :nilai="d.persetujuan_menunggu" :ikon="PhStamp" warna="verifikasi" ke="/pengajuan?tab=persetujuan" :keterangan="d.persetujuan_menunggu ? 'Ketuk untuk memutus' : 'Tidak ada antrean'" />
      <KartuStatistik judul="Anggota hadir hari ini" :nilai="`${d.hadir ?? 0}/${d.anggota ?? 0}`" :ikon="PhUsersThree" warna="presensi" ke="/rekap-presensi" :keterangan="`${d.terlambat ?? 0} terlambat`" />
      <KartuStatistik judul="Jurnal anggota hari ini" :nilai="pJurnal == null ? '–' : pJurnal + '%'" :ikon="PhNotebook" warna="tatausaha" ke="/jurnal/rekap" :keterangan="`${d.jurnal_terisi ?? 0} dari ${d.jurnal_wajib ?? 0} sudah mengisi`" />
      <KartuStatistik judul="Izin, sakit, cuti, dinas" :nilai="d.tidak_hadir?.length ?? 0" :ikon="PhUserMinus" warna="klinik" keterangan="Anggota hari ini" />
    </div>
    <section v-if="d.tidak_hadir?.length" class="kartu p-4">
      <h3 class="judul-bagian mb-2">Anggota yang tidak bertugas hari ini</h3>
      <ul class="divide-y divide-garis">
        <li v-for="(t, i) in d.tidak_hadir" :key="i" class="flex items-center gap-3 py-2 text-sm">
          <span class="min-w-0 flex-1 font-semibold">{{ t.nama }}</span><span class="lencana w-pengajuan">{{ t.jenis }}</span><span class="text-xs text-teks3">s.d. {{ formatPendek(t.selesai) }}</span>
        </li>
      </ul>
    </section>
  </div>
</template>
