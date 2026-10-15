<!-- SIMKA PRO | src/pages/wali/AkunWali.vue | v1.0 | Fase 9 – Tahap 13.0.0 Fondasi Portal Wali | 15/10/2026 -->
<script setup>
// Akun Portal Wali: daftar anak di perangkat ini (pindah, tambah, keluar), tema, dan keterangan privasi.
import { PhCheckCircle, PhPlus, PhSignOut, PhShieldCheck, PhPaintBrush, PhStudent } from '@phosphor-icons/vue'
import { usePortalWali } from '@/stores/portalWali'
import { useUI } from '@/stores/ui'
import { HUBUNGAN_WALI } from '@/lib/portalWali'
import { formatPendek } from '@/lib/tanggal'
import { inisial } from '@/lib/santri'
import { VERSI_APLIKASI } from '@/lib/versi'
import PilihTema from '@/components/PilihTema.vue'

const emit = defineEmits(['tambah', 'pilih'])
const pw = usePortalWali(); const ui = useUI()

async function keluar(a) {
  if (!(await ui.konfirmasi({ judul: 'Keluar', pesan: `Keluar dari data ${a.nama} di perangkat ini? Untuk membukanya lagi, masuk kembali dengan NIS/NISN, tanggal lahir, dan 6 digit nomor HP.`, ya: 'Keluar', bahaya: true }))) return
  await pw.keluar(a.nis); ui.toast(`Data ${a.nama} sudah dikeluarkan dari perangkat ini.`, 'sukses')
}
async function keluarSemua() {
  if (!(await ui.konfirmasi({ judul: 'Keluar dari semua anak', pesan: 'Semua data anak di perangkat ini akan dikeluarkan.', ya: 'Keluar semua', bahaya: true }))) return
  await pw.keluarSemua()
}
</script>

<template>
  <div class="space-y-4">
    <section class="kartu w-santri p-4 sm:p-5">
      <div class="flex items-center gap-3">
        <span class="chip-ikon h-10 w-10"><PhStudent :size="22" weight="duotone" /></span>
        <div class="flex-1"><h2 class="judul-bagian">Anak di perangkat ini</h2><p class="text-sm text-teks3">Ketuk untuk berpindah anak.</p></div>
      </div>
      <ul class="mt-3 space-y-2">
        <li v-for="a in pw.anak" :key="a.nis" class="flex items-center gap-2 rounded-xl border border-garis p-2.5" :class="a.nis === pw.aktif?.nis && 'bg-permukaan2'">
          <button type="button" class="flex min-h-[44px] min-w-0 flex-1 items-center gap-3 text-left" @click="emit('pilih', a.nis)">
            <span class="grid h-11 w-11 shrink-0 place-items-center rounded-full bg-[#C7332F] text-sm font-bold text-white">{{ inisial(a.nama) }}</span>
            <span class="min-w-0"><span class="block truncate font-semibold">{{ a.nama }}</span>
              <span class="block truncate text-sm text-teks3">NIS {{ a.nis }}<template v-if="a.kelas"> · Kelas {{ a.kelas }}</template></span>
              <span class="block text-xs text-teks3"><template v-if="a.hubungan">Masuk sebagai {{ (HUBUNGAN_WALI[a.hubungan] || a.hubungan).toLowerCase() }} · </template>berlaku sampai {{ formatPendek(a.kedaluwarsa) }}</span></span>
            <PhCheckCircle v-if="a.nis === pw.aktif?.nis" :size="22" weight="fill" class="ml-auto shrink-0 text-[#15803D]" aria-label="Sedang dibuka" />
          </button>
          <button type="button" class="tombol-ikon h-11 w-11 shrink-0" :aria-label="'Keluar dari data ' + a.nama" @click="keluar(a)"><PhSignOut :size="22" /></button>
        </li>
      </ul>
      <div class="mt-3 flex flex-wrap gap-2">
        <button type="button" class="tombol-utama" @click="emit('tambah')"><PhPlus :size="20" weight="bold" /> Tambah anak</button>
        <button v-if="pw.anak.length > 1" type="button" class="tombol-garis" @click="keluarSemua"><PhSignOut :size="20" /> Keluar semua</button>
      </div>
    </section>

    <section class="kartu w-pengaturan p-4 sm:p-5">
      <div class="mb-3 flex items-center gap-3">
        <span class="chip-ikon h-10 w-10"><PhPaintBrush :size="22" weight="duotone" /></span>
        <h2 class="judul-bagian">Tampilan</h2>
      </div>
      <PilihTema />
    </section>

    <section class="kartu w-hakakses p-4 text-sm text-teks2 sm:p-5">
      <div class="mb-2 flex items-center gap-3">
        <span class="chip-ikon h-10 w-10"><PhShieldCheck :size="22" weight="duotone" /></span>
        <h2 class="judul-bagian">Privasi</h2>
      </div>
      <ul class="list-disc space-y-1 pl-5">
        <li>Portal hanya menampilkan data anak Bapak/Ibu sendiri. Informasi yang ditampilkan diatur oleh pondok.</li>
        <li>Masuk berlaku di perangkat ini sampai tanggal yang tertera, dan otomatis berakhir bila nomor HP atau data santri diubah pondok.</li>
        <li>Bila HP hilang atau dipakai orang lain, minta pengasuh atau Tata Usaha mencabut sesi Portal Wali.</li>
      </ul>
    </section>
    <p class="text-center text-xs text-teks3">SIMKA PRO versi {{ VERSI_APLIKASI }}</p>
  </div>
</template>
