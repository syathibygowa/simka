<!-- SIMKA PRO | src/pages/santri/PergantianTA.vue | v1.0 | Fase 4 – Tahap 6 Tahun ajaran, statistik, laporan | 05/10/2026 -->
<script setup>
// Pergantian tahun ajaran bertahap: (1) tentukan tahun ajaran baru, (2) periksa keputusan naik/tinggal/lulus per santri,
// (3) buat DRAF (kelas naik otomatis, kamar/halaqah/ekskul disalin), (4) atur draf di Kelompok Santri, (5) aktifkan.
// Saat aktivasi: kenaikan dan kelulusan diterapkan, tahun ajaran lama dikunci (arsip baca saja),
// akun pelatih ekskul luar yang tidak lagi membina dinonaktifkan.
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { PhCalendarPlus, PhArrowFatLinesUp, PhArrowsCounterClockwise, PhGraduationCap, PhRocketLaunch, PhTrash, PhUsersThree, PhInfo } from '@phosphor-icons/vue'
import { useTahunAjaran } from '@/stores/tahunAjaran'
import { useKelompokSantri } from '@/stores/kelompokSantri'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { JENJANG_PENDEK } from '@/lib/santri'
import { formatPanjang } from '@/lib/tanggal'
import InputTanggal from '@/components/InputTanggal.vue'

const router = useRouter(); const ta = useTahunAjaran(); const kel = useKelompokSantri(); const sesi = useSesi(); const ui = useUI()
const boleh = computed(() => sesi.isSuperadmin || (sesi.bolehAdmin('kelola_santri') && sesi.bolehAdmin('kelompok_santri')))
const daftar = ref([]); const keputusan = ref({}); const draf = ref([]); const proses = ref(false); const saring = ref('')
const f = ref({ nama: '', mulai: '', selesai: '', salin_kelompok: true })
const tambahHari = (iso, n) => { const d = new Date(`${iso}T12:00:00+08:00`); d.setUTCDate(d.getUTCDate() + n); return d.toISOString().slice(0, 10) }

onMounted(async () => {
  if (!boleh.value) { ui.toast('Pergantian tahun ajaran hanya untuk superadmin atau admin ber-izin kelola santri dan kelompok santri.', 'galat'); return router.replace('/') }
  await kel.muat()
  const lama = kel.taAktif
  if (lama && /^\d{4}\/\d{4}$/.test(lama.nama)) {
    const [a, b] = lama.nama.split('/').map(Number)
    f.value = { nama: `${a + 1}/${b + 1}`, mulai: lama.selesai ? tambahHari(lama.selesai, 1) : `${b}-07-13`, selesai: `${b + 1}-06-30`, salin_kelompok: true }
  }
  try { [daftar.value, draf.value] = await Promise.all([ta.rencana(), ta.muatDraf()]) } catch (e) { ui.toast(e.message, 'galat') }
  keputusan.value = Object.fromEntries(daftar.value.map((s) => [s.student_id, s.usulan]))
})
const tingkatList = computed(() => [...new Set(daftar.value.map((s) => s.tingkat))].sort((a, b) => a - b))
const tampil = computed(() => daftar.value.filter((s) => !saring.value || String(s.tingkat) === saring.value))
const hitung = computed(() => ({ naik: 0, tinggal: 0, lulus: 0, ...Object.values(keputusan.value).reduce((a, k) => ({ ...a, [k]: (a[k] || 0) + 1 }), {}) }))
const AKSI = [{ k: 'naik', n: 'Naik', w: 'presensi' }, { k: 'tinggal', n: 'Tinggal', w: 'tahfizh' }, { k: 'lulus', n: 'Lulus', w: 'pegawai' }]
const tujuan = (s) => (keputusan.value[s.student_id] === 'naik' ? `→ kelas ${s.tingkat + 1}${s.tingkat === 9 ? ' SMA' : ''}` : keputusan.value[s.student_id] === 'tinggal' ? `tetap kelas ${s.tingkat}` : 'lulus')
function setSemua(aksi) { for (const s of tampil.value) keputusan.value[s.student_id] = aksi === 'naik' && s.tingkat >= 12 ? 'lulus' : aksi }

