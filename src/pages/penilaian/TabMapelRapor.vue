<!-- SIMKA PRO | src/pages/penilaian/TabMapelRapor.vue | v1.1 | Perbaikan 13.5.0: tab bergaris bawah | 15/10/2026 -->
<script setup>
// Mapel rapor per jenis rapor × tingkat. Urutan, kelompok (judul di rapor), nama, singkatan, KKM/KKTP, dan SUMBER NILAI:
// mapel ajar (satu atau gabungan berbobot), nilai UTAS tahfizh, atau diisi wali kelas. Contoh: PKn tidak diajarkan,
// nilainya diambil dari mapel Tahfizh. Susunan dapat disalin ke tingkat lain.
import { ref, computed, onMounted } from 'vue'
import { PhPlus, PhArrowUp, PhArrowDown, PhPencilSimple, PhTrash, PhCopy, PhWarningCircle, PhLink, PhInfo, PhChalkboardTeacher } from '@phosphor-icons/vue'
import { usePenilaian } from '@/stores/penilaian'
import { useJadwal } from '@/stores/jadwal'
import { useUI } from '@/stores/ui'
import { JENIS_RAPOR, MODE_NILAI, labelSumber, sumberKurang } from '@/lib/penilaian'
import LembarBawah from '@/components/LembarBawah.vue'
import LembarMapelRapor from './LembarMapelRapor.vue'

const pn = usePenilaian(); const jd = useJadwal(); const ui = useUI()
onMounted(() => jd.muat().catch(() => {}))
const jenis = ref('sma'); const tingkat = ref(10); const proses = ref(false)
function pilihJenis(j) { jenis.value = j; tingkat.value = JENIS_RAPOR[j].tingkat[0] }
const daftar = computed(() => pn.mapelTingkat(jenis.value, tingkat.value))
const kelompok = computed(() => {
  const g = []
  for (const m of daftar.value) { const n = m.kelompok || ''; let x = g[g.length - 1]; if (!x || x.n !== n) { x = { n, item: [] }; g.push(x) } x.item.push(m) }
  return g
})
const boleh = computed(() => pn.bolehAtur(jenis.value) && !pn.terkunci)
const ket = computed(() => pn.ketentuan[jenis.value] || {})
const jumlahKurang = (j, t) => pn.mapelTingkat(j, t).filter((m) => m.aktif && sumberKurang(m)).length

