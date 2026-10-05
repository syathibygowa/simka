<!-- SIMKA PRO | src/pages/musyrif/TabRekapMusyrif.vue | v1.0 | Fase 6 – Tahap M1 Menu Musyrif | 06/10/2026 -->
<script setup>
// Rekap kehadiran asrama satu kamar. Empat tampilan:
//   kamar   : per santri pada rentang (sesi, hadir, I, S, B, A, T, %)
//   pekan   : per santri per pekan (Senin–Ahad) pada rentang
//   bulan   : per santri per bulan pada rentang
//   individu: satu santri — ringkasan, matriks tanggal × sesi, daftar ketidakhadiran
// Periode cepat (hari ini, pekan ini/lalu, bulan ini/lalu) atau rentang bebas. Excel, cetak F4,
// WA rekap ke wali per santri, dan salin rekap kamar untuk grup WA (ringkas atau rinci per santri).
import { ref, computed, watch, onMounted } from 'vue'
import * as XLSX from 'xlsx'
import { PhDownloadSimple, PhEye, PhWhatsappLogo, PhCopy, PhUsersThree, PhCalendarDots, PhCalendarBlank, PhUser, PhArrowSquareOut } from '@phosphor-icons/vue'
import { useMusyrif } from '@/stores/musyrif'
import { useSantri } from '@/stores/santri'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { KODE, teksPersen, persen } from '@/lib/absensi'
import { kontakUtama, penandaKelompok } from '@/lib/santri'
import { hariIniISO, formatPendek } from '@/lib/tanggal'
import { pesanWA, tautanWA } from '@/lib/wa'
import {
  olahRinci, ringkasKamar, bagiPeriode, daftarTanggal, hadirDari, persenDari, teksRekapSantri, teksTidakHadir, teksRentang,
  awalPekan, awalBulanDari, akhirBulanDari, tambahHari, namaHari, teksKode,
} from '@/lib/musyrif'
import BilahTab from '@/components/BilahTab.vue'
import InputTanggal from '@/components/InputTanggal.vue'
import LembarBawah from '@/components/LembarBawah.vue'
import DaftarKirimWA from '@/components/DaftarKirimWA.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'

const props = defineProps({ santriAwal: { type: String, default: '' } })
const mu = useMusyrif(); const san = useSantri(); const sesi = useSesi(); const ui = useUI()
const mode = ref(props.santriAwal ? 'individu' : 'kamar')
const MODE = [{ k: 'kamar', n: 'Per santri', ikon: PhUsersThree, w: 'santri' }, { k: 'pekan', n: 'Per pekan', ikon: PhCalendarDots, w: 'agenda' },
  { k: 'bulan', n: 'Per bulan', ikon: PhCalendarBlank, w: 'laporan' }, { k: 'individu', n: 'Individu', ikon: PhUser, w: 'profil' }]
const hari = hariIniISO()
const mulai = ref(awalBulanDari(hari)); const selesai = ref(hari); const d = ref(null); const memuat = ref(false)
const santriPilih = ref(props.santriAwal || ''); const penanda = ref({ jabatan: '', nama: '', niy: '' })

const PRESET = computed(() => {
  const ap = awalPekan(hari); const bl = tambahHari(awalBulanDari(hari), -1)
  return [{ k: 'hari', n: 'Hari ini', m: hari, s: hari }, { k: 'pekan', n: 'Pekan ini', m: ap, s: hari },
    { k: 'pekanlalu', n: 'Pekan lalu', m: tambahHari(ap, -7), s: tambahHari(ap, -1) }, { k: 'bulan', n: 'Bulan ini', m: awalBulanDari(hari), s: hari },
    { k: 'bulanlalu', n: 'Bulan lalu', m: awalBulanDari(bl), s: akhirBulanDari(bl) }]
})
const presetAktif = computed(() => PRESET.value.find((p) => p.m === mulai.value && p.s === selesai.value)?.k)
function pakai(p) { mulai.value = p.m; selesai.value = p.s }

