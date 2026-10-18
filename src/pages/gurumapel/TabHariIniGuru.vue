<!-- SIMKA PRO | src/pages/gurumapel/TabHariIniGuru.vue | v1.1 | 14.4.0: tombol laporan hari ini/pekan ini ke grup WA | 17/10/2026 -->
<script setup>
// Halaman kerja guru mapel: statistik (JP hari ini, jurnal terisi, keterlaksanaan bulan ini, kelas diampu), jadwal
// mengajar hari ini beserta status jurnal tiap jam dan tombol "Isi jurnal mengajar", pengingat jurnal kemarin yang
// belum diisi (batas H+1), dan daftar kelas-mapel yang diampu beserta wali kelasnya.
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { PhSun, PhNotePencil, PhChartLineUp, PhChalkboard, PhWarningCircle, PhBookOpenText, PhCheckSquareOffset, PhWhatsappLogo } from '@phosphor-icons/vue'
import { useJadwal } from '@/stores/jadwal'
import { useKelompokSantri } from '@/stores/kelompokSantri'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { teksPersen } from '@/lib/absensi'
import { awalBulanDari, tambahHari } from '@/lib/musyrif'
import { STATUS_JP, statusSlot, rekapPenugasan, persenJP } from '@/lib/guruMapel'
import { hariIniISO, formatHari } from '@/lib/tanggal'
import KartuStatistik from '@/components/KartuStatistik.vue'

