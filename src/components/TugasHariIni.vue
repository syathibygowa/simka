<!-- SIMKA PRO | src/components/TugasHariIni.vue | v1.0 | Perbaikan: akses cepat tupoksi (musyrif, muhaffizh, wali kelas, guru mapel, medis, security) | 14/10/2026 -->
<script setup>
// Panel "Tugas saya hari ini" di beranda: satu ketukan langsung ke pekerjaan tupoksi.
//   Musyrif/muhaffizh/wali kelas/pembina : setiap sesi absensi kelompok asuhan hari ini (status dan tombol langsung absen)
//   Guru mapel                           : jurnal mengajar hari ini (x/y pertemuan terisi) → isian jurnal sepekan
//   Medis                                : antrean klinik yang menunggu pemeriksaan
//   Security                             : santri di luar dan terlambat kembali → halaman gerbang
// Ditambah baris pintasan menu tupoksi. Data hanya dimuat untuk tupoksi yang dimiliki (hemat kuota).
import { ref, computed, onMounted } from 'vue'
import {
  PhClipboardText, PhChalkboardTeacher, PhFirstAidKit, PhShieldCheck, PhBookOpenText, PhBuildings, PhChalkboard, PhMedal, PhPresentationChart,
  PhCaretRight, PhCheckCircle, PhHourglass, PhWarningCircle, PhPlayCircle, PhUsersThree,
} from '@phosphor-icons/vue'
import { useSesi } from '@/stores/sesi'
import { useAbsensiSantri } from '@/stores/absensiSantri'
import { useJadwal } from '@/stores/jadwal'
import { useKlinik } from '@/stores/klinik'
import { useSecurity } from '@/stores/security'
import { hariIniISO, formatJam } from '@/lib/tanggal'

const sesi = useSesi(); const abs = useAbsensiSantri(); const jd = useJadwal(); const kl = useKlinik(); const sc = useSecurity()
const t = computed(() => sesi.tugas || {})
const fungsi = computed(() => new Set(t.value.fungsional || []))
const kel = computed(() => new Set([...(t.value.kelompok || []), ...sesi.kelompokSaya.map((k) => k.jenis)]))
const peran = computed(() => ({
  wali: kel.value.has('kelas'), muhaffizh: kel.value.has('halaqah'), musyrif: kel.value.has('kamar'), pembina: kel.value.has('ekskul'),
  guru: !!t.value.mengajar, medis: fungsi.value.has('MEDIS') || (t.value.klinik || []).length > 0, security: fungsi.value.has('SECURITY') || !!t.value.gerbang,
}))
const ada = computed(() => Object.values(peran.value).some(Boolean))
const LABEL = { wali: 'Wali kelas', muhaffizh: 'Muhaffizh', musyrif: 'Musyrif', pembina: 'Pembina ekskul', guru: 'Guru mapel', medis: 'Medis', security: 'Security' }

const hari = hariIniISO(); const sesiSaya = ref([]); const slot = ref([]); const antrean = ref(null); const memuat = ref(true)
onMounted(async () => {
  if (!ada.value) { memuat.value = false; return }
  const tugas = []
  if (peran.value.wali || peran.value.muhaffizh || peran.value.musyrif || peran.value.pembina) tugas.push(abs.muatSesi(hari, false).then(() => { sesiSaya.value = abs.sesiHari.filter((s) => s.asuhan_saya !== false) }))
  if (peran.value.guru) tugas.push(jd.slot(hari, hari, null, jd.idSaya()).then((x) => { slot.value = x }))
  if (peran.value.medis) tugas.push(kl.daftar('antrean').then((x) => { antrean.value = x.length }))
  if (peran.value.security) tugas.push(sc.muatBeranda())
  await Promise.allSettled(tugas); memuat.value = false
})