async function muat() {
  if (!mu.pilih || !mulai.value || !selesai.value) return
  if (selesai.value < mulai.value) return ui.toast('Tanggal akhir sebelum tanggal awal.', 'galat')
  memuat.value = true
  try {
    d.value = await mu.rinci(mu.pilih, mulai.value, selesai.value)
    if (!santriPilih.value || !d.value.santri.some((s) => s.id === santriPilih.value)) santriPilih.value = d.value.santri[0]?.id || ''
    penanda.value = await penandaKelompok({ jenis: 'kamar' })
  } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false }
}
onMounted(async () => { await san.muat(); muat() })
watch(() => [mu.pilih, mulai.value, selesai.value], muat)

const kamar = computed(() => mu.kamarPilih)
const o = computed(() => olahRinci(d.value))
const ringkas = computed(() => ringkasKamar(d.value, o.value))
const santri = computed(() => d.value?.santri || [])
const totalDari = (id) => o.value.perSantri[id]?.total || { sesi: 0, H: 0, I: 0, S: 0, B: 0, A: 0, T: 0 }
const teksPeriode = computed(() => teksRentang(mulai.value, selesai.value))
const musyrifUtama = computed(() => kamar.value?.musyrif.find((m) => m.peran === 'utama') || kamar.value?.musyrif[0] || null)
const pengasuhSaya = computed(() => kamar.value?.musyrif.find((m) => m.employee_id === sesi.pengguna?.id) || musyrifUtama.value)

// ---------- Per pekan / per bulan ----------
const periode = computed(() => (mode.value === 'pekan' || mode.value === 'bulan' ? bagiPeriode(mulai.value, selesai.value, mode.value) : []))
const olahPeriode = computed(() => periode.value.map((p) => ({ ...p, o: olahRinci(d.value, (s) => s.tanggal >= p.mulai && s.tanggal <= p.selesai) })))
const selPeriode = (op, id) => { const r = op.o.perSantri[id]?.total; return r?.sesi ? { teks: teksPersen(persenDari(r)), sub: `${hadirDari(r)}/${r.sesi}`, p: persenDari(r) } : null }
const rataPeriode = (op) => ringkasKamar(d.value, op.o).persen

// ---------- Individu ----------
const sIndividu = computed(() => santri.value.find((s) => s.id === santriPilih.value) || null)
const tanggalMatriks = computed(() => daftarTanggal(mulai.value, selesai.value > hari ? hari : selesai.value).reverse())
const kodeSesi = computed(() => [...new Set((d.value?.rencana || []).map((r) => r.sesi).concat((d.value?.sesi || []).map((s) => s.sesi)))])
const namaSesi = (k) => (d.value?.rencana || []).find((r) => r.sesi === k)?.nama_sesi || d.value?.sesi.find((s) => s.sesi === k)?.nama_sesi || k
const selIndividu = (t, k) => o.value.sel[`${santriPilih.value}|${t}|${k}`] || null
const tidakIndividu = computed(() => [...(o.value.perSantri[santriPilih.value]?.tidak || [])].sort((a, b) => b.tanggal.localeCompare(a.tanggal)))
const diisiPada = (t, k) => (d.value?.sesi || []).some((s) => s.tanggal === t && s.sesi === k)
const warnaPersen = (p) => (p == null ? '' : p >= 95 ? 'w-presensi' : p >= 85 ? 'w-agenda' : p >= 75 ? 'w-laporan' : 'w-klinik')

// ---------- WA ke wali ----------
const lembarWA = ref(false)
const dataSantri = (id) => san.cari(id)
const penerimaWA = computed(() => santri.value.map((s) => {
  const x = dataSantri(s.id); const k = x ? kontakUtama(x) : null; const r = totalDari(s.id)
  return { employee_id: s.id, nama: s.nama, no_hp: k?.no_hp || null, unit: teksRekapSantri(r), keterangan: k ? `wali: ${k.nama || '–'}` : 'kontak wali belum ada', k, r, tidak: o.value.perSantri[s.id]?.tidak || [] }
}))
const pesanWali = (p) => pesanWA('rekap_asrama', { nama_wali: p.k?.nama || 'orang tua/wali', nama_santri: p.nama, kamar: kamar.value?.nama, periode: teksPeriode.value,
  rekap: teksRekapSantri(p.r), ketidakhadiran: teksTidakHadir(p.tidak), pengirim: sesi.pengguna?.nama_lengkap, jabatan_pengirim: `Musyrif ${kamar.value?.nama || ''}`.trim() })
