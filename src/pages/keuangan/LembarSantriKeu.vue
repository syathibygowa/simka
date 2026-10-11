<!-- SIMKA PRO | src/pages/keuangan/LembarSantriKeu.vue | v1.1 | Fase 13 – Pelengkap: cetak laporan keuangan individu santri | 11/10/2026 -->
<script setup>
// Rincian keuangan satu santri (dibuka dengan ?santri=<id> dari tab mana pun):
// ringkasan, kontak wali (WA), tagihan (ubah/batalkan beralasan), pembayaran (kuitansi, WA konfirmasi, batalkan),
// subsidi, dan surat tagihan. Tombol utama: catat pembayaran, surat tagihan, WA tunggakan, tambah subsidi.
// v1.1: cetak Laporan Keuangan Santri (individu) F4: tagihan, pembayaran, subsidi, dan sisa; TTD Mengetahui Direktur · Bendahara.
import { ref, computed, watch } from 'vue'
import { PhReceipt, PhPaperPlaneTilt, PhWhatsappLogo, PhPercent, PhPencilSimple, PhXCircle, PhPrinter, PhTrash, PhFloppyDisk, PhWarningCircle, PhFileText } from '@phosphor-icons/vue'
import { useLembaga } from '@/stores/lembaga'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'
import { useKeuangan } from '@/stores/keuangan'
import { useUI } from '@/stores/ui'
import { useSesi } from '@/stores/sesi'
import { formatPendek, formatWaktu, formatPanjang, hariIniISO } from '@/lib/tanggal'
import { rupiah, angka, bacaRupiah, STATUS_TAGIHAN, CARA_BAYAR, JENJANG, pesanKuitansi, pesanTunggakan } from '@/lib/keuangan'
import { tautanWA } from '@/lib/wa'
import LembarBawah from '@/components/LembarBawah.vue'
import InputTanggal from '@/components/InputTanggal.vue'
import CetakKeuangan from '@/components/cetak/CetakKeuangan.vue'
import LembarBayar from './LembarBayar.vue'
import LembarSuratTagihan from './LembarSuratTagihan.vue'
import LembarSubsidi from './LembarSubsidi.vue'

const props = defineProps({ id: { type: String, required: true } })
const emit = defineEmits(['tutup', 'berubah'])
const keu = useKeuangan(); const ui = useUI(); const sesi = useSesi()
const buka = computed({ get: () => true, set: (v) => !v && emit('tutup') })
const r = ref(null); const bagian = ref('tagihan')
async function muat() { try { r.value = await keu.rincianSantri(props.id) } catch (e) { ui.toast(e.message, 'galat'); emit('tutup') } }
watch(() => props.id, muat, { immediate: true })
const segar = async () => { await muat(); emit('berubah') }
const s = computed(() => r.value?.santri || {})
const aktifTagihan = computed(() => (r.value?.tagihan || []).filter((b) => b.status !== 'batal'))
const terbuka = computed(() => aktifTagihan.value.filter((b) => ['belum', 'sebagian'].includes(b.status)))
const lewat = computed(() => terbuka.value.filter((b) => b.lewat))
const jml = (a, k) => a.reduce((x, y) => x + Number(y[k] || 0), 0)
const BAGIAN = computed(() => [
  { k: 'tagihan', n: 'Tagihan', j: aktifTagihan.value.length }, { k: 'pembayaran', n: 'Pembayaran', j: (r.value?.pembayaran || []).length },
  { k: 'subsidi', n: 'Subsidi', j: (r.value?.subsidi || []).length }, { k: 'surat', n: 'Surat tagihan', j: (r.value?.surat || []).length },
])
const HUB = { ayah: 'Ayah', ibu: 'Ibu', wali: 'Wali' }
// Laporan individu (cetak F4)
const lembaga = useLembaga(); lembaga.muat()
const laporan = ref(false)
const direktur = computed(() => lembaga.signatories.find((x) => /^direktur$/i.test(x.jabatan_tertulis)) || {})
const sahBayar = computed(() => (r.value?.pembayaran || []).filter((p) => p.status === 'sah'))

