<!-- SIMKA PRO | src/pages/absensisantri/TabRekapAbsensi.vue | v1.0 | Fase 4 – Tahap 3 Absensi HISBAT | 04/10/2026 -->
<script setup>
// Rekap kehadiran santri per kelompok dan periode: kelas, halaqah, asrama, dan gabungan program pokok
// (Terlambat dan Bolos dihitung hadir). Ekspor Excel, cetak F4 mendatar, WA rekap ke wali, salin rekap umum untuk grup.
import { ref, computed, onMounted, watch } from 'vue'
import * as XLSX from 'xlsx'
import { PhDownloadSimple, PhEye, PhWhatsappLogo, PhCopy } from '@phosphor-icons/vue'
import { useAbsensiSantri } from '@/stores/absensiSantri'
import { useKelompokSantri } from '@/stores/kelompokSantri'
import { useSantri } from '@/stores/santri'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { JENIS_ABSENSI, susunRekap, persen, teksPersen, teksRingkas } from '@/lib/absensi'
import { judulKelompok, kontakUtama, labelRombel, penandaKelompok, JENIS_KELOMPOK } from '@/lib/santri'
import { hariIniISO, formatPanjang, formatPendek } from '@/lib/tanggal'
import { pesanWA } from '@/lib/wa'
import InputTanggal from '@/components/InputTanggal.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'
import LembarBawah from '@/components/LembarBawah.vue'
import DaftarKirimWA from '@/components/DaftarKirimWA.vue'

defineProps({ semua: Boolean })
const abs = useAbsensiSantri(); const kel = useKelompokSantri(); const san = useSantri(); const sesi = useSesi(); const ui = useUI()
const awalBulan = () => hariIniISO().slice(0, 8) + '01'
const mulai = ref(awalBulan()); const selesai = ref(hariIniISO()); const groupId = ref(''); const baris = ref([]); const memuat = ref(false)
const pratinjau = ref(false); const lembarWA = ref(false); const penanda = ref({ jabatan: '', nama: '', niy: '' })

const pilihan = computed(() => kel.dariTA.filter((g) => ['kelas', 'halaqah', 'kamar'].includes(g.jenis) && g.aktif))
const g = computed(() => kel.cari(groupId.value))
onMounted(async () => {
  await Promise.all([kel.daftar.length ? null : kel.muat(), san.muat()])
  groupId.value = pilihan.value.find((x) => x.asuhan_saya)?.id || pilihan.value[0]?.id || ''
})
async function muat() {
  if (!groupId.value || !mulai.value || !selesai.value) return
  if (selesai.value < mulai.value) return ui.toast('Tanggal akhir sebelum tanggal awal.', 'galat')
  memuat.value = true
  try {
    const [r] = await Promise.all([abs.rekap(mulai.value, selesai.value), kel.muatAnggota(groupId.value)])
    baris.value = r; penanda.value = g.value ? await penandaKelompok(g.value) : penanda.value
  } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false }
}
watch([groupId, mulai, selesai], muat)
const isoDari = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
function periode(jenis) {
  const d = new Date(`${hariIniISO()}T00:00:00`)
  if (jenis === 'pekan') { d.setDate(d.getDate() - ((d.getDay() + 6) % 7)); mulai.value = isoDari(d) } // Senin pekan ini
  if (jenis === 'bulan') mulai.value = awalBulan()
  if (jenis === '30') { d.setDate(d.getDate() - 29); mulai.value = isoDari(d) }
  selesai.value = hariIniISO()
}

const peta = computed(() => susunRekap(baris.value))
const anggota = computed(() => (kel.anggota[groupId.value]?.aktif || []).map((a) => san.cari(a.student_id)).filter(Boolean)
  .sort((a, b) => a.nama_lengkap.localeCompare(b.nama_lengkap, 'id')))
