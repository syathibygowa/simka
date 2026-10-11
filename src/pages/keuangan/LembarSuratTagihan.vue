<!-- SIMKA PRO | src/pages/keuangan/LembarSuratTagihan.vue | v1.0 | Fase 13 – Terbitkan surat tagihan (satu/banyak), cetak, dan kirim WA ke wali | 11/10/2026 -->
<script setup>
// Surat tagihan untuk santri terpilih: memuat tagihan belum lunas yang jatuh tempo paling lambat tanggal tertentu
// (bawaan = batas pembayaran). Setiap santri satu surat bernomor, bertanda tangan elektronik Bendahara Pondok.
// Sesudah terbit: cetak semua (F4, satu surat per halaman) dan daftar kirim WA ke wali satu per satu.
// Dapat juga dibuka untuk surat yang sudah terbit (ids) agar dicetak/dikirim ulang.
import { ref, computed, watch } from 'vue'
import { PhPaperPlaneTilt, PhPrinter, PhSealCheck } from '@phosphor-icons/vue'
import { useKeuangan } from '@/stores/keuangan'
import { useUI } from '@/stores/ui'
import { useSesi } from '@/stores/sesi'
import { hariIniISO } from '@/lib/tanggal'
import { rupiah, pesanTagihan, kelasSantri } from '@/lib/keuangan'
import LembarBawah from '@/components/LembarBawah.vue'
import InputTanggal from '@/components/InputTanggal.vue'
import DaftarKirimWA from '@/components/DaftarKirimWA.vue'
import CetakKeuangan from '@/components/cetak/CetakKeuangan.vue'

const props = defineProps({ santri: { type: Array, default: null }, ids: { type: Array, default: null } })   // santri: [{id, nama}] · ids: surat yang sudah terbit
const emit = defineEmits(['tutup', 'terbit'])
const keu = useKeuangan(); const ui = useUI(); const sesi = useSesi()
const buka = computed({ get: () => !!(props.santri || props.ids), set: (v) => !v && emit('tutup') })
const tambah = (n) => { const d = new Date(hariIniISO() + 'T00:00:00Z'); d.setUTCDate(d.getUTCDate() + n); return d.toISOString().slice(0, 10) }
const f = ref(null); const surat = ref([]); const proses = ref(false); const pratinjau = ref(false)
watch(() => [props.santri, props.ids], async () => {
  surat.value = []
  if (props.ids?.length) { try { surat.value = await keu.suratTagihan(props.ids) } catch (e) { ui.toast(e.message, 'galat') } return }
  if (props.santri) { const b = tambah(keu.pengaturan.batas_surat_hari || 7); f.value = { batas_bayar: b, tempo_sampai: b, catatan: '' } }
}, { immediate: true })
async function terbitkan() {
  if (f.value.tempo_sampai > f.value.batas_bayar) f.value.tempo_sampai = f.value.batas_bayar
  proses.value = true
  try {
    const r = await keu.terbitkanSurat({ student_ids: props.santri.map((s) => s.id), batas_bayar: f.value.batas_bayar, tempo_sampai: f.value.tempo_sampai, catatan: f.value.catatan })
    if (!r.length) { ui.toast('Tidak ada tagihan terbuka yang jatuh tempo sampai tanggal itu.', 'galat'); return }
    surat.value = await keu.suratTagihan(r.map((x) => x.id))
    ui.toast(`${r.length} surat tagihan terbit${props.santri.length > r.length ? `; ${props.santri.length - r.length} santri tanpa tagihan dilewati` : ''}.`); emit('terbit')
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
const penerima = computed(() => surat.value.map((l) => ({ employee_id: l.id, nama: `${l.santri?.wali?.nama || 'Wali'} – ${l.santri?.nama}`, no_hp: l.santri?.wali?.no_hp, unit: `${kelasSantri(l.santri)} · ${rupiah(l.total)}`, l })))
const total = computed(() => surat.value.reduce((a, l) => a + Number(l.total), 0))
</script>
<template>
  <LembarBawah v-model="buka" :judul="surat.length ? 'Surat tagihan' : 'Terbitkan surat tagihan'" lebar>
    <div v-if="surat.length" class="w-keuangan space-y-4 pb-2">
      <div class="flex items-center gap-3 rounded-2xl p-4" style="background: color-mix(in srgb, var(--c) 12%, rgb(var(--permukaan)))">
        <span class="chip-ikon h-12 w-12 shrink-0"><PhSealCheck :size="28" weight="duotone" /></span>
        <div><p class="text-lg font-extrabold">{{ surat.length }} surat tagihan · {{ rupiah(total) }}</p>
          <p class="text-sm text-teks2">Ditandatangani elektronik; keabsahan dapat diperiksa melalui QR.</p></div>
      </div>
      <button class="tombol-utama" @click="pratinjau = true"><PhPrinter :size="20" weight="duotone" /> Cetak {{ surat.length > 1 ? 'semua' : 'surat' }}</button>
      <div><p class="judul-bagian mb-2">Kirim ke wali melalui WhatsApp</p>
        <DaftarKirimWA :penerima="penerima" :pesan="(p) => (keu.catatKirim(p.l.id).catch(() => {}), pesanTagihan(p.l, keu.pengaturan))" :kunci="'tagihan-' + surat.map((l) => l.id).join('').slice(0, 40)" /></div>
      <CetakKeuangan v-model:pratinjau="pratinjau" jenis="tagihan" :dok="surat" :pengaturan="keu.pengaturan" :pencetak="sesi.pengguna?.nama_lengkap" />
    </div>
    <div v-else-if="santri && f" class="space-y-4 pb-2">
      <p class="rounded-xl bg-permukaan2 p-3 text-sm">{{ santri.length === 1 ? santri[0].nama : `${santri.length} santri terpilih` }}. Setiap santri mendapat satu surat bernomor.</p>
      <div class="grid gap-3 sm:grid-cols-2">
        <InputTanggal v-model="f.batas_bayar" label="Batas pembayaran" wajib />
        <InputTanggal v-model="f.tempo_sampai" label="Muat tagihan jatuh tempo sampai" wajib />
      </div>
      <p class="text-xs text-teks3">Tagihan yang belum lunas dan jatuh tempo paling lambat tanggal kedua dimuat (termasuk tunggakan bulan-bulan sebelumnya).</p>
      <div><label class="label-isian" for="st-cat">Catatan tambahan (tidak wajib)</label>
        <textarea id="st-cat" v-model="f.catatan" rows="2" class="isian" placeholder="Contoh: Pembayaran dapat diangsur dengan menghubungi Bendahara Pondok." /></div>
      <button class="tombol-utama w-full" :disabled="proses || !keu.hak.kelola" @click="terbitkan"><PhPaperPlaneTilt :size="20" weight="duotone" /> Terbitkan surat tagihan</button>
    </div>
  </LembarBawah>
</template>
