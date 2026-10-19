<!-- SIMKA PRO | src/pages/jadwal/TabRekapMengajar.vue | v1.5 | 14.15.0: penanda tangan dan kop dari Setelan → Penanda tangan | 19/10/2026 -->
<script setup>
// Rekap mengajar per guru dan penugasan: JP terjadwal (hari sekolah, di luar libur), terlaksana, tidak terlaksana,
// belum diisi. Jurnal mengajar menjadi bukti kehadiran mengajar dan dasar tunjangan guru (Fase 11).
// v1.3: cakupan cetak/Excel — semua guru (kolektif), per bidang (unit kerja guru beserta cabangnya), atau per guru;
//       pilihan "satu halaman per guru" mencetak laporan individu setiap guru sekaligus (tanda tangan pimpinan dan guru).
import { ref, computed, onMounted, watch } from 'vue'
import * as XLSX from 'xlsx'
import { PhDownloadSimple, PhEye } from '@phosphor-icons/vue'
import { useJadwal } from '@/stores/jadwal'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { persen, teksPersen } from '@/lib/absensi'
import { hariIniISO, formatPanjang, formatPendek } from '@/lib/tanggal'
import { ambilPenandaTangan } from '@/lib/penandatangan'
import InputTanggal from '@/components/InputTanggal.vue'
import SaringCorong from '@/components/SaringCorong.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'
import SubTabJenjang from '@/components/SubTabJenjang.vue'
import { useKelompokSantri } from '@/stores/kelompokSantri'
import { usePegawai } from '@/stores/pegawai'
import { useOrganisasi } from '@/stores/organisasi'
import { JENJANG_TAB, warnaJenjang } from '@/lib/jadwal'

