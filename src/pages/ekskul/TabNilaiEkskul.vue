<!-- SIMKA PRO | src/pages/ekskul/TabNilaiEkskul.vue | v1.3 | Perbaikan 13.7.0: saringan kategori ekskul indoor/outdoor | 16/10/2026 -->
<script setup>
// Ekskul → Nilai rapor: pembina mengisi nilai Pengembangan Diri (predikat A–D) per santri anggota ekskul.
// Acuan: persentase kehadiran ekskul semester ini (usulan otomatis: ≥ 90% A, ≥ 75% B, ≥ 60% C, selain itu D).
// Deskripsi rapor otomatis dari predikat (Penilaian → Predikat → Pengembangan diri, isian {kegiatan}); boleh diganti per santri.
// Pengisian terbuka saat periode penilaian jenjang santri Dibuka; pengelola nilai kapan saja. Cetak daftar nilai (F4).
import { ref, computed, onMounted } from 'vue'
import { PhMedal, PhMagicWand, PhFloppyDisk, PhPrinter, PhInfo } from '@phosphor-icons/vue'
import { useRapor } from '@/stores/rapor'
import { useKelompokSantri } from '@/stores/kelompokSantri'
import { KATEGORI_EKSKUL } from '@/lib/ekskul'
import { watch } from 'vue'
import { usePenilaian } from '@/stores/penilaian'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { LABEL_SEMESTER } from '@/lib/nilai'
import { JENJANG_PENDEK } from '@/lib/santri'
import { deskripsiPd, usulPd } from '@/lib/catatanRapor'
import { formatPanjang, hariIniISO } from '@/lib/tanggal'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'

const props = defineProps({ kategori: { type: String, default: '' } })
const rp = useRapor(); const pn = usePenilaian(); const sesi = useSesi(); const ui = useUI(); const kel = useKelompokSantri()
// Saringan kategori indoor/outdoor dari menu Ekskul
const katId = (id) => kel.cari(id)?.kategori_ekskul || ''
const daftarTampil = computed(() => daftar.value.filter((g) => !props.kategori || katId(g.group_id) === props.kategori))
const semester = ref(null); const daftar = ref([]); const pilih = ref(''); const D = ref(null); const galat = ref(''); const proses = ref(false)
async function muat(s) {
  galat.value = ''
  try {
    if (!pn.dimuat) await pn.muat()
    semester.value = s || semester.value || pn.ta?.semester || 1
    daftar.value = (await rp.ekskulSaya(semester.value)).daftar || []
    if (!daftar.value.some((g) => g.group_id === pilih.value)) pilih.value = daftar.value[0]?.group_id || ''
    await muatNilai()
  } catch (e) { galat.value = e.message }
}
async function muatNilai() { D.value = pilih.value ? await rp.nilaiEkskul(pilih.value, semester.value) : null; salin() }
onMounted(() => { kel.muat().catch(() => {}); muat() })
// Kategori berganti: buka ekskul pertama pada kategori itu
watch(() => props.kategori, () => { if (daftarTampil.value.length && !daftarTampil.value.some((g) => g.group_id === pilih.value)) bukaEkskul(daftarTampil.value[0].group_id) })
async function bukaEkskul(id) { pilih.value = id; D.value = null; try { await muatNilai() } catch (e) { galat.value = e.message } }

