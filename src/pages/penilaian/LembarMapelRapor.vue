<!-- SIMKA PRO | src/pages/penilaian/LembarMapelRapor.vue | v1.1 | Perbaikan: menu Roster menjadi Jadwal Pelajaran | 15/10/2026 -->
<script setup>
// Lembar tambah/ubah mapel rapor: nama di rapor, singkatan, judul kelompok, KKM/KKTP, sumber nilai (mapel ajar tunggal atau
// gabungan berbobot, nilai UTAS tahfizh, atau diisi wali kelas), cara menentukan nilai (ikut ketentuan atau khusus mapel ini).
import { ref, computed, watch } from 'vue'
import { PhFloppyDisk, PhPlus, PhX, PhInfo } from '@phosphor-icons/vue'
import { usePenilaian } from '@/stores/penilaian'
import { useJadwal } from '@/stores/jadwal'
import { useUI } from '@/stores/ui'
import { JENIS_RAPOR, MODE_NILAI, SUMBER_NILAI } from '@/lib/penilaian'
import LembarBawah from '@/components/LembarBawah.vue'

const buka = defineModel({ type: Boolean, default: false })
const props = defineProps({ mapel: { type: Object, default: null }, jenis: { type: String, required: true }, tingkat: { type: Number, required: true } })
const pn = usePenilaian(); const jd = useJadwal(); const ui = useUI()
const f = ref(null); const proses = ref(false); const tambahId = ref('')
const ket = computed(() => pn.ketentuan[props.jenis] || {})
watch(buka, (v) => {
  if (!v) return
  const m = props.mapel
  f.value = m
    ? { id: m.id, nama: m.nama, singkatan: m.singkatan || '', kelompok: m.kelompok || '', kkm: Number(m.kkm), sumber: m.sumber, mode_nilai: m.mode_nilai || '', aktif: m.aktif, catatan: m.catatan || '',
        sumber_mapel: (m.sumber_mapel || []).map((x) => ({ subject_id: x.subject_id, nama: x.nama, bobot: Number(x.bobot) })) }
    : { nama: '', singkatan: '', kelompok: pn.mapelTingkat(props.jenis, props.tingkat).slice(-1)[0]?.kelompok || '', kkm: Number(ket.value.ambang_bawaan || 75), sumber: 'mapel', mode_nilai: '', aktif: true, catatan: '', sumber_mapel: [] }
  tambahId.value = ''
})
const daftarKelompok = computed(() => [...new Set(pn.mapel.filter((m) => m.jenis === props.jenis && m.kelompok).map((m) => m.kelompok))])
const pilihanMapel = computed(() => jd.mapel.filter((m) => m.aktif && !(f.value?.sumber_mapel || []).some((x) => x.subject_id === m.id))
  .sort((a, b) => (a.jenjang === JENIS_RAPOR[props.jenis].jenjang || a.jenjang === 'semua' ? 0 : 1) - (b.jenjang === JENIS_RAPOR[props.jenis].jenjang || b.jenjang === 'semua' ? 0 : 1) || a.urutan - b.urutan))
const jenjangLain = (s) => { const m = jd.mapel.find((x) => x.id === s.subject_id); return m && m.jenjang !== 'semua' && m.jenjang !== JENIS_RAPOR[props.jenis].jenjang }
function tambahSumber() {
  const m = jd.mapel.find((x) => x.id === tambahId.value); if (!m) return
  const s = f.value.sumber_mapel; s.push({ subject_id: m.id, nama: m.nama, bobot: 0 })
  const rata = Math.floor(100 / s.length); s.forEach((x, i) => { x.bobot = i === s.length - 1 ? 100 - rata * (s.length - 1) : rata })
  tambahId.value = ''
  if (!f.value.nama) f.value.nama = m.nama
}
const jumlahBobot = computed(() => (f.value?.sumber_mapel || []).reduce((n, x) => n + Number(x.bobot || 0), 0))