const IKON_JENIS = { kelas: PhChalkboard, halaqah: PhBookOpenText, asrama: PhBuildings, kamar: PhBuildings, ekskul: PhMedal }
const W_JENIS = { kelas: 'walikelas', halaqah: 'tahfizh', asrama: 'musyrif', kamar: 'musyrif', ekskul: 'ekskul' }
const ST = {
  terbuka: { n: 'Absen sekarang', w: 'presensi', i: PhPlayCircle }, belum_buka: { n: 'Belum dibuka', w: 'hakakses', i: PhHourglass },
  terisi: { n: 'Terisi', w: 'presensi', i: PhCheckCircle }, lewat: { n: 'Lewat, segera isi', w: 'pengajuan', i: PhWarningCircle }, tidak_terisi: { n: 'Tidak terisi', w: 'klinik', i: PhWarningCircle },
}
const item = computed(() => {
  const d = sesiSaya.value.map((s) => ({ k: `${s.group_id}-${s.sesi}`, ikon: IKON_JENIS[s.jenis] || PhUsersThree, w: W_JENIS[s.jenis] || 'santri',
    judul: `${s.nama_sesi} · ${s.nama_kelompok}`, sub: `${String(s.jam_mulai || '').slice(0, 5)}${s.status === 'belum_buka' && s.buka ? ` · dibuka ${formatJam(s.buka)}` : ''}${s.status === 'terisi' && s.jumlah_hadir != null ? ` · hadir ${s.jumlah_hadir}/${s.jumlah_anggota}` : ''}`,
    st: ST[s.status] || ST.belum_buka, ke: `/absensi-santri/isi/${s.group_id}/${s.tanggal}/${s.sesi}`, urut: s.status === 'terbuka' ? 0 : s.status === 'lewat' ? 1 : s.status === 'belum_buka' ? 2 : 3 }))
  if (peran.value.guru) {
    const n = slot.value.length; const isi = slot.value.filter((x) => x.status !== 'belum').length; const lewat = slot.value.filter((x) => x.status === 'belum' && x.lewat).length
    d.push({ k: 'jurnal', ikon: PhChalkboardTeacher, w: 'jadwal', judul: 'Jurnal mengajar hari ini', sub: n ? `${isi}/${n} JP terisi · ${[...new Set(slot.value.map((x) => x.kelas))].join(', ')}` : 'Tidak ada jadwal mengajar hari ini',
      st: !n ? ST.terisi : lewat ? { ...ST.lewat, n: `${lewat} JP belum diisi` } : isi >= n ? ST.terisi : { ...ST.terbuka, n: 'Isi jurnal' }, ke: '/jurnal/mengajar', urut: lewat ? 1 : 2 })
  }
  if (peran.value.medis && antrean.value != null) d.push({ k: 'klinik', ikon: PhFirstAidKit, w: 'klinik', judul: 'Antrean klinik', sub: antrean.value ? `${antrean.value} santri menunggu pemeriksaan` : 'Tidak ada antrean',
    st: antrean.value ? { ...ST.lewat, n: `${antrean.value} menunggu` } : ST.terisi, ke: '/klinik/antrean', urut: antrean.value ? 0 : 3 })
  if (peran.value.security && sc.beranda) {
    const b = sc.beranda
    d.push({ k: 'gerbang', ikon: PhShieldCheck, w: 'security', judul: 'Gerbang', sub: `${b.di_luar ?? 0} santri di luar · ${b.titipan_di_pos ?? 0} titipan di pos`,
      st: b.terlambat ? { ...ST.tidak_terisi, n: `${b.terlambat} terlambat kembali` } : { ...ST.terisi, n: 'Aman' }, ke: '/security/gerbang', urut: b.terlambat ? 0 : 3 })
  }
  return d.sort((a, b) => a.urut - b.urut)
})
const pintasan = computed(() => [
  peran.value.wali && { n: 'Wali Kelas', ikon: PhChalkboard, w: 'walikelas', ke: '/wali-kelas' },
  peran.value.guru && { n: 'Guru Mapel', ikon: PhPresentationChart, w: 'gurumapel', ke: '/guru-mapel' },
  peran.value.muhaffizh && { n: 'Setoran Tahfizh', ikon: PhBookOpenText, w: 'tahfizh', ke: '/tahfizh/setoran' },
  peran.value.musyrif && { n: 'Musyrif', ikon: PhBuildings, w: 'musyrif', ke: '/musyrif' },
  peran.value.pembina && { n: 'Ekskul', ikon: PhMedal, w: 'ekskul', ke: '/ekskul' },
  peran.value.medis && { n: 'Klinik', ikon: PhFirstAidKit, w: 'klinik', ke: '/klinik' },
  peran.value.security && { n: 'Security', ikon: PhShieldCheck, w: 'security', ke: '/security' },
].filter(Boolean))
</script>
<template>
  <section v-if="ada" class="kartu p-4 sm:p-5" aria-labelledby="judul-tugas-hari-ini">
    <h2 id="judul-tugas-hari-ini" class="judul-bagian flex items-center gap-2"><PhClipboardText :size="20" weight="duotone" class="shrink-0 text-[rgb(var(--merah))]" /> Tugas saya hari ini</h2>
    <p class="mb-3 mt-0.5 text-xs text-teks3">{{ Object.keys(peran).filter((k) => peran[k]).map((k) => LABEL[k]).join(' · ') }}</p>
    <ul v-if="memuat" class="grid gap-2 sm:grid-cols-2" aria-hidden="true"><li v-for="i in 2" :key="i" class="h-16 animate-pulse rounded-2xl bg-permukaan2" /></ul>
    <ul v-else-if="item.length" class="grid gap-2 sm:grid-cols-2 xl:grid-cols-3">
      <li v-for="x in item" :key="x.k" :class="['min-w-0', 'w-' + x.w]">
        <router-link :to="x.ke" class="flex min-h-[64px] items-center gap-3 rounded-2xl border border-garis p-3 transition hover:bg-permukaan2 active:scale-[.99]">
          <span class="chip-ikon h-11 w-11 shrink-0"><component :is="x.ikon" :size="24" weight="duotone" /></span>
          <span class="min-w-0 flex-1"><b class="block truncate text-sm">{{ x.judul }}</b><span class="block truncate text-xs text-teks3">{{ x.sub }}</span>
            <span :class="['lencana mt-1', 'w-' + x.st.w]"><component :is="x.st.i" :size="13" weight="fill" /> {{ x.st.n }}</span></span>
          <PhCaretRight :size="18" class="shrink-0 text-teks3" />
        </router-link>
      </li>
    </ul>
    <p v-else class="rounded-xl bg-permukaan2 p-3 text-sm text-teks3">Tidak ada sesi tupoksi hari ini.</p>
    <div class="mt-3 flex flex-wrap gap-2">
      <router-link v-for="p in pintasan" :key="p.ke" :to="p.ke" :class="['tombol-garis min-h-[40px] px-3 text-sm', 'w-' + p.w]">
        <component :is="p.ikon" :size="18" weight="duotone" style="color: var(--c)" /> {{ p.n }}</router-link>
    </div>
  </section>
</template>
