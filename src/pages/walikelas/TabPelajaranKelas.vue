<!-- SIMKA PRO | src/pages/walikelas/TabPelajaranKelas.vue | v1.7 | 14.30.0: label saringan yang sudah jelas disembunyikan (hemat ruang) | 29/10/2026 -->
<script setup>
// Pelajaran di satu kelas berdasarkan jurnal mengajar guru: rekap keterlaksanaan per mapel/guru, materi per tanggal,
// dan roster (jadwal pelajaran pekanan). Wali kelas dapat memantau mapel yang kosong; cetak F4 rekap keterlaksanaan.
// v1.5: "Jurnal pelajaran" — jurnal mengajar semua guru mapel di kelas ini (atau satu mapel), cetak F4 dan Excel;
//       "Nilai per mapel" — nilai rapor setiap santri dari guru mapel, kemajuan pengisian, di bawah KKM merah.
// v1.4: tampilan "Kehadiran per mapel" — kehadiran setiap santri pada setiap mata pelajaran (absensi guru mapel).
import { ref, computed, watch, onMounted } from 'vue'
import { PhListChecks, PhCalendarDots, PhGridFour, PhPrinter, PhUserCheck, PhNotebook, PhExam } from '@phosphor-icons/vue'
import LaporanJurnalMengajar from '@/components/LaporanJurnalMengajar.vue'
import NilaiKelasMapel from './NilaiKelasMapel.vue'
import RekapKehadiranMapel from '@/components/RekapKehadiranMapel.vue'
import { useWaliKelas } from '@/stores/waliKelas'
import { useJadwal } from '@/stores/jadwal'
import { useLembaga } from '@/stores/lembaga'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { teksPersen } from '@/lib/absensi'
import { awalPekan, awalBulanDari, akhirBulanDari, tambahHari, teksRentang } from '@/lib/musyrif'
import { STATUS_JP, statusSlot, rekapPenugasan, persenJP, warnaPersen } from '@/lib/guruMapel'
import { hariIniISO, formatHari } from '@/lib/tanggal'
import GridJadwal from '@/pages/jadwal/GridJadwal.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'

const wk = useWaliKelas(); const jd = useJadwal(); const lembaga = useLembaga(); const sesi = useSesi(); const ui = useUI(); const hari = hariIniISO()
const PERIODE = [{ k: 'pekan', n: 'Pekan ini', m: awalPekan(hari), s: hari }, { k: 'bulan', n: 'Bulan ini', m: awalBulanDari(hari), s: hari },
  { k: 'lalu', n: 'Bulan lalu', m: awalBulanDari(tambahHari(awalBulanDari(hari), -1)), s: akhirBulanDari(tambahHari(awalBulanDari(hari), -1)) }]
