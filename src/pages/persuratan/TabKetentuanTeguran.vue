<!-- SIMKA PRO | src/pages/persuratan/TabKetentuanTeguran.vue | v1.0 | 14.1.0: ketentuan Surat Teguran (masa berlaku, penanda tangan, pelanggaran, tembusan) | 17/10/2026 -->
<script setup>
// Ketentuan Surat Teguran: dibaca semua yang membuka tab Surat Teguran; diubah pemegang Surat teguran tingkat Kelola.
//   masa berlaku per tingkat (bulan), penanda tangan per tingkat (bawaan Direktur; paling tinggi Ketua Yayasan),
//   daftar kategori pelanggaran, harapan perbaikan bawaan, tembusan ({bidang} = bidang pegawai yang ditegur).
import { ref, onMounted, computed } from 'vue'
import { PhFloppyDisk, PhInfo } from '@phosphor-icons/vue'
import { useTeguran } from '@/stores/teguran'
import { usePersuratan } from '@/stores/persuratan'
import { useUI } from '@/stores/ui'
import { TINGKAT_SP } from '@/lib/teguran'

const tg = useTeguran(); const ps = usePersuratan(); const ui = useUI()
const f = ref(null); const proses = ref(false)
onMounted(async () => {
  try {
    await Promise.all([tg.muatSet(), ps.muatPenandaTangan()])
    const s = tg.set
    f.value = { masa_bulan: { ...s.masa_bulan }, penanda: { 1: s.penanda?.[1] || '', 2: s.penanda?.[2] || '', 3: s.penanda?.[3] || '' },
      kategori: (s.kategori || []).join('\n'), harapan: s.harapan || '', tembusan: (s.tembusan || []).join('\n') }
  } catch (e) { ui.toast(e.message, 'galat') }
})
const boleh = computed(() => !!tg.set?.boleh_ubah)
async function simpan() {
  proses.value = true
  try {
    await tg.simpanSet({ masa_bulan: f.value.masa_bulan, penanda: f.value.penanda, harapan: f.value.harapan,
      kategori: f.value.kategori.split('\n').map((x) => x.trim()).filter(Boolean), tembusan: f.value.tembusan.split('\n').map((x) => x.trim()).filter(Boolean) })
    ui.toast('Ketentuan surat teguran tersimpan.')
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
</script>
<template>
  <p v-if="!f" class="py-10 text-center text-teks3">Memuat ketentuan…</p>
  <div v-else class="grid gap-4 lg:grid-cols-2">
    <section class="kartu w-klinik p-5">
      <h3 class="judul-bagian mb-3">Masa berlaku dan penanda tangan</h3>
      <div class="space-y-4">
        <div v-for="t in [1, 2, 3]" :key="t" :class="['grid grid-cols-[72px_1fr] items-end gap-3', 'w-' + TINGKAT_SP[t].w]">
          <div><label class="label-isian" :for="'masa-' + t"><b style="color: var(--c)">{{ TINGKAT_SP[t].singkat }}</b></label>
            <div class="flex items-center gap-1"><input :id="'masa-' + t" v-model.number="f.masa_bulan[t]" type="number" min="1" max="24" class="isian px-2 text-center" :disabled="!boleh" /></div>
            <span class="text-xs text-teks3">bulan</span></div>
          <div><label class="label-isian" :for="'pen-' + t">Ditandatangani</label>
            <select :id="'pen-' + t" v-model="f.penanda[t]" class="isian" :disabled="!boleh">
              <option value="">Direktur (bawaan)</option>
              <option v-for="s in ps.penandaTangan" :key="s.id" :value="s.id">{{ s.jabatan }} – {{ s.nama }}</option>
            </select></div>
        </div>
      </div>
      <p class="mt-3 flex gap-2 text-xs text-teks3"><PhInfo :size="16" class="shrink-0" />Penanda tangan paling tinggi Ketua Yayasan. Pilihan penanda tangan diambil dari Setelan → Penanda tangan.
        SP berakhir otomatis setelah masa berlakunya lewat dan tetap tercatat di riwayat.</p>
    </section>
    <section class="kartu w-pengajuan space-y-4 p-5">
      <div><label class="label-isian" for="sp-kat">Kategori pelanggaran (satu per baris)</label>
        <textarea id="sp-kat" v-model="f.kategori" rows="6" class="isian" :disabled="!boleh" /></div>
      <div><label class="label-isian" for="sp-har">Harapan perbaikan bawaan</label>
        <textarea id="sp-har" v-model="f.harapan" rows="2" class="isian" :disabled="!boleh" /></div>
      <div><label class="label-isian" for="sp-tem">Tembusan (satu per baris)</label>
        <textarea id="sp-tem" v-model="f.tembusan" rows="3" class="isian" :disabled="!boleh" />
        <p class="mt-1 text-xs text-teks3">Tulis {bidang} untuk nama bidang pegawai yang ditegur, mis. "Kepala {bidang}".</p></div>
      <button v-if="boleh" class="tombol-utama w-full" :disabled="proses" @click="simpan"><PhFloppyDisk :size="20" weight="duotone" /> Simpan ketentuan</button>
      <p v-else class="text-sm text-teks3">Ketentuan diubah oleh pemegang Surat teguran tingkat Kelola.</p>
    </section>
  </div>
</template>
