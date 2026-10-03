<!-- SIMKA PRO | src/pages/organisasi/TabJabatan.vue | v1.0 | Fase 1 – Struktur organisasi | 03/10/2026 -->
<script setup>
// Jabatan fungsional (P1, boleh rangkap) dan jabatan struktural (P2, satu per orang).
import { ref, computed } from 'vue'
import { PhPlus, PhPencilSimple, PhFloppyDisk } from '@phosphor-icons/vue'
import { useOrganisasi } from '@/stores/organisasi'
import { useUI } from '@/stores/ui'
import LembarBawah from '@/components/LembarBawah.vue'

const props = defineProps({ jenis: { type: String, required: true } }) // 'fungsional' | 'struktural'
const org = useOrganisasi(); const ui = useUI()
const P1 = computed(() => props.jenis === 'fungsional')
const daftar = computed(() => [...org[props.jenis]].sort((a, b) => P1.value ? a.urutan - b.urutan : a.tingkat - b.tingkat))
const jumlah = (id) => (P1.value ? org.jumlahFungsional : org.jumlahStruktural)[id] || 0
const SESI = { rentang: 'Jam kerja rentang', sesi: 'Per sesi (halaqah, asrama, ekskul)', shift: 'Shift bergilir', khusus: 'Jadwal khusus' }

