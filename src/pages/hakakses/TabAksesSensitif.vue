<!-- SIMKA PRO | src/pages/hakakses/TabAksesSensitif.vue | v1.0 | Fase 11 – Tahap 6 Penunjukan akses fitur sensitif (gaji, keuangan) oleh superadmin | 11/10/2026 -->
<script setup>
// Fitur sensitif tidak mengikuti hak akses per jabatan: pemegang jabatan Bendahara (Wustha, SMA, Pondok, Yayasan)
// TIDAK otomatis dapat membuka gaji atau keuangan. Superadmin menunjuk orangnya satu per satu:
//   • Gaji & Tunjangan : biasanya Bendahara Yayasan (penanda tangan slip) + pembantu (kelola/lihat)
//   • Keuangan santri  : biasanya Bendahara Pondok (penanda tangan kuitansi dan surat tagihan)
// Penanda tangan wajib bertingkat kelola; jabatan tertulisnya tampil pada slip/kuitansi/surat tagihan.
import { ref, computed, onMounted } from 'vue'
import { PhWallet, PhCashRegister, PhPlus, PhTrash, PhSignature, PhPencilSimple, PhShieldWarning, PhFloppyDisk } from '@phosphor-icons/vue'
import { supabase, MODE_DEMO } from '@/lib/supabase'
import { usePegawai } from '@/stores/pegawai'
import { useUI } from '@/stores/ui'
import { formatPendek } from '@/lib/tanggal'
import LembarBawah from '@/components/LembarBawah.vue'

const peg = usePegawai(); const ui = useUI()
const FITUR = [
  { k: 'gaji', n: 'Gaji & Tunjangan', ikon: PhWallet, w: 'gaji', ttd: 'Bendahara Yayasan', ket: 'Periode gaji, penetapan yayasan, slip, pinjaman/simpanan, tarif, rekening, laporan gaji.' },
  { k: 'keuangan', n: 'Keuangan santri', ikon: PhCashRegister, w: 'tahfizh', ttd: 'Bendahara Pondok', ket: 'Jenis biaya, subsidi, tagihan, pembayaran dan kuitansi, surat tagihan, tunggakan.' },
]
const TINGKAT = { kelola: 'Kelola (mengubah data)', lihat: 'Lihat saja' }
let demo = [{ id: 'sa1', fitur: 'gaji', employee_id: 'p5', nama: 'Ust. Rizal Fahmi, S.E.', niy: '2016010208', jabatan: 'Bendahara', unit: 'Yayasan', tingkat: 'kelola', penanda_tangan: true, jabatan_ttd: 'Bendahara Yayasan', aktif: true, created_at: new Date().toISOString() }]
const daftar = ref([]); const memuat = ref(true)
async function muat() {
  memuat.value = true
  try {
    if (MODE_DEMO) daftar.value = JSON.parse(JSON.stringify(demo))
    else { const { data, error } = await supabase.rpc('daftar_akses_sensitif'); if (error) throw error; daftar.value = data || [] }
  } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false }
}
onMounted(async () => { if (!peg.daftar.length) await peg.muat().catch(() => {}); muat() })
const per = (k) => daftar.value.filter((x) => x.fitur === k)

