<!-- SIMKA PRO | src/pages/ekskul/TabRekapEkskul.vue | v1.0 | Fase 4 – Tahap 4 Ekskul | 04/10/2026 -->
<script setup>
// Rekap ekskul per periode: kehadiran anggota (HISBAT) dan jurnal materi setiap pertemuan.
// Dapat dicetak oleh pembina, pimpinan, admin, dan superadmin (F4 mendatar, berkop pondok).
import { ref, computed, onMounted, watch } from 'vue'
import * as XLSX from 'xlsx'
import { PhDownloadSimple, PhEye, PhNotebook } from '@phosphor-icons/vue'
import { useAbsensiSantri } from '@/stores/absensiSantri'
import { useKelompokSantri } from '@/stores/kelompokSantri'
import { useSantri } from '@/stores/santri'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { susunRekap, persen, teksPersen } from '@/lib/absensi'
import { labelRombel, penandaKelompok } from '@/lib/santri'
import { hariIniISO, formatPanjang, formatPendek, formatHari } from '@/lib/tanggal'
import InputTanggal from '@/components/InputTanggal.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'
import FotoBerkas from '@/components/FotoBerkas.vue'

defineProps({ semua: Boolean })
const abs = useAbsensiSantri(); const kel = useKelompokSantri(); const san = useSantri(); const sesi = useSesi(); const ui = useUI()
const mulai = ref(hariIniISO().slice(0, 8) + '01'); const selesai = ref(hariIniISO()); const groupId = ref('')
const baris = ref([]); const jurnal = ref([]); const memuat = ref(false); const pratinjau = ref(false); const penanda = ref({ jabatan: '', nama: '', niy: '' })
const pilihan = computed(() => kel.dariTA.filter((g) => g.jenis === 'ekskul'))
const g = computed(() => kel.cari(groupId.value))
onMounted(async () => {
  await Promise.all([kel.daftar.length ? null : kel.muat(), san.muat()])
  groupId.value = pilihan.value.find((x) => x.asuhan_saya)?.id || pilihan.value[0]?.id || ''
})
async function muat() {
  if (!groupId.value) return
  memuat.value = true
  try {
    const [r, j] = await Promise.all([abs.rekap(mulai.value, selesai.value, { group: groupId.value, jenis: 'ekskul' }), abs.jurnalEkskul(groupId.value, mulai.value, selesai.value), kel.muatAnggota(groupId.value)])
    baris.value = r; jurnal.value = j; if (g.value) penanda.value = await penandaKelompok(g.value)
  } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false }
}
watch([groupId, mulai, selesai], muat)
const peta = computed(() => susunRekap(baris.value))
const data = computed(() => (kel.anggota[groupId.value]?.aktif || []).map((a) => san.cari(a.student_id)).filter(Boolean)
  .sort((a, b) => a.nama_lengkap.localeCompare(b.nama_lengkap, 'id')).map((s) => ({ s, r: peta.value[s.id]?.ekskul })))
const teksPeriode = computed(() => `${formatPanjang(mulai.value)} s.d. ${formatPanjang(selesai.value)}`)
const pembina = computed(() => (g.value?.pengasuh || []).find((p) => p.peran === 'utama') || (g.value?.pengasuh || [])[0] || null)

