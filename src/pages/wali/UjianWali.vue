<!-- SIMKA PRO | src/pages/wali/UjianWali.vue | v1.0 | Fase 9 – Tahap 13.2.0 Ujian tahfizh, UTAS, prestasi, keuangan di Portal Wali | 15/10/2026 -->
<script setup>
// Tiga bagian Portal Wali tanpa pilihan periode (prop bagian):
//   ujian    : ujian kenaikan juz dan sertifikasi yang sudah dinilai + UTAS yang sudah final
//   prestasi : prestasi santri yang tercatat
//   keuangan : ringkasan tagihan dan tunggakan, daftar tagihan, pembayaran 12 bulan (hanya bila dinyalakan superadmin)
import { computed, ref, watch } from 'vue'
import { PhExam, PhMedal, PhTrophy, PhWallet, PhReceipt, PhBank, PhWarningCircle } from '@phosphor-icons/vue'
import { usePortalWali } from '@/stores/portalWali'
import { JENIS_PENGUJI, HASIL_UJIAN } from '@/lib/tahfizh'
import { BIDANG_PRESTASI, TINGKAT_PRESTASI } from '@/lib/prestasi'
import { STATUS_TAGIHAN, CARA_BAYAR, rupiah } from '@/lib/keuangan'
import { formatPanjang, formatPendek } from '@/lib/tanggal'

defineOptions({ inheritAttrs: false })
const props = defineProps({ bagian: { type: String, required: true } })
const pw = usePortalWali()
const d = ref(null); const memuat = ref(false); const galat = ref('')
async function muat() {
  memuat.value = true; galat.value = ''
  try { d.value = await pw.ambil(props.bagian) } catch (e) { galat.value = e.message } finally { memuat.value = false }
}
watch([() => pw.aktif?.nis, () => props.bagian], muat, { immediate: true })

const juzTeks = (j) => (Array.isArray(j) && j.length ? 'Juz ' + j.join(', ') : '')
const angka = (n) => (n == null ? '–' : Number(n).toLocaleString('id-ID', { maximumFractionDigits: 2 }))
const r = computed(() => d.value?.ringkas || {})
</script>

