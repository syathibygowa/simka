<!-- SIMKA PRO | src/pages/gurumapel/TabRekapGuru.vue | v1.3 | 14.15.0: penanda tangan dan kop dari Setelan → Penanda tangan | 19/10/2026 -->
<script setup>
// Rekap keterlaksanaan mengajar seorang guru untuk satu periode (paling lama 62 hari): per kelas-mapel dan daftar jurnal
// per tanggal (materi atau keterangan). Guru melihat dirinya; pemantau dapat memilih guru.
// Cetak F4 "Laporan Keterlaksanaan Mengajar" (Direktur mengetahui di kiri, guru di kanan).
import { ref, computed, onMounted, watch } from 'vue'
import { PhPrinter } from '@phosphor-icons/vue'
import { useJadwal } from '@/stores/jadwal'
import { useKelompokSantri } from '@/stores/kelompokSantri'
import { useLembaga } from '@/stores/lembaga'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { teksPersen } from '@/lib/absensi'
import { awalPekan, awalBulanDari, akhirBulanDari, tambahHari, teksRentang } from '@/lib/musyrif'
import { STATUS_JP, statusSlot, rekapPenugasan, persenJP, warnaPersen } from '@/lib/guruMapel'
import { hariIniISO, formatHari, formatPendek } from '@/lib/tanggal'
import InputTanggal from '@/components/InputTanggal.vue'
import SaringCorong from '@/components/SaringCorong.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'

const props = defineProps({ pemantau: Boolean, mengajar: Boolean })
const jd = useJadwal(); const kel = useKelompokSantri(); const lembaga = useLembaga(); const sesi = useSesi(); const ui = useUI(); const hari = hariIniISO()
const PERIODE = [{ k: 'pekan', n: 'Pekan ini', m: awalPekan(hari), s: hari }, { k: 'bulan', n: 'Bulan ini', m: awalBulanDari(hari), s: hari },
  { k: 'lalu', n: 'Bulan lalu', m: awalBulanDari(tambahHari(awalBulanDari(hari), -1)), s: akhirBulanDari(tambahHari(awalBulanDari(hari), -1)) }]
