<!-- SIMKA PRO | src/pages/pegawai/DetailPegawai.vue | v1.3 | Profil lengkap pegawai (tanpa membuka Ubah data), foto, dan cetak CV/Daftar Riwayat Hidup | 15/10/2026 -->
<script setup>
// Biodata pegawai: kepala profil (foto, nama, NIY, status akun), ringkasan jabatan, profil lengkap per bagian
// (pribadi, kepegawaian, jabatan dan tugas, kontak dan akun), riwayat kepegawaian. Cetak: Biodata (tabel) dan
// Daftar Riwayat Hidup model CV dengan pas foto. Ubah data tetap lewat tombol Ubah.
import { computed, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import {
  PhIdentificationCard, PhBriefcase, PhCalendarBlank, PhBuildings, PhEye, PhPencilSimple, PhTrash, PhClockCounterClockwise, PhUser, PhAddressBook,
  PhUsersThree, PhFileText,
} from '@phosphor-icons/vue'
import { useUI } from '@/stores/ui'
import { useOrganisasi } from '@/stores/organisasi'
import { useKelompokSantri } from '@/stores/kelompokSantri'
import { PENDIDIKAN, STATUS_KELUARGA, KEAKTIFAN, LEVEL_MUHAFFIZH, KATEGORI_HONORER, STATUS_AKUN as AKUN } from '@/lib/kepegawaian'
import { JENIS_KELOMPOK, judulKelompok, PERAN_PENGASUH } from '@/lib/santri'
import { usePegawai } from '@/stores/pegawai'
import { formatPanjang, formatPendek } from '@/lib/tanggal'
import { ambilPenandaTangan } from '@/lib/penandatangan'
import { alamatBerkas } from '@/lib/penyimpanan'
import { MODE_DEMO } from '@/lib/supabase'
import { useSesi } from '@/stores/sesi'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'

const route = useRoute(); const router = useRouter(); const peg = usePegawai(); const sesi = useSesi(); const ui = useUI(); const org = useOrganisasi(); const kel = useKelompokSantri()
const pimpinan = ref({ jabatan: 'Direktur', nama: '', niy: '' })
const pratinjau = ref(false); const pratinjauCv = ref(false); const foto = ref('')
onMounted(async () => {
  if (!peg.daftar.length) await peg.muat()
  org.muat(); peg.muatRiwayat(route.params.id); kel.daftar.length || kel.muat().catch(() => {})
  pimpinan.value = await ambilPenandaTangan('Direktur')
})
const p = computed(() => peg.cari(route.params.id))
watch(() => p.value?.foto_id, async (id) => { foto.value = ''; if (id && !MODE_DEMO) { try { foto.value = (await alamatBerkas(id)) || '' } catch { foto.value = '' } } }, { immediate: true })
const riwayat = computed(() => peg.riwayat[route.params.id] || [])
const JENIS_RIWAYAT = { status_kepegawaian: 'Status kepegawaian', status_keaktifan: 'Status keaktifan', pendidikan: 'Pendidikan', level_muhaffizh: 'Level muhaffizh',
  kategori_honorer: 'Kategori honorer', tmt: 'TMT tugas', unit: 'Bidang/unit', jabatan_fungsional: 'Jabatan fungsional', jabatan_struktural: 'Jabatan struktural' }
function nilaiRiwayat(r, v) {
  if (!v) return '–'
  if (r.jenis === 'unit') return org.cariUnit(v)?.nama || v
  if (r.jenis === 'tmt') return formatPanjang(v)
  if (r.jenis === 'pendidikan') return PENDIDIKAN[v] || v
  return KEAKTIFAN[v] || STATUS_PEG[v] || LEVEL_MUHAFFIZH[v] || KATEGORI_HONORER[v] || v
}
const bolehHapus = computed(() => sesi.isSuperadmin && p.value && ['tanpa_akun', 'ditolak'].includes(p.value.status_akun))
async function hapus() {
  if (!(await ui.konfirmasi({ judul: 'Hapus data pegawai?', pesan: `${p.value.nama_lengkap} beserta jabatan dan riwayatnya akan dihapus permanen.`, ya: 'Hapus', bahaya: true }))) return
  try { await peg.hapus(p.value.id); ui.toast('Data pegawai dihapus.'); router.replace('/pegawai') } catch (e) { ui.toast(e.message, 'galat') }
}

const masaKerja = (tmt) => {
  if (!tmt) return '–'
  const a = new Date(tmt), b = new Date()
  let bln = (b.getFullYear() - a.getFullYear()) * 12 + b.getMonth() - a.getMonth(); if (b.getDate() < a.getDate()) bln--
  return `${Math.floor(bln / 12)} tahun ${bln % 12} bulan`
}
const STATUS_PEG = { tetap: 'Tetap', kontrak: 'Kontrak', honorer: 'Honorer' }
const STATUS_AKUN = Object.fromEntries(Object.entries(AKUN).map(([k, v]) => [k, [v.n, v.w]]))
const inisial = (n) => String(n || '').replace(/^(Ust\.|Ustzh\.)\s*/, '').split(/\s+/).slice(0, 2).map((k) => k[0]).join('')
const usia = (tgl) => { if (!tgl) return null; const a = new Date(tgl), b = new Date(); let u = b.getFullYear() - a.getFullYear(); if (b < new Date(b.getFullYear(), a.getMonth(), a.getDate())) u--; return u }

// Tugas tambahan: kelompok santri yang diasuh (wali kelas, musyrif, muhaffizh, pembina)
const asuhan = computed(() => (kel.daftar || []).filter((g) => g.aktif && (g.pengasuh || []).some((x) => x.employee_id === p.value?.id))
  .map((g) => { const x = g.pengasuh.find((y) => y.employee_id === p.value.id); return `${JENIS_KELOMPOK[g.jenis]?.pengasuh || 'Pengasuh'} ${judulKelompok(g)}${x.peran !== 'utama' ? ` (${PERAN_PENGASUH[x.peran]?.toLowerCase()})` : ''}` }))

const BAGIAN = computed(() => !p.value ? [] : [
  { judul: 'Data pribadi', ikon: PhUser, w: 'pegawai', isi: [
    ['Nama lengkap', p.value.nama_lengkap], ['NIY', p.value.niy || '–'], ['Jenis kelamin', p.value.jenis_kelamin === 'P' ? 'Perempuan' : 'Laki-laki'],
    ['Tempat, tanggal lahir', p.value.ttl || [p.value.tempat_lahir, p.value.tanggal_lahir && formatPanjang(p.value.tanggal_lahir)].filter(Boolean).join(', ') || '–'],
    ['Usia', usia(p.value.tanggal_lahir) != null ? `${usia(p.value.tanggal_lahir)} tahun` : '–'], ['Status keluarga', STATUS_KELUARGA[p.value.status_keluarga] || '–'],
    ['Pendidikan terakhir', PENDIDIKAN[p.value.pendidikan_terakhir] || '–'] ] },
  { judul: 'Kepegawaian', ikon: PhIdentificationCard, w: 'gaji', isi: [
    ['Status kepegawaian', [STATUS_PEG[p.value.status_kepegawaian], p.value.kategori_honorer && `(honorer ${KATEGORI_HONORER[p.value.kategori_honorer]?.toLowerCase()})`].filter(Boolean).join(' ') || '–'],
    ['Status keaktifan', KEAKTIFAN[p.value.status_keaktifan] || '–'], ['TMT tugas', p.value.tmt_tugas ? formatPanjang(p.value.tmt_tugas) : '–'],
    ['Masa kerja', p.value.masa_kerja?.teks || masaKerja(p.value.tmt_tugas)], ['Level muhaffizh', LEVEL_MUHAFFIZH[p.value.level_muhaffizh] || '–'] ] },
  { judul: 'Jabatan dan tugas', ikon: PhBriefcase, w: 'jadwal', isi: [
    ['Bidang/unit', p.value.nama_unit || '–'], ['Jabatan struktural', p.value.jabatan_struktural || '–'],
    ['Jabatan fungsional', (p.value.jabatan_fungsional || []).join(', ') || '–'], ['Tugas kelompok santri', asuhan.value.join('; ') || '–'] ] },
  { judul: 'Kontak dan akun', ikon: PhAddressBook, w: 'presensi', isi: [
    ['Nomor HP', p.value.no_hp || '–'], ['Email', p.value.email || '–'], ['Nama pengguna', p.value.username || '–'],
    ['Status akun', STATUS_AKUN[p.value.status_akun]?.[0] || '–'] ] },
])
const baris = computed(() => BAGIAN.value.flatMap((b) => b.isi).filter(([k]) => k !== 'Nama pengguna' && k !== 'Status akun'))
</script>
<template>
  <div v-if="p" class="mx-auto max-w-4xl">
    <div class="layar-saja">
      <section class="kartu w-pegawai overflow-hidden">
        <div class="kepala h-20 sm:h-24" />
        <div class="-mt-12 flex flex-wrap items-start gap-x-4 gap-y-2 px-5 pb-5">
          <img v-if="foto" :src="foto" :alt="`Foto ${p.nama_lengkap}`" class="h-24 w-[72px] rounded-2xl border-4 border-permukaan object-cover shadow-kartu" />
          <span v-else :class="['grid h-24 w-[72px] place-items-center rounded-2xl border-4 border-permukaan text-2xl font-extrabold text-white', p.jenis_kelamin === 'P' ? 'bg-[#B42A5E]' : 'bg-[#2F5FA8]']">{{ inisial(p.nama_lengkap) }}</span>
          <div class="min-w-0 flex-1 pt-14">
            <h2 class="text-xl font-extrabold leading-tight [overflow-wrap:anywhere]">{{ p.nama_lengkap }}</h2>
            <p class="text-sm text-teks3">NIY {{ p.niy || 'belum ada' }} · {{ [p.jabatan_struktural, ...(p.jabatan_fungsional || [])].filter(Boolean).join(', ') || 'Belum ada jabatan' }}</p>
          </div>
          <span :class="['lencana sm:mt-14', 'w-' + STATUS_AKUN[p.status_akun][1]]">{{ STATUS_AKUN[p.status_akun][0] }}</span>
        </div>
        <div class="grid gap-3 border-t border-garis p-5 sm:grid-cols-2">
          <div class="w-santri flex items-center gap-3"><span class="chip-ikon h-10 w-10"><PhBuildings :size="20" weight="duotone" /></span>
            <div class="min-w-0"><p class="text-xs text-teks3">Bidang/unit</p><p class="font-semibold">{{ p.nama_unit || '–' }}</p></div></div>
          <div class="w-tahfizh flex items-center gap-3"><span class="chip-ikon h-10 w-10"><PhCalendarBlank :size="20" weight="duotone" /></span>
            <div class="min-w-0"><p class="text-xs text-teks3">TMT tugas</p><p class="font-semibold">{{ p.tmt_tugas ? formatPendek(p.tmt_tugas) : '–' }} ({{ p.masa_kerja?.teks || masaKerja(p.tmt_tugas) }})</p></div></div>
        </div>
      </section>
      <div class="mt-4 flex flex-wrap gap-2">
        <router-link :to="`/pegawai/${p.id}/ubah`" class="tombol-utama"><PhPencilSimple :size="20" weight="duotone" /> Ubah data</router-link>
        <button class="tombol-garis" @click="pratinjauCv = true"><PhFileText :size="20" weight="duotone" /> Cetak CV</button>
        <button class="tombol-garis" @click="pratinjau = true"><PhEye :size="20" weight="duotone" /> Cetak biodata</button>
        <button v-if="bolehHapus" class="tombol-garis" @click="hapus"><PhTrash :size="20" weight="duotone" /> Hapus</button>
      </div>

      <!-- Profil lengkap -->
      <div class="mt-4 grid gap-4 md:grid-cols-2">
        <section v-for="b in BAGIAN" :key="b.judul" :class="['kartu p-5', 'w-' + b.w]">
          <div class="mb-3 flex items-center gap-3"><span class="chip-ikon h-10 w-10"><component :is="b.ikon" :size="22" weight="duotone" /></span><h3 class="judul-bagian">{{ b.judul }}</h3></div>
          <dl class="divide-y divide-garis text-sm">
            <div v-for="[k, v] in b.isi" :key="k" class="grid grid-cols-[42%_1fr] gap-2 py-2"><dt class="text-teks3">{{ k }}</dt><dd class="font-semibold [overflow-wrap:anywhere]">{{ v }}</dd></div>
          </dl>
        </section>
      </div>

      <section class="kartu w-pengajuan mt-4 p-5">
        <div class="mb-3 flex items-center gap-3"><span class="chip-ikon h-10 w-10"><PhClockCounterClockwise :size="22" weight="duotone" /></span>
          <div><h3 class="judul-bagian">Riwayat kepegawaian</h3><p class="text-sm text-teks3">Dasar perhitungan gaji per periode.</p></div></div>
        <ol v-if="riwayat.length" class="relative ml-2 space-y-3 border-l-2 border-garis pl-5">
          <li v-for="r in riwayat" :key="r.id" class="relative">
            <span class="absolute -left-[27px] top-1.5 h-3 w-3 rounded-full" style="background: var(--c)" aria-hidden="true" />
            <p class="text-sm font-semibold">{{ JENIS_RIWAYAT[r.jenis] || r.jenis }}</p>
            <p class="text-sm text-teks2">{{ nilaiRiwayat(r, r.nilai_lama) }} → <span class="font-semibold text-teks">{{ nilaiRiwayat(r, r.nilai_baru) }}</span></p>
            <p class="text-xs text-teks3">Berlaku {{ formatPanjang(r.tanggal_berlaku) }}</p>
          </li>
        </ol>
        <p v-else class="py-3 text-sm text-teks3">Belum ada perubahan tercatat.</p>
      </section>
    </div>

    <!-- Cetak biodata (tabel) -->
    <DokumenCetak judul="Biodata Pegawai" v-model:pratinjau="pratinjau" :pencetak="sesi.pengguna?.nama_lengkap">
      <table class="tabel">
        <colgroup><col style="width:7%"><col style="width:33%"><col style="width:60%"></colgroup>
        <thead><tr><th>No.</th><th>Data</th><th>Keterangan</th></tr></thead>
        <tbody><tr v-for="(b, i) in baris" :key="b[0]"><td class="tengah">{{ i + 1 }}</td><td>{{ b[0] }}</td><td>{{ b[1] }}</td></tr></tbody>
      </table>
      <template #ttd>
        <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: pimpinan.jabatan, nama: pimpinan.nama, niy: pimpinan.niy }"
          :kanan="{ jabatan: 'Pegawai yang bersangkutan', nama: p.nama_lengkap, niy: p.niy }" />
      </template>
    </DokumenCetak>

    <!-- Cetak CV / Daftar Riwayat Hidup -->
    <DokumenCetak judul="Daftar Riwayat Hidup" v-model:pratinjau="pratinjauCv" :pencetak="sesi.pengguna?.nama_lengkap">
      <table class="data" style="width: 100%; margin-bottom: 8pt">
        <tbody><tr>
          <td style="vertical-align: top; padding-right: 6mm">
            <p style="font-size: 15pt; margin: 0">{{ p.nama_lengkap }}</p>
            <p style="margin: 1pt 0 0">{{ [p.jabatan_struktural, ...(p.jabatan_fungsional || [])].filter(Boolean).join(', ') || '–' }}</p>
            <p style="margin: 1pt 0 0">{{ p.nama_unit || '' }}</p>
            <p style="margin: 6pt 0 0">{{ [p.no_hp, p.email].filter(Boolean).join(' · ') }}</p>
          </td>
          <td style="width: 32mm; vertical-align: top">
            <img v-if="foto" :src="foto" alt="Pas foto" style="width: 30mm; height: 40mm; object-fit: cover; border: 0.5pt solid #000" />
            <div v-else style="width: 30mm; height: 40mm; border: 0.5pt solid #000; display: flex; align-items: center; justify-content: center; text-align: center; font-size: 9pt">Pas foto<br>3 × 4</div>
          </td>
        </tr></tbody>
      </table>
      <template v-for="(b, n) in BAGIAN.filter((x) => x.judul !== 'Kontak dan akun')" :key="b.judul">
        <p style="margin: 8pt 0 3pt; font-weight: 700">{{ String.fromCharCode(65 + n) }}. {{ b.judul.toUpperCase() }}</p>
        <table class="data" style="width: 100%"><tbody>
          <tr v-for="[k, v] in b.isi" :key="k"><td style="width: 50mm">{{ k }}</td><td style="width: 4mm">:</td><td>{{ v }}</td></tr>
        </tbody></table>
      </template>
      <p style="margin: 8pt 0 3pt; font-weight: 700">D. RIWAYAT KEPEGAWAIAN</p>
      <table class="tabel kecil">
        <colgroup><col style="width:6%"><col style="width:20%"><col style="width:26%"><col style="width:30%"><col style="width:18%"></colgroup>
        <thead><tr><th>No.</th><th>Perubahan</th><th>Semula</th><th>Menjadi</th><th>Berlaku</th></tr></thead>
        <tbody>
          <tr v-for="(r, i) in riwayat" :key="r.id"><td class="tengah">{{ i + 1 }}</td><td>{{ JENIS_RIWAYAT[r.jenis] || r.jenis }}</td><td>{{ nilaiRiwayat(r, r.nilai_lama) }}</td>
            <td>{{ nilaiRiwayat(r, r.nilai_baru) }}</td><td class="tengah">{{ formatPendek(r.tanggal_berlaku) }}</td></tr>
          <tr v-if="!riwayat.length"><td colspan="5" class="tengah">Belum ada perubahan tercatat. Mulai bertugas {{ p.tmt_tugas ? formatPanjang(p.tmt_tugas) : '–' }}.</td></tr>
        </tbody>
      </table>
      <p style="margin-top: 8pt">Demikian daftar riwayat hidup ini dibuat dengan sebenarnya.</p>
      <template #ttd>
        <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: pimpinan.jabatan, nama: pimpinan.nama, niy: pimpinan.niy }"
          :kanan="{ jabatan: 'Yang membuat,', nama: p.nama_lengkap, niy: p.niy }" />
      </template>
    </DokumenCetak>
  </div>
  <p v-else-if="!peg.memuat" class="py-16 text-center text-teks3">Data pegawai tidak ditemukan.</p>
</template>
<style scoped>
.kepala { background: var(--gradasi-utama); }
</style>
