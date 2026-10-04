<!-- SIMKA PRO | src/pages/jurnal/TabMengajar.vue | v1.0 | Fase 4 – Tahap 5 Jadwal pelajaran dan jurnal mengajar | 04/10/2026 -->
<script setup>
// Jurnal mengajar (sepaket dengan Jurnal Harian; batas pengisian H+1). Jam pelajaran berurutan dengan mapel dan kelas
// yang sama digabung menjadi satu blok. Bila ada rencana materi, cukup satu ketukan "Terlaksana sesuai rencana".
import { ref, computed, onMounted, watch } from 'vue'
import { PhChalkboardTeacher, PhCheckCircle, PhLightning, PhFloppyDisk, PhListNumbers, PhXCircle, PhClock } from '@phosphor-icons/vue'
import { useJadwal } from '@/stores/jadwal'
import { useUI } from '@/stores/ui'
import { blokMengajar, jamPendek } from '@/lib/jadwal'
import { hariIniISO, formatHari } from '@/lib/tanggal'
import InputTanggal from '@/components/InputTanggal.vue'
import LembarBawah from '@/components/LembarBawah.vue'

const jd = useJadwal(); const ui = useUI()
const tanggal = ref(hariIniISO()); const slot = ref([]); const memuat = ref(false); const isian = ref({}); const proses = ref('')
async function muat() {
  memuat.value = true
  try {
    slot.value = await jd.jadwalMengajar(tanggal.value)
    isian.value = Object.fromEntries(blok.value.map((b) => [b.kunci, {
      status: b.jurnal?.status || 'terlaksana', materi: b.jurnal?.materi || '', keterangan: b.jurnal?.keterangan || '', plan_id: b.jurnal?.plan_id || null }]))
  } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false }
}
onMounted(muat); watch(tanggal, muat)
const blok = computed(() => blokMengajar(slot.value))
const kemarin = () => { const d = new Date(`${hariIniISO()}T12:00:00+08:00`); d.setUTCDate(d.getUTCDate() - 1); return d.toISOString().slice(0, 10) }
const terkunci = computed(() => tanggal.value < kemarin() || tanggal.value > hariIniISO())
const terisi = computed(() => blok.value.filter((b) => b.slot.every((s) => s.jurnal)).length)

async function simpan(b, sesuaiRencana = false) {
  const f = isian.value[b.kunci]
  if (sesuaiRencana) Object.assign(f, { status: 'terlaksana', materi: b.rencana.topik, plan_id: b.rencana.id, keterangan: '' })
  if (f.status === 'terlaksana' && f.materi.trim().length < 3) return ui.toast('Isi materi pokok yang diajarkan.', 'galat')
  if (f.status === 'tidak_terlaksana' && f.keterangan.trim().length < 3) return ui.toast('Isi keterangan mengapa tidak terlaksana.', 'galat')
  proses.value = b.kunci
  try {
    await jd.simpanJurnal(tanggal.value, b.slot.map((s) => ({ assignment_id: s.assignment_id, period_id: s.period_id, status: f.status, materi: f.materi.trim(), plan_id: f.plan_id, keterangan: f.keterangan.trim() })))
    ui.toast(`Jurnal ${b.mapel} kelas ${b.kelas} tersimpan.`); await muat()
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = '' }
}

