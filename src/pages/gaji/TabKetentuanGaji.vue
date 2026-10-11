<!-- SIMKA PRO | src/pages/gaji/TabKetentuanGaji.vue | v1.2 | Fase 11 – Tahap 3 Sakelar utama potongan kehadiran | 11/10/2026 -->
<script setup>
// Ketentuan gaji. Pengelola gaji (superadmin, Bendahara, admin ber-izin kelola_gaji) mengubah; pembaca gaji hanya melihat.
//  • Slip di akun pegawai: bawaan NONAKTIF (arahan yayasan). Bila nonaktif, menu Gaji tidak tampil bagi pegawai;
//    pegawai yang memerlukan slip meminta kepada Bendahara (dicetak atau dibuka khusus untuknya, Tahap slip).
//  • Tanda tangan slip: Bendahara selalu; Direktur opsional.
//  • Pembulatan, sakelar potongan izin/sakit/cuti/terlambat, tanggal gajian, aturan honorer, info beban kerja, catatan kaki slip.
import { ref, computed, watch } from 'vue'
import { PhEyeSlash, PhEye, PhSignature, PhCalculator, PhScissors, PhCalendarBlank, PhUserCircleGear, PhClockCountdown, PhNotePencil, PhFloppyDisk, PhInfo } from '@phosphor-icons/vue'
import { useGaji } from '@/stores/gaji'
import { useUI } from '@/stores/ui'

const gaji = useGaji(); const ui = useUI()
const boleh = computed(() => !!gaji.hak.kelola)
const f = ref({}); const proses = ref(false)
watch(() => gaji.pengaturan, (v) => { f.value = { ...v } }, { immediate: true, deep: true })
const berubah = computed(() => JSON.stringify(f.value) !== JSON.stringify(gaji.pengaturan))