async function geser(m, arah) {
  const ids = daftar.value.map((x) => x.id); const i = ids.indexOf(m.id); const j = i + arah
  if (j < 0 || j >= ids.length) return
  ;[ids[i], ids[j]] = [ids[j], ids[i]]
  proses.value = true
  try { await pn.urutkanMapel(ids) } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
async function hapus(m) {
  if (!(await ui.konfirmasi({ judul: 'Hapus mapel rapor?', pesan: `${m.nama} dihapus dari rapor kelas ${m.tingkat}. Nilai mapel ajarnya tetap tersimpan.`, ya: 'Hapus', bahaya: true }))) return
  try { await pn.hapusMapel(m.id); ui.toast('Mapel rapor dihapus.') } catch (e) { ui.toast(e.message, 'galat') }
}

// Tambah/ubah
const lembar = ref(false); const sunting = ref(null)
function buka(m = null) { sunting.value = m; lembar.value = true }

// Salin ke tingkat lain
const lembarSalin = ref(false); const ke = ref([]); const timpa = ref(false)
const tingkatLain = computed(() => JENIS_RAPOR[jenis.value].tingkat.filter((t) => t !== tingkat.value))
function bukaSalin() { ke.value = []; timpa.value = false; lembarSalin.value = true }
async function salinKe() {
  if (!ke.value.length) return ui.toast('Pilih tingkat tujuan.', 'galat')
  if (timpa.value && !(await ui.konfirmasi({ judul: 'Timpa susunan tujuan?', pesan: `Mapel rapor kelas ${ke.value.join(', ')} dihapus lalu diganti salinan kelas ${tingkat.value}.`, ya: 'Timpa', bahaya: true }))) return
  proses.value = true
  try { const n = await pn.salinMapel(jenis.value, tingkat.value, ke.value.map(Number), timpa.value); lembarSalin.value = false; ui.toast(`${n} mapel rapor disalin.`) }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
</script>
<template>
  <div class="space-y-4">
    <div class="kartu space-y-3 p-4">
      <div class="bilah-tab kecil" role="tablist" aria-label="Jenis rapor">
        <button v-for="j in ['sma', 'wustha']" :key="j" type="button" role="tab" :aria-selected="jenis === j" @click="pilihJenis(j)"
          :class="['tab-garis', jenis === j && 'aktif']">{{ JENIS_RAPOR[j].n }}</button>
      </div>
      <div class="flex flex-wrap items-center gap-2">
        <button v-for="t in JENIS_RAPOR[jenis].tingkat" :key="t" type="button" :aria-pressed="tingkat === t" @click="tingkat = t"
          :class="['flex min-h-[40px] items-center gap-2 rounded-xl border px-3 text-sm font-semibold', tingkat === t ? 'border-[color:var(--c)] bg-permukaan2 text-teks' : 'border-garis text-teks2']">
          Kelas {{ t }}<span class="text-xs font-normal text-teks3">{{ pn.mapelTingkat(jenis, t).length }}</span>
          <span v-if="jumlahKurang(jenis, t)" class="grid h-5 min-w-[1.25rem] place-items-center rounded-full bg-[#C7332F] px-1 text-[11px] font-bold text-white" :title="`${jumlahKurang(jenis, t)} mapel belum bersumber nilai`">{{ jumlahKurang(jenis, t) }}</span>
        </button>
        <span class="flex-1" />
        <button v-if="boleh && daftar.length" class="tombol-garis min-h-[40px] px-3 text-sm" @click="bukaSalin"><PhCopy :size="18" weight="duotone" /> Salin ke kelas lain</button>
        <button v-if="boleh" class="tombol-utama min-h-[40px] px-4 text-sm" @click="buka()"><PhPlus :size="18" weight="bold" /> Mapel rapor</button>
      </div>
      <p class="flex gap-2 text-xs text-teks3"><PhInfo :size="16" class="shrink-0" />
        <span>Mapel rapor = mapel yang tercetak di rapor. Nilainya diambil dari <b>mapel ajar</b> (yang diajarkan dan dinilai guru), misalnya PKn ← Tahfizh bila PKn tidak diajarkan. {{ ket.label_ambang || 'KKM' }} bawaan {{ Number(ket.ambang_bawaan || 0) }}.</span></p>
    </div>

    <section v-for="g in kelompok" :key="g.n" class="kartu overflow-hidden">
      <p class="border-b border-garis bg-permukaan2 px-4 py-2 text-xs font-bold uppercase tracking-wide text-teks2">{{ g.n || 'Tanpa judul kelompok' }}</p>
      <ul class="divide-y divide-garis">
        <li v-for="m in g.item" :key="m.id" :class="['flex flex-wrap items-center gap-3 px-4 py-3', !m.aktif && 'opacity-60']">
          <span class="grid h-9 w-9 shrink-0 place-items-center rounded-xl bg-permukaan2 text-sm font-bold tabular-nums">{{ m.urutan }}</span>
          <div class="min-w-0 flex-1 basis-[50%]">
            <p class="font-semibold">{{ m.nama }} <span v-if="m.singkatan" class="text-xs font-normal text-teks3">({{ m.singkatan }})</span>
              <span v-if="!m.aktif" class="lencana w-hakakses ml-1">nonaktif</span></p>
            <p :class="['flex items-center gap-1 text-sm', sumberKurang(m) ? 'font-semibold text-merah' : 'text-teks2']">
              <component :is="sumberKurang(m) ? PhWarningCircle : PhLink" :size="15" weight="bold" class="shrink-0" /> {{ labelSumber(m) }}</p>
            <p v-if="m.sumber === 'mapel' && (m.sumber_mapel || []).length && !m.pengampu" class="flex items-center gap-1 text-xs text-teks3">
              <PhChalkboardTeacher :size="14" /> Belum ada penugasan mengajar mapel sumber ini di kelas {{ m.tingkat }}.</p>
          </div>
          <span class="lencana w-rapor">{{ ket.label_ambang || 'KKM' }} {{ Number(m.kkm) }}</span>
          <span v-if="m.mode_nilai" class="lencana w-gurumapel" :title="MODE_NILAI[m.mode_nilai].ket">{{ MODE_NILAI[m.mode_nilai].n }}</span>
          <div v-if="boleh" class="flex shrink-0 items-center">
            <button class="tombol-ikon h-9 w-9" :disabled="proses || m.urutan === 1" :aria-label="`Naikkan ${m.nama}`" @click="geser(m, -1)"><PhArrowUp :size="16" /></button>
            <button class="tombol-ikon h-9 w-9" :disabled="proses || m.urutan === daftar.length" :aria-label="`Turunkan ${m.nama}`" @click="geser(m, 1)"><PhArrowDown :size="16" /></button>
            <button class="tombol-ikon h-9 w-9" :aria-label="`Ubah ${m.nama}`" @click="buka(m)"><PhPencilSimple :size="16" /></button>
            <button class="tombol-ikon h-9 w-9" :aria-label="`Hapus ${m.nama}`" @click="hapus(m)"><PhTrash :size="16" /></button>
          </div>
        </li>
      </ul>
    </section>
    <p v-if="!daftar.length" class="kartu p-6 text-center text-sm text-teks3">Belum ada mapel rapor untuk kelas {{ tingkat }}. {{ boleh ? 'Tekan + Mapel rapor, atau salin dari kelas lain.' : '' }}</p>

    <LembarMapelRapor v-model="lembar" :mapel="sunting" :jenis="jenis" :tingkat="tingkat" />

    <LembarBawah v-model="lembarSalin" :judul="`Salin susunan kelas ${tingkat}`">
      <div class="space-y-3 pb-2">
        <p class="text-sm text-teks2">Salin {{ daftar.length }} mapel rapor kelas {{ tingkat }} (urutan, kelompok, KKM, dan sumber nilai) ke:</p>
        <div class="flex flex-wrap gap-2">
          <label v-for="t in tingkatLain" :key="t" class="flex min-h-[44px] cursor-pointer items-center gap-2 rounded-xl border border-garis px-3 text-sm font-semibold">
            <input v-model="ke" type="checkbox" :value="t" class="h-5 w-5 accent-[#86198F]" /> Kelas {{ t }}</label>
        </div>
        <label class="flex min-h-[44px] cursor-pointer items-center gap-2 text-sm"><input v-model="timpa" type="checkbox" class="h-5 w-5 accent-[#C7332F]" />
          Timpa susunan tujuan (hapus dulu mapel rapor yang sudah ada)</label>
        <p class="text-xs text-teks3">Tanpa timpa, mapel yang namanya sudah ada di kelas tujuan dilewati.</p>
        <button class="tombol-utama w-full" :disabled="proses" @click="salinKe"><PhCopy :size="20" weight="duotone" /> {{ proses ? 'Menyalin…' : 'Salin' }}</button>
      </div>
    </LembarBawah>
  </div>
</template>
