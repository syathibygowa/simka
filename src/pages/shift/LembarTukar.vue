<!-- SIMKA PRO | src/pages/shift/LembarTukar.vue | v1.0 | Fase 2 – Tahap 5 Jadwal shift | 03/10/2026 -->
<script setup>
// Ajukan tukar shift: bertukar dengan shift rekan, atau rekan menggantikan.
// Alur: pemohon → rekan menyetujui → admin memutuskan → jadwal ditukar otomatis.
import { ref, computed, watch } from 'vue'
import { PhArrowsLeftRight, PhInfo } from '@phosphor-icons/vue'
import { useShift } from '@/stores/shift'
import { useUI } from '@/stores/ui'
import { hariIniISO, formatHari } from '@/lib/tanggal'
import { tambahHari } from '@/lib/shift'
import LembarBawah from '@/components/LembarBawah.vue'

const buka = defineModel({ type: Boolean, default: false })
const props = defineProps({ pola: Object, roster: Object, pegawai: Array, sesi: Array, saya: String })
const emit = defineEmits(['terkirim'])
const shift = useShift(); const ui = useUI()
const rekan = ref(''); const mode = ref('tukar'); const rosterRekan = ref(''); const alasan = ref(''); const proses = ref(false)
const pilihanRekan = ref([]); const memuat = ref(false)
const namaSesi = (id) => props.sesi.find((s) => s.id === id)?.nama || '–'

watch(buka, (v) => { if (v) { rekan.value = ''; mode.value = 'tukar'; rosterRekan.value = ''; alasan.value = ''; pilihanRekan.value = [] } })
watch(rekan, async (id) => {
  rosterRekan.value = ''; pilihanRekan.value = []
  if (!id) return
  memuat.value = true
  try {
    const d = await shift.muat(props.pola.id, hariIniISO(), tambahHari(hariIniISO(), 27))
    pilihanRekan.value = d.roster.filter((r) => r.employee_id === id && !r.sudah_mulai && !r.ada_presensi)
  } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false }
})
const rekanList = computed(() => props.pegawai.filter((p) => p.id !== props.saya))
async function kirim() {
  if (!rekan.value) return ui.toast('Pilih rekan lebih dulu.', 'galat')
  if (mode.value === 'tukar' && !rosterRekan.value) return ui.toast('Pilih shift rekan yang akan ditukar.', 'galat')
  if (alasan.value.trim().length < 5) return ui.toast('Alasan wajib diisi (minimal 5 karakter).', 'galat')
  proses.value = true
  try {
    await shift.ajukan({ roster: props.roster.id, rekan: rekan.value, rosterRekan: mode.value === 'tukar' ? rosterRekan.value : null, alasan: alasan.value.trim() })
    ui.toast('Permintaan tukar shift terkirim. Menunggu jawaban rekan.'); buka.value = false; emit('terkirim')
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
</script>
<template>
  <LembarBawah v-model="buka" judul="Ajukan tukar shift">
    <div v-if="roster" class="space-y-4 pb-2">
      <div class="rounded-xl bg-permukaan2 p-3">
        <p class="text-xs font-semibold text-teks3">Shift Anda</p>
        <p class="font-bold">{{ namaSesi(roster.session_id) }} · {{ formatHari(roster.tanggal) }}</p>
      </div>
      <div><label class="label-isian" for="tk-rekan">Rekan <span class="text-merah">*</span></label>
        <select id="tk-rekan" v-model="rekan" class="isian"><option value="">Pilih rekan…</option>
          <option v-for="p in rekanList" :key="p.id" :value="p.id">{{ p.nama }}</option></select></div>
      <div class="grid gap-2 sm:grid-cols-2">
        <label :class="['flex cursor-pointer gap-2.5 rounded-xl border p-3', mode === 'tukar' ? 'border-[#C7332F] bg-[#C7332F]/5' : 'border-garis']">
          <input v-model="mode" type="radio" value="tukar" class="mt-1 h-4 w-4 accent-[#C7332F]" />
          <span><span class="block text-sm font-semibold">Bertukar shift</span><span class="block text-xs text-teks3">Anda mengambil salah satu shift rekan.</span></span></label>
        <label :class="['flex cursor-pointer gap-2.5 rounded-xl border p-3', mode === 'ganti' ? 'border-[#C7332F] bg-[#C7332F]/5' : 'border-garis']">
          <input v-model="mode" type="radio" value="ganti" class="mt-1 h-4 w-4 accent-[#C7332F]" />
          <span><span class="block text-sm font-semibold">Rekan menggantikan</span><span class="block text-xs text-teks3">Rekan mengambil shift ini tanpa tukar balik.</span></span></label>
      </div>
      <div v-if="mode === 'tukar' && rekan">
        <label class="label-isian" for="tk-rr">Shift rekan (4 pekan ke depan)</label>
        <p v-if="memuat" class="text-sm text-teks3">Memuat jadwal rekan…</p>
        <select v-else id="tk-rr" v-model="rosterRekan" class="isian"><option value="">Pilih shift rekan…</option>
          <option v-for="r in pilihanRekan" :key="r.id" :value="r.id">{{ formatHari(r.tanggal) }} – {{ namaSesi(r.session_id) }}</option></select>
        <p v-if="!memuat && !pilihanRekan.length" class="mt-1 text-xs text-teks3">Rekan belum memiliki shift mendatang yang dapat ditukar.</p>
      </div>
      <div><label class="label-isian" for="tk-alasan">Alasan <span class="text-merah">*</span></label>
        <textarea id="tk-alasan" v-model="alasan" rows="2" class="isian py-2.5" placeholder="Contoh: ada keperluan keluarga" /></div>
      <p class="flex gap-2 text-xs text-teks3"><PhInfo :size="16" class="mt-0.5 shrink-0" /> Jadwal baru berubah setelah rekan menyetujui dan admin memberi persetujuan. Shift yang sudah dimulai tidak dapat ditukar.</p>
      <button class="tombol-utama w-full" :disabled="proses" @click="kirim"><PhArrowsLeftRight :size="20" weight="duotone" /> {{ proses ? 'Mengirim…' : 'Kirim permintaan' }}</button>
    </div>
  </LembarBawah>
</template>
