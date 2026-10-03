<!-- SIMKA PRO | src/pages/presensi/TabPola.vue | v1.0 | Fase 2 – Tahap 3 Pengaturan presensi | 03/10/2026 -->
<script setup>
// Pola sesi per tugas (Bagian 9): setiap jabatan fungsional membawa pola bawaan;
// setiap sesi memiliki jam, hari, jendela buka, toleransi, dan batas yang dapat diubah.
import { ref, computed } from 'vue'
import { PhPlus, PhPencilSimple, PhClock, PhEye, PhIdentificationBadge, PhCaretDown, PhUsers, PhInfo } from '@phosphor-icons/vue'
import { useAturPresensi } from '@/stores/aturPresensi'
import { useOrganisasi } from '@/stores/organisasi'
import { useLembaga } from '@/stores/lembaga'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { JENIS_POLA, teksHari, jamTitik, keMenit, durasi, ringkasJendela, jendela } from '@/lib/presensi'
import { formatPanjang } from '@/lib/tanggal'
import FormPola from './FormPola.vue'
import FormSesi from './FormSesi.vue'
import TombolAksi from '@/components/TombolAksi.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'

const atur = useAturPresensi(); const org = useOrganisasi(); const lembaga = useLembaga(); const sesi = useSesi(); const ui = useUI()
const bolehUbah = computed(() => atur.boleh('atur_presensi'))
const lembarPola = ref(false); const polaDipilih = ref(null)
const lembarSesi = ref(false); const sesiDipilih = ref(null); const polaUntukSesi = ref(null)
const jabatanTerbuka = ref(false); const pratinjau = ref(false)

