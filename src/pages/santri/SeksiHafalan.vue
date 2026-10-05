<!-- SIMKA PRO | src/pages/santri/SeksiHafalan.vue | v1.0 | Fase 5 – Tahap 6 Penutup fase tahfizh | 05/10/2026 -->
<script setup>
// Bagian Hafalan pada profil santri terpadu: posisi sabaq/sabqi/manzil, juz resmi (kisi 1–30), usulan menunggu,
// jenjang sertifikasi, status capaian bulan berjalan, riwayat setoran 14 hari, riwayat ujian, dan WA rekap hafalan ke wali.
import { ref, computed, onMounted, watch } from 'vue'
import { PhBookOpenText, PhExam, PhTrendUp } from '@phosphor-icons/vue'
import { useTahfizh } from '@/stores/tahfizh'
import { PROGRAM, STATUS_BULANAN, HASIL_UJIAN, formatPosisi, ringkasJuz, labelBulan } from '@/lib/tahfizh'
import { KODE } from '@/lib/absensi'
import { formatPendek, hariIniISO } from '@/lib/tanggal'
import { pesanWA } from '@/lib/wa'
import { kontakUtama, labelRombel } from '@/lib/santri'
import GridJuz from '@/components/GridJuz.vue'
import TombolWA from '@/components/TombolWA.vue'

