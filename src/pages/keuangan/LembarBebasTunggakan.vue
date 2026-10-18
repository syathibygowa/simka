<!-- SIMKA PRO | src/pages/keuangan/LembarBebasTunggakan.vue | v1.0 | 14.7.0: Surat Keterangan Bebas Tunggakan (periksa, terbitkan, cetak, cabut) | 18/10/2026 -->
<script setup>
// Surat Keterangan Bebas Tunggakan seorang santri (mis. untuk pengambilan ijazah atau pindah sekolah):
//   1. periksa: tagihan terbuka yang sudah ditagihkan sampai hari ini harus nol; tagihan yang baru ditagihkan kemudian dicatat sebagai keterangan
//   2. keperluan (pilihan cepat atau tulis sendiri) → terbit bernomor SKBT, ditandatangani elektronik Bendahara (QR, Cek Keabsahan)
//   3. cetak F4 (Direktur "Mengetahui" di kiri, Bendahara di kanan); riwayat surat dan pencabutan
import { ref, watch } from 'vue'
import { PhSealCheck, PhWarningCircle, PhPrinter, PhProhibit, PhCheckCircle } from '@phosphor-icons/vue'
import { useKeuangan } from '@/stores/keuangan'
import { useUI } from '@/stores/ui'
import { useSesi } from '@/stores/sesi'
import { formatPendek, formatPanjang } from '@/lib/tanggal'
import { rupiah } from '@/lib/keuangan'
import LembarBawah from '@/components/LembarBawah.vue'
import CetakKeuangan from '@/components/cetak/CetakKeuangan.vue'

