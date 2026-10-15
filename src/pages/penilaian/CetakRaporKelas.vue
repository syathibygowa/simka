<!-- SIMKA PRO | src/pages/penilaian/CetakRaporKelas.vue | v1.1 | Tahap C: identitas santri memuat pas foto dari biodata | 16/10/2026 -->
<script setup>
// Panel cetak rapor satu kelas (Wali Kelas → Rapor → Cetak): pemeriksaan kelengkapan, pilihan santri, dan dokumen:
//   sampul, identitas sekolah, identitas santri, rapor SMA/Wustha, rapor tahfizh, leger (cetak dan Excel),
//   laporan ketercapaian, lembar remidi, tanda terima rapor. Semua dokumen F4 dengan kop sesuai jenis rapor.
import { ref, computed } from 'vue'
import {
  PhBookOpen, PhIdentificationCard, PhBuildings, PhExam, PhBookOpenText, PhTable, PhChartBar, PhWrench, PhHandshake, PhFileXls, PhUsersThree, PhWarning, PhCheckCircle,
} from '@phosphor-icons/vue'
import { useRapor } from '@/stores/rapor'
import { useUI } from '@/stores/ui'
import { useSantri } from '@/stores/santri'
import { penandaTahfizh } from '@/lib/tahfizh'
import { hitungLeger, namaKelasRapor, kelasAkhir } from '@/lib/rapor'
import { LABEL_SEMESTER } from '@/lib/nilai'
import { eksporExcel } from '@/lib/excel'
import LembarBawah from '@/components/LembarBawah.vue'
import LembarRapor from '@/components/cetak/rapor/LembarRapor.vue'
import RaporSekolah from './cetak/RaporSekolah.vue'
import SampulRapor from './cetak/SampulRapor.vue'
import LegerRapor from './cetak/LegerRapor.vue'
import LembarKelasRapor from './cetak/LembarKelasRapor.vue'
import RaporTahfizh from './cetak/RaporTahfizh.vue'

const props = defineProps({ D: { type: Object, required: true } })
const rp = useRapor(); const ui = useUI()
const sma = computed(() => props.D.kelas.jenjang === 'sma')
const leger = computed(() => hitungLeger(props.D))

// ---------- Pilihan santri ----------
const pilih = ref(null) // null = semua
const lembarPilih = ref(false); const sementara = ref(new Set())
function bukaPilih() { sementara.value = new Set(pilih.value || props.D.santri.map((s) => s.id)); lembarPilih.value = true }
function terapPilih() { pilih.value = sementara.value.size === props.D.santri.length ? null : [...sementara.value]; lembarPilih.value = false }
const tog = (id) => { const s = new Set(sementara.value); s.has(id) ? s.delete(id) : s.add(id); sementara.value = s }
const jumlahPilih = computed(() => (pilih.value ? pilih.value.length : props.D.santri.length))

// ---------- Kelengkapan ----------
const periksa = computed(() => {
  const D = props.D; const n = D.santri.length; const hasil = []
  const kosongMapel = D.mapel.map((m, i) => ({ m, k: leger.value.filter((b) => b.n[i]?.nilai == null).length })).filter((x) => x.k)
  for (const x of kosongMapel) hasil.push({ ok: false, t: `${x.m.nama}: ${x.k} santri belum bernilai${x.m.sumber === 'manual' ? ' (diisi wali kelas)' : x.m.sumber === 'tahfizh' ? ' (UTAS)' : ''}` })
  const cat = D.santri.filter((s) => !s.catatan).length; hasil.push({ ok: !cat, t: cat ? `${cat} santri belum ada catatan wali kelas` : 'Catatan wali kelas lengkap' })
  if (D.ketentuan?.pakai_kokurikuler) { const k = D.santri.filter((s) => !Object.keys(s.kokurikuler?.dimensi || {}).length).length; hasil.push({ ok: !k, t: k ? `${k} santri belum dinilai kokurikuler` : 'Kokurikuler lengkap' }) }
  const pd = D.santri.filter((s) => !(s.pd || []).length).length; if (pd) hasil.push({ ok: false, t: `${pd} santri tanpa nilai pengembangan diri (ekskul)` })
  if (Number(D.semester) === 2) { const k = D.santri.filter((s) => !s.keputusan).length; hasil.push({ ok: !k, t: k ? `${k} santri belum ditetapkan ${kelasAkhir(D.kelas.tingkat) ? 'kelulusannya' : 'kenaikan kelasnya'}` : 'Keputusan akhir tahun lengkap' }) }
  if (!D.penanda?.nama) hasil.push({ ok: false, t: 'Penanda tangan kepala belum dipilih (Penilaian → Ketentuan)' })
  if (!n) hasil.push({ ok: false, t: 'Kelas belum beranggota' })
  return hasil
})
const kurang = computed(() => periksa.value.filter((x) => !x.ok))

