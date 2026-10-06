<!-- SIMKA PRO | src/pages/santri/SeksiSecuritySantri.vue | v1.0 | Fase 7 – Tahap 5 Penutup fase | 06/10/2026 -->
<script setup>
// Bagian profil santri terpadu (Fase 7): riwayat gerbang (keluar, kembali, ditolak, terlambat), titipan beserta
// pengambilnya, kunjungan orang tua, dan keputusan libur yang sudah disahkan.
import { ref, watch } from 'vue'
import { PhShieldCheck, PhDoorOpen, PhPackage, PhUsersThree, PhCalendarCheck } from '@phosphor-icons/vue'
import { useSecurity } from '@/stores/security'
import { JENIS_LOG, JENIS_TITIPAN, STATUS_TITIPAN, PENGAMBIL, durasi, rupiah } from '@/lib/security'
import { formatWaktu, formatPendek } from '@/lib/tanggal'

const props = defineProps({ santri: { type: Object, required: true } })
const sc = useSecurity(); const d = ref(null); const galat = ref('')
async function muat() { galat.value = ''; try { d.value = await sc.riwayatSantri(props.santri.id) } catch (e) { galat.value = e.message } }
watch(() => props.santri?.id, (v) => v && muat(), { immediate: true })
</script>
<template>
  <section class="kartu w-security mt-4 p-5">
    <div class="mb-3 flex flex-wrap items-center gap-3"><span class="chip-ikon h-10 w-10"><PhShieldCheck :size="22" weight="duotone" /></span>
      <div class="min-w-0 flex-1"><h3 class="judul-bagian">Security dan libur</h3>
        <p class="text-sm text-teks3"><template v-if="d">{{ d.ringkasan.keluar }} kali keluar · {{ d.ringkasan.terlambat }} kali terlambat kembali · {{ d.ringkasan.ditolak }} kali ditolak di gerbang<template v-if="d.ringkasan.titipan_di_pos"> · {{ d.ringkasan.titipan_di_pos }} titipan menunggu diambil</template></template>
          <template v-else>Riwayat gerbang, titipan, kunjungan, dan libur.</template></p></div>
    </div>
    <p v-if="galat" class="text-sm text-teks3">{{ galat }}</p>
    <div v-else-if="d" class="grid gap-4 lg:grid-cols-2">
      <div>
        <h4 class="mb-2 flex items-center gap-2 text-sm font-bold"><PhDoorOpen :size="18" weight="duotone" /> Gerbang ({{ d.gerbang.length }})</h4>
        <ul class="max-h-72 divide-y divide-garis overflow-y-auto rounded-xl border border-garis text-sm">
          <li v-for="g in d.gerbang" :key="g.id" class="px-3 py-2"><p class="flex items-center gap-1.5"><span class="lencana" :class="'w-' + JENIS_LOG[g.jenis].w">{{ JENIS_LOG[g.jenis].n }}</span>
            <span class="flex-1 text-xs text-teks2">{{ formatWaktu(g.waktu) }}</span></p>
            <p class="text-xs text-teks3">{{ [g.alasan_izin, g.penjemput && 'penjemput ' + g.penjemput, g.terlambat_menit && 'terlambat ' + durasi(g.terlambat_menit), g.catatan, g.petugas && 'petugas ' + g.petugas].filter(Boolean).join(' · ') }}</p></li>
          <li v-if="!d.gerbang.length" class="px-3 py-3 text-center text-xs text-teks3">Belum ada catatan gerbang.</li>
        </ul>
      </div>
      <div>
        <h4 class="mb-2 flex items-center gap-2 text-sm font-bold"><PhPackage :size="18" weight="duotone" /> Titipan ({{ d.titipan.length }})</h4>
        <ul class="max-h-72 divide-y divide-garis overflow-y-auto rounded-xl border border-garis text-sm">
          <li v-for="t in d.titipan" :key="t.id" class="px-3 py-2"><p class="flex flex-wrap items-center gap-1.5"><span class="flex-1 font-semibold">{{ JENIS_TITIPAN[t.jenis]?.n }}: {{ t.uraian }}{{ t.jenis === 'uang' ? ' (' + rupiah(t.nominal) + ')' : '' }}</span>
            <span class="lencana" :class="'w-' + STATUS_TITIPAN[t.status].w">{{ STATUS_TITIPAN[t.status].n }}</span></p>
            <p class="text-xs text-teks3">Dari {{ t.pengirim }} · diterima {{ formatPendek(t.diterima_pada) }}<template v-if="t.status === 'diambil'"> · diambil {{ t.pengambil_nama }} ({{ PENGAMBIL[t.pengambil_jenis] }}) {{ formatPendek(t.diambil_pada) }}</template></p></li>
          <li v-if="!d.titipan.length" class="px-3 py-3 text-center text-xs text-teks3">Belum ada titipan.</li>
        </ul>
      </div>
      <div>
        <h4 class="mb-2 flex items-center gap-2 text-sm font-bold"><PhUsersThree :size="18" weight="duotone" /> Kunjungan ({{ d.kunjungan.length }})</h4>
        <ul class="max-h-60 divide-y divide-garis overflow-y-auto rounded-xl border border-garis text-sm">
          <li v-for="k in d.kunjungan" :key="k.id" class="px-3 py-2"><p class="font-semibold">{{ k.pengunjung }}{{ k.hubungan ? ' (' + k.hubungan + ')' : '' }}</p>
            <p class="text-xs text-teks3">{{ formatWaktu(k.datang_pada) }}{{ k.pulang_pada ? ' s.d. ' + formatWaktu(k.pulang_pada).slice(-5) : ' · berlangsung' }}{{ k.luar_jadwal ? ' · di luar jadwal' : '' }}</p></li>
          <li v-if="!d.kunjungan.length" class="px-3 py-3 text-center text-xs text-teks3">Belum ada kunjungan tercatat.</li>
        </ul>
      </div>
      <div>
        <h4 class="mb-2 flex items-center gap-2 text-sm font-bold"><PhCalendarCheck :size="18" weight="duotone" /> Libur ({{ d.libur.length }})</h4>
        <ul class="max-h-60 divide-y divide-garis overflow-y-auto rounded-xl border border-garis text-sm">
          <li v-for="(l, i) in d.libur" :key="i" class="px-3 py-2"><p class="flex flex-wrap items-center gap-1.5"><span class="flex-1 font-semibold">{{ l.periode }}</span>
            <span class="lencana" :class="l.keputusan === 'boleh' ? 'w-presensi' : 'w-klinik'">{{ l.keputusan === 'boleh' ? 'Libur' : 'Tinggal' }}</span></p>
            <p class="text-xs text-teks3">{{ formatPendek(l.pulang_pada) }} s.d. {{ formatPendek(l.kembali_batas) }}{{ l.alasan_ubah ? ' · ' + l.alasan_ubah : '' }}{{ (l.rincian?.gagal || []).length ? ' · ' + l.rincian.gagal.join('; ') : '' }}</p></li>
          <li v-if="!d.libur.length" class="px-3 py-3 text-center text-xs text-teks3">Belum ada periode libur yang disahkan.</li>
        </ul>
      </div>
    </div>
  </section>
</template>
