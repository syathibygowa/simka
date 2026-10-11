<!-- SIMKA PRO | src/pages/persuratan/LembarRincianKeluar.vue | v1.2 | Fase 10 – Penutup: revisi surat terbit | 11/10/2026 -->
<script setup>
// Rincian surat keluar: status, nomor, penanda tangan, dan tindakan sesuai peran:
//   penyusun (Kepala Bidang) : Ubah, Kirim ke Tata Usaha, Batalkan
//   Tata Usaha               : Ubah, Ajukan tanda tangan (elektronik/basah), Batalkan, Unggah arsip pindaian, Revisi (surat terbit)
//   penanda tangan           : Tanda tangani atau Tolak (beralasan); nomor surat terbit otomatis saat sah
//   semua yang berhak        : Pratinjau/Cetak F4 (draf bertanda DRAF; surat sah dengan QR dan kode validasi)
// Surat yang sudah diajukan dicetak dari salinan beku di registri dokumen.
import { ref, watch, computed } from 'vue'
import { PhPrinter, PhPencilSimple, PhPaperPlaneTilt, PhSignature, PhProhibit, PhPenNib, PhXCircle, PhUploadSimple, PhPaperclip, PhArrowLeft, PhSealCheck, PhInfo, PhArrowsClockwise } from '@phosphor-icons/vue'
import { usePersuratan } from '@/stores/persuratan'
import { useUI } from '@/stores/ui'
import { STATUS_KELUAR, isianKosong } from '@/lib/suratKeluar'
import { formatPanjang, formatWaktu } from '@/lib/tanggal'
import { MODE_DEMO } from '@/lib/supabase'
import { ambilBerkasUrl, unggahKeDrive, kompresGambar, namaRapi } from '@/lib/penyimpanan'
import LembarBawah from '@/components/LembarBawah.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import SuratResmi from '@/components/cetak/SuratResmi.vue'

const buka = defineModel({ type: Boolean, default: false })
const props = defineProps({ id: { type: String, default: '' }, doc: { type: String, default: '' }, versi: { type: Number, default: 0 } })
const emit = defineEmits(['berubah', 'ubah', 'revisi'])
const ps = usePersuratan(); const ui = useUI()
const s = ref(null); const memuat = ref(false); const mode = ref('rincian'); const teks = ref(''); const ttdMode = ref('elektronik'); const proses = ref(false); const cetak = ref(false); const nomorBaru = ref(false)
async function muat() {
  if (!props.id && !props.doc) return
  memuat.value = true
  try { await ps.muatKonteks(); s.value = await ps.rincianKeluar({ id: props.id || null, doc: props.doc || null }) } catch (e) { ui.toast(e.message, 'galat'); buka.value = false } finally { memuat.value = false }
}
watch(() => [buka.value, props.id, props.doc], ([b]) => { if (b) { mode.value = 'rincian'; cetak.value = false; s.value = null; muat() } }, { immediate: true })
watch(() => props.versi, () => { if (buka.value && mode.value === 'rincian') muat() })

const beku = computed(() => s.value?.dokumen?.isi || null)
const suratCetak = computed(() => {
  if (!s.value) return null
  const b = beku.value
  const dasar = b ? { ...b } : { ...s.value }
  return { ...dasar, nomor: s.value.nomor || s.value.dokumen?.nomor || dasar.nomor, tanggal_hijriah: dasar.tanggal_hijriah || s.value.tanggal_hijriah, mode_ttd: s.value.mode_ttd }
})
const lembagaCetak = computed(() => beku.value?.lembaga || ps.konteks || {})
const sah = computed(() => s.value?.dokumen?.status === 'sah')
const kosong = computed(() => (s.value ? isianKosong(s.value.tampilan?.isian, s.value.nilai) : []))
const ttdRingkas = computed(() => (s.value?.dokumen?.penanda?.length ? s.value.dokumen.penanda : (s.value?.penanda || []).map((p) => ({ ...p, status: null }))))
const STATUS_TTD = { ditandatangani: 'Sudah menandatangani', menunggu: 'Menunggu', ditolak: 'Menolak' }