function ekspor() {
  const wb = XLSX.utils.book_new()
  const k1 = ['No.', 'NIS', 'Nama', 'Kelas', 'Pertemuan', 'Hadir', 'Izin', 'Sakit', 'Bolos', 'Absen', 'Terlambat', 'Kehadiran (%)']
  const ws1 = XLSX.utils.aoa_to_sheet([[`Rekap kehadiran ekskul ${g.value.nama} – ${teksPeriode.value}`], [], k1,
    ...data.value.map(({ s, r }, i) => [i + 1, s.nis, s.nama_lengkap, labelRombel(s), r?.sesi || 0, r?.hadir || 0, r?.izin || 0, r?.sakit || 0, r?.bolos || 0, r?.absen || 0, r?.terlambat || 0, persen(r?.hadir, r?.sesi) ?? ''])])
  ws1['!cols'] = k1.map((k, i) => ({ wch: i === 2 ? 30 : Math.max(8, k.length + 2) }))
  XLSX.utils.book_append_sheet(wb, ws1, 'Kehadiran')
  const k2 = ['No.', 'Tanggal', 'Topik/materi', 'Uraian', 'Hadir', 'Pembina']
  const ws2 = XLSX.utils.aoa_to_sheet([[`Jurnal materi ekskul ${g.value.nama} – ${teksPeriode.value}`], [], k2,
    ...jurnal.value.map((j, i) => [i + 1, formatPendek(j.tanggal), j.topik || '', j.uraian || '', `${j.jumlah_hadir}/${j.jumlah_anggota}`, j.pengampu || ''])])
  ws2['!cols'] = [{ wch: 5 }, { wch: 12 }, { wch: 36 }, { wch: 60 }, { wch: 8 }, { wch: 28 }]
  XLSX.utils.book_append_sheet(wb, ws2, 'Jurnal materi')
  XLSX.writeFile(wb, `Rekap-Ekskul-${g.value.nama.replace(/[^\w.-]+/g, '-')}-${formatPendek(mulai.value).replace(/\//g, '')}-${formatPendek(selesai.value).replace(/\//g, '')}.xlsx`)
}
</script>
<template>
  <div>
    <div class="kartu mb-4 grid gap-3 p-4 sm:grid-cols-[1fr_auto_auto]">
      <div><label class="label-isian" for="re-g">Ekskul</label>
        <select id="re-g" v-model="groupId" class="isian">
          <option v-for="x in pilihan" :key="x.id" :value="x.id">{{ x.nama }}{{ x.asuhan_saya ? ' (binaan saya)' : '' }}{{ x.aktif ? '' : ' (nonaktif)' }}</option>
          <option v-if="!pilihan.length" value="">Belum ada ekskul</option>
        </select></div>
      <div class="sm:w-44"><InputTanggal v-model="mulai" label="Dari" wajib /></div>
      <div class="sm:w-44"><InputTanggal v-model="selesai" label="Sampai" wajib /></div>
    </div>

    <template v-if="g">
      <div class="-mx-4 mb-4 flex gap-2 overflow-x-auto px-4 pb-1 lg:mx-0 lg:px-0">
        <button class="w-santri tombol-garis shrink-0 px-4 text-sm" @click="ekspor"><PhDownloadSimple :size="20" weight="duotone" style="color: var(--c)" /> Excel</button>
        <button class="w-pengajuan tombol-garis shrink-0 px-4 text-sm" @click="pratinjau = true"><PhEye :size="20" weight="duotone" style="color: var(--c)" /> Cetak rekap</button>
      </div>
      <div class="grid gap-4 xl:grid-cols-2">
        <section class="kartu overflow-x-auto">
          <p class="border-b border-garis p-4 font-bold">Kehadiran anggota · {{ jurnal.length }} pertemuan</p>
          <table class="w-full min-w-[480px] text-left text-sm">
            <thead class="border-b border-garis bg-permukaan2 text-teks2"><tr><th class="px-3 py-2 font-bold">Nama</th><th class="px-3 py-2 text-center font-bold">Hadir</th>
              <th class="px-3 py-2 text-center font-bold">I</th><th class="px-3 py-2 text-center font-bold">S</th><th class="px-3 py-2 text-center font-bold">A</th><th class="px-3 py-2 text-center font-bold">%</th></tr></thead>
            <tbody class="divide-y divide-garis">
              <tr v-for="{ s, r } in data" :key="s.id"><td class="px-3 py-2 font-semibold">{{ s.nama_lengkap }} <span class="font-normal text-teks3">· {{ labelRombel(s) }}</span></td>
                <td class="px-3 py-2 text-center tabular-nums">{{ r ? `${r.hadir}/${r.sesi}` : '–' }}</td><td class="px-3 py-2 text-center tabular-nums">{{ r?.izin || '' }}</td>
                <td class="px-3 py-2 text-center tabular-nums">{{ r?.sakit || '' }}</td><td class="px-3 py-2 text-center font-semibold tabular-nums text-merah">{{ r?.absen || '' }}</td>
                <td class="px-3 py-2 text-center font-bold tabular-nums">{{ teksPersen(persen(r?.hadir, r?.sesi)) }}</td></tr>
            </tbody>
          </table>
          <p v-if="!data.length && !memuat" class="py-8 text-center text-sm text-teks3">Belum ada anggota.</p>
        </section>
        <section class="kartu w-ekskul p-4">
          <p class="mb-3 flex items-center gap-2 font-bold"><PhNotebook :size="20" weight="duotone" style="color: var(--c)" /> Jurnal materi</p>
          <ol class="space-y-3">
            <li v-for="j in jurnal" :key="j.session_id" class="flex gap-3 rounded-xl bg-permukaan2 p-3">
              <FotoBerkas v-if="j.foto_id" :id="j.foto_id" alt="Foto kegiatan ekskul" ukuran="h-16 w-20" />
              <div class="min-w-0 flex-1"><p class="text-xs text-teks3">{{ formatHari(j.tanggal) }} · hadir {{ j.jumlah_hadir }}/{{ j.jumlah_anggota }}</p>
                <p class="font-semibold">{{ j.topik || 'Topik belum diisi' }}</p><p v-if="j.uraian" class="text-sm text-teks2">{{ j.uraian }}</p></div>
            </li>
            <li v-if="!jurnal.length && !memuat" class="py-6 text-center text-sm text-teks3">Belum ada pertemuan tercatat pada periode ini.</li>
          </ol>
        </section>
      </div>

      <DokumenCetak kop="pondok" :judul="`Rekap Ekskul ${g.nama}`" :subjudul="`Tahun Ajaran ${g.tahun_ajaran} · ${teksPeriode}`" mendatar v-model:pratinjau="pratinjau" :pencetak="sesi.pengguna?.nama_lengkap">
        <p style="margin-bottom: 4pt">A. Kehadiran anggota ({{ jurnal.length }} pertemuan)</p>
        <table class="tabel kecil">
          <thead><tr><th style="width:4%">No.</th><th style="width:9%">NIS</th><th>Nama</th><th style="width:10%">Kelas</th><th style="width:8%">Hadir/Pertemuan</th>
            <th style="width:6%">Izin</th><th style="width:6%">Sakit</th><th style="width:6%">Bolos</th><th style="width:6%">Absen</th><th style="width:7%">Terlambat</th><th style="width:8%">Kehadiran</th></tr></thead>
          <tbody><tr v-for="({ s, r }, i) in data" :key="s.id"><td class="tengah">{{ i + 1 }}</td><td class="tengah">{{ s.nis }}</td><td>{{ s.nama_lengkap }}</td><td class="tengah">{{ labelRombel(s).replace('Kelas ', '') }}</td>
            <td class="tengah">{{ r ? `${r.hadir}/${r.sesi}` : '0/0' }}</td><td class="tengah">{{ r?.izin || 0 }}</td><td class="tengah">{{ r?.sakit || 0 }}</td><td class="tengah">{{ r?.bolos || 0 }}</td>
            <td class="tengah">{{ r?.absen || 0 }}</td><td class="tengah">{{ r?.terlambat || 0 }}</td><td class="tengah">{{ teksPersen(persen(r?.hadir, r?.sesi)) }}</td></tr></tbody>
        </table>
        <p style="margin: 8pt 0 4pt">B. Jurnal materi</p>
        <table class="tabel kecil">
          <thead><tr><th style="width:4%">No.</th><th style="width:16%">Hari, tanggal</th><th style="width:26%">Topik/materi</th><th>Uraian</th><th style="width:8%">Hadir</th></tr></thead>
          <tbody><tr v-for="(j, i) in jurnal" :key="j.session_id"><td class="tengah">{{ i + 1 }}</td><td>{{ formatHari(j.tanggal) }}</td><td>{{ j.topik || '–' }}</td><td>{{ j.uraian || '–' }}</td><td class="tengah">{{ j.jumlah_hadir }}/{{ j.jumlah_anggota }}</td></tr></tbody>
        </table>
        <template #ttd>
          <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: penanda.jabatan, nama: penanda.nama, niy: penanda.niy }"
            :kanan="{ jabatan: 'Pembina/pelatih ekskul', nama: pembina?.nama || '', niy: pembina?.niy }" />
        </template>
      </DokumenCetak>
    </template>
  </div>
</template>