async function simpan() {
  const d = f.value
  if (d.nama.trim().length < 2) return ui.toast('Nama mapel di rapor wajib diisi.', 'galat')
  if (!(Number(d.kkm) >= 0 && Number(d.kkm) <= 100)) return ui.toast(`${ket.value.label_ambang || 'KKM'} harus 0–100.`, 'galat')
  if (d.sumber === 'mapel' && d.sumber_mapel.length > 1 && jumlahBobot.value !== 100) return ui.toast(`Bobot gabungan harus berjumlah 100% (sekarang ${jumlahBobot.value}%).`, 'galat')
  proses.value = true
  try {
    await pn.simpanMapel({ ...(d.id ? { id: d.id } : { jenis: props.jenis, tingkat: props.tingkat }), nama: d.nama.trim(), singkatan: d.singkatan.trim(), kelompok: d.kelompok.trim(),
      kkm: Number(d.kkm), sumber: d.sumber, mode_nilai: d.mode_nilai, aktif: d.aktif, catatan: d.catatan,
      sumber_mapel: d.sumber === 'mapel' ? d.sumber_mapel.map((x) => ({ subject_id: x.subject_id, bobot: Number(x.bobot) })) : [] })
    buka.value = false; ui.toast(d.id ? 'Mapel rapor disimpan.' : 'Mapel rapor ditambahkan.')
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
</script>
<template>
  <LembarBawah v-model="buka" :judul="mapel ? `Ubah mapel rapor · kelas ${tingkat}` : `Tambah mapel rapor · ${JENIS_RAPOR[jenis].pendek} kelas ${tingkat}`" lebar>
    <form v-if="f" class="space-y-4 pb-2" novalidate @submit.prevent="simpan">
      <div class="grid gap-3 sm:grid-cols-[1fr_9rem]">
        <div><label class="label-isian" for="mr-nama">Nama di rapor <span class="text-merah">*</span></label><input id="mr-nama" v-model="f.nama" class="isian" placeholder="Contoh: Pendidikan Pancasila dan Kewarganegaraan" /></div>
        <div><label class="label-isian" for="mr-singkat">Singkatan</label><input id="mr-singkat" v-model="f.singkatan" class="isian" maxlength="8" placeholder="PKn" /></div>
      </div>
      <div class="grid gap-3 sm:grid-cols-[1fr_9rem]">
        <div><label class="label-isian" for="mr-kel">Judul kelompok di rapor</label>
          <input id="mr-kel" v-model="f.kelompok" class="isian" list="mr-daftar-kel" placeholder="Contoh: KELOMPOK UMUM (kosongkan bila tanpa judul)" />
          <datalist id="mr-daftar-kel"><option v-for="k in daftarKelompok" :key="k" :value="k" /></datalist></div>
        <div><label class="label-isian" for="mr-kkm">{{ ket.label_ambang || 'KKM' }}</label><input id="mr-kkm" v-model.number="f.kkm" type="number" min="0" max="100" step="0.5" class="isian tabular-nums" /></div>
      </div>

      <div>
        <p class="label-isian">Sumber nilai</p>
        <div class="grid gap-1 rounded-2xl bg-permukaan2 p-1 sm:grid-cols-3" role="radiogroup" aria-label="Sumber nilai">
          <button v-for="(s, k) in SUMBER_NILAI" :key="k" type="button" role="radio" :aria-checked="f.sumber === k" @click="f.sumber = k"
            :class="['min-h-[44px] rounded-xl px-2 text-sm font-semibold', f.sumber === k ? 'bg-permukaan text-teks shadow-kartu' : 'text-teks2']">{{ s.n }}</button>
        </div>
        <p class="mt-1 text-xs text-teks3">{{ SUMBER_NILAI[f.sumber].ket }}</p>
      </div>

      <div v-if="f.sumber === 'mapel'" class="rounded-2xl border border-garis p-3">
        <p class="mb-2 text-sm font-bold">Mapel ajar sumber nilai</p>
        <ul class="space-y-2">
          <li v-for="(s, i) in f.sumber_mapel" :key="s.subject_id" class="flex items-center gap-2">
            <span class="min-w-0 flex-1 truncate text-sm font-semibold">{{ s.nama }}<span v-if="jenjangLain(s)" class="lencana w-laporan ml-1">jenjang lain</span></span>
            <div v-if="f.sumber_mapel.length > 1" class="relative w-24"><input v-model.number="s.bobot" type="number" min="1" max="100" class="isian min-h-[40px] pr-7 text-right tabular-nums" :aria-label="`Bobot ${s.nama}`" /><span class="absolute right-2.5 top-1/2 -translate-y-1/2 text-xs text-teks3">%</span></div>
            <button type="button" class="tombol-ikon h-10 w-10" :aria-label="`Lepas ${s.nama}`" @click="f.sumber_mapel.splice(i, 1)"><PhX :size="16" /></button>
          </li>
        </ul>
        <p v-if="f.sumber_mapel.length > 1" :class="['mt-1 text-xs font-semibold', jumlahBobot === 100 ? 'text-teks3' : 'text-merah']">Jumlah bobot {{ jumlahBobot }}% (harus 100%). Nilai rapor = rata-rata berbobot nilai mapel-mapel ini.</p>
        <div class="mt-2 flex gap-2">
          <select v-model="tambahId" class="isian min-h-[44px] flex-1" aria-label="Pilih mapel ajar">
            <option value="">{{ f.sumber_mapel.length ? 'Tambah mapel lain untuk digabung…' : 'Pilih mapel ajar…' }}</option>
            <option v-for="m in pilihanMapel" :key="m.id" :value="m.id">{{ m.nama }} ({{ m.kode }}){{ m.jenjang !== 'semua' ? ` · ${m.jenjang === 'sma' ? 'SMA' : 'Wustha'}` : '' }}</option></select>
          <button type="button" class="tombol-garis min-h-[44px] px-3" :disabled="!tambahId" @click="tambahSumber"><PhPlus :size="18" weight="bold" /></button>
        </div>
        <p v-if="!f.sumber_mapel.length" class="mt-2 text-xs font-semibold text-merah">Belum ada sumber: nilai mapel ini belum dapat terisi otomatis.</p>
        <p class="mt-2 flex gap-1.5 text-xs text-teks3"><PhInfo :size="14" class="mt-0.5 shrink-0" /> Daftar mapel ajar diatur di menu Jadwal Pelajaran → Mapel dan jam. Guru pengampunya dibaca dari penugasan mengajar kelas ini.</p>
      </div>

      <div class="grid gap-3 sm:grid-cols-2">
        <div><label class="label-isian" for="mr-mode">Cara menentukan nilai rapor</label>
          <select id="mr-mode" v-model="f.mode_nilai" class="isian"><option value="">Ikut ketentuan ({{ MODE_NILAI[ket.mode_nilai || 'rekomendasi'].n }})</option>
            <option v-for="(m, k) in MODE_NILAI" :key="k" :value="k">Khusus mapel ini: {{ m.n }}</option></select></div>
        <div><p class="label-isian">Status</p>
          <label class="flex min-h-[46px] cursor-pointer items-center gap-2 rounded-xl border border-garis px-3 text-sm font-semibold"><input v-model="f.aktif" type="checkbox" class="h-5 w-5 accent-[#86198F]" /> Tercetak di rapor (aktif)</label></div>
      </div>
      <div><label class="label-isian" for="mr-cat">Catatan</label><input id="mr-cat" v-model="f.catatan" class="isian" placeholder="Opsional, mis. alasan nilai diambil dari mapel lain" /></div>
      <button class="tombol-utama w-full" :disabled="proses"><PhFloppyDisk :size="20" weight="duotone" /> {{ proses ? 'Menyimpan…' : 'Simpan mapel rapor' }}</button>
    </form>
  </LembarBawah>
</template>