async function jalankan(fn, pesan) {
  proses.value = true
  try { const h = await fn(); ui.toast(typeof pesan === 'function' ? pesan(h) : pesan); emit('berubah'); mode.value = 'rincian'; await muat() } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
const kirimTu = () => jalankan(() => ps.kirimKeTu(s.value.id), 'Surat dikirim ke Tata Usaha untuk diperiksa dan dinomori.')
function ajukan() {
  if (kosong.value.length) return ui.toast(`Lengkapi isian wajib lebih dulu: ${kosong.value.join(', ')}.`, 'galat')
  const o = s.value
  const isi = { tampilan: o.tampilan, nilai: o.nilai, perihal: o.perihal, kepada: o.kepada, lampiran: o.lampiran, tembusan: o.tembusan, narahubung: o.narahubung,
    tanggal_surat: o.tanggal_surat, penanda: o.penanda, kop_kode: o.kop_kode, jenis_nama: o.jenis_nama, lembaga: ps.konteks }
  return jalankan(() => ps.ajukanKeluar(o.id, ttdMode.value, isi), (h) => h.status === 'terbit' ? `Surat terbit dengan nomor ${h.nomor}.` : 'Permintaan tanda tangan terkirim. Nomor surat terbit otomatis setelah ditandatangani.')
}
const tandatangani = () => jalankan(() => ps.tandatanganiKeluar(s.value.dokumen.id, true), (h) => h.status === 'sah' ? `Surat sah. Kode validasi ${h.kode}.` : 'Tanda tangan Anda tersimpan.')
function kirimTeks() {
  const t = teks.value.trim()
  if (t.length < 5) return ui.toast('Tuliskan alasan (minimal 5 huruf).', 'galat')
  if (mode.value === 'tolak') return jalankan(() => ps.tandatanganiKeluar(s.value.dokumen.id, false, t), 'Surat ditolak. Tata Usaha dan penyusun mendapat pemberitahuan.')
  if (mode.value === 'revisi') return revisi(t)
  return jalankan(() => ps.batalKeluar(s.value.id, t), 'Surat dibatalkan.')
}
// Revisi: draf salinan dibuka; surat lama tetap berlaku sampai revisinya sah, lalu berstatus Direvisi
async function revisi(alasan) {
  proses.value = true
  try {
    const id = await ps.revisiKeluar(s.value.id, alasan, nomorBaru.value)
    ui.toast('Draf revisi dibuat. Ubah isinya, lalu ajukan tanda tangan kembali.'); emit('berubah'); emit('revisi', id)
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
const JUDUL_TEKS = { tolak: 'Tolak menandatangani', batal: 'Batalkan surat', revisi: 'Revisi surat' }
async function unggahArsip(e) {
  const f = e.target.files?.[0]; e.target.value = ''; if (!f) return
  if (!/^image\//.test(f.type) && f.type !== 'application/pdf') return ui.toast('Pilih foto atau PDF.', 'galat')
  if (f.type === 'application/pdf' && f.size > 5 * 1024 * 1024) return ui.toast('Ukuran PDF paling besar 5 MB.', 'galat')
  await jalankan(async () => {
    let id = 'demo'
    if (!MODE_DEMO) {
      const blob = f.type === 'application/pdf' ? f : await kompresGambar(f, { maks: 1800, kualitas: 0.72 }); const t = s.value.tanggal_surat
      id = await unggahKeDrive(blob, { nama: namaRapi('SuratKeluar', (s.value.nomor || '').replace(/\//g, '-')) + (f.type === 'application/pdf' ? '.pdf' : '.jpg'), kategori: 'surat_keluar',
        folder: `SIMKA PRO/Persuratan/Surat Keluar/${t.slice(0, 4)}/${t.slice(5, 7)}` })
    }
    await ps.arsipKeluar(s.value.id, id)
  }, 'Arsip pindaian surat tersimpan.')
}
async function lihatArsip() {
  if (MODE_DEMO) return ui.toast('Mode demo: pindaian tidak tersedia.')
  try { window.open(await ambilBerkasUrl(s.value.berkas_arsip_id), '_blank', 'noopener') } catch (e) { ui.toast(e.message, 'galat') }
}
</script>
<template>
  <LembarBawah v-model="buka" :judul="s ? s.jenis_nama : 'Surat keluar'" lebar>
    <p v-if="!s" class="py-10 text-center text-sm text-teks3">{{ memuat ? 'Memuat…' : '' }}</p>
    <div v-else-if="mode === 'rincian'" class="space-y-4 pb-2">
      <div>
        <p class="flex flex-wrap items-center gap-1.5"><span class="lencana" :class="'w-' + STATUS_KELUAR[s.status].w">{{ STATUS_KELUAR[s.status].n }}</span>
          <span class="lencana w-hakakses">{{ s.mode_ttd === 'basah' ? 'TTD basah' : 'TTD elektronik' }}</span>
          <span v-if="s.dokumen?.kode" class="text-xs text-teks3">Kode validasi {{ s.dokumen.kode }}</span></p>
        <h3 class="mt-1 text-lg font-bold leading-snug [overflow-wrap:anywhere]">{{ s.perihal }}</h3>
        <p class="text-sm text-teks2 tabular-nums">{{ s.nomor || 'Nomor terbit setelah surat sah' }}</p>
      </div>
      <p v-if="s.catatan && ['ditolak', 'dibatalkan', 'dicabut'].includes(s.status)" class="rounded-xl bg-[#C7332F]/10 px-3 py-2 text-sm text-merah">
        <b>{{ s.status === 'ditolak' ? 'Alasan penolakan' : 'Catatan' }}:</b> {{ s.catatan }}</p>
      <div v-if="s.revisi_ke || s.pengganti" class="w-pengajuan rounded-xl px-3 py-2 text-sm" style="background: color-mix(in srgb, var(--c) 12%, transparent)">
        <p v-if="s.revisi_ke" class="flex items-start gap-2"><PhArrowsClockwise :size="18" class="mt-0.5 shrink-0" style="color: var(--c)" />
          <span>Revisi ke-{{ s.revisi_ke }}{{ s.revisi_dari_nomor ? ` dari surat ${s.revisi_dari_nomor}` : '' }}<template v-if="s.alasan_revisi">. Alasan: {{ s.alasan_revisi }}</template>
            <button v-if="s.revisi_dari" type="button" class="ml-1 font-semibold underline" @click="emit('revisi', s.revisi_dari)">Buka surat asal</button></span></p>
        <p v-if="s.pengganti" class="flex items-start gap-2"><PhArrowsClockwise :size="18" class="mt-0.5 shrink-0" style="color: var(--c)" />
          <span>{{ s.status === 'direvisi' ? 'Surat ini sudah diganti' : 'Sedang direvisi' }}: revisi ke-{{ s.pengganti.revisi_ke }} ({{ STATUS_KELUAR[s.pengganti.status]?.n || s.pengganti.status }})
            <button type="button" class="ml-1 font-semibold underline" @click="emit('revisi', s.pengganti.id)">Buka revisi</button></span></p>
      </div>

      <dl class="grid gap-x-4 gap-y-2 rounded-2xl bg-permukaan2 p-3 text-sm sm:grid-cols-2">
        <div><dt class="text-xs text-teks3">Tanggal surat</dt><dd>{{ formatPanjang(s.tanggal_surat) }}<span v-if="s.tanggal_hijriah" class="block text-xs text-teks3">{{ s.tanggal_hijriah }}</span></dd></div>
        <div><dt class="text-xs text-teks3">Kepada</dt><dd class="whitespace-pre-line">{{ s.kepada || '–' }}</dd></div>
        <div><dt class="text-xs text-teks3">Disusun oleh</dt><dd>{{ s.disusun_oleh || '–' }}<span v-if="s.pemohon && s.pemohon !== s.disusun_oleh" class="block text-xs text-teks3">Atas permintaan {{ s.pemohon }}</span></dd></div>
        <div><dt class="text-xs text-teks3">Jenis</dt><dd>{{ s.dk === 'K' ? 'Khariji (keluar)' : 'Dakhily (internal)' }} · {{ s.perihal_kode }}</dd></div>
      </dl>

      <section>
        <h4 class="judul-bagian mb-2 flex items-center gap-2"><PhSignature :size="20" weight="duotone" class="text-[#6D44B8]" /> Penanda tangan</h4>
        <ul class="space-y-2">
          <li v-for="(p, i) in ttdRingkas" :key="i" class="flex items-center gap-3 rounded-xl border border-garis px-3 py-2 text-sm">
            <span class="min-w-0 flex-1"><b class="block truncate">{{ p.nama || '–' }}</b><span class="text-xs text-teks3">{{ p.jabatan }}</span></span>
            <span v-if="p.status" class="lencana" :class="p.status === 'ditandatangani' ? 'w-presensi' : p.status === 'ditolak' ? 'w-klinik' : 'w-shift'">
              {{ p.catatan === 'basah' ? 'Tanda tangan basah' : STATUS_TTD[p.status] }}<template v-if="p.waktu"> · {{ formatWaktu(p.waktu) }}</template></span>
          </li>
        </ul>
      </section>

      <div v-if="s.boleh.tanda_tangan" class="rounded-2xl border-2 border-[#6D44B8] p-3">
        <p class="text-sm"><b>Surat ini menunggu tanda tangan Anda.</b> Periksa isinya dengan Pratinjau sebelum menandatangani.</p>
        <div class="mt-2 flex flex-wrap gap-2">
          <button class="tombol-utama" :disabled="proses" @click="tandatangani"><PhPenNib :size="20" weight="duotone" /> Tanda tangani</button>
          <button class="tombol-garis" @click="teks = ''; mode = 'tolak'"><PhXCircle :size="20" /> Tolak</button>
        </div>
      </div>

      <div v-if="s.boleh.ajukan" class="space-y-2 rounded-2xl border border-garis p-3">
        <p class="text-sm font-semibold">Ajukan tanda tangan</p>
        <div class="grid grid-cols-2 gap-2" role="radiogroup" aria-label="Mode tanda tangan">
          <button v-for="m in [{ k: 'elektronik', n: 'Elektronik', ket: 'Pejabat menandatangani dari akunnya; QR tercetak' }, { k: 'basah', n: 'Basah', ket: 'Langsung terbit bernomor; ditandatangani setelah dicetak' }]" :key="m.k"
            type="button" role="radio" :aria-checked="ttdMode === m.k" @click="ttdMode = m.k"
            :class="['rounded-xl border p-2.5 text-left text-sm w-verifikasi', ttdMode === m.k ? 'pilih' : 'border-garis']"><b class="block">{{ m.n }}</b><span class="text-xs text-teks2">{{ m.ket }}</span></button>
        </div>
        <p v-if="kosong.length" class="text-xs text-merah">Isian wajib belum lengkap: {{ kosong.join(', ') }}.</p>
        <button class="tombol-utama w-full" :disabled="proses" @click="ajukan"><PhSealCheck :size="20" weight="duotone" /> {{ ttdMode === 'basah' ? 'Terbitkan bernomor' : 'Ajukan tanda tangan' }}</button>
      </div>

      <div class="flex flex-wrap gap-2 border-t border-garis pt-4">
        <button class="tombol-garis w-rekap" @click="cetak = true"><PhPrinter :size="20" style="color: var(--c)" /> {{ sah ? 'Cetak surat' : 'Pratinjau' }}</button>
        <button v-if="s.boleh.kirim_tu" class="tombol-utama" :disabled="proses" @click="kirimTu"><PhPaperPlaneTilt :size="20" weight="duotone" /> Kirim ke Tata Usaha</button>
        <button v-if="s.boleh.ubah" class="tombol-garis" @click="emit('ubah', s)"><PhPencilSimple :size="20" /> Ubah</button>
        <label v-if="s.boleh.arsip" class="tombol-garis cursor-pointer"><PhUploadSimple :size="20" /> {{ s.berkas_arsip_id ? 'Ganti arsip pindaian' : 'Unggah arsip pindaian' }}
          <input type="file" accept="image/*,application/pdf" class="sr-only" @change="unggahArsip" /></label>
        <button v-if="s.berkas_arsip_id" class="tombol-garis" @click="lihatArsip"><PhPaperclip :size="20" /> Arsip pindaian</button>
        <button v-if="s.boleh.revisi && !s.pengganti" class="tombol-garis w-pengajuan" @click="teks = ''; nomorBaru = false; mode = 'revisi'"><PhArrowsClockwise :size="20" style="color: var(--c)" /> Revisi surat</button>
        <button v-if="s.boleh.batal" class="tombol-teks" @click="teks = ''; mode = 'batal'"><PhProhibit :size="20" /> Batalkan</button>
      </div>
      <p v-if="s.status === 'terbit' && s.mode_ttd === 'basah' && !s.berkas_arsip_id" class="flex items-start gap-2 text-xs text-teks3"><PhInfo :size="15" class="mt-0.5 shrink-0" />
        Setelah dicetak dan ditandatangani, unggah pindaiannya sebagai arsip.</p>
      <DokumenCetak :kop="suratCetak.kop_kode || s.kop_kode" :judul="`${s.jenis_nama}${s.nomor ? ' ' + s.nomor : ''}`" v-model:pratinjau="cetak" sembunyikan-judul tanpa-catatan>
        <SuratResmi :surat="suratCetak" :lembaga="lembagaCetak" :ttd="s.dokumen?.penanda || []" :kode="s.dokumen?.kode || ''"
          :status-dokumen="s.dokumen?.status || ''" :mode="sah ? 'final' : 'pratinjau'" />
      </DokumenCetak>
    </div>

    <div v-else class="space-y-3 pb-2">
      <button type="button" class="tombol-teks -ml-3 px-3" @click="mode = 'rincian'"><PhArrowLeft :size="18" /> Kembali ke rincian</button>
      <h3 class="judul-bagian">{{ JUDUL_TEKS[mode] }}</h3>
      <p class="text-sm text-teks2">{{ s.perihal }}<span v-if="s.nomor" class="block text-xs tabular-nums">{{ s.nomor }}</span></p>
      <template v-if="mode === 'revisi'">
        <p class="text-sm text-teks2">Revisi dibuat sebagai draf salinan surat ini. Setelah diubah, ajukan tanda tangan kembali. Surat ini tetap berlaku sampai revisinya sah,
          lalu berstatus <b>Direvisi</b> dan halaman Cek Keabsahan menunjuk surat penggantinya.</p>
        <label class="flex min-h-[44px] items-center gap-3 rounded-xl border border-garis px-3 text-sm">
          <input v-model="nomorBaru" type="checkbox" class="h-5 w-5" />
          <span><b>Pakai nomor baru</b><span class="block text-xs text-teks3">Bila tidak dicentang, nomor dan tanggal surat lama tetap dipakai.</span></span></label>
      </template>
      <textarea v-model="teks" rows="3" class="isian py-2.5" aria-label="Alasan"
        :placeholder="mode === 'tolak' ? 'Alasan penolakan (wajib), mis. tanggal acara keliru' : mode === 'revisi' ? 'Alasan revisi (wajib), mis. perbaikan tempat acara' : 'Alasan pembatalan (wajib)'" />
      <button class="tombol-utama w-full" :disabled="proses" @click="kirimTeks"><component :is="mode === 'tolak' ? PhXCircle : mode === 'revisi' ? PhArrowsClockwise : PhProhibit" :size="20" />
        {{ mode === 'tolak' ? 'Tolak surat' : mode === 'revisi' ? 'Buat draf revisi' : 'Batalkan surat' }}</button>
    </div>
  </LembarBawah>
</template>
<style scoped>
.pilih { border-color: var(--c); border-width: 2px; background: color-mix(in srgb, var(--c) 12%, transparent); }
</style>