async function buatDraf() {
  if (!/^\d{4}\/\d{4}$/.test(f.value.nama)) return ui.toast('Nama tahun ajaran ditulis seperti 2027/2028.', 'galat')
  if (!f.value.mulai || !f.value.selesai || f.value.selesai <= f.value.mulai) return ui.toast('Periksa tanggal mulai dan selesai.', 'galat')
  if (!(await ui.konfirmasi({ judul: `Buat draf tahun ajaran ${f.value.nama}?`, ya: 'Buat draf',
    pesan: `${hitung.value.naik} naik, ${hitung.value.tinggal} tinggal kelas, ${hitung.value.lulus} lulus. ${f.value.salin_kelompok ? 'Kelas dinaikkan otomatis; kamar, halaqah, dan ekskul disalin sebagai draf.' : ''} Tahun ajaran aktif belum berubah sampai Anda mengaktifkan draf ini.` }))) return
  proses.value = true
  try {
    const h = await ta.buatDraf({ ...f.value, keputusan: Object.entries(keputusan.value).map(([student_id, aksi]) => ({ student_id, aksi })) })
    ui.toast(`Draf ${f.value.nama} dibuat: ${h.kelompok} kelompok, ${h.keanggotaan} keanggotaan.`); draf.value = await ta.muatDraf()
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
async function hapus(d) {
  if (!(await ui.konfirmasi({ judul: `Hapus draf ${d.nama}?`, pesan: 'Kelompok draf, rencana kenaikan, dan penugasan mengajar draf dihapus. Tahun ajaran aktif tidak berubah.', ya: 'Hapus draf', bahaya: true }))) return
  try { await ta.hapusDraf(d.id); draf.value = await ta.muatDraf(); ui.toast('Draf dihapus.') } catch (e) { ui.toast(e.message, 'galat') }
}
async function aktifkan(d) {
  if (!(await ui.konfirmasi({ judul: `Aktifkan tahun ajaran ${d.nama}?`, bahaya: true, ya: 'Aktifkan sekarang',
    pesan: `Kenaikan (${d.naik}) dan kelulusan (${d.lulus}) diterapkan ke Data Santri; tahun ajaran ${kel.taAktif?.nama || 'lama'} dikunci sebagai arsip (baca saja). Absensi, jadwal, dan pengasuh memakai kelompok ${d.nama}. Langkah ini tidak dapat dibatalkan dari aplikasi.` }))) return
  proses.value = true
  try {
    const h = await ta.aktifkan(d.id)
    ui.toast(`Tahun ajaran ${h.ta_baru} aktif. ${h.naik} santri naik kelas, ${h.lulus} lulus${h.pelatih_dinonaktifkan ? `, ${h.pelatih_dinonaktifkan} akun pelatih luar dinonaktifkan` : ''}.`)
    router.replace('/kelompok-santri')
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
</script>
<template>
  <div class="mx-auto max-w-4xl space-y-4">
    <!-- Draf yang sudah ada -->
    <section v-for="d in draf" :key="d.id" class="kartu w-pengajuan p-5">
      <div class="flex flex-wrap items-center gap-3">
        <span class="chip-ikon h-11 w-11"><PhRocketLaunch :size="24" weight="duotone" /></span>
        <div class="min-w-[200px] flex-1"><p class="font-bold">Draf tahun ajaran {{ d.nama }}</p>
          <p class="text-sm text-teks3">{{ formatPanjang(d.mulai) }} – {{ formatPanjang(d.selesai) }} · {{ d.naik }} naik · {{ d.tinggal }} tinggal · {{ d.lulus }} lulus · {{ d.kelompok }} kelompok</p></div>
      </div>
      <p class="mt-3 flex gap-2 rounded-xl bg-permukaan2 p-3 text-sm text-teks2"><PhInfo :size="18" class="mt-0.5 shrink-0" />
        Atur draf lebih dulu: buka Kelompok Santri, pilih tahun ajaran {{ d.nama }}, lalu tetapkan wali kelas, tambahkan santri baru kelas 7, dan periksa kamar serta halaqah.</p>
      <div class="mt-3 flex flex-wrap gap-2">
        <router-link to="/kelompok-santri" class="tombol-garis" @click="kel.taDipilih = d.id"><PhUsersThree :size="20" weight="duotone" /> Atur kelompok draf</router-link>
        <button class="tombol-garis" :disabled="proses" @click="hapus(d)"><PhTrash :size="20" /> Hapus draf</button>
        <button class="tombol-utama ml-auto" :disabled="proses" @click="aktifkan(d)"><PhRocketLaunch :size="20" weight="duotone" /> Aktifkan {{ d.nama }}</button>
      </div>
    </section>

    <template v-if="!draf.length">
      <section class="kartu w-agenda p-5">
        <div class="mb-3 flex items-center gap-3"><span class="chip-ikon h-11 w-11"><PhCalendarPlus :size="24" weight="duotone" /></span>
          <div><h2 class="judul-bagian">1. Tahun ajaran baru</h2><p class="text-sm text-teks3">Tahun ajaran aktif: {{ kel.taAktif?.nama || '–' }}</p></div></div>
        <div class="grid gap-3 sm:grid-cols-3">
          <div><label class="label-isian" for="ta-n">Nama</label><input id="ta-n" v-model="f.nama" class="isian tabular-nums" placeholder="2027/2028" /></div>
          <InputTanggal v-model="f.mulai" label="Mulai" wajib />
          <InputTanggal v-model="f.selesai" label="Selesai" wajib />
        </div>
        <label class="mt-3 flex min-h-[44px] items-center gap-2 text-sm font-semibold"><input v-model="f.salin_kelompok" type="checkbox" class="h-5 w-5 accent-[#0B7F81]" />
          Salin kelompok sebagai draf (kelas dinaikkan otomatis, mis. 7A → 8A, 9A → 10A; kamar, halaqah, ekskul beserta pengasuh dan jadwal)</label>
      </section>

      <section class="kartu p-5">
        <div class="mb-3 flex flex-wrap items-center gap-2">
          <h2 class="judul-bagian flex-1">2. Keputusan kenaikan ({{ daftar.length }} santri)</h2>
          <span class="lencana w-presensi">{{ hitung.naik }} naik</span><span class="lencana w-tahfizh">{{ hitung.tinggal }} tinggal</span><span class="lencana w-pegawai">{{ hitung.lulus }} lulus</span>
        </div>
        <div class="mb-3 flex flex-wrap items-center gap-2">
          <select v-model="saring" class="isian w-auto" aria-label="Saring kelas"><option value="">Semua kelas</option><option v-for="t in tingkatList" :key="t" :value="String(t)">Kelas {{ t }}</option></select>
          <button class="tombol-garis min-h-[40px] px-3 text-sm" @click="setSemua('naik')"><PhArrowFatLinesUp :size="18" /> Semua yang tampil naik</button>
        </div>
        <ul class="max-h-[60vh] divide-y divide-garis overflow-y-auto">
          <li v-for="s in tampil" :key="s.student_id" class="flex flex-wrap items-center gap-2 py-2">
            <span class="min-w-[160px] flex-1"><b class="block">{{ s.nama }}</b><span class="text-xs text-teks3">{{ s.nis }} · {{ s.rombel ? 'Kelas ' + s.rombel : `Kelas ${s.tingkat} ${JENJANG_PENDEK[s.jenjang]}` }} · {{ tujuan(s) }}</span></span>
            <div class="grid grid-cols-3 gap-1 rounded-xl bg-permukaan2 p-1" role="radiogroup" :aria-label="`Keputusan ${s.nama}`">
              <button v-for="a in AKSI" :key="a.k" type="button" role="radio" :aria-checked="keputusan[s.student_id] === a.k" :disabled="a.k === 'naik' && s.tingkat >= 12"
                @click="keputusan[s.student_id] = a.k" :class="['min-h-[36px] rounded-lg px-2.5 text-xs font-bold disabled:opacity-40', 'w-' + a.w, keputusan[s.student_id] === a.k ? 'bg-permukaan shadow-kartu' : 'text-teks2']"
                :style="keputusan[s.student_id] === a.k ? 'color: var(--c)' : ''">{{ a.n }}</button>
            </div>
          </li>
        </ul>
      </section>

      <div class="flex flex-wrap items-center gap-3 pb-6">
        <p class="flex-1 text-sm text-teks3"><PhArrowsCounterClockwise :size="16" class="inline" /> Draf dapat dihapus dan dibuat ulang selama belum diaktifkan. <PhGraduationCap :size="16" class="inline" /> Santri lulus berstatus "Lulus" saat aktivasi.</p>
        <button class="tombol-utama" :disabled="proses || !daftar.length" @click="buatDraf"><PhCalendarPlus :size="20" weight="duotone" /> {{ proses ? 'Memproses…' : '3. Buat draf tahun ajaran' }}</button>
      </div>
    </template>
  </div>
</template>
