<!-- SIMKA PRO | src/pages/wali/RiwayatWali.vue | v1.0 | Fase 9 – Tahap 13.1.0 Perizinan, kunjungan, titipan, riwayat sakit | 15/10/2026 -->
<script setup>
// Satu halaman untuk empat bagian Portal Wali (prop bagian):
//   perizinan : izin keluar/pulang yang disetujui + keluar/kembali di gerbang + libur santri yang disahkan
//   kunjungan : kunjungan orang tua/wali yang dicatat Security
//   titipan   : titipan untuk anak (diterima/diambil); yang masih di pos selalu tampil
//   sakit     : riwayat Klinik ringkas tanpa diagnosis (hanya bila dinyalakan superadmin)
import { computed, ref, watch } from 'vue'
import { PhDoorOpen, PhHandshake, PhPackage, PhFirstAidKit, PhSignOut, PhSignIn, PhWarningCircle, PhCalendarStar, PhClock } from '@phosphor-icons/vue'
import { usePortalWali } from '@/stores/portalWali'
import { STATUS_IZIN, JENIS_IZIN, JENIS_PERIODE } from '@/lib/izin'
import { JENIS_TITIPAN, STATUS_TITIPAN, PENGAMBIL, rupiah } from '@/lib/security'
import { STATUS_KASUS, TINDAK_LANJUT, HASIL_KASUS } from '@/lib/klinik'
import { HUBUNGAN_WALI } from '@/lib/portalWali'
import { formatWaktu, formatHari, formatPendek } from '@/lib/tanggal'
import PilihPeriode from './PilihPeriode.vue'

defineOptions({ inheritAttrs: false })
const props = defineProps({ bagian: { type: String, required: true } })
const pw = usePortalWali()
const periode = ref({}); const d = ref(null); const memuat = ref(false); const galat = ref('')

const INFO = {
  perizinan: { n: 'Perizinan dan libur', ikon: PhDoorOpen, w: 'pengajuan', kosong: 'Tidak ada izin keluar atau libur pada periode ini.' },
  kunjungan: { n: 'Kunjungan', ikon: PhHandshake, w: 'security', kosong: 'Belum ada kunjungan tercatat pada periode ini.' },
  titipan: { n: 'Titipan', ikon: PhPackage, w: 'tugas', kosong: 'Tidak ada titipan pada periode ini.' },
  sakit: { n: 'Riwayat sakit', ikon: PhFirstAidKit, w: 'klinik', kosong: 'Tidak ada kunjungan Klinik pada periode ini. Alhamdulillah.' },
}
const info = computed(() => INFO[props.bagian])

async function muat() {
  if (!periode.value.mulai) return
  memuat.value = true; galat.value = ''
  try { d.value = await pw.ambil(props.bagian, periode.value) } catch (e) { galat.value = e.message } finally { memuat.value = false }
}
watch([periode, () => pw.aktif?.nis, () => props.bagian], muat, { deep: true, immediate: true })

const kosong = computed(() => {
  if (!d.value) return false
  if (props.bagian === 'perizinan') return !d.value.izin?.length && !d.value.libur?.length
  return !(d.value[{ kunjungan: 'kunjungan', titipan: 'titipan', sakit: 'kasus' }[props.bagian]] || []).length
})
const HUB = { ...HUBUNGAN_WALI, saudara: 'Saudara', kakek: 'Kakek', nenek: 'Nenek', paman: 'Paman', bibi: 'Bibi', lainnya: 'Lainnya' }
</script>

