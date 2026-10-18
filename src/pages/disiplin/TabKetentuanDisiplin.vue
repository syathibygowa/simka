<!-- SIMKA PRO | src/pages/disiplin/TabKetentuanDisiplin.vue | v1.0 | 14.6.0: ketentuan Kedisiplinan Santri (kategori, sanksi per SP, ambang, penanda tangan) | 18/10/2026 -->
<script setup>
// Ketentuan Kedisiplinan Santri: dibaca semua yang membuka menu; diubah Bidang Kesantrian/pemegang tingkat Kelola.
//   kategori pelanggaran dan tingkatnya (ringan/sedang/berat, tanpa poin), sanksi per tingkat SP, masa berlaku dan penanda tangan
//   per SP (bawaan Direktur), ambang pemberitahuan ke Kesantrian, SP-3 mengubah status santri, harapan, tembusan.
import { ref, onMounted, computed } from 'vue'
import { PhFloppyDisk, PhInfo, PhPlus, PhTrash } from '@phosphor-icons/vue'
import { useDisiplin } from '@/stores/disiplin'
import { usePersuratan } from '@/stores/persuratan'
import { useUI } from '@/stores/ui'
import { TINGKAT_SP_SANTRI, TINGKAT_PELANGGARAN } from '@/lib/disiplin'

