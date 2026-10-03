<!-- SIMKA PRO | src/pages/presensi/TabUmum.vue | v1.0 | Fase 2 – Tahap 3 Pengaturan presensi | 03/10/2026 -->
<script setup>
// Pengaturan umum presensi (superadmin): tanggal mulai penutupan otomatis, jeda pulang,
// batas akurasi GPS, masa berlaku cek lokasi, masa simpan selfie, dan pengingat.
import { ref, computed } from 'vue'
import { PhFloppyDisk, PhInfo, PhPlay, PhPause } from '@phosphor-icons/vue'
import { useAturPresensi } from '@/stores/aturPresensi'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { formatPanjang, hariIniISO } from '@/lib/tanggal'
import InputTanggal from '@/components/InputTanggal.vue'

const atur = useAturPresensi(); const sesi = useSesi(); const ui = useUI()
const bolehUbah = computed(() => sesi.isSuperadmin)
const f = ref({ ...atur.pengaturan }); const proses = ref(false)
const aktif = ref(!!atur.pengaturan.mulai_tanggal)
const tglMulai = ref(atur.pengaturan.mulai_tanggal || hariIniISO())

const ANGKA = [
  { k: 'jeda_minimal_pulang_menit', n: 'Jeda minimal datang ke pulang', s: 'menit', min: 0, max: 240, ket: 'Mencegah ketukan ganda tercatat sebagai pulang.' },
  { k: 'batas_akurasi_m', n: 'Batas akurasi GPS', s: 'meter', min: 10, max: 1000, ket: 'Akurasi lebih buruk dari ini (atau terlalu sempurna) ditandai di panel kecurigaan.' },
  { k: 'berlaku_cek_detik', n: 'Masa berlaku cek lokasi', s: 'detik', min: 60, max: 600, ket: 'Waktu antara membaca lokasi dan mengirim selfie.' },
  { k: 'retensi_selfie_hari', n: 'Masa simpan selfie', s: 'hari', min: 30, max: 730, ket: 'Setelah itu foto dihapus dari Drive; data presensinya tetap permanen.' },
  { k: 'pengingat_menit', n: 'Pengingat sebelum jendela dibuka', s: 'menit', min: 0, max: 60, ket: 'Dipakai pada pengingat sesi (notifikasi aplikasi).' },
]
async function simpan() {
  for (const a of ANGKA) {
    const v = Number(f.value[a.k])
    if (!Number.isInteger(v) || v < a.min || v > a.max) return ui.toast(`${a.n} harus ${a.min}–${a.max} ${a.s}.`, 'galat')
  }
  if (!f.value.folder_selfie?.trim()) return ui.toast('Folder selfie wajib diisi.', 'galat')
  if (aktif.value && !tglMulai.value) return ui.toast('Isi tanggal mulai penutupan otomatis.', 'galat')
  if (aktif.value && !atur.pengaturan.mulai_tanggal && !(await ui.konfirmasi({
    judul: 'Aktifkan penutupan otomatis?',
    pesan: `Mulai ${formatPanjang(tglMulai.value)}, setiap sesi wajib yang terlewat tanpa presensi tercatat Tanpa keterangan, dan presensi pulang yang terlewat ditandai. Aktifkan setelah uji coba selesai dan semua pegawai siap.`,
    ya: 'Aktifkan' }))) return
  proses.value = true
  try {
    const nilai = { ...f.value, mulai_tanggal: aktif.value ? tglMulai.value : null }
    ANGKA.forEach((a) => { nilai[a.k] = Number(nilai[a.k]) })
    await atur.simpanPengaturan(nilai); f.value = { ...atur.pengaturan }; ui.toast('Pengaturan presensi tersimpan.')
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
</script>
<template>
  <div class="mx-auto max-w-3xl space-y-4">
    <p v-if="!bolehUbah" class="flex gap-2 rounded-xl bg-permukaan2 p-3 text-sm text-teks2"><PhInfo :size="18" class="mt-0.5 shrink-0" /> Pengaturan umum hanya dapat diubah superadmin.</p>

    <section class="kartu p-4 sm:p-5">
      <div class="flex items-start gap-3">
        <span :class="['chip-ikon h-11 w-11', aktif ? 'w-presensi' : 'w-laporan']"><component :is="aktif ? PhPlay : PhPause" :size="24" weight="duotone" /></span>
        <div class="flex-1">
          <h3 class="judul-bagian">Penutupan sesi otomatis</h3>
          <p class="text-sm text-teks3">Berjalan tiap 15 menit dan penyapuan akhir hari pukul 00.30 WITA.
            {{ atur.pengaturan.mulai_tanggal ? `Aktif sejak ${formatPanjang(atur.pengaturan.mulai_tanggal)}.` : 'Belum aktif (masa uji coba).' }}</p>
        </div>
      </div>
      <label class="mt-3 flex min-h-[44px] items-center gap-3 font-semibold"><input v-model="aktif" type="checkbox" :disabled="!bolehUbah" class="h-5 w-5 accent-[#C7332F]" /> Aktifkan penutupan otomatis</label>
      <div v-if="aktif" class="mt-2 max-w-xs"><InputTanggal v-model="tglMulai" label="Berlaku mulai tanggal" wajib /></div>
      <p class="mt-2 text-xs text-teks3">Selama belum aktif, sesi yang terlewat tidak dicatat sebagai tanpa keterangan. Aktifkan setelah uji coba selesai.</p>
    </section>

    <section class="kartu p-4 sm:p-5">
      <h3 class="judul-bagian mb-3">Aturan umum presensi</h3>
      <div class="grid gap-4 sm:grid-cols-2">
        <div v-for="a in ANGKA" :key="a.k">
          <label class="label-isian" :for="'pu-' + a.k">{{ a.n }}</label>
          <div class="relative"><input :id="'pu-' + a.k" v-model.number="f[a.k]" type="number" :min="a.min" :max="a.max" :disabled="!bolehUbah" inputmode="numeric" class="isian pr-16 tabular-nums" />
            <span class="pointer-events-none absolute right-3 top-1/2 -translate-y-1/2 text-sm text-teks3">{{ a.s }}</span></div>
          <p class="mt-1 text-xs text-teks3">{{ a.ket }}</p>
        </div>
        <div class="sm:col-span-2"><label class="label-isian" for="pu-folder">Folder selfie di Google Drive</label>
          <input id="pu-folder" v-model="f.folder_selfie" :disabled="!bolehUbah" class="isian" />
          <p class="mt-1 text-xs text-teks3">Selfie disimpan di subfolder tahun/bulan, contoh {{ f.folder_selfie }}/2026/10.</p></div>
      </div>
      <button v-if="bolehUbah" class="tombol-utama mt-4 w-full sm:w-auto" :disabled="proses" @click="simpan"><PhFloppyDisk :size="20" weight="duotone" /> {{ proses ? 'Menyimpan…' : 'Simpan pengaturan' }}</button>
    </section>
  </div>
</template>