const namaKalender = (k) => lembaga.holiday_calendars.find((x) => x.jenis_tugas === k)?.nama || 'Tanpa kalender'
// Hari sesi dikurangi libur pekanan kalender polanya (contoh: setiap hari − Ahad = Senin–Sabtu)
const hariEfektif = (s, p) => { const libur = lembaga.holiday_calendars.find((k) => k.jenis_tugas === p.kalender)?.hari_libur || []; return teksHari(s.hari.filter((h) => !libur.includes(h))) }
const jabatanPola = (id) => org.fungsional.filter((f) => f.pola_id === id).map((f) => f.nama)
const rentangJam = (s) => `${jamTitik(keMenit(s.jam_mulai))}–${jamTitik(keMenit(s.jam_mulai) + durasi(s))}`
function ubahPola(p) { polaDipilih.value = p; lembarPola.value = true }
function tambahSesi(p) { sesiDipilih.value = null; polaUntukSesi.value = p.id; lembarSesi.value = true }
function ubahSesi(s) { sesiDipilih.value = s; polaUntukSesi.value = s.pattern_id; lembarSesi.value = true }
async function aturJabatan(f, e) {
  const nilai = e.target.value || null
  try { await atur.aturPolaJabatan(f.id, nilai); ui.toast(`Pola ${f.nama} diperbarui. Jadwal pegawai yang memegang jabatan ini ikut disesuaikan.`) }
  catch (er) { ui.toast(er.message, 'galat'); e.target.value = f.pola_id || '' }
}
const direktur = computed(() => lembaga.signatories.find((s) => /^direktur$/i.test(s.jabatan_tertulis)) || lembaga.signatories[0] || {})
const barisCetak = computed(() => atur.polaUmum.flatMap((p) => atur.sesiPola(p.id).filter((s) => s.aktif).map((s) => ({ p, s, j: jendela(s) }))))
</script>
<template>
  <div class="space-y-4">
    <div class="layar-saja flex flex-wrap items-center gap-2">
      <p class="flex flex-1 gap-2 text-sm text-teks3"><PhInfo :size="18" class="mt-0.5 shrink-0" />
        Jadwal harian pegawai = gabungan sesi semua pola tugasnya. Semua jam dan toleransi dapat diubah kapan saja; perubahan berlaku untuk presensi berikutnya.</p>
      <button class="tombol-garis" @click="pratinjau = true"><PhEye :size="20" weight="duotone" /> Pratinjau cetak</button>
      <button v-if="bolehUbah" class="tombol-utama hidden lg:inline-flex" @click="ubahPola(null)"><PhPlus :size="20" weight="bold" /> Tambah pola</button>
    </div>
    <p v-if="!bolehUbah" class="flex gap-2 rounded-xl bg-permukaan2 p-3 text-sm text-teks2"><PhInfo :size="18" class="mt-0.5 shrink-0" /> Anda dapat melihat pola, tetapi mengubahnya memerlukan izin "Mengatur pola sesi, jadwal pegawai, dan shift presensi" dari superadmin.</p>

    <!-- Jabatan fungsional → pola bawaan -->
    <section class="kartu w-pegawai">
      <button class="flex w-full items-center gap-3 p-4 text-left" @click="jabatanTerbuka = !jabatanTerbuka" :aria-expanded="jabatanTerbuka">
        <span class="chip-ikon h-10 w-10"><PhIdentificationBadge :size="22" weight="duotone" /></span>
        <span class="flex-1"><span class="judul-bagian block">Pola bawaan per jabatan fungsional</span>
          <span class="text-sm text-teks3">Pegawai otomatis mendapat pola dari jabatannya; dapat disesuaikan per orang di tab Jadwal pegawai.</span></span>
        <PhCaretDown :size="20" :class="['transition', jabatanTerbuka && 'rotate-180']" />
      </button>
      <ul v-if="jabatanTerbuka" class="divide-y divide-garis border-t border-garis px-4">
        <li v-for="f in org.fungsional.filter((x) => x.aktif)" :key="f.id" class="flex flex-wrap items-center gap-2 py-2">
          <span class="min-w-[12rem] flex-1 font-semibold">{{ f.nama }}</span>
          <select class="isian w-full sm:w-64" :value="f.pola_id || ''" :disabled="!bolehUbah" @change="aturJabatan(f, $event)" :aria-label="`Pola bawaan ${f.nama}`">
            <option value="">Tanpa pola sendiri</option>
            <option v-for="p in atur.polaUmum" :key="p.id" :value="p.id">{{ p.nama }}</option>
          </select>
        </li>
      </ul>
    </section>

    <!-- Daftar pola dan sesinya -->
    <div class="grid gap-4 xl:grid-cols-2">
      <section v-for="p in atur.polaUmum" :key="p.id" :class="['kartu p-4 sm:p-5', 'w-' + p.warna, !p.aktif && 'opacity-70']">
        <div class="flex items-start gap-3">
          <span class="chip-ikon h-11 w-11"><PhClock :size="24" weight="duotone" /></span>
          <div class="min-w-0 flex-1">
            <h3 class="judul-bagian">{{ p.nama }} <span v-if="!p.aktif" class="lencana w-hakakses ml-1">Nonaktif</span></h3>
            <p class="text-sm text-teks3">{{ JENIS_POLA[p.jenis]?.n }} · {{ namaKalender(p.kalender) }}</p>
            <p class="mt-0.5 flex flex-wrap items-center gap-1 text-xs text-teks3"><PhUsers :size="14" /> {{ atur.pemakaiPola(p.id) }} pegawai
              <span v-if="p.pola_struktural" class="lencana">Pimpinan tanpa tugas terjadwal</span></p>
            <p v-if="jabatanPola(p.id).length" class="text-xs text-teks3">Jabatan: {{ jabatanPola(p.id).join(', ') }}</p>
          </div>
          <button v-if="bolehUbah" class="tombol-ikon" @click="ubahPola(p)" :aria-label="`Ubah pola ${p.nama}`"><PhPencilSimple :size="20" /></button>
        </div>
        <ul class="mt-3 space-y-2">
          <li v-for="s in atur.sesiPola(p.id)" :key="s.id">
            <button class="w-full rounded-xl border border-garis p-3 text-left hover:bg-permukaan2 disabled:cursor-default disabled:hover:bg-transparent" :disabled="!bolehUbah" @click="ubahSesi(s)">
              <div class="flex flex-wrap items-center gap-x-2 gap-y-1">
                <span class="font-semibold">{{ s.nama }}</span>
                <span class="lencana tabular-nums">{{ rentangJam(s) }}</span>
                <span v-if="s.opsional" class="lencana w-tahfizh">Opsional</span>
                <span v-if="!s.aktif" class="lencana w-hakakses">Nonaktif</span>
              </div>
              <p class="mt-0.5 text-xs text-teks3">{{ p.jenis === 'shift' ? 'Sesuai jadwal shift' : hariEfektif(s, p) }} · {{ ringkasJendela(s) }}</p>
            </button>
          </li>
          <li v-if="!atur.sesiPola(p.id).length" class="rounded-xl border border-dashed border-garis p-3 text-sm text-teks3">
            Belum ada sesi. {{ p.kode === 'EKSKUL' ? 'Tambahkan sesi sesuai jadwal pertemuan ekskul.' : 'Pegawai dengan pola ini belum memiliki kewajiban presensi.' }}</li>
        </ul>
        <button v-if="bolehUbah" class="tombol-teks mt-2" @click="tambahSesi(p)"><PhPlus :size="18" weight="bold" /> Tambah sesi</button>
      </section>
    </div>

    <TombolAksi v-if="bolehUbah" label="Tambah pola" :ikon="PhPlus" warna="tahfizh" @klik="ubahPola(null)" />
    <FormPola v-model="lembarPola" :pola="polaDipilih" />
    <FormSesi v-model="lembarSesi" :sesi="sesiDipilih" :pola-id="polaUntukSesi" />

    <!-- Dokumen cetak: pola sesi presensi -->
    <DokumenCetak v-model:pratinjau="pratinjau" mendatar judul="Pola Sesi Presensi Pegawai" :subjudul="`Berlaku per ${formatPanjang(new Date())}`" :pencetak="sesi.pengguna?.nama_lengkap">
      <table class="tabel">
        <colgroup><col style="width:4%"><col style="width:15%"><col style="width:13%"><col style="width:15%"><col style="width:10%"><col style="width:8%"><col style="width:9%"><col style="width:8%"><col style="width:10%"><col style="width:8%"></colgroup>
        <thead><tr><th>No.</th><th>Pola</th><th>Sesi</th><th>Hari</th><th>Jam</th><th>Dibuka</th><th>Tepat waktu s.d.</th><th>Ditutup</th><th>Presensi pulang</th><th>Cepat pulang sebelum</th></tr></thead>
        <tbody>
          <tr v-for="(b, i) in barisCetak" :key="b.s.id">
            <td class="tengah">{{ i + 1 }}</td><td>{{ b.p.nama }}</td><td>{{ b.s.nama }}{{ b.s.opsional ? ' (opsional)' : '' }}</td>
            <td>{{ b.p.jenis === 'shift' ? 'Sesuai jadwal shift' : hariEfektif(b.s, b.p) }}</td><td class="tengah">{{ rentangJam(b.s) }}</td>
            <td class="tengah">{{ jamTitik(b.j.buka) }}</td><td class="tengah">{{ jamTitik(b.j.tepat) }}</td><td class="tengah">{{ jamTitik(b.j.tutup) }}</td>
            <td class="tengah">{{ b.s.wajib_pulang ? `${jamTitik(b.j.pulangBuka)}–${jamTitik(b.j.batasPulang)}` : '–' }}</td>
            <td class="tengah">{{ b.s.wajib_pulang && !b.s.opsional ? jamTitik(b.j.batasCepat) : '–' }}</td>
          </tr>
        </tbody>
      </table>
      <p style="margin-top: 6pt">Catatan: semua jam dalam WITA. Presensi wajib disertai selfie dan dilakukan di dalam radius titik GPS pondok. Presensi di luar area memerlukan verifikasi admin.</p>
      <template #ttd>
        <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: direktur.jabatan_tertulis || 'Direktur', nama: direktur.nama || '', niy: direktur.niy }"
          :kanan="{ jabatan: sesi.isSuperadmin ? 'Pengelola Sistem' : 'Admin Presensi', nama: sesi.pengguna?.nama_lengkap || '' }" />
      </template>
    </DokumenCetak>
  </div>
</template>
