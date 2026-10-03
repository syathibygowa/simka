<!-- SIMKA PRO | src/pages/shift/LembarBergilir.vue | v1.0 | Fase 2 – Tahap 5 Jadwal shift | 03/10/2026 -->
<script setup>
// Pembuat jadwal bergilir otomatis: memutar petugas pada shift yang dipilih dengan hari libur bergantian.
// Hasilnya langsung disimpan untuk rentang yang dipilih, lalu dapat disunting manual.
import { ref, computed, watch } from 'vue'
import { PhArrowUp, PhArrowDown, PhMagicWand, PhInfo } from '@phosphor-icons/vue'
import { useShift } from '@/stores/shift'
import { useUI } from '@/stores/ui'
import { hariIniISO, formatPanjang, formatPendek } from '@/lib/tanggal'
import { buatBergilir, tambahHari, periksaKeterisian, ringkasPegawai } from '@/lib/shift'
import { HARI_SINGKAT, jamTitik, keMenit, durasi } from '@/lib/presensi'
import LembarBawah from '@/components/LembarBawah.vue'
import InputTanggal from '@/components/InputTanggal.vue'

const buka = defineModel({ type: Boolean, default: false })
const props = defineProps({ pola: Object, sesi: Array, pegawai: Array })
const emit = defineEmits(['tersimpan'])
const shift = useShift(); const ui = useUI()
const urut = ref([]); const pilihSesi = ref([]); const mulai = ref(hariIniISO()); const pekan = ref(4); const blok = ref(2); const proses = ref(false)

watch(buka, (v) => {
  if (!v) return
  urut.value = props.pegawai.map((p) => ({ ...p, ikut: true }))
  pilihSesi.value = props.sesi.map((s) => s.id)
  mulai.value = hariIniISO(); pekan.value = 4
  blok.value = props.pegawai.length > props.sesi.length ? 2 : 1
})
function geser(i, arah) { const a = urut.value; const j = i + arah; if (j < 0 || j >= a.length) return; [a[i], a[j]] = [a[j], a[i]] }
const ikut = computed(() => urut.value.filter((p) => p.ikut))
const sesiDipakai = computed(() => props.sesi.filter((s) => pilihSesi.value.includes(s.id)))
const akhir = computed(() => tambahHari(mulai.value, pekan.value * 7 - 1))
const hasil = computed(() => {
  try { return { baris: buatBergilir({ pegawai: ikut.value.map((p) => p.id), sesi: sesiDipakai.value.map((s) => s.id), mulai: mulai.value, hari: pekan.value * 7, blok: blok.value }) } }
  catch (e) { return { galat: e.message, baris: [] } }
})
const tujuhHari = computed(() => Array.from({ length: 7 }, (_, i) => tambahHari(mulai.value, i)))
const ringkas = computed(() => ringkasPegawai(hasil.value.baris, ikut.value, sesiDipakai.value, Array.from({ length: pekan.value * 7 }, (_, i) => tambahHari(mulai.value, i))))
const nama = (id) => (props.pegawai.find((p) => p.id === id)?.nama || '–').replace(/^(Ust\.|Ustzh\.)\s*/, '').split(',')[0]
const singkat = (s) => s.nama
const sel = (t, s) => hasil.value.baris.filter((r) => r.tanggal === t && r.session_id === s.id).map((r) => nama(r.employee_id)).join(', ')