// ---------- Lembar anak ----------
const bayar = ref(null); const surat = ref(null); const suratIds = ref(null); const subsidi = ref(null)
const kuitansi = ref([]); const pratinjau = ref(false)
async function cetakKuitansi(p) { try { kuitansi.value = await keu.kuitansi([p.id]); pratinjau.value = true } catch (e) { ui.toast(e.message, 'galat') } }
async function waKuitansi(p) {
  if (!p.wali?.no_hp) return ui.toast('Nomor HP wali belum diisi di Data Santri.', 'galat')
  try { const k = (await keu.kuitansi([p.id]))[0]; window.open(tautanWA(p.wali.no_hp, pesanKuitansi(k)), '_blank', 'noopener') } catch (e) { ui.toast(e.message, 'galat') }
}
const pesanTunggak = computed(() => pesanTunggakan(s.value, lewat.value.length ? lewat.value : terbuka.value, keu.pengaturan))

// ---------- Ubah tagihan ----------
const ubah = ref(null)
const mulaiUbah = (b) => { ubah.value = { b, standar: angka(b.standar), potongan: angka(b.potongan), alasan_potongan: b.alasan_potongan || '', jatuh_tempo: b.jatuh_tempo, alasan: '' } }
async function simpanUbah() {
  const u = ubah.value
  try { await keu.ubahTagihan(u.b.id, { standar: bacaRupiah(u.standar), potongan: bacaRupiah(u.potongan) || 0, alasan_potongan: u.alasan_potongan, jatuh_tempo: u.jatuh_tempo, alasan: u.alasan })
    ui.toast('Tagihan diubah.'); ubah.value = null; await segar() } catch (e) { ui.toast(e.message, 'galat') }
}

