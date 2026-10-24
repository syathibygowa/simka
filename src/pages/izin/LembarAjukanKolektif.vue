<!-- SIMKA PRO | src/pages/izin/LembarAjukanKolektif.vue | v1.0 | 14.20.0: ajukan izin kolektif beberapa santri sekaligus | 22/10/2026 -->
<script setup>
// Ajukan izin kolektif (mis. lomba): kegiatan, tempat, keperluan, jenis (keluar/pulang), waktu, pendamping, dan santri dari
// kelas/kamar berbeda. Santri dipilih satu per satu (cari nama/NIS) atau sekaligus dari satu kelompok (kelas, kamar, halaqah,
// ekskul). Ringkasan menunjukkan sebaran kelas dan kamar; diputus Kepala Bidang Kesantrian (dan Direktur/Wadir bila melebihi
// batas hari), pengasuh dan kepala sekolah santri terkait menerima tembusan otomatis.
import { ref, computed, watch } from 'vue'
import { PhPaperPlaneTilt, PhMagnifyingGlass, PhHouseLine, PhPersonSimpleWalk, PhInfo, PhX, PhUsersThree, PhPlus } from '@phosphor-icons/vue'
import { useIzin } from '@/stores/izin'
import { useSantri } from '@/stores/santri'
import { useKelompokSantri } from '@/stores/kelompokSantri'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { namaKelompok } from '@/lib/santri'
import LembarBawah from '@/components/LembarBawah.vue'
import InputTanggal from '@/components/InputTanggal.vue'
import InputJam from '@/components/InputJam.vue'

const buka = defineModel({ type: Boolean, default: false })
const emit = defineEmits(['selesai'])
const iz = useIzin(); const san = useSantri(); const kelS = useKelompokSantri(); const sesi = useSesi(); const ui = useUI()
const isi = ref({}); const tglK = ref(''); const jamK = ref(''); const tglB = ref(''); const jamB = ref(''); const pilih = ref([]); const cari = ref('')
const pendamping = ref('saya'); const kelompok = ref(''); const proses = ref(false)

const isoLokal = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
const jamLokal = (d) => `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`
const gabung = (t, j) => new Date(`${t}T${(j || '00:00').slice(0, 5)}:00+08:00`).toISOString()
watch(buka, async (v) => {
  if (!v) return
  isi.value = { kegiatan: '', tempat: '', alasan: '', jenis: 'keluar', pendamping_lain: '', hp_pendamping: '', catatan: '' }
  // Bawaan: keluar satu jam lagi, kembali pukul 17.00 hari itu (atau 6 jam setelah keluar bila sudah lewat sore)
  const k = new Date(Date.now() + 3600000); tglK.value = isoLokal(k); jamK.value = jamLokal(k)
  const sore = new Date(`${isoLokal(k)}T17:00:00+08:00`); const b = sore - k >= 2 * 3600000 ? sore : new Date(k.getTime() + 6 * 3600000)
  tglB.value = isoLokal(b); jamB.value = jamLokal(b)
  pilih.value = []; cari.value = ''; pendamping.value = 'saya'; kelompok.value = ''
  await san.muat(); kelS.muat().catch(() => {})
})
watch(() => isi.value.jenis, (j) => {
  if (!buka.value) return
  const k = new Date(gabung(tglK.value, jamK.value))
  const b = j === 'pulang' ? new Date(k.getTime() + 86400000) : new Date(k.getTime() + 6 * 3600000)
  tglB.value = isoLokal(b); if (j !== 'pulang') jamB.value = jamLokal(b)
})

const aktif = computed(() => san.daftar.filter((s) => s.status === 'aktif'))
const terpilih = computed(() => pilih.value.map((id) => san.cari(id)).filter(Boolean))
const calon = computed(() => {
  const q = cari.value.toLowerCase().trim(); if (q.length < 2) return []
  return aktif.value.filter((s) => !pilih.value.includes(s.id) && `${s.nama_lengkap} ${s.nis}`.toLowerCase().includes(q)).slice(0, 30)
})
function tambah(s) { if (!pilih.value.includes(s.id)) pilih.value.push(s.id); cari.value = '' }
const hapus = (id) => { pilih.value = pilih.value.filter((x) => x !== id) }
const KEL_JENIS = { kelas: 'Kelas', kamar: 'Kamar', halaqah: 'Halaqah', ekskul: 'Ekskul' }
const URUT_KEL = { kelas: 1, kamar: 2, halaqah: 3, ekskul: 4 }
const pilihanKelompok = computed(() => (kelS.daftar || []).filter((g) => g.aktif !== false && KEL_JENIS[g.jenis]).sort((a, b) => URUT_KEL[a.jenis] - URUT_KEL[b.jenis] || a.nama.localeCompare(b.nama, 'id', { numeric: true })))
async function tambahKelompok() {
  if (!kelompok.value) return
  try {
    await kelS.muatAnggota(kelompok.value)
    const ids = (kelS.anggota[kelompok.value]?.aktif || []).map((a) => a.student_id).filter((id) => aktif.value.some((s) => s.id === id))
    const baru = ids.filter((id) => !pilih.value.includes(id)); pilih.value.push(...baru)
    ui.toast(`${baru.length} santri ditambahkan dari ${kelS.cari(kelompok.value)?.nama || 'kelompok'}. Hapus yang tidak ikut.`); kelompok.value = ''
  } catch (e) { ui.toast(e.message, 'galat') }
}
// Sebaran santri (mekanisme lintas kelas/kamar)
const sebaran = computed(() => {
  const hit = (jenis) => { const m = {}; for (const s of terpilih.value) { const n = namaKelompok(s, jenis) || 'Belum ada'; m[n] = (m[n] || 0) + 1 } return Object.entries(m).sort((a, b) => b[1] - a[1]) }
  return { kelas: hit('kelas'), kamar: hit('kamar') }
})
const lamaHari = computed(() => Math.max(1, Math.ceil((new Date(gabung(tglB.value, jamB.value)) - new Date(gabung(tglK.value, jamK.value))) / 86400000)))
const perluPimpinan = computed(() => lamaHari.value > Number(iz.pengaturan.batas_hari_bidang || 2))

