<!-- SIMKA PRO | src/pages/penilaian/TabPeriodeNilai.vue | v1.3 | 14.4.0: rentang semester bawaan sama dengan rentang rapor | 17/10/2026 -->
<script setup>
// Periode penilaian per jenis rapor × semester: status (Disiapkan → Dibuka → Ditutup), batas pengisian, tanggal rapor
// (dicetak di atas tanda tangan), hari efektif (otomatis dari kalender, dapat diubah), dan tema kokurikuler (SMA).
// v1.2: awal/akhir semester (kosong = sama dengan rentang rapor) — rentang penghitungan komponen nilai Kehadiran.
import { ref, computed, watch } from 'vue'
import { PhFloppyDisk, PhLockSimple, PhLockSimpleOpen, PhHourglassMedium, PhInfo } from '@phosphor-icons/vue'
import { usePenilaian } from '@/stores/penilaian'
import { useUI } from '@/stores/ui'
import { JENIS_RAPOR, STATUS_PERIODE, statusEfektif } from '@/lib/penilaian'
import { formatPanjang } from '@/lib/tanggal'
import InputTanggal from '@/components/InputTanggal.vue'

const pn = usePenilaian(); const ui = useUI(); const proses = ref('')
const form = ref({})
function salinForm() {
  form.value = Object.fromEntries(pn.periode.map((p) => [p.id, { batas_isi: p.batas_isi || '', tanggal_rapor: p.tanggal_rapor || '', hari_efektif: p.hari_efektif ?? '', tema_kokurikuler: p.tema_kokurikuler || '', tanggal_mulai: p.tanggal_mulai || '', tanggal_selesai: p.tanggal_selesai || '' }]))
}
watch(() => pn.periode, salinForm, { immediate: true })
const kelompok = computed(() => Object.keys(JENIS_RAPOR).map((j) => ({ j, info: JENIS_RAPOR[j], baris: pn.periode.filter((p) => p.jenis === j).sort((a, b) => a.semester - b.semester) })))
const boleh = (j) => pn.bolehAtur(j) && !pn.terkunci
const IKON = { disiapkan: PhHourglassMedium, dibuka: PhLockSimpleOpen, ditutup: PhLockSimple }