const SAKELAR = [
  { k: 'potong_izin', n: 'Izin yang disetujui memotong tunjangan fungsional' },
  { k: 'potong_sakit', n: 'Sakit yang disetujui memotong tunjangan fungsional' },
  { k: 'potong_cuti', n: 'Cuti yang disetujui memotong tunjangan fungsional' },
  { k: 'potong_terlambat', n: 'Terlambat dihitung sebagai sesi tidak terlaksana' },
]
async function alih(k) {
  if (!boleh.value) return
  f.value[k] = !f.value[k]
  if (k === 'slip_pegawai') await simpan(`Slip gaji ${f.value[k] ? 'ditampilkan di' : 'disembunyikan dari'} akun pegawai.`)
}
async function simpan(pesan = 'Ketentuan gaji tersimpan.') {
  proses.value = true
  try { await gaji.simpanPengaturan({ ...f.value, pembulatan: Number(f.value.pembulatan), tanggal_gajian: Number(f.value.tanggal_gajian) }); ui.toast(pesan) }
  catch (e) { ui.toast(e.message, 'galat'); f.value = { ...gaji.pengaturan } } finally { proses.value = false }
}
</script>
<template>
  <div class="grid gap-4 xl:grid-cols-2">
    <!-- Slip di akun pegawai -->
    <section :class="['kartu p-4 sm:p-5 xl:col-span-2', f.slip_pegawai ? 'w-presensi' : 'w-klinik']">
      <div class="flex flex-wrap items-start gap-3">
        <span class="chip-ikon h-11 w-11 shrink-0"><component :is="f.slip_pegawai ? PhEye : PhEyeSlash" :size="24" weight="duotone" /></span>
        <div class="min-w-[220px] flex-1">
          <h2 class="judul-bagian">Slip gaji di akun pegawai</h2>
          <p class="text-sm text-teks2">{{ f.slip_pegawai
            ? 'Aktif: setiap pegawai melihat dan mengunduh slip gajinya sendiri di menu Gaji.'
            : 'Nonaktif: menu Gaji tidak tampil bagi pegawai. Pegawai yang memerlukan slip meminta kepada Bendahara.' }}</p>
          <p class="mt-1 text-xs text-teks3">Bawaan nonaktif sesuai arahan yayasan. Bendahara dan superadmin tetap dapat menerbitkan dan mencetak slip.</p>
        </div>
        <button v-if="boleh" role="switch" :aria-checked="!!f.slip_pegawai" :disabled="proses" @click="alih('slip_pegawai')" aria-label="Tampilkan slip gaji di akun pegawai"
          :class="['relative h-8 w-14 shrink-0 rounded-full transition', f.slip_pegawai ? 'bg-[#1E7D4F]' : 'bg-garis']">
          <span :class="['absolute top-1 h-6 w-6 rounded-full bg-white shadow transition-all', f.slip_pegawai ? 'left-7' : 'left-1']" /></button>
        <span v-else class="lencana">{{ f.slip_pegawai ? 'Aktif' : 'Nonaktif' }}</span>
      </div>
    </section>

    <!-- Tanda tangan -->
    <section class="kartu w-verifikasi p-4 sm:p-5">
      <h3 class="judul-bagian mb-1 flex items-center gap-2"><PhSignature :size="20" weight="duotone" style="color: var(--c)" /> Tanda tangan slip</h3>
      <p class="mb-3 text-sm text-teks3">Bendahara selalu menandatangani slip secara elektronik dengan kode validasi.</p>
      <label class="flex min-h-[44px] items-center gap-3">
        <input type="checkbox" v-model="f.ttd_direktur" :disabled="!boleh" class="h-5 w-5 accent-[#C7332F]" />
        <span class="text-sm font-semibold">Slip juga ditandatangani Direktur ("Mengetahui", di sebelah kiri)</span></label>
    </section>

    <!-- Perhitungan -->
    <section class="kartu w-tahfizh p-4 sm:p-5">
      <h3 class="judul-bagian mb-3 flex items-center gap-2"><PhCalculator :size="20" weight="duotone" style="color: var(--c)" /> Perhitungan</h3>
      <div class="grid gap-3 sm:grid-cols-2">
        <div><label class="label-isian" for="kg-bulat">Pembulatan potongan</label>
          <select id="kg-bulat" v-model.number="f.pembulatan" :disabled="!boleh" class="isian">
            <option :value="1">Tanpa pembulatan</option><option :value="100">Ke Rp100</option><option :value="500">Ke Rp500</option><option :value="1000">Ke Rp1.000</option></select></div>
        <div><label class="label-isian" for="kg-tgl"><PhCalendarBlank :size="14" class="inline" /> Tanggal gajian</label>
          <select id="kg-tgl" v-model.number="f.tanggal_gajian" :disabled="!boleh" class="isian">
            <option v-for="n in 28" :key="n" :value="n">Tanggal {{ n }}</option></select></div>
      </div>
      <p class="mt-2 text-xs text-teks3">Periode gaji satu bulan kalender (tanggal 1 sampai akhir bulan); masa kerja dihitung pada tanggal akhir periode. Tanggal gajian tercetak di slip sebagai tanggal pembayaran.</p>
    </section>

    <!-- Potongan kehadiran -->
    <section class="kartu w-klinik p-4 sm:p-5">
      <h3 class="judul-bagian mb-1 flex items-center gap-2"><PhScissors :size="20" weight="duotone" style="color: var(--c)" /> Potongan berbasis kehadiran</h3>
      <p class="mb-2 text-sm text-teks3">Hanya tunjangan fungsional yang dapat dipotong: tunjangan × sesi tidak terlaksana tanpa keterangan ÷ sesi wajib.
        Tunjangan struktural dan kepegawaian tidak pernah dipotong.</p>
      <div class="mb-2 flex items-start gap-3 rounded-xl bg-permukaan2 p-3">
        <div class="flex-1"><p class="text-sm font-bold">Berlakukan potongan kehadiran</p>
          <p class="text-xs text-teks3">{{ f.potong_kehadiran ? 'Aktif: potongan masuk ke periode gaji yang dibuat atau dihitung ulang.' : 'Nonaktif: kehadiran per tugas hanya tampil sebagai perkiraan di rincian gaji. Aktifkan setelah data absensi dan jurnal terisi rutin.' }}</p></div>
        <button v-if="boleh" role="switch" :aria-checked="!!f.potong_kehadiran" @click="f.potong_kehadiran = !f.potong_kehadiran" aria-label="Berlakukan potongan kehadiran"
          :class="['relative h-8 w-14 shrink-0 rounded-full transition', f.potong_kehadiran ? 'bg-[#C7332F]' : 'bg-garis']">
          <span :class="['absolute top-1 h-6 w-6 rounded-full bg-white shadow transition-all', f.potong_kehadiran ? 'left-7' : 'left-1']" /></button>
      </div>
      <label v-for="s in SAKELAR" :key="s.k" class="flex min-h-[44px] items-center gap-3">
        <input type="checkbox" v-model="f[s.k]" :disabled="!boleh" class="h-5 w-5 accent-[#C7332F]" /><span class="text-sm font-semibold">{{ s.n }}</span></label>
    </section>

    <!-- Honorer dan beban kerja -->
    <section class="kartu w-pegawai p-4 sm:p-5">
      <h3 class="judul-bagian mb-1 flex items-center gap-2"><PhUserCircleGear :size="20" weight="duotone" style="color: var(--c)" /> Honorer dan beban kerja</h3>
      <p class="mb-2 text-sm text-teks3">Honorer dibayar per jam (jam mengajar dari jurnal mengajar, jam halaqah dari sesi yang terlaksana) tanpa tunjangan pendidikan, masa kerja, kepegawaian, dan kesehatan.</p>
      <label class="flex min-h-[44px] items-center gap-3">
        <input type="checkbox" v-model="f.honorer_tunjangan_jabatan" :disabled="!boleh" class="h-5 w-5 accent-[#C7332F]" />
        <span class="text-sm font-semibold">Honorer yang memegang jabatan menerima tunjangan jabatan struktural/fungsional</span></label>
      <label class="flex min-h-[44px] items-center gap-3">
        <input type="checkbox" v-model="f.info_beban_kerja" :disabled="!boleh" class="h-5 w-5 accent-[#C7332F]" />
        <span class="text-sm font-semibold"><PhClockCountdown :size="14" class="inline" /> Tampilkan kelebihan/kekurangan jam beban kerja di slip (informasi, tanpa nominal)</span></label>
    </section>

    <!-- Label penyesuaian -->
    <section class="kartu w-verifikasi p-4 sm:p-5 xl:col-span-2">
      <h3 class="judul-bagian mb-1">Nama baris penyesuaian di slip</h3>
      <p class="mb-2 text-sm text-teks3">Selisih antara skema dan gaji yang ditetapkan yayasan tampil di slip dengan nama ini (nilai bisa plus atau minus).</p>
      <input v-model="f.label_penyesuaian" :disabled="!boleh" maxlength="60" class="isian" placeholder="Penyesuaian ketetapan yayasan" />
    </section>

    <!-- Catatan kaki -->
    <section class="kartu w-pengumuman p-4 sm:p-5 xl:col-span-2">
      <h3 class="judul-bagian mb-2 flex items-center gap-2"><PhNotePencil :size="20" weight="duotone" style="color: var(--c)" /> Catatan kaki slip (tidak wajib)</h3>
      <textarea v-model="f.catatan_slip" :disabled="!boleh" maxlength="300" rows="2" class="isian py-2.5" placeholder="Contoh: Slip ini bersifat rahasia. Pertanyaan tentang gaji disampaikan kepada Bendahara." />
    </section>

    <div v-if="boleh" class="xl:col-span-2">
      <button class="tombol-utama w-full sm:w-auto" :disabled="proses || !berubah" @click="simpan()"><PhFloppyDisk :size="20" weight="duotone" /> {{ proses ? 'Menyimpan…' : 'Simpan ketentuan' }}</button>
    </div>
    <p v-else class="flex gap-2 text-sm text-teks3 xl:col-span-2"><PhInfo :size="18" class="mt-0.5 shrink-0" /> Ketentuan diubah oleh Bendahara atau superadmin.</p>
  </div>
</template>
