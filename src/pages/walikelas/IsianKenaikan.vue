<!-- SIMKA PRO | src/pages/walikelas/IsianKenaikan.vue | v1.0 | Fase 12 – Tahap 5 Keputusan kenaikan kelas dan kelulusan | 13/10/2026 -->
<script setup>
// Wali Kelas → Rapor → Kenaikan/Kelulusan (semester 2): keputusan per santri untuk rapor akhir tahun.
//   Kelas 7, 8, 10, 11 : Naik kelas / Tinggal kelas;  Kelas 9 dan 12 : Lulus / Tidak lulus.
// "Tetapkan semua" mengisi santri yang belum berkeputusan dengan keputusan bawaan (naik/lulus); santri dengan nilai di
// bawah KKM ditandai agar ditinjau. Keterangan tercetak pada rapor semester 2.
import { ref, computed, watch } from 'vue'
import { PhFloppyDisk, PhInfo, PhMagicWand, PhWarning } from '@phosphor-icons/vue'
import { useRapor } from '@/stores/rapor'
import { useUI } from '@/stores/ui'
import { KEPUTUSAN, kelasAkhir, keputusanBawaan, teksKeputusan, hitungLeger } from '@/lib/rapor'

const props = defineProps({ D: { type: Object, required: true } })
const emit = defineEmits(['tersimpan'])
const rp = useRapor(); const ui = useUI()
const akhir = computed(() => kelasAkhir(props.D.kelas.tingkat))
const PILIHAN = computed(() => (akhir.value ? ['lulus', 'tidak_lulus'] : ['naik', 'tinggal']))
const bawah = computed(() => Object.fromEntries(hitungLeger(props.D).map((b) => [b.s.id, b.bawah.length])))
const isi = ref({}); const ubah = ref(new Set()); const proses = ref(false)
function salin() { isi.value = Object.fromEntries(props.D.santri.map((s) => [s.id, { keputusan: s.keputusan?.keputusan || '', catatan: s.keputusan?.catatan || '' }])); ubah.value = new Set() }
watch(() => props.D, salin, { immediate: true })
const set = (s, f, v) => { isi.value[s.id][f] = v; ubah.value = new Set([...ubah.value, s.id]) }
function semua() { let n = 0; for (const s of props.D.santri) if (!isi.value[s.id].keputusan) { set(s, 'keputusan', keputusanBawaan(props.D.kelas.tingkat)); n++ }
  ui.toast(n ? `${n} santri ditetapkan ${KEPUTUSAN[keputusanBawaan(props.D.kelas.tingkat)].n.toLowerCase()}. Tinjau santri bertanda, lalu simpan.` : 'Semua santri sudah berkeputusan.') }
async function simpan() {
  proses.value = true
  try { await rp.simpanKeputusan(props.D.kelas.group_id, [...ubah.value].map((id) => ({ student_id: id, keputusan: isi.value[id].keputusan, catatan: isi.value[id].catatan.trim() })))
    ui.toast('Keputusan akhir tahun disimpan.'); emit('tersimpan') } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
const terisi = computed(() => props.D.santri.filter((s) => isi.value[s.id]?.keputusan).length)
</script>
<template>
  <div class="space-y-3">
    <div class="kartu flex flex-wrap items-center gap-2 p-3 text-sm">
      <p class="min-w-[200px] flex-1"><b class="tabular-nums">{{ terisi }}/{{ D.santri.length }}</b> <span class="text-teks3">santri {{ akhir ? 'berketerangan lulus' : 'berketerangan kenaikan kelas' }}</span></p>
      <button v-if="D.boleh" class="tombol-garis min-h-[40px] px-3 text-sm" @click="semua"><PhMagicWand :size="18" /> Tetapkan yang kosong: {{ KEPUTUSAN[keputusanBawaan(D.kelas.tingkat)].n.toLowerCase() }}</button>
    </div>
    <p v-if="!D.boleh" class="flex gap-2 rounded-2xl bg-permukaan2 p-3 text-sm text-teks2"><PhInfo :size="18" class="mt-0.5 shrink-0" /> Pengisian terbuka saat periode penilaian semester 2 dibuka (Penilaian → Periode).</p>
    <ul class="space-y-2">
      <li v-for="(s, i) in D.santri" :key="s.id" class="kartu p-3">
        <div class="flex flex-wrap items-center gap-2">
          <div class="min-w-0 flex-1 basis-[45%]">
            <p class="truncate text-sm font-semibold"><span class="text-teks3 tabular-nums">{{ i + 1 }}.</span> {{ s.nama }} <span class="text-xs font-normal text-teks3">{{ s.nis }} · {{ s.jenis_kelamin }}</span></p>
            <p v-if="bawah[s.id]" class="flex items-center gap-1 text-xs font-semibold text-merah"><PhWarning :size="14" /> {{ bawah[s.id] }} mapel di bawah {{ D.ketentuan?.label_ambang || 'KKM' }}</p>
            <p v-else-if="isi[s.id]?.keputusan" class="text-xs text-teks3">Tercetak: {{ teksKeputusan({ keputusan: isi[s.id].keputusan }, D.kelas.tingkat) }}</p>
          </div>
          <div class="flex gap-1" role="radiogroup" :aria-label="`Keputusan ${s.nama}`">
            <button v-for="k in PILIHAN" :key="k" type="button" role="radio" :aria-checked="isi[s.id]?.keputusan === k" :disabled="!D.boleh"
              :class="['min-h-[40px] rounded-xl border px-3 text-sm font-semibold', isi[s.id]?.keputusan === k ? 'w-' + KEPUTUSAN[k].w + ' border-transparent text-[rgb(var(--permukaan))]' : 'border-garis text-teks2']"
              :style="isi[s.id]?.keputusan === k ? 'background: var(--c)' : ''" @click="set(s, 'keputusan', isi[s.id].keputusan === k ? '' : k)">{{ KEPUTUSAN[k].n }}</button>
          </div>
        </div>
        <input v-if="['tinggal', 'tidak_lulus'].includes(isi[s.id]?.keputusan)" :value="isi[s.id].catatan" :disabled="!D.boleh" class="isian mt-2 py-2 text-sm" placeholder="Alasan (arsip, tidak dicetak)" :aria-label="`Alasan ${s.nama}`" @input="set(s, 'catatan', $event.target.value)" />
      </li>
    </ul>
    <div v-if="ubah.size" class="sticky bottom-[84px] z-20 lg:bottom-4">
      <div class="kartu mx-auto flex max-w-2xl flex-wrap items-center gap-2 p-3 shadow-xl">
        <p class="flex-1 text-sm font-semibold">{{ ubah.size }} perubahan belum disimpan</p>
        <button class="tombol-garis min-h-[40px] px-3 text-sm" :disabled="proses" @click="salin">Batal</button>
        <button class="tombol-utama min-h-[40px] px-3 text-sm" :disabled="proses" @click="simpan"><PhFloppyDisk :size="18" weight="duotone" /> {{ proses ? 'Menyimpan…' : 'Simpan keputusan' }}</button>
      </div>
    </div>
  </div>
</template>
