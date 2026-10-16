<!-- SIMKA PRO | src/pages/ekskul/Ekskul.vue | v1.4 | Perbaikan 13.7.0: kategori indoor/outdoor, pertemuan sepekan tanpa memilih tanggal | 16/10/2026 -->
<script setup>
// Ekskul: Pertemuan (absensi HISBAT + jurnal materi per pertemuan), Jadwal pertemuan (otomatis menjadi sesi
// presensi pembina/pelatih), dan Rekap (kehadiran santri, jurnal materi; Excel dan cetak F4).
// Ekskul adalah kegiatan eksternal: tidak memengaruhi persentase kehadiran program pokok santri.
// v1.3: tab Nilai rapor — pembina mengisi nilai Pengembangan Diri (A–D) per santri untuk rapor.
// v1.2: tab Dasbor — perkembangan semua ekskul (pertemuan, kehadiran, jurnal materi) untuk admin/pimpinan/pembina.
// v1.4: sub-tab kategori Semua/Indoor/Outdoor berlaku di semua tab; Pertemuan tampil sepekan (seperti jurnal mengajar guru)
//       sehingga pelatih langsung memilih pertemuan sesuai jadwal; kategori diatur di tab Jadwal.
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import BilahTab from '@/components/BilahTab.vue'
import { PhMedal, PhCalendarDots, PhChartBar, PhCaretRight, PhCaretLeft, PhPencilSimple, PhPlus, PhX, PhFloppyDisk, PhMapPin, PhUserCircle, PhInfo, PhGauge, PhExam, PhCheckCircle, PhNotePencil, PhHourglass, PhLockSimple } from '@phosphor-icons/vue'
import { KATEGORI_EKSKUL, TAB_KATEGORI, BELUM_KATEGORI, cocokKategori } from '@/lib/ekskul'
import { useAbsensiSantri } from '@/stores/absensiSantri'
import { useKelompokSantri } from '@/stores/kelompokSantri'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { STATUS_SESI, jam } from '@/lib/absensi'
import { HARI, hariIniISO, formatPendek } from '@/lib/tanggal'
import { seninDari, tambahHari } from '@/lib/shift'
import LembarBawah from '@/components/LembarBawah.vue'
import TabRekapEkskul from './TabRekapEkskul.vue'
import TabDasborEkskul from './TabDasborEkskul.vue'
import TabNilaiEkskul from './TabNilaiEkskul.vue'

const props = defineProps({ tab: { type: String, default: '' } })
const router = useRouter(); const abs = useAbsensiSantri(); const kel = useKelompokSantri(); const sesi = useSesi(); const ui = useUI()
const TAB = [{ k: 'dasbor', n: 'Dasbor', ikon: PhGauge, w: 'ekskul' }, { k: 'pertemuan', n: 'Pertemuan', ikon: PhMedal, w: 'ekskul' }, { k: 'jadwal', n: 'Jadwal', ikon: PhCalendarDots, w: 'agenda' }, { k: 'rekap', n: 'Rekap', ikon: PhChartBar, w: 'rekap' }, { k: 'nilai', n: 'Nilai rapor', ikon: PhExam, w: 'rapor' }]
const aktif = computed(() => (TAB.some((t) => t.k === props.tab) ? props.tab : lihatSemua.value ? 'dasbor' : 'pertemuan'))
const lihatSemua = computed(() => sesi.isAdmin || sesi.tingkat('absensi_ekskul') >= 1 && sesi.tingkat('data_santri') >= 1)
const bolehAtur = computed(() => sesi.bolehAdmin('kelompok_santri') || sesi.tingkat('kelompok_santri') >= 2)
// Saringan kategori (tersimpan di perangkat): '' semua · indoor · outdoor
const kategori = ref((() => { try { return localStorage.getItem('simka.ekskul.kategori') || '' } catch { return '' } })())
watch(kategori, (v) => { try { localStorage.setItem('simka.ekskul.kategori', v) } catch { /* abaikan */ } })
const hari = hariIniISO(); const senin = ref(seninDari(hari)); const pekan = ref([]); const memuatPekan = ref(false)