const mulai = ref(PERIODE[1].m); const selesai = ref(hari); const emp = ref(''); const slot = ref([]); const memuat = ref(false); const pratinjau = ref(false)
const guruList = computed(() => [...new Map(jd.penugasan.map((t) => [t.employee_id, { id: t.employee_id, nama: t.nama_guru, niy: t.niy_guru }])).values()].sort((a, b) => String(a.nama).localeCompare(String(b.nama), 'id')))
const guru = computed(() => guruList.value.find((g) => g.id === emp.value) || { nama: sesi.pengguna?.nama_lengkap, niy: sesi.pengguna?.niy })
onMounted(async () => { await Promise.all([kel.muat(), jd.muat(), lembaga.muat()]); emp.value = props.mengajar ? jd.idSaya() : guruList.value[0]?.id || '' })
async function muat() {
  if (!emp.value || !mulai.value || !selesai.value) return
  if (selesai.value < mulai.value) return ui.toast('Tanggal akhir sebelum tanggal awal.', 'galat')
  if ((new Date(selesai.value) - new Date(mulai.value)) / 864e5 > 61) return ui.toast('Rentang paling lama 62 hari.', 'galat')
  memuat.value = true
  try { slot.value = await jd.slot(mulai.value, selesai.value, null, emp.value) } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false }
}
watch([emp, mulai, selesai], muat)
const pilihCepat = (x) => { mulai.value = x.m; selesai.value = x.s }
const rekap = computed(() => rekapPenugasan(slot.value))
const total = computed(() => rekap.value.reduce((a, r) => ({ terjadwal: a.terjadwal + r.terjadwal, terlaksana: a.terlaksana + r.terlaksana, tidak: a.tidak + r.tidak, kosong: a.kosong + r.kosong }), { terjadwal: 0, terlaksana: 0, tidak: 0, kosong: 0 }))
const lewat = computed(() => slot.value.filter((s) => s.lewat).slice().reverse())
const direktur = computed(() => lembaga.signatories.find((s) => s.sumber_jabatan === 'DIREKTUR' || /^direktur/i.test(s.jabatan_tertulis)) || {})
</script>
<template>
  <div>
    <SaringCorong class="mb-3" :ringkasan="[pemantau ? guruList.find((g) => g.id === emp)?.nama : '', `${formatPendek(mulai)} – ${formatPendek(selesai)}`].filter(Boolean).join(' · ')" judul="Saring rekap mengajar">
      <div v-if="pemantau" class="min-w-[12rem] flex-1"><label class="label-isian" for="rg-guru">Guru</label>
        <select id="rg-guru" v-model="emp" class="isian"><option v-for="g in guruList" :key="g.id" :value="g.id">{{ g.nama }}</option></select></div>
      <p v-else class="self-center font-bold">{{ guru.nama }}</p>
      <div class="sm:w-40"><InputTanggal v-model="mulai" label="Dari" wajib /></div>
      <div class="sm:w-40"><InputTanggal v-model="selesai" label="Sampai" wajib /></div>
      <div class="bilah-tab kecil w-full" role="tablist" aria-label="Periode cepat">
        <button v-for="x in PERIODE" :key="x.k" type="button" role="tab" :aria-selected="mulai === x.m && selesai === x.s" :class="['tab-garis', mulai === x.m && selesai === x.s && 'aktif']" @click="pilihCepat(x)">{{ x.n }}</button>
      </div>
    </SaringCorong>
    <div class="mb-3 flex justify-end"><button class="tombol-utama" :disabled="!rekap.length" @click="pratinjau = true"><PhPrinter :size="20" weight="duotone" /> Cetak</button></div>
    <p class="mb-2 text-sm text-teks2">{{ teksRentang(mulai, selesai) }} · terlaksana <b>{{ total.terlaksana }}</b> dari {{ total.terjadwal }} JP ({{ teksPersen(persenJP(total.terlaksana, total.terjadwal)) }}) · tidak terlaksana {{ total.tidak }} · belum diisi {{ total.kosong }}</p>
    <p v-if="memuat && !slot.length" class="kartu p-8 text-center text-sm text-teks3">Memuat rekap…</p>
    <p v-else-if="!slot.length" class="kartu p-8 text-center text-sm text-teks3">Tidak ada jam pelajaran terjadwal pada periode ini.</p>
    <div v-else class="grid gap-4 lg:grid-cols-[1fr_1.2fr]">
      <ul class="space-y-2">
        <li v-for="r in rekap" :key="r.assignment_id" class="kartu p-3.5" :class="'w-' + warnaPersen(r.persen)">
          <div class="flex items-start gap-2">
            <div class="min-w-0 flex-1"><p class="truncate font-bold">{{ r.mapel_nama }}</p><p class="text-xs text-teks3">Kelas {{ r.kelas_nama }}</p></div>
            <span class="text-xl font-extrabold tabular-nums" style="color: var(--c)">{{ teksPersen(r.persen) }}</span></div>
          <div class="mt-2 h-2 overflow-hidden rounded-full bg-permukaan2"><div class="h-full rounded-full" :style="{ width: (r.persen ?? 0) + '%', background: 'var(--c)' }" /></div>
          <p class="mt-1.5 text-xs text-teks3">Terlaksana {{ r.terlaksana }}/{{ r.terjadwal }} JP<template v-if="r.tidak"> · tidak {{ r.tidak }}</template><template v-if="r.kosong"> · <b class="text-merah">belum diisi {{ r.kosong }}</b></template></p>
        </li>
      </ul>
      <section class="kartu p-3.5">
        <p class="judul-bagian mb-2">Jurnal per tanggal</p>
        <ul class="max-h-[32rem] divide-y divide-garis overflow-y-auto">
          <li v-for="s in lewat" :key="s.tanggal + s.period_id + s.assignment_id" class="flex flex-wrap items-center gap-x-3 gap-y-1 py-2 text-sm">
            <span class="w-24 shrink-0 tabular-nums text-teks3">{{ formatPendek(s.tanggal) }}<span class="block text-xs">{{ s.jam_mulai }}</span></span>
            <span class="min-w-0 flex-1"><b>{{ s.mapel }}</b> <span class="text-xs text-teks3">· {{ s.kelas }}</span><span v-if="s.materi || s.keterangan" class="block text-xs text-teks2">{{ s.materi || s.keterangan }}</span></span>
            <span class="lencana shrink-0" :class="'w-' + STATUS_JP[statusSlot(s)].w">{{ STATUS_JP[statusSlot(s)].n }}</span>
          </li>
        </ul>
      </section>
    </div>

    <DokumenCetak jenis="gm_rekap_guru" :konteks="{ groupIds: rekap.map((r) => jd.cariPenugasan(r.assignment_id)?.group_id).filter(Boolean) }" v-model:pratinjau="pratinjau" judul="Laporan Keterlaksanaan Mengajar" :subjudul="teksRentang(mulai, selesai)" :pencetak="sesi.pengguna?.nama_lengkap">
      <table class="tabel kecil" style="width: 70%; margin-bottom: 6pt">
        <colgroup><col style="width:30%"><col style="width:70%"></colgroup>
        <tbody><tr><td>Nama guru</td><td>{{ guru.nama }}</td></tr><tr><td>NIY</td><td>{{ guru.niy || '–' }}</td></tr>
          <tr><td>Keterlaksanaan</td><td>{{ total.terlaksana }} dari {{ total.terjadwal }} JP ({{ teksPersen(persenJP(total.terlaksana, total.terjadwal)) }})</td></tr></tbody>
      </table>
      <table class="tabel kecil">
        <colgroup><col style="width:5%"><col style="width:12%"><col style="width:33%"><col style="width:10%"><col style="width:10%"><col style="width:10%"><col style="width:10%"><col style="width:10%"></colgroup>
        <thead><tr><th>No.</th><th>Kelas</th><th>Mata pelajaran</th><th>JP terjadwal</th><th>Terlaksana</th><th>Tidak terlaksana</th><th>Belum diisi</th><th>Keterlaksanaan</th></tr></thead>
        <tbody><tr v-for="(r, i) in rekap" :key="r.assignment_id"><td class="tengah">{{ i + 1 }}</td><td>{{ r.kelas_nama }}</td><td>{{ r.mapel_nama }}</td><td class="tengah">{{ r.terjadwal }}</td>
          <td class="tengah">{{ r.terlaksana }}</td><td class="tengah">{{ r.tidak }}</td><td class="tengah">{{ r.kosong }}</td><td class="kanan">{{ teksPersen(r.persen) }}</td></tr>
          <tr><th colspan="3">Jumlah</th><th>{{ total.terjadwal }}</th><th>{{ total.terlaksana }}</th><th>{{ total.tidak }}</th><th>{{ total.kosong }}</th><th class="kanan">{{ teksPersen(persenJP(total.terlaksana, total.terjadwal)) }}</th></tr></tbody>
      </table>
      <p class="mt-3 font-bold" style="font-size: 9pt">Rincian jurnal mengajar</p>
      <table class="tabel kecil">
        <colgroup><col style="width:5%"><col style="width:20%"><col style="width:9%"><col style="width:20%"><col style="width:8%"><col style="width:38%"></colgroup>
        <thead><tr><th>No.</th><th>Hari, tanggal</th><th>Jam</th><th>Mata pelajaran</th><th>Kelas</th><th>Materi/keterangan</th></tr></thead>
        <tbody><tr v-for="(s, i) in slot.filter((x) => x.lewat)" :key="i"><td class="tengah">{{ i + 1 }}</td><td>{{ formatHari(s.tanggal) }}</td><td class="tengah">{{ s.jam_mulai }}</td><td>{{ s.mapel }}</td>
          <td class="tengah">{{ s.kelas }}</td><td>{{ s.status === 'terlaksana' ? s.materi : `${STATUS_JP[s.status].n}${s.keterangan ? ': ' + s.keterangan : ''}` }}</td></tr></tbody>
      </table>
      <template #ttd><TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: direktur.jabatan_tertulis || 'Direktur', nama: direktur.nama || '', niy: direktur.niy }" :kanan="{ jabatan: 'Guru Mata Pelajaran', nama: guru.nama || '', niy: guru.niy }" /></template>
    </DokumenCetak>
  </div>
</template>