async function simpan() {
  if (hasil.value.galat) return ui.toast(hasil.value.galat, 'galat')
  const cek = periksaKeterisian(hasil.value.baris, sesiDipakai.value, [mulai.value])
  if (cek.kosong.length) return ui.toast('Masih ada shift kosong. Periksa pilihan petugas.', 'galat')
  if (!(await ui.konfirmasi({ judul: 'Simpan jadwal bergilir?', ya: 'Simpan jadwal',
    pesan: `Jadwal ${props.pola.nama} ${formatPanjang(mulai.value)} s.d. ${formatPanjang(akhir.value)} akan diganti dengan hasil ini. Jadwal yang sudah berisi presensi tetap dipertahankan. Petugas mendapat notifikasi.` }))) return
  proses.value = true
  try {
    const r = await shift.simpan(props.pola.id, mulai.value, akhir.value, hasil.value.baris)
    ui.toast(`Jadwal tersimpan: ${r.ditambah} shift baru, ${r.dihapus} shift lama dihapus.`); buka.value = false; emit('tersimpan', mulai.value)
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
</script>
<template>
  <LembarBawah v-model="buka" :judul="`Jadwal bergilir – ${pola?.nama || ''}`">
    <div v-if="pola" class="space-y-4 pb-2">
      <p class="flex gap-2 text-sm text-teks3"><PhInfo :size="18" class="mt-0.5 shrink-0" />
        Setiap petugas bergiliran maju (contoh pagi → siang → malam → libur), satu petugas per shift, dengan hari libur bergantian. Urutan petugas menentukan giliran.</p>
      <div>
        <p class="label-isian">Shift yang diisi</p>
        <div class="flex flex-wrap gap-2">
          <label v-for="s in sesi" :key="s.id" class="flex min-h-[40px] items-center gap-2 rounded-full border border-garis px-3 text-sm font-semibold">
            <input v-model="pilihSesi" type="checkbox" :value="s.id" class="h-4 w-4 accent-[#C7332F]" /> {{ s.nama }}
            <span class="font-normal text-teks3">{{ jamTitik(keMenit(s.jam_mulai)) }}–{{ jamTitik(keMenit(s.jam_mulai) + durasi(s)).replace(' (+1 hari)', '') }}</span></label>
        </div>
      </div>
      <div>
        <p class="label-isian">Urutan petugas ({{ ikut.length }} ikut)</p>
        <ul class="divide-y divide-garis rounded-xl border border-garis">
          <li v-for="(p, i) in urut" :key="p.id" class="flex items-center gap-2 px-3 py-1.5">
            <input v-model="p.ikut" type="checkbox" class="h-5 w-5 accent-[#C7332F]" :aria-label="`Ikutkan ${p.nama}`" />
            <span class="w-6 text-center text-sm font-bold text-teks3">{{ i + 1 }}</span>
            <span :class="['flex-1 text-sm font-semibold', !p.ikut && 'text-teks3 line-through']">{{ p.nama }}</span>
            <button class="tombol-ikon h-10 w-10" :disabled="i === 0" @click="geser(i, -1)" :aria-label="`Naikkan ${p.nama}`"><PhArrowUp :size="18" /></button>
            <button class="tombol-ikon h-10 w-10" :disabled="i === urut.length - 1" @click="geser(i, 1)" :aria-label="`Turunkan ${p.nama}`"><PhArrowDown :size="18" /></button>
          </li>
        </ul>
      </div>
      <div class="grid gap-3 sm:grid-cols-3">
        <InputTanggal v-model="mulai" label="Mulai tanggal" wajib />
        <div><label class="label-isian" for="bg-pekan">Lama jadwal</label>
          <select id="bg-pekan" v-model.number="pekan" class="isian"><option v-for="n in 8" :key="n" :value="n">{{ n }} pekan</option></select></div>
        <div><label class="label-isian" for="bg-blok">Shift sama berturut-turut</label>
          <select id="bg-blok" v-model.number="blok" class="isian"><option v-for="n in 3" :key="n" :value="n">{{ n }} hari</option></select></div>
      </div>
      <p class="text-sm text-teks2">Rentang: {{ formatPanjang(mulai) }} s.d. {{ formatPanjang(akhir) }}</p>

      <p v-if="hasil.galat" class="rounded-xl bg-[#C7332F]/10 p-3 text-sm font-semibold text-merah">{{ hasil.galat }}</p>
      <template v-else>
        <div class="overflow-x-auto rounded-xl border border-garis">
          <table class="w-full min-w-[520px] text-sm">
            <thead><tr class="bg-permukaan2"><th class="px-2 py-1.5 text-left">Shift</th>
              <th v-for="t in tujuhHari" :key="t" class="px-2 py-1.5 text-center">{{ HARI_SINGKAT[new Date(t + 'T00:00:00Z').getUTCDay()] }}<br><span class="font-normal text-teks3">{{ formatPendek(t).slice(0, 5) }}</span></th></tr></thead>
            <tbody><tr v-for="s in sesiDipakai" :key="s.id" class="border-t border-garis">
              <td class="px-2 py-1.5 font-semibold">{{ singkat(s) }}</td>
              <td v-for="t in tujuhHari" :key="t" class="px-2 py-1.5 text-center">{{ sel(t, s) }}</td></tr></tbody>
          </table>
        </div>
        <p class="text-xs text-teks3">Contoh pekan pertama. Selama {{ pekan }} pekan: {{ ringkas.map((r) => `${nama(r.id)} ${r.total} shift, libur ${r.libur} hari`).join(' · ') }}.</p>
      </template>
      <button class="tombol-utama w-full" :disabled="proses || !!hasil.galat" @click="simpan"><PhMagicWand :size="20" weight="duotone" /> {{ proses ? 'Menyimpan…' : 'Buat dan simpan jadwal' }}</button>
    </div>
  </LembarBawah>
</template>
