<!-- SIMKA PRO | src/pages/walikelas/NilaiKelasMapel.vue | v1.0 | 14.4.0: pantauan nilai santri per mapel bagi wali kelas | 17/10/2026 -->
<script setup>
// Wali Kelas → Pelajaran → Nilai per mapel: nilai rapor setiap santri pada setiap mata pelajaran rapor (dari guru mapel),
// kemajuan pengisian per mapel, nilai di bawah KKM bertanda merah, rata-rata santri. Excel dan cetak F4 mendatar.
import { ref, computed, watch, onMounted } from 'vue'
import { PhFileXls, PhPrinter } from '@phosphor-icons/vue'
import { useRapor } from '@/stores/rapor'
import { useLembaga } from '@/stores/lembaga'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'

const props = defineProps({ groupId: { type: String, required: true } })
const rp = useRapor(); const lembaga = useLembaga(); const sesi = useSesi(); const ui = useUI()
const smt = ref(1); const d = ref(null); const memuat = ref(false); const pratinjau = ref(false); const galat = ref('')
async function muat() {
  memuat.value = true; galat.value = ''
  try { d.value = await rp.dataRaporDasar(props.groupId, smt.value) } catch (e) { galat.value = e.message; d.value = null } finally { memuat.value = false }
}
onMounted(async () => { await lembaga.muat(); smt.value = Number(lembaga.tahunAktif?.semester) || 1; muat() })
watch([smt, () => props.groupId], muat)
const mapel = computed(() => (d.value?.mapel || []).filter((m) => m.sumber !== 'manual' || true))
const nilaiDari = (s, m) => s.nilai?.[m.id]?.nilai ?? null
const baris = computed(() => (d.value?.santri || []).map((s) => { const v = mapel.value.map((m) => nilaiDari(s, m)).filter((x) => x != null)
  return { ...s, rata: v.length ? Math.round((10 * v.reduce((a, b) => a + Number(b), 0)) / v.length) / 10 : null, bawah: mapel.value.filter((m) => nilaiDari(s, m) != null && Number(nilaiDari(s, m)) < Number(m.kkm || 0)).length } }))