<template>
  <div class="space-y-4">
    <p v-if="galat" class="kartu p-4 text-sm font-semibold text-merah" role="alert">{{ galat }}</p>
    <div v-if="memuat && !d" class="kartu h-32 animate-pulse" aria-busy="true" />
    <p v-if="d?.nonaktif" class="kartu p-6 text-center text-teks3">Informasi ini tidak ditampilkan oleh pondok.</p>

    <!-- UJIAN -->
    <template v-if="bagian === 'ujian' && d && !d.nonaktif">
      <p v-if="!d.ujian?.length && !d.utas?.length" class="kartu p-8 text-center text-teks3">Belum ada hasil ujian tahfizh.</p>
      <section v-if="d.utas?.length" class="space-y-2">
        <h2 class="judul-bagian px-1">Ujian Tahfizh Akhir Semester (UTAS)</h2>
        <article v-for="(u, i) in d.utas" :key="'u' + i" class="kartu w-rapor p-4">
          <div class="flex items-start gap-3">
            <span class="chip-ikon h-10 w-10"><PhMedal :size="22" weight="duotone" /></span>
            <div class="min-w-0 flex-1">
              <p class="font-semibold">{{ u.ta }} · Semester {{ u.semester }}</p>
              <p class="text-sm text-teks2">{{ juzTeks(u.juz) }}<template v-if="u.diuji_pada"> · {{ formatPanjang(u.diuji_pada) }}</template></p>
              <p class="text-xs text-teks3">Tajwid {{ angka(u.tajwid) }} · Itqan {{ angka(u.itqan) }}</p>
            </div>
            <p class="shrink-0 text-right"><span class="block text-2xl font-extrabold tabular-nums">{{ angka(u.nilai_akhir) }}</span>
              <span class="text-xs font-semibold">{{ u.predikat || u.huruf }}</span></p>
          </div>
        </article>
      </section>
      <section v-if="d.ujian?.length" class="space-y-2">
        <h2 class="judul-bagian px-1">Ujian kenaikan juz dan sertifikasi</h2>
        <article v-for="(x, i) in d.ujian" :key="'x' + i" class="kartu w-tahfizh p-4">
          <div class="flex items-start gap-3">
            <span class="chip-ikon h-10 w-10"><PhExam :size="22" weight="duotone" /></span>
            <div class="min-w-0 flex-1">
              <p class="font-semibold">{{ JENIS_PENGUJI[x.jenis] || x.jenis }}<template v-if="x.jenis === 'sertifikasi' && x.jenjang"> {{ x.jenjang }} juz</template></p>
              <p class="text-sm text-teks2">{{ juzTeks(x.juz) }}<template v-if="x.diuji_pada"> · {{ formatPanjang(x.diuji_pada) }}</template><template v-if="x.ujian_ke > 1"> · ujian ke-{{ x.ujian_ke }}</template></p>
              <p class="text-xs text-teks3">Tajwid {{ angka(x.tajwid) }} · Itqan {{ angka(x.itqan) }}<template v-if="x.penguji"> · Penguji {{ x.penguji }}</template></p>
              <p v-if="x.catatan" class="mt-1 text-sm text-teks2">{{ x.catatan }}</p>
            </div>
            <div class="shrink-0 text-right">
              <p class="text-2xl font-extrabold tabular-nums">{{ angka(x.nilai_akhir) }}</p>
              <span :class="['lencana', 'w-' + (HASIL_UJIAN[x.hasil]?.w || 'presensi')]">{{ HASIL_UJIAN[x.hasil]?.n || x.hasil }}</span>
            </div>
          </div>
        </article>
      </section>
    </template>

    <!-- PRESTASI -->
    <template v-if="bagian === 'prestasi' && d && !d.nonaktif">
      <p v-if="!d.prestasi?.length" class="kartu p-8 text-center text-teks3">Belum ada prestasi yang dicatat.</p>
      <article v-for="(p, i) in d.prestasi" :key="i" :class="['kartu flex gap-3 p-4', 'w-' + (BIDANG_PRESTASI[p.bidang]?.w || 'prestasi')]">
        <span class="chip-ikon h-11 w-11"><PhTrophy :size="24" weight="duotone" /></span>
        <div class="min-w-0 flex-1">
          <p class="font-bold">{{ p.capaian }}</p>
          <p class="text-sm text-teks2">{{ p.nama_kegiatan }}<template v-if="p.penyelenggara"> · {{ p.penyelenggara }}</template></p>
          <p class="mt-1 flex flex-wrap gap-1.5 text-xs">
            <span class="lencana">{{ BIDANG_PRESTASI[p.bidang]?.n || p.bidang }}</span>
            <span v-if="p.tingkat" class="lencana w-hakakses">Tingkat {{ TINGKAT_PRESTASI[p.tingkat] || p.tingkat }}</span>
            <span class="text-teks3">{{ formatPanjang(p.tanggal) }}</span>
          </p>
          <p v-if="p.keterangan" class="mt-1 text-sm text-teks3">{{ p.keterangan }}</p>
        </div>
      </article>
    </template>

    <!-- KEUANGAN -->
    <template v-if="bagian === 'keuangan' && d && !d.nonaktif">
      <section class="grid grid-cols-2 gap-3">
        <div class="kartu w-klinik p-3.5"><p class="text-xs text-teks3">Belum dibayar</p><p class="text-xl font-extrabold tabular-nums">{{ rupiah(r.sisa) }}</p>
          <p class="text-xs text-teks3">dari tagihan berjalan</p></div>
        <div :class="['kartu p-3.5', r.tunggakan > 0 ? 'w-pengajuan' : 'w-presensi']"><p class="text-xs text-teks3">Lewat jatuh tempo</p>
          <p class="text-xl font-extrabold tabular-nums">{{ rupiah(r.tunggakan) }}</p><p class="text-xs text-teks3">{{ r.jumlah_tunggak || 0 }} tagihan</p></div>
      </section>
      <section v-if="d.rekening?.length" class="kartu w-gaji p-4">
        <div class="flex items-center gap-3"><span class="chip-ikon h-10 w-10"><PhBank :size="22" weight="duotone" /></span><h2 class="judul-bagian">Rekening pondok</h2></div>
        <ul class="mt-2 space-y-1 text-sm"><li v-for="(k, i) in d.rekening" :key="i"><b>{{ k.bank }}</b> {{ k.nomor }} a.n. {{ k.atas_nama }}</li></ul>
        <p class="mt-2 text-xs text-teks3">Setelah transfer, kirim bukti kepada Bendahara pondok agar pembayaran dicatat.</p>
      </section>
      <section class="kartu w-keuangan p-4 sm:p-5">
        <div class="flex items-center gap-3"><span class="chip-ikon h-10 w-10"><PhWallet :size="22" weight="duotone" /></span><h2 class="judul-bagian">Tagihan</h2></div>
        <p v-if="!d.tagihan?.length" class="py-4 text-center text-sm text-teks3">Tidak ada tagihan.</p>
        <ul v-else class="mt-2 divide-y divide-garis/70">
          <li v-for="(b, i) in d.tagihan" :key="i" class="flex items-center gap-3 py-2.5">
            <div class="min-w-0 flex-1">
              <p class="font-semibold">{{ b.nama }}</p>
              <p class="text-xs text-teks3">Jatuh tempo {{ formatPendek(b.jatuh_tempo) }}<template v-if="b.potongan > 0"> · subsidi {{ rupiah(b.potongan) }}</template>
                <template v-if="b.dibayar > 0 && b.status !== 'lunas'"> · dibayar {{ rupiah(b.dibayar) }}</template></p>
              <p v-if="b.lewat" class="flex items-center gap-1 text-xs font-semibold text-merah"><PhWarningCircle :size="14" weight="fill" /> Lewat jatuh tempo</p>
            </div>
            <div class="shrink-0 text-right"><p class="font-bold tabular-nums">{{ rupiah(b.nominal) }}</p>
              <span :class="['lencana', 'w-' + (STATUS_TAGIHAN[b.status]?.w || 'hakakses')]">{{ STATUS_TAGIHAN[b.status]?.n || b.status }}</span></div>
          </li>
        </ul>
      </section>
      <section class="kartu w-presensi p-4 sm:p-5">
        <div class="flex items-center gap-3"><span class="chip-ikon h-10 w-10"><PhReceipt :size="22" weight="duotone" /></span>
          <div><h2 class="judul-bagian">Pembayaran</h2><p class="text-sm text-teks3">12 bulan terakhir</p></div></div>
        <p v-if="!d.pembayaran?.length" class="py-4 text-center text-sm text-teks3">Belum ada pembayaran tercatat.</p>
        <ul v-else class="mt-2 divide-y divide-garis/70">
          <li v-for="(y, i) in d.pembayaran" :key="i" class="flex items-center gap-3 py-2.5">
            <div class="min-w-0 flex-1"><p class="font-semibold">{{ formatPanjang(y.tanggal) }}</p>
              <p class="text-xs text-teks3">{{ CARA_BAYAR[y.cara] || y.cara }}<template v-if="y.nomor"> · kuitansi {{ y.nomor }}</template><template v-if="y.riwayat"> · catatan pembayaran lama</template></p></div>
            <p class="shrink-0 font-bold tabular-nums">{{ rupiah(y.jumlah) }}</p>
          </li>
        </ul>
      </section>
    </template>
  </div>
</template>
