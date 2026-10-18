<!-- SIMKA PRO | src/pages/keuangan/LembarBayar.vue | v1.2 | 14.2.0: tombol WhatsApp hijau | 17/10/2026 -->
<script setup>
// Catat pembayaran seorang santri. Tagihan terbuka tampil berurutan dari jatuh tempo tertua; centang tagihan dan
// ubah jumlahnya (pembayaran sebagian boleh), atau isi "jumlah diterima" untuk dibagi otomatis ke tagihan tertua.
// Tanggal bawaan hari ini. Foto bukti transfer (tidak wajib) diunggah ke Google Drive lewat antrian.
// Setelah tersimpan: kuitansi bernomor bertanda tangan elektronik siap dicetak dan dikirim melalui WA.
// v1.1: "Catatan pembayaran lama" untuk pembayaran tahun-tahun lalu yang kuitansinya sudah diberikan dahulu:
//       tidak menerbitkan kuitansi bernomor baru; otomatis tercentang bila tanggal sebelum tahun ajaran aktif.
import { ref, computed, watch } from 'vue'
import { PhFloppyDisk, PhCamera, PhCheckSquare, PhSquare, PhMagicWand, PhPrinter, PhWhatsappLogo, PhSealCheck } from '@phosphor-icons/vue'
import { useKeuangan } from '@/stores/keuangan'
import { useUI } from '@/stores/ui'
import { useSesi } from '@/stores/sesi'
import { useLembaga } from '@/stores/lembaga'
import { MODE_DEMO } from '@/lib/supabase'
import { hariIniISO, formatPendek } from '@/lib/tanggal'
import { rupiah, angka, bacaRupiah, terbilang, CARA_BAYAR, pesanKuitansi } from '@/lib/keuangan'
import { kompresGambar, unggahKeDrive, namaRapi } from '@/lib/penyimpanan'
import { tautanWA } from '@/lib/wa'
import LembarBawah from '@/components/LembarBawah.vue'
import InputTanggal from '@/components/InputTanggal.vue'
import CetakKeuangan from '@/components/cetak/CetakKeuangan.vue'

const props = defineProps({ santri: { type: Object, default: null }, tagihan: { type: Array, default: () => [] }, pilihAwal: { type: Array, default: () => [] } })
const emit = defineEmits(['tutup', 'tersimpan'])
const keu = useKeuangan(); const ui = useUI(); const sesi = useSesi(); const lembaga = useLembaga()
const awalTA = computed(() => lembaga.tahunAktif?.mulai || `${Number(hariIniISO().slice(0, 4)) - (Number(hariIniISO().slice(5, 7)) < 7 ? 1 : 0)}-07-01`)
const buka = computed({ get: () => !!props.santri, set: (v) => !v && emit('tutup') })

const terbuka = computed(() => props.tagihan.filter((b) => ['belum', 'sebagian'].includes(b.status)).sort((a, b) => a.jatuh_tempo.localeCompare(b.jatuh_tempo)))
const f = ref(null); const alok = ref({}); const otomatis = ref('')
watch(() => props.santri, (s) => {
  if (!s) return
  const rek = keu.pengaturan.rekening?.[0]
  f.value = { tanggal: hariIniISO(), cara: 'tunai', rekening_tujuan: rek ? `${rek.bank} ${rek.nomor}` : '', penyetor: s.wali?.nama || '', keterangan: '', bukti: null, buktiNama: '', riwayat: false }
  alok.value = Object.fromEntries(terbuka.value.map((b) => [b.id, props.pilihAwal.includes(b.id) ? angka(b.sisa) : '']))
  otomatis.value = ''; hasil.value = null
}, { immediate: true })
watch(() => f.value?.tanggal, (t) => { if (f.value && t) f.value.riwayat = t < awalTA.value })
const pilih = (b) => { alok.value[b.id] = alok.value[b.id] ? '' : angka(b.sisa) }
function bagi() {
  let sisa = bacaRupiah(otomatis.value) || 0
  for (const b of terbuka.value) { const v = Math.min(sisa, Number(b.sisa)); alok.value[b.id] = v > 0 ? angka(v) : ''; sisa -= Math.max(v, 0) }
  if (sisa > 0) ui.toast(`Jumlah melebihi seluruh sisa tagihan; kelebihan ${rupiah(sisa)}.`, 'galat')
}
const total = computed(() => Object.values(alok.value).reduce((a, v) => a + (bacaRupiah(v) || 0), 0))
const galat = computed(() => terbuka.value.find((b) => (bacaRupiah(alok.value[b.id]) || 0) > Number(b.sisa)))
async function pilihFoto(e) {
  const berkas = e.target.files?.[0]; e.target.value = ''
  if (!berkas) return
  try { f.value.bukti = await kompresGambar(berkas, { maks: 1280, kualitas: 0.7 }); f.value.buktiNama = berkas.name } catch { ui.toast('Foto tidak dapat dibaca.', 'galat') }
}

