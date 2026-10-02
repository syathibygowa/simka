<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import { PhIdentificationCard, PhBriefcase, PhPhone, PhCalendarBlank, PhBuildings, PhEye } from '@phosphor-icons/vue'
import { usePegawai } from '@/stores/pegawai'
import { formatPanjang, formatPendek } from '@/lib/tanggal'
import { ambilPenandaTangan } from '@/lib/penandatangan'
import { useSesi } from '@/stores/sesi'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'
import TombolCetak from '@/components/TombolCetak.vue'

const route = useRoute(); const peg = usePegawai(); const sesi = useSesi()
const pimpinan = ref({ jabatan: 'Direktur', nama: '', niy: '' })
const pratinjau = ref(false)
onMounted(async () => { if (!peg.daftar.length) await peg.muat(); pimpinan.value = await ambilPenandaTangan('Direktur') })
const p = computed(() => peg.cari(route.params.id))

const masaKerja = (tmt) => {
  if (!tmt) return '–'
  const a = new Date(tmt), b = new Date()
  let bln = (b.getFullYear() - a.getFullYear()) * 12 + b.getMonth() - a.getMonth(); if (b.getDate() < a.getDate()) bln--
  return `${Math.floor(bln / 12)} tahun ${bln % 12} bulan`
}
const STATUS_PEG = { tetap: 'Tetap', kontrak: 'Kontrak', honorer: 'Honorer' }
const STATUS_AKUN = { aktif: ['Akun aktif', 'presensi'], menunggu: ['Menunggu verifikasi', 'verifikasi'], tanpa_akun: ['Belum punya akun', 'tahfizh'], ditolak: ['Ditolak', 'klinik'], nonaktif: ['Nonaktif', 'hakakses'] }
const baris = computed(() => !p.value ? [] : [
  ['Nama lengkap', p.value.nama_lengkap], ['NIY', p.value.niy || '–'],
  ['Jenis kelamin', p.value.jenis_kelamin === 'P' ? 'Perempuan' : 'Laki-laki'],
  ['Tempat, tanggal lahir', p.value.ttl || '–'], ['Pendidikan terakhir', p.value.pendidikan_terakhir || '–'],
  ['Bidang/unit', p.value.nama_unit || '–'], ['Jabatan struktural', p.value.jabatan_struktural || '–'],
  ['Jabatan fungsional', (p.value.jabatan_fungsional || []).join(', ') || '–'],
  ['Status kepegawaian', STATUS_PEG[p.value.status_kepegawaian] || '–'],
  ['TMT tugas', p.value.tmt_tugas ? formatPanjang(p.value.tmt_tugas) : '–'], ['Masa kerja', p.value.masa_kerja?.teks || masaKerja(p.value.tmt_tugas)],
  ['Nomor HP', p.value.no_hp || '–'],
])
</script>
<template>
  <div v-if="p" class="mx-auto max-w-4xl">
    <div class="layar-saja">
      <section class="kartu w-pegawai overflow-hidden">
        <div class="kepala h-20 sm:h-24" />
        <div class="-mt-10 flex flex-wrap items-end gap-4 px-5 pb-5">
          <span :class="['grid h-20 w-20 place-items-center rounded-2xl border-4 border-permukaan text-2xl font-extrabold text-white', p.jenis_kelamin === 'P' ? 'bg-[#B42A5E]' : 'bg-[#2F5FA8]']">
            {{ p.nama_lengkap.replace(/^(Ust\.|Ustzh\.)\s*/, '').split(/\s+/).slice(0, 2).map((k) => k[0]).join('') }}
          </span>
          <div class="min-w-0 flex-1">
            <h2 class="text-xl font-extrabold leading-tight">{{ p.nama_lengkap }}</h2>
            <p class="text-sm text-teks3">NIY {{ p.niy || 'belum ada' }}</p>
          </div>
          <span :class="['lencana', 'w-' + STATUS_AKUN[p.status_akun][1]]">{{ STATUS_AKUN[p.status_akun][0] }}</span>
        </div>
        <div class="grid gap-3 border-t border-garis p-5 sm:grid-cols-2">
          <div class="w-pegawai flex items-center gap-3"><span class="chip-ikon h-10 w-10"><PhBriefcase :size="20" weight="duotone" /></span>
            <div><p class="text-xs text-teks3">Jabatan</p><p class="font-semibold">{{ [p.jabatan_struktural, ...(p.jabatan_fungsional || [])].filter(Boolean).join(', ') }}</p></div></div>
          <div class="w-santri flex items-center gap-3"><span class="chip-ikon h-10 w-10"><PhBuildings :size="20" weight="duotone" /></span>
            <div><p class="text-xs text-teks3">Bidang/unit</p><p class="font-semibold">{{ p.nama_unit }}</p></div></div>
          <div class="w-tahfizh flex items-center gap-3"><span class="chip-ikon h-10 w-10"><PhCalendarBlank :size="20" weight="duotone" /></span>
            <div><p class="text-xs text-teks3">TMT tugas</p><p class="font-semibold">{{ formatPendek(p.tmt_tugas) }} ({{ p.masa_kerja?.teks || masaKerja(p.tmt_tugas) }})</p></div></div>
          <div class="w-gaji flex items-center gap-3"><span class="chip-ikon h-10 w-10"><PhIdentificationCard :size="20" weight="duotone" /></span>
            <div><p class="text-xs text-teks3">Status kepegawaian</p><p class="font-semibold">{{ STATUS_PEG[p.status_kepegawaian] || '–' }}</p></div></div>
        </div>
      </section>
      <div class="mt-4 flex flex-wrap gap-2">
        <button class="tombol-garis" @click="pratinjau = !pratinjau"><PhEye :size="20" weight="duotone" /> {{ pratinjau ? 'Tutup pratinjau' : 'Pratinjau biodata' }}</button>
        <TombolCetak label="Cetak biodata" />
      </div>
    </div>

    <div :class="pratinjau && 'wadah-pratinjau mt-4 overflow-x-auto rounded-kartu bg-[#E9E3E0] p-4 dark:bg-[#0F0A0B] sm:p-8'">
      <DokumenCetak judul="Biodata Pegawai" :pratinjau="pratinjau" :pencetak="sesi.pengguna?.nama_lengkap">
        <table class="tabel">
          <colgroup><col style="width:7%"><col style="width:33%"><col style="width:60%"></colgroup>
          <thead><tr><th>No.</th><th>Data</th><th>Keterangan</th></tr></thead>
          <tbody><tr v-for="(b, i) in baris" :key="b[0]"><td class="tengah">{{ i + 1 }}</td><td>{{ b[0] }}</td><td>{{ b[1] }}</td></tr></tbody>
        </table>
        <template #ttd>
          <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: pimpinan.jabatan, nama: pimpinan.nama, niy: pimpinan.niy }"
            :kanan="{ jabatan: 'Pegawai yang bersangkutan', nama: p.nama_lengkap, niy: p.niy }" />
        </template>
      </DokumenCetak>
    </div>
  </div>
  <p v-else-if="!peg.memuat" class="py-16 text-center text-teks3">Data pegawai tidak ditemukan.</p>
</template>
<style scoped>
.kepala { background: var(--gradasi-utama); }
@media print { .wadah-pratinjau { background: none !important; padding: 0 !important; margin: 0 !important; } }
</style>
