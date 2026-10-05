<!-- SIMKA PRO | src/pages/klinik/LembarKasus.vue | v1.1 | Fase 6 – Tahap 3 Jurnal musyrif dan klinik lanjutan | 06/10/2026 -->
<script setup>
// Rincian satu kasus klinik: data santri, rujukan, pemeriksaan (rahasia; hanya yang berhak), jejak kasus,
// dan riwayat kasus santri sebelumnya.
// v1.1: surat keterangan sakit (buat/cetak) dan tombol WA kabar ke orang tua/wali (sakit atau sembuh).
import { ref, watch } from 'vue'
import { PhStethoscope, PhPaperPlaneTilt, PhClockCounterClockwise, PhLockSimple, PhFileText, PhPrinter, PhWhatsappLogo } from '@phosphor-icons/vue'
import { useSesi } from '@/stores/sesi'
import { pesanWA, tautanWA } from '@/lib/wa'
import LembarSuratSakit from './LembarSuratSakit.vue'
import CetakSuratSakit from './CetakSuratSakit.vue'
import { useKlinik } from '@/stores/klinik'
import { useUI } from '@/stores/ui'
import { KLINIK, TINDAK_LANJUT, SUMBER_RUJUKAN, HASIL_KASUS, STATUS_KASUS, labelKasus } from '@/lib/klinik'
import { formatWaktu, formatPendek } from '@/lib/tanggal'
import LembarBawah from '@/components/LembarBawah.vue'

const buka = defineModel({ type: Boolean, default: false })
const props = defineProps({ id: { type: String, default: '' } })
const emit = defineEmits(['periksa'])
const kl = useKlinik(); const ui = useUI()
const sesi = useSesi()
const d = ref(null); const memuat = ref(false); const surat = ref([]); const kontak = ref(null)
watch(buka, async (v) => {
  if (!v || !props.id) return
  d.value = null; memuat.value = true; surat.value = []; kontak.value = null
  try {
    d.value = await kl.detail(props.id)
    ;[surat.value, kontak.value] = await Promise.all([kl.daftarSurat(props.id).catch(() => []), kl.kontakWali(props.id).catch(() => null)])
  } catch (e) { ui.toast(e.message, 'galat'); buka.value = false } finally { memuat.value = false }
})

// ---------- Surat keterangan sakit ----------
const lembarSurat = ref(false); const cetak = ref(false); const suratCetak = ref(null)
const diagnosisTerakhir = () => (d.value?.pemeriksaan || []).filter((v) => v.diagnosis).at(-1)?.diagnosis || ''
async function lihatSurat(x) { try { suratCetak.value = await kl.surat(x.id); cetak.value = true } catch (e) { ui.toast(e.message, 'galat') } }
async function suratDibuat(x) { suratCetak.value = x; surat.value = await kl.daftarSurat(props.id).catch(() => [x]); cetak.value = true }

