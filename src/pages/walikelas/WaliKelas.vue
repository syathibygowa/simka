<!-- SIMKA PRO | src/pages/walikelas/WaliKelas.vue | v1.2 | 14.2.0: tombol WhatsApp hijau | 17/10/2026 -->
<script setup>
// Menu Wali Kelas. Wali kelas melihat kelasnya; admin, superadmin, dan pimpinan (pemegang hak Absensi Kelas/Jadwal
// mengajar menurut jenjangnya) melihat semua kelas. Tab:
//   Semua kelas (pemantau) : kehadiran, absensi hari ini, sakit/izin, keterlaksanaan pelajaran per kelas; cetak dan Excel
//   Dasbor                 : statistik langsung kelas terpilih, absensi kelas hari ini (tombol isi), pelajaran hari ini,
//                            santri yang perlu perhatian (WA wali), santri sakit/di klinik
//   Santri                 : daftar santri kelas, kehadiran bulan ini, kontak orang tua/wali; cetak daftar
//   Pelajaran              : keterlaksanaan jurnal mengajar per mapel/guru dan materi per tanggal; roster kelas
//   Rekap                  : rekap absensi kelas (Excel, cetak F4, WA ke wali)
//   Perizinan              : izin santri kelas (wali kelas sebagai pengusul)
//   Rapor (v1.1)           : catatan wali kelas (disusun otomatis, dapat disunting) dan kokurikuler SMA
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { PhGauge, PhChartBar, PhChalkboard, PhLockSimple, PhWhatsappLogo, PhUsersThree, PhSignOut, PhSquaresFour, PhStudent, PhBookOpenText, PhExam } from '@phosphor-icons/vue'
import { useWaliKelas } from '@/stores/waliKelas'
import { useSantri } from '@/stores/santri'
import { useSesi } from '@/stores/sesi'
import { JENJANG_PENDEK } from '@/lib/santri'
import BilahTab from '@/components/BilahTab.vue'
import TabRingkasanKelas from './TabRingkasanKelas.vue'
import TabDasborKelas from './TabDasborKelas.vue'
import TabSantriKelas from './TabSantriKelas.vue'
import TabPelajaranKelas from './TabPelajaranKelas.vue'
import TabRekapAbsensi from '@/pages/absensisantri/TabRekapAbsensi.vue'
import TabIzin from '@/pages/izin/TabIzin.vue'
import TabRaporKelas from './TabRaporKelas.vue'

const props = defineProps({ tab: { type: String, default: '' } })
const router = useRouter(); const wk = useWaliKelas(); const san = useSantri(); const sesi = useSesi(); const galat = ref('')
async function muat(paksa = false) { galat.value = ''; try { await wk.muatKelas(paksa) } catch (e) { galat.value = e.message } }
onMounted(() => { muat(true); san.muat().catch(() => {}) })
/** Pemantau = admin/superadmin, pemegang hak Absensi Kelas cakupan luas, atau yang melihat lebih dari kelas asuhannya. */
const pemantau = computed(() => sesi.isAdmin || sesi.luas('absensi_kelas') || wk.kelas.some((k) => !k.asuhan_saya))
const TAB = computed(() => [
  ...(pemantau.value ? [{ k: 'ringkasan', n: 'Semua kelas', ikon: PhSquaresFour, w: 'walikelas' }] : []),
  { k: 'dasbor', n: 'Dasbor', ikon: PhGauge, w: 'walikelas' }, { k: 'santri', n: 'Santri', ikon: PhStudent, w: 'santri' },
  { k: 'pelajaran', n: 'Pelajaran', ikon: PhBookOpenText, w: 'gurumapel' }, { k: 'rekap', n: 'Rekap absensi', ikon: PhChartBar, w: 'rekap' },
  { k: 'izin', n: 'Perizinan', ikon: PhSignOut, w: 'pengajuan' }, { k: 'rapor', n: 'Rapor', ikon: PhExam, w: 'rapor' }])
