<!-- SIMKA PRO | src/pages/musyrif/Musyrif.vue | v1.3 | Fase 6 – Tahap 4 Lapor ke bidang dan dasbor ringkasan | 06/10/2026 -->
<script setup>
// Menu Musyrif (kepengasuhan asrama). Musyrif/musyrifah melihat kamar asuhannya; admin, pimpinan, dan pemegang
// hak fitur Absensi Asrama melihat semua kamar. Tab: Dasbor (statistik langsung, sesi hari ini, perlu perhatian)
// dan Rekap (per santri, per pekan, per bulan, individu; cetak, Excel, WA wali, salin grup WA).
// Perizinan (v1.1): izin santri kamar terpilih — ajukan, pantau, catat keluar/kembali, WA wali.
// Ringkasan (v1.3): dasbor pemantauan semua kamar bagi admin/pimpinan (tampil bila dapat melihat lebih dari satu kamar).
// Jurnal (v1.2): catatan kegiatan kepengasuhan harian, tanggapan pimpinan, cetak, salin ke grup WA.
import { computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { PhGauge, PhChartBar, PhHouseLine, PhLockSimple, PhWhatsappLogo, PhUsersThree, PhSignOut, PhNotePencil, PhSquaresFour } from '@phosphor-icons/vue'
import { useMusyrif } from '@/stores/musyrif'
import { useUI } from '@/stores/ui'
import { useSantri } from '@/stores/santri'
import BilahTab from '@/components/BilahTab.vue'
import TabDasborMusyrif from './TabDasborMusyrif.vue'
import TabRekapMusyrif from './TabRekapMusyrif.vue'
import TabIzin from '@/pages/izin/TabIzin.vue'
import TabJurnalMusyrif from './TabJurnalMusyrif.vue'
import TabRingkasanMusyrif from './TabRingkasanMusyrif.vue'

const props = defineProps({ tab: { type: String, default: '' } })
const router = useRouter(); const mu = useMusyrif(); const ui = useUI(); const san = useSantri()
onMounted(async () => { try { await mu.muatKamar() } catch (e) { ui.toast(e.message, 'galat') } })
const pemantau = computed(() => mu.kamar.length > 1 || mu.kamar.some((k) => !k.asuhan_saya))
const TAB = computed(() => [...(pemantau.value ? [{ k: 'ringkasan', n: 'Semua kamar', ikon: PhSquaresFour, w: 'musyrif' }] : []), { k: 'dasbor', n: 'Dasbor', ikon: PhGauge, w: 'musyrif' }, { k: 'rekap', n: 'Rekap', ikon: PhChartBar, w: 'rekap' }, { k: 'jurnal', n: 'Jurnal', ikon: PhNotePencil, w: 'musyrif' }, { k: 'izin', n: 'Perizinan', ikon: PhSignOut, w: 'pengajuan' }])
const aktif = computed(() => (TAB.value.some((t) => t.k === props.tab) ? props.tab : pemantau.value ? 'ringkasan' : 'dasbor'))
const k = computed(() => mu.kamarPilih)
/** Santri kamar terpilih (calon pengajuan izin). */
const santriKamar = computed(() => san.daftar.filter((s) => s.status === 'aktif' && (s.kelompok || []).some((g) => g.id === mu.pilih)).map((s) => ({ id: s.id, nama: s.nama_lengkap, nis: s.nis })))
const daftarMusyrif = computed(() => (k.value?.musyrif || []).map((m) => m.nama).join(', ') || 'Belum ada musyrif')
</script>
<template>
  <div>
    <div v-if="mu.dimuat && !mu.kamar.length" class="kartu w-musyrif flex items-center gap-3 p-5">
      <span class="chip-ikon h-11 w-11"><PhLockSimple :size="24" weight="duotone" /></span>
      <p class="text-sm text-teks2">Belum ada kamar yang dapat Anda lihat. Menu Musyrif terbuka bagi musyrif/musyrifah yang ditetapkan pada kamar (Kelompok Santri), pimpinan, dan admin.</p>
    </div>
    <template v-else-if="k">
      <section v-if="aktif !== 'ringkasan'" class="kartu w-musyrif kepala-kamar mb-4 p-4 sm:p-5">
        <div class="flex flex-wrap items-center gap-3">
          <span class="chip-ikon h-12 w-12 shrink-0"><PhHouseLine :size="26" weight="duotone" /></span>
          <div class="min-w-0 flex-1">
            <select v-if="mu.kamar.length > 1" v-model="mu.pilih" class="isian max-w-full py-1 text-base font-bold" aria-label="Pilih kamar">
              <option v-for="x in mu.kamar" :key="x.id" :value="x.id">{{ x.nama }}{{ x.asuhan_saya ? ' (asuhan saya)' : '' }}</option></select>
            <h2 v-else class="text-lg font-bold">{{ k.nama }}</h2>
            <p class="mt-1 text-sm text-teks2"><PhUsersThree :size="16" class="inline" /> {{ k.jumlah }} santri · {{ k.jenis_kelamin === 'P' ? 'Putri' : 'Putra' }}{{ k.keterangan ? ' · ' + k.keterangan : '' }}</p>
            <p class="text-xs text-teks3">Musyrif: {{ daftarMusyrif }}</p>
          </div>
          <div class="flex flex-wrap gap-2">
            <a v-if="k.wa_wali" :href="k.wa_wali" target="_blank" rel="noopener" class="tombol-garis w-presensi min-h-[40px] px-3 text-sm"><PhWhatsappLogo :size="18" weight="duotone" style="color: var(--c)" /> Grup wali</a>
            <a v-if="k.wa_internal" :href="k.wa_internal" target="_blank" rel="noopener" class="tombol-garis w-agenda min-h-[40px] px-3 text-sm"><PhWhatsappLogo :size="18" weight="duotone" style="color: var(--c)" /> Grup internal</a>
          </div>
        </div>
      </section>
      <BilahTab class="mb-4" :tab="TAB" :model-value="aktif" label="Bagian musyrif" @update:model-value="(x) => router.replace(`/musyrif/${x}`)" />
      <TabRingkasanMusyrif v-if="aktif === 'ringkasan'" @buka="router.replace('/musyrif/dasbor')" />
      <TabDasborMusyrif v-else-if="aktif === 'dasbor'" :key="'d' + mu.pilih" @rekap="router.replace('/musyrif/rekap')" />
      <TabRekapMusyrif v-else-if="aktif === 'rekap'" :key="'r' + mu.pilih" />
      <TabJurnalMusyrif v-else-if="aktif === 'jurnal'" :key="'j' + mu.pilih" :calon="santriKamar" />
      <TabIzin v-else :key="'i' + mu.pilih" :group="mu.pilih" :calon="santriKamar" peran-utama="musyrif" />
    </template>
    <p v-else class="kartu p-8 text-center text-sm text-teks3">Memuat kamar…</p>
  </div>
</template>
<style scoped>
.kepala-kamar { background: linear-gradient(135deg, color-mix(in srgb, var(--c) 12%, rgb(var(--permukaan))), rgb(var(--permukaan)) 70%); }
</style>