const jd = useJadwal(); const kel = useKelompokSantri(); const sesi = useSesi(); const ui = useUI(); const router = useRouter()
const hari = hariIniISO(); const awal = awalBulanDari(hari); const kemarin = tambahHari(hari, -1)
const slot = ref([]); const memuat = ref(true)
const saya = computed(() => jd.idSaya())
onMounted(async () => {
  try { await Promise.all([jd.muat(), kel.daftar.length ? null : kel.muat()]); slot.value = await jd.slot(awal < kemarin ? awal : kemarin, hari, null, saya.value) }
  catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false }
})
const hariIni = computed(() => slot.value.filter((s) => s.tanggal === hari))
const bulan = computed(() => slot.value.filter((s) => s.tanggal >= awal))
const lewatBulan = computed(() => bulan.value.filter((s) => s.lewat))
const belumKemarin = computed(() => slot.value.filter((s) => s.tanggal === kemarin && s.status === 'belum'))
// Nama kelas dan wali kelas dari slot (hasil server), cadangan dari daftar kelompok yang terlihat
const penugasan = computed(() => jd.penugasan.filter((t) => t.employee_id === saya.value).map((t) => {
  const sl = slot.value.find((x) => x.assignment_id === t.id); const g = kel.cari(t.group_id)
  return { ...t, kelas: sl?.kelas || g?.nama || '–', mapel: sl?.mapel || jd.cariMapel(t.subject_id)?.nama || '–',
    wali: sl?.wali_kelas || (g?.pengasuh || []).filter((p) => p.berlaku !== false).map((p) => p.nama).join(', ') }
}).sort((a, b) => a.kelas.localeCompare(b.kelas, 'id', { numeric: true })))
const statistik = computed(() => [
  { judul: 'Jam mengajar hari ini', nilai: hariIni.value.length, ikon: PhSun, warna: 'beranda', ket: hariIni.value.length ? `${hariIni.value[0].jam_mulai}–${hariIni.value[hariIni.value.length - 1].jam_selesai} WITA` : 'Tidak ada jadwal hari ini' },
  { judul: 'Jurnal hari ini', nilai: `${hariIni.value.filter((s) => s.status !== 'belum').length}/${hariIni.value.length}`, ikon: PhNotePencil, warna: 'tatausaha', ket: 'Jam yang sudah diisi jurnalnya' },
  { judul: 'Keterlaksanaan bulan ini', nilai: teksPersen(persenJP(lewatBulan.value.filter((s) => s.status === 'terlaksana').length, lewatBulan.value.length)), ikon: PhChartLineUp, warna: 'presensi',
    ket: `${lewatBulan.value.filter((s) => s.status === 'belum').length} JP belum diisi` },
  { judul: 'Kelas diampu', nilai: new Set(penugasan.value.map((t) => t.group_id)).size, ikon: PhChalkboard, warna: 'gurumapel', ket: `${penugasan.value.length} kelas-mapel · ${penugasan.value.reduce((a, t) => a + (t.jp_pekan || 0), 0)} JP/pekan` },
])
const rekapBulan = computed(() => rekapPenugasan(bulan.value))
const isiJurnal = () => router.push('/jurnal/mengajar')
</script>
<template>
  <div class="space-y-4">
    <div class="-mx-4 flex snap-x gap-3 overflow-x-auto px-4 pb-1 sm:mx-0 sm:grid sm:grid-cols-4 sm:overflow-visible sm:px-0">
      <KartuStatistik v-for="k in statistik" :key="k.judul" class="w-[44%] shrink-0 snap-start sm:w-auto" :judul="k.judul" :nilai="memuat ? '…' : k.nilai" :ikon="k.ikon" :warna="k.warna" :keterangan="k.ket" />
    </div>

    <div class="flex flex-wrap gap-2">
      <router-link to="/guru-mapel/jurnal?periode=hari&mode=semua" class="tombol-wa-garis min-h-[40px] px-4 text-sm"><PhWhatsappLogo :size="18" weight="duotone" /> Lapor jurnal hari ini ke grup</router-link>
      <router-link to="/guru-mapel/jurnal?periode=pekan&mode=semua" class="tombol-garis min-h-[40px] px-4 text-sm"><PhWhatsappLogo :size="18" weight="duotone" /> Rekap pekan ini</router-link>
    </div>

    <div v-if="belumKemarin.length" class="kartu w-tahfizh flex flex-wrap items-center gap-3 p-4">
      <PhWarningCircle :size="26" weight="duotone" style="color: var(--c)" class="shrink-0" />
      <p class="min-w-[200px] flex-1 text-sm"><b>{{ belumKemarin.length }} jam pelajaran kemarin belum diisi jurnalnya</b>
        <span class="block text-xs text-teks3">{{ formatHari(kemarin) }}: {{ belumKemarin.map((s) => `${s.mapel} ${s.kelas}`).join(', ') }}. Batas pengisian hari ini (H+1).</span></p>
      <button class="tombol-utama min-h-[40px] px-4 text-sm" @click="isiJurnal">Isi sekarang</button>
    </div>

    <div class="grid gap-4 lg:grid-cols-[1.3fr_1fr]">
      <section class="kartu w-gurumapel p-4">
        <div class="mb-3 flex flex-wrap items-center gap-2"><PhBookOpenText :size="22" weight="duotone" style="color: var(--c)" /><h2 class="judul-bagian flex-1">Mengajar hari ini · {{ formatHari(hari) }}</h2>
          <button class="tombol-utama min-h-[40px] px-4 text-sm" :disabled="!hariIni.length" @click="isiJurnal"><PhNotePencil :size="18" weight="duotone" /> Isi jurnal mengajar</button></div>
        <ul class="space-y-2">
          <li v-for="s in hariIni" :key="s.period_id + s.assignment_id" class="flex items-center gap-3 rounded-xl border border-garis p-3" :class="'w-' + STATUS_JP[statusSlot(s)].w">
            <span class="w-24 shrink-0 text-sm font-bold tabular-nums">{{ s.jam_mulai }}–{{ s.jam_selesai }}<span class="block text-xs font-normal text-teks3">{{ s.jam_ke }}</span></span>
            <span class="min-w-0 flex-1"><b class="block truncate">{{ s.mapel }}</b><span class="block truncate text-xs text-teks3">Kelas {{ s.kelas }}<template v-if="s.materi"> · {{ s.materi }}</template></span></span>
            <span class="lencana shrink-0" :class="'w-' + STATUS_JP[statusSlot(s)].w">{{ STATUS_JP[statusSlot(s)].n }}</span>
          </li>
          <li v-if="!memuat && !hariIni.length" class="p-4 text-center text-sm text-teks3">Tidak ada jadwal mengajar hari ini.</li>
        </ul>
        <p class="mt-3 flex items-start gap-2 text-xs text-teks3"><PhCheckSquareOffset :size="16" class="mt-0.5 shrink-0" /> Jurnal mengajar adalah bukti kehadiran mengajar dan dasar tunjangan guru. Batas pengisian H+1.</p>
      </section>

      <section class="kartu w-jadwal p-4">
        <div class="mb-3 flex items-center gap-2"><PhChalkboard :size="22" weight="duotone" style="color: var(--c)" /><h2 class="judul-bagian">Kelas dan mapel yang diampu</h2></div>
        <ul class="divide-y divide-garis">
          <li v-for="t in penugasan" :key="t.id" class="py-2.5 text-sm">
            <div class="flex items-center gap-2"><b class="flex-1">{{ t.mapel }} · kelas {{ t.kelas }}</b><span class="text-xs text-teks3">{{ t.jp_pekan }} JP/pekan</span>
              <span v-if="rekapBulan.find((r) => r.assignment_id === t.id)" class="lencana w-presensi">{{ teksPersen(rekapBulan.find((r) => r.assignment_id === t.id).persen) }}</span></div>
            <p class="text-xs text-teks3">Wali kelas: {{ t.wali || 'belum ditetapkan' }}</p>
          </li>
          <li v-if="!penugasan.length" class="py-4 text-center text-sm text-teks3">Belum ada penugasan mengajar.</li>
        </ul>
      </section>
    </div>
  </div>
</template>