const data = computed(() => anggota.value.map((s) => ({ s, r: peta.value[s.id] })))
const rataRata = computed(() => { const t = data.value.reduce((a, x) => ({ h: a.h + (x.r?.pokok.hadir || 0), n: a.n + (x.r?.pokok.sesi || 0) }), { h: 0, n: 0 }); return persen(t.h, t.n) })
const jenisTampil = computed(() => ['kelas', 'halaqah', 'asrama'].filter((j) => data.value.some((x) => x.r?.[j].sesi)))
const sel = (r, j) => (r && r[j].sesi ? `${r[j].hadir}/${r[j].sesi}` : '–')
const teksPeriode = computed(() => `${formatPanjang(mulai.value)} s.d. ${formatPanjang(selesai.value)}`)
const pengasuhUtama = computed(() => (g.value?.pengasuh || []).find((p) => p.peran === 'utama') || (g.value?.pengasuh || [])[0] || null)

function ekspor() {
  const kolom = ['No.', 'NIS', 'Nama', 'L/P', ...jenisTampil.value.map((j) => `${JENIS_ABSENSI[j].n} (hadir/sesi)`), 'Izin', 'Sakit', 'Bolos', 'Absen', 'Terlambat', 'Kehadiran program pokok (%)']
  const isi = data.value.map(({ s, r }, i) => [i + 1, s.nis, s.nama_lengkap, s.jenis_kelamin, ...jenisTampil.value.map((j) => sel(r, j)),
    r?.pokok.izin || 0, r?.pokok.sakit || 0, r?.pokok.bolos || 0, r?.pokok.absen || 0, r?.pokok.terlambat || 0, persen(r?.pokok.hadir, r?.pokok.sesi) ?? ''])
  const ws = XLSX.utils.aoa_to_sheet([[`Rekap kehadiran ${judulKelompok(g.value)} – ${teksPeriode.value}`], [], kolom, ...isi])
  ws['!cols'] = kolom.map((k, i) => ({ wch: i === 2 ? 30 : Math.max(8, k.length + 2) }))
  const wb = XLSX.utils.book_new(); XLSX.utils.book_append_sheet(wb, ws, 'Rekap')
  XLSX.writeFile(wb, `Rekap-Kehadiran-${judulKelompok(g.value).replace(/[^\w.-]+/g, '-')}-${formatPendek(mulai.value).replace(/\//g, '')}-${formatPendek(selesai.value).replace(/\//g, '')}.xlsx`)
}
// Rekap umum untuk grup WA: tanpa rincian sakit atau alasan pribadi santri
async function salinGrup() {
  const penuh = data.value.filter(({ r }) => r && r.pokok.sesi && r.pokok.hadir === r.pokok.sesi).length
  const teks = `Assalamu'alaikum warahmatullahi wabarakatuh.\n\nRekap kehadiran ${judulKelompok(g.value)} periode ${teksPeriode.value}:\n• Rata-rata kehadiran program pokok: ${teksPersen(rataRata.value)}\n• ${penuh} dari ${data.value.length} santri hadir penuh\n\nRincian per santri dapat ditanyakan langsung kepada ${JENIS_KELOMPOK[g.value.jenis]?.pengasuh.toLowerCase() || 'pengasuh'}.\nJazakumullahu khairan.`
  try { await navigator.clipboard.writeText(teks); ui.toast(g.value.wa_wali ? 'Rekap disalin. Grup WA wali dibuka; tempel di sana.' : 'Rekap disalin. Tempel di grup WA wali santri.') }
  catch { ui.toast('Rekap tidak dapat disalin otomatis di peramban ini.', 'galat') }
  if (g.value.wa_wali) window.open(g.value.wa_wali, '_blank', 'noopener')
}
const penerimaWA = computed(() => data.value.map(({ s, r }) => { const k = kontakUtama(s)
  return { employee_id: s.id, nama: s.nama_lengkap, no_hp: k?.no_hp || null, unit: teksRingkas(r), keterangan: k ? `wali: ${k.nama || '–'}` : 'kontak wali belum ada', s, r, k } }))