<template>
  <div :class="['space-y-4', 'w-' + info.w]">
    <PilihPeriode v-model="periode" />
    <p v-if="galat" class="kartu p-4 text-sm font-semibold text-merah" role="alert">{{ galat }}</p>
    <div v-if="memuat && !d" class="kartu h-32 animate-pulse" aria-busy="true" />
    <p v-if="d?.nonaktif" class="kartu p-6 text-center text-teks3">Informasi ini tidak ditampilkan oleh pondok.</p>
    <p v-else-if="kosong" class="kartu p-8 text-center text-teks3">{{ info.kosong }}</p>

    <!-- PERIZINAN -->
    <template v-if="bagian === 'perizinan' && d && !d.nonaktif">
      <section v-if="d.libur?.length" class="space-y-2">
        <h2 class="judul-bagian px-1">Libur santri</h2>
        <article v-for="(l, i) in d.libur" :key="'l' + i" class="kartu w-agenda flex gap-3 p-4">
          <span class="chip-ikon h-10 w-10"><PhCalendarStar :size="22" weight="duotone" /></span>
          <div class="min-w-0 flex-1">
            <p class="font-semibold">{{ l.nama }} <span class="font-normal text-teks3">· {{ JENIS_PERIODE[l.jenis] || l.jenis }}</span></p>
            <p class="text-sm text-teks2">Pulang {{ formatWaktu(l.pulang_pada) }} · kembali paling lambat {{ formatWaktu(l.kembali_batas) }}</p>
          </div>
          <span :class="['lencana shrink-0 self-start', l.keputusan === 'boleh' ? 'w-presensi' : 'w-klinik']">{{ l.keputusan === 'boleh' ? 'Boleh libur' : 'Tidak libur' }}</span>
        </article>
      </section>
      <section v-if="d.izin?.length" class="space-y-2">
        <h2 class="judul-bagian px-1">Izin keluar dan pulang</h2>
        <article v-for="(x, i) in d.izin" :key="'i' + i" class="kartu p-4">
          <div class="flex items-start gap-3">
            <span :class="['chip-ikon h-10 w-10', 'w-' + (STATUS_IZIN[x.status]?.w || 'pengajuan')]"><component :is="STATUS_IZIN[x.status]?.ikon || PhDoorOpen" :size="22" weight="duotone" /></span>
            <div class="min-w-0 flex-1">
              <p class="font-semibold">{{ JENIS_IZIN[x.jenis] || x.jenis }}</p>
              <p class="text-sm text-teks2">{{ x.alasan }}</p>
            </div>
            <span :class="['lencana shrink-0', 'w-' + (STATUS_IZIN[x.status]?.w || 'pengajuan')]">{{ STATUS_IZIN[x.status]?.n || x.status }}</span>
          </div>
          <dl class="mt-3 grid gap-x-4 gap-y-1.5 text-sm sm:grid-cols-2">
            <div><dt class="text-xs text-teks3">Rencana</dt><dd>{{ formatWaktu(x.keluar_pada) }} s.d. {{ formatWaktu(x.kembali_batas) }}</dd></div>
            <div v-if="x.penjemput"><dt class="text-xs text-teks3">Penjemput</dt><dd>{{ x.penjemput }}<template v-if="x.hubungan_penjemput"> ({{ x.hubungan_penjemput }})</template></dd></div>
            <div v-if="x.keluar_aktual"><dt class="flex items-center gap-1 text-xs text-teks3"><PhSignOut :size="14" /> Keluar gerbang</dt><dd>{{ formatWaktu(x.keluar_aktual) }}</dd></div>
            <div v-if="x.kembali_pada"><dt class="flex items-center gap-1 text-xs text-teks3"><PhSignIn :size="14" /> Kembali di gerbang</dt><dd>{{ formatWaktu(x.kembali_pada) }}</dd></div>
          </dl>
          <p v-if="x.terlambat" class="mt-2 flex items-center gap-1.5 text-sm font-semibold text-merah"><PhWarningCircle :size="18" weight="fill" />
            {{ x.status === 'keluar' ? 'Sudah melewati batas kembali.' : 'Kembali melewati batas waktu.' }}</p>
        </article>
      </section>
    </template>

    <!-- KUNJUNGAN -->
    <template v-if="bagian === 'kunjungan' && d?.kunjungan?.length">
      <article v-for="(v, i) in d.kunjungan" :key="i" class="kartu flex gap-3 p-4">
        <span class="chip-ikon h-10 w-10"><PhHandshake :size="22" weight="duotone" /></span>
        <div class="min-w-0 flex-1">
          <p class="font-semibold">{{ formatHari(v.datang_pada) }}</p>
          <p class="text-sm text-teks2">{{ v.pengunjung }}<template v-if="v.hubungan"> ({{ HUB[v.hubungan] || v.hubungan }})</template> · {{ v.jumlah_orang }} orang</p>
          <p class="flex items-center gap-1 text-xs text-teks3"><PhClock :size="14" /> Datang {{ formatWaktu(v.datang_pada) }}<template v-if="v.pulang_pada"> · pulang {{ formatWaktu(v.pulang_pada) }}</template></p>
        </div>
        <span v-if="v.luar_jadwal" class="lencana w-pengajuan shrink-0 self-start">Di luar jadwal</span>
      </article>
    </template>

    <!-- TITIPAN -->
    <template v-if="bagian === 'titipan' && d?.titipan?.length">
      <article v-for="(t, i) in d.titipan" :key="i" class="kartu p-4">
        <div class="flex items-start gap-3">
          <span :class="['chip-ikon h-10 w-10', 'w-' + (JENIS_TITIPAN[t.jenis]?.w || 'security')]"><component :is="JENIS_TITIPAN[t.jenis]?.ikon || PhPackage" :size="22" weight="duotone" /></span>
          <div class="min-w-0 flex-1">
            <p class="font-semibold">{{ JENIS_TITIPAN[t.jenis]?.n || t.jenis }}<template v-if="t.uraian"> · {{ t.uraian }}</template></p>
            <p class="text-sm text-teks2">Dari {{ t.pengirim || '–' }}<template v-if="t.ekspedisi"> lewat {{ t.ekspedisi }}</template><template v-if="t.nominal"> · {{ rupiah(t.nominal) }}</template></p>
          </div>
          <span :class="['lencana shrink-0', 'w-' + (STATUS_TITIPAN[t.status]?.w || 'pengajuan')]">{{ t.status === 'di_pos' ? 'Di pos, belum diambil' : STATUS_TITIPAN[t.status]?.n || t.status }}</span>
        </div>
        <p class="mt-2 text-xs text-teks3">Diterima pos {{ formatWaktu(t.diterima_pada) }}<template v-if="t.diambil_pada"> · diambil {{ formatWaktu(t.diambil_pada) }} oleh {{ t.pengambil_nama || PENGAMBIL[t.pengambil_jenis] || '–' }}</template></p>
      </article>
    </template>

    <!-- SAKIT -->
    <template v-if="bagian === 'sakit' && d?.kasus?.length">
      <p class="px-1 text-sm text-teks3">Ringkasan dari Klinik pondok. Untuk keterangan lebih lanjut, hubungi wali kelas atau musyrif.</p>
      <article v-for="(c, i) in d.kasus" :key="i" class="kartu p-4">
        <div class="flex items-start gap-3">
          <span :class="['chip-ikon h-10 w-10', 'w-' + (TINDAK_LANJUT[c.tindak_lanjut]?.w || 'klinik')]"><component :is="TINDAK_LANJUT[c.tindak_lanjut]?.ikon || PhFirstAidKit" :size="22" weight="duotone" /></span>
          <div class="min-w-0 flex-1">
            <p class="font-semibold">{{ formatHari(c.dibuka_pada) }}</p>
            <p class="text-sm text-teks2">Keluhan: {{ c.keluhan || '–' }}</p>
            <p v-if="c.tindak_lanjut" class="text-sm text-teks2">Penanganan: {{ TINDAK_LANJUT[c.tindak_lanjut]?.n || c.tindak_lanjut }}</p>
            <p class="text-xs text-teks3"><template v-if="c.kontrol_pada">Kontrol {{ formatPendek(c.kontrol_pada) }} · </template>
              <template v-if="c.selesai_pada">Selesai {{ formatPendek(c.selesai_pada) }}<template v-if="c.hasil"> ({{ HASIL_KASUS[c.hasil] || c.hasil }})</template></template></p>
          </div>
          <span :class="['lencana shrink-0', 'w-' + (STATUS_KASUS[c.status]?.w || 'klinik')]">{{ STATUS_KASUS[c.status]?.p || c.status }}</span>
        </div>
      </article>
    </template>
  </div>
</template>
