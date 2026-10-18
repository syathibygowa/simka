<!-- SIMKA PRO | src/pages/santri/PergantianTA.vue | v1.2 | 14.5.0: keputusan per jenjang (Wustha/SMA), usulan dari rapor, SK Kenaikan Kelas | 18/10/2026 -->
<script setup>
// Pergantian tahun ajaran bertahap: (1) tentukan tahun ajaran baru, (2) periksa keputusan naik/tinggal/lulus per santri,
// (3) buat DRAF (kelas naik otomatis, kamar/halaqah/ekskul disalin), (4) atur draf di Kelompok Santri, (5) aktifkan.
// Saat aktivasi: kenaikan dan kelulusan diterapkan, tahun ajaran lama dikunci (arsip baca saja),
// akun pelatih ekskul luar yang tidak lagi membina dinonaktifkan.
// v1.2: keputusan dipetakan per jenjang (sub-tab Wustha / SMA, jumlah masing-masing); usulan awal mengikuti keputusan rapor
//       wali kelas bila ada (lencana "Rapor"). Setelah draf dibuat: SK Kenaikan Kelas per jenjang diusulkan ke Persuratan
//       (TU memberi nomor SK dan mengajukan tanda tangan; lampiran daftar santri otomatis).
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { PhCalendarPlus, PhArrowFatLinesUp, PhArrowsCounterClockwise, PhGraduationCap, PhRocketLaunch, PhTrash, PhUsersThree, PhInfo, PhCertificate, PhArrowSquareOut } from '@phosphor-icons/vue'
import SubTabJenjang from '@/components/SubTabJenjang.vue'
import { useLembaga } from '@/stores/lembaga'
import { STATUS_KELUAR } from '@/lib/suratKeluar'
import { useTahunAjaran } from '@/stores/tahunAjaran'
import { useKelompokSantri } from '@/stores/kelompokSantri'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { JENJANG_PENDEK } from '@/lib/santri'
import { formatPanjang } from '@/lib/tanggal'
import InputTanggal from '@/components/InputTanggal.vue'
import LembarBawah from '@/components/LembarBawah.vue'

const router = useRouter(); const ta = useTahunAjaran(); const kel = useKelompokSantri(); const sesi = useSesi(); const ui = useUI()
const boleh = computed(() => sesi.isSuperadmin || (sesi.bolehAdmin('kelola_santri') && sesi.bolehAdmin('kelompok_santri')) || sesi.tingkat('kelompok_santri') >= 3)
const daftar = ref([]); const keputusan = ref({}); const draf = ref([]); const proses = ref(false); const saring = ref(''); const jenjang = ref('wustha')
const lembaga = useLembaga()
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
  lembaga.muat().catch(() => null); muatSK()
})
const diJenjang = computed(() => daftar.value.filter((s) => !jenjang.value || s.jenjang === jenjang.value))
const tingkatList = computed(() => [...new Set(diJenjang.value.map((s) => s.tingkat))].sort((a, b) => a - b))
watch(jenjang, () => { saring.value = '' })
const tampil = computed(() => diJenjang.value.filter((s) => !saring.value || String(s.tingkat) === saring.value))
const hitungDari = (xs) => xs.reduce((a, s) => { const k = keputusan.value[s.student_id]; a[k] = (a[k] || 0) + 1; return a }, { naik: 0, tinggal: 0, lulus: 0 })
const hitung = computed(() => hitungDari(daftar.value))
const hitungJ = computed(() => hitungDari(diJenjang.value))
const jumlahJ = computed(() => ({ wustha: daftar.value.filter((s) => s.jenjang === 'wustha').length, sma: daftar.value.filter((s) => s.jenjang === 'sma').length }))
const dariRapor = computed(() => diJenjang.value.filter((s) => s.sumber_usulan === 'rapor').length)

