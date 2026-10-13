<!-- SIMKA PRO | src/pages/walikelas/IsianNilaiManual.vue | v1.0 | Fase 12 – Tahap 5 Nilai mapel rapor diisi wali kelas | 13/10/2026 -->
<script setup>
// Wali Kelas → Rapor → Nilai wali kelas: mapel rapor bersumber "Diisi wali kelas" (tidak ada mapel ajar yang menjadi
// sumber). Wali kelas mengisi nilai (dan keterampilan bila rapor memakainya) serta deskripsi khusus bila perlu.
import { ref, computed, watch } from 'vue'
import { PhFloppyDisk, PhInfo } from '@phosphor-icons/vue'
import { useRapor } from '@/stores/rapor'
import { useUI } from '@/stores/ui'

const props = defineProps({ D: { type: Object, required: true } })
const emit = defineEmits(['tersimpan'])
const rp = useRapor(); const ui = useUI()
const mapel = computed(() => props.D.mapel.filter((m) => m.sumber === 'manual'))
const pilih = ref(''); watch(mapel, (v) => { if (!v.some((m) => m.id === pilih.value)) pilih.value = v[0]?.id || '' }, { immediate: true })
const m = computed(() => mapel.value.find((x) => x.id === pilih.value))
const ket = computed(() => !!props.D.ketentuan?.pakai_keterampilan)
const isi = ref({}); const ubah = ref(new Set()); const proses = ref(false)
function salin() { isi.value = Object.fromEntries(props.D.santri.map((s) => { const x = s.nilai?.[pilih.value] || {}; return [s.id, { nilai: x.nilai ?? '', keterampilan: x.keterampilan ?? '', deskripsi: x.deskripsi || '' }] })); ubah.value = new Set() }
watch([pilih, () => props.D], salin, { immediate: true })
const set = (s, f, v) => { isi.value[s.id][f] = v; ubah.value = new Set([...ubah.value, s.id]) }
async function simpan() {
  const daftar = [...ubah.value].map((id) => ({ student_id: id, report_subject_id: pilih.value, nilai: isi.value[id].nilai === '' ? '' : Number(isi.value[id].nilai),
    keterampilan: !ket.value || isi.value[id].keterampilan === '' ? '' : Number(isi.value[id].keterampilan), deskripsi: isi.value[id].deskripsi.trim() }))
  if (daftar.some((x) => [x.nilai, x.keterampilan].some((v) => v !== '' && !(v >= 0 && v <= 100)))) return ui.toast('Nilai harus 0–100.', 'galat')
  proses.value = true
  try { await rp.simpanNilaiManual(props.D.kelas.group_id, props.D.semester, daftar); ui.toast(`Nilai ${m.value.nama} disimpan.`); emit('tersimpan') }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
</script>
<template>
  <div class="space-y-3">
    <div class="kartu flex flex-wrap items-center gap-2 p-3">
      <select v-model="pilih" class="isian w-auto max-w-full font-semibold" aria-label="Mapel rapor"><option v-for="x in mapel" :key="x.id" :value="x.id">{{ x.nama }}</option></select>
      <p class="min-w-[200px] flex-1 text-xs text-teks3">Mapel ini tidak bersumber dari mapel ajar, sehingga nilainya diisi wali kelas. {{ D.ketentuan?.label_ambang || 'KKM' }} {{ Number(m?.kkm || 0) }}. Deskripsi kosong = otomatis dari predikat.</p>
    </div>
    <p v-if="!D.boleh" class="flex gap-2 rounded-2xl bg-permukaan2 p-3 text-sm text-teks2"><PhInfo :size="18" class="mt-0.5 shrink-0" /> Pengisian belum/tidak terbuka untuk semester ini.</p>
    <ul class="space-y-2">
      <li v-for="(s, i) in D.santri" :key="s.id" class="kartu flex flex-wrap items-center gap-2 p-3">
        <p class="min-w-0 flex-1 basis-[40%] truncate text-sm font-semibold"><span class="text-teks3 tabular-nums">{{ i + 1 }}.</span> {{ s.nama }} <span class="text-xs font-normal text-teks3">{{ s.nis }} · {{ s.jenis_kelamin }}</span></p>
        <label class="text-center text-[11px] text-teks3">{{ ket ? 'Pengetahuan' : 'Nilai' }}<input :value="isi[s.id]?.nilai" type="number" min="0" max="100" :disabled="!D.boleh" :aria-label="`Nilai ${s.nama}`"
          :class="['mt-0.5 block h-10 w-20 rounded-lg border bg-permukaan text-center text-sm tabular-nums text-teks', ubah.has(s.id) ? 'border-[color:var(--c)]' : 'border-garis']" @input="set(s, 'nilai', $event.target.value)" /></label>
        <label v-if="ket" class="text-center text-[11px] text-teks3">Keterampilan<input :value="isi[s.id]?.keterampilan" type="number" min="0" max="100" :disabled="!D.boleh" :aria-label="`Keterampilan ${s.nama}`"
          class="mt-0.5 block h-10 w-20 rounded-lg border border-garis bg-permukaan text-center text-sm tabular-nums text-teks" @input="set(s, 'keterampilan', $event.target.value)" /></label>
        <input :value="isi[s.id]?.deskripsi" :disabled="!D.boleh" class="isian basis-full py-2 text-sm" placeholder="Deskripsi khusus (opsional)" :aria-label="`Deskripsi ${s.nama}`" @input="set(s, 'deskripsi', $event.target.value)" />
      </li>
    </ul>
    <div v-if="ubah.size" class="sticky bottom-[84px] z-20 lg:bottom-4">
      <div class="kartu mx-auto flex max-w-2xl flex-wrap items-center gap-2 p-3 shadow-xl">
        <p class="flex-1 text-sm font-semibold">{{ ubah.size }} perubahan belum disimpan</p>
        <button class="tombol-garis min-h-[40px] px-3 text-sm" :disabled="proses" @click="salin">Batal</button>
        <button class="tombol-utama min-h-[40px] px-3 text-sm" :disabled="proses" @click="simpan"><PhFloppyDisk :size="18" weight="duotone" /> {{ proses ? 'Menyimpan…' : 'Simpan nilai' }}</button>
      </div>
    </div>
  </div>
</template>