const isi = ref({}); const ubah = ref(new Set())
function salin() { isi.value = Object.fromEntries((D.value?.santri || []).map((s) => [s.id, { nilai: s.nilai || '', deskripsi: s.deskripsi || '' }])); ubah.value = new Set() }
const huruf = computed(() => (D.value?.predikat || []).map((p) => p.huruf))
const boleh = (s) => !!D.value?.boleh?.[s.jenjang]
const set = (s, f, v) => { isi.value[s.id][f] = v; ubah.value = new Set([...ubah.value, s.id]) }
const persen = (s) => (s.sesi ? Math.round((s.hadir / s.sesi) * 100) : null)
const auto = (s) => deskripsiPd(D.value?.predikat, isi.value[s.id]?.nilai, D.value?.ekskul?.nama)
function usulkan() {
  let n = 0
  for (const s of D.value.santri) if (boleh(s) && !isi.value[s.id].nilai) { const u = usulPd(s.hadir, s.sesi, huruf.value); if (u) { set(s, 'nilai', u); n++ } }
  ui.toast(n ? `${n} nilai diusulkan dari kehadiran. Periksa lalu simpan.` : 'Tidak ada isian kosong yang dapat diusulkan (belum ada pertemuan tercatat atau semua sudah terisi).')
}
async function simpan() {
  proses.value = true
  try {
    await rp.simpanEkskul(pilih.value, semester.value, [...ubah.value].map((id) => ({ student_id: id, nilai: isi.value[id].nilai || null, deskripsi: (isi.value[id].deskripsi || '').trim() })))
    ui.toast('Nilai pengembangan diri disimpan.'); await muat()
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
const terisi = computed(() => (D.value?.santri || []).filter((s) => isi.value[s.id]?.nilai).length)
const tertutup = computed(() => D.value && !D.value.boleh?.sma && !D.value.boleh?.wustha)
const pratinjau = ref(false)
const pembina = computed(() => daftar.value.find((g) => g.group_id === pilih.value)?.pembina || '')
</script>
<template>
  <div class="w-ekskul space-y-4">
    <div class="kartu flex flex-wrap items-center gap-3 p-4">
      <div class="bilah-tab kecil" role="tablist" aria-label="Semester">
        <button v-for="s in [1, 2]" :key="s" type="button" role="tab" :aria-selected="semester === s" @click="muat(s)"
          :class="['tab-garis', semester === s && 'aktif']">{{ LABEL_SEMESTER[s] }}</button>
      </div>
      <p class="min-w-[200px] flex-1 text-xs text-teks3">Nilai Pengembangan Diri di rapor diambil dari ekskul yang diikuti santri. Usulan nilai dari kehadiran: ≥ 90% A, ≥ 75% B, ≥ 60% C, selain itu D.</p>
      <button class="tombol-garis min-h-[40px] px-3 text-sm" :disabled="!D" @click="pratinjau = true"><PhPrinter :size="18" weight="duotone" /> Cetak</button>
    </div>
    <div v-if="galat" class="kartu w-klinik p-5 text-sm font-semibold" style="color: var(--c)">Nilai ekskul gagal dimuat: {{ galat }} Pastikan migrasi SQL 8500 sudah dijalankan.</div>
    <p v-else-if="semester && !daftar.length" class="kartu p-6 text-center text-sm text-teks3">Belum ada ekskul yang dapat Anda nilai. Pembina ditetapkan di Kelompok Santri → Ekskul.</p>
    <template v-else-if="semester">
      <!-- Daftar ekskul: kisi berlipat (tidak memanjang ke samping), tersaring kategori indoor/outdoor -->
      <ul class="grid grid-cols-2 gap-2 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5">
        <li v-for="g in daftarTampil" :key="g.group_id">
          <button type="button" :class="['pilih-ekskul flex h-full min-h-[56px] w-full items-center gap-2 rounded-2xl border px-3 py-2 text-left text-sm', 'w-' + (KATEGORI_EKSKUL[katId(g.group_id)]?.w || 'ekskul'), g.group_id === pilih ? 'aktif' : 'border-garis text-teks2 hover:bg-permukaan2']" @click="bukaEkskul(g.group_id)">
            <component :is="KATEGORI_EKSKUL[katId(g.group_id)]?.ikon || PhMedal" :size="20" weight="duotone" class="shrink-0" style="color: var(--c)" />
            <span class="min-w-0"><b class="block truncate">{{ g.nama }}</b><span class="block truncate text-xs text-teks3 tabular-nums">{{ g.terisi }}/{{ g.santri }} dinilai{{ g.asuhan_saya ? ' · binaan saya' : '' }}</span></span>
          </button></li>
        <li v-if="!daftarTampil.length" class="col-span-full kartu p-4 text-center text-sm text-teks3">Tidak ada ekskul pada kategori ini.</li>
      </ul>
      <template v-if="D">
        <p v-if="tertutup" class="flex gap-2 rounded-2xl bg-permukaan2 p-3 text-sm text-teks2"><PhInfo :size="18" class="mt-0.5 shrink-0" />
          <span>Pengisian belum/tidak terbuka: periode penilaian {{ LABEL_SEMESTER[semester]?.toLowerCase() }} belum dibuka atau sudah ditutup (Penilaian → Periode), atau Anda bukan pembina ekskul ini.</span></p>
        <div class="kartu flex flex-wrap items-center gap-2 p-3 text-sm">
          <p class="min-w-[160px] flex-1"><b class="tabular-nums">{{ terisi }}/{{ D.santri.length }}</b> <span class="text-teks3">santri dinilai · pembina {{ pembina || '–' }}</span></p>
          <button v-if="!tertutup" class="tombol-garis min-h-[40px] px-3 text-sm" @click="usulkan"><PhMagicWand :size="18" /> Usulkan dari kehadiran</button>
        </div>
        <ul class="space-y-2">
          <li v-for="(s, i) in D.santri" :key="s.id" class="kartu p-3">
            <div class="flex flex-wrap items-center gap-x-3 gap-y-2">
              <div class="min-w-0 flex-1 basis-[50%]">
                <p class="truncate font-semibold"><span class="text-teks3 tabular-nums">{{ i + 1 }}.</span> {{ s.nama }}</p>
                <p class="text-xs text-teks3">{{ s.nis }} · {{ s.jenis_kelamin }} · {{ s.kelas ? 'Kelas ' + s.kelas : JENJANG_PENDEK[s.jenjang] }} · hadir
                  <b :class="persen(s) != null && persen(s) < 75 ? 'text-merah' : ''">{{ s.sesi ? `${s.hadir}/${s.sesi} (${persen(s)}%)` : 'belum ada pertemuan' }}</b></p>
              </div>
              <div class="flex gap-1" role="radiogroup" :aria-label="`Nilai ${s.nama}`">
                <button v-for="h in huruf" :key="h" type="button" role="radio" :aria-checked="isi[s.id]?.nilai === h" :disabled="!boleh(s)"
                  :class="['h-10 w-10 rounded-xl border text-sm font-bold', isi[s.id]?.nilai === h ? 'border-transparent text-[rgb(var(--permukaan))]' : 'border-garis text-teks2']"
                  :style="isi[s.id]?.nilai === h ? 'background: var(--c)' : ''" @click="set(s, 'nilai', isi[s.id].nilai === h ? '' : h)">{{ h }}</button>
              </div>
            </div>
            <input :value="isi[s.id]?.deskripsi" :disabled="!boleh(s)" class="isian mt-2 py-2 text-sm" :placeholder="auto(s) || 'Deskripsi otomatis dari predikat'" :aria-label="`Deskripsi ${s.nama}`"
              @input="set(s, 'deskripsi', $event.target.value)" />
          </li>
        </ul>
        <p v-if="!D.santri.length" class="kartu p-6 text-center text-sm text-teks3">Ekskul ini belum beranggota.</p>
        <div v-if="ubah.size" class="sticky bottom-[84px] z-20 lg:bottom-4">
          <div class="kartu mx-auto flex max-w-2xl flex-wrap items-center gap-2 p-3 shadow-xl">
            <p class="flex-1 text-sm font-semibold">{{ ubah.size }} perubahan belum disimpan</p>
            <button class="tombol-garis min-h-[40px] px-3 text-sm" :disabled="proses" @click="salin">Batal</button>
            <button class="tombol-utama min-h-[40px] px-3 text-sm" :disabled="proses" @click="simpan"><PhFloppyDisk :size="18" weight="duotone" /> {{ proses ? 'Menyimpan…' : 'Simpan nilai' }}</button>
          </div>
        </div>
      </template>
      <p v-else class="kartu p-6 text-center text-sm text-teks3">Memuat nilai…</p>
    </template>

    <DokumenCetak kop="pondok" judul="Daftar Nilai Pengembangan Diri" :subjudul="`${D?.ekskul?.nama || ''} · ${LABEL_SEMESTER[semester] || ''} · keadaan ${formatPanjang(hariIniISO())}`"
      v-model:pratinjau="pratinjau" :pencetak="sesi.pengguna?.nama_lengkap">
      <table v-if="D" class="tabel"><colgroup><col style="width:6%"><col style="width:12%"><col style="width:28%"><col style="width:5%"><col style="width:9%"><col style="width:11%"><col style="width:7%"><col style="width:22%"></colgroup>
        <thead><tr><th>No.</th><th>NIS</th><th>Nama</th><th>JK</th><th>Kelas</th><th>Kehadiran</th><th>Nilai</th><th>Deskripsi</th></tr></thead>
        <tbody><tr v-for="(s, i) in D.santri" :key="s.id"><td class="tengah">{{ i + 1 }}</td><td>{{ s.nis }}</td><td>{{ s.nama }}</td><td class="tengah">{{ s.jenis_kelamin }}</td>
          <td class="tengah">{{ s.kelas || '–' }}</td><td class="tengah">{{ s.sesi ? `${s.hadir}/${s.sesi}` : '–' }}</td><td class="tengah">{{ s.nilai || '' }}</td>
          <td>{{ s.nilai ? s.deskripsi || deskripsiPd(D.predikat, s.nilai, D.ekskul.nama) : '' }}</td></tr></tbody></table>
      <p v-if="D" style="margin-top: 4pt; font-size: 9pt">{{ D.predikat.map((p) => `${p.huruf} = ${p.sebutan}`).join(' · ') }}</p>
      <template #ttd><TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: 'Koordinator Ekstrakurikuler', nama: '' }" :kanan="{ jabatan: 'Pembina ' + (D?.ekskul?.nama || ''), nama: pembina.split(', ')[0] || '' }" /></template>
    </DokumenCetak>
  </div>
</template>
<style scoped>
.pilih-ekskul.aktif { border-color: var(--c); background: color-mix(in srgb, var(--c) 10%, rgb(var(--permukaan))); box-shadow: 0 0 0 1px var(--c); color: rgb(var(--teks)); }
</style>
