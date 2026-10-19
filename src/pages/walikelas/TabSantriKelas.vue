<!-- SIMKA PRO | src/pages/walikelas/TabSantriKelas.vue | v1.3 | 14.15.0: penanda tangan dan kop dari Setelan → Penanda tangan | 19/10/2026 -->
<script setup>
// Daftar santri satu kelas: NIS, nama, JK, kehadiran bulan berjalan (izin, sakit, absen), orang tua/wali utama dan
// tombol WA, serta tautan biodata. Cetak F4 "Daftar Santri Kelas" (wali kelas di kanan, Direktur mengetahui di kiri) dan Excel.
import { ref, computed, onMounted } from 'vue'
import * as XLSX from 'xlsx'
import { PhMagnifyingGlass, PhPrinter, PhFileXls, PhWhatsappLogo, PhCaretRight } from '@phosphor-icons/vue'
import { useWaliKelas } from '@/stores/waliKelas'
import { useSantri } from '@/stores/santri'
import { useLembaga } from '@/stores/lembaga'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { teksPersen } from '@/lib/absensi'
import { kontakUtama, HUBUNGAN } from '@/lib/santri'
import { olahRinci, awalBulanDari, namaBulan, persenDari } from '@/lib/musyrif'
import { hariIniISO } from '@/lib/tanggal'
import { tautanWA } from '@/lib/wa'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'