const pesanKe = (p) => pesanWA('rekap_santri', { nama_wali: p.k?.nama, nama_santri: p.nama, kelas: labelRombel(p.s), periode: teksPeriode.value, rekap: teksRingkas(p.r) })
</script>
<template>
  <div>
    <div class="kartu mb-4 grid gap-3 p-4 sm:grid-cols-[1fr_auto_auto]">
      <div><label class="label-isian" for="rk-g">Kelompok</label>
        <select id="rk-g" v-model="groupId" class="isian">
          <option v-for="x in pilihan" :key="x.id" :value="x.id">{{ x.jenis === 'kelas' ? judulKelompok(x) : `${JENIS_KELOMPOK[x.jenis].n} · ${judulKelompok(x)}` }}{{ x.asuhan_saya ? ' (asuhan saya)' : '' }}</option>
          <option v-if="!pilihan.length" value="">Belum ada kelompok</option>
        </select></div>
      <div class="sm:w-44"><InputTanggal v-model="mulai" label="Dari" wajib /></div>
      <div class="sm:w-44"><InputTanggal v-model="selesai" label="Sampai" wajib /></div>
      <div class="flex flex-wrap gap-2 sm:col-span-3">
        <button v-for="p in [{ k: 'pekan', n: 'Pekan ini' }, { k: 'bulan', n: 'Bulan ini' }, { k: '30', n: '30 hari terakhir' }]" :key="p.k" class="tombol-garis min-h-[36px] px-3 text-sm" @click="periode(p.k)">{{ p.n }}</button>
      </div>
    </div>

    <div v-if="g" class="-mx-4 mb-4 flex gap-2 overflow-x-auto px-4 pb-1 lg:mx-0 lg:px-0">
      <button class="w-santri tombol-garis shrink-0 px-4 text-sm" @click="ekspor"><PhDownloadSimple :size="20" weight="duotone" style="color: var(--c)" /> Excel</button>
      <button class="w-pengajuan tombol-garis shrink-0 px-4 text-sm" @click="pratinjau = true"><PhEye :size="20" weight="duotone" style="color: var(--c)" /> Cetak rekap</button>
      <button class="w-presensi tombol-garis shrink-0 px-4 text-sm" @click="lembarWA = true"><PhWhatsappLogo :size="20" weight="duotone" style="color: var(--c)" /> WA rekap ke wali</button>
      <button class="w-agenda tombol-garis shrink-0 px-4 text-sm" @click="salinGrup"><PhCopy :size="20" weight="duotone" style="color: var(--c)" /> Rekap untuk grup WA</button>
    </div>

    <div v-if="g" class="kartu overflow-x-auto">
      <div class="flex flex-wrap items-center gap-3 border-b border-garis p-4">
        <p class="flex-1 font-bold">{{ judulKelompok(g) }} · {{ teksPeriode }}</p>
        <span class="lencana w-absensi">Rata-rata program pokok {{ teksPersen(rataRata) }}</span>
      </div>
      <table class="w-full min-w-[640px] text-left text-sm">
        <thead class="border-b border-garis bg-permukaan2 text-teks2">
          <tr><th class="px-3 py-2.5 font-bold">No.</th><th class="px-3 py-2.5 font-bold">Nama</th>
            <th v-for="j in jenisTampil" :key="j" class="px-3 py-2.5 text-center font-bold">{{ JENIS_ABSENSI[j].n }}</th>
            <th class="px-3 py-2.5 text-center font-bold">I</th><th class="px-3 py-2.5 text-center font-bold">S</th><th class="px-3 py-2.5 text-center font-bold">B</th>
            <th class="px-3 py-2.5 text-center font-bold">A</th><th class="px-3 py-2.5 text-center font-bold">T</th><th class="px-3 py-2.5 text-center font-bold">%</th></tr>
        </thead>
        <tbody class="divide-y divide-garis">
          <tr v-for="({ s, r }, i) in data" :key="s.id">
            <td class="px-3 py-2 tabular-nums text-teks3">{{ i + 1 }}</td>
            <td class="px-3 py-2"><router-link :to="`/santri/${s.id}`" class="font-semibold hover:underline">{{ s.nama_lengkap }}</router-link></td>
            <td v-for="j in jenisTampil" :key="j" class="px-3 py-2 text-center tabular-nums">{{ sel(r, j) }}</td>
            <td class="px-3 py-2 text-center tabular-nums">{{ r?.pokok.izin || '' }}</td><td class="px-3 py-2 text-center tabular-nums">{{ r?.pokok.sakit || '' }}</td>
            <td class="px-3 py-2 text-center tabular-nums">{{ r?.pokok.bolos || '' }}</td><td class="px-3 py-2 text-center tabular-nums font-semibold text-merah">{{ r?.pokok.absen || '' }}</td>
            <td class="px-3 py-2 text-center tabular-nums">{{ r?.pokok.terlambat || '' }}</td>
            <td class="px-3 py-2 text-center font-bold tabular-nums">{{ teksPersen(persen(r?.pokok.hadir, r?.pokok.sesi)) }}</td>
          </tr>
        </tbody>
      </table>
      <p v-if="!data.length && !memuat" class="py-8 text-center text-sm text-teks3">Belum ada anggota atau data absensi pada periode ini.</p>
      <p class="p-4 text-xs text-teks3">Angka kolom kegiatan = hadir/sesi terlaksana. Terlambat dan Bolos dihitung hadir; Izin, Sakit, dan Absen mengurangi persentase. Sesi yang tidak diisi pengampu tidak dihitung.</p>
    </div>

    <DokumenCetak v-if="g" :kop="g.jenis === 'kelas' ? g.jenjang : 'pondok'" judul="Rekap Kehadiran Santri" :subjudul="`${judulKelompok(g)} · ${teksPeriode}`" mendatar
      v-model:pratinjau="pratinjau" :pencetak="sesi.pengguna?.nama_lengkap">
      <table class="tabel kecil">
        <thead><tr><th style="width:4%">No.</th><th style="width:9%">NIS</th><th>Nama</th>
          <th v-for="j in jenisTampil" :key="j" style="width:9%">{{ JENIS_ABSENSI[j].n }} (hadir/sesi)</th>
          <th style="width:6%">Izin</th><th style="width:6%">Sakit</th><th style="width:6%">Bolos</th><th style="width:6%">Absen</th><th style="width:7%">Terlambat</th><th style="width:8%">Kehadiran</th></tr></thead>
        <tbody>
          <tr v-for="({ s, r }, i) in data" :key="s.id">
            <td class="tengah">{{ i + 1 }}</td><td class="tengah">{{ s.nis }}</td><td>{{ s.nama_lengkap }}</td>
            <td v-for="j in jenisTampil" :key="j" class="tengah">{{ sel(r, j) }}</td>
            <td class="tengah">{{ r?.pokok.izin || 0 }}</td><td class="tengah">{{ r?.pokok.sakit || 0 }}</td><td class="tengah">{{ r?.pokok.bolos || 0 }}</td>
            <td class="tengah">{{ r?.pokok.absen || 0 }}</td><td class="tengah">{{ r?.pokok.terlambat || 0 }}</td><td class="tengah">{{ teksPersen(persen(r?.pokok.hadir, r?.pokok.sesi)) }}</td>
          </tr>
        </tbody>
      </table>
      <p style="margin-top: 4pt; font-size: 9pt">Keterangan: kehadiran = (sesi − Izin − Sakit − Absen) ÷ sesi terlaksana; Terlambat dan Bolos dihitung hadir. Rata-rata kehadiran program pokok {{ teksPersen(rataRata) }}.</p>
      <template #ttd>
        <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: penanda.jabatan, nama: penanda.nama, niy: penanda.niy }"
          :kanan="{ jabatan: JENIS_KELOMPOK[g.jenis]?.pengasuh, nama: pengasuhUtama?.nama || '', niy: pengasuhUtama?.niy }" />
      </template>
    </DokumenCetak>

    <LembarBawah v-model="lembarWA" judul="WA rekap ke wali santri">
      <div class="pb-2"><p class="mb-3 text-sm text-teks2">Pesan per santri ke orang tua/wali utama: {{ teksPeriode }}.</p>
        <DaftarKirimWA :penerima="penerimaWA" :pesan="pesanKe" :kunci="`rekap-${groupId}-${mulai}-${selesai}`" /></div>
    </LembarBawah>
  </div>
</template>
