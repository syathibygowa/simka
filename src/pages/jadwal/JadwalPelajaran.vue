<!-- SIMKA PRO | src/pages/jadwal/JadwalPelajaran.vue | v1.1 | Fase 5 – Perbaikan tampilan tab seragam | 05/10/2026 -->
<script setup>
// Jadwal pelajaran. Tab: Jadwal kelas, Jadwal guru, Penugasan mengajar, Pengaturan (mapel dan jam pelajaran),
// Rekap mengajar. Pengatur: admin ber-izin atur_jadwal (atau hak fitur jadwal_mengajar tingkat 3).
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import BilahTab from '@/components/BilahTab.vue'
import { PhCalendarDots, PhChalkboardTeacher, PhListChecks, PhGearSix, PhChartBar, PhEye, PhTrash } from '@phosphor-icons/vue'
import { useJadwal } from '@/stores/jadwal'
import { useKelompokSantri } from '@/stores/kelompokSantri'
import { usePegawai } from '@/stores/pegawai'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { HARI, formatPanjang, hariIniISO } from '@/lib/tanggal'
import { HARI_SEKOLAH, jenisHari, jamPendek } from '@/lib/jadwal'
import { judulKelompok, penandaJenjang } from '@/lib/santri'
import { ambilPenandaTangan } from '@/lib/penandatangan'
import GridJadwal from './GridJadwal.vue'
import TabPenugasan from './TabPenugasan.vue'
import TabPengaturanJadwal from './TabPengaturanJadwal.vue'
import TabRekapMengajar from './TabRekapMengajar.vue'
import LembarBawah from '@/components/LembarBawah.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'

const props = defineProps({ tab: { type: String, default: 'kelas' } })
const router = useRouter(); const jd = useJadwal(); const kel = useKelompokSantri(); const peg = usePegawai(); const sesi = useSesi(); const ui = useUI()
const bolehAtur = computed(() => sesi.bolehAdmin('atur_jadwal') || sesi.tingkat('jadwal_mengajar') >= 3)
const TAB = computed(() => [
  { k: 'kelas', n: 'Jadwal kelas', ikon: PhCalendarDots, w: 'jadwal' }, { k: 'guru', n: 'Jadwal guru', ikon: PhChalkboardTeacher, w: 'pegawai' },
  { k: 'penugasan', n: 'Penugasan', ikon: PhListChecks, w: 'laporan' },
  ...(bolehAtur.value ? [{ k: 'pengaturan', n: 'Mapel dan jam', ikon: PhGearSix, w: 'pengaturan' }] : []),
  { k: 'rekap', n: 'Rekap mengajar', ikon: PhChartBar, w: 'rekap' },
])
const aktif = computed(() => (TAB.value.some((t) => t.k === props.tab) ? props.tab : 'kelas'))
const kelasList = computed(() => kel.dariTA.filter((g) => g.jenis === 'kelas' && g.aktif))
const groupId = ref(''); const employeeId = ref('')
onMounted(async () => {
  await kel.muat(); await jd.muat()
  groupId.value = kelasList.value.find((g) => g.asuhan_saya)?.id || kelasList.value[0]?.id || ''
  employeeId.value = jd.idSaya() && jd.jadwal.some((s) => s.employee_id === jd.idSaya()) ? jd.idSaya() : (jd.penugasan[0]?.employee_id || '')
  if (sesi.isAdmin) peg.daftar.length || peg.muat()
})
const g = computed(() => kel.cari(groupId.value))
const guruList = computed(() => [...new Map(jd.penugasan.map((t) => [t.employee_id, { id: t.employee_id, nama: t.nama_guru }])).values()].sort((a, b) => String(a.nama).localeCompare(String(b.nama), 'id')))
const penugasanKelas = computed(() => jd.penugasan.filter((t) => t.group_id === groupId.value))
const terjadwal = (id) => jd.jadwal.filter((s) => s.assignment_id === id).length

// ---------- Ubah sel ----------
const lembar = ref(false); const sel = ref(null); const proses = ref(false)
function bukaSel(e) { sel.value = e; lembar.value = true }
async function pilihPenugasan(id) {
  proses.value = true
  try { await jd.aturSel(groupId.value, sel.value.hari, sel.value.period.id, id); lembar.value = false; ui.toast(id ? 'Jadwal diperbarui.' : 'Jam dikosongkan.') }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}

