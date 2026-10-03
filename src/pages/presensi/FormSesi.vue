<!-- SIMKA PRO | src/pages/presensi/FormSesi.vue | v1.0 | Fase 2 – Tahap 3 Pengaturan presensi | 03/10/2026 -->
<script setup>
// Lembar ubah/tambah sesi: jam, hari, jendela buka, toleransi terlambat, batas datang,
// presensi pulang (jendela, toleransi cepat pulang, batas), sesi opsional.
import { ref, computed, watch } from 'vue'
import { PhFloppyDisk, PhTrash, PhClock, PhInfo } from '@phosphor-icons/vue'
import { useAturPresensi } from '@/stores/aturPresensi'
import { useUI } from '@/stores/ui'
import { useLembaga } from '@/stores/lembaga'
import { jamSekarang } from '@/lib/tanggal'
import { HARI_PENUH, URUT_HARI, jamInput, jendela, jamTitik, periksaSesi, durasi, lewatTengahMalam } from '@/lib/presensi'
import LembarBawah from '@/components/LembarBawah.vue'

const buka = defineModel({ type: Boolean, default: false })
const props = defineProps({ sesi: { type: Object, default: null }, polaId: String })
const emit = defineEmits(['tersimpan'])
const atur = useAturPresensi(); const ui = useUI(); const lembaga = useLembaga()
const f = ref(null); const proses = ref(false); const kodeManual = ref(false)

const tambahMenit = (hhmm, m) => { const t = (Number(hhmm.slice(0, 2)) * 60 + Number(hhmm.slice(3, 5)) + m) % 1440; return `${String(Math.floor(t / 60)).padStart(2, '0')}:${String(t % 60).padStart(2, '0')}` }
watch(buka, (v) => {
  if (!v) return
  const pola = atur.cariPola(props.sesi?.pattern_id || props.polaId)
  if (props.sesi?.id) {
    f.value = { ...props.sesi, jam_mulai: jamInput(props.sesi.jam_mulai), jam_selesai: jamInput(props.sesi.jam_selesai), hari: [...props.sesi.hari] }
    kodeManual.value = true
  } else {
    // Isian jam baru mengikuti jam saat ini (ketentuan #10), dibulatkan ke 5 menit
    const j = jamSekarang(); const m = Math.round(Number(j.slice(3, 5)) / 5) * 5
    const mulai = tambahMenit(j.slice(0, 2) + ':00', m)
    const rentang = pola?.jenis === 'rentang' || pola?.jenis === 'shift'
    f.value = { pattern_id: pola?.id, kode: '', nama: '', hari: [0, 1, 2, 3, 4, 5, 6], jam_mulai: mulai, jam_selesai: tambahMenit(mulai, 60),
      buka_menit: 30, toleransi_terlambat_menit: 10, tutup_menit: rentang ? 120 : 45, wajib_pulang: rentang,
      pulang_buka_menit: rentang ? 120 : 0, toleransi_cepat_pulang_menit: rentang ? 10 : 0, batas_pulang_menit: rentang ? 180 : 0,
      opsional: false, label_datang: rentang ? 'Datang' : 'Hadir', label_pulang: rentang ? 'Pulang' : 'Selesai', aktif: true,
      urutan: atur.sesiPola(pola?.id).length + 1 }
    kodeManual.value = false
  }
})
watch(() => f.value?.nama, (n) => {
  if (!f.value || kodeManual.value) return
  f.value.kode = String(n || '').toUpperCase().normalize('NFKD').replace(/[^A-Z0-9 ]/g, '').trim().split(/\s+/).slice(-2).join('_').slice(0, 30)
})
const pola = computed(() => atur.cariPola(f.value?.pattern_id))
const j = computed(() => (f.value?.jam_mulai && f.value?.jam_selesai ? jendela({ ...f.value, jam_mulai: f.value.jam_mulai + ':00', jam_selesai: f.value.jam_selesai + ':00',
  buka_menit: +f.value.buka_menit || 0, toleransi_terlambat_menit: +f.value.toleransi_terlambat_menit || 0, tutup_menit: +f.value.tutup_menit || 0,
  pulang_buka_menit: +f.value.pulang_buka_menit || 0, toleransi_cepat_pulang_menit: +f.value.toleransi_cepat_pulang_menit || 0, batas_pulang_menit: +f.value.batas_pulang_menit || 0 }) : null))
