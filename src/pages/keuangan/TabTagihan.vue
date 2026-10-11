<!-- SIMKA PRO | src/pages/keuangan/TabTagihan.vue | v1.2 | Fase 13 – Tagihan tahun ajaran lalu, sasaran putra/putri, impor catatan lama | 12/10/2026 -->
<script setup>
// Buat tagihan massal: pilih jenis biaya → periode (bulan-bulan untuk bulanan; tahun ajaran untuk tahunan; sekali)
// → sasaran (jenjang, tingkat, santri baru saja, atau santri tertentu) → pratinjau (standar, subsidi, tagihan, sudah ada)
// → buat. Tagihan yang sudah ada (santri + jenis + periode) otomatis dilewati.
// Daftar tagihan: saring jenis, periode, status, kelompok; ekspor Excel; ketuk baris membuka rincian santri.
// v1.1: siklus semesteran; sasaran kelas/kamar/halaqah tertentu; sesudah tagihan dibuat → kabari wali (WA "tagihan baru");
//       saringan "Segera jatuh tempo"/"Lewat jatuh tempo" → WA pengingat/tunggakan berurutan ke wali.
// v1.2: tahun ajaran tagihan dapat dipilih mundur dua tahun (kelas santri saat itu dihitung server); sasaran putra/putri;
//       tombol "Impor catatan lama" (Excel) untuk tagihan dan pembayaran tahun-tahun lalu.
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import * as XLSX from 'xlsx'
import { PhPlus, PhEye, PhCheckCircle, PhFileXls, PhMagnifyingGlass, PhInvoice, PhX, PhWhatsappLogo, PhClockCounterClockwise, PhInfo } from '@phosphor-icons/vue'
import { useKeuangan } from '@/stores/keuangan'
import { useLembaga } from '@/stores/lembaga'
import { useUI } from '@/stores/ui'
import { formatPendek, hariIniISO } from '@/lib/tanggal'
import { rupiah, angka, SIKLUS, STATUS_TAGIHAN, JENJANG, TINGKAT, namaBulan, bulanTahunAjaran, perSantri, JK_SANTRI, labelTarif, tahunAjaranMundur, pesanTagihanBaru, pesanPengingat, pesanTunggakan } from '@/lib/keuangan'
import DaftarKirimWA from '@/components/DaftarKirimWA.vue'
import LembarBawah from '@/components/LembarBawah.vue'
import InputTanggal from '@/components/InputTanggal.vue'
import LembarImporRiwayat from './LembarImporRiwayat.vue'

const emit = defineEmits(['berubah'])
const keu = useKeuangan(); const lembaga = useLembaga(); const ui = useUI(); const router = useRouter(); const route = useRoute()
const daftar = ref([]); const memuat = ref(true)
const saring = ref({ fee_type_id: '', kunci_periode: '', status: typeof route.query.status === 'string' ? route.query.status : '', q: '', group_id: '' })
const kelompok = ref([])
const JENIS_KEL = { kelas: 'Kelas', kamar: 'Kamar', halaqah: 'Halaqah' }
async function muat() {
  memuat.value = true
  try { daftar.value = await keu.daftarTagihan({ fee_type_id: saring.value.fee_type_id, kunci_periode: saring.value.kunci_periode, status: saring.value.status, group_id: saring.value.group_id }) }
  catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false }
}
onMounted(() => { muat(); lembaga.muat(); if (route.query.buat) mulai(); keu.kelompok().then((k) => { kelompok.value = k }).catch(() => {}) })
watch(() => [saring.value.fee_type_id, saring.value.kunci_periode, saring.value.status, saring.value.group_id], muat)
watch(() => route.query.status, (v) => { if (typeof v === 'string') saring.value.status = v })
const periodeAda = computed(() => [...new Set(daftar.value.map((b) => b.kunci_periode))].sort())
const tampil = computed(() => { const c = saring.value.q.toLowerCase().trim(); return c ? daftar.value.filter((b) => b.nama.toLowerCase().includes(c) || b.nis.startsWith(c)) : daftar.value })
const jml = (k) => tampil.value.reduce((a, b) => a + Number(b[k] || 0), 0)
const STATUS = [{ k: '', n: 'Semua' }, { k: 'tunggak', n: 'Belum lunas' }, { k: 'segera', n: 'Segera jatuh tempo' }, { k: 'lewat', n: 'Lewat jatuh tempo' }, { k: 'lunas', n: 'Lunas' }, { k: 'batal', n: 'Dibatalkan' }]
const buka = (b) => router.replace({ query: { ...route.query, santri: b.student_id } })
const labelPeriode = (k) => (k === 'sekali' ? 'Sekali' : /-S[12]$/.test(k) ? `Semester ${k.endsWith('1') ? 'ganjil' : 'genap'} ${k.slice(0, 9)}` : namaBulan(k))