function waIndividu() {
  const p = penerimaWA.value.find((x) => x.employee_id === santriPilih.value)
  if (!p?.no_hp) return ui.toast('Nomor HP orang tua/wali santri ini belum diisi di Data Santri.', 'galat')
  window.open(tautanWA(p.no_hp, pesanWali(p)), '_blank', 'noopener')
}

// ---------- Salin untuk grup WA ----------
const lembarGrup = ref(false); const gayaGrup = ref('rinci'); const tampilAlasan = ref(false)
const teksGrup = computed(() => {
  const baris = santri.value.filter((s) => totalDari(s.id).sesi).map((s, i) => {
    const r = totalDari(s.id); const lain = ['I', 'S', 'A', 'B', 'T'].filter((k) => r[k]).map((k) => `${k}${r[k]}`)
    return `${i + 1}. ${s.nama} — ${hadirDari(r)}/${r.sesi} (${teksPersen(persenDari(r))})${lain.length ? ' · ' + lain.join(' ') : ''}`
  })
  const rincian = gayaGrup.value === 'rinci' ? `\nRincian per santri (hadir/sesi):\n${baris.join('\n')}\n\nKeterangan: I = izin, S = sakit, A = absen, B = bolos, T = terlambat.` : '\nRincian per santri dapat ditanyakan langsung kepada musyrif.'
  return pesanWA('rekap_kamar', { kamar: kamar.value?.nama, periode: teksPeriode.value, persen: teksPersen(ringkas.value.persen), jumlah_sesi: `${ringkas.value.sesi} sesi`,
    hadir_penuh: `${ringkas.value.penuh} dari ${ringkas.value.santri} santri`, rincian, pengirim: sesi.pengguna?.nama_lengkap, jabatan_pengirim: `Musyrif ${kamar.value?.nama || ''}`.trim() })
})
const teksSunting = ref('')
watch([lembarGrup, gayaGrup], () => { if (lembarGrup.value) teksSunting.value = teksGrup.value })
async function salin(buka) {
  try { await navigator.clipboard.writeText(teksSunting.value); ui.toast(buka ? 'Rekap disalin. Grup WA dibuka; tempel di sana.' : 'Rekap disalin. Tempel di grup WA.') }
  catch { ui.toast('Tidak dapat menyalin otomatis. Tekan lama teks lalu pilih Salin.', 'galat'); return }
  if (buka) window.open(buka, '_blank', 'noopener')
}

