<!-- SIMKA PRO | src/pages/rapat/LembarRapat.vue | v1.0 | 14.28.0: isian rapat baru/ubah (admin dan superadmin) | 26/10/2026 -->
<script setup>
// Lembar isian rapat: judul, jenis (pimpinan, bidang, rutin, koordinasi, tim/panitia), bidang, tanggal (bawaan hari ini), jam (bawaan jam
// sekarang), lokasi, tautan daring, pimpinan rapat, notulis, dan peserta. Peserta dipilih dengan pemilih sasaran yang sama dengan
// Agenda/Pengumuman (tim kerja, bidang, jabatan fungsional/struktural, pegawai tertentu). Peserta menerima notifikasi undangan.
// Rapat rutin yang sudah dijadwalkan di Agenda (jenis Rapat) tidak perlu dibuat di sini: rapat dan pesertanya terbentuk otomatis.
import { ref, computed, watch } from 'vue'
import { PhFloppyDisk, PhInfo } from '@phosphor-icons/vue'
import { useRapat } from '@/stores/rapat'
import { usePegawai } from '@/stores/pegawai'
import { useOrganisasi } from '@/stores/organisasi'
import { usePengumuman } from '@/stores/pengumuman'
import { useUI } from '@/stores/ui'
import { JENIS_RAPAT } from '@/lib/rapat'
import { hariIniISO, jamSekarang } from '@/lib/tanggal'
import LembarBawah from '@/components/LembarBawah.vue'
import InputTanggal from '@/components/InputTanggal.vue'
import InputJam from '@/components/InputJam.vue'
import PilihSasaran from '@/components/PilihSasaran.vue'