const ds = useDisiplin(); const ps = usePersuratan(); const ui = useUI()
const f = ref(null); const proses = ref(false)
onMounted(async () => {
  try {
    await Promise.all([ds.muatSet(), ps.muatPenandaTangan().catch(() => {})])
    const s = ds.set
    f.value = { kategori: (s.kategori || []).map((k) => ({ ...k })), sanksi: { 1: (s.sanksi?.[1] || []).join('\n'), 2: (s.sanksi?.[2] || []).join('\n'), 3: (s.sanksi?.[3] || []).join('\n') },
      masa_bulan: { ...s.masa_bulan }, penanda: { 1: s.penanda?.[1] || '', 2: s.penanda?.[2] || '', 3: s.penanda?.[3] || '' }, ambang: { ...s.ambang },
      jendela_hari: s.jendela_hari || 180, harapan: s.harapan || '', tembusan: (s.tembusan || []).join('\n'), beri_tahu_pengasuh: s.beri_tahu_pengasuh !== false, sp3_keluar: s.sp3_keluar !== false }
  } catch (e) { ui.toast(e.message, 'galat') }
})
const boleh = computed(() => !!ds.set?.boleh_ubah)
const tambahKategori = () => f.value.kategori.push({ nama: '', tingkat: 'ringan' })
async function simpan() {
  const baris = (t) => t.split('\n').map((x) => x.trim()).filter(Boolean)
  proses.value = true
  try {
    await ds.simpanSet({ kategori: f.value.kategori.filter((k) => k.nama.trim().length >= 3).map((k) => ({ nama: k.nama.trim(), tingkat: k.tingkat })),
      sanksi: { 1: baris(f.value.sanksi[1]), 2: baris(f.value.sanksi[2]), 3: baris(f.value.sanksi[3]) }, masa_bulan: f.value.masa_bulan, penanda: f.value.penanda,
      ambang: f.value.ambang, jendela_hari: Number(f.value.jendela_hari), harapan: f.value.harapan, tembusan: baris(f.value.tembusan),
      beri_tahu_pengasuh: f.value.beri_tahu_pengasuh, sp3_keluar: f.value.sp3_keluar })
    ui.toast('Ketentuan kedisiplinan santri tersimpan.')
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
</script>
<template>
  <p v-if="!f" class="py-10 text-center text-teks3">Memuat ketentuan…</p>
  <div v-else class="grid gap-4 lg:grid-cols-2">
    <section class="kartu w-disiplin p-5 lg:row-span-2">
      <h3 class="judul-bagian mb-1">Kategori pelanggaran</h3>
      <p class="mb-3 text-sm text-teks3">Tanpa poin. Tingkat kategori menentukan warna catatan, pemberitahuan, dan ambang. "Lainnya" memilih tingkatnya saat dicatat.</p>
      <ul class="space-y-2">
        <li v-for="(k, i) in f.kategori" :key="i" class="grid grid-cols-[1fr_7.5rem_auto] items-center gap-2">
          <input v-model="k.nama" class="isian" :aria-label="`Nama kategori ${i + 1}`" :disabled="!boleh" />
          <select v-model="k.tingkat" class="isian px-2" :aria-label="`Tingkat kategori ${i + 1}`" :disabled="!boleh">
            <option v-for="(t, kk) in TINGKAT_PELANGGARAN" :key="kk" :value="kk">{{ t.n }}</option></select>
          <button v-if="boleh" class="tombol-ikon" :aria-label="`Hapus kategori ${k.nama}`" @click="f.kategori.splice(i, 1)"><PhTrash :size="18" /></button>
        </li>
      </ul>
      <button v-if="boleh" class="tombol-garis mt-3 min-h-[44px] px-3 text-sm" @click="tambahKategori"><PhPlus :size="18" weight="bold" /> Tambah kategori</button>
    </section>

    <section class="kartu w-laporan space-y-4 p-5">
      <h3 class="judul-bagian">Surat peringatan: sanksi, masa berlaku, penanda tangan</h3>
      <div v-for="t in [1, 2, 3]" :key="t" :class="['space-y-2 rounded-xl border border-garis p-3', 'w-' + TINGKAT_SP_SANTRI[t].w]">
        <p class="font-extrabold" style="color: var(--c)">{{ TINGKAT_SP_SANTRI[t].singkat }} · {{ TINGKAT_SP_SANTRI[t].nama }}</p>
        <div><label class="label-isian" :for="'sk-' + t">Pilihan sanksi (satu per baris)</label><textarea :id="'sk-' + t" v-model="f.sanksi[t]" rows="3" class="isian" :disabled="!boleh" /></div>
        <div class="grid grid-cols-[6rem_1fr] gap-2">
          <div v-if="t < 3"><label class="label-isian" :for="'mb-' + t">Berlaku (bulan)</label><input :id="'mb-' + t" v-model.number="f.masa_bulan[t]" type="number" min="1" max="24" class="isian text-center" :disabled="!boleh" /></div>
          <div :class="t === 3 && 'col-span-2'"><label class="label-isian" :for="'pn-' + t">Ditandatangani</label>
            <select :id="'pn-' + t" v-model="f.penanda[t]" class="isian" :disabled="!boleh"><option value="">Direktur (bawaan)</option>
              <option v-for="s in ps.penandaTangan" :key="s.id" :value="s.id">{{ s.jabatan }} – {{ s.nama }}</option></select></div>
        </div>
      </div>
      <label class="flex items-start gap-3 rounded-xl border border-garis p-3 text-sm"><input v-model="f.sp3_keluar" type="checkbox" class="mt-0.5 h-5 w-5 shrink-0 accent-[#A3261C]" :disabled="!boleh" />
        <span><b>SP-3 mengubah status santri menjadi Berhenti</b><span class="block text-xs text-teks3">Saat SP-3 terbit, santri dikembalikan kepada orang tua; status berubah otomatis dan pengelola Keuangan diberi tahu untuk memeriksa tunggakan.</span></span></label>
    </section>

    <section class="kartu w-pengajuan space-y-4 p-5">
      <h3 class="judul-bagian">Pemberitahuan dan isi surat</h3>
      <div><p class="label-isian">Ambang pemberitahuan ke Bidang Kesantrian</p>
        <div class="grid grid-cols-3 gap-2">
          <div v-for="(t, k) in TINGKAT_PELANGGARAN" :key="k" :class="'w-' + t.w"><label class="text-xs font-semibold" style="color: var(--c)" :for="'am-' + k">{{ t.n }}</label>
            <input :id="'am-' + k" v-model.number="f.ambang[k]" type="number" min="0" max="50" class="isian text-center" :disabled="!boleh" /></div>
        </div>
        <div class="mt-2 grid grid-cols-[1fr_7rem] items-center gap-2"><label class="text-sm text-teks2" for="am-jendela">Dihitung dalam rentang (hari terakhir)</label>
          <input id="am-jendela" v-model.number="f.jendela_hari" type="number" min="30" max="365" class="isian text-center" :disabled="!boleh" /></div>
        <p class="mt-1 text-xs text-teks3">Bila jumlah pelanggaran yang belum ditindaklanjuti SP mencapai angka ini, Bidang Kesantrian mendapat notifikasi untuk mempertimbangkan surat peringatan. 0 = tidak dipakai.</p></div>
      <label class="flex items-start gap-3 text-sm"><input v-model="f.beri_tahu_pengasuh" type="checkbox" class="mt-0.5 h-5 w-5 shrink-0 accent-[#A3261C]" :disabled="!boleh" />
        <span><b>Beri tahu pengasuh santri</b><span class="block text-xs text-teks3">Wali kelas, musyrif, muhaffizh, dan pembina ekskul santri menerima notifikasi setiap pelanggaran dicatat.</span></span></label>
      <div><label class="label-isian" for="ds-har">Harapan perbaikan bawaan (SP-1 dan SP-2)</label><textarea id="ds-har" v-model="f.harapan" rows="2" class="isian" :disabled="!boleh" /></div>
      <div><label class="label-isian" for="ds-tem">Tembusan (satu per baris)</label><textarea id="ds-tem" v-model="f.tembusan" rows="4" class="isian" :disabled="!boleh" /></div>
      <p class="flex gap-2 text-xs text-teks3"><PhInfo :size="16" class="shrink-0" />Isi surat (template SP-1, SP-2, SP-3 santri) dapat disunting Tata Usaha di Persuratan → Template. Penanda tangan diambil dari Setelan → Penanda tangan.</p>
      <button v-if="boleh" class="tombol-utama w-full" :disabled="proses" @click="simpan"><PhFloppyDisk :size="20" weight="duotone" /> Simpan ketentuan</button>
      <p v-else class="text-sm text-teks3">Ketentuan diubah oleh Bidang Kesantrian atau pemegang Kedisiplinan santri tingkat Kelola.</p>
    </section>
  </div>
</template>
