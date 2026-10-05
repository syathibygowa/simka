<!-- SIMKA PRO | src/pages/ekskul/Ekskul.vue | v1.2 | Fase 6 – Tahap 4 Lapor ke bidang dan dasbor ringkasan | 06/10/2026 -->
<script setup>
// Ekskul: Pertemuan (absensi HISBAT + jurnal materi per pertemuan), Jadwal pertemuan (otomatis menjadi sesi
// presensi pembina/pelatih), dan Rekap (kehadiran santri, jurnal materi; Excel dan cetak F4).
// Ekskul adalah kegiatan eksternal: tidak memengaruhi persentase kehadiran program pokok santri.
// v1.2: tab Dasbor — perkembangan semua ekskul (pertemuan, kehadiran, jurnal materi) untuk admin/pimpinan/pembina.
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import BilahTab from '@/components/BilahTab.vue'
import { PhMedal, PhCalendarDots, PhChartBar, PhCaretRight, PhPencilSimple, PhPlus, PhX, PhFloppyDisk, PhMapPin, PhUserCircle, PhInfo, PhGauge } from '@phosphor-icons/vue'
import { useAbsensiSantri } from '@/stores/absensiSantri'
import { useKelompokSantri } from '@/stores/kelompokSantri'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { STATUS_SESI, jam } from '@/lib/absensi'
import { HARI, hariIniISO, formatHari } from '@/lib/tanggal'
import InputTanggal from '@/components/InputTanggal.vue'
import LembarBawah from '@/components/LembarBawah.vue'
import TabRekapEkskul from './TabRekapEkskul.vue'
import TabDasborEkskul from './TabDasborEkskul.vue'

const props = defineProps({ tab: { type: String, default: '' } })
const router = useRouter(); const abs = useAbsensiSantri(); const kel = useKelompokSantri(); const sesi = useSesi(); const ui = useUI()
const TAB = [{ k: 'dasbor', n: 'Dasbor', ikon: PhGauge, w: 'ekskul' }, { k: 'pertemuan', n: 'Pertemuan', ikon: PhMedal, w: 'ekskul' }, { k: 'jadwal', n: 'Jadwal', ikon: PhCalendarDots, w: 'agenda' }, { k: 'rekap', n: 'Rekap', ikon: PhChartBar, w: 'rekap' }]
const aktif = computed(() => (TAB.some((t) => t.k === props.tab) ? props.tab : lihatSemua.value ? 'dasbor' : 'pertemuan'))
const lihatSemua = computed(() => sesi.isAdmin || sesi.tingkat('absensi_ekskul') >= 1 && sesi.tingkat('data_santri') >= 1)
const bolehAtur = computed(() => sesi.bolehAdmin('kelompok_santri') || sesi.tingkat('kelompok_santri') >= 2)
const tanggal = ref(hariIniISO())

async function muat() {
  if (aktif.value === 'pertemuan') await abs.muatSesi(tanggal.value, lihatSemua.value)
  if (aktif.value === 'jadwal') { await kel.muat(); try { await kel.muatJadwal() } catch (e) { ui.toast(e.message, 'galat') } }
}
onMounted(muat)
watch([aktif, tanggal], muat)
const pertemuan = computed(() => abs.sesiHari.filter((s) => s.jenis === 'ekskul'))
const ekskul = computed(() => kel.dariTA.filter((g) => g.jenis === 'ekskul' && g.aktif))
const pilihTab = (k) => router.replace(`/ekskul/${k}`)