const periode = ref('bulan'); const tampilan = ref('rekap'); const slot = ref([]); const memuat = ref(false); const pratinjau = ref(false)
const p = computed(() => PERIODE.find((x) => x.k === periode.value))
async function muat() { memuat.value = true; try { slot.value = await jd.slot(p.value.m, p.value.s, wk.pilih) } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false } }
onMounted(() => { muat(); jd.muat(); lembaga.muat() })
watch(periode, muat)
const rekap = computed(() => rekapPenugasan(slot.value))
const total = computed(() => rekap.value.reduce((a, r) => ({ terjadwal: a.terjadwal + r.terjadwal, terlaksana: a.terlaksana + r.terlaksana, tidak: a.tidak + r.tidak, kosong: a.kosong + r.kosong }), { terjadwal: 0, terlaksana: 0, tidak: 0, kosong: 0 }))
const perTanggal = computed(() => { const m = {}; for (const s of slot.value) (m[s.tanggal] ||= []).push(s); return Object.entries(m).sort((a, b) => b[0].localeCompare(a[0])) })
const TAMPILAN = [{ k: 'rekap', n: 'Per mapel', ikon: PhListChecks }, { k: 'tanggal', n: 'Per tanggal', ikon: PhCalendarDots }, { k: 'jurnal', n: 'Jurnal pelajaran', ikon: PhNotebook }, { k: 'hadir', n: 'Kehadiran per mapel', ikon: PhUserCheck }, { k: 'nilai', n: 'Nilai per mapel', ikon: PhExam }, { k: 'roster', n: 'Jadwal pelajaran', ikon: PhGridFour }]
const waliKelas = computed(() => wk.kelasPilih?.wali?.[0] || {})
const mapelJurnal = ref('')
const tugasKelas = computed(() => jd.penugasan.filter((t) => t.group_id === wk.pilih))
watch(() => wk.pilih, () => { mapelJurnal.value = '' })
const direktur = computed(() => lembaga.signatories.find((s) => s.sumber_jabatan === 'DIREKTUR' || /^direktur/i.test(s.jabatan_tertulis)) || {})
</script>
<template>
  <div>
    <div class="mb-3 flex flex-wrap items-center gap-2">
      <div class="bilah-tab kecil" role="tablist" aria-label="Tampilan pelajaran">
        <button v-for="t in TAMPILAN" :key="t.k" type="button" role="tab" :aria-selected="tampilan === t.k" @click="tampilan = t.k"
          :class="['tab-garis', tampilan === t.k && 'aktif']"><component :is="t.ikon" :size="18" weight="duotone" /><span>{{ t.n }}</span></button>
      </div>
      <template v-if="!['roster', 'hadir', 'jurnal', 'nilai'].includes(tampilan)">
        <div class="bilah-tab kecil" role="tablist" aria-label="Periode"><button v-for="x in PERIODE" :key="x.k" :class="['tab-garis', periode === x.k && 'aktif']" type="button" role="tab" :aria-selected="periode === x.k" @click="periode = x.k">{{ x.n }}</button></div>
        <span class="text-xs text-teks3">{{ teksRentang(p.m, p.s) }}</span>
        <span class="flex-1" />
        <button class="tombol-garis min-h-[40px] px-3 text-sm" :disabled="!rekap.length" @click="pratinjau = true"><PhPrinter :size="18" weight="duotone" /> Cetak</button>
      </template>
    </div>

    <template v-if="tampilan === 'jurnal'">
      <div class="mb-3"><label class="label-isian sr-only" for="pk-mapel">Mata pelajaran</label>
        <select id="pk-mapel" v-model="mapelJurnal" class="isian md:max-w-md"><option value="">Semua mapel kelas ini</option>
          <option v-for="t in tugasKelas" :key="t.id" :value="t.id">{{ jd.cariMapel(t.subject_id)?.nama || 'Mapel' }} · {{ t.nama_guru }}</option></select></div>
      <LaporanJurnalMengajar :key="wk.pilih + mapelJurnal" :cakupan="mapelJurnal ? { assignment_id: mapelJurnal } : { group_id: wk.pilih }" :judul="mapelJurnal ? 'Jurnal Mengajar' : 'Jurnal Pelajaran Kelas'" :kanan="mapelJurnal ? 'guru' : 'wali'" />
    </template>
    <NilaiKelasMapel v-else-if="tampilan === 'nilai'" :group-id="wk.pilih" />
    <RekapKehadiranMapel v-else-if="tampilan === 'hadir'" :group-id="wk.pilih" :ttd-kanan="{ jabatan: `Wali Kelas ${wk.kelasPilih?.nama || ''}`, nama: waliKelas.nama || '', niy: waliKelas.niy }" />
    <div v-else-if="tampilan === 'roster'" class="kartu p-3">
      <GridJadwal v-if="jd.dimuat" mode="kelas" :group-id="wk.pilih" :jenjang="wk.kelasPilih?.jenjang || 'wustha'" />
      <p v-else class="p-6 text-center text-sm text-teks3">Memuat jadwal pelajaran…</p>
    </div>
    <p v-else-if="memuat && !slot.length" class="kartu p-8 text-center text-sm text-teks3">Memuat jurnal mengajar…</p>
    <p v-else-if="!slot.length" class="kartu p-8 text-center text-sm text-teks3">Belum ada jam pelajaran terjadwal untuk kelas ini pada periode tersebut. Jadwal diatur di menu Jadwal Pelajaran.</p>
    <template v-else-if="tampilan === 'rekap'">
      <p class="mb-2 text-sm text-teks2">Terlaksana <b>{{ total.terlaksana }}</b> dari {{ total.terjadwal }} JP ({{ teksPersen(persenJP(total.terlaksana, total.terjadwal)) }}) · tidak terlaksana {{ total.tidak }} · belum diisi {{ total.kosong }}</p>
      <ul class="grid gap-2 md:grid-cols-2">
        <li v-for="r in rekap" :key="r.assignment_id" class="kartu p-3.5" :class="'w-' + warnaPersen(r.persen)">
          <div class="flex items-start gap-2">
            <div class="min-w-0 flex-1"><p class="truncate font-bold">{{ r.mapel_nama }}</p><p class="truncate text-xs text-teks3">{{ r.guru }}</p></div>
            <span class="text-xl font-extrabold tabular-nums" style="color: var(--c)">{{ teksPersen(r.persen) }}</span>
          </div>
          <div class="mt-2 h-2 overflow-hidden rounded-full bg-permukaan2"><div class="h-full rounded-full" :style="{ width: (r.persen ?? 0) + '%', background: 'var(--c)' }" /></div>
          <p class="mt-1.5 text-xs text-teks3">Terlaksana {{ r.terlaksana }}/{{ r.terjadwal }} JP<template v-if="r.tidak"> · tidak terlaksana {{ r.tidak }}</template><template v-if="r.kosong"> · <b class="text-merah">belum diisi {{ r.kosong }}</b></template></p>
        </li>
      </ul>
    </template>
    <div v-else class="space-y-3">
      <section v-for="[tgl, isi] in perTanggal" :key="tgl" class="kartu p-3.5">
        <p class="mb-2 font-bold">{{ formatHari(tgl) }}</p>
        <ul class="divide-y divide-garis">
          <li v-for="s in isi" :key="s.period_id + s.assignment_id" class="flex flex-wrap items-center gap-x-3 gap-y-1 py-2 text-sm">
            <span class="w-24 shrink-0 tabular-nums text-teks2">{{ s.jam_mulai }}–{{ s.jam_selesai }}</span>
            <span class="min-w-0 flex-1"><b>{{ s.mapel }}</b> <span class="text-xs text-teks3">· {{ s.guru }}</span>
              <span v-if="s.materi || s.keterangan" class="block text-xs text-teks2">{{ s.materi || s.keterangan }}</span></span>
            <span class="lencana shrink-0" :class="'w-' + STATUS_JP[statusSlot(s)].w">{{ STATUS_JP[statusSlot(s)].n }}</span>
          </li>
        </ul>
      </section>
    </div>

    <DokumenCetak jenis="wk_pelajaran" :konteks="{ groupIds: [wk.pilih] }" v-model:pratinjau="pratinjau" :judul="`Rekap Keterlaksanaan Pelajaran Kelas ${wk.kelasPilih?.nama || ''}`" :subjudul="teksRentang(p.m, p.s)" :pencetak="sesi.pengguna?.nama_lengkap">
      <table class="tabel kecil">
        <colgroup><col style="width:5%"><col style="width:24%"><col style="width:27%"><col style="width:9%"><col style="width:9%"><col style="width:9%"><col style="width:8%"><col style="width:9%"></colgroup>
        <thead><tr><th>No.</th><th>Mata pelajaran</th><th>Guru</th><th>JP terjadwal</th><th>Terlaksana</th><th>Tidak terlaksana</th><th>Belum diisi</th><th>Keterlaksanaan</th></tr></thead>
        <tbody>
          <tr v-for="(r, i) in rekap" :key="r.assignment_id"><td class="tengah">{{ i + 1 }}</td><td>{{ r.mapel_nama }}</td><td>{{ r.guru }}</td><td class="tengah">{{ r.terjadwal }}</td>
            <td class="tengah">{{ r.terlaksana }}</td><td class="tengah">{{ r.tidak }}</td><td class="tengah">{{ r.kosong }}</td><td class="kanan">{{ teksPersen(r.persen) }}</td></tr>
          <tr><th colspan="3">Jumlah</th><th>{{ total.terjadwal }}</th><th>{{ total.terlaksana }}</th><th>{{ total.tidak }}</th><th>{{ total.kosong }}</th><th class="kanan">{{ teksPersen(persenJP(total.terlaksana, total.terjadwal)) }}</th></tr>
        </tbody>
      </table>
      <p class="mt-2 text-[8pt]">Berdasarkan jurnal mengajar yang diisi guru mapel. JP terjadwal hanya menghitung jam pelajaran yang sudah lewat.</p>
      <template #ttd><TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: direktur.jabatan_tertulis || 'Direktur', nama: direktur.nama || '', niy: direktur.niy }"
        :kanan="{ jabatan: `Wali Kelas ${wk.kelasPilih?.nama || ''}`, nama: waliKelas.nama || '', niy: waliKelas.niy }" /></template>
    </DokumenCetak>
  </div>
</template>