const proses = ref(false); const hasil = ref(null); const pratinjau = ref(false)
async function simpan() {
  if (!total.value) return ui.toast('Pilih tagihan dan isi jumlah yang dibayar.', 'galat')
  if (galat.value) return ui.toast(`Jumlah untuk ${galat.value.tagihan} melebihi sisanya.`, 'galat')
  if (!(await ui.konfirmasi({ judul: `Simpan pembayaran ${rupiah(total.value)}?`, pesan: `${props.santri.nama} · ${CARA_BAYAR[f.value.cara]} · ${formatPendek(f.value.tanggal)}. ${f.value.riwayat ? 'Dicatat sebagai catatan pembayaran lama, tanpa kuitansi baru.' : 'Kuitansi bernomor akan terbit dan ditandatangani elektronik.'}`, ya: 'Simpan pembayaran' }))) return
  proses.value = true
  try {
    let bukti_id = null
    if (f.value.bukti && !MODE_DEMO) {
      bukti_id = await unggahKeDrive(f.value.bukti, { nama: namaRapi('BuktiBayar', props.santri.nis, f.value.tanggal.replaceAll('-', ''), Date.now() % 1000) + '.jpg',
        kategori: 'bukti_bayar', folder: `SIMKA PRO/Keuangan/${f.value.tanggal.slice(0, 4)}/${f.value.tanggal.slice(5, 7)}` })
    }
    const r = await keu.catatPembayaran({ student_id: props.santri.id, tanggal: f.value.tanggal, cara: f.value.cara,
      rekening_tujuan: f.value.cara === 'transfer' ? f.value.rekening_tujuan : null, penyetor: f.value.penyetor, keterangan: f.value.keterangan, bukti_id, riwayat: f.value.riwayat,
      alokasi: terbuka.value.filter((b) => bacaRupiah(alok.value[b.id]) > 0).map((b) => ({ bill_id: b.id, jumlah: bacaRupiah(alok.value[b.id]) })) })
    if (f.value.riwayat) { ui.toast('Catatan pembayaran lama tersimpan.'); emit('tersimpan'); emit('tutup'); return }
    hasil.value = (await keu.kuitansi([r.id]))[0]
    ui.toast(`Pembayaran tersimpan. Kuitansi ${r.nomor}.`); emit('tersimpan')
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
</script>
<template>
  <LembarBawah v-model="buka" :judul="hasil ? 'Pembayaran tersimpan' : 'Catat pembayaran'" lebar>
    <div v-if="hasil" class="w-presensi space-y-4 pb-2">
      <div class="flex items-center gap-3 rounded-2xl p-4" style="background: color-mix(in srgb, var(--c) 12%, rgb(var(--permukaan)))">
        <span class="chip-ikon h-12 w-12 shrink-0"><PhSealCheck :size="28" weight="duotone" /></span>
        <div class="min-w-0"><p class="text-xl font-extrabold tabular-nums">{{ rupiah(hasil.jumlah) }}</p>
          <p class="text-sm text-teks2">Kuitansi {{ hasil.nomor }} · kode {{ hasil.kode_validasi }}</p>
          <p class="text-sm text-teks2">{{ Number(hasil.sisa_total) ? 'Sisa tagihan ' + rupiah(hasil.sisa_total) : 'Seluruh tagihan lunas' }}</p></div>
      </div>
      <div class="flex flex-wrap gap-2">
        <button class="tombol-utama" @click="pratinjau = true"><PhPrinter :size="20" weight="duotone" /> Cetak kuitansi</button>
        <a v-if="hasil.santri?.wali?.no_hp" :href="tautanWA(hasil.santri.wali.no_hp, pesanKuitansi(hasil))" target="_blank" rel="noopener" class="tombol-wa-garis">
          <PhWhatsappLogo :size="20" weight="duotone" /> Kirim konfirmasi ke {{ hasil.santri.wali.nama }}</a>
        <span v-else class="tombol-garis cursor-not-allowed opacity-60"><PhWhatsappLogo :size="20" /> Nomor HP wali belum diisi</span>
        <button class="tombol-garis" @click="emit('tutup')">Selesai</button>
      </div>
      <CetakKeuangan v-model:pratinjau="pratinjau" jenis="kuitansi" :dok="[hasil]" :pengaturan="keu.pengaturan" :pencetak="sesi.pengguna?.nama_lengkap" />
    </div>
    <div v-else-if="f && santri" class="space-y-4 pb-2">
      <p class="rounded-xl bg-permukaan2 p-3 text-sm"><b>{{ santri.nama }}</b> · NIS {{ santri.nis }} · {{ santri.kelas || '–' }}</p>
      <div class="grid gap-3 sm:grid-cols-2">
        <InputTanggal v-model="f.tanggal" label="Tanggal pembayaran" wajib />
        <div><span class="label-isian">Cara bayar</span>
          <div class="flex rounded-xl bg-permukaan2 p-1" role="radiogroup" aria-label="Cara bayar">
            <button v-for="(n, k) in CARA_BAYAR" :key="k" type="button" role="radio" :aria-checked="f.cara === k" @click="f.cara = k"
              :class="['min-h-[40px] flex-1 rounded-lg text-sm font-semibold', f.cara === k ? 'bg-permukaan text-teks shadow-kartu' : 'text-teks2']">{{ n }}</button>
          </div></div>
        <div v-if="f.cara === 'transfer'"><label class="label-isian" for="lb-rek">Ke rekening</label>
          <select id="lb-rek" v-model="f.rekening_tujuan" class="isian"><option v-for="r in keu.pengaturan.rekening" :key="r.nomor" :value="`${r.bank} ${r.nomor}`">{{ r.bank }} {{ r.nomor }} – {{ r.atas_nama }}</option>
            <option value="">Lainnya / tidak dicatat</option></select></div>
        <div><label class="label-isian" for="lb-pen">Penyetor</label><input id="lb-pen" v-model="f.penyetor" class="isian" placeholder="Nama orang tua/wali yang membayar" /></div>
      </div>

      <div>
        <div class="mb-1.5 flex flex-wrap items-end gap-2">
          <p class="label-isian mb-0 flex-1">Tagihan yang dibayar</p>
          <div class="flex gap-1.5"><input v-model="otomatis" inputmode="numeric" class="isian h-10 w-40 text-sm" placeholder="Jumlah diterima" aria-label="Jumlah diterima untuk dibagi otomatis" @keydown.enter.prevent="bagi" />
            <button type="button" class="tombol-garis min-h-[40px] px-3 text-sm" @click="bagi"><PhMagicWand :size="18" /> Bagi otomatis</button></div>
        </div>
        <p v-if="!terbuka.length" class="rounded-xl bg-permukaan2 p-3 text-sm text-teks3">Tidak ada tagihan terbuka untuk santri ini.</p>
        <ul class="divide-y divide-garis rounded-xl border border-garis">
          <li v-for="b in terbuka" :key="b.id" class="flex flex-wrap items-center gap-2 px-3 py-2">
            <button type="button" class="tombol-ikon h-10 w-10" :aria-label="(alok[b.id] ? 'Batalkan pilihan ' : 'Pilih ') + b.tagihan" @click="pilih(b)">
              <component :is="alok[b.id] ? PhCheckSquare : PhSquare" :size="24" :weight="alok[b.id] ? 'fill' : 'regular'" style="color: var(--c)" /></button>
            <div class="min-w-[150px] flex-1"><p class="font-semibold">{{ b.tagihan }}</p>
              <p :class="['text-xs', b.lewat ? 'font-semibold text-merah' : 'text-teks3']">Jatuh tempo {{ formatPendek(b.jatuh_tempo) }} · sisa {{ rupiah(b.sisa) }}{{ b.dibayar > 0 ? ' dari ' + rupiah(b.nominal) : '' }}</p></div>
            <input v-model="alok[b.id]" inputmode="numeric" :class="['isian h-10 w-36 text-right tabular-nums', (bacaRupiah(alok[b.id]) || 0) > Number(b.sisa) && 'ring-2 ring-[#C7332F]']" placeholder="0" :aria-label="'Jumlah dibayar ' + b.tagihan" />
          </li>
        </ul>
      </div>
      <div class="rounded-xl p-3" style="background: color-mix(in srgb, var(--c) 10%, rgb(var(--permukaan)))">
        <p class="flex items-baseline justify-between gap-2"><span class="font-semibold">Jumlah dibayar</span><span class="text-2xl font-extrabold tabular-nums">{{ rupiah(total) }}</span></p>
        <p v-if="total" class="text-xs italic text-teks2">Terbilang: {{ terbilang(total) }}</p>
      </div>
      <div class="grid gap-3 sm:grid-cols-2">
        <div><label class="label-isian" for="lb-ket">Keterangan (tidak wajib)</label><input id="lb-ket" v-model="f.keterangan" class="isian" /></div>
        <div><span class="label-isian">Foto bukti (tidak wajib)</span>
          <label class="tombol-garis w-full cursor-pointer"><PhCamera :size="20" weight="duotone" /> {{ f.bukti ? 'Ganti foto: ' + f.buktiNama.slice(0, 18) : 'Ambil/pilih foto bukti' }}
            <input type="file" accept="image/*" capture="environment" class="sr-only" @change="pilihFoto" /></label></div>
      </div>
      <label class="flex items-start gap-3 rounded-xl border border-garis p-3"><input v-model="f.riwayat" type="checkbox" class="mt-0.5 h-5 w-5 shrink-0" />
        <span><span class="font-semibold">Catatan pembayaran lama</span><span class="block text-xs text-teks3">Untuk pembayaran tahun-tahun lalu yang kuitansinya sudah diberikan dahulu: tercatat sebagai pelunasan tanpa menerbitkan kuitansi bernomor baru.</span></span></label>
      <button class="tombol-utama w-full" :disabled="proses || !total" @click="simpan"><PhFloppyDisk :size="20" weight="duotone" /> {{ f.riwayat ? 'Simpan catatan pembayaran lama' : 'Simpan dan terbitkan kuitansi' }}</button>
    </div>
  </LembarBawah>
</template>