const lembar = ref(false); const f = ref({})
function buka(j = null) {
  f.value = j ? { ...j } : P1.value
    ? { _baru: true, kode: '', nama: '', jenis_sesi: 'rentang', tanpa_rangkap: false, pengasuh: false, aktif: true, urutan: daftar.value.length + 1 }
    : { _baru: true, kode: '', nama: '', tingkat: 45, boleh_menyetujui: false, aktif: true, urutan: daftar.value.length + 1 }
  lembar.value = true
}
async function simpan() {
  const j = f.value
  j.kode = (j.kode || '').trim().toUpperCase().replace(/\s+/g, '_')
  if (!j.nama?.trim()) return ui.toast('Nama jabatan wajib diisi.', 'galat')
  if (!/^[A-Z0-9_]{2,30}$/.test(j.kode)) return ui.toast('Kode 2–30 karakter: huruf kapital, angka, atau garis bawah.', 'galat')
  try { await org.simpan(props.jenis, { ...j, nama: j.nama.trim() }, !!j._baru); lembar.value = false; ui.toast(`Jabatan ${j.nama} disimpan.`) }
  catch (e) { ui.toast(e.message, 'galat') }
}
async function ubahAktif(j, ev) {
  if (j.aktif && jumlah(j.id) && !(await ui.konfirmasi({ judul: `Nonaktifkan ${j.nama}?`, pesan: `${jumlah(j.id)} pegawai masih memegang jabatan ini. Jabatan tidak dapat dipilih lagi untuk pegawai baru, tetapi data lama tetap tersimpan.`, ya: 'Nonaktifkan' }))) { ev.target.checked = j.aktif; return }
  try { await org.simpan(props.jenis, { id: j.id, aktif: !j.aktif }); ui.toast(`${j.nama} ${j.aktif ? 'diaktifkan' : 'dinonaktifkan'}.`) } catch (e) { ui.toast(e.message, 'galat') }
}
</script>
<template>
  <div>
    <section class="kartu p-4 sm:p-5">
      <div class="mb-3 flex flex-wrap items-center justify-between gap-2">
        <p class="max-w-xl text-sm text-teks3">
          <template v-if="P1">Jabatan fungsional menentukan menu kerja dan pola presensi. Satu pegawai boleh memegang beberapa jabatan fungsional, kecuali jabatan bertanda <strong class="font-semibold text-teks2">tidak rangkap</strong>.</template>
          <template v-else>Satu pegawai hanya memegang satu jabatan struktural. Tingkat makin kecil makin tinggi; tingkat 20 ke bawah melihat seluruh pondok.</template>
        </p>
        <button class="tombol-garis" @click="buka()"><PhPlus :size="18" weight="bold" /> Tambah jabatan</button>
      </div>
      <ul class="divide-y divide-garis">
        <li v-for="j in daftar" :key="j.id" :class="['flex flex-wrap items-center gap-3 py-3', !j.aktif && 'opacity-60']">
          <span v-if="!P1" class="grid h-10 w-10 shrink-0 place-items-center rounded-xl bg-permukaan2 text-sm font-bold tabular-nums" :title="'Tingkat ' + j.tingkat">{{ j.tingkat }}</span>
          <div class="min-w-[180px] flex-1">
            <p class="font-semibold">{{ j.nama }}</p>
            <p class="text-xs text-teks3">Kode {{ j.kode }}<template v-if="P1"> – {{ SESI[j.jenis_sesi] }}</template> – {{ jumlah(j.id) }} pegawai</p>
            <div class="mt-1 flex flex-wrap gap-1">
              <span v-if="P1 && j.pengasuh" class="lencana w-santri">Pengasuh santri</span>
              <span v-if="P1 && j.tanpa_rangkap" class="lencana w-klinik">Tidak rangkap</span>
              <span v-if="!P1 && j.boleh_menyetujui" class="lencana w-presensi">Menyetujui pengajuan</span>
              <span v-if="!P1 && !j.boleh_menyetujui" class="lencana w-hakakses">Tidak menyetujui, kecuali Plt</span>
            </div>
          </div>
          <label class="flex min-h-[44px] items-center gap-2 text-sm font-semibold text-teks2">
            <input type="checkbox" :checked="j.aktif" class="h-5 w-5 accent-[#C7332F]" @change="ubahAktif(j, $event)" /> Aktif</label>
          <button class="tombol-ikon" @click="buka(j)" :aria-label="`Ubah ${j.nama}`"><PhPencilSimple :size="20" /></button>
        </li>
      </ul>
    </section>

    <LembarBawah v-model="lembar" :judul="f._baru ? 'Tambah jabatan' : `Ubah ${f.nama}`">
      <div class="space-y-4 pb-2">
        <div><label class="label-isian" for="jb-nama">Nama jabatan</label><input id="jb-nama" v-model="f.nama" class="isian" /></div>
        <div class="grid gap-4 sm:grid-cols-2">
          <div><label class="label-isian" for="jb-kode">Kode</label><input id="jb-kode" v-model="f.kode" class="isian uppercase" :disabled="!f._baru" /></div>
          <div v-if="P1"><label class="label-isian" for="jb-urut">Urutan tampil</label><input id="jb-urut" v-model.number="f.urutan" type="number" min="0" class="isian" /></div>
          <div v-else><label class="label-isian" for="jb-tkt">Tingkat (10–99)</label><input id="jb-tkt" v-model.number="f.tingkat" type="number" min="10" max="99" class="isian" /></div>
        </div>
        <p v-if="!f._baru" class="-mt-2 text-xs text-teks3">Kode tidak dapat diubah karena dipakai aturan hak akses dan impor data.</p>
        <template v-if="P1">
          <div><label class="label-isian" for="jb-sesi">Pola presensi</label>
            <select id="jb-sesi" v-model="f.jenis_sesi" class="isian"><option v-for="(n, k) in SESI" :key="k" :value="k">{{ n }}</option></select></div>
          <label class="flex min-h-[44px] items-center gap-3 font-semibold"><input v-model="f.pengasuh" type="checkbox" class="h-5 w-5 accent-[#C7332F]" /> Pengasuh santri (hanya mengakses santri kelompoknya)</label>
          <label class="flex min-h-[44px] items-center gap-3 font-semibold"><input v-model="f.tanpa_rangkap" type="checkbox" class="h-5 w-5 accent-[#C7332F]" /> Tidak boleh dirangkap dengan tugas lain</label>
        </template>
        <label v-else class="flex min-h-[44px] items-center gap-3 font-semibold"><input v-model="f.boleh_menyetujui" type="checkbox" class="h-5 w-5 accent-[#C7332F]" /> Berwenang menyetujui pengajuan anggota</label>
        <button class="tombol-utama w-full" @click="simpan"><PhFloppyDisk :size="20" weight="duotone" /> Simpan</button>
      </div>
    </LembarBawah>
  </div>
</template>