async function muat() {
  await kel.muat().catch(() => {})
  if (aktif.value === 'pertemuan') {
    memuatPekan.value = true
    try { pekan.value = await abs.pekanEkskul(senin.value, lihatSemua.value) } catch (e) { ui.toast(e.message, 'galat') } finally { memuatPekan.value = false }
  }
  if (aktif.value === 'jadwal') { try { await kel.muatJadwal() } catch (e) { ui.toast(e.message, 'galat') } }
}
onMounted(muat)
watch([aktif, senin], muat)
const ekskulSemua = computed(() => kel.dariTA.filter((g) => g.jenis === 'ekskul' && g.aktif))
const ekskul = computed(() => ekskulSemua.value.filter((g) => cocokKategori(g, kategori.value)))
const jumlahKat = computed(() => ({ '': ekskulSemua.value.length, indoor: ekskulSemua.value.filter((g) => g.kategori_ekskul === 'indoor').length, outdoor: ekskulSemua.value.filter((g) => g.kategori_ekskul === 'outdoor').length }))
const katGrup = (id) => kel.cari(id)?.kategori_ekskul || ''

// ---------- Pertemuan sepekan ----------
const STATUS_P = {
  terisi: { n: 'Jurnal terisi', w: 'presensi', i: PhCheckCircle }, belum: { n: 'Belum diisi', w: 'pengajuan', i: PhNotePencil },
  nanti: { n: 'Akan datang', w: 'hakakses', i: PhHourglass }, kunci: { n: 'Lewat batas, belum diisi', w: 'klinik', i: PhLockSimple },
}
const statusP = (s) => (s.status === 'terisi' ? 'terisi' : s.tanggal > hari || s.status === 'belum_buka' ? 'nanti' : s.status === 'tidak_terisi' ? 'kunci' : 'belum')
const hariPekan = computed(() => pekan.value.map((h) => ({ ...h, nama: HARI[new Date(`${h.tanggal}T12:00:00+08:00`).getUTCDay()],
  sesi: h.sesi.filter((s) => !kategori.value || katGrup(s.group_id) === kategori.value).map((s) => ({ ...s, tanggal: s.tanggal || h.tanggal, st: statusP({ ...s, tanggal: s.tanggal || h.tanggal }) })) })))
