<!-- SIMKA PRO | src/pages/santri/SeksiDisiplin.vue | v1.0 | 14.6.0: kedisiplinan santri di biodata (pelanggaran, SP, cetak riwayat) | 18/10/2026 -->
<script setup>
// Bagian "Kedisiplinan" di biodata santri (hanya bagi yang berhak: pengasuh, Security, Kesantrian, pimpinan, TU, pemegang fitur):
// ringkasan pelanggaran per tingkat, surat peringatan, lima catatan terakhir, catat pelanggaran, riwayat lengkap, usul SP, cetak riwayat F4.
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { PhGavel, PhPlus, PhCaretRight, PhPrinter, PhWarningOctagon } from '@phosphor-icons/vue'
import { useDisiplin } from '@/stores/disiplin'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { TINGKAT_PELANGGARAN, TINGKAT_SP_SANTRI, KEADAAN_SP_SANTRI } from '@/lib/disiplin'
import { formatPendek, formatPanjang } from '@/lib/tanggal'
import { namaBerkas } from '@/lib/namaBerkas'
import { ambilPenandaTangan } from '@/lib/penandatangan'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'
import LembarPelanggaran from '@/pages/disiplin/LembarPelanggaran.vue'
import LembarUsulSPSantri from '@/pages/disiplin/LembarUsulSPSantri.vue'

const props = defineProps({ santri: { type: Object, required: true } })
const ds = useDisiplin(); const sesi = useSesi(); const ui = useUI(); const router = useRouter()
const pel = ref([]); const sp = ref([]); const memuat = ref(true); const lembar = ref(false); const lembarSP = ref(false); const pratinjau = ref(false)
const kesantrian = ref({ jabatan: 'Kepala Bidang Kesantrian', nama: '', niy: '' })
async function muat() {
  memuat.value = true
  try { [pel.value, sp.value] = await Promise.all([ds.daftar({ santri: props.santri.id }), ds.daftarSP({ santri: props.santri.id })]) }
  catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false }
}
onMounted(async () => {
  try { if (!ds.hakDimuat) await ds.muatHak() } catch { /* tanpa hak: bagian tidak tampil */ }
  if (ds.hak.tampil) { muat(); ambilPenandaTangan('%Kesantrian%').then((d) => { if (d?.nama) kesantrian.value = d }).catch(() => {}) }
})
watch(() => props.santri.id, () => ds.hak.tampil && muat())
const hitung = computed(() => Object.fromEntries(['ringan', 'sedang', 'berat'].map((t) => [t, pel.value.filter((x) => x.tingkat === t).length])))
const spAktif = computed(() => sp.value.filter((x) => x.keadaan === 'aktif').reduce((m, x) => Math.max(m, x.tingkat), 0))
const kunci = computed(() => ({ id: props.santri.id, nama: props.santri.nama_lengkap, nis: props.santri.nis,
  kelas: (props.santri.kelompok || []).find((k) => k.jenis === 'kelas')?.nama || '', kamar: (props.santri.kelompok || []).find((k) => k.jenis === 'kamar')?.nama || '' }))
