<!-- SIMKA PRO | src/pages/jurnal/PengaturanJurnalMengajar.vue | v1.1 | 14.4.0: pilihan alat dan sumber belajar, isian wajib dapat diatur | 17/10/2026 -->
<script setup>
// Pengaturan jurnal mengajar guru mapel (sebelumnya tombol di tab Jurnal mengajar): batas pengisian, absensi santri
// oleh guru mapel, pilihan metode dan media. Diubah superadmin atau admin ber-izin Jadwal pelajaran; lainnya membaca.
// v1.1: pilihan alat/perlengkapan dan sumber belajar/referensi; isian wajib (bab/materi pokok selalu wajib).
import { ref, computed, onMounted } from 'vue'
import { PhChalkboardTeacher, PhFloppyDisk } from '@phosphor-icons/vue'
import { useJadwal } from '@/stores/jadwal'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'

const jd = useJadwal(); const sesi = useSesi(); const ui = useUI()
const boleh = computed(() => sesi.isSuperadmin || sesi.bolehAdmin('atur_jadwal'))
const fa = ref(null); const proses = ref(false)
const WAJIB = [['subbab', 'Sub-bab/pembahasan'], ['metode', 'Metode/strategi'], ['tujuan', 'Tujuan pembelajaran'], ['kegiatan', 'Kegiatan pembelajaran'], ['media', 'Media'], ['alat', 'Alat/perlengkapan'], ['sumber', 'Sumber belajar/referensi']]
function salin(a) { fa.value = { batas_hari: a.batas_hari ?? 1, absen_santri: a.absen_santri !== false, metode: (a.metode || []).join('\n'), media: (a.media || []).join('\n'),
  alat: (a.alat || []).join('\n'), sumber: (a.sumber || []).join('\n'), wajib: { subbab: true, metode: true, ...(a.wajib || {}) } } }
onMounted(async () => { try { salin(await jd.muatAturJurnal()) } catch (e) { ui.toast(e.message, 'galat') } })
async function simpan() {
  const daftar = (t) => [...new Set(t.split('\n').map((x) => x.trim()).filter(Boolean))].slice(0, 30)
  proses.value = true
  try {
    salin(await jd.simpanAturJurnal({ batas_hari: Number(fa.value.batas_hari), absen_santri: fa.value.absen_santri, metode: daftar(fa.value.metode), media: daftar(fa.value.media),
      alat: daftar(fa.value.alat), sumber: daftar(fa.value.sumber), wajib: { ...fa.value.wajib } }))
    ui.toast('Pengaturan jurnal mengajar disimpan.')
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
</script>
<template>
  <section class="kartu w-jadwal p-4 sm:p-5">
    <h2 class="judul-bagian flex items-center gap-2"><PhChalkboardTeacher :size="22" weight="duotone" style="color: var(--c)" /> Jurnal mengajar guru mapel</h2>
    <p class="mt-1 text-sm text-teks2">Berlaku untuk semua guru mapel di tab Jurnal mengajar.<template v-if="!boleh"> Diubah oleh superadmin atau admin ber-izin Jadwal pelajaran.</template></p>
    <div v-if="fa" class="mt-3 space-y-3">
      <div class="grid gap-3 sm:grid-cols-2">
        <div><label class="label-isian" for="ja-batas">Batas pengisian (hari setelah mengajar)</label>
          <select id="ja-batas" v-model.number="fa.batas_hari" class="isian" :disabled="!boleh"><option v-for="n in [0, 1, 2, 3, 6, 7, 14]" :key="n" :value="n">{{ n === 0 ? 'Hari itu saja' : `H+${n}` }}{{ n === 1 ? ' (bawaan, sama dengan Jurnal Harian)' : n === 6 ? ' (sepekan)' : '' }}</option></select></div>
        <label class="flex items-center gap-3 rounded-xl border border-garis p-3 text-sm"><input v-model="fa.absen_santri" type="checkbox" class="h-5 w-5 shrink-0 accent-[#1E7D4F]" :disabled="!boleh" />
          <span><b>Absensi santri oleh guru mapel</b><span class="block text-xs text-teks3">Guru menandai santri yang tidak hadir pada pelajarannya.</span></span></label>
      </div>
      <div class="grid gap-3 sm:grid-cols-2">
        <div><label class="label-isian" for="ja-metode">Pilihan metode/strategi (satu per baris)</label><textarea id="ja-metode" v-model="fa.metode" class="isian" rows="6" :disabled="!boleh" /></div>
        <div><label class="label-isian" for="ja-media">Pilihan media (satu per baris)</label><textarea id="ja-media" v-model="fa.media" class="isian" rows="6" :disabled="!boleh" /></div>
        <div><label class="label-isian" for="ja-alat">Pilihan alat/perlengkapan (satu per baris)</label><textarea id="ja-alat" v-model="fa.alat" class="isian" rows="6" :disabled="!boleh" /></div>
        <div><label class="label-isian" for="ja-sumber">Pilihan sumber belajar/referensi (satu per baris)</label><textarea id="ja-sumber" v-model="fa.sumber" class="isian" rows="6" :disabled="!boleh" /></div>
      </div>
      <div class="rounded-xl border border-garis p-3">
        <p class="text-sm font-bold">Isian wajib saat guru menyimpan jurnal</p>
        <p class="mb-2 text-xs text-teks3">Bab/materi pokok selalu wajib. Absensi santri mengikuti pilihan "Absensi santri oleh guru mapel" di atas. Guru tetap dapat menambah pilihan sendiri.</p>
        <div class="grid gap-1 sm:grid-cols-2">
          <label v-for="[k, n] in WAJIB" :key="k" class="flex min-h-[40px] items-center gap-2 text-sm"><input v-model="fa.wajib[k]" type="checkbox" class="h-5 w-5 accent-[#1E7D4F]" :disabled="!boleh" /> {{ n }}</label>
        </div>
      </div>
      <button v-if="boleh" class="tombol-utama" :disabled="proses" @click="simpan"><PhFloppyDisk :size="20" weight="duotone" /> Simpan pengaturan</button>
    </div>
    <p v-else class="py-6 text-center text-sm text-teks3">Memuat…</p>
  </section>
</template>