// ---------- Buat tagihan ----------
const f = ref(null); const pra = ref(null); const proses = ref(false); const cariSantri = ref(''); const semuaSantri = ref([])
const taAktif = computed(() => lembaga.tahunAktif?.nama || `${hariIniISO().slice(0, 4)}/${Number(hariIniISO().slice(0, 4)) + 1}`)
const BULAN_TA = computed(() => bulanTahunAjaran(f.value?.tahun_ajaran || taAktif.value))
const PILIH_TA = computed(() => [...new Set([...tahunAjaranMundur(taAktif.value, 2), ...(lembaga.academic_years || []).map((t) => t.nama)])].sort().reverse())
const taLalu = computed(() => f.value && f.value.tahun_ajaran < taAktif.value)
function gantiTA() { f.value.bulan = f.value.tahun_ajaran === taAktif.value ? [hariIniISO().slice(0, 7)] : []; pra.value = null }
const impor = ref(false)
function mulai() {
  f.value = { fee_type_id: keu.jenisAktif[0]?.id || '', bulan: [hariIniISO().slice(0, 7)], tahun_ajaran: taAktif.value, jatuh_tempo: '', jk: '',
    semester: lembaga.tahunAktif?.semester || 1, jenjang: '', tingkat: [], group_id: '', hanya_baru: false, santri: [], catatan: '' }
  pra.value = null; cariSantri.value = ''
}
const jenisPilih = computed(() => keu.jenis.find((j) => j.id === f.value?.fee_type_id))
watch(() => f.value?.fee_type_id, () => { if (f.value) { f.value.hanya_baru = !!jenisPilih.value?.santri_baru; pra.value = null } })
const toggle = (arr, v) => { const i = arr.indexOf(v); i >= 0 ? arr.splice(i, 1) : arr.push(v); pra.value = null }
const calon = computed(() => { const c = cariSantri.value.toLowerCase().trim(); return c ? semuaSantri.value.filter((s) => s.status === 'aktif' && (s.nama.toLowerCase().includes(c) || s.nis.startsWith(c)) && !f.value.santri.some((x) => x.id === s.id)).slice(0, 8) : [] })
watch(cariSantri, async (v) => { if (v && !semuaSantri.value.length) try { semuaSantri.value = await keu.santri({}) } catch { /* abaikan */ } })
const muatan = () => ({ fee_type_id: f.value.fee_type_id, bulan: jenisPilih.value?.siklus === 'bulanan' ? [...f.value.bulan].sort() : undefined,
  tahun_ajaran: f.value.tahun_ajaran, academic_year_id: (lembaga.academic_years || []).find((t) => t.nama === f.value.tahun_ajaran)?.id || undefined, semester: f.value.semester, jatuh_tempo: f.value.jatuh_tempo || undefined, catatan: f.value.catatan,
  sasaran: { jenjang: f.value.jenjang || undefined, tingkat: f.value.tingkat, jk: f.value.jk || undefined, group_id: f.value.group_id || undefined, hanya_baru: f.value.hanya_baru, student_ids: f.value.santri.map((s) => s.id) } })