const buka = defineModel({ type: Boolean, default: false })
const props = defineProps({ data: { type: Object, default: null } })   // rapat yang diubah (detail_rapat.rapat) atau null
const emit = defineEmits(['selesai'])
const rp = useRapat(); const peg = usePegawai(); const org = useOrganisasi(); const pg = usePengumuman(); const ui = useUI()
const f = ref({}); const proses = ref(false); const ringkas = ref('')
watch(buka, (v) => {
  if (!v) return
  peg.daftar.length || peg.muat(); org.dimuat || org.muat()
  const d = props.data
  f.value = d ? { id: d.id, judul: d.judul, jenis: d.jenis, org_unit_id: d.org_unit_id || '', tanggal: d.tanggal, jam_mulai: String(d.jam_mulai || '').slice(0, 5), jam_selesai: String(d.jam_selesai || '').slice(0, 5),
    lokasi: d.lokasi || '', tautan: d.tautan || '', pimpinan_id: d.pimpinan_id || '', notulis_id: d.notulis_id || '', status: d.status, sasaran: { jenis: 'pilihan' }, ubahPeserta: false }
    : { judul: '', jenis: 'rutin', org_unit_id: '', tanggal: hariIniISO(), jam_mulai: jamSekarang(), jam_selesai: '', lokasi: '', tautan: '', pimpinan_id: '', notulis_id: '', sasaran: { jenis: 'pilihan' }, ubahPeserta: true }
  ringkas.value = ''
})
const pegawai = computed(() => [...peg.daftar].sort((a, b) => a.nama_lengkap.localeCompare(b.nama_lengkap)))
const bidang = computed(() => (org.units || []).filter((u) => u.aktif !== false).sort((a, b) => a.nama.localeCompare(b.nama)))
async function simpan() {
  const x = f.value
  if (x.judul.trim().length < 3) return ui.toast('Judul rapat minimal 3 huruf.', 'galat')
  if (!x.tanggal) return ui.toast('Tanggal rapat wajib diisi.', 'galat')
  if (x.jam_selesai && x.jam_mulai && x.jam_selesai <= x.jam_mulai) return ui.toast('Jam selesai harus setelah jam mulai.', 'galat')
  const kosong = x.sasaran.jenis !== 'semua' && !['unit', 'fungsional', 'struktural', 'pegawai', 'kelompok_pegawai'].some((k) => (x.sasaran[k] || []).length)
  if (!x.id && kosong && !x.pimpinan_id) return ui.toast('Pilih peserta rapat (tim kerja, bidang, jabatan, atau pegawai).', 'galat')
  proses.value = true
  try {
    const isi = { ...x, judul: x.judul.trim(), ringkasan_sasaran: x.ubahPeserta && !kosong ? ringkas.value : undefined, sasaran: x.ubahPeserta && !kosong ? x.sasaran : undefined }
    delete isi.ubahPeserta
    const id = await rp.simpan(isi)
    ui.toast(x.id ? 'Rapat diperbarui.' : 'Rapat dibuat. Peserta menerima undangan di akunnya.')
    buka.value = false; emit('selesai', id)
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
</script>
<template>
  <LembarBawah v-model="buka" :judul="f.id ? 'Ubah rapat' : 'Rapat baru'" lebar>
    <div class="space-y-4 pb-2">
      <p v-if="!f.id" class="flex gap-2 rounded-xl bg-permukaan2 p-3 text-xs text-teks2"><PhInfo :size="16" class="mt-0.5 shrink-0" />
        Rapat rutin yang dijadwalkan di Agenda (jenis Rapat) terbentuk otomatis beserta pesertanya. Gunakan isian ini untuk rapat di luar Agenda.</p>
      <div><label class="label-isian" for="rp-judul">Judul rapat <span class="text-merah">*</span></label>
        <input id="rp-judul" v-model="f.judul" class="isian" maxlength="200" placeholder="Contoh: Rapat Bidang Tahfizh persiapan ujian kenaikan juz" /></div>
      <div><p class="label-isian">Jenis rapat</p>
        <div class="flex flex-wrap gap-1.5">
          <button v-for="(v, k) in JENIS_RAPAT" :key="k" type="button" :aria-pressed="f.jenis === k" @click="f.jenis = k"
            :class="['min-h-[40px] rounded-xl border-2 px-3 text-sm font-semibold', 'w-' + v.w, f.jenis === k ? 'text-teks' : 'border-garis text-teks2']"
            :style="f.jenis === k ? 'border-color: var(--c); background: color-mix(in srgb, var(--c) 16%, transparent)' : ''">{{ v.n }}</button>
        </div></div>
      <div><label class="label-isian" for="rp-bidang">Bidang/unit (opsional)</label>
        <select id="rp-bidang" v-model="f.org_unit_id" class="isian"><option value="">Tidak khusus satu bidang</option><option v-for="u in bidang" :key="u.id" :value="u.id">{{ u.nama }}</option></select></div>
      <div class="grid gap-3 sm:grid-cols-3">
        <InputTanggal v-model="f.tanggal" label="Tanggal" wajib />
        <InputJam v-model="f.jam_mulai" label="Jam mulai" />
        <div><label class="label-isian" for="rp-selesai">Jam selesai (opsional)</label><input id="rp-selesai" v-model="f.jam_selesai" type="time" class="isian tabular-nums" /></div>
      </div>
      <div class="grid gap-3 sm:grid-cols-2">
        <div><label class="label-isian" for="rp-lokasi">Lokasi</label><input id="rp-lokasi" v-model="f.lokasi" class="isian" placeholder="Contoh: Ruang Direktur" /></div>
        <div><label class="label-isian" for="rp-tautan">Tautan daring (opsional)</label><input id="rp-tautan" v-model="f.tautan" type="url" class="isian" placeholder="https://…" /></div>
      </div>
      <div class="grid gap-3 sm:grid-cols-2">
        <div><label class="label-isian" for="rp-pimpinan">Pimpinan rapat</label>
          <select id="rp-pimpinan" v-model="f.pimpinan_id" class="isian"><option value="">Belum ditentukan</option><option v-for="p in pegawai" :key="p.id" :value="p.id">{{ p.nama_lengkap }}</option></select></div>
        <div><label class="label-isian" for="rp-notulis">Notulis</label>
          <select id="rp-notulis" v-model="f.notulis_id" class="isian"><option value="">Belum ditentukan</option><option v-for="p in pegawai" :key="p.id" :value="p.id">{{ p.nama_lengkap }}</option></select></div>
      </div>
      <div v-if="f.id" class="flex flex-wrap gap-1.5">
        <p class="label-isian w-full">Status</p>
        <button v-for="s in [{ k: 'dijadwalkan', n: 'Dijadwalkan', w: 'agenda' }, { k: 'batal', n: 'Batalkan rapat', w: 'klinik' }]" :key="s.k" type="button" :aria-pressed="f.status === s.k" @click="f.status = s.k"
          :class="['min-h-[40px] rounded-xl border-2 px-3 text-sm font-semibold', 'w-' + s.w, f.status === s.k ? 'text-teks' : 'border-garis text-teks2']"
          :style="f.status === s.k ? 'border-color: var(--c); background: color-mix(in srgb, var(--c) 16%, transparent)' : ''">{{ s.n }}</button>
      </div>
      <div>
        <div class="mb-1 flex items-center justify-between gap-2"><p class="label-isian mb-0">{{ f.id ? 'Tambah peserta' : 'Peserta' }}</p>
          <label v-if="f.id" class="flex items-center gap-2 text-sm font-semibold"><input v-model="f.ubahPeserta" type="checkbox" class="h-5 w-5 accent-[#C7332F]" /> Tambah peserta</label></div>
        <PilihSasaran v-if="f.ubahPeserta" v-model="f.sasaran" :hitung="pg.hitungSasaran" @ringkasan="ringkas = $event" />
        <p class="mt-1 text-xs text-teks3">Pilih tim kerja (mis. Pengurus Harian), bidang, jabatan fungsional/struktural, atau pegawai tertentu. Pimpinan rapat dan notulis otomatis menjadi peserta.</p>
      </div>
      <button class="tombol-utama w-full" :disabled="proses" @click="simpan"><PhFloppyDisk :size="20" weight="duotone" /> {{ proses ? 'Menyimpan…' : f.id ? 'Simpan perubahan' : 'Buat rapat dan undang peserta' }}</button>
    </div>
  </LembarBawah>
</template>