// ---------- Rencana materi ----------
const lembar = ref(false); const bR = ref(null); const teksRencana = ref(''); const daftarRencana = ref([])
async function bukaRencana(b) {
  bR.value = b; daftarRencana.value = await jd.muatRencana(b.assignment_id)
  teksRencana.value = daftarRencana.value.map((r) => r.topik).join('\n'); lembar.value = true
}
async function simpanRencana() {
  const topik = teksRencana.value.split('\n').map((x) => x.trim()).filter((x) => x.length >= 2)
  try { const n = await jd.simpanRencana(bR.value.assignment_id, topik); ui.toast(`${n} topik rencana materi disimpan.`); lembar.value = false; await muat() } catch (e) { ui.toast(e.message, 'galat') }
}
</script>
<template>
  <div>
    <div class="mb-4 flex flex-wrap items-end gap-3">
      <div class="w-48"><InputTanggal v-model="tanggal" label="Tanggal mengajar" wajib /></div>
      <p class="flex-1 pb-3 text-sm text-teks3">{{ formatHari(tanggal) }} · {{ terisi }}/{{ blok.length }} pertemuan terisi. Batas pengisian H+1, sama dengan Jurnal Harian.</p>
    </div>
    <p v-if="terkunci" class="mb-3 rounded-xl bg-permukaan2 p-3 text-sm text-teks2">Jurnal tanggal ini sudah terkunci (atau belum waktunya). Hanya dapat dilihat.</p>

    <ul class="space-y-3">
      <li v-for="b in blok" :key="b.kunci" :class="['kartu p-4', b.slot.every((s) => s.jurnal) ? (b.jurnal?.status === 'tidak_terlaksana' ? 'w-klinik' : 'w-presensi') : 'w-jadwal']">
        <div class="flex items-start gap-3">
          <span class="chip-ikon h-11 w-11 shrink-0"><PhChalkboardTeacher :size="24" weight="duotone" /></span>
          <div class="min-w-0 flex-1">
            <p class="font-bold">{{ b.mapel }} · Kelas {{ b.kelas }}</p>
            <p class="flex items-center gap-1 text-sm text-teks3"><PhClock :size="14" /> {{ b.slot.length > 1 ? `${b.slot[0].jam_ke}–${b.slot[b.slot.length - 1].jam_ke.replace('Jam ke-', '')}` : b.jam_ke }} · {{ jamPendek(b.jam_mulai) }}–{{ jamPendek(b.jam_selesai) }} ({{ b.slot.length }} JP)</p>
          </div>
          <span v-if="b.slot.every((s) => s.jurnal)" class="lencana"><component :is="b.jurnal?.status === 'tidak_terlaksana' ? PhXCircle : PhCheckCircle" :size="14" weight="fill" /> {{ b.jurnal?.status === 'tidak_terlaksana' ? 'Tidak terlaksana' : 'Terisi' }}</span>
        </div>

        <template v-if="!terkunci">
          <button v-if="b.rencana && !b.jurnal" class="tombol-utama mt-3 w-full" :disabled="proses === b.kunci" @click="simpan(b, true)">
            <PhLightning :size="20" weight="duotone" /> Terlaksana sesuai rencana: {{ b.rencana.topik }}</button>
          <div class="mt-3 grid grid-cols-2 gap-1 rounded-2xl bg-permukaan2 p-1" role="radiogroup" :aria-label="`Status ${b.mapel}`">
            <button v-for="s in [{ k: 'terlaksana', n: 'Terlaksana' }, { k: 'tidak_terlaksana', n: 'Tidak terlaksana' }]" :key="s.k" type="button" role="radio"
              :aria-checked="isian[b.kunci].status === s.k" @click="isian[b.kunci].status = s.k"
              :class="['min-h-[40px] rounded-xl text-sm font-semibold', isian[b.kunci].status === s.k ? 'bg-permukaan text-teks shadow-kartu' : 'text-teks2']">{{ s.n }}</button>
          </div>
          <input v-if="isian[b.kunci].status === 'terlaksana'" v-model="isian[b.kunci].materi" class="isian mt-2" :aria-label="`Materi ${b.mapel}`"
            :placeholder="b.rencana ? `Rencana: ${b.rencana.topik}` : b.materi_terakhir ? `Sebelumnya: ${b.materi_terakhir}` : 'Materi pokok yang diajarkan'" @input="isian[b.kunci].plan_id = null" />
          <input v-else v-model="isian[b.kunci].keterangan" class="isian mt-2" placeholder="Alasan, mis. kegiatan pondok, digantikan, izin" :aria-label="`Keterangan ${b.mapel}`" />
          <div class="mt-2 flex flex-wrap gap-2">
            <button class="tombol-garis min-h-[40px] px-3 text-sm" @click="bukaRencana(b)"><PhListNumbers :size="18" /> Rencana materi</button>
            <button class="tombol-utama ml-auto min-h-[40px] px-4 text-sm" :disabled="proses === b.kunci" @click="simpan(b)"><PhFloppyDisk :size="18" weight="duotone" /> {{ b.jurnal ? 'Perbarui' : 'Simpan' }}</button>
          </div>
        </template>
        <p v-else-if="b.jurnal" class="mt-2 text-sm text-teks2">{{ b.jurnal.status === 'terlaksana' ? b.jurnal.materi : b.jurnal.keterangan }}</p>
      </li>
    </ul>
    <p v-if="!blok.length && !memuat" class="kartu py-10 text-center text-sm text-teks3">Tidak ada jadwal mengajar pada tanggal ini (hari libur sekolah atau belum ada jadwal pelajaran).</p>

    <LembarBawah v-model="lembar" :judul="bR ? `Rencana materi ${bR.mapel} · ${bR.kelas}` : ''">
      <div class="space-y-3 pb-2">
        <p class="text-sm text-teks2">Tulis satu topik per baris sesuai urutan. Saat mengisi jurnal, topik berikutnya muncul sebagai tombol "Terlaksana sesuai rencana".</p>
        <textarea v-model="teksRencana" class="isian min-h-[220px]" rows="10" placeholder="Bab 1: …&#10;Bab 2: …" aria-label="Daftar rencana materi" />
        <button class="tombol-utama w-full" @click="simpanRencana">Simpan rencana</button>
      </div>
    </LembarBawah>
  </div>
</template>