// ---------- Aksi beralasan (batalkan tagihan/pembayaran, cabut surat) ----------
const alasan = ref(null)
const minta = (judul, ya, aksi) => { alasan.value = { judul, ya, aksi, teks: '' } }
async function jalankan() {
  const a = alasan.value
  if (a.teks.trim().length < 5) return ui.toast('Tulis alasan paling sedikit 5 karakter.', 'galat')
  try { await a.aksi(a.teks.trim()); alasan.value = null; ui.toast('Tersimpan.'); await segar() } catch (e) { ui.toast(e.message, 'galat') }
}
const batalTagihan = (b) => minta(`Batalkan tagihan ${b.tagihan}?`, 'Batalkan tagihan', (t) => keu.batalkanTagihan(b.id, t))
const batalBayar = (p) => minta(`Batalkan pembayaran ${rupiah(p.jumlah)}?`, 'Batalkan pembayaran', (t) => keu.batalkanPembayaran(p.id, t))
const cabutSurat = (l) => minta(`Cabut surat tagihan ${l.nomor}?`, 'Cabut surat', (t) => keu.cabutSurat(l.id, t))
async function hapusSubsidi(x) {
  if (!(await ui.konfirmasi({ judul: 'Hapus subsidi?', pesan: `${x.alasan}. Tagihan yang sudah dibuat tidak berubah.`, ya: 'Hapus', bahaya: true }))) return
  try { await keu.hapusSubsidi(x.id); await segar() } catch (e) { ui.toast(e.message, 'galat') }
}
</script>
<template>
  <LembarBawah v-model="buka" :judul="s.nama || 'Keuangan santri'" lebar>
    <p v-if="!r" class="p-8 text-center text-sm text-teks3">Memuat…</p>
    <div v-else class="w-keuangan space-y-4 pb-2">
      <p class="text-sm text-teks2">NIS {{ s.nis }} · {{ s.kelas || '–' }} · {{ JENJANG[s.jenjang] }}<span v-if="s.status !== 'aktif'" class="lencana w-klinik ml-1">{{ s.status }}</span></p>
      <div class="grid grid-cols-2 gap-2 sm:grid-cols-4">
        <p class="rounded-xl bg-permukaan2 p-3"><span class="block text-xs text-teks3">Tagihan</span><span class="block font-extrabold tabular-nums">{{ rupiah(jml(aktifTagihan, 'nominal')) }}</span></p>
        <p class="rounded-xl bg-permukaan2 p-3"><span class="block text-xs text-teks3">Dibayar</span><span class="block font-extrabold tabular-nums">{{ rupiah(jml(aktifTagihan, 'dibayar')) }}</span></p>
        <p class="rounded-xl bg-permukaan2 p-3"><span class="block text-xs text-teks3">Sisa</span><span class="block font-extrabold tabular-nums" style="color: var(--c)">{{ rupiah(jml(terbuka, 'sisa')) }}</span></p>
        <p class="rounded-xl bg-permukaan2 p-3"><span class="block text-xs text-teks3">Lewat jatuh tempo</span><span :class="['block font-extrabold tabular-nums', lewat.length && 'text-merah']">{{ rupiah(jml(lewat, 'sisa')) }}</span></p>
      </div>
      <div class="flex flex-wrap gap-2">
        <button v-if="keu.hak.kelola" class="tombol-utama" :disabled="!terbuka.length" @click="bayar = s"><PhReceipt :size="20" weight="duotone" /> Catat pembayaran</button>
        <button v-if="keu.hak.kelola" class="tombol-garis" :disabled="!terbuka.length" @click="surat = [s]"><PhPaperPlaneTilt :size="20" weight="duotone" /> Surat tagihan</button>
        <a v-if="s.wali?.no_hp && terbuka.length" :href="tautanWA(s.wali.no_hp, pesanTunggak)" target="_blank" rel="noopener" class="tombol-garis w-presensi" style="color: var(--c)"><PhWhatsappLogo :size="20" weight="duotone" /> WA {{ lewat.length ? 'tunggakan' : 'tagihan' }}</a>
        <button v-if="keu.hak.kelola" class="tombol-garis" @click="subsidi = { student_id: s.id, nama: s.nama, mulai: '' }"><PhPercent :size="20" /> Subsidi</button>
        <button class="tombol-garis" @click="laporan = true"><PhFileText :size="20" weight="duotone" /> Cetak laporan</button>
      </div>
      <ul v-if="r.kontak.length" class="flex flex-wrap gap-2 text-sm">
        <li v-for="k in r.kontak" :key="k.hubungan" class="rounded-xl bg-permukaan2 px-3 py-1.5">{{ HUB[k.hubungan] }}: <b>{{ k.nama || '–' }}</b> {{ k.no_hp || '(tanpa HP)' }}<span v-if="k.utama" class="text-xs text-teks3"> · utama</span></li>
      </ul>
      <p v-else class="flex items-center gap-1.5 text-sm text-teks3"><PhWarningCircle :size="16" /> Kontak wali belum diisi di Data Santri; WA tidak dapat dikirim.</p>

      <div class="flex gap-1.5 overflow-x-auto" role="tablist" aria-label="Bagian rincian">
        <button v-for="b in BAGIAN" :key="b.k" role="tab" :aria-selected="bagian === b.k" @click="bagian = b.k"
          :class="['min-h-[40px] shrink-0 rounded-full border px-3 text-sm font-semibold', bagian === b.k ? 'border-transparent bg-[#9A4F00] text-white dark:bg-[#FFB86B] dark:text-[#1A1206]' : 'border-garis text-teks2']">{{ b.n }} <span class="opacity-80">{{ b.j }}</span></button>
      </div>

      <!-- Tagihan -->
      <ul v-if="bagian === 'tagihan'" class="divide-y divide-garis">
        <li v-if="!(r.tagihan || []).length" class="py-4 text-sm text-teks3">Belum ada tagihan.</li>
        <li v-for="b in r.tagihan" :key="b.id" :class="['py-2.5', b.status === 'batal' && 'opacity-60']">
          <div class="flex flex-wrap items-center gap-2">
            <div class="min-w-[160px] flex-1"><p class="font-semibold">{{ b.tagihan }}</p>
              <p :class="['text-xs', b.lewat ? 'font-semibold text-merah' : 'text-teks3']">Jatuh tempo {{ formatPendek(b.jatuh_tempo) }}<template v-if="b.potongan > 0"> · subsidi {{ rupiah(b.potongan) }}</template></p></div>
            <p class="text-right tabular-nums"><span class="block font-bold">{{ rupiah(b.nominal) }}</span><span v-if="b.dibayar > 0 && b.status !== 'lunas'" class="block text-xs text-teks3">sisa {{ rupiah(b.sisa) }}</span></p>
            <span :class="['lencana', 'w-' + STATUS_TAGIHAN[b.status].w]">{{ b.nominal === 0 && b.status === 'lunas' ? 'Bebas biaya' : STATUS_TAGIHAN[b.status].n }}</span>
            <template v-if="keu.hak.kelola && b.status !== 'batal'">
              <button class="tombol-ikon h-9 w-9" :aria-label="'Ubah ' + b.tagihan" @click="mulaiUbah(b)"><PhPencilSimple :size="18" /></button>
              <button v-if="!b.dibayar" class="tombol-ikon h-9 w-9 text-merah" :aria-label="'Batalkan ' + b.tagihan" @click="batalTagihan(b)"><PhXCircle :size="18" /></button>
            </template>
          </div>
          <div v-if="ubah?.b.id === b.id" class="mt-2 grid gap-2 rounded-xl border border-garis p-3 sm:grid-cols-2">
            <div><label class="label-isian" :for="'ub-s' + b.id">Standar (Rp)</label><input :id="'ub-s' + b.id" v-model="ubah.standar" inputmode="numeric" class="isian tabular-nums" /></div>
            <div><label class="label-isian" :for="'ub-p' + b.id">Potongan/subsidi (Rp)</label><input :id="'ub-p' + b.id" v-model="ubah.potongan" inputmode="numeric" class="isian tabular-nums" /></div>
            <div><label class="label-isian" :for="'ub-a' + b.id">Keterangan potongan</label><input :id="'ub-a' + b.id" v-model="ubah.alasan_potongan" class="isian" /></div>
            <InputTanggal v-model="ubah.jatuh_tempo" label="Jatuh tempo" />
            <div class="sm:col-span-2"><label class="label-isian" :for="'ub-x' + b.id">Alasan perubahan</label><input :id="'ub-x' + b.id" v-model="ubah.alasan" class="isian" placeholder="Wajib diisi" /></div>
            <div class="flex gap-2 sm:col-span-2"><button class="tombol-utama flex-1" @click="simpanUbah"><PhFloppyDisk :size="20" weight="duotone" /> Simpan</button><button class="tombol-garis" @click="ubah = null">Batal</button></div>
          </div>
          <p v-if="b.catatan" class="mt-1 whitespace-pre-line text-xs text-teks3">{{ b.catatan }}</p>
        </li>
      </ul>

      <!-- Pembayaran -->
      <ul v-else-if="bagian === 'pembayaran'" class="divide-y divide-garis">
        <li v-if="!r.pembayaran.length" class="py-4 text-sm text-teks3">Belum ada pembayaran.</li>
        <li v-for="p in r.pembayaran" :key="p.id" :class="['flex flex-wrap items-center gap-2 py-2.5', p.status === 'batal' && 'opacity-60']">
          <div class="min-w-[170px] flex-1"><p class="font-semibold">{{ formatPendek(p.tanggal) }} · {{ CARA_BAYAR[p.cara] }} <span v-if="p.status === 'batal'" class="lencana w-klinik">Dibatalkan</span></p>
            <p class="text-xs text-teks3">{{ p.nomor }} · {{ (p.rincian || []).map((x) => x.tagihan).join(', ') }}</p>
            <p v-if="p.alasan_batal" class="text-xs text-merah">{{ p.alasan_batal }}</p></div>
          <p class="font-bold tabular-nums">{{ rupiah(p.jumlah) }}</p>
          <button class="tombol-ikon h-9 w-9" :aria-label="'Cetak kuitansi ' + p.nomor" @click="cetakKuitansi(p)"><PhPrinter :size="18" /></button>
          <button v-if="p.status === 'sah'" class="tombol-ikon h-9 w-9" :aria-label="'Kirim konfirmasi WA ' + p.nomor" @click="waKuitansi(p)"><PhWhatsappLogo :size="18" /></button>
          <button v-if="keu.hak.kelola && p.status === 'sah'" class="tombol-ikon h-9 w-9 text-merah" :aria-label="'Batalkan pembayaran ' + p.nomor" @click="batalBayar(p)"><PhXCircle :size="18" /></button>
        </li>
      </ul>

      <!-- Subsidi -->
      <ul v-else-if="bagian === 'subsidi'" class="divide-y divide-garis">
        <li v-if="!r.subsidi.length" class="py-4 text-sm text-teks3">Tidak ada subsidi.</li>
        <li v-for="x in r.subsidi" :key="x.id" class="flex flex-wrap items-center gap-2 py-2.5">
          <div class="min-w-[170px] flex-1"><p class="font-semibold">{{ x.jenis === 'persen' ? Number(x.nilai) + '%' : rupiah(x.nilai) }} · {{ x.jenis_biaya || 'Semua jenis biaya' }}</p>
            <p class="text-xs text-teks3">{{ x.alasan }} · {{ formatPendek(x.mulai) }} s.d. {{ x.sampai ? formatPendek(x.sampai) : 'seterusnya' }}</p></div>
          <span :class="['lencana', x.berlaku ? 'w-presensi' : 'w-hakakses']">{{ x.berlaku ? 'Berlaku' : 'Tidak berlaku' }}</span>
          <template v-if="keu.hak.kelola">
            <button class="tombol-ikon h-9 w-9" aria-label="Ubah subsidi" @click="subsidi = { ...x, nama: s.nama }"><PhPencilSimple :size="18" /></button>
            <button class="tombol-ikon h-9 w-9 text-merah" aria-label="Hapus subsidi" @click="hapusSubsidi(x)"><PhTrash :size="18" /></button>
          </template>
        </li>
      </ul>

      <!-- Surat tagihan -->
      <ul v-else class="divide-y divide-garis">
        <li v-if="!r.surat.length" class="py-4 text-sm text-teks3">Belum ada surat tagihan.</li>
        <li v-for="l in r.surat" :key="l.id" :class="['flex flex-wrap items-center gap-2 py-2.5', l.status === 'dicabut' && 'opacity-60']">
          <div class="min-w-[170px] flex-1"><p class="font-semibold">{{ l.nomor }} <span v-if="l.status === 'dicabut'" class="lencana w-klinik">Dicabut</span></p>
            <p class="text-xs text-teks3">{{ formatPendek(l.tanggal) }} · batas {{ formatPendek(l.batas_bayar) }}{{ l.dikirim_pada ? ' · WA dibuka ' + formatWaktu(l.dikirim_pada) : '' }}</p></div>
          <p class="font-bold tabular-nums">{{ rupiah(l.total) }}</p>
          <button class="tombol-ikon h-9 w-9" :aria-label="'Cetak atau kirim ' + l.nomor" @click="suratIds = [l.id]"><PhPrinter :size="18" /></button>
          <button v-if="keu.hak.kelola && l.status === 'sah'" class="tombol-ikon h-9 w-9 text-merah" :aria-label="'Cabut ' + l.nomor" @click="cabutSurat(l)"><PhXCircle :size="18" /></button>
        </li>
      </ul>
    </div>
  </LembarBawah>

  <LembarBayar :santri="bayar" :tagihan="r?.tagihan || []" @tutup="bayar = null" @tersimpan="segar" />
  <LembarSuratTagihan :santri="surat" :ids="suratIds" @tutup="(surat = null), (suratIds = null)" @terbit="segar" />
  <LembarSubsidi :isi="subsidi" @tutup="subsidi = null" @tersimpan="segar" />
  <DokumenCetak v-if="r" v-model:pratinjau="laporan" judul="Laporan Keuangan Santri" :subjudul="`Posisi per ${formatPanjang(hariIniISO())}`" :pencetak="sesi.pengguna?.nama_lengkap">
    <table class="meta-dok" style="margin-bottom: 6pt"><tbody>
      <tr><td style="width: 1%; white-space: nowrap; padding-right: 6pt">Nama santri</td><td>: {{ s.nama }}</td><td style="width: 1%; white-space: nowrap; padding-right: 6pt">Kelas/jenjang</td><td>: {{ s.kelas || '–' }} · {{ JENJANG[s.jenjang] }}</td></tr>
      <tr><td style="white-space: nowrap; padding-right: 6pt">NIS</td><td>: {{ s.nis }}</td><td style="white-space: nowrap; padding-right: 6pt">Orang tua/wali</td><td>: {{ s.wali?.nama || '–' }}{{ s.wali?.no_hp ? ' (' + s.wali.no_hp + ')' : '' }}</td></tr>
    </tbody></table>
    <p style="font-weight: bold; margin: 4pt 0 2pt">A. Tagihan</p>
    <table class="tabel">
      <colgroup><col style="width:6%"><col style="width:30%"><col style="width:13%"><col style="width:12%"><col style="width:12%"><col style="width:13%"><col style="width:14%"></colgroup>
      <thead><tr><th>No.</th><th>Tagihan</th><th>Jatuh tempo</th><th>Nominal (Rp)</th><th>Subsidi (Rp)</th><th>Dibayar (Rp)</th><th>Sisa/status</th></tr></thead>
      <tbody><tr v-for="(b, i) in aktifTagihan" :key="b.id"><td class="tengah">{{ i + 1 }}</td><td>{{ b.tagihan }}</td><td class="tengah">{{ formatPendek(b.jatuh_tempo) }}</td>
        <td class="kanan">{{ angka(b.nominal) }}</td><td class="kanan">{{ angka(b.potongan) }}</td><td class="kanan">{{ angka(b.dibayar) }}</td>
        <td class="kanan">{{ b.status === 'lunas' ? 'Lunas' : angka(b.sisa) + (b.lewat ? ' *' : '') }}</td></tr>
        <tr><th colspan="3">Jumlah</th><th class="kanan">{{ angka(jml(aktifTagihan, 'nominal')) }}</th><th class="kanan">{{ angka(jml(aktifTagihan, 'potongan')) }}</th>
          <th class="kanan">{{ angka(jml(aktifTagihan, 'dibayar')) }}</th><th class="kanan">{{ angka(jml(terbuka, 'sisa')) }}</th></tr></tbody>
    </table>
    <p v-if="lewat.length" class="catatan-cetak" style="margin-top: 2pt">* telah melewati jatuh tempo; jumlah tunggakan {{ rupiah(jml(lewat, 'sisa')) }}.</p>
    <p style="font-weight: bold; margin: 8pt 0 2pt">B. Pembayaran</p>
    <table class="tabel">
      <colgroup><col style="width:6%"><col style="width:13%"><col style="width:22%"><col style="width:11%"><col style="width:33%"><col style="width:15%"></colgroup>
      <thead><tr><th>No.</th><th>Tanggal</th><th>Nomor kuitansi</th><th>Cara</th><th>Untuk pembayaran</th><th>Jumlah (Rp)</th></tr></thead>
      <tbody><tr v-for="(p, i) in sahBayar" :key="p.id"><td class="tengah">{{ i + 1 }}</td><td class="tengah">{{ formatPendek(p.tanggal) }}</td><td>{{ p.nomor }}</td><td>{{ CARA_BAYAR[p.cara] }}</td>
        <td>{{ (p.rincian || []).map((x) => x.tagihan).join(', ') }}</td><td class="kanan">{{ angka(p.jumlah) }}</td></tr>
        <tr v-if="!sahBayar.length"><td class="tengah">–</td><td colspan="5">Belum ada pembayaran.</td></tr>
        <tr><th colspan="5">Jumlah pembayaran</th><th class="kanan">{{ angka(sahBayar.reduce((a, p) => a + Number(p.jumlah), 0)) }}</th></tr></tbody>
    </table>
    <template v-if="r.subsidi.length">
      <p style="font-weight: bold; margin: 8pt 0 2pt">C. Subsidi/keringanan</p>
      <table class="tabel">
        <colgroup><col style="width:6%"><col style="width:16%"><col style="width:24%"><col style="width:30%"><col style="width:24%"></colgroup>
        <thead><tr><th>No.</th><th>Besaran</th><th>Jenis biaya</th><th>Alasan</th><th>Berlaku</th></tr></thead>
        <tbody><tr v-for="(x, i) in r.subsidi" :key="x.id"><td class="tengah">{{ i + 1 }}</td><td>{{ x.jenis === 'persen' ? Number(x.nilai) + '%' : rupiah(x.nilai) }}</td>
          <td>{{ x.jenis_biaya || 'Semua jenis biaya' }}</td><td>{{ x.alasan }}</td><td>{{ formatPendek(x.mulai) }} s.d. {{ x.sampai ? formatPendek(x.sampai) : 'seterusnya' }}</td></tr></tbody>
      </table>
    </template>
    <p style="margin-top: 8pt">Sisa seluruh tagihan per tanggal laporan: <b>{{ rupiah(jml(terbuka, 'sisa')) }}</b>.</p>
    <template #ttd>
      <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: direktur.jabatan_tertulis || 'Direktur', nama: direktur.nama || '', niy: direktur.niy }"
        :kanan="{ jabatan: keu.jabatanSaya, nama: sesi.pengguna?.nama_lengkap || '', niy: sesi.pengguna?.niy }" />
    </template>
  </DokumenCetak>
  <CetakKeuangan v-model:pratinjau="pratinjau" jenis="kuitansi" :dok="kuitansi" :pengaturan="keu.pengaturan" :pencetak="sesi.pengguna?.nama_lengkap" />
  <LembarBawah :model-value="!!alasan" @update:model-value="(v) => !v && (alasan = null)" :judul="alasan?.judul">
    <div v-if="alasan" class="space-y-3 pb-2">
      <label class="label-isian" for="ls-als">Alasan</label>
      <input id="ls-als" v-model="alasan.teks" class="isian" placeholder="Paling sedikit 5 karakter" @keydown.enter.prevent="jalankan" />
      <button class="tombol-utama w-full bg-[#C7332F]" @click="jalankan"><PhXCircle :size="20" weight="duotone" /> {{ alasan.ya }}</button>
    </div>
  </LembarBawah>
</template>
