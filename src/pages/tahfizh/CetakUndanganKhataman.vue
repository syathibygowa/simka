<!-- SIMKA PRO | src/pages/tahfizh/CetakUndanganKhataman.vue | v1.0 | 14.10.0: Surat Undangan Khataman Al-Qur'an untuk orang tua/wali | 18/10/2026 -->
<script setup>
// Surat Undangan Khataman Al-Qur'an 30 juz (F4, kop pondok) untuk diteruskan muhaffizh kepada orang tua/wali santri.
// Isi dari registri dokumen (nomor, jadwal, tempat beku saat disetujui/diubah). Tanda tangan elektronik Kepala Bidang Tahfizh (QR Cek Keabsahan).
import { computed } from 'vue'
import { formatHari, formatJam, formatPanjang, formatPendek, formatHijriah } from '@/lib/tanggal'
import { svgQR, alamatCek } from '@/lib/dokumen'
import { HUBUNGAN } from '@/lib/santri'
import { useLembaga } from '@/stores/lembaga'
import { namaBerkas } from '@/lib/namaBerkas'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import CatatanValidasi from '@/components/cetak/CatatanValidasi.vue'

const pratinjau = defineModel('pratinjau', { type: Boolean, default: false })
const props = defineProps({ k: { type: Object, required: true } })
const lembaga = useLembaga(); lembaga.muat().catch(() => {})
const u = computed(() => props.k.undangan || {})
const isi = computed(() => u.value.isi || { jadwal: props.k.jadwal, tempat: props.k.tempat, nama: props.k.nama, kelas: props.k.kelas, halaqah: props.k.halaqah })
const t = computed(() => (u.value.ttd || [])[0] || {})
const sah = computed(() => t.value.status === 'ditandatangani' && u.value.kode)
const kota = computed(() => lembaga.identitas?.kota_surat || 'Gowa')
const wali = computed(() => (props.k.wali?.nama ? `${props.k.wali.nama.replace(/^(bapak|ibu|bpk\.?|ibu\.?)\s+/i, '')}${props.k.wali.hubungan ? ` (${HUBUNGAN[props.k.wali.hubungan] || props.k.wali.hubungan})` : ''}` : 'Orang Tua/Wali Santri'))
const qr = computed(() => (sah.value ? svgQR(alamatCek(u.value.kode)) : ''))
</script>
<template>
  <DokumenCetak kop="pondok" judul="Surat Undangan Khataman" :nomor="u.nomor" sembunyikan-judul tanpa-catatan v-model:pratinjau="pratinjau"
    :nama-berkas="namaBerkas(k.nama, 'Undangan Khataman', u.nomor)">
    <div class="undangan">
      <table class="kepala-surat"><tbody>
        <tr><td style="width: 22mm">Nomor</td><td style="width: 4mm">:</td><td>{{ u.nomor || '…' }}</td>
          <td class="kanan" rowspan="3">{{ kota }}, {{ formatHijriah(k.diputus_pada || new Date()) }}<br>{{ formatPanjang(k.diputus_pada || new Date()) }}</td></tr>
        <tr><td>Lampiran</td><td>:</td><td>–</td></tr>
        <tr><td>Hal</td><td>:</td><td><b>Undangan Khataman Al-Qur'an 30 Juz</b></td></tr>
      </tbody></table>
      <p style="margin-top: 8pt">Kepada Yth.<br><b>Bapak/Ibu {{ wali }}</b><br>Orang tua/wali ananda {{ isi.nama }}<br>di Tempat</p>
      <p style="margin-top: 8pt"><i>Assalamu'alaikum warahmatullahi wabarakatuh,</i></p>
      <p class="rata">Segala puji bagi Allah <i>Subhanahu wa Ta'ala</i> yang telah memberikan taufik kepada ananda <b>{{ isi.nama }}</b>
        ({{ isi.kelas ? 'kelas ' + isi.kelas : 'santri' }}{{ isi.halaqah ? ', ' + isi.halaqah : '' }}) sehingga dapat menuntaskan hafalan Al-Qur'an 30 juz.
        Sebagai bentuk syukur, kami mengundang Bapak/Ibu untuk hadir pada <b>Khataman Al-Qur'an</b> ananda yang insya Allah dilaksanakan pada:</p>
      <table class="rincian"><tbody>
        <tr><td style="width: 34mm">Hari/tanggal</td><td style="width: 4mm">:</td><td>{{ isi.jadwal ? formatHari(isi.jadwal) : '–' }}</td></tr>
        <tr><td>Waktu</td><td>:</td><td>{{ isi.jadwal ? formatJam(isi.jadwal) + ' WITA – selesai' : '–' }}</td></tr>
        <tr><td>Tempat</td><td>:</td><td>{{ isi.tempat || '–' }}</td></tr>
        <tr><td>Acara</td><td>:</td><td>Khataman Al-Qur'an 30 juz dan penyerahan Sertifikat Penghargaan</td></tr>
      </tbody></table>
      <p class="rata">Kehadiran dan doa Bapak/Ibu merupakan kebahagiaan dan penyemangat bagi ananda. Atas perhatian dan kehadirannya kami ucapkan
        <i>jazakumullahu khairan</i>.</p>
      <p style="margin-top: 6pt"><i>Wassalamu'alaikum warahmatullahi wabarakatuh.</i></p>
    </div>
    <template #ttd>
      <div class="ttd-kanan">
        <p>{{ t.jabatan || 'Kepala Bidang Tahfizh' }},</p>
        <div class="ruang">
          <div v-if="qr" class="qr-el"><span class="qr" v-html="qr" /><span class="ket">Ditandatangani secara elektronik<br>{{ t.waktu ? `${formatPendek(t.waktu)} ${formatJam(t.waktu)} WITA` : '' }}</span></div>
        </div>
        <p class="nm">{{ t.nama || '' }}</p>
        <p v-if="t.niy">NIY. {{ t.niy }}</p>
      </div>
      <CatatanValidasi :kode="u.kode" :draf="u.status === 'draf'" :status="u.status === 'dicabut' ? 'dicabut' : u.status" />
    </template>
  </DokumenCetak>
</template>
<style scoped>
.undangan { font-size: 11.5pt; line-height: 1.45; }
.kepala-surat { width: 100%; border-collapse: collapse; }
.kepala-surat td { padding: 0 2pt 0 0; vertical-align: top; }
.kepala-surat .kanan { text-align: right; white-space: nowrap; }
.rata { text-align: justify; margin-top: 6pt; }
.rincian { margin: 6pt 0 6pt 12mm; border-collapse: collapse; }
.rincian td { padding: 1pt 2pt 1pt 0; vertical-align: top; }
.ttd-kanan { margin: 12pt 0 0 auto; width: 78mm; font-size: 11.5pt; line-height: 1.35; }
.ruang { height: 22mm; display: flex; align-items: center; }
.nm { font-weight: 700; text-decoration: underline; }
.qr-el { display: flex; align-items: center; gap: 3mm; }
.qr-el .qr { display: block; width: 19mm; height: 19mm; }
.qr-el .qr :deep(svg) { width: 100%; height: 100%; display: block; }
.qr-el .ket { font-size: 8pt; line-height: 1.25; font-style: italic; }
</style>