async function pratinjau() {
  if (!f.value.fee_type_id) return ui.toast('Pilih jenis biaya.', 'galat')
  proses.value = true
  try { pra.value = await keu.pratinjauTagihan(muatan()) } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
const baru = computed(() => (pra.value?.baris || []).filter((x) => !x.ada))
async function buat() {
  if (!(await ui.konfirmasi({ judul: `Buat ${baru.value.length} tagihan?`, pesan: `${jenisPilih.value.nama}, jumlah ${rupiah(baru.value.reduce((a, x) => a + Number(x.nominal), 0))}. Tagihan yang sudah ada dilewati.`, ya: 'Buat tagihan' }))) return
  proses.value = true
  try {
    const kunci = pra.value.periode.map((x) => x.kunci); const fid = f.value.fee_type_id; const lalu = taLalu.value
    const r = await keu.buatTagihan(muatan()); ui.toast(`${r.dibuat} tagihan dibuat${r.dilewati ? `, ${r.dilewati} sudah ada` : ''}.`); f.value = null; await muat()   // tidak memicu muat ulang tab (agar lembar "Kabari wali" tetap terbuka)
    if (r.dibuat && !lalu) { const baruDibuat = await keu.daftarTagihan({ fee_type_id: fid, kunci, status: 'tunggak' }); kirim.value = { jenis: 'baru', santri: perSantri(baruDibuat) } }
  }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}

// ---------- WA ke wali ----------
const kirim = ref(null)   // { jenis: 'baru' | 'segera' | 'lewat', santri: [...] }
const bukaKirim = () => { kirim.value = { jenis: saring.value.status === 'segera' ? 'segera' : 'lewat', santri: perSantri(tampil.value.filter((b) => ['belum', 'sebagian'].includes(b.status))) } }
const JUDUL_KIRIM = { baru: 'Kabari wali: tagihan baru', segera: 'WA pengingat jatuh tempo', lewat: 'WA pemberitahuan tunggakan' }
const penerimaWA = computed(() => (kirim.value?.santri || []).map((x) => ({ employee_id: x.id, nama: `${x.wali?.nama || 'Wali'} – ${x.nama}`, no_hp: x.wali?.no_hp,
  unit: `${x.kelas || '–'} · ${rupiah(x.isi.reduce((a, b) => a + Number(b.sisa), 0))}`, x })))
const pesanKirim = (p) => (kirim.value.jenis === 'baru' ? pesanTagihanBaru : kirim.value.jenis === 'segera' ? pesanPengingat : pesanTunggakan)(p.x, p.x.isi, keu.pengaturan)

function ekspor() {
  const aoa = [['No.', 'NIS', 'Nama', 'JK', 'Kelas', 'Jenis', 'Tagihan', 'Jatuh tempo', 'Standar', 'Subsidi', 'Tagihan (Rp)', 'Dibayar', 'Sisa', 'Status', 'Keterangan subsidi'],
    ...tampil.value.map((b, i) => [i + 1, b.nis, b.nama, b.jk, b.kelas || '', b.jenis, b.tagihan, formatPendek(b.jatuh_tempo), Number(b.standar), Number(b.potongan), Number(b.nominal),
      Number(b.dibayar), Number(b.sisa), STATUS_TAGIHAN[b.status].n, b.alasan_potongan || ''])]
  const ws = XLSX.utils.aoa_to_sheet(aoa); ws['!cols'] = aoa[0].map((j) => ({ wch: ['Nama', 'Tagihan', 'Keterangan subsidi'].includes(j) ? 28 : 13 }))
  const wb = XLSX.utils.book_new(); XLSX.utils.book_append_sheet(wb, ws, 'Tagihan'); XLSX.writeFile(wb, `Tagihan-Santri-${hariIniISO()}.xlsx`)
}
</script>
<template>
  <div>
    <div class="mb-3 flex flex-wrap items-end gap-2">
      <select v-model="saring.fee_type_id" class="isian w-48" aria-label="Jenis biaya"><option value="">Semua jenis</option><option v-for="j in keu.jenis" :key="j.id" :value="j.id">{{ j.nama }}</option></select>
      <select v-model="saring.group_id" class="isian w-44" aria-label="Kelompok"><option value="">Semua kelompok</option>
        <optgroup v-for="(n, jn) in JENIS_KEL" :key="jn" :label="n"><option v-for="g in kelompok.filter((x) => x.jenis === jn)" :key="g.id" :value="g.id">{{ g.nama }} ({{ g.anggota }})</option></optgroup></select>
      <select v-model="saring.kunci_periode" class="isian w-44" aria-label="Periode"><option value="">Semua periode</option><option v-for="k in periodeAda" :key="k" :value="k">{{ labelPeriode(k) }}</option></select>
      <div class="relative min-w-[180px] flex-1"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-teks3" />
        <input v-model="saring.q" type="search" class="isian pl-10" placeholder="Cari nama atau NIS" aria-label="Cari santri" /></div>
      <button class="tombol-garis" :disabled="!tampil.length" @click="ekspor"><PhFileXls :size="20" weight="duotone" /> Excel</button>
      <button v-if="keu.hak.kelola" class="tombol-garis" :disabled="!keu.jenis.length" @click="impor = true"><PhClockCounterClockwise :size="20" weight="duotone" /> Impor catatan lama</button>
      <button v-if="keu.hak.kelola" class="tombol-utama" :disabled="!keu.jenisAktif.length" @click="mulai"><PhPlus :size="20" weight="bold" /> Buat tagihan</button>
    </div>
    <div class="-mx-4 mb-3 flex gap-1.5 overflow-x-auto px-4 sm:mx-0 sm:px-0" role="group" aria-label="Saring status">
      <button v-for="s in STATUS" :key="s.k" type="button" @click="saring.status = s.k" :aria-pressed="saring.status === s.k"
        :class="['min-h-[40px] shrink-0 rounded-xl border px-3 text-sm font-semibold', saring.status === s.k ? 'border-transparent bg-[#C7332F] text-white' : 'border-garis text-teks2']">{{ s.n }}</button>
    </div>
    <button v-if="['segera', 'lewat', 'tunggak'].includes(saring.status) && tampil.length" class="tombol-garis mb-3 w-presensi" style="color: var(--c)" @click="bukaKirim">
      <PhWhatsappLogo :size="20" weight="duotone" /> {{ saring.status === 'segera' ? 'WA pengingat jatuh tempo ke wali' : 'WA tunggakan ke wali' }}</button>
    <p v-if="!keu.jenisAktif.length" class="kartu mb-3 p-4 text-sm">Belum ada jenis biaya aktif. Isi dulu di <router-link to="/keuangan/pengaturan" class="font-semibold underline">Pengaturan → Jenis biaya</router-link>.</p>
    <p v-if="memuat" class="kartu p-8 text-center text-sm text-teks3">Memuat…</p>
    <p v-else-if="!tampil.length" class="kartu p-8 text-center text-sm text-teks3">Tidak ada tagihan yang sesuai.</p>
    <template v-else>
      <p class="mb-2 text-sm text-teks2">{{ tampil.length }} tagihan · nominal {{ rupiah(jml('nominal')) }} · dibayar {{ rupiah(jml('dibayar')) }} · sisa <b>{{ rupiah(jml('sisa')) }}</b></p>
      <div class="kartu hidden overflow-x-auto lg:block">
        <table class="w-full text-left text-sm">
          <thead class="border-b border-garis bg-permukaan2 text-teks2"><tr><th class="px-3 py-3 font-bold">NIS</th><th class="px-3 py-3 font-bold">Nama</th><th class="px-3 py-3 font-bold">JK</th>
            <th class="px-3 py-3 font-bold">Tagihan</th><th class="px-3 py-3 font-bold">Jatuh tempo</th><th class="px-3 py-3 text-right font-bold">Tagihan (Rp)</th>
            <th class="px-3 py-3 text-right font-bold">Dibayar</th><th class="px-3 py-3 text-right font-bold">Sisa</th><th class="px-3 py-3 font-bold">Status</th></tr></thead>
          <tbody class="divide-y divide-garis">
            <tr v-for="b in tampil" :key="b.id" class="cursor-pointer hover:bg-permukaan2" @click="buka(b)">
              <td class="px-3 py-2.5 tabular-nums text-teks2">{{ b.nis }}</td><td class="px-3 py-2.5"><p class="font-semibold">{{ b.nama }}</p><p class="text-xs text-teks3">{{ b.kelas || '–' }}</p></td>
              <td class="px-3 py-2.5">{{ b.jk }}</td><td class="px-3 py-2.5">{{ b.tagihan }}<p v-if="b.potongan > 0" class="text-xs text-teks3">subsidi {{ rupiah(b.potongan) }}</p></td>
              <td :class="['px-3 py-2.5 tabular-nums', b.lewat && 'font-semibold text-merah']">{{ formatPendek(b.jatuh_tempo) }}</td>
              <td class="px-3 py-2.5 text-right tabular-nums">{{ angka(b.nominal) }}</td><td class="px-3 py-2.5 text-right tabular-nums">{{ angka(b.dibayar) }}</td>
              <td class="px-3 py-2.5 text-right font-bold tabular-nums">{{ b.status === 'batal' ? '–' : angka(b.sisa) }}</td>
              <td class="px-3 py-2.5"><span :class="['lencana', 'w-' + STATUS_TAGIHAN[b.status].w]">{{ STATUS_TAGIHAN[b.status].n }}</span></td>
            </tr>
          </tbody>
        </table>
      </div>
      <ul class="space-y-2.5 lg:hidden">
        <li v-for="b in tampil" :key="b.id"><button class="kartu w-full p-3.5 text-left active:bg-permukaan2" @click="buka(b)">
          <div class="flex items-start gap-2"><div class="min-w-0 flex-1"><p class="truncate font-bold">{{ b.nama }}</p><p class="truncate text-xs text-teks3">{{ b.nis }} · {{ b.kelas || '–' }} · {{ b.tagihan }}</p></div>
            <span :class="['lencana shrink-0', 'w-' + STATUS_TAGIHAN[b.status].w]">{{ STATUS_TAGIHAN[b.status].n }}</span></div>
          <p class="mt-1.5 flex justify-between text-sm"><span :class="b.lewat ? 'font-semibold text-merah' : 'text-teks2'">Jatuh tempo {{ formatPendek(b.jatuh_tempo) }}</span>
            <span class="font-bold tabular-nums">{{ b.status === 'lunas' ? rupiah(b.nominal) : 'sisa ' + rupiah(b.sisa) }}</span></p>
        </button></li>
      </ul>
    </template>

    <LembarBawah :model-value="!!kirim" @update:model-value="(v) => !v && (kirim = null)" :judul="kirim ? JUDUL_KIRIM[kirim.jenis] : ''" lebar>
      <div v-if="kirim" class="pb-2">
        <p v-if="kirim.jenis === 'baru'" class="mb-3 text-sm text-teks2">Tagihan sudah dibuat. Kabari wali satu per satu melalui WhatsApp (pesan dapat disunting di Setelan → Template WA), atau tutup bila tidak perlu.</p>
        <DaftarKirimWA :penerima="penerimaWA" :pesan="pesanKirim" :kunci="'tagihan-' + kirim.jenis + '-' + hariIniISO()" />
      </div>
    </LembarBawah>

    <LembarImporRiwayat v-model="impor" @selesai="muat" />

    <!-- Buat tagihan massal -->
    <LembarBawah :model-value="!!f" @update:model-value="(v) => !v && (f = null)" judul="Buat tagihan" lebar>
      <div v-if="f" class="space-y-4 pb-2">
        <div><label class="label-isian" for="bt-jns">Jenis biaya</label>
          <select id="bt-jns" v-model="f.fee_type_id" class="isian"><option v-for="j in keu.jenisAktif" :key="j.id" :value="j.id">{{ j.nama }} · {{ SIKLUS[j.siklus].n }} · {{ rupiah(j.nominal) }}</option></select>
          <p v-if="jenisPilih?.berlaku_jenjang?.length || jenisPilih?.berlaku_tingkat?.length" class="mt-1 text-xs font-semibold" style="color: var(--c)">
            Hanya untuk {{ [...(jenisPilih.berlaku_jenjang || []).map((k) => JENJANG[k]), ...(jenisPilih.berlaku_tingkat || []).map((t) => 'kelas ' + t)].join(', ') }}</p>
          <p v-if="jenisPilih?.berlaku_jk" class="mt-1 text-xs font-semibold" style="color: var(--c)">Hanya santri {{ JK_SANTRI[jenisPilih.berlaku_jk].toLowerCase() }}</p>
          <p v-if="jenisPilih?.tarif?.length" class="mt-1 text-xs text-teks3">Tarif khusus: {{ jenisPilih.tarif.map((t) => `${labelTarif(t)} ${rupiah(t.nominal)}`).join('; ') }}</p></div>
        <div v-if="jenisPilih && jenisPilih.siklus !== 'sekali'" class="grid gap-3 sm:grid-cols-2">
          <div><label class="label-isian" for="bt-ta">Tahun ajaran</label>
            <select id="bt-ta" v-model="f.tahun_ajaran" class="isian" @change="gantiTA"><option v-for="t in PILIH_TA" :key="t" :value="t">{{ t }}{{ t === taAktif ? ' (aktif)' : t < taAktif ? ' (lalu)' : '' }}</option></select></div>
          <div v-if="jenisPilih?.siklus === 'semesteran'"><span class="label-isian">Semester</span>
            <div class="flex rounded-xl bg-permukaan2 p-1" role="radiogroup" aria-label="Semester">
              <button v-for="sm in [1, 2]" :key="sm" type="button" role="radio" :aria-checked="f.semester === sm" @click="(f.semester = sm), (pra = null)"
                :class="['min-h-[40px] flex-1 rounded-lg text-sm font-semibold', f.semester === sm ? 'bg-permukaan text-teks shadow-kartu' : 'text-teks2']">{{ sm === 1 ? 'Ganjil' : 'Genap' }}</button></div></div>
        </div>
        <p v-if="taLalu" class="flex gap-2 rounded-xl bg-permukaan2 p-3 text-sm text-teks2"><PhInfo :size="20" class="shrink-0" style="color: var(--c)" />
          <span>Tagihan tahun ajaran lalu: kelas santri dihitung mundur (santri kelas 9 sekarang = kelas {{ 9 - (Number(taAktif.slice(0, 4)) - Number(f.tahun_ajaran.slice(0, 4))) }} pada {{ f.tahun_ajaran }}); santri yang belum masuk dilewati.
            Pilihan kelas di bawah berarti kelas pada tahun ajaran itu. Pembayarannya dicatat sebagai "catatan pembayaran lama" atau melalui Impor catatan lama.</span></p>
        <div v-if="jenisPilih?.siklus === 'bulanan'">
          <p class="label-isian">Bulan tagihan ({{ f.tahun_ajaran }})</p>
          <div class="grid grid-cols-3 gap-1.5 sm:grid-cols-6">
            <button v-for="b in BULAN_TA" :key="b" type="button" :aria-pressed="f.bulan.includes(b)" @click="toggle(f.bulan, b)"
              :class="['min-h-[40px] rounded-xl border text-sm font-semibold', f.bulan.includes(b) ? 'border-transparent bg-[#1572B6] text-white' : 'border-garis text-teks2']">{{ namaBulan(b).replace(/ \d+$/, '').slice(0, 3) }} {{ b.slice(2, 4) }}</button>
          </div></div>
        <div class="grid gap-3 sm:grid-cols-2">
          <InputTanggal v-if="jenisPilih?.siklus !== 'bulanan' || f.bulan.length === 1" v-model="f.jatuh_tempo" label="Jatuh tempo (kosong = bawaan)" bawaan-kosong />
          <p v-else class="self-end text-xs text-teks3">Jatuh tempo setiap bulan: tanggal {{ keu.pengaturan.jatuh_tempo_hari }} (Ketentuan).</p>
          <div><label class="label-isian" for="bt-cat">Catatan (tidak wajib)</label><input id="bt-cat" v-model="f.catatan" class="isian" /></div>
        </div>
        <fieldset class="rounded-xl border border-garis p-3"><legend class="px-1 text-sm font-bold">Sasaran (kosong = semua santri aktif)</legend>
          <div class="flex flex-wrap gap-1.5">
            <button v-for="(n, k) in { '': 'Semua jenjang', ...JENJANG }" :key="k" type="button" :aria-pressed="f.jenjang === k" @click="(f.jenjang = k), (f.tingkat = []), (pra = null)"
              :class="['min-h-[40px] rounded-xl border px-3 text-sm font-semibold', f.jenjang === k ? 'border-transparent bg-[#0B7F81] text-white' : 'border-garis text-teks2']">{{ n }}</button>
          </div>
          <div class="mt-2 flex flex-wrap gap-1.5">
            <button v-for="t in (f.jenjang ? TINGKAT[f.jenjang] : [7, 8, 9, 10, 11, 12])" :key="t" type="button" :aria-pressed="f.tingkat.includes(t)" @click="toggle(f.tingkat, t)"
              :class="['min-h-[40px] min-w-[52px] rounded-xl border px-2 text-sm font-semibold', f.tingkat.includes(t) ? 'border-transparent bg-[#0B7F81] text-white' : 'border-garis text-teks2']">Kelas {{ t }}</button>
          </div>
          <div class="mt-2 flex flex-wrap gap-1.5">
            <button v-for="(n, k) in { '': 'Putra & putri', ...JK_SANTRI }" :key="k" type="button" :aria-pressed="f.jk === k" @click="(f.jk = k), (pra = null)"
              :class="['min-h-[40px] rounded-xl border px-3 text-sm font-semibold', f.jk === k ? 'border-transparent bg-[#A13A86] text-white' : 'border-garis text-teks2']">{{ n }}</button>
          </div>
          <select v-model="f.group_id" class="isian mt-2" aria-label="Kelompok tertentu" @change="pra = null"><option value="">Semua kelas/kamar/halaqah</option>
            <optgroup v-for="(n, jn) in JENIS_KEL" :key="jn" :label="n"><option v-for="g in kelompok.filter((x) => x.jenis === jn)" :key="g.id" :value="g.id">{{ g.nama }} ({{ g.anggota }} santri)</option></optgroup></select>
          <label class="mt-2 flex items-center gap-2 text-sm"><input v-model="f.hanya_baru" type="checkbox" class="h-5 w-5" @change="pra = null" /> Hanya santri baru (masuk pada tahun ajaran tagihan)</label>
          <div class="mt-2"><input v-model="cariSantri" type="search" class="isian" placeholder="Atau tambahkan santri tertentu: cari nama/NIS" aria-label="Cari santri tertentu" />
            <ul v-if="calon.length" class="mt-1 divide-y divide-garis rounded-xl border border-garis">
              <li v-for="s in calon" :key="s.id"><button type="button" class="w-full px-3 py-2 text-left text-sm hover:bg-permukaan2" @click="(f.santri.push(s)), (cariSantri = ''), (pra = null)">{{ s.nama }} <span class="text-xs text-teks3">{{ s.nis }} · {{ s.kelas || '–' }}</span></button></li>
            </ul>
            <p v-if="f.santri.length" class="mt-2 flex flex-wrap gap-1.5">
              <span v-for="(s, i) in f.santri" :key="s.id" class="lencana w-santri">{{ s.nama }}<button type="button" :aria-label="'Hapus ' + s.nama" @click="(f.santri.splice(i, 1)), (pra = null)"><PhX :size="12" /></button></span></p>
          </div>
        </fieldset>
        <button class="tombol-garis w-full" :disabled="proses" @click="pratinjau"><PhEye :size="20" weight="duotone" /> Pratinjau tagihan</button>
        <div v-if="pra">
          <p class="mb-2 text-sm"><b>{{ baru.length }}</b> tagihan baru · {{ rupiah(baru.reduce((a, x) => a + Number(x.nominal), 0)) }}<template v-if="pra.baris.length > baru.length"> · {{ pra.baris.length - baru.length }} sudah ada (dilewati)</template></p>
          <div class="max-h-72 overflow-auto rounded-xl border border-garis">
            <table class="w-full text-left text-sm">
              <thead class="sticky top-0 bg-permukaan2"><tr><th class="px-2 py-2">NIS</th><th class="px-2 py-2">Nama</th><th class="px-2 py-2">JK</th><th class="px-2 py-2">Kelas saat itu</th><th class="px-2 py-2">Periode</th><th class="px-2 py-2 text-right">Standar</th><th class="px-2 py-2 text-right">Subsidi</th><th class="px-2 py-2 text-right">Tagihan</th></tr></thead>
              <tbody class="divide-y divide-garis"><tr v-for="x in pra.baris" :key="x.student_id + x.kunci" :class="x.ada && 'opacity-50'">
                <td class="px-2 py-1.5 tabular-nums">{{ x.nis }}</td><td class="px-2 py-1.5">{{ x.nama }}<span v-if="x.ada" class="text-xs"> (sudah ada)</span></td><td class="px-2 py-1.5">{{ x.jk }}</td>
                <td class="px-2 py-1.5">{{ x.tingkat }}<span v-if="x.tingkat_kini && x.tingkat !== x.tingkat_kini" class="text-xs text-teks3"> (kini {{ x.tingkat_kini }})</span></td><td class="px-2 py-1.5">{{ labelPeriode(x.kunci) }}</td>
                <td class="px-2 py-1.5 text-right tabular-nums">{{ angka(x.standar) }}</td><td class="px-2 py-1.5 text-right tabular-nums" :title="x.alasan_potongan || ''">{{ x.potongan ? angka(x.potongan) : '–' }}</td>
                <td class="px-2 py-1.5 text-right font-bold tabular-nums">{{ angka(x.nominal) }}</td></tr></tbody>
            </table>
          </div>
          <button class="tombol-utama mt-3 w-full" :disabled="proses || !baru.length" @click="buat"><PhCheckCircle :size="20" weight="duotone" /> Buat {{ baru.length }} tagihan</button>
        </div>
      </div>
    </LembarBawah>
  </div>
</template>
