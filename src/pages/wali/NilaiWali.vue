<!-- SIMKA PRO | src/pages/wali/NilaiWali.vue | v1.1 | Fase 9 – Tahap 13.4.0 Unduh PDF ringkasan nilai semester | 15/10/2026 -->
<script setup>
// Nilai rapor anak per mapel untuk periode penilaian yang SUDAH DITUTUP (server tidak mengirim periode yang masih berjalan).
// Menampilkan nilai, predikat, ketuntasan terhadap KKM/KKTP, deskripsi, kehadiran rapor (hari), pengembangan diri,
// catatan wali kelas, dan keputusan akhir tahun (semester 2). Rapor resmi tetap dibagikan sekolah (bertanda tangan basah).
import { computed, ref, watch } from 'vue'
import { PhChartBar, PhChatCenteredText, PhCalendarCheck, PhTarget, PhSealCheck, PhInfo, PhFilePdf } from '@phosphor-icons/vue'
import CetakWali from './CetakWali.vue'
import { usePortalWali } from '@/stores/portalWali'
import { SEMESTER_RAPOR, KEPUTUSAN, teksKeputusan, persenHadir } from '@/lib/rapor'
import { formatPanjang } from '@/lib/tanggal'

defineOptions({ inheritAttrs: false })
const pw = usePortalWali()
const pilih = ref(''); const cetak = ref(false); const d = ref(null); const memuat = ref(false); const galat = ref('')
async function muat() {
  memuat.value = true; galat.value = ''
  const [group, semester] = pilih.value ? pilih.value.split('|') : []
  try { d.value = await pw.ambil('nilai', group ? { group, semester } : {}); if (d.value?.group) pilih.value = `${d.value.group}|${d.value.semester}` }
  catch (e) { galat.value = e.message } finally { memuat.value = false }
}
watch(() => pw.aktif?.nis, () => { pilih.value = ''; muat() }, { immediate: true })
function ganti(e) { pilih.value = e.target.value; muat() }

const angka = (n) => (n == null ? '–' : Number(n).toLocaleString('id-ID', { maximumFractionDigits: 0 }))
const mapel = computed(() => d.value?.mapel || [])
const terisi = computed(() => mapel.value.filter((m) => m.nilai != null))
const rata = computed(() => (terisi.value.length ? terisi.value.reduce((a, m) => a + Number(m.nilai), 0) / terisi.value.length : null))
const kelompok = computed(() => {
  const peta = new Map()
  for (const m of mapel.value) { const k = m.kelompok || ''; if (!peta.has(k)) peta.set(k, []); peta.get(k).push(m) }
  return [...peta.entries()]
})
const hadir = computed(() => d.value?.kehadiran)
</script>