// ---------- WA ke orang tua/wali ----------
function waWali() {
  if (!kontak.value?.no_hp) return ui.toast('Nomor HP orang tua/wali santri ini belum diisi di Data Santri.', 'galat')
  const k = d.value.kasus; const kelas = k.kelas ? 'Kelas ' + k.kelas.replace(/^kelas\s*/i, '') : ''
  const umum = { nama_wali: kontak.value.nama || 'orang tua/wali', nama_santri: k.nama, kelas, pengirim: sesi.pengguna?.nama_lengkap, jabatan_pengirim: 'Klinik Pondok' }
  const pesan = k.status === 'selesai' && k.hasil !== 'batal'
    ? pesanWA('santri_sembuh', { ...umum, tanggal: formatPendek(k.selesai_pada) })
    : pesanWA('santri_sakit', { ...umum, keluhan: k.keluhan, penanganan: k.status === 'menunggu' ? 'menunggu pemeriksaan klinik' : labelKasus(k).n.toLowerCase(),
        tanggal: formatPendek(k.dibuka_pada), keterangan: k.kontrol_pada ? `• Jadwal kontrol: ${formatWaktu(k.kontrol_pada)} WITA` : '' })
  window.open(tautanWA(kontak.value.no_hp, pesan), '_blank', 'noopener')
}
const baris = (label, nilai) => (nilai ? { label, nilai } : null)
</script>
<template>
  <LembarBawah v-model="buka" :judul="d ? d.kasus.nama : 'Rincian kasus'">
    <p v-if="memuat" class="py-8 text-center text-sm text-teks3">Memuat…</p>
    <div v-else-if="d" class="space-y-4 pb-2">
      <div class="rounded-xl bg-permukaan2 p-3 text-sm">
        <p class="flex flex-wrap items-center gap-1.5"><span class="lencana" :class="'w-' + labelKasus(d.kasus).w">{{ labelKasus(d.kasus).n }}</span><span class="text-xs text-teks3">{{ KLINIK[d.kasus.klinik] }}</span></p>
        <p class="mt-1 text-xs text-teks3">{{ d.kasus.nis }} · Kelas {{ (d.kasus.kelas || '–').replace(/^kelas\s*/i, '') }} · {{ d.kasus.kamar || 'Kamar –' }} · {{ d.kasus.halaqah || 'Halaqah –' }}</p>
        <p class="mt-1.5 font-semibold">{{ d.kasus.keluhan }}</p>
        <p class="text-xs text-teks3">Dibuka {{ formatWaktu(d.kasus.dibuka_pada) }}<template v-if="d.kasus.sakit_mulai"> · sakit sejak {{ formatPendek(d.kasus.sakit_mulai) }}</template>
          <template v-if="d.kasus.kontrol_pada"> · kontrol {{ formatWaktu(d.kasus.kontrol_pada) }}</template>
          <template v-if="d.kasus.selesai_pada"> · ditutup {{ formatWaktu(d.kasus.selesai_pada) }}</template></p>
        <p v-if="d.kasus.catatan_selesai" class="text-xs text-teks2">Catatan: {{ d.kasus.catatan_selesai }}</p>
        <button v-if="d.kasus.status !== 'batal'" class="tombol-garis w-presensi mt-3 min-h-[40px] w-full text-sm" @click="waWali">
          <PhWhatsappLogo :size="18" weight="duotone" style="color: var(--c)" /> {{ d.kasus.status === 'selesai' ? 'Kabari wali: sudah sembuh' : 'Kabari wali: sedang sakit' }}{{ kontak?.nama ? ' (' + kontak.nama + ')' : '' }}</button>
        <button v-if="d.boleh_periksa && ['menunggu', 'ditangani'].includes(d.kasus.status)" class="tombol-utama mt-3 min-h-[40px] w-full text-sm"
          @click="emit('periksa', { ...d.kasus, id: d.kasus.id })"><PhStethoscope :size="18" /> {{ d.kasus.status === 'menunggu' ? 'Periksa sekarang' : 'Catat kontrol' }}</button>
      </div>

      <section>
        <h3 class="mb-2 flex items-center gap-2 text-sm font-bold"><PhPaperPlaneTilt :size="18" weight="duotone" /> Rujukan ({{ d.rujukan.length }})</h3>
        <ul class="space-y-2">
          <li v-for="(r, i) in d.rujukan" :key="i" class="rounded-xl border border-garis p-3 text-sm">
            <p class="font-semibold">{{ r.keluhan }}</p>
            <p class="text-xs text-teks3">{{ SUMBER_RUJUKAN[r.sumber] }}{{ r.perujuk ? ' · ' + r.perujuk : '' }} · {{ formatWaktu(r.dirujuk_pada) }} · periksa {{ r.waktu_periksa === 'besok' ? 'besok' : 'hari ini' }}</p>
          </li>
        </ul>
      </section>

      <section v-if="d.detail">
        <h3 class="mb-2 flex items-center gap-2 text-sm font-bold"><PhStethoscope :size="18" weight="duotone" /> Pemeriksaan ({{ d.pemeriksaan.length }})</h3>
        <p v-if="!d.pemeriksaan.length" class="rounded-xl border border-dashed border-garis p-3 text-center text-xs text-teks3">Belum diperiksa.</p>
        <ul class="space-y-2">
          <li v-for="v in d.pemeriksaan" :key="v.id" class="rounded-xl border border-garis p-3 text-sm" :class="'w-' + TINDAK_LANJUT[v.tindak_lanjut].w">
            <p class="flex flex-wrap items-center gap-1.5"><b>{{ v.jenis === 'kontrol' ? 'Kontrol' : 'Pemeriksaan' }}</b>
              <span class="lencana" :class="'w-' + TINDAK_LANJUT[v.tindak_lanjut].w">{{ TINDAK_LANJUT[v.tindak_lanjut].n }}</span></p>
            <p class="text-xs text-teks3">{{ formatWaktu(v.waktu) }} · {{ v.petugas || '–' }}</p>
            <dl class="mt-1.5 grid grid-cols-[7.5rem_1fr] gap-x-2 gap-y-0.5 text-xs">
              <template v-for="b in [baris('Keluhan', v.keluhan), baris('Pemeriksaan', v.pemeriksaan), baris('Diagnosis', v.diagnosis), baris('Tindakan', v.tindakan), baris('Obat/terapi', v.obat), baris('Dirujuk ke', v.rujuk_ke), baris('Kontrol', v.kontrol_pada && formatWaktu(v.kontrol_pada)), baris('Catatan', v.catatan)].filter(Boolean)" :key="b.label">
                <dt class="text-teks3">{{ b.label }}</dt><dd class="text-teks">{{ b.nilai }}</dd></template>
            </dl>
          </li>
        </ul>
      </section>
      <p v-else class="flex items-center gap-2 rounded-xl bg-permukaan2 p-3 text-xs text-teks2"><PhLockSimple :size="18" weight="duotone" /> Catatan pemeriksaan hanya dapat dibaca petugas klinik dan pimpinan Kesantrian.</p>

      <section v-if="surat.length || (d.boleh_periksa && d.pemeriksaan?.length)">
        <div class="mb-2 flex items-center gap-2"><PhFileText :size="18" weight="duotone" /><h3 class="flex-1 text-sm font-bold">Surat keterangan sakit ({{ surat.length }})</h3>
          <button v-if="d.boleh_periksa && d.pemeriksaan?.length" class="tombol-garis min-h-[36px] px-3 text-xs" @click="lembarSurat = true">Buat surat</button></div>
        <ul class="divide-y divide-garis rounded-xl border border-garis text-sm">
          <li v-for="x in surat" :key="x.id" class="flex items-center gap-2 px-3 py-2">
            <span class="min-w-0 flex-1"><b class="block truncate">{{ x.nomor }}</b><span class="text-xs text-teks3">Istirahat {{ formatPendek(x.istirahat_mulai) }}{{ x.istirahat_sampai !== x.istirahat_mulai ? ' s.d. ' + formatPendek(x.istirahat_sampai) : '' }} · kode {{ x.kode_validasi }}</span></span>
            <button class="tombol-garis min-h-[36px] px-3 text-xs" @click="lihatSurat(x)"><PhPrinter :size="16" /> Cetak</button></li>
          <li v-if="!surat.length" class="px-3 py-2 text-xs text-teks3">Belum ada surat.</li>
        </ul>
      </section>

      <section v-if="d.detail && d.jejak?.length">
        <h3 class="mb-2 flex items-center gap-2 text-sm font-bold"><PhClockCounterClockwise :size="18" weight="duotone" /> Jejak kasus</h3>
        <ol class="relative ml-2 space-y-2 border-l border-garis pl-4 text-xs">
          <li v-for="(j, i) in d.jejak" :key="i"><span class="absolute -left-[5px] mt-1 h-2.5 w-2.5 rounded-full bg-[#C7332F]" aria-hidden="true" />
            <p class="text-teks">{{ j.isi }}</p><p class="text-teks3">{{ formatWaktu(j.pada) }}{{ j.oleh ? ' · ' + j.oleh : '' }}</p></li>
        </ol>
      </section>

      <section v-if="d.riwayat_santri.length">
        <h3 class="mb-2 text-sm font-bold">Riwayat klinik sebelumnya</h3>
        <ul class="divide-y divide-garis rounded-xl border border-garis text-sm">
          <li v-for="h in d.riwayat_santri" :key="h.id" class="flex items-center gap-2 px-3 py-2">
            <span class="min-w-0 flex-1"><span class="block truncate">{{ h.keluhan }}</span><span class="text-xs text-teks3">{{ formatPendek(h.dibuka_pada) }}</span></span>
            <span class="lencana" :class="'w-' + (h.status === 'selesai' ? 'presensi' : STATUS_KASUS[h.status].w)">{{ h.status === 'selesai' ? HASIL_KASUS[h.hasil] || 'Selesai' : STATUS_KASUS[h.status].p }}</span>
          </li>
        </ul>
      </section>
    </div>
  </LembarBawah>
  <LembarSuratSakit v-model="lembarSurat" :kasus="d?.kasus" :diagnosis="diagnosisTerakhir()" @dibuat="suratDibuat" />
  <CetakSuratSakit v-model:pratinjau="cetak" :surat="suratCetak" />
</template>