const ringkasPekan = computed(() => { const x = hariPekan.value.flatMap((h) => h.sesi).filter((s) => s.tanggal <= hari); return { isi: x.filter((s) => s.st === 'terisi').length, n: x.length, belum: x.filter((s) => ['belum', 'kunci'].includes(s.st)).length } })
const labelPekan = computed(() => `${formatPendek(senin.value)} – ${formatPendek(tambahHari(senin.value, 6))}`)
function bukaPertemuan(s) {
  if (s.st === 'nanti') return ui.toast('Pertemuan ini belum dimulai. Jurnal dapat diisi saat atau setelah pertemuan.', 'info')
  router.push(`/absensi-santri/isi/${s.group_id}/${s.tanggal}/${s.sesi}`)
}
// ---------- Kategori (tab Jadwal) ----------
const kelompokJadwal = computed(() => {
  const isi = [...Object.entries(KATEGORI_EKSKUL).map(([k, v]) => ({ k, ...v, d: ekskul.value.filter((g) => g.kategori_ekskul === k) })),
    { k: 'belum', ...BELUM_KATEGORI, d: ekskul.value.filter((g) => !g.kategori_ekskul) }]
  return isi.filter((x) => x.d.length)
})
async function aturKategori(g, k) {
  try { await kel.aturKategoriEkskul(g.id, g.kategori_ekskul === k ? null : k); ui.toast(`${g.nama}: ${g.kategori_ekskul ? KATEGORI_EKSKUL[g.kategori_ekskul].n : 'tanpa kategori'}.`) }
  catch (e) { ui.toast(e.message, 'galat') }
}
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
    <BilahTab class="mb-3" :tab="TAB" :model-value="aktif" label="Bagian ekskul" @update:model-value="pilihTab" />
    <!-- Kelompok/saringan kategori: berlaku di semua tab -->
    <nav class="bilah-tab kecil mb-4" role="tablist" aria-label="Kategori ekskul">
      <button v-for="t in TAB_KATEGORI" :key="t.k" type="button" role="tab" :aria-selected="kategori === t.k" :class="['tab-garis', 'w-' + t.w, kategori === t.k && 'aktif']" @click="kategori = t.k">
        <component :is="t.ikon" :size="18" weight="duotone" /><span>{{ t.n }}</span><span class="angka-tab">{{ jumlahKat[t.k] }}</span></button>
    </nav>

    <!-- Pertemuan -->
    <TabDasborEkskul v-if="aktif === 'dasbor'" :kategori="kategori" @rekap="pilihTab('rekap')" />
    <template v-else-if="aktif === 'pertemuan'">
      <div class="mb-4 flex flex-wrap items-center gap-2">
        <div class="flex items-center gap-1 rounded-2xl border border-garis bg-permukaan p-0.5" role="group" aria-label="Pilih pekan">
          <button class="tombol-ikon h-10 w-10" aria-label="Pekan sebelumnya" @click="senin = tambahHari(senin, -7)"><PhCaretLeft :size="18" weight="bold" /></button>
          <span class="px-2 text-sm font-bold tabular-nums">{{ labelPekan }}</span>
          <button class="tombol-ikon h-10 w-10" aria-label="Pekan berikutnya" @click="senin = tambahHari(senin, 7)"><PhCaretRight :size="18" weight="bold" /></button>
        </div>
        <button v-if="senin !== seninDari(hari)" class="tombol-garis min-h-[40px] px-3 text-sm" @click="senin = seninDari(hari)">Pekan ini</button>
        <p class="min-w-[180px] flex-1 text-sm text-teks3">{{ ringkasPekan.isi }}/{{ ringkasPekan.n }} pertemuan berjurnal<template v-if="ringkasPekan.belum"> · <b class="text-merah">{{ ringkasPekan.belum }} belum diisi</b></template> · {{ lihatSemua ? 'semua ekskul' : 'ekskul yang Anda bina' }}</p>
      </div>
      <p v-if="memuatPekan && !pekan.length" class="kartu py-10 text-center text-sm text-teks3">Memuat jadwal pertemuan sepekan…</p>
      <div v-else class="space-y-4">
        <section v-for="h in hariPekan" :key="h.tanggal" :class="['kartu p-3 sm:p-4', h.tanggal === hari && 'ring-2 ring-[#1E7D4F]/40']">
          <h3 class="mb-2 flex flex-wrap items-center gap-2 px-1 text-sm font-bold">{{ h.nama }}, {{ formatPendek(h.tanggal) }}<span v-if="h.tanggal === hari" class="lencana w-presensi">Hari ini</span>
            <span class="ml-auto text-xs font-normal text-teks3">{{ h.sesi.length ? `${h.sesi.length} pertemuan` : 'Tidak ada pertemuan' }}</span></h3>
          <ul v-if="h.sesi.length" class="grid gap-2 md:grid-cols-2">
            <li v-for="s in h.sesi" :key="s.group_id + s.sesi">
              <button type="button" :class="['flex w-full items-center gap-3 rounded-xl border border-garis p-3 text-left transition hover:bg-permukaan2', 'w-' + STATUS_P[s.st].w, s.st === 'nanti' && 'opacity-70']" @click="bukaPertemuan(s)">
                <span class="grid h-12 w-14 shrink-0 place-items-center rounded-xl text-xs font-bold tabular-nums leading-tight" style="background: color-mix(in srgb, var(--c) 14%, rgb(var(--permukaan))); color: var(--c)">{{ jam(s.jam_mulai) }}<br>{{ jam(s.jam_selesai) }}</span>
                <span class="min-w-0 flex-1"><b class="block truncate">{{ s.nama_kelompok }}</b>
                  <span class="block truncate text-xs text-teks3">{{ KATEGORI_EKSKUL[katGrup(s.group_id)]?.n || 'Belum dikategorikan' }}{{ s.tempat ? ' · ' + s.tempat : '' }}{{ lihatSemua ? ' · ' + (s.pengampu || 'pembina belum ditetapkan') : '' }}</span>
                  <span v-if="s.st === 'terisi'" class="block truncate text-xs text-teks2"><b class="tabular-nums" style="color: var(--c)">{{ s.jumlah_hadir }}/{{ s.jumlah_anggota }} hadir</b>{{ s.topik ? ' · ' + s.topik : '' }}</span></span>
                <span :class="['lencana shrink-0', 'w-' + STATUS_P[s.st].w]"><component :is="STATUS_P[s.st].i" :size="12" weight="bold" /> {{ STATUS_P[s.st].n }}</span>
              </button>
            </li>
          </ul>
        </section>
        <p class="flex gap-2 text-xs text-teks3"><PhInfo :size="16" class="mt-0.5 shrink-0" /> Ketuk pertemuan untuk mengisi absensi santri dan jurnal latihan (materi, kegiatan, metode, dan capaian wajib diisi). Jadwal pertemuan diatur di tab Jadwal.</p>
      </div>
    </template>

    <!-- Jadwal -->
    <template v-else-if="aktif === 'jadwal'">
      <p class="mb-4 flex gap-2 rounded-xl bg-permukaan2 p-3 text-sm text-teks2"><PhInfo :size="18" class="mt-0.5 shrink-0" />
        Setiap jadwal otomatis menjadi sesi presensi GPS bagi pembina/pelatih utama dan pendamping ekskul tersebut (pola "Pembina ekskul"). Anggota dan pembina diatur di menu Kelompok Santri → Ekskul.</p>
      <section v-for="kk in kelompokJadwal" :key="kk.k" :class="['mb-5', 'w-' + kk.w]">
      <h3 class="mb-2 flex items-center gap-2 px-1 font-bold"><span class="chip-ikon h-8 w-8 rounded-lg"><component :is="kk.ikon" :size="18" weight="duotone" /></span>{{ kk.n }}
        <span class="text-sm font-normal text-teks3">· {{ kk.d.length }} ekskul</span></h3>
      <ul class="grid gap-3 md:grid-cols-2">
        <li v-for="g in kk.d" :key="g.id" class="kartu w-ekskul p-4">
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
          <div v-if="bolehAtur" class="mt-3 flex flex-wrap items-center gap-2 border-t border-garis pt-3" role="group" :aria-label="`Kategori ${g.nama}`">
            <span class="text-xs font-semibold text-teks3">Kategori:</span>
            <button v-for="(v, k) in KATEGORI_EKSKUL" :key="k" type="button" :aria-pressed="g.kategori_ekskul === k"
              :class="['flex min-h-[36px] items-center gap-1.5 rounded-full border px-3 text-xs font-semibold', 'w-' + v.w, g.kategori_ekskul === k ? 'kat-aktif' : 'border-garis text-teks2']" @click="aturKategori(g, k)">
              <component :is="v.ikon" :size="16" weight="duotone" /> {{ v.n }}</button>
          </div>
        </li>
      </ul>
      </section>
      <p v-if="!ekskul.length && !kel.memuat" class="kartu py-10 text-center text-sm text-teks3">{{ ekskulSemua.length ? 'Tidak ada ekskul pada kategori ini.' : 'Belum ada ekskul aktif. Tambahkan di Kelompok Santri → Ekskul.' }}</p>
    </template>

    <TabNilaiEkskul v-else-if="aktif === 'nilai'" :kategori="kategori" />
    <TabRekapEkskul v-else :semua="lihatSemua" :kategori="kategori" />

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
<style scoped>
.kat-aktif { border-color: transparent; color: #fff; background: var(--c); }
:global(.dark) .kat-aktif { color: rgb(var(--latar)); }
</style>