const props = defineProps({ santri: { type: Object, default: null } })   // { id, nama }
const emit = defineEmits(['tutup', 'terbit'])
const keu = useKeuangan(); const ui = useUI(); const sesi = useSesi()
const buka = ref(false)
const cek = ref(null); const keperluan = ref(''); const proses = ref(false); const dok = ref([]); const pratinjau = ref(false)
const cabutId = ref(null); const alasan = ref('')
const PILIHAN = ['Pengambilan ijazah', 'Pindah sekolah/mutasi keluar', 'Pendaftaran ujian akhir', 'Pengambilan rapor', 'Kelulusan']
async function muat() { try { cek.value = await keu.cekBebas(props.santri.id) } catch (e) { ui.toast(e.message, 'galat') } }
watch(() => props.santri, (s) => { buka.value = !!s; if (s) { cek.value = null; keperluan.value = ''; cabutId.value = null; muat() } }, { immediate: true })
watch(buka, (v) => { if (!v) emit('tutup') })
async function terbitkan() {
  if (keperluan.value.trim().length < 5) return ui.toast('Tuliskan keperluan surat (minimal 5 huruf).', 'galat')
  proses.value = true
  try {
    const r = await keu.terbitkanBebas({ student_id: props.santri.id, keperluan: keperluan.value.trim() })
    ui.toast(`Surat keterangan bebas tunggakan ${r.nomor} terbit.`); emit('terbit'); await muat(); cetak(r.id)
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
async function cetak(id) { try { dok.value = await keu.suratBebas([id]); pratinjau.value = true } catch (e) { ui.toast(e.message, 'galat') } }
async function cabut() {
  if (alasan.value.trim().length < 5) return ui.toast('Tuliskan alasan pencabutan (minimal 5 huruf).', 'galat')
  try { await keu.cabutBebas(cabutId.value, alasan.value.trim()); ui.toast('Surat dicabut; Cek Keabsahan menampilkan status dicabut.'); cabutId.value = null; alasan.value = ''; muat() } catch (e) { ui.toast(e.message, 'galat') }
}
</script>
<template>
  <LembarBawah v-model="buka" judul="Surat keterangan bebas tunggakan" lebar>
    <div class="w-keuangan space-y-4 pb-2">
      <p v-if="!cek" class="py-6 text-center text-sm text-teks3">Memeriksa tagihan…</p>
      <template v-else>
        <div class="flex items-center gap-3 rounded-2xl border border-garis p-3">
          <span :class="['chip-ikon h-12 w-12 shrink-0', cek.terbuka.length ? 'w-klinik' : 'w-presensi']"><component :is="cek.terbuka.length ? PhWarningCircle : PhCheckCircle" :size="28" weight="duotone" /></span>
          <div class="min-w-0"><p class="font-bold">{{ cek.santri?.nama }} <span class="font-normal text-teks3">· {{ cek.santri?.nis }} · {{ cek.santri?.kelas || '–' }}</span></p>
            <p :class="['text-sm font-semibold', cek.terbuka.length ? 'text-merah' : '']">{{ cek.terbuka.length ? `Masih ada ${cek.terbuka.length} tagihan belum lunas (${rupiah(cek.terbuka.reduce((a, b) => a + Number(b.sisa), 0))})` : 'Tidak ada tunggakan. Surat dapat diterbitkan.' }}</p>
            <p class="text-xs text-teks3">{{ cek.lunas.tagihan }} tagihan lunas ({{ rupiah(cek.lunas.jumlah) }}){{ cek.lunas.terakhir ? `; pembayaran terakhir ${formatPendek(cek.lunas.terakhir)}` : '' }}</p></div>
        </div>
        <ul v-if="cek.terbuka.length" class="divide-y divide-garis rounded-xl border border-garis text-sm">
          <li v-for="b in cek.terbuka" :key="b.bill_id" class="flex justify-between px-3 py-2"><span>{{ b.tagihan }} <span class="text-xs text-teks3">jatuh tempo {{ formatPendek(b.jatuh_tempo) }}</span></span><b class="tabular-nums text-merah">{{ rupiah(b.sisa) }}</b></li>
        </ul>
        <p v-if="cek.mendatang.length" class="rounded-xl bg-permukaan2 p-3 text-xs text-teks2">Tagihan yang baru ditagihkan setelah hari ini tidak menghalangi surat: {{ cek.mendatang.map((b) => `${b.tagihan} (${formatPendek(b.tanggal_tagih)})`).join(', ') }}. Batalkan tagihan tersebut bila santri keluar.</p>

        <template v-if="!cek.terbuka.length && keu.hak.kelola">
          <div><p class="label-isian">Keperluan <span class="text-merah">*</span></p>
            <div class="mb-2 flex flex-wrap gap-1.5"><button v-for="k in PILIHAN" :key="k" type="button" :aria-pressed="keperluan === k" @click="keperluan = k"
              :class="['min-h-[38px] rounded-full border px-3 text-sm', keperluan === k ? 'border-transparent bg-[#9A4F00] font-semibold text-white' : 'border-garis text-teks2']">{{ k }}</button></div>
            <input v-model="keperluan" class="isian" placeholder="Atau tulis keperluan lain" aria-label="Keperluan surat" /></div>
          <button class="tombol-utama w-full" :disabled="proses" @click="terbitkan"><PhSealCheck :size="20" weight="duotone" /> {{ proses ? 'Menerbitkan…' : 'Terbitkan surat keterangan' }}</button>
          <p class="text-xs text-teks3">Surat bernomor SKBT dan ditandatangani elektronik oleh Bendahara Pondok; keabsahannya dapat diperiksa melalui QR.</p>
        </template>

        <div v-if="cek.riwayat.length"><p class="judul-bagian mb-2">Riwayat surat</p>
          <ul class="divide-y divide-garis rounded-xl border border-garis">
            <li v-for="l in cek.riwayat" :key="l.id" :class="['flex flex-wrap items-center gap-2 px-3 py-2 text-sm', l.status === 'dicabut' && 'opacity-60']">
              <span class="min-w-0 flex-1"><b>{{ l.nomor }}</b> · {{ formatPanjang(l.tanggal) }}<span class="block text-xs text-teks3">{{ l.keperluan }}{{ l.status === 'dicabut' ? ' · dicabut' : '' }}</span></span>
              <button class="tombol-ikon" aria-label="Cetak surat" @click="cetak(l.id)"><PhPrinter :size="20" /></button>
              <button v-if="keu.hak.kelola && l.status === 'sah'" class="tombol-ikon text-merah" aria-label="Cabut surat" @click="cabutId = l.id"><PhProhibit :size="20" /></button>
            </li>
          </ul>
          <div v-if="cabutId" class="mt-2 space-y-2 rounded-xl border border-garis p-3">
            <label class="label-isian" for="bt-alasan">Alasan pencabutan</label><textarea id="bt-alasan" v-model="alasan" rows="2" class="isian" />
            <div class="flex gap-2"><button class="tombol-garis flex-1" @click="cabutId = null">Batal</button><button class="tombol-utama flex-1" @click="cabut">Cabut surat</button></div>
          </div>
        </div>
      </template>
      <CetakKeuangan v-model:pratinjau="pratinjau" jenis="bebas" :dok="dok" :pengaturan="keu.pengaturan" :pencetak="sesi.pengguna?.nama_lengkap" />
    </div>
  </LembarBawah>
</template>