// ---------- Cetak ----------
const pratinjau = ref(false); const penanda = ref({ jabatan: '', nama: '', niy: '' })
async function cetak() { penanda.value = aktif.value === 'kelas' && g.value ? await penandaJenjang(g.value.jenjang) : await ambilPenandaTangan('Direktur'); pratinjau.value = true }
const barisCetak = computed(() => {
  // Baris = urutan jam reguler; sel Jumat diambil menurut urutan pada jam Jumat
  const jj = aktif.value === 'kelas' ? g.value?.jenjang || 'wustha' : 'wustha'
  const per = HARI_SEKOLAH.map((h) => jd.jamUntuk(jj, jenisHari(h)))
  const n = Math.max(...per.map((x) => x.length), 0)
  return Array.from({ length: n }, (_, i) => HARI_SEKOLAH.map((h, k) => {
    const p = per[k][i]; if (!p) return { teks: '' }
    if (p.jenis === 'istirahat') return { teks: `${jamPendek(p.jam_mulai)}–${jamPendek(p.jam_selesai)} ${p.nama}`, istirahat: true }
    const s = aktif.value === 'kelas' ? jd.jadwal.find((x) => x.group_id === groupId.value && x.hari === h && x.period_id === p.id)
      : jd.jadwal.find((x) => x.employee_id === employeeId.value && x.hari === h && x.period_id === p.id)
    const t = s && jd.cariPenugasan(s.assignment_id)
    return { teks: `${jamPendek(p.jam_mulai)}–${jamPendek(p.jam_selesai)}`, isi: t ? (aktif.value === 'kelas' ? `${jd.cariMapel(t.subject_id)?.nama} (${String(t.nama_guru || '').split(',')[0]})` : `${kel.cari(t.group_id)?.nama} · ${jd.cariMapel(t.subject_id)?.nama}`) : '' }
  }))
})
const namaGuru = computed(() => guruList.value.find((x) => x.id === employeeId.value)?.nama || '')
</script>
<template>
  <div>
    <BilahTab class="mb-4" :tab="TAB" :model-value="aktif" label="Bagian jadwal pelajaran" @update:model-value="(k) => router.replace(`/jadwal-pelajaran/${k}`)" />

    <template v-if="aktif === 'kelas' || aktif === 'guru'">
      <div class="kartu mb-4 flex flex-wrap items-end gap-3 p-4">
        <div v-if="aktif === 'kelas'" class="min-w-[200px] flex-1"><label class="label-isian" for="jp-kelas">Kelas</label>
          <select id="jp-kelas" v-model="groupId" class="isian"><option v-for="x in kelasList" :key="x.id" :value="x.id">{{ judulKelompok(x) }}{{ x.asuhan_saya ? ' (kelas saya)' : '' }}</option>
            <option v-if="!kelasList.length" value="">Belum ada kelas di Kelompok Santri</option></select></div>
        <div v-else class="min-w-[200px] flex-1"><label class="label-isian" for="jp-guru">Guru</label>
          <select id="jp-guru" v-model="employeeId" class="isian"><option v-for="x in guruList" :key="x.id" :value="x.id">{{ x.nama }}{{ x.id === jd.idSaya() ? ' (saya)' : '' }}</option>
            <option v-if="!guruList.length" value="">Belum ada penugasan mengajar</option></select></div>
        <button class="tombol-garis" @click="cetak"><PhEye :size="20" weight="duotone" /> Cetak jadwal</button>
      </div>
      <section class="kartu w-jadwal p-4">
        <GridJadwal v-if="aktif === 'kelas' && g" mode="kelas" :group-id="groupId" :jenjang="g.jenjang" :boleh-ubah="bolehAtur" @sel="bukaSel" />
        <GridJadwal v-else-if="aktif === 'guru' && employeeId" mode="guru" :employee-id="employeeId" />
        <p v-else class="py-8 text-center text-sm text-teks3">Pilih kelas atau guru.</p>
        <p v-if="aktif === 'kelas' && bolehAtur" class="mt-3 text-xs text-teks3">Ketuk jam untuk mengisi pelajaran dari penugasan kelas ini. Bentrok kelas dan bentrok guru ditolak otomatis. Jumat memakai jam pelajaran Jumat.</p>
      </section>
      <section v-if="aktif === 'kelas' && penugasanKelas.length" class="kartu mt-4 p-4">
        <p class="mb-2 font-bold">Kecukupan jam per mapel</p>
        <ul class="grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
          <li v-for="t in penugasanKelas" :key="t.id" :class="['flex items-center gap-2 rounded-xl bg-permukaan2 px-3 py-2 text-sm', terjadwal(t.id) < t.jp_pekan ? 'w-klinik' : 'w-presensi']">
            <span class="min-w-0 flex-1"><b>{{ jd.cariMapel(t.subject_id)?.nama }}</b><span class="block truncate text-xs text-teks3">{{ t.nama_guru }}</span></span>
            <span class="font-bold tabular-nums" style="color: var(--c)">{{ terjadwal(t.id) }}/{{ t.jp_pekan }} JP</span></li>
        </ul>
      </section>
    </template>

    <TabPenugasan v-else-if="aktif === 'penugasan'" :boleh-atur="bolehAtur" />
    <TabPengaturanJadwal v-else-if="aktif === 'pengaturan'" />
    <TabRekapMengajar v-else />

    <LembarBawah v-model="lembar" :judul="sel ? `${HARI[sel.hari]}, ${sel.period.nama} (${jamPendek(sel.period.jam_mulai)}–${jamPendek(sel.period.jam_selesai)})` : ''">
      <div class="space-y-2 pb-2">
        <button v-for="t in penugasanKelas" :key="t.id" type="button" :disabled="proses" @click="pilihPenugasan(t.id)"
          :class="['flex min-h-[52px] w-full items-center gap-3 rounded-xl border px-3 text-left', sel?.sesi?.assignment_id === t.id ? 'border-[#1E7D4F] bg-[#1E7D4F]/10' : 'border-garis hover:bg-permukaan2']">
          <span class="min-w-0 flex-1"><b class="block">{{ jd.cariMapel(t.subject_id)?.nama }}</b><span class="block truncate text-xs text-teks3">{{ t.nama_guru }} · {{ terjadwal(t.id) }}/{{ t.jp_pekan }} JP</span></span></button>
        <p v-if="!penugasanKelas.length" class="rounded-xl bg-permukaan2 p-3 text-sm text-teks2">Belum ada penugasan mengajar untuk kelas ini. Tambahkan di tab Penugasan.</p>
        <button v-if="sel?.sesi" class="tombol-garis w-full" :disabled="proses" @click="pilihPenugasan(null)"><PhTrash :size="18" /> Kosongkan jam ini</button>
      </div>
    </LembarBawah>

    <DokumenCetak :kop="aktif === 'kelas' && g ? g.jenjang : 'pondok'" :judul="aktif === 'kelas' ? `Jadwal Pelajaran ${judulKelompok(g || {})}` : `Jadwal Mengajar ${namaGuru}`"
      :subjudul="`Tahun Ajaran ${kel.taSekarang?.nama || ''} · keadaan ${formatPanjang(hariIniISO())}`" mendatar v-model:pratinjau="pratinjau" :pencetak="sesi.pengguna?.nama_lengkap">
      <table class="tabel kecil">
        <thead><tr><th v-for="h in HARI_SEKOLAH" :key="h">{{ HARI[h] }}</th></tr></thead>
        <tbody><tr v-for="(b, i) in barisCetak" :key="i"><td v-for="(c, k) in b" :key="k" :class="c.istirahat && 'tengah'">{{ c.teks }}<template v-if="c.isi"><br />{{ c.isi }}</template></td></tr></tbody>
      </table>
      <template #ttd>
        <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: penanda.jabatan, nama: penanda.nama, niy: penanda.niy }"
          :kanan="aktif === 'kelas' ? { jabatan: 'Wali kelas', nama: (g?.pengasuh || []).find((p) => p.peran === 'utama')?.nama || '' } : { jabatan: 'Guru', nama: namaGuru }" />
      </template>
    </DokumenCetak>
  </div>
</template>