<template>
  <div class="space-y-4">
    <p v-if="galat" class="kartu p-4 text-sm font-semibold text-merah" role="alert">{{ galat }}</p>
    <div v-if="memuat && !d" class="kartu h-40 animate-pulse" aria-busy="true" />
    <p v-if="d?.nonaktif" class="kartu p-6 text-center text-teks3">Informasi ini tidak ditampilkan oleh pondok.</p>
    <div v-else-if="d?.kosong" class="kartu w-penilaian flex gap-3 p-5">
      <span class="chip-ikon h-10 w-10"><PhInfo :size="22" weight="duotone" /></span>
      <p class="text-sm text-teks2">Nilai rapor tampil setelah periode penilaian semester ditutup oleh pengelola nilai. Saat ini belum ada periode yang ditutup.</p>
    </div>

    <template v-if="d?.mapel">
      <div v-if="d.pilihan?.length > 1">
        <label for="nw-per" class="label-isian">Periode rapor</label>
        <select id="nw-per" class="isian" :value="pilih" @change="ganti">
          <option v-for="o in d.pilihan" :key="o.group + o.semester" :value="`${o.group}|${o.semester}`">Kelas {{ o.kelas }} · {{ o.ta }} · Semester {{ SEMESTER_RAPOR[o.semester] }}</option>
        </select>
      </div>

      <div class="flex justify-end"><button type="button" class="tombol-garis min-h-[40px] px-3.5 text-sm" @click="cetak = true"><PhFilePdf :size="18" weight="duotone" /> Unduh PDF</button></div>
      <section class="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <div class="kartu w-penilaian p-3.5"><p class="text-xs text-teks3">Rata-rata nilai</p><p class="text-2xl font-extrabold tabular-nums">{{ rata == null ? '–' : rata.toLocaleString('id-ID', { maximumFractionDigits: 1 }) }}</p>
          <p class="text-xs text-teks3">{{ terisi.length }} dari {{ mapel.length }} mapel</p></div>
        <div class="kartu w-presensi p-3.5"><p class="text-xs text-teks3">Tuntas {{ d.label_ambang }}</p><p class="text-2xl font-extrabold tabular-nums">{{ terisi.filter((m) => m.tuntas).length }}</p>
          <p class="text-xs text-teks3">mapel</p></div>
        <div class="kartu w-walikelas p-3.5"><p class="text-xs text-teks3">Kehadiran</p><p class="text-2xl font-extrabold tabular-nums">{{ persenHadir(hadir) == null ? '–' : persenHadir(hadir) + '%' }}</p>
          <p class="text-xs text-teks3">{{ hadir ? `${hadir.hadir} dari ${hadir.hari} hari` : 'belum ada data' }}</p></div>
        <div class="kartu w-rapor p-3.5"><p class="text-xs text-teks3">Kelas</p><p class="text-2xl font-extrabold">{{ d.kelas }}</p>
          <p class="text-xs text-teks3">{{ d.ta }} · Smt {{ d.semester }}</p></div>
      </section>

      <!-- Keputusan -->
      <section v-if="d.keputusan?.keputusan" :class="['kartu flex items-center gap-3 p-4', 'w-' + (KEPUTUSAN[d.keputusan.keputusan]?.w || 'presensi')]">
        <span class="chip-ikon h-10 w-10"><PhSealCheck :size="22" weight="duotone" /></span>
        <div><p class="text-sm text-teks3">Keputusan akhir tahun</p><p class="text-lg font-extrabold">{{ teksKeputusan(d.keputusan, d.tingkat) }}</p></div>
      </section>

      <!-- Nilai per mapel -->
      <section class="kartu w-penilaian p-4 sm:p-5">
        <div class="flex items-center gap-3">
          <span class="chip-ikon h-10 w-10"><PhChartBar :size="22" weight="duotone" /></span>
          <div><h2 class="judul-bagian">Nilai per mata pelajaran</h2>
            <p class="text-sm text-teks3">Semester {{ SEMESTER_RAPOR[d.semester] }}<template v-if="d.tanggal_rapor"> · rapor {{ formatPanjang(d.tanggal_rapor) }}</template></p></div>
        </div>
        <template v-for="[k, daftar] in kelompok" :key="k">
          <p v-if="k" class="mt-4 text-xs font-bold uppercase tracking-wide text-teks3">{{ k }}</p>
          <ul class="mt-2 divide-y divide-garis/70">
            <li v-for="m in daftar" :key="m.nama" class="py-2.5">
              <div class="flex items-center gap-3">
                <p class="min-w-0 flex-1 font-semibold">{{ m.nama }}</p>
                <span class="text-xs text-teks3">{{ d.label_ambang }} {{ angka(m.kkm) }}</span>
                <span :class="['grid h-10 w-12 shrink-0 place-items-center rounded-xl text-lg font-extrabold tabular-nums', m.nilai == null ? 'bg-permukaan2 text-teks3' : m.tuntas ? 'nilai-tuntas' : 'nilai-belum']">{{ angka(m.nilai) }}</span>
                <span class="w-6 shrink-0 text-center font-bold">{{ m.predikat || '' }}</span>
              </div>
              <p v-if="m.deskripsi" class="mt-1 text-sm text-teks2">{{ m.deskripsi }}</p>
            </li>
          </ul>
        </template>
      </section>

      <section v-if="d.pd?.length" class="kartu w-ekskul p-4 sm:p-5">
        <div class="flex items-center gap-3"><span class="chip-ikon h-10 w-10"><PhTarget :size="22" weight="duotone" /></span><h2 class="judul-bagian">Pengembangan diri</h2></div>
        <ul class="mt-2 divide-y divide-garis/70">
          <li v-for="x in d.pd" :key="x.kegiatan" class="py-2.5"><p class="flex justify-between gap-2 font-semibold"><span>{{ x.kegiatan }}</span><span>{{ x.nilai }}</span></p>
            <p v-if="x.deskripsi" class="text-sm text-teks2">{{ x.deskripsi }}</p></li>
        </ul>
      </section>

      <section v-if="hadir" class="kartu w-walikelas p-4 sm:p-5">
        <div class="flex items-center gap-3"><span class="chip-ikon h-10 w-10"><PhCalendarCheck :size="22" weight="duotone" /></span><h2 class="judul-bagian">Kehadiran di rapor</h2></div>
        <p class="mt-2 text-sm text-teks2">Hadir {{ hadir.hadir }} hari dari {{ hadir.hari }} hari · Sakit {{ hadir.sakit }} · Izin {{ hadir.izin }} · Tanpa keterangan {{ hadir.absen }}</p>
      </section>

      <section v-if="d.catatan" class="kartu w-pengumuman p-4 sm:p-5">
        <div class="flex items-center gap-3"><span class="chip-ikon h-10 w-10"><PhChatCenteredText :size="22" weight="duotone" /></span><h2 class="judul-bagian">Catatan wali kelas</h2></div>
        <p class="mt-2 text-sm text-teks2">{{ d.catatan }}</p>
      </section>
      <p class="px-1 text-xs text-teks3">Rapor resmi bertanda tangan dibagikan langsung oleh wali kelas. Nilai di portal ini sama dengan nilai di rapor.</p>
    </template>
    <CetakWali v-if="d?.mapel" jenis="nilai" :data="d" v-model:pratinjau="cetak" />
  </div>
</template>
<style scoped>
.nilai-tuntas { background: color-mix(in srgb, #1E7D4F 16%, rgb(var(--permukaan))); color: rgb(var(--teks)); }
.nilai-belum { background: color-mix(in srgb, #C7332F 16%, rgb(var(--permukaan))); color: rgb(var(--teks)); }
</style>