const wk = useWaliKelas(); const san = useSantri(); const lembaga = useLembaga(); const sesi = useSesi(); const ui = useUI()
const hari = hariIniISO(); const awal = awalBulanDari(hari)
const d = ref(null); const cari = ref(''); const memuat = ref(false); const pratinjau = ref(false)
onMounted(async () => {
  memuat.value = true
  try { await san.muat(); d.value = await wk.rinci(wk.pilih, awal, hari); lembaga.muat() } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false }
})
const o = computed(() => olahRinci(d.value))
const baris = computed(() => (d.value?.santri || []).filter((s) => s.aktif_di_kamar !== false).map((s) => {
  const data = san.cari(s.id); const k = data ? kontakUtama(data) : null; const r = o.value.perSantri[s.id]?.total
  return { ...s, kontak: k, r, persen: r?.sesi ? persenDari(r) : null }
}))
const tampil = computed(() => { const q = cari.value.toLowerCase().trim(); return q ? baris.value.filter((s) => s.nama.toLowerCase().includes(q) || String(s.nis).startsWith(q)) : baris.value })
const jk = computed(() => ({ L: baris.value.filter((s) => s.jenis_kelamin === 'L').length, P: baris.value.filter((s) => s.jenis_kelamin === 'P').length }))
const waliKelas = computed(() => wk.kelasPilih?.wali?.[0] || {})
const direktur = computed(() => lembaga.signatories.find((s) => s.sumber_jabatan === 'DIREKTUR' || /^direktur/i.test(s.jabatan_tertulis)) || {})
const sapa = (s) => `Assalamu'alaikum warahmatullahi wabarakatuh, Bapak/Ibu ${s.kontak?.nama || ''}. Kami wali kelas ${wk.kelasPilih?.nama} ingin menyampaikan perihal ananda ${s.nama}.`
function ekspor() {
  const aoa = [['No.', 'NIS', 'Nama', 'JK', `Sesi ${namaBulan(awal)}`, 'Hadir', 'Izin', 'Sakit', 'Absen', 'Bolos', 'Kehadiran (%)', 'Orang tua/wali', 'Hubungan', 'No. HP'],
    ...baris.value.map((s, i) => [i + 1, s.nis, s.nama, s.jenis_kelamin, s.r?.sesi || 0, s.r ? s.r.sesi - s.r.I - s.r.S - s.r.A : 0, s.r?.I || 0, s.r?.S || 0, s.r?.A || 0, s.r?.B || 0,
      s.persen ?? '', s.kontak?.nama || '', HUBUNGAN[s.kontak?.hubungan] || '', s.kontak?.no_hp || ''])]
  const ws = XLSX.utils.aoa_to_sheet(aoa); ws['!cols'] = aoa[0].map((j) => ({ wch: ['Nama', 'Orang tua/wali'].includes(j) ? 28 : 11 }))
  for (let i = 1; i < aoa.length; i++) { const a = XLSX.utils.encode_cell({ r: i, c: 1 }); if (ws[a]) { ws[a].t = 's'; ws[a].z = '@' } }
  const wb = XLSX.utils.book_new(); XLSX.utils.book_append_sheet(wb, ws, 'Santri'); XLSX.writeFile(wb, `Santri-Kelas-${wk.kelasPilih?.nama}-${hari}.xlsx`)
}
</script>
<template>
  <div>
    <div class="mb-3 flex flex-wrap items-center gap-2">
      <div class="relative min-w-[200px] flex-1"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-teks3" />
        <input v-model="cari" type="search" class="isian pl-10" placeholder="Cari nama atau NIS" aria-label="Cari santri" /></div>
      <button class="tombol-garis" :disabled="!baris.length" @click="ekspor"><PhFileXls :size="20" weight="duotone" /> Ekspor</button>
      <button class="tombol-utama" :disabled="!baris.length" @click="pratinjau = true"><PhPrinter :size="20" weight="duotone" /> Cetak daftar</button>
    </div>
    <p class="mb-2 text-sm text-teks2">{{ baris.length }} santri ({{ jk.L }} putra, {{ jk.P }} putri) · kehadiran {{ namaBulan(awal) }}</p>
    <p v-if="memuat" class="kartu p-8 text-center text-sm text-teks3">Memuat santri…</p>
    <p v-else-if="!tampil.length" class="kartu p-8 text-center text-sm text-teks3">Belum ada santri di kelas ini.</p>
    <template v-else>
      <div class="kartu hidden overflow-x-auto lg:block">
        <table class="w-full text-left text-sm">
          <thead class="border-b border-garis bg-permukaan2 text-teks2"><tr><th class="px-3 py-3 font-bold">NIS</th><th class="px-3 py-3 font-bold">Nama</th><th class="px-3 py-3 font-bold">JK</th>
            <th class="px-3 py-3 text-right font-bold">Kehadiran</th><th class="px-3 py-3 font-bold">I · S · A · B</th><th class="px-3 py-3 font-bold">Orang tua/wali</th><th class="px-3 py-3" /></tr></thead>
          <tbody class="divide-y divide-garis">
            <tr v-for="s in tampil" :key="s.id">
              <td class="px-3 py-2.5 tabular-nums text-teks2">{{ s.nis }}</td>
              <td class="px-3 py-2.5"><router-link :to="`/santri/${s.id}`" class="font-semibold hover:underline">{{ s.nama }}</router-link></td>
              <td class="px-3 py-2.5">{{ s.jenis_kelamin }}</td>
              <td :class="['px-3 py-2.5 text-right font-bold tabular-nums', s.persen != null && s.persen < 85 && 'text-merah']">{{ teksPersen(s.persen) }}</td>
              <td class="px-3 py-2.5 tabular-nums text-teks2">{{ s.r ? `${s.r.I} · ${s.r.S} · ${s.r.A} · ${s.r.B}` : '–' }}</td>
              <td class="px-3 py-2.5">{{ s.kontak?.nama || '–' }}<span v-if="s.kontak" class="block text-xs text-teks3">{{ HUBUNGAN[s.kontak.hubungan] }} · {{ s.kontak.no_hp || 'HP belum diisi' }}</span></td>
              <td class="px-3 py-2.5 text-right"><a v-if="s.kontak?.no_hp" :href="tautanWA(s.kontak.no_hp, sapa(s))" target="_blank" rel="noopener" class="tombol-wa-garis w-presensi min-h-[36px] px-3 text-sm"><PhWhatsappLogo :size="18" weight="duotone" /> WA</a></td>
            </tr>
          </tbody>
        </table>
      </div>
      <ul class="space-y-2 lg:hidden">
        <li v-for="s in tampil" :key="s.id" class="kartu flex items-center gap-3 p-3.5">
          <router-link :to="`/santri/${s.id}`" class="min-w-0 flex-1">
            <p class="truncate font-bold">{{ s.nama }}</p>
            <p class="truncate text-xs text-teks3">{{ s.nis }} · {{ s.jenis_kelamin }} · {{ s.kontak?.nama || 'kontak belum diisi' }}</p>
            <p class="text-xs"><b :class="s.persen != null && s.persen < 85 ? 'text-merah' : ''">{{ teksPersen(s.persen) }}</b> <span class="text-teks3">{{ s.r ? `· I ${s.r.I} · S ${s.r.S} · A ${s.r.A}` : '' }}</span></p>
          </router-link>
          <a v-if="s.kontak?.no_hp" :href="tautanWA(s.kontak.no_hp, sapa(s))" target="_blank" rel="noopener" class="tombol-ikon w-presensi h-11 w-11" :aria-label="`WA orang tua/wali ${s.nama}`"><PhWhatsappLogo :size="22" weight="duotone" style="color: var(--c)" /></a>
          <PhCaretRight v-else :size="18" class="text-teks3" />
        </li>
      </ul>
    </template>

    <DokumenCetak jenis="wk_daftar_santri" :konteks="{ groupIds: [wk.pilih] }" v-model:pratinjau="pratinjau" :judul="`Daftar Santri Kelas ${wk.kelasPilih?.nama || ''}`" :subjudul="`Tahun Ajaran ${lembaga.tahunAktif?.nama || ''} · kehadiran ${namaBulan(awal)}`" :pencetak="sesi.pengguna?.nama_lengkap">
      <table class="tabel kecil">
        <colgroup><col style="width:4%"><col style="width:10%"><col style="width:26%"><col style="width:4%"><col style="width:9%"><col style="width:5%"><col style="width:5%"><col style="width:5%"><col style="width:18%"><col style="width:14%"></colgroup>
        <thead><tr><th>No.</th><th>NIS</th><th>Nama</th><th>JK</th><th>Kehadiran</th><th>Izin</th><th>Sakit</th><th>Absen</th><th>Orang tua/wali</th><th>No. HP</th></tr></thead>
        <tbody><tr v-for="(s, i) in baris" :key="s.id"><td class="tengah">{{ i + 1 }}</td><td>{{ s.nis }}</td><td>{{ s.nama }}</td><td class="tengah">{{ s.jenis_kelamin }}</td>
          <td class="kanan">{{ teksPersen(s.persen) }}</td><td class="tengah">{{ s.r?.I || 0 }}</td><td class="tengah">{{ s.r?.S || 0 }}</td><td class="tengah">{{ s.r?.A || 0 }}</td>
          <td>{{ s.kontak?.nama || '–' }}</td><td>{{ s.kontak?.no_hp || '–' }}</td></tr></tbody>
      </table>
      <p class="mt-2 text-[8pt]">Jumlah: {{ baris.length }} santri ({{ jk.L }} putra, {{ jk.P }} putri). Kehadiran dihitung dari absensi kelas {{ namaBulan(awal) }} sampai hari ini.</p>
      <template #ttd><TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: direktur.jabatan_tertulis || 'Direktur', nama: direktur.nama || '', niy: direktur.niy }"
        :kanan="{ jabatan: `Wali Kelas ${wk.kelasPilih?.nama || ''}`, nama: waliKelas.nama || '', niy: waliKelas.niy }" /></template>
    </DokumenCetak>
  </div>
</template>
