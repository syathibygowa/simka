<!-- SIMKA PRO | src/pages/organisasi/TabUnit.vue | v1.0 | Fase 1 – Struktur organisasi | 03/10/2026 -->
<script setup>
import { ref, computed } from 'vue'
import { PhFloppyDisk, PhTrash } from '@phosphor-icons/vue'
import { useOrganisasi } from '@/stores/organisasi'
import { useUI } from '@/stores/ui'
import SimpulUnit from './SimpulUnit.vue'
import LembarBawah from '@/components/LembarBawah.vue'

const org = useOrganisasi(); const ui = useUI()
const lembar = ref(false); const f = ref({})

function tambah(induk) {
  f.value = { _baru: true, parent_id: induk.id, kode: '', nama: '', jenis: induk.jenis === 'pimpinan' ? 'bidang' : 'unit', prioritas: false, aktif: true, urutan: org.anak(induk.id).length + 1 }
  lembar.value = true
}
function ubah(u) { f.value = { ...u }; lembar.value = true }
// Induk yang boleh dipilih: bukan dirinya sendiri dan bukan turunannya
const pilihanInduk = computed(() => {
  const larang = f.value.id ? org.turunan(f.value.id) : new Set()
  return org.datar.filter((u) => !larang.has(u.id))
})
async function simpan() {
  const u = f.value
  u.kode = (u.kode || '').trim().toUpperCase().replace(/\s+/g, '_')
  if (!u.nama?.trim()) return ui.toast('Nama bidang/unit wajib diisi.', 'galat')
  if (!/^[A-Z0-9_]{2,20}$/.test(u.kode)) return ui.toast('Kode 2–20 karakter: huruf kapital, angka, atau garis bawah.', 'galat')
  try {
    const isi = { id: u.id, kode: u.kode, nama: u.nama.trim(), jenis: u.jenis, prioritas: u.prioritas, aktif: u.aktif, urutan: Number(u.urutan) || 0 }
    if (u.jenis !== 'pimpinan') isi.parent_id = u.parent_id
    await org.simpan('units', isi, !!u._baru)
    lembar.value = false; ui.toast(`${isi.nama} disimpan.`)
  } catch (e) { ui.toast(e.message, 'galat') }
}
async function hapus() {
  const u = f.value
  if (!(await ui.konfirmasi({ judul: `Hapus ${u.nama}?`, pesan: 'Unit yang sudah dihapus tidak dapat dikembalikan. Bila ragu, cukup nonaktifkan.', ya: 'Hapus', bahaya: true }))) return
  try { await org.hapusUnit(u.id); lembar.value = false; ui.toast(`${u.nama} dihapus.`) } catch (e) { ui.toast(e.message, 'galat') }
}
</script>
<template>
  <div>
    <section class="kartu p-3 sm:p-4">
      <p class="mb-2 px-2 text-sm text-teks3">Persetujuan dan laporan mengikuti cabang. Kepala bidang otomatis melihat pegawai unit di bawahnya. Tanda bintang menandai bidang prioritas.</p>
      <ul><SimpulUnit v-for="r in org.akar" :key="r.id" :unit="r" @tambah="tambah" @ubah="ubah" /></ul>
    </section>

    <LembarBawah v-model="lembar" :judul="f._baru ? 'Tambah bidang atau unit' : `Ubah ${f.nama}`">
      <div class="space-y-4 pb-2">
        <div><label class="label-isian" for="un-nama">Nama</label><input id="un-nama" v-model="f.nama" class="isian" placeholder="Contoh: Unit Perpustakaan" /></div>
        <div class="grid gap-4 sm:grid-cols-2">
          <div><label class="label-isian" for="un-kode">Kode</label><input id="un-kode" v-model="f.kode" class="isian uppercase" placeholder="PERPUS" /></div>
          <div v-if="f.jenis !== 'pimpinan'"><label class="label-isian" for="un-jenis">Jenis</label>
            <select id="un-jenis" v-model="f.jenis" class="isian"><option value="bidang">Bidang</option><option value="unit">Unit</option></select></div>
        </div>
        <div v-if="f.jenis !== 'pimpinan'"><label class="label-isian" for="un-induk">Berada di bawah</label>
          <select id="un-induk" v-model="f.parent_id" class="isian">
            <option v-for="u in pilihanInduk" :key="u.id" :value="u.id">{{ '\u2003'.repeat(u.tingkat) }}{{ u.nama }}</option>
          </select></div>
        <div class="grid gap-4 sm:grid-cols-2">
          <div><label class="label-isian" for="un-urut">Urutan tampil</label><input id="un-urut" v-model.number="f.urutan" type="number" min="0" class="isian" /></div>
          <div class="flex flex-col justify-end gap-1">
            <label v-if="f.jenis === 'bidang'" class="flex min-h-[40px] items-center gap-3 font-semibold"><input v-model="f.prioritas" type="checkbox" class="h-5 w-5 accent-[#C7332F]" /> Bidang prioritas</label>
            <label v-if="f.jenis !== 'pimpinan'" class="flex min-h-[40px] items-center gap-3 font-semibold"><input v-model="f.aktif" type="checkbox" class="h-5 w-5 accent-[#C7332F]" /> Aktif</label>
          </div>
        </div>
        <div class="flex gap-2">
          <button v-if="!f._baru && f.jenis !== 'pimpinan'" class="tombol-garis" @click="hapus"><PhTrash :size="20" weight="duotone" /> Hapus</button>
          <button class="tombol-utama flex-1" @click="simpan"><PhFloppyDisk :size="20" weight="duotone" /> Simpan</button>
        </div>
      </div>
    </LembarBawah>
  </div>
</template>