// ---------- Excel ----------
function ekspor() {
  const wb = XLSX.utils.book_new(); const judul = `Rekap kehadiran asrama ${kamar.value?.nama} – ${teksPeriode.value}`
  if (mode.value === 'individu' && sIndividu.value) {
    const isi = tanggalMatriks.value.map((t) => [formatPendek(t), namaHari(t), ...kodeSesi.value.map((k) => selIndividu(t, k)?.kode || (diisiPada(t, k) ? '' : 'tidak diisi'))])
    const ws = XLSX.utils.aoa_to_sheet([[`${judul} – ${sIndividu.value.nama}`], [], ['Tanggal', 'Hari', ...kodeSesi.value.map(namaSesi)], ...isi])
    XLSX.utils.book_append_sheet(wb, ws, 'Individu')
  } else if (mode.value === 'kamar') {
    const kolom = ['No.', 'NIS', 'Nama', 'Sesi', 'Hadir', 'Izin', 'Sakit', 'Bolos', 'Absen', 'Terlambat', 'Kehadiran (%)']
    const isi = santri.value.map((s, i) => { const r = totalDari(s.id); return [i + 1, s.nis, s.nama, r.sesi, hadirDari(r), r.I, r.S, r.B, r.A, r.T, persenDari(r) ?? ''] })
    const ws = XLSX.utils.aoa_to_sheet([[judul], [], kolom, ...isi]); ws['!cols'] = kolom.map((k, i) => ({ wch: i === 2 ? 30 : 10 }))
    XLSX.utils.book_append_sheet(wb, ws, 'Per santri')
  } else {
    const kolom = ['No.', 'NIS', 'Nama', ...olahPeriode.value.map((p) => `${p.n} (%)`)]
    const isi = santri.value.map((s, i) => [i + 1, s.nis, s.nama, ...olahPeriode.value.map((p) => selPeriode(p, s.id)?.p ?? '')])
    const ws = XLSX.utils.aoa_to_sheet([[judul], [], kolom, ...isi, ['', '', 'Rata-rata kamar', ...olahPeriode.value.map((p) => rataPeriode(p) ?? '')]])
    XLSX.utils.book_append_sheet(wb, ws, mode.value === 'pekan' ? 'Per pekan' : 'Per bulan')
  }
  XLSX.writeFile(wb, `Rekap-Asrama-${(kamar.value?.nama || '').replace(/[^\w.-]+/g, '-')}-${formatPendek(mulai.value).replace(/\//g, '')}-${formatPendek(selesai.value).replace(/\//g, '')}.xlsx`)
}