const aktif = computed(() => (TAB.value.some((t) => t.k === props.tab) ? props.tab : pemantau.value ? 'ringkasan' : 'dasbor'))
const k = computed(() => wk.kelasPilih)
const santriKelas = computed(() => san.daftar.filter((s) => s.status === 'aktif' && (s.kelompok || []).some((g) => g.id === wk.pilih)).map((s) => ({ id: s.id, nama: s.nama_lengkap, nis: s.nis })))
const daftarWali = computed(() => (k.value?.wali || []).map((m) => m.nama).join(', ') || 'Belum ada wali kelas')
const pindah = (x) => router.replace(`/wali-kelas/${x}`)
</script>
<template>
  <div class="w-walikelas">
    <div v-if="galat" class="kartu w-klinik flex flex-wrap items-center gap-3 p-5">
      <p class="min-w-[200px] flex-1 text-sm font-semibold" style="color: var(--c)">Data kelas gagal dimuat: {{ galat }} Pastikan migrasi SQL 8100 sudah dijalankan.</p>
      <button class="tombol-utama" @click="muat(true)">Coba lagi</button>
    </div>
    <template v-else-if="wk.dimuat && !wk.kelas.length && pemantau">
      <BilahTab class="mb-4" :tab="TAB.slice(0, 1)" model-value="ringkasan" label="Bagian wali kelas" />
      <TabRingkasanKelas />
    </template>
    <div v-else-if="wk.dimuat && !wk.kelas.length" class="kartu flex items-center gap-3 p-5">
      <span class="chip-ikon h-11 w-11"><PhLockSimple :size="24" weight="duotone" /></span>
      <p class="text-sm text-teks2">Belum ada kelas yang dapat Anda lihat. Menu Wali Kelas terbuka bagi wali kelas yang ditetapkan pada kelas (Kelompok Santri → Kelas), pimpinan, dan admin.</p>
    </div>
    <template v-else-if="k">
      <section v-if="aktif !== 'ringkasan'" class="kartu kepala-kelas mb-4 p-4 sm:p-5">
        <div class="flex flex-wrap items-center gap-3">
          <span class="chip-ikon h-12 w-12 shrink-0"><PhChalkboard :size="26" weight="duotone" /></span>
          <div class="min-w-0 flex-1 basis-[60%]">
            <select v-if="wk.kelas.length > 1" v-model="wk.pilih" class="isian max-w-full py-1 text-base font-bold" aria-label="Pilih kelas">
              <option v-for="x in wk.kelas" :key="x.id" :value="x.id">Kelas {{ x.nama }} · {{ JENJANG_PENDEK[x.jenjang] || '' }}{{ x.asuhan_saya ? ' (kelas saya)' : '' }}</option></select>
            <h2 v-else class="text-lg font-bold">Kelas {{ k.nama }}</h2>
            <p class="mt-1 text-sm text-teks2"><PhUsersThree :size="16" class="inline" /> {{ k.jumlah }} santri ({{ k.putra }} putra, {{ k.putri }} putri) · {{ JENJANG_PENDEK[k.jenjang] }} kelas {{ k.tingkat }} · {{ k.mapel }} mapel</p>
            <p class="text-xs text-teks3">Wali kelas: {{ daftarWali }}</p>
          </div>
          <div class="flex w-full flex-wrap gap-2 sm:w-auto">
            <a v-if="k.wa_wali" :href="k.wa_wali" target="_blank" rel="noopener" class="tombol-wa-garis w-presensi min-h-[40px] px-3 text-sm"><PhWhatsappLogo :size="18" weight="duotone" /> Grup wali santri</a>
            <a v-if="k.wa_internal" :href="k.wa_internal" target="_blank" rel="noopener" class="tombol-wa-garis w-agenda min-h-[40px] px-3 text-sm"><PhWhatsappLogo :size="18" weight="duotone" /> Grup internal</a>
          </div>
        </div>
      </section>
      <BilahTab class="mb-4" :tab="TAB" :model-value="aktif" label="Bagian wali kelas" @update:model-value="pindah" />
      <TabRingkasanKelas v-if="aktif === 'ringkasan'" @buka="pindah('dasbor')" />
      <TabDasborKelas v-else-if="aktif === 'dasbor'" :key="'d' + wk.pilih" @rekap="pindah('rekap')" @pelajaran="pindah('pelajaran')" />
      <TabSantriKelas v-else-if="aktif === 'santri'" :key="'s' + wk.pilih" />
      <TabPelajaranKelas v-else-if="aktif === 'pelajaran'" :key="'p' + wk.pilih" />
      <TabRekapAbsensi v-else-if="aktif === 'rekap'" :key="'r' + wk.pilih" :group="wk.pilih" />
      <TabRaporKelas v-else-if="aktif === 'rapor'" :key="'rp' + wk.pilih" />
      <TabIzin v-else :key="'i' + wk.pilih" :group="wk.pilih" :calon="santriKelas" peran-utama="wali_kelas" />
    </template>
    <p v-else class="kartu p-8 text-center text-sm text-teks3">Memuat kelas…</p>
  </div>
</template>
<style scoped>
.kepala-kelas { background: linear-gradient(135deg, color-mix(in srgb, var(--c) 12%, rgb(var(--permukaan))), rgb(var(--permukaan)) 70%); }
</style>
