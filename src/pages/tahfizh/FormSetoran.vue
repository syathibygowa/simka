<!-- SIMKA PRO | src/pages/tahfizh/FormSetoran.vue | v1.0 | Fase 5 – Tahap 2 Setoran per sesi halaqah | 05/10/2026 -->
<script setup>
// Setoran satu sesi halaqah. Bawaan semua santri "Sama"; ketuk "Bertambah" pada Sabaq/Sabqi/Manzil lalu atur posisi
// barunya (Juz + Halaman). Santri yang Izin/Sakit/Bolos/Absen pada absensi sesi ini otomatis "Tidak setor".
// Peringatan janggal tampil langsung (posisi turun, lonjakan, sabqi/manzil melebihi sabaq) dan tetap boleh disimpan.
import { ref, computed, watch } from 'vue'
import { PhCheckCircle, PhFloppyDisk, PhArrowCounterClockwise, PhMagnifyingGlass, PhWarning, PhCaretDown, PhTrendUp, PhProhibit, PhNotePencil, PhLockSimple } from '@phosphor-icons/vue'
import { useTahfizh } from '@/stores/tahfizh'
import { useUI } from '@/stores/ui'
import { KODE } from '@/lib/absensi'
import { inisial } from '@/lib/santri'
import { formatPosisi, periksaIsian, TANDA_JANGGAL, JENIS_POSISI } from '@/lib/tahfizh'
import { formatWaktu } from '@/lib/tanggal'
import InputPosisi from '@/components/InputPosisi.vue'

const props = defineProps({ group: String, tanggal: String, sesi: String, absensi: Object, atasNamaId: String, tertutup: Boolean })
const emit = defineEmits(['tersimpan'])
const tz = useTahfizh(); const ui = useUI()
const d = ref(null); const galat = ref(''); const isian = ref({}); const catatan = ref(''); const proses = ref(false); const cari = ref(''); const awal = ref('')
const JENIS = ['sabaq', 'sabqi', 'manzil']
const TIDAK_SETOR = ['I', 'S', 'B', 'A']

async function muat() {
  galat.value = ''
  try {
    const x = await tz.detailSetoran(props.group, props.tanggal, props.sesi, props.absensi)
    d.value = x
    isian.value = Object.fromEntries(x.santri.map((s) => [s.id, {
      sabaq: s.sabaq_hal, sabqi: s.sabqi_hal, manzil: s.manzil_hal, juz_sedang: s.juz_sedang || '', catatan: s.catatan || '',
      buka: !!s.catatan || s.janggal?.length > 0,
    }]))
    catatan.value = x.catatan || ''
    awal.value = jejak()
  } catch (e) { galat.value = e.message }
}
watch(() => [props.group, props.tanggal, props.sesi, props.absensi?.sesi_tercatat?.diisi_pada], muat, { immediate: true })

const jejak = () => JSON.stringify([Object.entries(isian.value).map(([k, v]) => [k, v.sabaq, v.sabqi, v.manzil, v.juz_sedang, v.catatan]), catatan.value])
const berubah = computed(() => d.value && jejak() !== awal.value)
const bolehIsi = computed(() => d.value?.boleh_isi && !props.tertutup)
const tampil = computed(() => { const q = cari.value.toLowerCase().trim(); return (d.value?.santri || []).filter((s) => !q || `${s.nama} ${s.nis}`.toLowerCase().includes(q)) })
const tidakSetor = (s) => TIDAK_SETOR.includes(s.kehadiran)
const tambah = (s) => { const v = isian.value[s.id]; return v?.sabaq != null ? v.sabaq - s.sabaq_lama : 0 }
const tanda = (s) => { const v = isian.value[s.id]; return v ? periksaIsian({ ...s, sabaq_hal: v.sabaq, sabqi_hal: v.sabqi, manzil_hal: v.manzil }, d.value?.batas_lonjakan_hal) : [] }
const ringkas = computed(() => {
  const sn = d.value?.santri || []
  return { setor: sn.filter((s) => !tidakSetor(s)).length, tidak: sn.filter(tidakSetor).length,
    bertambah: sn.filter((s) => tambah(s) > 0).length, total: sn.reduce((n, s) => n + Math.max(0, tambah(s)), 0), janggal: sn.filter((s) => tanda(s).length).length }
})

