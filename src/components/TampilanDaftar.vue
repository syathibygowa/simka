<!-- SIMKA PRO | src/components/TampilanDaftar.vue | v1.0 | 14.36.0: daftar bertampilan Baris (hemat ruang, rincian di jendela) atau Kartu | 30/10/2026 -->
<script setup>
// Daftar yang dapat ditampilkan sebagai:
//   • Baris (bawaan): tabel ringkas di desktop / daftar satu baris di HP. Ketuk baris → rincian lengkap (kartu yang sama) di jendela.
//   • Kartu: tampilan kartu seperti sebelumnya.
// Pilihan tampilan diingat per daftar di perangkat ini. Isi kartu diberikan lewat slot #kartu="{ x }" sehingga tombol aksi
// (Nilai, Setujui, Cetak, WA, …) tetap sama; menekan tombol di jendela rincian otomatis menutup jendela.
import { ref, computed, watch } from 'vue'
import { PhRows, PhSquaresFour, PhCaretRight } from '@phosphor-icons/vue'
import LembarBawah from './LembarBawah.vue'

const props = defineProps({
  item: { type: Array, default: () => [] },
  kunci: { type: Function, default: (x) => x.id },
  kolom: { type: Array, default: () => [] },          // [{ n: 'Judul kolom', f: (x) => teks, kelas?: 'lebar/rata', hp?: true (tampil di baris HP) }]
  lencana: { type: Function, default: null },          // (x) => { n, w } — status di ujung baris
  kelasKartu: { type: Function, default: () => '' },   // (x) => kelas <li> pada tampilan kartu
  judulRinci: { type: Function, default: () => 'Rincian' },
  simpanKe: { type: String, default: '' },              // kunci penyimpanan pilihan tampilan
  bawaan: { type: String, default: 'baris' },
})
const baca = () => { try { return localStorage.getItem('simka.tampil.' + props.simpanKe) } catch { return null } }
const mode = ref((props.simpanKe && baca()) || props.bawaan)
watch(mode, (m) => { try { if (props.simpanKe) localStorage.setItem('simka.tampil.' + props.simpanKe, m) } catch { /* abaikan */ } })
const dipilih = ref(null)
const rinci = computed(() => (dipilih.value ? props.item.find((x) => props.kunci(x) === props.kunci(dipilih.value)) || null : null))
const bukaRinci = computed({ get: () => !!rinci.value, set: (v) => { if (!v) dipilih.value = null } })
/** Tombol aksi di jendela rincian membuka lembar lain/menjalankan aksi → jendela rincian ditutup. */
function tutupBilaTombol(e) { if (e.target.closest('button, a')) setTimeout(() => { dipilih.value = null }, 0) }
const kolomHp = computed(() => props.kolom.filter((k) => k.hp))
</script>
<template>
  <div>
    <div v-if="item.length" class="mb-2 flex items-center justify-end gap-2">
      <slot name="kiri" />
      <span class="flex-1" />
      <div class="flex rounded-xl bg-permukaan2 p-0.5" role="radiogroup" aria-label="Bentuk tampilan">
        <button type="button" role="radio" :aria-checked="mode === 'baris'" title="Tampilan baris" aria-label="Tampilan baris" @click="mode = 'baris'"
          :class="['grid h-9 w-10 place-items-center rounded-lg', mode === 'baris' ? 'bg-permukaan text-teks shadow-kartu' : 'text-teks3']"><PhRows :size="18" weight="bold" /></button>
        <button type="button" role="radio" :aria-checked="mode === 'kartu'" title="Tampilan kartu" aria-label="Tampilan kartu" @click="mode = 'kartu'"
          :class="['grid h-9 w-10 place-items-center rounded-lg', mode === 'kartu' ? 'bg-permukaan text-teks shadow-kartu' : 'text-teks3']"><PhSquaresFour :size="18" weight="bold" /></button>
      </div>
    </div>

    <!-- Kartu -->
    <ul v-if="mode === 'kartu'" class="grid gap-3 md:grid-cols-2">
      <li v-for="x in item" :key="kunci(x)" :class="['kartu p-4', kelasKartu(x)]"><slot name="kartu" :x="x" /></li>
    </ul>

    <!-- Baris -->
    <template v-else-if="item.length">
      <div class="kartu hidden overflow-x-auto md:block">
        <table class="w-full text-sm">
          <thead class="bg-permukaan2 text-left text-xs text-teks2"><tr>
            <th class="w-10 px-3 py-2.5 text-center">No</th>
            <template v-for="(k, j) in kolom" :key="k.n"><th :class="['px-3 py-2.5', k.kelas]">{{ k.n }}</th>
              <th v-if="j === 0 && lencana" class="px-3 py-2.5">Status</th></template><th class="w-8" /></tr></thead>
          <tbody class="divide-y divide-garis">
            <tr v-for="(x, i) in item" :key="kunci(x)" :class="['cursor-pointer hover:bg-permukaan2', kelasKartu(x)]" tabindex="0"
              @click="dipilih = x" @keydown.enter="dipilih = x">
              <td class="px-3 py-2 text-center text-teks3">{{ i + 1 }}</td>
              <template v-for="(k, j) in kolom" :key="k.n"><td :class="['px-3 py-2', k.kelas, j === 0 && 'font-semibold']">{{ k.f(x) }}</td>
                <td v-if="j === 0 && lencana" class="px-3 py-2"><span :class="['lencana whitespace-nowrap', 'w-' + lencana(x).w]">{{ lencana(x).n }}</span></td></template>
              <td class="pr-3 text-teks3"><PhCaretRight :size="16" /></td>
            </tr>
          </tbody>
        </table>
      </div>
      <ul class="kartu divide-y divide-garis md:hidden">
        <li v-for="x in item" :key="kunci(x)">
          <button type="button" class="flex min-h-[56px] w-full items-center gap-3 px-3 py-2 text-left" @click="dipilih = x">
            <span class="min-w-0 flex-1">
              <b class="block truncate text-sm">{{ kolom[0]?.f(x) }}</b>
              <span class="block truncate text-xs text-teks3">{{ kolomHp.map((k) => k.f(x)).filter(Boolean).join(' · ') }}</span></span>
            <span v-if="lencana" :class="['lencana shrink-0', 'w-' + lencana(x).w]">{{ lencana(x).n }}</span>
            <PhCaretRight :size="16" class="shrink-0 text-teks3" />
          </button>
        </li>
      </ul>
    </template>

    <LembarBawah v-model="bukaRinci" :judul="rinci ? judulRinci(rinci) : 'Rincian'">
      <div v-if="rinci" :class="['rounded-2xl p-1', kelasKartu(rinci)]" @click.capture="tutupBilaTombol"><slot name="kartu" :x="rinci" /></div>
    </LembarBawah>
  </div>
</template>