const jd = useJadwal(); const sesi = useSesi(); const ui = useUI(); const kel = useKelompokSantri(); const peg = usePegawai(); const org = useOrganisasi()
// 14.4.0: cakupan cetak
const cakupan = ref('semua'); const bidang = ref(''); const guruPilih = ref(''); const perHalaman = ref(false)
const daftarBidang = computed(() => org.units.filter((u) => u.jenis === 'bidang' && u.aktif !== false))
const unitGuru = (id) => peg.daftar.find((p) => p.id === id)?.org_unit_id
const masukCakupan = (r) => cakupan.value === 'semua' || (cakupan.value === 'guru' ? r.employee_id === guruPilih.value : bidang.value && org.turunan(bidang.value).includes(unitGuru(r.employee_id)))
const namaCakupan = computed(() => (cakupan.value === 'guru' ? perGuruSemua.value.find((g) => g.employee_id === guruPilih.value)?.guru || '' : cakupan.value === 'bidang' ? org.units.find((u) => u.id === bidang.value)?.nama || '' : 'Semua guru'))
// Saring jenjang: jenjang kelas dari penugasan
const jenjang = ref('')
const jenjangBaris = (r) => kel.cari(jd.cariPenugasan(r.assignment_id)?.group_id)?.jenjang || ''
const barisJ = computed(() => baris.value.filter((r) => (!jenjang.value || jenjangBaris(r) === jenjang.value) && masukCakupan(r)))
const jumlahJ = computed(() => ({ '': baris.value.length, wustha: baris.value.filter((r) => jenjangBaris(r) === 'wustha').length, sma: baris.value.filter((r) => jenjangBaris(r) === 'sma').length }))
const mulai = ref(hariIniISO().slice(0, 8) + '01'); const selesai = ref(hariIniISO()); const baris = ref([]); const pratinjau = ref(false); const cari = ref('')
const pimpinan = ref({ jabatan: 'Direktur', nama: '', niy: '' })
const jumlahSaring = computed(() => [cakupan.value !== 'semua', perHalaman.value].filter(Boolean).length)
const ringkasSaring = computed(() => [`${formatPendek(mulai.value)} – ${formatPendek(selesai.value)}`, cakupan.value === 'bidang' ? 'Per bidang' : cakupan.value === 'guru' ? 'Per guru' : 'Kolektif'].join(' · '))
async function muat() { try { baris.value = await jd.rekap(mulai.value, selesai.value) } catch (e) { ui.toast(e.message, 'galat') } }
onMounted(async () => { await muat(); pimpinan.value = await ambilPenandaTangan('Direktur'); peg.muat().catch(() => null); org.muat().catch(() => null) })
watch([mulai, selesai], muat)
const kelompokkan = (rows) => {
  const peta = new Map()
  for (const r of rows.filter((x) => !cari.value.trim() || x.guru?.toLowerCase().includes(cari.value.toLowerCase().trim()))) {
    const g = peta.get(r.employee_id) || { employee_id: r.employee_id, guru: r.guru, niy: r.niy, rinci: [], jp_terjadwal: 0, jp_terlaksana: 0, jp_tidak: 0, jp_kosong: 0 }
    g.rinci.push(r); for (const k of ['jp_terjadwal', 'jp_terlaksana', 'jp_tidak', 'jp_kosong']) g[k] += r[k]
    peta.set(r.employee_id, g)
  }
  return [...peta.values()]
}
const perGuru = computed(() => kelompokkan(barisJ.value))
const perGuruSemua = computed(() => kelompokkan(baris.value))
watch(perGuruSemua, (x) => { if (!guruPilih.value && x.length) guruPilih.value = x[0].employee_id })
const teksPeriode = computed(() => `${cakupan.value !== 'semua' ? namaCakupan.value + ' · ' : ''}${formatPanjang(mulai.value)} s.d. ${formatPanjang(selesai.value)}${jenjang.value ? ' · ' + JENJANG_TAB[jenjang.value].n : ''}`)
function ekspor() {
  const k = ['NIY', 'Guru', 'Kelas', 'Mapel', 'JP/pekan', 'JP terjadwal', 'Terlaksana', 'Tidak terlaksana', 'Belum diisi', 'Keterlaksanaan (%)']
  const isi = barisJ.value.map((r) => [r.niy || '', r.guru, r.kelas, r.mapel, r.jp_pekan, r.jp_terjadwal, r.jp_terlaksana, r.jp_tidak, r.jp_kosong, persen(r.jp_terlaksana, r.jp_terjadwal) ?? ''])
  const ws = XLSX.utils.aoa_to_sheet([[`Rekap mengajar ${teksPeriode.value}`], [], k, ...isi]); ws['!cols'] = k.map((x, i) => ({ wch: i === 1 ? 30 : Math.max(10, x.length + 2) }))
  const wb = XLSX.utils.book_new(); XLSX.utils.book_append_sheet(wb, ws, 'Rekap mengajar')
  XLSX.writeFile(wb, `Rekap-Mengajar-${namaCakupan.value.replace(/[^A-Za-z0-9]+/g, '-')}-${formatPendek(mulai.value).replace(/\//g, '')}-${formatPendek(selesai.value).replace(/\//g, '')}.xlsx`)
}
</script>
<template>
  <div>
    <SubTabJenjang v-model="jenjang" class="mb-3" :jumlah="jumlahJ" label="Saring jenjang rekap" />
    <SaringCorong class="mb-4" :jumlah="jumlahSaring" :ringkasan="ringkasSaring" judul="Saring rekap mengajar">
      <template #cari><input id="rm-c" v-model="cari" type="search" class="isian" placeholder="Cari nama guru" aria-label="Cari guru" /></template>
      <div class="sm:w-44"><InputTanggal v-model="mulai" label="Dari" wajib /></div>
      <div class="sm:w-44"><InputTanggal v-model="selesai" label="Sampai" wajib /></div>
      <div><label class="label-isian" for="rm-ck">Cakupan cetak/unduh</label>
        <select id="rm-ck" v-model="cakupan" class="isian w-auto max-w-full"><option value="semua">Semua guru (kolektif)</option><option value="bidang">Per bidang</option><option value="guru">Per guru</option></select></div>
      <div v-if="cakupan === 'bidang'"><label class="label-isian" for="rm-bd">Bidang</label>
        <select id="rm-bd" v-model="bidang" class="isian"><option value="" disabled>Pilih bidang</option><option v-for="b in daftarBidang" :key="b.id" :value="b.id">{{ b.nama }}</option></select></div>
      <div v-if="cakupan === 'guru'"><label class="label-isian" for="rm-gr">Guru</label>
        <select id="rm-gr" v-model="guruPilih" class="isian"><option v-for="g in perGuruSemua" :key="g.employee_id" :value="g.employee_id">{{ g.guru }}</option></select></div>
      <label v-if="cakupan !== 'guru'" class="flex min-h-[46px] items-center gap-2 self-end text-sm"><input v-model="perHalaman" type="checkbox" class="h-5 w-5" /> Cetak satu halaman per guru</label>
    </SaringCorong>
    <div class="-mx-4 mb-4 flex gap-2 overflow-x-auto px-4 pb-1 lg:mx-0 lg:px-0">
      <button class="w-santri tombol-garis shrink-0 px-4 text-sm" @click="ekspor"><PhDownloadSimple :size="20" weight="duotone" style="color: var(--c)" /> Ekspor</button>
      <button class="w-pengajuan tombol-garis shrink-0 px-4 text-sm" @click="pratinjau = true"><PhEye :size="20" weight="duotone" style="color: var(--c)" /> Cetak Rekap</button>
    </div>
    <ul class="space-y-3">
      <li v-for="g in perGuru" :key="g.employee_id" class="kartu w-jadwal p-4">
        <div class="flex flex-wrap items-center gap-2">
          <p class="flex-1 font-bold">{{ g.guru }}</p>
          <span class="lencana">{{ teksPersen(persen(g.jp_terlaksana, g.jp_terjadwal)) }} terlaksana</span>
        </div>
        <p class="text-sm text-teks2">{{ g.jp_terlaksana }}/{{ g.jp_terjadwal }} JP terlaksana · {{ g.jp_tidak }} tidak terlaksana · <span :class="g.jp_kosong && 'font-semibold text-merah'">{{ g.jp_kosong }} belum diisi</span></p>
        <ul class="mt-2 grid gap-1 text-xs text-teks3 sm:grid-cols-2">
          <li v-for="r in g.rinci" :key="r.assignment_id" :class="['flex items-center gap-1.5', 'w-' + warnaJenjang(jenjangBaris(r))]"><span class="h-2 w-2 shrink-0 rounded-full" style="background: var(--c)" aria-hidden="true" />{{ r.kelas }} · {{ r.mapel }}: {{ r.jp_terlaksana }}/{{ r.jp_terjadwal }} JP</li>
        </ul>
      </li>
    </ul>
    <p v-if="!perGuru.length" class="kartu py-10 text-center text-sm text-teks3">Belum ada penugasan mengajar pada tahun ajaran aktif.</p>

    <DokumenCetak jenis="jadwal_rekap_mengajar" :konteks="{ jenjang: jenjang || null }" kop="pondok" :judul="cakupan === 'guru' ? 'Laporan Keterlaksanaan Mengajar' : 'Rekap Keterlaksanaan Mengajar'" :subjudul="teksPeriode" mendatar v-model:pratinjau="pratinjau" :pencetak="sesi.pengguna?.nama_lengkap">
      <template v-if="perHalaman && cakupan !== 'guru'">
        <section v-for="(g, gi) in perGuru" :key="g.employee_id" :style="gi < perGuru.length - 1 ? 'break-after: page' : ''">
          <p style="margin: 4pt 0"><b>{{ g.guru }}</b>{{ g.niy ? ' · NIY ' + g.niy : '' }} — {{ g.jp_terlaksana }}/{{ g.jp_terjadwal }} JP terlaksana ({{ teksPersen(persen(g.jp_terlaksana, g.jp_terjadwal)) }})</p>
          <table class="tabel kecil">
            <thead><tr><th style="width:4%">No.</th><th style="width:10%">Kelas</th><th>Mapel</th><th style="width:8%">JP/pekan</th><th style="width:10%">JP terjadwal</th><th style="width:10%">Terlaksana</th><th style="width:10%">Tidak terlaksana</th><th style="width:9%">Belum diisi</th><th style="width:7%">%</th></tr></thead>
            <tbody><tr v-for="(r, i) in g.rinci" :key="r.assignment_id"><td class="tengah">{{ i + 1 }}</td><td class="tengah">{{ r.kelas }}</td><td>{{ r.mapel }}</td><td class="tengah">{{ r.jp_pekan }}</td>
              <td class="tengah">{{ r.jp_terjadwal }}</td><td class="tengah">{{ r.jp_terlaksana }}</td><td class="tengah">{{ r.jp_tidak }}</td><td class="tengah">{{ r.jp_kosong }}</td><td class="tengah">{{ teksPersen(persen(r.jp_terlaksana, r.jp_terjadwal)) }}</td></tr></tbody>
          </table>
          <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: pimpinan.jabatan, nama: pimpinan.nama, niy: pimpinan.niy }" :kanan="{ jabatan: 'Guru Mata Pelajaran', nama: g.guru, niy: g.niy }" />
        </section>
      </template>
      <table v-else class="tabel kecil">
        <thead><tr><th style="width:4%">No.</th><th style="width:10%">NIY</th><th>Guru</th><th style="width:8%">Kelas</th><th style="width:18%">Mapel</th><th style="width:7%">JP/pekan</th>
          <th style="width:8%">JP terjadwal</th><th style="width:8%">Terlaksana</th><th style="width:8%">Tidak terlaksana</th><th style="width:7%">Belum diisi</th><th style="width:7%">%</th></tr></thead>
        <tbody><tr v-for="(r, i) in barisJ" :key="r.assignment_id"><td class="tengah">{{ i + 1 }}</td><td class="tengah">{{ r.niy || '–' }}</td><td>{{ r.guru }}</td><td class="tengah">{{ r.kelas }}</td><td>{{ r.mapel }}</td>
          <td class="tengah">{{ r.jp_pekan }}</td><td class="tengah">{{ r.jp_terjadwal }}</td><td class="tengah">{{ r.jp_terlaksana }}</td><td class="tengah">{{ r.jp_tidak }}</td><td class="tengah">{{ r.jp_kosong }}</td>
          <td class="tengah">{{ teksPersen(persen(r.jp_terlaksana, r.jp_terjadwal)) }}</td></tr></tbody>
      </table>
      <template v-if="!(perHalaman && cakupan !== 'guru')" #ttd>
        <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: pimpinan.jabatan, nama: pimpinan.nama, niy: pimpinan.niy }"
          :kanan="cakupan === 'guru' ? { jabatan: 'Guru Mata Pelajaran', nama: perGuru[0]?.guru || '', niy: perGuru[0]?.niy } : { jabatan: sesi.isSuperadmin ? 'Pengelola Sistem' : 'Petugas akademik', nama: sesi.pengguna?.nama_lengkap, niy: sesi.pengguna?.niy }" />
      </template>
    </DokumenCetak>
  </div>
</template>