function setel(s, j, mode) {
  const v = isian.value[s.id]
  v[j] = mode === 'sama' ? null : Math.min(600, (v[j] ?? s[j + '_lama']) + (v[j] == null ? 1 : 0))
}
function semuaSama() { for (const v of Object.values(isian.value)) { v.sabaq = null; v.sabqi = null; v.manzil = null } }

async function simpan() {
  if (!bolehIsi.value) return
  const baris = d.value.santri.filter((s) => !tidakSetor(s) || isian.value[s.id].catatan).map((s) => {
    const v = isian.value[s.id]
    const juzBerubah = v.juz_sedang !== '' && Number(v.juz_sedang) !== Number(s.juz_sedang || 0)
    return { student_id: s.id, sabaq_hal: tidakSetor(s) ? null : v.sabaq, sabqi_hal: tidakSetor(s) ? null : v.sabqi, manzil_hal: tidakSetor(s) ? null : v.manzil,
      juz_sedang: juzBerubah ? Number(v.juz_sedang) : null, catatan: v.catatan.trim() || null }
  }).filter((b) => b.sabaq_hal != null || b.sabqi_hal != null || b.manzil_hal != null || b.juz_sedang != null || b.catatan)
  if (ringkas.value.janggal && !(await ui.konfirmasi({ judul: 'Ada isian janggal', pesan: `${ringkas.value.janggal} santri bertanda janggal (lihat tanda kuning). Tetap simpan? Isian tetap tercatat dengan tanda tersebut.`, ya: 'Tetap simpan' }))) return
  proses.value = true
  try {
    const h = await tz.simpanSetoran({ group_id: props.group, tanggal: props.tanggal, sesi: props.sesi, baris, catatan: catatan.value.trim() || null, atas_nama_id: props.atasNamaId || null }, d.value)
    ui.toast(`Setoran tersimpan: ${ringkas.value.bertambah} santri bertambah (${formatPosisi(ringkas.value.total)}), ${ringkas.value.setor - ringkas.value.bertambah} sama, ${ringkas.value.tidak} tidak setor.`)
    if (h?.janggal?.length) ui.toast(`${h.janggal.length} isian ditandai janggal dan akan tampil di laporan.`, 'info')
    await muat(); emit('tersimpan')
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
defineExpose({ berubah })
</script>
<template>
  <div class="pb-28">
    <p v-if="galat" class="kartu w-klinik p-5 font-semibold" style="color: var(--c)">{{ galat }}</p>
    <template v-else-if="d">
      <div v-if="!d.absensi_tersimpan" class="kartu w-pengajuan flex items-center gap-3 p-5">
        <span class="chip-ikon h-11 w-11"><PhLockSimple :size="24" weight="duotone" /></span>
        <p class="text-sm text-teks2"><b class="text-teks">Simpan absensi sesi ini lebih dulu.</b> Setoran memakai kehadiran dari absensi: santri yang Izin, Sakit, Bolos, atau Absen otomatis tidak setor.</p>
      </div>
      <template v-else>
        <!-- Ringkasan -->
        <section class="kartu w-tahfizh grid grid-cols-4 divide-x divide-garis text-center">
          <div class="p-2.5"><p class="text-xl font-extrabold tabular-nums" style="color: var(--c)">{{ ringkas.setor }}</p><p class="text-xs text-teks3">Setor</p></div>
          <div class="w-presensi p-2.5"><p class="text-xl font-extrabold tabular-nums" style="color: var(--c)">{{ ringkas.bertambah }}</p><p class="text-xs text-teks3">Bertambah</p></div>
          <div class="w-pengajuan p-2.5"><p class="text-xl font-extrabold tabular-nums" style="color: var(--c)">+{{ ringkas.total }}</p><p class="text-xs text-teks3">halaman</p></div>
          <div class="w-klinik p-2.5"><p class="text-xl font-extrabold tabular-nums" style="color: var(--c)">{{ ringkas.tidak }}</p><p class="text-xs text-teks3">Tidak setor</p></div>
        </section>
        <p v-if="d.session_id" class="mt-2 text-xs text-teks3">Setoran terakhir disimpan {{ formatWaktu(d.diisi_pada) }} WITA oleh {{ d.diinput_oleh }}{{ d.atas_nama ? ` atas nama ${d.pengampu}` : '' }}{{ d.diisi_terlambat ? ' · diisi setelah jendela sesi' : '' }}.</p>
        <p v-else-if="bolehIsi" class="mt-2 text-xs text-teks3">Belum disimpan. Bila semua santri sama, cukup tekan "Simpan setoran" agar tercatat sudah diisi.</p>

        <section class="kartu mt-4 p-4">
          <div class="mb-3 flex flex-wrap items-center gap-2">
            <p class="flex-1 text-sm text-teks2">Bawaan semua <b>Sama</b>. Ketuk <b>Bertambah</b> bila posisinya maju.</p>
            <button v-if="bolehIsi" class="tombol-garis min-h-[40px] px-3 text-sm" @click="semuaSama"><PhArrowCounterClockwise :size="18" /> Tandai semua sama</button>
          </div>
          <div v-if="d.santri.length > 10" class="relative mb-2">
            <PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
            <input v-model="cari" type="search" class="isian pl-11" placeholder="Cari nama atau NIS" aria-label="Cari santri" />
          </div>

          <ul class="divide-y divide-garis">
            <li v-for="(s, i) in tampil" :key="s.id" class="py-3">
              <div class="flex items-center gap-3">
                <span class="w-6 shrink-0 text-right text-xs tabular-nums text-teks3">{{ i + 1 }}</span>
                <span :class="['chip-ikon h-9 w-9 shrink-0 text-xs font-extrabold', tidakSetor(s) ? 'w-klinik' : tambah(s) > 0 ? 'w-presensi' : 'w-tahfizh']">{{ inisial(s.nama) }}</span>
                <span class="min-w-0 flex-1"><span class="block truncate font-semibold">{{ s.nama }}</span>
                  <span class="block text-xs text-teks3">{{ s.nis }} · resmi {{ s.total_resmi }} juz<template v-if="s.juz_sedang"> · sedang juz {{ s.juz_sedang }}</template></span></span>
                <span v-if="tidakSetor(s)" class="lencana w-klinik"><PhProhibit :size="14" weight="bold" /> Tidak setor · {{ KODE[s.kehadiran].n }}</span>
                <span v-else-if="tambah(s) > 0" class="lencana w-presensi"><PhTrendUp :size="14" weight="bold" /> +{{ formatPosisi(tambah(s)) }}</span>
                <span v-else class="lencana w-hakakses">Sama</span>
              </div>

              <div v-if="!tidakSetor(s)" class="mt-2 space-y-2 sm:pl-9">
                <div v-for="j in JENIS" :key="j" class="rounded-xl bg-permukaan2 p-2.5">
                  <div class="flex items-center gap-2">
                    <span class="min-w-0 flex-1 text-sm"><b>{{ JENIS_POSISI[j] }}</b>
                      <span class="block text-xs text-teks3">Sebelumnya {{ formatPosisi(s[j + '_lama'], true) }}</span></span>
                    <div class="grid grid-cols-2 gap-1 rounded-xl bg-permukaan p-1" role="radiogroup" :aria-label="`${JENIS_POSISI[j]} ${s.nama}`">
                      <button type="button" role="radio" :aria-checked="isian[s.id][j] == null" :disabled="!bolehIsi" @click="setel(s, j, 'sama')"
                        :class="['min-h-[36px] rounded-lg px-3 text-xs font-bold', isian[s.id][j] == null ? 'bg-permukaan2 text-teks shadow-kartu' : 'text-teks3']">Sama</button>
                      <button type="button" role="radio" :aria-checked="isian[s.id][j] != null" :disabled="!bolehIsi" @click="setel(s, j, 'tambah')"
                        :class="['min-h-[36px] rounded-lg px-3 text-xs font-bold', isian[s.id][j] != null ? 'w-presensi text-white' : 'text-teks3']"
                        :style="isian[s.id][j] != null ? 'background: var(--c)' : ''">Bertambah</button>
                    </div>
                  </div>
                  <InputPosisi v-if="isian[s.id][j] != null" :id="`st-${s.id}-${j}`" v-model="isian[s.id][j]" :nama-aria="`${JENIS_POSISI[j]} ${s.nama}`" ringkas class="mt-2" :nonaktif="!bolehIsi"
                    :keterangan="j === 'sabaq' ? `Bertambah ${isian[s.id][j] - s.sabaq_lama >= 0 ? '+' : ''}${isian[s.id][j] - s.sabaq_lama} halaman` : ''" />
                </div>
                <ul v-if="tanda(s).length" class="space-y-1 rounded-xl bg-[#B5501A]/10 p-2.5 text-xs font-semibold text-teks">
                  <li v-for="t in tanda(s)" :key="t" class="flex items-center gap-1.5"><PhWarning :size="14" weight="fill" class="text-[#B5501A] dark:text-[#F5A06B]" /> {{ TANDA_JANGGAL[t] }}</li>
                </ul>
              </div>

              <div class="mt-1.5 sm:pl-9">
                <button type="button" class="inline-flex min-h-[36px] items-center gap-1 text-xs font-semibold text-teks3" :aria-expanded="isian[s.id].buka" @click="isian[s.id].buka = !isian[s.id].buka">
                  <PhNotePencil :size="14" /> Juz sedang dihafal & catatan <PhCaretDown :size="12" :class="isian[s.id].buka && 'rotate-180'" /></button>
                <div v-if="isian[s.id].buka" class="mt-1 grid gap-2 sm:grid-cols-[10rem_1fr]">
                  <select v-model="isian[s.id].juz_sedang" class="isian min-h-[40px] text-sm" :disabled="!bolehIsi || tidakSetor(s)" :aria-label="`Juz sedang dihafal ${s.nama}`">
                    <option value="">Juz sedang: –</option><option v-for="n in 30" :key="n" :value="n">Sedang juz {{ n }}</option></select>
                  <input v-model="isian[s.id].catatan" class="isian min-h-[40px] text-sm" :disabled="!bolehIsi" placeholder="Catatan (opsional), mis. bacaan belum lancar" :aria-label="`Catatan ${s.nama}`" />
                </div>
              </div>
            </li>
          </ul>
          <div class="mt-3"><label class="label-isian" for="st-cat">Catatan sesi (opsional)</label>
            <input id="st-cat" v-model="catatan" :disabled="!bolehIsi" class="isian" placeholder="Contoh: setoran dipersingkat karena kegiatan pondok" /></div>
        </section>

        <div v-if="bolehIsi" class="bilah-simpan layar-saja fixed inset-x-0 z-30 border-t border-garis bg-permukaan/95 px-4 py-3 backdrop-blur lg:left-auto lg:right-6 lg:w-[30rem] lg:rounded-2xl lg:border">
          <div class="mx-auto flex max-w-3xl items-center gap-3">
            <p class="flex-1 text-sm"><b class="tabular-nums">{{ ringkas.bertambah }}</b> bertambah<span class="text-teks3"> · +{{ ringkas.total }} hal{{ ringkas.janggal ? ` · ${ringkas.janggal} janggal` : '' }}</span></p>
            <button class="tombol-utama min-h-[44px]" :disabled="proses || (d.session_id && !berubah)" @click="simpan">
              <component :is="d.session_id && !berubah ? PhCheckCircle : PhFloppyDisk" :size="20" weight="duotone" />
              {{ proses ? 'Menyimpan…' : d.session_id ? (berubah ? 'Simpan koreksi' : 'Tersimpan') : 'Simpan setoran' }}</button>
          </div>
        </div>
      </template>
    </template>
    <p v-else class="py-16 text-center text-teks3">Memuat setoran…</p>
  </div>
</template>
<style scoped>
.bilah-simpan { bottom: calc(68px + env(safe-area-inset-bottom)); }
@media (min-width: 1024px) { .bilah-simpan { bottom: 1.5rem; } }
</style>