// ---------- Ubah jadwal ----------
const lembar = ref(false); const gEdit = ref(null); const baris = ref([]); const proses = ref(false)
function bukaJadwal(g) { gEdit.value = g; baris.value = (kel.jadwal[g.id] || []).map((j) => ({ ...j })); if (!baris.value.length) tambahBaris(); lembar.value = true }
function tambahBaris() { baris.value.push({ hari: 2, jam_mulai: '15:30', jam_selesai: '17:00', tempat: '' }) }
async function simpanJadwal() {
  for (const b of baris.value) if (!b.jam_mulai || !b.jam_selesai || b.jam_selesai <= b.jam_mulai) return ui.toast('Jam selesai harus setelah jam mulai.', 'galat')
  proses.value = true
  try {
    await kel.simpanJadwal(gEdit.value.id, baris.value.map((b) => ({ id: b.id || null, hari: Number(b.hari), jam_mulai: b.jam_mulai, jam_selesai: b.jam_selesai, tempat: b.tempat || null })))
    ui.toast(`Jadwal ${gEdit.value.nama} disimpan. Sesi presensi pembina ikut diperbarui.`); lembar.value = false
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
const pembina = (g) => (g.pengasuh || []).filter((p) => p.berlaku !== false).map((p) => p.nama).join(', ')
</script>
<template>
  <div>
    <BilahTab class="mb-4" :tab="TAB" :model-value="aktif" label="Bagian ekskul" @update:model-value="pilihTab" />

    <!-- Pertemuan -->
    <TabDasborEkskul v-if="aktif === 'dasbor'" @rekap="pilihTab('rekap')" />
    <template v-else-if="aktif === 'pertemuan'">
      <div class="mb-4 flex flex-wrap items-end gap-3">
        <div class="w-48"><InputTanggal v-model="tanggal" label="Tanggal" wajib /></div>
        <p class="flex-1 pb-3 text-sm text-teks3">{{ formatHari(tanggal) }} · {{ lihatSemua ? 'semua ekskul' : 'ekskul yang Anda bina' }}. Isi absensi dan jurnal materi setiap pertemuan.</p>
      </div>
      <ul class="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
        <li v-for="s in pertemuan" :key="s.group_id + s.sesi">
          <button type="button" class="kartu w-ekskul flex h-full w-full flex-col gap-2 p-4 text-left transition hover:-translate-y-0.5 hover:shadow-apung" @click="router.push(`/absensi-santri/isi/${s.group_id}/${s.tanggal}/${s.sesi}`)">
            <div class="flex items-start gap-3">
              <span class="chip-ikon h-11 w-11 shrink-0"><PhMedal :size="24" weight="duotone" /></span>
              <div class="min-w-0 flex-1"><p class="truncate font-bold">{{ s.nama_kelompok }}</p>
                <p class="text-sm text-teks3">{{ jam(s.jam_mulai) }}–{{ jam(s.jam_selesai) }}{{ s.tempat ? ' · ' + s.tempat : '' }}</p></div>
              <PhCaretRight :size="18" class="mt-1 text-teks3" />
            </div>
            <span :class="['lencana self-start', 'w-' + STATUS_SESI[s.status].w]">{{ STATUS_SESI[s.status].n }}</span>
            <p v-if="s.status === 'terisi'" class="text-sm"><b class="tabular-nums" style="color: var(--c)">{{ s.jumlah_hadir }}/{{ s.jumlah_anggota }} hadir</b><span v-if="s.topik" class="text-teks2"> · {{ s.topik }}</span></p>
            <p v-else class="text-sm text-teks2">{{ s.jumlah_anggota }} anggota</p>
            <p v-if="lihatSemua" class="mt-auto border-t border-garis pt-2 text-xs text-teks3">Pembina: {{ s.pengampu || 'belum ditetapkan' }}</p>
          </button>
        </li>
      </ul>
      <p v-if="!pertemuan.length && !abs.memuat" class="kartu py-10 text-center text-sm text-teks3">Tidak ada pertemuan ekskul pada tanggal ini. Jadwal pertemuan diatur di tab Jadwal.</p>
    </template>

    <!-- Jadwal -->
    <template v-else-if="aktif === 'jadwal'">
      <p class="mb-4 flex gap-2 rounded-xl bg-permukaan2 p-3 text-sm text-teks2"><PhInfo :size="18" class="mt-0.5 shrink-0" />
        Setiap jadwal otomatis menjadi sesi presensi GPS bagi pembina/pelatih utama dan pendamping ekskul tersebut (pola "Pembina ekskul"). Anggota dan pembina diatur di menu Kelompok Santri → Ekskul.</p>
      <ul class="grid gap-3 md:grid-cols-2">
        <li v-for="g in ekskul" :key="g.id" class="kartu w-ekskul p-4">
          <div class="flex items-start gap-3">
            <span class="chip-ikon h-11 w-11 shrink-0"><PhMedal :size="24" weight="duotone" /></span>
            <div class="min-w-0 flex-1"><p class="font-bold">{{ g.nama }}</p>
              <p class="flex items-center gap-1 text-sm text-teks3"><PhUserCircle :size="16" /> {{ pembina(g) || 'Pembina belum ditetapkan' }} · {{ g.jumlah || 0 }} anggota</p></div>
            <button v-if="bolehAtur" class="tombol-ikon h-10 w-10" :aria-label="`Ubah jadwal ${g.nama}`" @click="bukaJadwal(g)"><PhPencilSimple :size="20" /></button>
          </div>
          <ul v-if="(kel.jadwal[g.id] || []).length" class="mt-3 space-y-1.5">
            <li v-for="j in kel.jadwal[g.id]" :key="j.id" class="flex flex-wrap items-center gap-2 rounded-xl bg-permukaan2 px-3 py-2 text-sm">
              <b class="w-16">{{ HARI[j.hari] }}</b><span class="tabular-nums">{{ jam(j.jam_mulai) }}–{{ jam(j.jam_selesai) }}</span>
              <span v-if="j.tempat" class="inline-flex items-center gap-1 text-teks3"><PhMapPin :size="14" /> {{ j.tempat }}</span></li>
          </ul>
          <p v-else class="mt-3 text-sm font-semibold text-merah">Belum ada jadwal pertemuan.</p>
        </li>
      </ul>
      <p v-if="!ekskul.length && !kel.memuat" class="kartu py-10 text-center text-sm text-teks3">Belum ada ekskul aktif. Tambahkan di Kelompok Santri → Ekskul.</p>
    </template>

    <TabRekapEkskul v-else :semua="lihatSemua" />

    <LembarBawah v-model="lembar" :judul="`Jadwal ${gEdit?.nama || ''}`">
      <div class="space-y-3 pb-2">
        <div v-for="(b, i) in baris" :key="i" class="rounded-2xl border border-garis p-3">
          <div class="flex items-center gap-2">
            <select v-model.number="b.hari" class="isian flex-1" :aria-label="`Hari jadwal ${i + 1}`"><option v-for="(h, k) in HARI" :key="k" :value="k">{{ h }}</option></select>
            <button class="tombol-ikon h-10 w-10" :aria-label="`Hapus jadwal ${i + 1}`" @click="baris.splice(i, 1)"><PhX :size="18" /></button>
          </div>
          <div class="mt-2 grid grid-cols-2 gap-2">
            <div><label class="label-isian" :for="`jm-${i}`">Mulai</label><input :id="`jm-${i}`" v-model="b.jam_mulai" type="time" class="isian tabular-nums" /></div>
            <div><label class="label-isian" :for="`js-${i}`">Selesai</label><input :id="`js-${i}`" v-model="b.jam_selesai" type="time" class="isian tabular-nums" /></div>
          </div>
          <input v-model="b.tempat" class="isian mt-2" placeholder="Tempat, contoh: Lapangan panahan" :aria-label="`Tempat jadwal ${i + 1}`" />
        </div>
        <button class="tombol-garis w-full" @click="tambahBaris"><PhPlus :size="18" weight="bold" /> Tambah hari pertemuan</button>
        <p class="text-xs text-teks3">Menghapus jadwal menonaktifkan sesi presensinya; riwayat presensi dan absensi tetap tersimpan.</p>
        <button class="tombol-utama w-full" :disabled="proses" @click="simpanJadwal"><PhFloppyDisk :size="20" weight="duotone" /> {{ proses ? 'Menyimpan…' : 'Simpan jadwal' }}</button>
      </div>
    </LembarBawah>
  </div>
</template>