</script>
<template>
  <section v-if="ds.hak.tampil" class="kartu w-disiplin mt-4 p-5">
    <div class="mb-3 flex flex-wrap items-center gap-3">
      <span class="chip-ikon h-10 w-10"><PhGavel :size="22" weight="duotone" /></span>
      <div class="min-w-0 flex-1"><h3 class="judul-bagian">Kedisiplinan</h3><p class="text-sm text-teks3">Catatan terbatas; tidak tampil di Portal Wali.</p></div>
      <button v-if="ds.hak.catat && santri.status === 'aktif'" class="tombol-garis min-h-[40px] px-3 text-sm" @click="lembar = true"><PhPlus :size="18" weight="bold" /> Catat</button>
      <button v-if="ds.hak.usul && santri.status === 'aktif'" class="tombol-garis min-h-[40px] px-3 text-sm" @click="lembarSP = true"><PhWarningOctagon :size="18" weight="duotone" /> Usulkan SP</button>
      <button class="tombol-garis min-h-[40px] px-3 text-sm" :disabled="memuat || (!pel.length && !sp.length)" @click="pratinjau = true"><PhPrinter :size="18" weight="duotone" /> Cetak</button>
    </div>
    <p v-if="memuat" class="py-3 text-sm text-teks3">Memuat kedisiplinan…</p>
    <template v-else>
      <div class="grid grid-cols-4 gap-2 text-center">
        <div v-for="(t, k) in TINGKAT_PELANGGARAN" :key="k" :class="['rounded-xl bg-permukaan2 p-2', 'w-' + t.w]"><p class="text-xl font-extrabold tabular-nums" style="color: var(--c)">{{ hitung[k] }}</p><p class="text-xs text-teks3">{{ t.n }}</p></div>
        <div :class="['rounded-xl bg-permukaan2 p-2', spAktif ? 'w-' + TINGKAT_SP_SANTRI[spAktif].w : '']"><p class="text-xl font-extrabold" style="color: var(--c)">{{ spAktif ? TINGKAT_SP_SANTRI[spAktif].singkat : '–' }}</p><p class="text-xs text-teks3">SP aktif</p></div>
      </div>
      <ul v-if="sp.length" class="mt-3 space-y-1.5">
        <li v-for="w in sp" :key="w.id"><router-link :to="{ path: '/disiplin-santri/sp', query: { sp: w.id } }" :class="['flex items-center gap-2 rounded-xl border border-garis px-3 py-2 text-sm hover:bg-permukaan2', 'w-' + TINGKAT_SP_SANTRI[w.tingkat].w]">
          <b style="color: var(--c)">{{ TINGKAT_SP_SANTRI[w.tingkat].singkat }}</b><span class="min-w-0 flex-1 truncate">{{ w.nomor || 'Diproses Tata Usaha' }} · {{ w.kategori.join(', ') }}</span>
          <span :class="['lencana', 'w-' + KEADAAN_SP_SANTRI[w.keadaan].w]">{{ KEADAAN_SP_SANTRI[w.keadaan].n }}</span></router-link></li>
      </ul>
      <ul v-if="pel.length" class="mt-3 divide-y divide-garis">
        <li v-for="x in pel.slice(0, 5)" :key="x.id" class="flex items-start gap-2 py-2 text-sm">
          <span :class="['lencana mt-0.5', 'w-' + TINGKAT_PELANGGARAN[x.tingkat].w]">{{ TINGKAT_PELANGGARAN[x.tingkat].n }}</span>
          <span class="min-w-0 flex-1"><b>{{ x.kategori }}</b><span class="block text-xs text-teks3">{{ formatPendek(x.tanggal) }} · {{ x.uraian }}</span></span></li>
      </ul>
      <p v-else class="mt-3 rounded-xl bg-permukaan2 p-3 text-sm text-teks3">Belum ada catatan pelanggaran.</p>
      <button v-if="pel.length" class="tombol-teks mt-2 min-h-[40px] px-1 text-sm" @click="router.push({ path: '/disiplin-santri/pelanggaran', query: { santri: santri.id } })">Lihat seluruh riwayat ({{ pel.length }}) <PhCaretRight :size="16" /></button>
    </template>
    <LembarPelanggaran v-model="lembar" :santri="kunci" @selesai="muat" />
    <LembarUsulSPSantri v-if="ds.hak.usul" v-model="lembarSP" :santri-awal="kunci" @tersimpan="muat" />

    <DokumenCetak judul="Riwayat Kedisiplinan Santri" :subjudul="`${santri.nama_lengkap} · NIS ${santri.nis}${kunci.kelas ? ' · ' + kunci.kelas : ''}`" v-model:pratinjau="pratinjau"
      :pencetak="sesi.pengguna?.nama_lengkap" :nama-berkas="namaBerkas(santri.nama_lengkap, 'Riwayat Kedisiplinan Santri')">
      <p style="font-weight: 700; margin: 0 0 4pt">A. Surat peringatan</p>
      <table class="tabel">
        <colgroup><col style="width:5%"><col style="width:8%"><col style="width:22%"><col style="width:12%"><col style="width:33%"><col style="width:20%"></colgroup>
        <thead><tr><th>No.</th><th>Tingkat</th><th>Nomor surat</th><th>Tanggal</th><th>Pelanggaran</th><th>Keadaan</th></tr></thead>
        <tbody><tr v-for="(w, i) in sp" :key="w.id"><td class="tengah">{{ i + 1 }}</td><td class="tengah">{{ TINGKAT_SP_SANTRI[w.tingkat].singkat }}</td><td>{{ w.nomor || 'Belum terbit' }}</td>
          <td class="tengah">{{ w.tanggal_surat ? formatPendek(w.tanggal_surat) : '–' }}</td><td>{{ w.kategori.join('; ') }}</td><td>{{ KEADAAN_SP_SANTRI[w.keadaan].n }}</td></tr>
          <tr v-if="!sp.length"><td colspan="6" class="tengah">Tidak ada surat peringatan.</td></tr></tbody>
      </table>
      <p style="font-weight: 700; margin: 10pt 0 4pt">B. Catatan pelanggaran</p>
      <table class="tabel">
        <colgroup><col style="width:5%"><col style="width:12%"><col style="width:9%"><col style="width:22%"><col style="width:32%"><col style="width:20%"></colgroup>
        <thead><tr><th>No.</th><th>Tanggal</th><th>Tingkat</th><th>Kategori</th><th>Uraian dan tindakan</th><th>Dicatat oleh</th></tr></thead>
        <tbody><tr v-for="(x, i) in pel" :key="x.id"><td class="tengah">{{ i + 1 }}</td><td class="tengah">{{ formatPendek(x.tanggal) }}</td><td class="tengah">{{ TINGKAT_PELANGGARAN[x.tingkat].n }}</td>
          <td>{{ x.kategori }}</td><td>{{ x.uraian }}{{ x.tindakan ? '. Tindakan: ' + x.tindakan : '' }}</td><td>{{ x.pencatat || '–' }}</td></tr>
          <tr v-if="!pel.length"><td colspan="6" class="tengah">Tidak ada catatan pelanggaran.</td></tr></tbody>
      </table>
      <p style="margin-top: 6pt; font-size: 9pt">Ringan {{ hitung.ringan }}, sedang {{ hitung.sedang }}, berat {{ hitung.berat }}. Dicetak {{ formatPanjang(new Date()) }}. Dokumen ini bersifat terbatas.</p>
      <template #ttd>
        <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: kesantrian.jabatan || 'Kepala Bidang Kesantrian', nama: kesantrian.nama, niy: kesantrian.niy }"
          :kanan="{ jabatan: 'Yang membuat,', nama: sesi.pengguna?.nama_lengkap || '', niy: sesi.pengguna?.niy }" />
      </template>
    </DokumenCetak>
  </section>
</template>