const malam = computed(() => f.value?.jam_mulai && f.value?.jam_selesai && lewatTengahMalam({ jam_mulai: f.value.jam_mulai, jam_selesai: f.value.jam_selesai }))
function ubahHari(h) { const s = new Set(f.value.hari); s.has(h) ? s.delete(h) : s.add(h); f.value.hari = [...s] }

async function simpan() {
  const isi = { ...f.value, jam_mulai: f.value.jam_mulai + ':00', jam_selesai: f.value.jam_selesai + ':00' }
  const galat = periksaSesi(isi); if (galat) return ui.toast(galat, 'galat')
  proses.value = true
  try { await atur.simpanSesi(isi); ui.toast(`Sesi ${isi.nama} tersimpan.`); buka.value = false; emit('tersimpan') }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
async function hapus() {
  if (!(await ui.konfirmasi({ judul: `Hapus sesi ${f.value.nama}?`, pesan: 'Sesi yang sudah memiliki data presensi tidak dapat dihapus; nonaktifkan saja agar tidak berlaku lagi.', ya: 'Hapus', bahaya: true }))) return
  try { await atur.hapusSesi(f.value.id); ui.toast('Sesi dihapus.'); buka.value = false } catch (e) { ui.toast(e.message, 'galat') }
}
const MENIT = [
  { k: 'buka_menit', n: 'Jendela buka', ket: 'menit sebelum jam mulai' },
  { k: 'toleransi_terlambat_menit', n: 'Toleransi terlambat', ket: 'menit setelah jam mulai' },
  { k: 'tutup_menit', n: 'Batas presensi datang', ket: 'menit setelah jam mulai' },
]
const MENIT_PULANG = [
  { k: 'pulang_buka_menit', n: 'Presensi pulang dibuka', ket: 'menit sebelum jam selesai' },
  { k: 'toleransi_cepat_pulang_menit', n: 'Toleransi cepat pulang', ket: 'menit sebelum jam selesai' },
  { k: 'batas_pulang_menit', n: 'Batas presensi pulang', ket: 'menit setelah jam selesai' },
]
</script>
<template>
  <LembarBawah v-model="buka" :judul="f?.id ? `Ubah sesi ${f.nama}` : `Tambah sesi – ${pola?.nama || ''}`">
    <div v-if="f" class="space-y-4 pb-2">
      <div class="grid grid-cols-[1fr_9rem] gap-3">
        <div><label class="label-isian" for="ss-nama">Nama sesi <span class="text-merah">*</span></label>
          <input id="ss-nama" v-model="f.nama" class="isian" placeholder="Contoh: Halaqah subuh" /></div>
        <div><label class="label-isian" for="ss-kode">Kode</label>
          <input id="ss-kode" v-model="f.kode" class="isian uppercase" @input="kodeManual = true; f.kode = f.kode.toUpperCase().replace(/[^A-Z0-9_]/g, '')" /></div>
      </div>
      <div>
        <p class="label-isian">Berlaku pada hari</p>
        <div class="flex flex-wrap gap-1.5">
          <button v-for="h in URUT_HARI" :key="h" type="button" @click="ubahHari(h)" :aria-pressed="f.hari.includes(h)"
            :class="['min-h-[40px] rounded-full border px-3 text-sm font-semibold', f.hari.includes(h) ? 'border-transparent bg-[#C7332F] text-white' : 'border-garis text-teks2']">{{ HARI_PENUH[h] }}</button>
        </div>
        <p class="mt-1 text-xs text-teks3">Hari libur menurut kalender {{ lembaga.holiday_calendars.find((k) => k.jenis_tugas === pola?.kalender)?.nama || 'umum' }} tetap dilewati otomatis. Bila jam berbeda pada hari tertentu, buat sesi lain dengan kode yang sama untuk hari tersebut.</p>
      </div>
      <div class="grid grid-cols-2 gap-3">
        <div><label class="label-isian" for="ss-m">Jam mulai <span class="text-merah">*</span></label><input id="ss-m" v-model="f.jam_mulai" type="time" class="isian tabular-nums" /></div>
        <div><label class="label-isian" for="ss-s">Jam selesai <span class="text-merah">*</span></label><input id="ss-s" v-model="f.jam_selesai" type="time" class="isian tabular-nums" /></div>
      </div>
      <p v-if="malam" class="-mt-2 flex gap-1.5 text-xs font-semibold text-teks2"><PhClock :size="16" class="shrink-0" /> Sesi melewati tengah malam dan selesai pada hari berikutnya.</p>

      <div class="grid gap-3 sm:grid-cols-3">
        <div v-for="m in MENIT" :key="m.k"><label class="label-isian" :for="'ss-' + m.k">{{ m.n }}</label>
          <div class="relative"><input :id="'ss-' + m.k" v-model.number="f[m.k]" type="number" min="0" inputmode="numeric" class="isian pr-16 tabular-nums" />
            <span class="pointer-events-none absolute right-3 top-1/2 -translate-y-1/2 text-sm text-teks3">menit</span></div>
          <p class="mt-1 text-xs text-teks3">{{ m.ket }}</p></div>
      </div>

      <label class="flex min-h-[44px] items-center gap-3 font-semibold"><input v-model="f.wajib_pulang" type="checkbox" class="h-5 w-5 accent-[#C7332F]" /> Wajib presensi pulang (rentang kerja dan shift)</label>
      <div v-if="f.wajib_pulang" class="grid gap-3 sm:grid-cols-3">
        <div v-for="m in MENIT_PULANG" :key="m.k"><label class="label-isian" :for="'ss-' + m.k">{{ m.n }}</label>
          <div class="relative"><input :id="'ss-' + m.k" v-model.number="f[m.k]" type="number" min="0" inputmode="numeric" class="isian pr-16 tabular-nums" />
            <span class="pointer-events-none absolute right-3 top-1/2 -translate-y-1/2 text-sm text-teks3">menit</span></div>
          <p class="mt-1 text-xs text-teks3">{{ m.ket }}</p></div>
      </div>
      <div class="grid grid-cols-2 gap-3">
        <div><label class="label-isian" for="ss-ld">Label tombol datang</label><input id="ss-ld" v-model="f.label_datang" class="isian" maxlength="20" /></div>
        <div v-if="f.wajib_pulang"><label class="label-isian" for="ss-lp">Label tombol pulang</label><input id="ss-lp" v-model="f.label_pulang" class="isian" maxlength="20" /></div>
      </div>
      <label class="flex min-h-[44px] items-start gap-3 font-semibold"><input v-model="f.opsional" type="checkbox" class="mt-0.5 h-5 w-5 accent-[#C7332F]" />
        <span>Sesi opsional<span class="block text-xs font-normal text-teks3">Tidak dihitung sesi wajib dan tidak dicatat tanpa keterangan bila dilewati (contoh: istirahat).</span></span></label>
      <label class="flex min-h-[44px] items-center gap-3 font-semibold"><input v-model="f.aktif" type="checkbox" class="h-5 w-5 accent-[#C7332F]" /> Sesi aktif</label>

      <!-- Ringkasan jendela waktu -->
      <div v-if="j" class="rounded-2xl border border-garis bg-permukaan2 p-3 text-sm">
        <p class="mb-1.5 flex items-center gap-1.5 font-bold"><PhInfo :size="18" weight="duotone" /> Ringkasan aturan sesi ({{ Math.floor(durasi({ jam_mulai: f.jam_mulai, jam_selesai: f.jam_selesai }) / 60) }} jam {{ durasi({ jam_mulai: f.jam_mulai, jam_selesai: f.jam_selesai }) % 60 }} menit)</p>
        <ul class="space-y-0.5 text-teks2">
          <li>Presensi {{ (f.label_datang || 'datang').toLowerCase() }} dibuka pukul <b>{{ jamTitik(j.buka) }}</b></li>
          <li>Tepat waktu sampai pukul <b>{{ jamTitik(j.tepat) }}</b>, setelah itu tercatat terlambat</li>
          <li>Ditutup pukul <b>{{ jamTitik(j.tutup) }}</b>; tanpa presensi tercatat {{ f.opsional ? 'tidak apa-apa (opsional)' : 'tanpa keterangan' }}</li>
          <template v-if="f.wajib_pulang">
            <li>Presensi {{ (f.label_pulang || 'pulang').toLowerCase() }} dapat dilakukan pukul <b>{{ jamTitik(j.pulangBuka) }}</b> sampai <b>{{ jamTitik(j.batasPulang) }}</b></li>
            <li v-if="!f.opsional">Sebelum pukul <b>{{ jamTitik(j.batasCepat) }}</b> dihitung cepat pulang (perlu konfirmasi pegawai)</li>
          </template>
        </ul>
      </div>
      <button class="tombol-utama w-full" :disabled="proses" @click="simpan"><PhFloppyDisk :size="20" weight="duotone" /> {{ proses ? 'Menyimpan…' : 'Simpan sesi' }}</button>
      <button v-if="f.id" class="tombol-teks w-full" @click="hapus"><PhTrash :size="20" /> Hapus sesi</button>
    </div>
  </LembarBawah>
</template>