// ---------- Cetak ----------
const pratinjau = ref(false)
const judulCetak = computed(() => (mode.value === 'individu' ? 'Rekap Kehadiran Asrama Santri' : 'Rekap Kehadiran Asrama'))
const subjudulCetak = computed(() => `${kamar.value?.nama || ''} · ${teksPeriode.value}${mode.value === 'pekan' ? ' · per pekan' : mode.value === 'bulan' ? ' · per bulan' : ''}`)
</script>
<template>
  <div>
    <div class="kartu mb-4 space-y-3 p-4">
      <div class="flex flex-wrap gap-2">
        <button v-for="p in PRESET" :key="p.k" :class="['min-h-[36px] rounded-full border px-3 text-sm font-semibold', presetAktif === p.k ? 'border-transparent bg-[#245E3F] text-white' : 'border-garis bg-permukaan text-teks2']" @click="pakai(p)">{{ p.n }}</button>
      </div>
      <div class="grid grid-cols-2 gap-3 sm:max-w-md"><InputTanggal v-model="mulai" label="Dari" wajib /><InputTanggal v-model="selesai" label="Sampai" wajib /></div>
    </div>

    <BilahTab v-model="mode" class="mb-3" :tab="MODE" label="Tampilan rekap" />

    <div class="-mx-4 mb-4 flex gap-2 overflow-x-auto px-4 pb-1 lg:mx-0 lg:px-0">
      <button class="w-presensi tombol-garis shrink-0 px-4 text-sm" @click="mode === 'individu' ? waIndividu() : (lembarWA = true)"><PhWhatsappLogo :size="20" weight="duotone" style="color: var(--c)" /> {{ mode === 'individu' ? 'WA ke wali santri ini' : 'WA rekap ke wali' }}</button>
      <button class="w-agenda tombol-garis shrink-0 px-4 text-sm" @click="lembarGrup = true"><PhCopy :size="20" weight="duotone" style="color: var(--c)" /> Salin untuk grup WA</button>
      <button class="w-pengajuan tombol-garis shrink-0 px-4 text-sm" @click="pratinjau = true"><PhEye :size="20" weight="duotone" style="color: var(--c)" /> Cetak</button>
      <button class="w-santri tombol-garis shrink-0 px-4 text-sm" @click="ekspor"><PhDownloadSimple :size="20" weight="duotone" style="color: var(--c)" /> Excel</button>
    </div>

    <p v-if="memuat && !d" class="kartu p-8 text-center text-sm text-teks3">Memuat rekap…</p>
    <template v-else-if="d">
      <div class="kartu mb-4 flex flex-wrap items-center gap-2 p-4 text-sm">
        <b class="flex-1">{{ kamar?.nama }} · {{ teksPeriode }}</b>
        <span class="lencana" :class="warnaPersen(ringkas.persen)">Rata-rata {{ teksPersen(ringkas.persen) }}</span>
        <span class="lencana w-agenda">{{ ringkas.sesi }} sesi</span>
        <span class="lencana w-presensi">{{ ringkas.penuh }}/{{ ringkas.santri }} hadir penuh</span>
        <span v-if="o.tidakDiisi.length" class="lencana w-klinik">{{ o.tidakDiisi.length }} sesi tidak diisi</span>
      </div>

      <!-- Per santri -->
      <div v-if="mode === 'kamar'" class="kartu overflow-x-auto">
        <table class="w-full min-w-[620px] text-left text-sm">
          <thead class="border-b border-garis bg-permukaan2 text-teks2"><tr>
            <th class="px-3 py-2.5 font-bold">No.</th><th class="px-3 py-2.5 font-bold">Nama</th><th class="px-3 py-2.5 text-center font-bold">Hadir/sesi</th>
            <th v-for="k in ['I', 'S', 'B', 'A', 'T']" :key="k" class="px-3 py-2.5 text-center font-bold" :title="KODE[k].n">{{ k }}</th><th class="px-3 py-2.5 text-center font-bold">%</th></tr></thead>
          <tbody class="divide-y divide-garis">
            <tr v-for="(s, i) in santri" :key="s.id">
              <td class="px-3 py-2 tabular-nums text-teks3">{{ i + 1 }}</td>
              <td class="px-3 py-2"><button class="text-left font-semibold hover:underline" @click="santriPilih = s.id; mode = 'individu'">{{ s.nama }}</button>
                <span v-if="!s.aktif_di_kamar" class="lencana w-hakakses ml-1">pindah</span></td>
              <td class="px-3 py-2 text-center tabular-nums">{{ totalDari(s.id).sesi ? `${hadirDari(totalDari(s.id))}/${totalDari(s.id).sesi}` : '–' }}</td>
              <td v-for="k in ['I', 'S', 'B', 'A', 'T']" :key="k" class="px-3 py-2 text-center tabular-nums" :class="k === 'A' && totalDari(s.id)[k] ? 'font-bold text-merah' : ''">{{ totalDari(s.id)[k] || '' }}</td>
              <td class="px-3 py-2 text-center"><span class="lencana" :class="warnaPersen(persenDari(totalDari(s.id)))">{{ teksPersen(persenDari(totalDari(s.id))) }}</span></td>
            </tr>
          </tbody>
        </table>
        <p v-if="!santri.length" class="py-8 text-center text-sm text-teks3">Belum ada santri di kamar ini.</p>
        <p class="p-4 text-xs text-teks3">Kehadiran = (sesi − Izin − Sakit − Absen) ÷ sesi terlaksana. Terlambat dan Bolos dihitung hadir. Ketuk nama untuk rekap individu.</p>
      </div>

      <!-- Per pekan / per bulan -->
      <div v-else-if="mode === 'pekan' || mode === 'bulan'" class="kartu overflow-x-auto">
        <table class="w-full text-left text-sm" :style="{ minWidth: 260 + olahPeriode.length * 96 + 'px' }">
          <thead class="border-b border-garis bg-permukaan2 text-teks2"><tr><th class="sticky left-0 bg-permukaan2 px-3 py-2.5 font-bold">Nama</th>
            <th v-for="p in olahPeriode" :key="p.k" class="px-2 py-2.5 text-center font-bold">{{ p.n }}</th></tr></thead>
          <tbody class="divide-y divide-garis">
            <tr v-for="s in santri" :key="s.id">
              <td class="sticky left-0 bg-permukaan px-3 py-2"><button class="text-left font-semibold hover:underline" @click="santriPilih = s.id; mode = 'individu'">{{ s.nama }}</button></td>
              <td v-for="p in olahPeriode" :key="p.k" class="px-2 py-2 text-center">
                <template v-if="selPeriode(p, s.id)"><span class="lencana" :class="warnaPersen(selPeriode(p, s.id).p)">{{ selPeriode(p, s.id).teks }}</span>
                  <span class="block text-[11px] text-teks3 tabular-nums">{{ selPeriode(p, s.id).sub }}</span></template>
                <span v-else class="text-teks3">–</span></td>
            </tr>
            <tr class="bg-permukaan2 font-bold"><td class="sticky left-0 bg-permukaan2 px-3 py-2">Rata-rata kamar</td>
              <td v-for="p in olahPeriode" :key="p.k" class="px-2 py-2 text-center tabular-nums">{{ teksPersen(rataPeriode(p)) }}</td></tr>
          </tbody>
        </table>
      </div>

      <!-- Individu -->
      <div v-else class="space-y-4">
        <div class="kartu p-4">
          <label class="label-isian" for="rk-sn">Santri</label>
          <select id="rk-sn" v-model="santriPilih" class="isian"><option v-for="s in santri" :key="s.id" :value="s.id">{{ s.nama }} · {{ s.nis }}</option></select>
          <template v-if="sIndividu">
            <div class="mt-3 grid grid-cols-3 gap-2 text-center sm:grid-cols-7">
              <div class="rounded-xl bg-permukaan2 p-2" :class="warnaPersen(persenDari(totalDari(santriPilih)))"><b class="block text-xl tabular-nums" style="color: var(--c)">{{ teksPersen(persenDari(totalDari(santriPilih))) }}</b><span class="text-xs text-teks2">Kehadiran</span></div>
              <div class="rounded-xl bg-permukaan2 p-2"><b class="block text-xl tabular-nums">{{ hadirDari(totalDari(santriPilih)) }}/{{ totalDari(santriPilih).sesi }}</b><span class="text-xs text-teks2">Hadir/sesi</span></div>
              <div v-for="k in ['I', 'S', 'B', 'A', 'T']" :key="k" class="rounded-xl bg-permukaan2 p-2" :class="'w-' + KODE[k].w"><b class="block text-xl tabular-nums" style="color: var(--c)">{{ totalDari(santriPilih)[k] }}</b><span class="text-xs text-teks2">{{ KODE[k].n }}</span></div>
            </div>
            <div class="mt-3 flex flex-wrap gap-2">
              <button class="tombol-utama min-h-[40px] px-4 text-sm" @click="waIndividu"><PhWhatsappLogo :size="18" weight="duotone" /> WA rekap ke wali</button>
              <router-link :to="`/santri/${santriPilih}`" class="tombol-garis min-h-[40px] px-4 text-sm"><PhArrowSquareOut :size="18" /> Profil santri</router-link>
            </div>
          </template>
        </div>
        <div v-if="sIndividu" class="kartu overflow-x-auto">
          <table class="w-full min-w-[360px] text-sm">
            <thead class="border-b border-garis bg-permukaan2 text-teks2"><tr><th class="px-3 py-2.5 text-left font-bold">Tanggal</th>
              <th v-for="k in kodeSesi" :key="k" class="px-3 py-2.5 text-center font-bold">{{ namaSesi(k) }}</th></tr></thead>
            <tbody class="divide-y divide-garis">
              <tr v-for="t in tanggalMatriks" :key="t">
                <td class="px-3 py-2 text-left"><b>{{ namaHari(t) }}</b> <span class="tabular-nums text-teks3">{{ formatPendek(t) }}</span></td>
                <td v-for="k in kodeSesi" :key="k" class="px-3 py-2 text-center">
                  <span v-if="selIndividu(t, k)" class="lencana" :class="'w-' + KODE[selIndividu(t, k).kode].w" :title="selIndividu(t, k).ket || ''">{{ KODE[selIndividu(t, k).kode].n }}</span>
                  <span v-else-if="diisiPada(t, k)" class="text-xs text-teks3">bukan anggota</span>
                  <span v-else class="text-xs text-teks3">–</span></td>
              </tr>
            </tbody>
          </table>
          <p class="p-4 text-xs text-teks3">"–" = sesi belum/tidak diisi atau belum berlangsung.</p>
        </div>
        <div v-if="sIndividu" class="kartu p-4">
          <h3 class="mb-2 text-sm font-bold">Ketidakhadiran ({{ tidakIndividu.length }})</h3>
          <ul class="divide-y divide-garis text-sm">
            <li v-for="(x, i) in tidakIndividu" :key="i" class="flex items-center gap-2 py-2">
              <span class="lencana" :class="'w-' + KODE[x.kode].w">{{ teksKode[x.kode] }}</span>
              <span class="flex-1">{{ namaHari(x.tanggal) }}, {{ formatPendek(x.tanggal) }} · {{ x.nama_sesi }}<span v-if="x.ket" class="block text-xs text-teks3">{{ x.ket }}</span></span></li>
            <li v-if="!tidakIndividu.length" class="py-3 text-center text-teks3">Alhamdulillah, hadir penuh pada periode ini.</li>
          </ul>
        </div>
      </div>
    </template>

    <!-- WA ke wali -->
    <LembarBawah v-model="lembarWA" judul="WA rekap asrama ke wali">
      <div class="pb-2"><p class="mb-3 text-sm text-teks2">Pesan per santri ke orang tua/wali utama, periode {{ teksPeriode }}. Pesan memuat ringkasan dan tanggal ketidakhadiran (tanpa keterangan sakit).</p>
        <DaftarKirimWA :penerima="penerimaWA" :pesan="pesanWali" :kunci="`asrama-${mu.pilih}-${mulai}-${selesai}`"
          :saringan="[{ k: 'semua', n: 'Semua', f: () => true }, { k: 'tidak', n: 'Ada ketidakhadiran', f: (p) => p.tidak.some((x) => ['I', 'S', 'A'].includes(x.kode)) }, { k: 'absen', n: 'Ada Absen', f: (p) => p.r.A > 0 }]" /></div>
    </LembarBawah>

    <!-- Salin grup -->
    <LembarBawah v-model="lembarGrup" judul="Salin rekap untuk grup WA">
      <div class="space-y-3 pb-2">
        <div class="grid grid-cols-2 gap-1 rounded-2xl bg-permukaan2 p-1" role="radiogroup" aria-label="Isi rekap">
          <button v-for="g in [{ k: 'rinci', n: 'Rinci per santri' }, { k: 'ringkas', n: 'Ringkas' }]" :key="g.k" type="button" role="radio" :aria-checked="gayaGrup === g.k" @click="gayaGrup = g.k"
            :class="['min-h-[40px] rounded-xl text-sm font-semibold', gayaGrup === g.k ? 'bg-permukaan text-teks shadow-kartu' : 'text-teks2']">{{ g.n }}</button></div>
        <textarea v-model="teksSunting" rows="12" class="isian font-mono text-xs leading-relaxed" aria-label="Teks rekap untuk grup WA" />
        <p class="text-xs text-teks3">Teks dapat disunting sebelum disalin. Keterangan sakit atau alasan pribadi santri tidak dicantumkan.</p>
        <div class="grid gap-2 sm:grid-cols-2">
          <button class="tombol-utama" @click="salin(null)"><PhCopy :size="20" weight="duotone" /> Salin teks</button>
          <button v-if="kamar?.wa_wali" class="tombol-garis w-presensi" @click="salin(kamar.wa_wali)"><PhWhatsappLogo :size="20" weight="duotone" style="color: var(--c)" /> Salin & buka grup wali</button>
          <button v-if="kamar?.wa_internal" class="tombol-garis w-agenda" @click="salin(kamar.wa_internal)"><PhWhatsappLogo :size="20" weight="duotone" style="color: var(--c)" /> Salin & buka grup internal</button>
        </div>
        <p v-if="!kamar?.wa_wali && !kamar?.wa_internal" class="text-xs text-teks3">Tautan grup WA kamar dapat diisi di Kelompok Santri → kamar ini → Ubah.</p>
      </div>
    </LembarBawah>

    <!-- Cetak -->
    <DokumenCetak v-if="d" kop="pondok" :judul="judulCetak" :subjudul="subjudulCetak" :mendatar="mode === 'pekan' || mode === 'bulan'" v-model:pratinjau="pratinjau" :pencetak="sesi.pengguna?.nama_lengkap">
      <template v-if="mode === 'individu' && sIndividu">
        <table class="tabel info"><tbody>
          <tr><td style="width:28%">Nama santri</td><td>{{ sIndividu.nama }}</td></tr><tr><td>NIS</td><td>{{ sIndividu.nis }}</td></tr>
          <tr><td>Kamar</td><td>{{ kamar?.nama }}</td></tr><tr><td>Periode</td><td>{{ teksPeriode }}</td></tr>
          <tr><td>Ringkasan</td><td>{{ teksRekapSantri(totalDari(santriPilih)) }}</td></tr></tbody></table>
        <table class="tabel kecil" style="margin-top: 8pt">
          <thead><tr><th style="width:5%">No.</th><th style="width:30%">Hari, tanggal</th><th v-for="k in kodeSesi" :key="k">{{ namaSesi(k) }}</th></tr></thead>
          <tbody><tr v-for="(t, i) in [...tanggalMatriks].reverse()" :key="t"><td class="tengah">{{ i + 1 }}</td><td>{{ namaHari(t) }}, {{ formatPendek(t) }}</td>
            <td v-for="k in kodeSesi" :key="k" class="tengah">{{ selIndividu(t, k) ? KODE[selIndividu(t, k).kode].n : '–' }}</td></tr></tbody>
        </table>
      </template>
      <table v-else-if="mode === 'kamar'" class="tabel kecil">
        <thead><tr><th style="width:5%">No.</th><th style="width:11%">NIS</th><th>Nama</th><th style="width:7%">Sesi</th><th style="width:7%">Hadir</th>
          <th style="width:7%">Izin</th><th style="width:7%">Sakit</th><th style="width:7%">Bolos</th><th style="width:7%">Absen</th><th style="width:8%">Terlambat</th><th style="width:9%">Kehadiran</th></tr></thead>
        <tbody><tr v-for="(s, i) in santri" :key="s.id"><td class="tengah">{{ i + 1 }}</td><td class="tengah">{{ s.nis }}</td><td>{{ s.nama }}</td>
          <td class="tengah">{{ totalDari(s.id).sesi }}</td><td class="tengah">{{ hadirDari(totalDari(s.id)) }}</td>
          <td v-for="k in ['I', 'S', 'B', 'A', 'T']" :key="k" class="tengah">{{ totalDari(s.id)[k] }}</td><td class="tengah">{{ teksPersen(persenDari(totalDari(s.id))) }}</td></tr></tbody>
      </table>
      <table v-else class="tabel kecil">
        <thead><tr><th style="width:4%">No.</th><th style="width:22%">Nama</th><th v-for="p in olahPeriode" :key="p.k">{{ p.n }}</th></tr></thead>
        <tbody><tr v-for="(s, i) in santri" :key="s.id"><td class="tengah">{{ i + 1 }}</td><td>{{ s.nama }}</td>
            <td v-for="p in olahPeriode" :key="p.k" class="tengah">{{ selPeriode(p, s.id) ? `${selPeriode(p, s.id).teks} (${selPeriode(p, s.id).sub})` : '–' }}</td></tr>
          <tr><td></td><td>Rata-rata kamar</td><td v-for="p in olahPeriode" :key="p.k" class="tengah">{{ teksPersen(rataPeriode(p)) }}</td></tr></tbody>
      </table>
      <p style="margin-top: 4pt; font-size: 9pt">Keterangan: kehadiran = (sesi − Izin − Sakit − Absen) ÷ sesi terlaksana; Terlambat dan Bolos dihitung hadir. Rata-rata kamar {{ teksPersen(ringkas.persen) }}; {{ ringkas.sesi }} sesi terlaksana.</p>
      <template #ttd>
        <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: penanda.jabatan, nama: penanda.nama, niy: penanda.niy }"
          :kanan="{ jabatan: 'Musyrif ' + (kamar?.nama || ''), nama: pengasuhSaya?.nama || '', niy: pengasuhSaya?.niy }" />
      </template>
    </DokumenCetak>
  </div>
</template>