const terisi = (m) => baris.value.filter((s) => nilaiDari(s, m) != null).length
const nama = (s) => s.nama_lengkap || s.nama
const wali = computed(() => d.value?.wali?.[0] || {})
const direktur = computed(() => lembaga.signatories.find((x) => x.sumber_jabatan === 'DIREKTUR' || /^direktur/i.test(x.jabatan_tertulis)) || {})
async function excel() {
  const XLSX = await import('xlsx')
  const kepala = ['No', 'NIS', 'Nama', ...mapel.value.map((m) => m.singkatan || m.nama), 'Rata-rata', 'Di bawah KKM']
  const isi = baris.value.map((s, i) => [i + 1, s.nis, nama(s), ...mapel.value.map((m) => nilaiDari(s, m) ?? ''), s.rata ?? '', s.bawah])
  const ws = XLSX.utils.aoa_to_sheet([[`NILAI SANTRI PER MATA PELAJARAN – KELAS ${d.value?.kelas?.nama || ''}`], [`Semester ${smt.value} · ${d.value?.ta?.nama || ''}`], [], kepala,
    ...isi, [], ['', '', 'KKM', ...mapel.value.map((m) => m.kkm ?? '')], ['', '', 'Terisi', ...mapel.value.map((m) => `${terisi(m)}/${baris.value.length}`)]])
  ws['!cols'] = [5, 12, 30, ...mapel.value.map(() => 8), 10, 12].map((w) => ({ wch: w }))
  const wb = XLSX.utils.book_new(); XLSX.utils.book_append_sheet(wb, ws, 'Nilai per mapel')
  XLSX.writeFile(wb, `Nilai-per-mapel-${(d.value?.kelas?.nama || '').replace(/[^A-Za-z0-9]+/g, '-')}-smt${smt.value}.xlsx`)
}
</script>
<template>
  <div>
    <div class="mb-3 flex flex-wrap items-center gap-2">
      <div class="bilah-tab kecil" role="tablist" aria-label="Semester"><button v-for="x in [1, 2]" :key="x" type="button" role="tab" :aria-selected="smt === x"
        :class="['tab-garis', smt === x && 'aktif']" @click="smt = x">Semester {{ x }}</button></div>
      <span class="flex-1" />
      <template v-if="d && baris.length">
        <button class="tombol-garis min-h-[40px] px-3 text-sm" @click="excel"><PhFileXls :size="18" weight="duotone" /> Excel</button>
        <button class="tombol-garis min-h-[40px] px-3 text-sm" @click="pratinjau = true"><PhPrinter :size="18" weight="duotone" /> Cetak</button>
      </template>
    </div>
    <p v-if="galat" class="kartu p-6 text-center text-sm text-teks3">{{ galat }}</p>
    <p v-else-if="memuat && !d" class="kartu p-8 text-center text-sm text-teks3">Memuat nilai…</p>
    <p v-else-if="!d || !mapel.length" class="kartu p-8 text-center text-sm text-teks3">Belum ada mapel rapor untuk kelas ini (Penilaian → Mapel rapor).</p>
    <template v-else>
      <div class="mb-3 flex gap-2 overflow-x-auto pb-1">
        <span v-for="m in mapel" :key="m.id" :class="['lencana shrink-0', terisi(m) === baris.length ? 'w-presensi' : terisi(m) ? 'w-agenda' : 'w-klinik']" :title="`${m.nama}${m.guru ? ' · ' + m.guru : ''}`">
          {{ m.singkatan || m.nama }} {{ terisi(m) }}/{{ baris.length }}</span>
      </div>
      <div class="kartu overflow-auto">
        <table class="w-full text-sm">
          <thead class="sticky top-0 bg-permukaan2 text-xs text-teks2"><tr><th class="sticky left-0 bg-permukaan2 px-2 py-2 text-left">Nama</th>
            <th v-for="m in mapel" :key="m.id" class="px-1.5 text-center" :title="`${m.nama} · KKM ${m.kkm ?? '–'}${m.guru ? ' · ' + m.guru : ''}`">{{ m.singkatan || m.nama }}</th>
            <th class="px-2 text-center">Rata-rata</th></tr></thead>
          <tbody class="divide-y divide-garis">
            <tr v-for="s in baris" :key="s.id">
              <td class="sticky left-0 max-w-[200px] truncate bg-permukaan px-2 py-1.5 font-semibold">{{ nama(s) }}</td>
              <td v-for="m in mapel" :key="m.id" :class="['px-1.5 text-center tabular-nums', nilaiDari(s, m) != null && Number(nilaiDari(s, m)) < Number(m.kkm || 0) && 'persen-ambang']">{{ nilaiDari(s, m) ?? '–' }}</td>
              <td class="px-2 text-center font-bold tabular-nums">{{ s.rata == null ? '–' : String(s.rata).replace('.', ',') }}</td>
            </tr>
          </tbody>
        </table>
      </div>
      <p class="mt-2 text-xs text-teks3">Angka merah = di bawah KKM mapel. "–" = guru belum mengisi nilai. Lencana di atas menunjukkan jumlah santri yang sudah bernilai pada setiap mapel.</p>
      <DokumenCetak v-model:pratinjau="pratinjau" mendatar judul="Nilai Santri per Mata Pelajaran" :subjudul="`Kelas ${d.kelas?.nama} · Semester ${smt} · Tahun Ajaran ${d.ta?.nama || ''}`" :pencetak="sesi.pengguna?.nama_lengkap">
        <table class="tabel kecil">
          <thead><tr><th style="width: 4%">No.</th><th style="width: 9%">NIS</th><th>Nama</th><th v-for="m in mapel" :key="m.id">{{ m.singkatan || m.nama }}</th><th style="width: 7%">Rata-rata</th></tr></thead>
          <tbody>
            <tr v-for="(s, i) in baris" :key="s.id"><td class="tengah">{{ i + 1 }}</td><td>{{ s.nis }}</td><td>{{ nama(s) }}</td>
              <td v-for="m in mapel" :key="m.id" class="tengah">{{ nilaiDari(s, m) ?? '' }}</td><td class="tengah">{{ s.rata == null ? '' : String(s.rata).replace('.', ',') }}</td></tr>
            <tr><td colspan="3">KKM</td><td v-for="m in mapel" :key="m.id" class="tengah">{{ m.kkm ?? '' }}</td><td /></tr>
          </tbody>
        </table>
        <template #ttd><TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: direktur.jabatan_tertulis || 'Direktur', nama: direktur.nama || '', niy: direktur.niy }"
          :kanan="{ jabatan: `Wali Kelas ${d.kelas?.nama || ''}`, nama: wali.nama || '', niy: wali.niy }" /></template>
      </DokumenCetak>
    </template>
  </div>
</template>