async function ubahStatus(p, status) {
  if (p.status === status) return
  const n = `${JENIS_RAPOR[p.jenis].n} semester ${p.semester}`
  if (status === 'ditutup' && !(await ui.konfirmasi({ judul: 'Tutup periode penilaian?', pesan: `Nilai ${n} dikunci. Perubahan sesudahnya harus melalui permintaan ubah nilai yang disetujui admin dan tercatat.`, ya: 'Tutup periode', bahaya: true }))) return
  if (status !== 'ditutup' && p.status === 'ditutup' && !(await ui.konfirmasi({ judul: 'Buka kembali periode?', pesan: `Guru dapat kembali mengubah nilai ${n} secara langsung.`, ya: 'Buka kembali' }))) return
  proses.value = p.id
  try { await pn.simpanPeriode(p.id, { status }); ui.toast(`${n}: ${STATUS_PERIODE[status].n.toLowerCase()}.`) } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = '' }
}
async function simpan(p) {
  const f = form.value[p.id]
  if (f.hari_efektif !== '' && !(Number(f.hari_efektif) >= 1 && Number(f.hari_efektif) <= 200)) return ui.toast('Hari efektif harus 1–200 hari, atau kosongkan untuk hitungan otomatis.', 'galat')
  proses.value = p.id
  try {
    await pn.simpanPeriode(p.id, { batas_isi: f.batas_isi || '', tanggal_rapor: f.tanggal_rapor || '', hari_efektif: f.hari_efektif === '' ? '' : Number(f.hari_efektif),
      ...(p.jenis === 'sma' ? { tema_kokurikuler: f.tema_kokurikuler } : {}),
      ...(p.jenis !== 'tahfizh' ? { tanggal_mulai: f.tanggal_mulai || '', tanggal_selesai: f.tanggal_selesai || '' } : {}) })
    ui.toast('Periode disimpan.')
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = '' }
}
</script>
<template>
  <div class="space-y-4">
    <p class="flex gap-2 rounded-2xl bg-permukaan2 p-3 text-sm text-teks2"><PhInfo :size="18" class="mt-0.5 shrink-0" />
      <span>Guru, muhaffizh, pembina, dan wali kelas hanya dapat mengisi nilai saat periodenya <b>Dibuka</b>. Setelah <b>Ditutup</b>, nilai terkunci; perubahan melalui permintaan ubah nilai yang disetujui admin.</span></p>
    <section v-for="k in kelompok" :key="k.j" :class="['kartu p-4', 'w-' + k.info.warna]">
      <p class="mb-3 font-bold"><span style="color: var(--c)">{{ k.info.n }}</span> <span class="text-sm font-normal text-teks3">· {{ k.info.kurikulum }}</span></p>
      <div class="grid gap-3 lg:grid-cols-2">
        <div v-for="p in k.baris" :key="p.id" class="rounded-2xl border border-garis p-3">
          <div class="mb-3 flex flex-wrap items-center gap-2">
            <p class="flex-1 font-bold">Semester {{ p.semester }} ({{ p.semester === 1 ? 'Ganjil' : 'Genap' }})</p>
            <span :class="['lencana', 'w-' + STATUS_PERIODE[p.status].w]"><component :is="IKON[p.status]" :size="14" weight="bold" /> {{ STATUS_PERIODE[p.status].n }}</span>
          </div>
          <div class="mb-3 grid grid-cols-3 gap-1 rounded-2xl bg-permukaan2 p-1" role="radiogroup" :aria-label="`Status ${k.info.n} semester ${p.semester}`">
            <button v-for="(st, kunci) in STATUS_PERIODE" :key="kunci" type="button" role="radio" :aria-checked="p.status === kunci" :disabled="!boleh(k.j) || proses === p.id"
              :class="['min-h-[40px] rounded-xl text-sm font-semibold disabled:cursor-not-allowed', p.status === kunci ? 'bg-permukaan text-teks shadow-kartu' : 'text-teks2']" @click="ubahStatus(p, kunci)">{{ st.n }}</button>
          </div>
          <p class="mb-3 text-xs text-teks3">{{ STATUS_PERIODE[p.status].ket }}<template v-if="p.pengubah"> Terakhir diubah oleh {{ p.pengubah }}.</template>
            <b v-if="statusEfektif(p) !== p.status" class="block text-merah">Batas pengisian sudah lewat: guru dan pengasuh tidak dapat mengisi lagi (terkunci otomatis); perubahan melalui permintaan ubah nilai.</b></p>
          <div class="grid gap-3 sm:grid-cols-2">
            <InputTanggal v-model="form[p.id].batas_isi" label="Batas pengisian nilai" bawaan-kosong />
            <InputTanggal v-model="form[p.id].tanggal_rapor" label="Tanggal rapor" bawaan-kosong />
            <div><label class="label-isian" :for="`hef-${p.id}`">Hari efektif</label>
              <input :id="`hef-${p.id}`" v-model="form[p.id].hari_efektif" type="number" min="1" max="200" class="isian tabular-nums" :placeholder="`Otomatis: ${p.hari_otomatis} hari`" :disabled="!boleh(k.j)" />
              <p class="mt-1 text-xs text-teks3">Kosongkan untuk hitungan otomatis dari kalender ({{ p.hari_otomatis }} hari, ±{{ Math.round(p.hari_otomatis / 6) }} pekan).</p></div>
            <template v-if="k.j !== 'tahfizh'">
              <InputTanggal v-model="form[p.id].tanggal_mulai" label="Awal semester (kosong = otomatis)" bawaan-kosong />
              <InputTanggal v-model="form[p.id].tanggal_selesai" label="Akhir semester (kosong = otomatis)" bawaan-kosong />
              <p class="text-xs text-teks3 sm:col-span-2">Rentang ini dipakai untuk menghitung komponen nilai <b>Kehadiran</b> (absensi pelajaran). Bila kosong: sama dengan rentang rapor (semester 1 = awal tahun ajaran s.d. 31 Desember, semester 2 = 1 Januari s.d. akhir tahun ajaran).</p>
            </template>
            <div v-if="k.j === 'sma'"><label class="label-isian" :for="`tema-${p.id}`">Tema kokurikuler</label>
              <input :id="`tema-${p.id}`" v-model="form[p.id].tema_kokurikuler" class="isian" placeholder="Contoh: Generasi Sehat dan Bugar" :disabled="!boleh(k.j)" /></div>
          </div>
          <p v-if="p.tanggal_rapor" class="mt-2 text-xs text-teks3">Dicetak di rapor: {{ pn.ketentuan[k.j]?.tempat || 'Gowa' }}, {{ formatPanjang(p.tanggal_rapor) }}</p>
          <button v-if="boleh(k.j)" class="tombol-garis mt-3 w-full" :disabled="!!proses" @click="simpan(p)"><PhFloppyDisk :size="20" weight="duotone" /> {{ proses === p.id ? 'Menyimpan…' : 'Simpan periode' }}</button>
        </div>
      </div>
    </section>
  </div>
</template>