const f = ref(null); const proses = ref(false); const cari = ref('')
const calon = computed(() => {
  const q = cari.value.toLowerCase().trim(); const ada = new Set(per(f.value?.fitur).map((x) => x.employee_id))
  return peg.daftar.filter((p) => p.status_akun === 'aktif' && p.peran !== 'superadmin' && (f.value?.id || !ada.has(p.id))
    && (!q || [p.nama_lengkap, p.niy, p.jabatan_struktural].join(' ').toLowerCase().includes(q))).slice(0, 40)
})
function baru(k) { cari.value = ''; f.value = { fitur: k, employee_id: '', tingkat: 'kelola', penanda_tangan: !per(k).some((x) => x.penanda_tangan), jabatan_ttd: FITUR.find((x) => x.k === k).ttd, catatan: '' } }
function ubah(x) { cari.value = ''; f.value = { ...x } }
async function simpan() {
  const d = f.value
  if (!d.employee_id) return ui.toast('Pilih pegawai yang ditunjuk.', 'galat')
  if (d.penanda_tangan && d.tingkat !== 'kelola') d.tingkat = 'kelola'
  proses.value = true
  try {
    if (MODE_DEMO) {
      const p = peg.daftar.find((x) => x.id === d.employee_id) || {}
      const i = demo.findIndex((x) => x.fitur === d.fitur && x.employee_id === d.employee_id)
      const r = { ...d, id: d.id || 'sa' + Date.now(), nama: p.nama_lengkap || d.nama, niy: p.niy || d.niy, jabatan: p.jabatan_struktural || d.jabatan, unit: p.nama_unit || d.unit, aktif: true, created_at: d.created_at || new Date().toISOString() }
      if (i >= 0) demo[i] = r; else demo.push(r)
    } else {
      const { error } = await supabase.rpc('simpan_akses_sensitif', { p: { fitur: d.fitur, employee_id: d.employee_id, tingkat: d.tingkat, penanda_tangan: d.penanda_tangan, jabatan_ttd: d.jabatan_ttd, catatan: d.catatan } })
      if (error) throw error
    }
    ui.toast('Penunjukan disimpan.'); f.value = null; await muat()
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
async function hapus(x) {
  if (!(await ui.konfirmasi({ judul: `Cabut akses ${x.nama}?`, pesan: `${x.nama} tidak lagi dapat membuka ${FITUR.find((y) => y.k === x.fitur).n.toLowerCase()}.`, ya: 'Cabut akses', bahaya: true }))) return
  try {
    if (MODE_DEMO) demo = demo.filter((y) => y.id !== x.id)
    else { const { error } = await supabase.rpc('hapus_akses_sensitif', { p_id: x.id }); if (error) throw error }
    ui.toast('Akses dicabut.'); await muat()
  } catch (e) { ui.toast(e.message, 'galat') }
}
const namaPilih = computed(() => peg.daftar.find((p) => p.id === f.value?.employee_id)?.nama_lengkap || f.value?.nama || '')
</script>
<template>
  <div>
    <div class="kartu w-pengajuan mb-4 flex gap-3 p-4">
      <span class="chip-ikon h-10 w-10 shrink-0"><PhShieldWarning :size="22" weight="duotone" /></span>
      <p class="text-sm text-teks2">Gaji dan keuangan santri hanya dapat dibuka oleh <b class="text-teks">superadmin</b> dan pegawai yang <b class="text-teks">ditunjuk di sini</b>.
        Jabatan Bendahara (Wustha, SMA, Pondok, Yayasan) tidak otomatis memperoleh akses. Setiap penunjukan dan pencabutan tercatat di log audit.</p>
    </div>
    <p v-if="memuat" class="kartu p-8 text-center text-sm text-teks3">Memuat…</p>
    <div v-else class="grid gap-4 xl:grid-cols-2">
      <section v-for="x in FITUR" :key="x.k" :class="['kartu p-4 sm:p-5', 'w-' + x.w]">
        <div class="mb-1 flex items-center gap-3">
          <span class="chip-ikon h-11 w-11 shrink-0"><component :is="x.ikon" :size="24" weight="duotone" /></span>
          <h3 class="judul-bagian flex-1">{{ x.n }}</h3>
          <button class="tombol-utama min-h-[40px] px-3 text-sm" @click="baru(x.k)"><PhPlus :size="18" weight="bold" /> Tunjuk</button>
        </div>
        <p class="mb-3 text-sm text-teks3">{{ x.ket }}</p>
        <p v-if="!per(x.k).length" class="rounded-xl bg-permukaan2 p-3 text-sm text-teks2">Belum ada yang ditunjuk. Saat ini hanya superadmin yang dapat membuka fitur ini.</p>
        <p v-else-if="!per(x.k).some((y) => y.penanda_tangan)" class="mb-2 rounded-xl bg-permukaan2 p-3 text-sm font-semibold" style="color: var(--c)">Belum ada penanda tangan; dokumen belum dapat diterbitkan.</p>
        <ul class="divide-y divide-garis">
          <li v-for="y in per(x.k)" :key="y.id" class="flex flex-wrap items-center gap-2 py-3">
            <div class="min-w-[180px] flex-1">
              <p class="font-semibold">{{ y.nama }} <span v-if="!y.aktif" class="lencana w-klinik">Akun/kepegawaian nonaktif</span></p>
              <p class="text-xs text-teks3">NIY {{ y.niy || '–' }}{{ y.jabatan ? ' · ' + y.jabatan : '' }}{{ y.unit ? ' · ' + y.unit : '' }} · sejak {{ formatPendek(y.created_at) }}</p>
              <p class="mt-1 flex flex-wrap gap-1">
                <span :class="['lencana', y.tingkat === 'kelola' ? 'w-presensi' : 'w-agenda']">{{ y.tingkat === 'kelola' ? 'Kelola' : 'Lihat saja' }}</span>
                <span v-if="y.penanda_tangan" class="lencana w-verifikasi"><PhSignature :size="12" /> Penanda tangan: {{ y.jabatan_ttd || x.ttd }}</span>
              </p>
              <p v-if="y.catatan" class="mt-1 text-xs text-teks2">{{ y.catatan }}</p>
            </div>
            <button class="tombol-ikon h-10 w-10" :aria-label="'Ubah penunjukan ' + y.nama" @click="ubah(y)"><PhPencilSimple :size="20" /></button>
            <button class="tombol-ikon h-10 w-10 text-merah" :aria-label="'Cabut akses ' + y.nama" @click="hapus(y)"><PhTrash :size="20" /></button>
          </li>
        </ul>
      </section>
    </div>

    <LembarBawah :model-value="!!f" @update:model-value="(v) => !v && (f = null)" :judul="f?.id ? 'Ubah penunjukan' : 'Tunjuk pengelola ' + (FITUR.find((x) => x.k === f?.fitur)?.n || '')">
      <div v-if="f" class="space-y-4 pb-2">
        <div v-if="!f.id">
          <label class="label-isian" for="as-cari">Pegawai</label>
          <input id="as-cari" v-model="cari" type="search" class="isian" placeholder="Cari nama, NIY, atau jabatan" />
          <ul class="mt-2 max-h-56 divide-y divide-garis overflow-y-auto rounded-xl border border-garis">
            <li v-for="p in calon" :key="p.id"><button type="button" @click="f.employee_id = p.id"
              :class="['w-full px-3 py-2 text-left text-sm', f.employee_id === p.id ? 'bg-permukaan2 font-bold' : 'hover:bg-permukaan2']">
              {{ p.nama_lengkap }} <span class="block text-xs font-normal text-teks3">{{ p.niy || '–' }}{{ p.jabatan_struktural ? ' · ' + p.jabatan_struktural : '' }}{{ p.nama_unit ? ' · ' + p.nama_unit : '' }}</span></button></li>
            <li v-if="!calon.length" class="px-3 py-3 text-sm text-teks3">Tidak ada pegawai berakun aktif yang sesuai.</li>
          </ul>
        </div>
        <p v-if="namaPilih" class="rounded-xl bg-permukaan2 p-3 text-sm">Ditunjuk: <b>{{ namaPilih }}</b></p>
        <div><label class="label-isian" for="as-tkt">Tingkat akses</label>
          <select id="as-tkt" v-model="f.tingkat" class="isian" :disabled="f.penanda_tangan"><option v-for="(n, k) in TINGKAT" :key="k" :value="k">{{ n }}</option></select></div>
        <label class="flex items-start gap-3 rounded-xl border border-garis p-3">
          <input v-model="f.penanda_tangan" type="checkbox" class="mt-1 h-5 w-5" @change="f.penanda_tangan && (f.tingkat = 'kelola')" />
          <span><span class="font-semibold">Penanda tangan dokumen</span><span class="block text-sm text-teks3">{{ f.fitur === 'gaji' ? 'Menandatangani daftar gaji dan slip secara elektronik.' : 'Menandatangani kuitansi dan surat tagihan secara elektronik.' }}</span></span>
        </label>
        <div v-if="f.penanda_tangan"><label class="label-isian" for="as-jab">Jabatan tertulis pada dokumen</label>
          <input id="as-jab" v-model="f.jabatan_ttd" class="isian" :placeholder="FITUR.find((x) => x.k === f.fitur).ttd" /></div>
        <div><label class="label-isian" for="as-cat">Catatan (tidak wajib)</label><input id="as-cat" v-model="f.catatan" class="isian" placeholder="Contoh: Membantu sementara sampai Bendahara Yayasan definitif" /></div>
        <button class="tombol-utama w-full" :disabled="proses" @click="simpan"><PhFloppyDisk :size="20" weight="duotone" /> Simpan penunjukan</button>
      </div>
    </LembarBawah>
  </div>
</template>
