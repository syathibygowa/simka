<!-- SIMKA PRO | src/pages/persuratan/TabKetentuanSurat.vue | v1.3 | Fase 10 – Penutup: revisi surat dan inventaris semua surat | 11/10/2026 -->
<script setup>
// Ketentuan persuratan: alur surat masuk (dibaca semua), pilihan instruksi disposisi dan batas waktu bawaan (diubah pengelola).
import { ref, watch } from 'vue'
import { PhListChecks, PhPlus, PhTrash, PhFloppyDisk, PhArrowUp, PhFlowArrow, PhNumberSquareOne } from '@phosphor-icons/vue'
import { usePersuratan } from '@/stores/persuratan'
import { useUI } from '@/stores/ui'

const ps = usePersuratan(); const ui = useUI()
const instruksi = ref([]); const batas = ref(3); const baru = ref(''); const proses = ref(false)
watch(() => ps.pengaturan, (p) => { instruksi.value = [...(p.instruksi || [])]; batas.value = p.batas_bawaan_hari ?? 3 }, { immediate: true })
function tambah() { const t = baru.value.trim(); if (t.length < 3) return ui.toast('Tuliskan instruksi (minimal 3 huruf).', 'galat'); if (!instruksi.value.includes(t)) instruksi.value.push(t); baru.value = '' }
function naik(i) { if (i > 0) instruksi.value.splice(i - 1, 0, instruksi.value.splice(i, 1)[0]) }
async function simpan() {
  if (!instruksi.value.length) return ui.toast('Isi minimal satu pilihan instruksi.', 'galat')
  proses.value = true
  try { await ps.simpanPengaturan({ instruksi: instruksi.value, batas_bawaan_hari: Number(batas.value) || 0 }); ui.toast('Ketentuan persuratan tersimpan.') }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
const ALUR_KELUAR = [
  'Semua surat melalui Tata Usaha. Tata Usaha menyusun surat dari template (isian, penanda tangan, tembusan) dan dapat mencatat pemohonnya, yaitu pegawai atau pimpinan yang meminta surat. Naskah boleh disunting per surat.',
  'Kepala Bidang ke atas juga dapat menyusun draf, tetapi draf itu selalu dikirim ke Tata Usaha untuk diperiksa. Hanya Tata Usaha yang mengajukan tanda tangan: elektronik (pejabat menandatangani dari akunnya di Dokumen → Tanda tangan) atau basah.',
  'Nomor surat diambil otomatis saat surat sah (tanda tangan basah: saat diterbitkan), sesuai format di Setelan → Penomoran; Surat Keputusan memakai urutan sendiri.',
  'Surat sah memuat QR dan kode validasi yang dapat diperiksa di halaman Cek Keabsahan, lalu tercatat di buku agenda surat keluar. Pindaian surat bertanda tangan basah dapat diunggah sebagai arsip.',
  'Penanda tangan dapat menolak dengan alasan; surat kembali ke penyusun untuk diperbaiki dan diajukan ulang.',
  'Surat yang sudah terbit dapat direvisi Tata Usaha: draf revisi disalin dari surat lama (nomor lama dipakai, atau nomor baru bila dipilih) lalu ditandatangani ulang. Setelah revisi sah, surat lama berstatus Direvisi dan Cek Keabsahan menunjuk penggantinya.',
  'Buku agenda surat keluar menginventaris semua surat yang terbit di SIMKA PRO: surat Persuratan, surat pengajuan pegawai, surat keterangan sakit, surat keterangan pindah santri, dan laporan resmi bertanda tangan. Setiap baris dapat dibuka di tempat asalnya.',
]
const ALUR = [
  'Tata Usaha mencatat surat masuk: nomor agenda otomatis, data surat, sifat, dan pindaian (foto/PDF).',
  'Surat diteruskan ke pimpinan (bawaan Direktur; dapat dipilih Wakil Direktur, Yayasan, atau Kepala Bidang). Pimpinan mendapat notifikasi.',
  'Pimpinan memberi disposisi kepada pejabat/pegawai dengan instruksi, catatan, dan batas waktu, atau menutupnya bila cukup diketahui.',
  'Penerima disposisi boleh meneruskan ke stafnya, lalu menandai selesai dengan laporan tindak lanjut. Pemberi disposisi dikabari.',
  'Surat otomatis Selesai bila semua disposisi selesai. Batas waktu diingatkan pukul 07.00 WITA pada hari batas dan sehari sesudahnya bila belum selesai.',
  'Surat bersifat Rahasia hanya dibaca Tata Usaha, pimpinan penerima, dan penerima disposisinya; notifikasinya tidak memuat perihal.',
]
</script>
<template>
  <div class="grid gap-4 lg:grid-cols-2">
    <section class="kartu w-tatausaha p-4 sm:p-5">
      <h2 class="judul-bagian flex items-center gap-2"><span class="chip-ikon h-9 w-9"><PhFlowArrow :size="20" weight="duotone" /></span> Alur surat masuk</h2>
      <ol class="mt-3 space-y-2.5 text-sm">
        <li v-for="(a, i) in ALUR" :key="i" class="flex gap-3"><span class="grid h-6 w-6 shrink-0 place-items-center rounded-full bg-permukaan2 text-xs font-bold">{{ i + 1 }}</span><span class="text-teks2">{{ a }}</span></li>
      </ol>
      <p class="mt-3 flex items-center gap-2 text-xs text-teks3"><PhNumberSquareOne :size="16" /> Format nomor agenda diatur di Setelan → Penomoran (bawaan 001/SM/bulan Hijriah/tahun Hijriah).</p>
      <h2 class="judul-bagian mt-5 flex items-center gap-2"><span class="chip-ikon h-9 w-9"><PhFlowArrow :size="20" weight="duotone" /></span> Alur surat keluar</h2>
      <ol class="mt-3 space-y-2.5 text-sm">
        <li v-for="(a, i) in ALUR_KELUAR" :key="i" class="flex gap-3"><span class="grid h-6 w-6 shrink-0 place-items-center rounded-full bg-permukaan2 text-xs font-bold">{{ i + 1 }}</span><span class="text-teks2">{{ a }}</span></li>
      </ol>
    </section>
    <section class="kartu w-shift p-4 sm:p-5">
      <h2 class="judul-bagian flex items-center gap-2"><span class="chip-ikon h-9 w-9"><PhListChecks :size="20" weight="duotone" /></span> Pilihan instruksi disposisi</h2>
      <ul class="mt-3 divide-y divide-garis">
        <li v-for="(t, i) in instruksi" :key="t + i" class="flex min-h-[44px] items-center gap-2">
          <span class="flex-1 text-sm">{{ t }}</span>
          <template v-if="ps.hak.kelola">
            <button class="tombol-ikon h-9 w-9" :disabled="i === 0" :aria-label="`Naikkan ${t}`" @click="naik(i)"><PhArrowUp :size="18" /></button>
            <button class="tombol-ikon h-9 w-9 text-merah" :aria-label="`Hapus ${t}`" @click="instruksi.splice(i, 1)"><PhTrash :size="18" /></button>
          </template>
        </li>
      </ul>
      <template v-if="ps.hak.kelola">
        <div class="mt-3 flex gap-2"><input v-model="baru" class="isian" placeholder="Instruksi baru" aria-label="Instruksi baru" @keyup.enter="tambah" />
          <button class="tombol-garis shrink-0 px-3" @click="tambah"><PhPlus :size="18" /> Tambah</button></div>
        <div class="mt-3"><label class="label-isian" for="kt-batas">Batas waktu bawaan (hari sesudah disposisi)</label>
          <input id="kt-batas" v-model="batas" type="number" min="0" max="60" class="isian w-32" /></div>
        <button class="tombol-utama mt-4 w-full" :disabled="proses" @click="simpan"><PhFloppyDisk :size="20" weight="duotone" /> Simpan ketentuan</button>
      </template>
      <p v-else class="mt-3 text-xs text-teks3">Batas waktu bawaan: {{ batas }} hari. Hanya Tata Usaha atau pengelola persuratan yang dapat mengubah ketentuan.</p>
    </section>
  </div>
</template>