async function kirim() {
  const x = isi.value
  if (x.kegiatan.trim().length < 3) return ui.toast('Isi nama kegiatan, mis. Lomba MTQ tingkat kabupaten.', 'galat')
  if (x.alasan.trim().length < 5) return ui.toast('Tuliskan keperluan izin (minimal 5 huruf).', 'galat')
  const keluar = gabung(tglK.value, jamK.value); const kembali = gabung(tglB.value, jamB.value)
  if (new Date(kembali) <= new Date(keluar)) return ui.toast('Batas kembali harus setelah waktu keluar.', 'galat')
  if (pilih.value.length < 2) return ui.toast('Pilih minimal 2 santri. Untuk satu santri gunakan izin biasa.', 'galat')
  if (pendamping.value === 'lain' && x.pendamping_lain.trim().length < 3) return ui.toast('Tuliskan nama pendamping.', 'galat')
  proses.value = true
  try {
    const id = await iz.ajukanKolektif({ ...x, keluar_pada: keluar, kembali_batas: kembali, santri: pilih.value,
      pendamping_id: pendamping.value === 'saya' ? sesi.pengguna?.id : null, pendamping_nama: pendamping.value === 'saya' ? sesi.pengguna?.nama_lengkap : null,
      pendamping_lain: pendamping.value === 'lain' ? x.pendamping_lain.trim() : '' })
    ui.toast(`Izin kolektif ${pilih.value.length} santri diajukan ke Kepala Bidang Kesantrian${perluPimpinan.value ? ', lalu Direktur/Wadir' : ''}.`)
    buka.value = false; emit('selesai', id)
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
</script>
<template>
  <LembarBawah v-model="buka" judul="Ajukan izin kolektif" lebar>
    <div class="space-y-3 pb-2">
      <div class="grid gap-3 sm:grid-cols-2">
        <div><label class="label-isian" for="ik-keg">Kegiatan <span class="text-merah">*</span></label><input id="ik-keg" v-model="isi.kegiatan" class="isian" placeholder="Contoh: Lomba MTQ Kabupaten Gowa" /></div>
        <div><label class="label-isian" for="ik-tmp">Tempat</label><input id="ik-tmp" v-model="isi.tempat" class="isian" placeholder="Contoh: Masjid Agung Syekh Yusuf" /></div>
      </div>
      <div><label class="label-isian" for="ik-als">Keperluan <span class="text-merah">*</span></label>
        <textarea id="ik-als" v-model="isi.alasan" rows="2" class="isian" placeholder="Contoh: mewakili pondok pada cabang tilawah dan hifzh" /></div>
      <div class="grid grid-cols-2 gap-1 rounded-2xl bg-permukaan2 p-1" role="radiogroup" aria-label="Jenis izin">
        <button v-for="j in [{ k: 'keluar', n: 'Keluar sehari', ikon: PhPersonSimpleWalk }, { k: 'pulang', n: 'Menginap di luar', ikon: PhHouseLine }]" :key="j.k" type="button" role="radio"
          :aria-checked="isi.jenis === j.k" @click="isi.jenis = j.k"
          :class="['flex min-h-[44px] items-center justify-center gap-2 rounded-xl px-2 text-sm font-semibold', isi.jenis === j.k ? 'bg-permukaan text-teks shadow-kartu' : 'text-teks2']"><component :is="j.ikon" :size="20" weight="duotone" /> {{ j.n }}</button>
      </div>
      <div class="grid gap-3 sm:grid-cols-2"><InputTanggal v-model="tglK" label="Tanggal keluar" wajib /><InputJam v-model="jamK" label="Jam keluar" /></div>
      <div class="grid gap-3 sm:grid-cols-2"><InputTanggal v-model="tglB" label="Batas kembali (tanggal)" wajib /><InputJam v-model="jamB" label="Batas kembali (jam)" /></div>

      <div><p class="label-isian">Pendamping <span class="text-merah">*</span></p>
        <div class="flex flex-wrap gap-2" role="radiogroup" aria-label="Pendamping">
          <button v-for="p in [{ k: 'saya', n: `Saya (${sesi.namaPendek || 'pengusul'})` }, { k: 'lain', n: 'Pendamping lain' }]" :key="p.k" type="button" role="radio" :aria-checked="pendamping === p.k" @click="pendamping = p.k"
            :class="['min-h-[40px] rounded-full border px-4 text-sm font-semibold', pendamping === p.k ? 'border-[#1E7D4F] bg-[#E2F1E8] text-[#14583A] dark:bg-[#123524] dark:text-[#8FE0B5]' : 'border-garis text-teks2']">{{ p.n }}</button>
        </div>
        <div v-if="pendamping === 'lain'" class="mt-2 grid gap-3 sm:grid-cols-2">
          <input v-model="isi.pendamping_lain" class="isian" placeholder="Nama pendamping" aria-label="Nama pendamping" />
          <input v-model="isi.hp_pendamping" class="isian" inputmode="tel" placeholder="HP pendamping (08…)" aria-label="HP pendamping" />
        </div></div>

      <div class="rounded-2xl border border-garis p-3">
        <p class="label-isian flex items-center gap-1.5"><PhUsersThree :size="18" /> Santri ({{ pilih.length }}) <span class="text-merah">*</span></p>
        <div class="grid gap-2 sm:grid-cols-[1fr_auto]">
          <div class="relative"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
            <input v-model="cari" type="search" class="isian pl-11" placeholder="Cari nama atau NIS (minimal 2 huruf)" aria-label="Cari santri" /></div>
          <div class="flex gap-2">
            <select v-model="kelompok" class="isian min-w-0 flex-1 sm:w-56" aria-label="Tambah dari kelompok"><option value="">Tambah dari kelompok…</option>
              <option v-for="g in pilihanKelompok" :key="g.id" :value="g.id">{{ KEL_JENIS[g.jenis] }} · {{ g.nama }}</option></select>
            <button type="button" class="tombol-garis min-h-[44px] px-3" :disabled="!kelompok" aria-label="Tambahkan anggota kelompok" @click="tambahKelompok"><PhPlus :size="18" weight="bold" /></button>
          </div>
        </div>
        <ul v-if="calon.length" class="mt-2 max-h-56 divide-y divide-garis overflow-y-auto rounded-xl border border-garis">
          <li v-for="s in calon" :key="s.id"><button type="button" class="flex min-h-[46px] w-full items-center gap-3 px-3 text-left text-sm hover:bg-permukaan2" @click="tambah(s)">
            <span class="min-w-0 flex-1"><b class="block truncate">{{ s.nama_lengkap }}</b><span class="text-xs text-teks3">{{ s.nis }} · {{ namaKelompok(s, 'kelas') || '–' }} · {{ namaKelompok(s, 'kamar') || '–' }}</span></span>
            <PhPlus :size="18" class="text-teks3" /></button></li>
        </ul>
        <ul v-if="terpilih.length" class="mt-2 flex flex-wrap gap-1.5">
          <li v-for="s in terpilih" :key="s.id" class="flex items-center gap-1 rounded-full border border-garis bg-permukaan2 py-1 pl-3 pr-1 text-sm">
            <span>{{ s.nama_lengkap }} <span class="text-xs text-teks3">{{ namaKelompok(s, 'kelas') || '' }}</span></span>
            <button type="button" class="grid h-7 w-7 place-items-center rounded-full text-teks3 hover:bg-permukaan" :aria-label="`Hapus ${s.nama_lengkap}`" @click="hapus(s.id)"><PhX :size="14" weight="bold" /></button></li>
        </ul>
        <p v-if="terpilih.length" class="mt-2 text-xs text-teks2">Sebaran: {{ sebaran.kelas.length }} kelas ({{ sebaran.kelas.map(([n, j]) => `${n} ${j}`).join(', ') }}) ·
          {{ sebaran.kamar.length }} kamar ({{ sebaran.kamar.map(([n, j]) => `${n} ${j}`).join(', ') }})</p>
      </div>

      <p class="flex items-start gap-2 rounded-xl bg-permukaan2 p-3 text-xs text-teks2"><PhInfo :size="18" class="shrink-0" />
        <span>Lama {{ lamaHari }} hari. Satu keputusan untuk semua santri walau berbeda kelas dan kamar: diputus <b>Kepala Bidang Kesantrian</b>{{ perluPimpinan ? `, lalu Direktur/Wakil Direktur (lebih dari ${iz.pengaturan.batas_hari_bidang} hari)` : '' }}.
          Musyrif, wali kelas, dan kepala sekolah santri terkait menerima tembusan. Setelah disetujui terbit satu surat izin kolektif; santri otomatis berstatus Izin di absensi.</span></p>
      <div><label class="label-isian" for="ik-cat">Catatan</label><input id="ik-cat" v-model="isi.catatan" class="isian" placeholder="Opsional, mis. kendaraan pondok" /></div>
      <button class="tombol-utama w-full" :disabled="proses" @click="kirim"><PhPaperPlaneTilt :size="20" weight="duotone" /> Ajukan izin kolektif ({{ pilih.length }} santri)</button>
    </div>
  </LembarBawah>
</template>