// ---------- Dokumen ----------
const DOKUMEN = computed(() => [
  { k: 'rapor', n: `Rapor ${sma.value ? 'SMA' : 'Wustha'}`, ket: 'Nilai, capaian, pengembangan diri, kehadiran, catatan', ikon: PhExam, w: 'rapor', per: true },
  { k: 'tahfizh', n: 'Rapor tahfizh', ket: 'Capaian bulanan, ujian kenaikan juz, UTAS, kehadiran halaqah', ikon: PhBookOpenText, w: 'tahfizh', per: true },
  { k: 'sampul', n: 'Sampul rapor', ket: 'Halaman depan per santri', ikon: PhBookOpen, w: 'pengumuman', per: true },
  { k: 'sekolah', n: 'Identitas sekolah', ket: 'Satu halaman', ikon: PhBuildings, w: 'tatausaha' },
  { k: 'santri', n: 'Identitas santri', ket: 'Biodata, orang tua, wali, pas foto', ikon: PhIdentificationCard, w: 'santri', per: true },
  { k: 'leger', n: 'Leger nilai', ket: 'F4 mendatar; jumlah, rata-rata, peringkat, sikap, absen', ikon: PhTable, w: 'gurumapel', excel: true },
  { k: 'ketercapaian', n: 'Laporan ketercapaian', ket: 'Rata-rata kelas terhadap KKM per mapel', ikon: PhChartBar, w: 'laporan' },
  { k: 'remidi', n: 'Lembar remidi', ket: `${leger.value.filter((b) => b.bawah.length).length} santri bernilai di bawah ${props.D.ketentuan?.label_ambang || 'KKM'}`, ikon: PhWrench, w: 'klinik', per: true },
  { k: 'terima', n: 'Tanda terima rapor', ket: 'Tanggal dan tanda tangan orang tua', ikon: PhHandshake, w: 'agenda' },
])
const jenis = ref(''); const pratinjau = ref(false); const T = ref(null); const proses = ref(''); const kepalaTz = ref(null)
const judul = computed(() => DOKUMEN.value.find((d) => d.k === jenis.value)?.n || '')
async function cetak(d) {
  if (d.k === 'tahfizh') {
    proses.value = 'tahfizh'
    try { T.value = await rp.dataRaporTahfizh(props.D.kelas.group_id, props.D.semester); if (!T.value.penanda?.nama) kepalaTz.value = await penandaTahfizh().catch(() => null) }
    catch (e) { proses.value = ''; return ui.toast(e.message, 'galat') }
    proses.value = ''
  }
  if (d.k === 'santri') {
    // Pas foto santri dari biodata (dimuat bertahap agar ringan)
    proses.value = 'santri'; const san = useSantri(); const peta = {}
    const daftar = props.D.santri.filter((s) => s.foto_id && (!pilih.value || pilih.value.includes(s.id)))
    for (let i = 0; i < daftar.length; i += 8) await Promise.all(daftar.slice(i, i + 8).map(async (s) => { peta[s.id] = await san.urlFoto({ id: s.id, foto_id: s.foto_id }) }))
    foto.value = peta; proses.value = ''
  }
  jenis.value = d.k; pratinjau.value = true
}
const foto = ref({})
function excel() {
  const D = props.D; const L = leger.value
  const kolom = [{ judul: 'No', kunci: 'no' }, { judul: 'NIS', kunci: 'nis' }, { judul: 'Nama', kunci: 'nama' }, { judul: 'JK', kunci: 'jk' },
    ...D.mapel.map((m, i) => ({ judul: m.singkatan || m.nama, kunci: `m${i}` })), { judul: 'Jumlah', kunci: 'jumlah' }, { judul: 'Rata-rata', kunci: 'rata' },
    { judul: 'Peringkat', kunci: 'peringkat' }, { judul: 'Sikap', kunci: 'sikap' }, { judul: 'Sakit', kunci: 's' }, { judul: 'Izin', kunci: 'i' }, { judul: 'Tanpa keterangan', kunci: 'a' }]
  const baris = L.map((b, i) => ({ no: i + 1, nis: b.s.nis, nama: b.s.nama, jk: b.s.jenis_kelamin, ...Object.fromEntries(b.n.map((x, j) => [`m${j}`, x.nilai ?? ''])),
    jumlah: b.jumlah, rata: b.rata ?? '', peringkat: b.peringkat ?? '', sikap: b.sikap, s: b.s.kehadiran?.sakit ?? 0, i: b.s.kehadiran?.izin ?? 0, a: b.s.kehadiran?.absen ?? 0 }))
  eksporExcel(`Leger ${namaKelasRapor(D.kelas)} smt ${D.semester} ${D.ta.nama.replace('/', '-')}.xlsx`, kolom, baris, `Leger ${D.kelas.nama}`)
}
</script>
<template>
  <div class="space-y-4">
    <section class="kartu p-4">
      <div class="flex flex-wrap items-center gap-2">
        <p class="min-w-[180px] flex-1 font-bold">Kelengkapan rapor {{ namaKelasRapor(D.kelas) }} · {{ LABEL_SEMESTER[D.semester] }}</p>
        <span :class="['lencana', kurang.length ? 'w-pengajuan' : 'w-presensi']">{{ kurang.length ? `${kurang.length} perlu dilengkapi` : 'Siap dicetak' }}</span>
      </div>
      <ul class="mt-2 grid gap-1 text-sm md:grid-cols-2">
        <li v-for="(x, i) in periksa" :key="i" class="flex items-start gap-2"><component :is="x.ok ? PhCheckCircle : PhWarning" :size="18" :weight="x.ok ? 'fill' : 'duotone'"
          :class="['mt-0.5 shrink-0', x.ok ? 'text-[#1E7D4F] dark:text-[#6EE7B7]' : 'text-[#B45309] dark:text-[#FCD34D]']" /><span :class="x.ok ? 'text-teks2' : ''">{{ x.t }}</span></li>
      </ul>
      <p class="mt-2 text-xs text-teks3">Rapor tetap dapat dicetak walau belum lengkap; isian kosong tercetak kosong.</p>
    </section>

    <div class="kartu flex flex-wrap items-center gap-2 p-3 text-sm">
      <PhUsersThree :size="20" weight="duotone" class="text-teks3" />
      <p class="flex-1">Dokumen per santri dicetak untuk <b>{{ pilih ? `${jumlahPilih} santri terpilih` : `semua santri (${D.santri.length})` }}</b>.</p>
      <button class="tombol-garis min-h-[40px] px-3 text-sm" @click="bukaPilih">Pilih santri</button>
      <button v-if="pilih" class="tombol-garis min-h-[40px] px-3 text-sm" @click="pilih = null">Semua</button>
    </div>

    <ul class="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
      <li v-for="d in DOKUMEN" :key="d.k" :class="['kartu flex flex-col gap-2 p-4', 'w-' + d.w]">
        <div class="flex items-start gap-3">
          <span class="chip-ikon h-11 w-11 shrink-0"><component :is="d.ikon" :size="24" weight="duotone" /></span>
          <div class="min-w-0 flex-1"><p class="font-bold">{{ d.n }}</p><p class="text-xs text-teks3">{{ d.ket }}{{ d.per && pilih ? ` · ${jumlahPilih} santri` : '' }}</p></div>
        </div>
        <div class="mt-auto flex gap-2">
          <button class="tombol-utama min-h-[40px] flex-1 px-3 text-sm" :disabled="!!proses || !D.santri.length" @click="cetak(d)">{{ proses === d.k ? 'Memuat…' : 'Pratinjau dan cetak' }}</button>
          <button v-if="d.excel" class="tombol-garis min-h-[40px] px-3 text-sm" :disabled="!D.santri.length" aria-label="Unduh Excel leger" @click="excel"><PhFileXls :size="18" weight="duotone" /> Excel</button>
        </div>
      </li>
    </ul>

    <LembarBawah v-model="lembarPilih" :judul="`Pilih santri · ${sementara.size} dipilih`">
      <div class="space-y-3 pb-2">
        <div class="flex gap-2"><button class="tombol-garis min-h-[38px] flex-1 text-sm" @click="sementara = new Set(D.santri.map((s) => s.id))">Pilih semua</button>
          <button class="tombol-garis min-h-[38px] flex-1 text-sm" @click="sementara = new Set()">Kosongkan</button></div>
        <ul class="max-h-[50dvh] divide-y divide-garis overflow-y-auto rounded-xl border border-garis">
          <li v-for="s in D.santri" :key="s.id"><label class="flex min-h-[48px] items-center gap-3 px-3 text-sm">
            <input type="checkbox" class="h-5 w-5" :checked="sementara.has(s.id)" @change="tog(s.id)" /><span class="flex-1"><b>{{ s.nama }}</b> <span class="text-xs text-teks3">{{ s.nis }} · {{ s.jenis_kelamin }}</span></span></label></li>
        </ul>
        <button class="tombol-utama w-full" :disabled="!sementara.size" @click="terapPilih">Terapkan</button>
      </div>
    </LembarBawah>

    <LembarRapor v-model:pratinjau="pratinjau" :judul="`${judul} · ${namaKelasRapor(D.kelas)}`" :keterangan="LABEL_SEMESTER[D.semester]" :mendatar="jenis === 'leger'">
      <RaporSekolah v-if="jenis === 'rapor'" :D="D" :pilih="pilih" />
      <SampulRapor v-else-if="['sampul', 'sekolah', 'santri'].includes(jenis)" :D="D" :mode="jenis" :pilih="pilih" :foto="foto" />
      <LegerRapor v-else-if="['leger', 'ketercapaian'].includes(jenis)" :D="D" :mode="jenis" />
      <LembarKelasRapor v-else-if="['remidi', 'terima'].includes(jenis)" :D="D" :mode="jenis" :pilih="pilih" />
      <RaporTahfizh v-else-if="jenis === 'tahfizh' && T" :D="T" :pilih="pilih" :penanda="kepalaTz" />
    </LembarRapor>
  </div>
</template>