const props = defineProps({ santri: { type: Object, required: true } })
const tz = useTahfizh(); const h = ref(null); const riwayat = ref([]); const galat = ref('')
async function muat() {
  galat.value = ''
  try {
    const d = new Date(); d.setDate(d.getDate() - 13)
    const awal = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
    const [x, r] = await Promise.all([tz.hafalanSantri(props.santri.id), tz.riwayatSetoran(props.santri.id, awal, hariIniISO())])
    h.value = x; riwayat.value = r || []
  } catch (e) { galat.value = e.message }
}
onMounted(muat); watch(() => props.santri.id, muat)
const juzAwal = computed(() => (h.value?.juz || []).filter((j) => j.sumber === 'awal').map((j) => j.juz))
const juzLain = computed(() => (h.value?.juz || []).filter((j) => j.sumber !== 'awal').map((j) => j.juz))
const tambah14 = computed(() => riwayat.value.reduce((t, r) => t + Math.max(0, r.tambah_hal || 0), 0))
const b = computed(() => h.value?.bulan_ini)
const kontak = computed(() => kontakUtama(props.santri))
const pesan = computed(() => pesanWA('rekap_hafalan', {
  nama_wali: kontak.value?.nama, nama_santri: props.santri.nama_lengkap, kelas: labelRombel(props.santri), halaqah: h.value?.halaqah || '-',
  posisi: formatPosisi(h.value?.sabaq_hal || 0, true), total_juz: (h.value?.juz || []).length,
  periode: b.value ? labelBulan(hariIniISO().slice(0, 8) + '01') : '14 hari terakhir',
  capaian: b.value ? `bertambah ${b.value.tambah_hal} dari target ${b.value.target_hal} halaman (${STATUS_BULANAN[b.value.status]?.n})` : `bertambah ${tambah14.value} halaman`,
  keterangan: h.value?.usulan?.length ? `• Juz ${ringkasJuz(h.value.usulan)} sedang menunggu validasi.` : '',
}))
</script>
<template>
  <section class="kartu w-tahfizh mt-4 p-5">
    <div class="mb-3 flex flex-wrap items-center gap-3"><span class="chip-ikon h-10 w-10"><PhBookOpenText :size="22" weight="duotone" /></span>
      <div class="min-w-[200px] flex-1"><h3 class="judul-bagian">Hafalan</h3>
        <p class="text-sm text-teks3">{{ h ? `${PROGRAM[h.program]} · ${h.halaqah || 'belum masuk halaqah'}${h.muhaffizh ? ' · ' + h.muhaffizh : ''}` : 'Memuat…' }}</p></div>
      <TombolWA v-if="h && kontak?.no_hp" kecil :hp="kontak.no_hp" :pesan="pesan" label="WA rekap hafalan ke wali" />
    </div>
    <p v-if="galat" class="text-sm text-teks3">{{ galat }}</p>
    <template v-else-if="h">
      <div class="grid grid-cols-2 gap-2 sm:grid-cols-4">
        <div v-for="k in ['sabaq', 'sabqi', 'manzil']" :key="k" class="rounded-2xl border border-garis p-3">
          <p class="text-xs font-bold uppercase tracking-wide" style="color: var(--c)">{{ k }}</p><p class="mt-1 text-lg font-extrabold tabular-nums">{{ formatPosisi(h[k + '_hal']) }}</p></div>
        <div class="rounded-2xl border border-garis p-3"><p class="text-xs font-bold uppercase tracking-wide" style="color: var(--c)">Hafalan resmi</p>
          <p class="mt-1 text-lg font-extrabold tabular-nums">{{ h.juz.length }} juz</p><p class="text-xs text-teks3">Sertifikasi {{ h.jenjang_sertifikasi ? h.jenjang_sertifikasi + ' juz' : 'belum' }}</p></div>
      </div>
      <div class="mt-3"><GridJuz :model-value="juzAwal" :terkunci="juzLain" :sedang="h.juz_sedang" baca-saja label="Juz resmi" label-pilih="Data awal" label-kunci="Lulus ujian/disetujui" /></div>
      <p v-if="h.usulan.length" class="mt-2 text-sm text-teks2">Menunggu validasi: juz {{ ringkasJuz(h.usulan) }}</p>
      <div v-if="b" class="mt-3 flex flex-wrap items-center gap-2 rounded-xl bg-permukaan2 p-3 text-sm">
        <PhTrendUp :size="18" weight="duotone" style="color: var(--c)" /><b>Bulan ini:</b> bertambah {{ b.tambah_hal }} dari target {{ b.target_hal }} halaman
        <span class="lencana" :class="'w-' + STATUS_BULANAN[b.status].w">{{ STATUS_BULANAN[b.status].n }}</span>
      </div>
      <div class="mt-3 grid gap-3 lg:grid-cols-2">
        <div><p class="mb-1 text-sm font-bold">Setoran 14 hari terakhir · +{{ tambah14 }} hal</p>
          <ul class="max-h-60 divide-y divide-garis overflow-y-auto rounded-xl border border-garis text-sm">
            <li v-for="(r, i) in riwayat" :key="i" class="flex gap-2 px-3 py-1.5"><span class="w-24 shrink-0 text-teks3">{{ formatPendek(r.tanggal) }}</span><span class="w-20 shrink-0 text-teks3">{{ r.sesi }}</span>
              <span class="min-w-0 flex-1">{{ ['I', 'S', 'B', 'A'].includes(r.kehadiran) ? 'Tidak setor (' + KODE[r.kehadiran].n + ')' : r.sabaq_hal == null ? 'Sama' : `${formatPosisi(r.sabaq_hal)} (+${r.tambah_hal})` }}</span></li>
            <li v-if="!riwayat.length" class="px-3 py-3 text-teks3">Belum ada setoran tercatat.</li>
          </ul></div>
        <div><p class="mb-1 flex items-center gap-1.5 text-sm font-bold"><PhExam :size="16" weight="duotone" /> Ujian</p>
          <ul class="max-h-60 divide-y divide-garis overflow-y-auto rounded-xl border border-garis text-sm">
            <li v-for="(u, i) in h.ujian" :key="i" class="px-3 py-1.5"><b>{{ u.jenis === 'kenaikan' ? `Kenaikan juz ${ringkasJuz(u.juz)}` : `Sertifikasi ${u.jenjang} juz` }}</b>
              <span v-if="u.hasil" class="lencana ml-1" :class="'w-' + HASIL_UJIAN[u.hasil].w">{{ HASIL_UJIAN[u.hasil].n }} {{ u.nilai_akhir }} ({{ u.huruf }})</span>
              <span v-else class="ml-1 text-teks3">{{ u.status }}</span>
              <span class="block text-xs text-teks3">{{ u.diuji_pada ? formatPendek(u.diuji_pada) : '' }}{{ u.penguji ? ' · ' + u.penguji : '' }}</span></li>
            <li v-if="!h.ujian.length" class="px-3 py-3 text-teks3">Belum ada ujian.</li>
          </ul></div>
      </div>
    </template>
  </section>
</template>
