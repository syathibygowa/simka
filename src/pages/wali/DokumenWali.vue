<!-- SIMKA PRO | src/pages/wali/DokumenWali.vue | v1.0 | Fase 9 – Tahap 13.4.0 Dokumen santri di Portal Wali | 15/10/2026 -->
<script setup>
// Dokumen santri yang sudah sah: surat dari Persuratan (mis. Keterangan Aktif, SKBB, SKL) dan dokumen tahfizh (suket, sertifikat).
// Dokumen bertanda tangan ELEKTRONIK dapat dibuka lalu disimpan sebagai PDF (sama dengan dokumen resmi: salinan beku ber-QR).
// Dokumen bertanda tangan basah hanya tercantum; dokumen aslinya diambil di Tata Usaha pondok.
import { computed, ref, watch } from 'vue'
import { PhFileText, PhCertificate, PhDownloadSimple, PhSealCheck, PhInfo } from '@phosphor-icons/vue'
import { usePortalWali } from '@/stores/portalWali'
import { useUI } from '@/stores/ui'
import { formatPanjang } from '@/lib/tanggal'
import { namaBerkas, periodeBulan, subjekSurat } from '@/lib/namaBerkas'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import SuratResmi from '@/components/cetak/SuratResmi.vue'
import CetakDokumenTahfizh from '@/pages/tahfizh/CetakDokumenTahfizh.vue'

defineOptions({ inheritAttrs: false })
const pw = usePortalWali(); const ui = useUI()
const d = ref(null); const memuat = ref(false); const galat = ref('')
async function muat() {
  memuat.value = true; galat.value = ''
  try { d.value = await pw.ambil('dokumen') } catch (e) { galat.value = e.message } finally { memuat.value = false }
}
watch(() => pw.aktif?.nis, muat, { immediate: true })
const daftar = computed(() => d.value?.dokumen || [])

const membuka = ref(''); const surat = ref(null); const dokTahfizh = ref(null); const pratinjau = ref(false)
async function unduh(x) {
  membuka.value = x.id
  try {
    const h = await pw.ambil('dokumen_buka', { id: x.id, sumber: x.sumber })
    if (!h) return
    if (h.sumber === 'tahfizh') { surat.value = null; dokTahfizh.value = h.dok }
    else { dokTahfizh.value = null; surat.value = h.surat }
    pratinjau.value = true
  } catch (e) { ui.toast(e.message, 'galat') } finally { membuka.value = '' }
}
// Surat dicetak dari salinan beku (isi) seperti di Persuratan
const suratCetak = computed(() => (surat.value ? { ...(surat.value.isi || {}), nomor: surat.value.nomor, mode_ttd: surat.value.mode_ttd } : null))
const lembagaCetak = computed(() => surat.value?.isi?.lembaga || {})
const cek = (k) => `#/cek/${String(k || '').replace(/-/g, '')}`
</script>

<template>
  <div class="w-laporan space-y-3">
    <p class="px-1 text-sm text-teks3">Dokumen resmi ananda yang sudah sah. Ketuk <b>Unduh PDF</b>, lalu pilih <b>Simpan sebagai PDF</b> di jendela cetak.</p>
    <p v-if="galat" class="kartu p-4 text-sm font-semibold text-merah" role="alert">{{ galat }}</p>
    <div v-if="memuat && !d" class="kartu h-32 animate-pulse" aria-busy="true" />
    <p v-if="d?.nonaktif" class="kartu p-6 text-center text-teks3">Informasi ini tidak ditampilkan oleh pondok.</p>
    <p v-else-if="d && !daftar.length" class="kartu p-8 text-center text-teks3">Belum ada dokumen yang dapat ditampilkan. Permohonan surat (mis. Surat Keterangan Aktif) diajukan ke Tata Usaha pondok.</p>

    <article v-for="x in daftar" :key="x.sumber + x.id" class="kartu p-4">
      <div class="flex items-start gap-3">
        <span :class="['chip-ikon h-11 w-11', x.sumber === 'tahfizh' ? 'w-tahfizh' : 'w-laporan']"><component :is="x.sumber === 'tahfizh' ? PhCertificate : PhFileText" :size="24" weight="duotone" /></span>
        <div class="min-w-0 flex-1">
          <p class="font-bold leading-snug">{{ x.nama }}</p>
          <p class="text-sm text-teks2"><template v-if="x.nomor">Nomor {{ x.nomor }} · </template>{{ formatPanjang(x.tanggal) }}</p>
          <p v-if="x.perihal" class="text-sm text-teks3">{{ x.perihal }}</p>
        </div>
      </div>
      <div class="mt-3 flex flex-wrap items-center gap-2">
        <template v-if="x.unduh">
          <button type="button" class="tombol-utama min-h-[42px] text-sm" :disabled="membuka === x.id" @click="unduh(x)"><PhDownloadSimple :size="18" weight="bold" /> {{ membuka === x.id ? 'Membuka…' : 'Unduh PDF' }}</button>
          <a v-if="x.kode" :href="cek(x.kode)" class="tombol-garis min-h-[42px] text-sm"><PhSealCheck :size="18" weight="duotone" /> Cek keabsahan</a>
        </template>
        <p v-else class="flex items-start gap-1.5 text-sm text-teks2"><PhInfo :size="18" class="mt-0.5 shrink-0" /> Ditandatangani basah. Dokumen asli diambil di Tata Usaha pondok.</p>
      </div>
    </article>

    <DokumenCetak v-if="suratCetak" :key="surat.id" :kop="suratCetak.kop_kode || surat.kop_kode" :judul="`${surat.jenis_nama} ${surat.nomor || ''}`.trim()"
      :nama-berkas="namaBerkas(subjekSurat(suratCetak) || pw.aktif?.nama, surat.jenis_nama, surat.nomor, periodeBulan(surat.tanggal_surat))"
      v-model:pratinjau="pratinjau" sembunyikan-judul tanpa-catatan>
      <SuratResmi :surat="suratCetak" :lembaga="lembagaCetak" :ttd="surat.ttd || []" :kode="surat.kode || ''" :status-dokumen="surat.status || ''" mode="final" />
    </DokumenCetak>
    <CetakDokumenTahfizh v-if="dokTahfizh" :key="dokTahfizh.id" v-model:pratinjau="pratinjau" :dok="dokTahfizh" />
  </div>
</template>