// ---------- SK Kenaikan Kelas (14.5.0) ----------
const sk = ref({}); const lembarSK = ref(null); const fsk = ref({ signatory_id: '', tanggal_rapat: '' })
async function muatSK() { for (const d of draf.value) { try { sk.value[d.id] = await ta.daftarSK(d.id) } catch { sk.value[d.id] = [] } } }
const skJenjang = (d, j) => (sk.value[d.id] || []).find((x) => x.jenjang === j && !['dibatalkan', 'ditolak', 'dicabut'].includes(x.status))
const penandaPilihan = computed(() => lembaga.signatories.filter((x) => x.aktif !== false))
function bukaSK(d, j) {
  const cari = (re) => penandaPilihan.value.find((x) => re.test(x.jabatan_tertulis || ''))
  const bawaan = (j === 'sma' ? cari(/^kepala.*sma/i) : cari(/^kepala.*(wustha|smp|mts)/i)) || cari(/^direktur/i)
  fsk.value = { signatory_id: bawaan?.id || '', tanggal_rapat: '' }; lembarSK.value = { d, j }
}
async function usulSK() {
  const { d, j } = lembarSK.value
  proses.value = true
  try {
    await ta.usulSK({ academic_year_id: d.id, jenjang: j, signatory_id: fsk.value.signatory_id || null, tanggal_rapat: fsk.value.tanggal_rapat || null })
    ui.toast(`SK Kenaikan Kelas ${j === 'sma' ? 'SMA' : 'Wustha'} dikirim ke Tata Usaha untuk diberi nomor dan ditandatangani.`); lembarSK.value = null; await muatSK()
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
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
      <div class="mt-3 grid gap-2 sm:grid-cols-2">
        <div v-for="j in ['wustha', 'sma']" :key="j" class="rounded-xl border border-garis p-3">
          <p class="flex items-center gap-2 text-sm font-bold"><PhCertificate :size="18" weight="duotone" class="text-[#3B4CB0]" /> SK Kenaikan Kelas {{ j === 'sma' ? 'SMA' : 'Wustha' }}</p>
          <template v-if="skJenjang(d, j)">
            <p class="mt-1 text-xs text-teks2"><span :class="['lencana', 'w-' + (STATUS_KELUAR[skJenjang(d, j).status]?.w || 'hakakses')]">{{ STATUS_KELUAR[skJenjang(d, j).status]?.n || skJenjang(d, j).status }}</span>
              {{ skJenjang(d, j).nomor ? ' Nomor ' + skJenjang(d, j).nomor : '' }} · {{ skJenjang(d, j).jumlah }} santri</p>
            <router-link :to="`/persuratan/keluar?surat=${skJenjang(d, j).letter_id}`" class="tombol-teks mt-1 h-9 min-h-0 px-1 text-sm"><PhArrowSquareOut :size="16" /> Buka di Persuratan</router-link>
          </template>
          <template v-else>
            <p class="mt-1 text-xs text-teks3">Disusun dari keputusan kenaikan pada draf ini; lampiran daftar santri otomatis. TU memberi nomor SK dan mengajukan tanda tangan.</p>
            <button class="tombol-garis mt-2 min-h-[40px] px-3 text-sm" :disabled="proses" @click="bukaSK(d, j)"><PhCertificate :size="18" weight="duotone" /> Usulkan SK</button>
          </template>
        </div>
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
        <div class="mb-2 flex flex-wrap items-center gap-2">
          <h2 class="judul-bagian flex-1">2. Keputusan kenaikan ({{ daftar.length }} santri)</h2>
          <span class="text-xs text-teks3">Seluruh pondok: {{ hitung.naik }} naik · {{ hitung.tinggal }} tinggal · {{ hitung.lulus }} lulus</span>
        </div>
        <SubTabJenjang v-model="jenjang" class="mb-3" :semua="false" :jumlah="jumlahJ" label="Jenjang keputusan" />
        <div class="mb-3 flex flex-wrap items-center gap-2">
          <span class="lencana w-presensi">{{ hitungJ.naik }} naik</span><span class="lencana w-tahfizh">{{ hitungJ.tinggal }} tinggal</span><span class="lencana w-pegawai">{{ hitungJ.lulus }} lulus</span>
          <span v-if="dariRapor" class="text-xs text-teks3">{{ dariRapor }} usulan dari keputusan rapor wali kelas</span>
        </div>
        <div class="mb-3 flex flex-wrap items-center gap-2">
          <select v-model="saring" class="isian w-auto" aria-label="Saring kelas"><option value="">Semua kelas</option><option v-for="t in tingkatList" :key="t" :value="String(t)">Kelas {{ t }}</option></select>
          <button class="tombol-garis min-h-[40px] px-3 text-sm" @click="setSemua('naik')"><PhArrowFatLinesUp :size="18" /> Semua yang tampil naik</button>
        </div>
        <ul class="max-h-[60vh] divide-y divide-garis overflow-y-auto">
          <li v-for="s in tampil" :key="s.student_id" class="flex flex-wrap items-center gap-2 py-2">
            <span class="min-w-[160px] flex-1"><b class="block">{{ s.nama }}</b><span class="text-xs text-teks3">{{ s.nis }} · {{ s.rombel ? 'Kelas ' + s.rombel : `Kelas ${s.tingkat} ${JENJANG_PENDEK[s.jenjang]}` }} · {{ tujuan(s) }}</span>
              <span v-if="s.sumber_usulan === 'rapor'" class="lencana w-rapor mt-0.5" :title="s.catatan_rapor || ''">Rapor: {{ s.usulan === 'naik' ? 'naik' : s.usulan === 'tinggal' ? 'tinggal' : 'lulus' }}</span></span>
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
    <LembarBawah :model-value="!!lembarSK" :judul="lembarSK ? `Usulkan SK Kenaikan Kelas ${lembarSK.j === 'sma' ? 'SMA' : 'Wustha'}` : ''" @update:model-value="(v) => !v && (lembarSK = null)">
      <div v-if="lembarSK" class="space-y-3 pb-2">
        <p class="text-sm text-teks2">SK disusun dari keputusan kenaikan santri {{ lembarSK.j === 'sma' ? 'SMA' : 'Wustha' }} pada draf {{ lembarSK.d.nama }}: menimbang, mengingat, diktum, dan lampiran daftar santri. Isinya masih dapat disunting Tata Usaha sebelum diajukan tanda tangan.</p>
        <div><label class="label-isian" for="sk-pen">Penanda tangan</label>
          <select id="sk-pen" v-model="fsk.signatory_id" class="isian"><option value="">Otomatis (Kepala jenjang, atau Direktur)</option>
            <option v-for="x in penandaPilihan" :key="x.id" :value="x.id">{{ x.jabatan_tertulis }} – {{ x.nama }}</option></select></div>
        <InputTanggal v-model="fsk.tanggal_rapat" label="Tanggal rapat dewan guru (opsional)" bawaan-kosong />
        <button class="tombol-utama w-full" :disabled="proses" @click="usulSK"><PhCertificate :size="20" weight="duotone" /> Kirim ke Tata Usaha</button>
      </div>
    </LembarBawah>
  </div>
</template>
