<!-- SIMKA PRO | src/pages/verval/VervalPresensi.vue | v1.0 | Fase 2 – Tahap 6 Verval dan koreksi | 03/10/2026 -->
<script setup>
// Verval Presensi (admin ber-izin verval_presensi dan superadmin):
//   Antrian verval (luar area, pulang luar area, izin sesi) → keputusan final beralasan
//   Koreksi bertingkat (admin mengajukan → superadmin memutuskan)
//   Panel kecurigaan (koordinat identik, akurasi tidak wajar, perangkat bersama, selfie identik)
//   Data presensi per pegawai per tanggal + riwayat status; superadmin dapat mengubah langsung / catat manual.
import { ref, computed, onMounted, nextTick, watch } from 'vue'
import { useRouter } from 'vue-router'
import { PhTray, PhListChecks, PhWarningOctagon, PhMagnifyingGlass, PhMapPin, PhArrowSquareOut, PhClockCounterClockwise, PhPencilSimple, PhPlus, PhCheck, PhX, PhInfo, PhArrowClockwise } from '@phosphor-icons/vue'
import { useVerval } from '@/stores/verval'
import { usePegawai } from '@/stores/pegawai'
import { useAturPresensi } from '@/stores/aturPresensi'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { formatHari, formatPendek, formatJam, formatRelatif, formatWaktu, hariIniISO } from '@/lib/tanggal'
import { STATUS_PRESENSI, STATUS_PULANG, formatJarak, lencanaSesi } from '@/lib/presensi'
import FotoBerkas from '@/components/FotoBerkas.vue'
import LembarBawah from '@/components/LembarBawah.vue'
import InputTanggal from '@/components/InputTanggal.vue'
import LembarKeputusan from './LembarKeputusan.vue'

const props = defineProps({ tab: { type: String, default: 'antrian' } })
const router = useRouter(); const vv = useVerval(); const peg = usePegawai(); const atur = useAturPresensi(); const sesi = useSesi(); const ui = useUI()
const galat = ref('')
onMounted(async () => {
  try { await Promise.all([atur.muat(), peg.daftar.length ? null : peg.muat()]); if (boleh.value) await vv.muat() } catch (e) { galat.value = e.message }
  await nextTick(); document.querySelector('[role=tab][aria-selected=true]')?.scrollIntoView({ inline: 'center', block: 'nearest' })
})
const boleh = computed(() => atur.boleh('verval_presensi'))
const TAB = [
  { k: 'antrian', n: 'Antrian verval', ikon: PhTray, w: 'pengajuan' },
  { k: 'koreksi', n: 'Koreksi', ikon: PhListChecks, w: 'verifikasi' },
  { k: 'kecurigaan', n: 'Kecurigaan', ikon: PhWarningOctagon, w: 'klinik' },
  { k: 'data', n: 'Data presensi', ikon: PhMagnifyingGlass, w: 'pegawai' },
]
const aktif = computed(() => TAB.find((t) => t.k === props.tab) || TAB[0])

const P = (k) => ({ k, n: STATUS_PRESENSI[k].n, w: STATUS_PRESENSI[k].w })
const PILIH_DATANG = ['hadir', 'terlambat', 'dinas_luar', 'izin', 'sakit', 'tanpa_keterangan'].map(P)
const PILIH_SEMUA = ['hadir', 'terlambat', 'dinas_luar', 'izin', 'sakit', 'cuti', 'tanpa_keterangan'].map(P)
const PILIH_PULANG = ['tepat', 'cepat', 'tidak_presensi'].map((k) => ({ k, n: STATUS_PULANG[k].n, w: STATUS_PULANG[k].w }))
const JENIS_CURIGA = {
  koordinat_identik: { n: 'Koordinat sama persis', ket: (r) => `Sama dengan ${r.jumlah_sebelumnya} presensi sebelumnya (30 hari).` },
  akurasi_tidak_wajar: { n: 'Akurasi GPS tidak wajar', ket: (r) => `Akurasi ${r.akurasi_m ?? 'tidak dilaporkan'} m (batas ${r.batas_m ?? 100} m).` },
  perangkat_bersama: { n: 'Satu perangkat banyak akun', ket: (r) => `Perangkat yang sama juga dipakai ${(r.pegawai_lain || []).join(', ')}.` },
  selfie_identik: { n: 'Selfie identik', ket: () => 'Berkas foto sama persis dengan foto presensi sebelumnya.' },
}
const usulan = (a) => a.sumber === 'izin_sesi' ? `Izin sesi – ${STATUS_PRESENSI[a.usulan_status]?.n || 'Izin'}` : a.bagian === 'pulang' ? 'Pulang di luar area' : `Di luar area – usulan ${STATUS_PRESENSI[a.usulan_status]?.n || 'Hadir'}`
const peta = (ev) => `https://www.google.com/maps?q=${ev.lat},${ev.lng}`

// ---------- Lembar keputusan (satu untuk semua aksi) ----------
const lk = ref({ buka: false })
function bukaLembar(o) { lk.value = { buka: true, ...o } }
async function kirimKeputusan(isi, res, rej) {
  try { await lk.value.aksi(isi); ui.toast(lk.value.pesan || 'Tersimpan.'); res() } catch (e) { rej(e) }
}
function vervalA(a) {
  const datang = a.bagian === 'datang'
  bukaLembar({ judul: datang ? 'Verval presensi' : 'Verval presensi pulang', ringkasan: `${a.nama} · ${a.nama_sesi} ${formatPendek(a.tanggal)} · ${usulan(a)}`,
    pilihan: datang ? PILIH_DATANG : PILIH_PULANG, bawaan: datang ? (a.usulan_status === 'izin' || a.usulan_status === 'sakit' ? a.usulan_status : a.terlambat_menit ? 'terlambat' : 'dinas_luar') : (a.cepat_pulang_menit ? 'cepat' : 'tepat'),
    catatan: 'Hasil verval bersifat final. Perubahan berikutnya melalui permintaan koreksi yang disetujui superadmin.', labelTombol: 'Simpan verval', pesan: 'Verval tersimpan. Pegawai mendapat notifikasi.',
    aksi: ({ status, alasan }) => vv.verval(a.id, a.bagian, status, alasan) })
}
function putuskanK(k, setuju) {
  if (setuju) return ui.konfirmasi({ judul: 'Setujui koreksi?', pesan: `${k.nama} · ${k.nama_sesi} ${formatPendek(k.tanggal)}: ${STATUS_PRESENSI[k.status_lama]?.n} → ${STATUS_PRESENSI[k.status_baru]?.n}.`, ya: 'Setujui' })
    .then((ya) => ya && vv.putuskanKoreksi(k.id, true, null).then(() => ui.toast('Koreksi disetujui.')).catch((e) => ui.toast(e.message, 'galat')))
  bukaLembar({ judul: 'Tolak koreksi', ringkasan: `${k.nama} · ${k.nama_sesi} ${formatPendek(k.tanggal)}`, pilihan: [], labelTombol: 'Tolak koreksi', bahaya: true,
    contohAlasan: 'Contoh: bukti kehadiran tidak cukup', pesan: 'Koreksi ditolak.', aksi: ({ alasan }) => vv.putuskanKoreksi(k.id, false, alasan) })
}
function tinjauC(c, status) {
  bukaLembar({ judul: status === 'wajar' ? 'Tandai wajar' : 'Tandai pelanggaran', ringkasan: `${c.nama} · ${JENIS_CURIGA[c.jenis]?.n}`, pilihan: [],
    labelTombol: status === 'wajar' ? 'Tandai wajar' : 'Tandai pelanggaran', contohAlasan: status === 'wajar' ? 'Contoh: HP dipinjam karena baterai habis' : 'Contoh: titip presensi, akan dipanggil kepala bidang',
    pesan: 'Tinjauan tersimpan.', aksi: ({ alasan }) => vv.tinjau(c.id, status, alasan) })
}

// ---------- Data presensi per pegawai ----------
const cari = ref(''); const empId = ref(''); const tgl = ref(hariIniISO()); const harian = ref(null); const memuatH = ref(false)
const daftarPeg = computed(() => {
  const q = cari.value.toLowerCase().trim()
  return peg.daftar.filter((p) => p.status_akun === 'aktif' && (!q || [p.nama_lengkap, p.niy].join(' ').toLowerCase().includes(q))).slice(0, 30)
})
const pegDipilih = computed(() => peg.cari(empId.value))
async function muatH() {
  if (!empId.value) return
  memuatH.value = true
  try { harian.value = await vv.harianPegawai(empId.value, tgl.value) } catch (e) { ui.toast(e.message, 'galat') } finally { memuatH.value = false }
}
watch([empId, tgl], muatH)
function koreksiS(s) {
  bukaLembar({ judul: 'Ajukan koreksi', ringkasan: `${pegDipilih.value?.nama_lengkap} · ${s.nama_sesi} ${formatPendek(s.tanggal)} · sekarang ${lencanaSesi(s).n}`,
    pilihan: PILIH_SEMUA, bawaan: s.status, pilihanPulang: s.wajib_pulang ? PILIH_PULANG : null, labelTombol: 'Kirim ke superadmin',
    catatan: 'Koreksi berlaku setelah disetujui superadmin.', pesan: 'Permintaan koreksi terkirim ke superadmin.',
    aksi: async ({ status, pulang, alasan }) => { await vv.ajukanKoreksi(s.attendance_id, status, pulang, alasan); await muatH() } })
}
function ubahS(s) {
  bukaLembar({ judul: 'Ubah langsung (superadmin)', ringkasan: `${pegDipilih.value?.nama_lengkap} · ${s.nama_sesi} ${formatPendek(s.tanggal)} · sekarang ${lencanaSesi(s).n}`,
    pilihan: PILIH_SEMUA, bawaan: s.status, pilihanPulang: s.wajib_pulang ? PILIH_PULANG : null, labelTombol: 'Simpan perubahan', pesan: 'Presensi diubah dan tercatat di riwayat.',
    aksi: async ({ status, pulang, alasan }) => { await vv.ubah(s.attendance_id, status, pulang, alasan); await muatH() } })
}
function manualS(s) {
  bukaLembar({ judul: 'Catat manual (superadmin)', ringkasan: `${pegDipilih.value?.nama_lengkap} · ${s.nama_sesi} ${formatPendek(s.tanggal)} · belum ada data`,
    pilihan: PILIH_SEMUA, bawaan: 'hadir', labelTombol: 'Catat presensi', pesan: 'Presensi dicatat manual.',
    aksi: async ({ status, alasan }) => { await vv.catatManual(empId.value, s.tanggal, s.session_id, status, alasan); await muatH() } })
}
const riwayat = ref(null)
async function lihatRiwayat(s) {
  try { riwayat.value = { s, isi: await vv.riwayat(s.attendance_id) } } catch (e) { ui.toast(e.message, 'galat') }
}
const JENIS_RIWAYAT = { presensi: 'Presensi', penutupan: 'Penutupan otomatis', verval: 'Verval admin', koreksi: 'Koreksi disetujui', superadmin: 'Diubah superadmin', pengajuan: 'Pengajuan pegawai', sistem: 'Sistem' }
</script>
<template>
  <div class="w-verval">
    <nav class="-mx-4 mb-4 flex gap-2 overflow-x-auto px-4 pb-1 lg:mx-0 lg:px-0" role="tablist" aria-label="Bagian verval presensi">
      <button v-for="t in TAB" :key="t.k" role="tab" :aria-selected="aktif.k === t.k" @click="router.replace(`/verval-presensi/${t.k}`)"
        :class="['tab flex min-h-[44px] shrink-0 items-center gap-2.5 rounded-xl border px-3 text-sm font-semibold', 'w-' + t.w, aktif.k === t.k ? 'aktif text-teks' : 'border-garis bg-permukaan text-teks2 hover:text-teks']">
        <span class="chip-ikon h-8 w-8 rounded-lg"><component :is="t.ikon" :size="20" weight="duotone" /></span><span class="whitespace-nowrap">{{ t.n }}</span>
        <span v-if="vv.jumlah[t.k === 'kecurigaan' ? 'curiga' : t.k]" class="grid h-6 min-w-[1.5rem] place-items-center rounded-full bg-[#C7332F] px-1.5 text-xs font-bold text-white">{{ vv.jumlah[t.k === 'kecurigaan' ? 'curiga' : t.k] }}</span>
      </button>
    </nav>

    <p v-if="galat" class="rounded-xl bg-[#C7332F]/10 p-3 text-sm font-semibold text-merah">{{ galat }} Pastikan migrasi SQL 1700 sudah dijalankan.</p>
    <div v-else-if="atur.dimuat && !boleh" class="flex gap-2 rounded-xl bg-permukaan2 p-4 text-sm text-teks2"><PhInfo :size="20" class="shrink-0" />
      Menu ini memerlukan izin "Verval presensi di luar area dan permintaan koreksi" dari superadmin (Verifikasi Akun → peran admin).</div>
    <p v-else-if="!vv.dimuat" class="py-10 text-center text-teks3">Memuat data verval…</p>

    <section v-else :class="'w-' + aktif.w" role="tabpanel" :aria-label="aktif.n">
      <div class="mb-3 flex justify-end"><button class="tombol-garis min-h-[40px] text-sm" :disabled="vv.memuat" @click="vv.muat()"><PhArrowClockwise :size="18" /> Muat ulang</button></div>

      <!-- ===== Antrian verval ===== -->
      <template v-if="aktif.k === 'antrian'">
        <div v-if="!vv.panel.antrian.length" class="flex flex-col items-center py-12 text-center">
          <span class="chip-ikon h-14 w-14 rounded-2xl"><PhCheck :size="30" weight="bold" /></span>
          <p class="mt-2 font-bold">Antrian kosong</p><p class="text-sm text-teks3">Tidak ada presensi yang menunggu verval.</p>
        </div>
        <ul class="grid gap-3 xl:grid-cols-2">
          <li v-for="a in vv.panel.antrian" :key="a.id + a.bagian" class="kartu flex gap-3 p-4">
            <FotoBerkas v-if="a.ev" :id="a.ev.selfie_id" :alt="`Selfie ${a.nama}`" />
            <div class="min-w-0 flex-1">
              <p class="font-bold">{{ a.nama }}</p>
              <p class="text-sm text-teks2">{{ a.nama_sesi }} · {{ a.nama_pola }} · {{ formatHari(a.tanggal) }}</p>
              <div class="mt-1 flex flex-wrap gap-1">
                <span class="lencana">{{ usulan(a) }}</span>
                <span v-if="a.terlambat_menit && a.bagian === 'datang'" class="lencana w-tahfizh">Terlambat {{ a.terlambat_menit }} menit</span>
                <span v-if="a.cepat_pulang_menit && a.bagian === 'pulang'" class="lencana w-tahfizh">Cepat {{ a.cepat_pulang_menit }} menit</span>
                <span v-for="c in a.curiga" :key="c" class="lencana w-klinik">{{ JENIS_CURIGA[c]?.n }}</span>
              </div>
              <p v-if="a.ev?.alasan || a.keterangan" class="mt-1.5 text-sm">“{{ a.ev?.alasan || a.keterangan?.replace(/^Izin sesi:\s*/, '') }}”</p>
              <p v-if="a.ev" class="mt-1 flex flex-wrap items-center gap-x-2 text-xs text-teks3">
                <span>{{ formatJam(a.ev.waktu) }} WITA</span><span>· {{ formatJarak(a.ev.jarak_m ?? 0) }} dari {{ a.ev.titik || 'titik' }}</span><span>· akurasi ±{{ Math.round(a.ev.akurasi_m ?? 0) }} m</span>
                <a :href="peta(a.ev)" target="_blank" rel="noopener" class="inline-flex items-center gap-0.5 font-semibold text-merah"><PhMapPin :size="14" /> Lihat peta <PhArrowSquareOut :size="12" /></a>
              </p>
              <p v-else class="mt-1 text-xs text-teks3">Diajukan {{ formatRelatif(a.dibuat) }}</p>
              <button class="tombol-utama mt-2 min-h-[40px] px-4 text-sm" @click="vervalA(a)"><PhCheck :size="18" weight="bold" /> Verval</button>
            </div>
          </li>
        </ul>
      </template>

      <!-- ===== Koreksi ===== -->
      <template v-else-if="aktif.k === 'koreksi'">
        <p class="mb-3 flex gap-2 text-sm text-teks3"><PhInfo :size="18" class="mt-0.5 shrink-0" /> Ajukan koreksi dari tab Data presensi. Koreksi berlaku setelah disetujui superadmin.</p>
        <p v-if="!vv.panel.koreksi.length" class="py-10 text-center text-teks3">Belum ada permintaan koreksi.</p>
        <ul class="space-y-2">
          <li v-for="k in vv.panel.koreksi" :key="k.id" class="kartu p-4">
            <div class="flex flex-wrap items-center gap-2">
              <p class="flex-1 font-bold">{{ k.nama }}</p>
              <span :class="['lencana', k.status === 'menunggu' ? 'w-tahfizh' : k.status === 'disetujui' ? 'w-presensi' : 'w-klinik']">{{ { menunggu: 'Menunggu superadmin', disetujui: 'Disetujui', ditolak: 'Ditolak' }[k.status] }}</span>
            </div>
            <p class="text-sm text-teks2">{{ k.nama_sesi }} · {{ formatHari(k.tanggal) }}: <b>{{ STATUS_PRESENSI[k.status_lama]?.n }}</b> → <b>{{ STATUS_PRESENSI[k.status_baru]?.n }}</b><template v-if="k.pulang_baru">, {{ STATUS_PULANG[k.pulang_baru]?.n }}</template></p>
            <p class="mt-1 text-sm">“{{ k.alasan }}”</p>
            <p class="text-xs text-teks3">Diajukan {{ k.pengaju }} · {{ formatRelatif(k.dibuat) }}<template v-if="k.catatan"> · Catatan: {{ k.catatan }}</template></p>
            <div v-if="k.status === 'menunggu' && sesi.isSuperadmin" class="mt-2 flex gap-2">
              <button class="tombol-utama min-h-[40px] px-4 text-sm" @click="putuskanK(k, true)"><PhCheck :size="18" weight="bold" /> Setujui</button>
              <button class="tombol-garis min-h-[40px] px-4 text-sm" @click="putuskanK(k, false)"><PhX :size="18" /> Tolak</button>
            </div>
          </li>
        </ul>
      </template>

      <!-- ===== Kecurigaan ===== -->
      <template v-else-if="aktif.k === 'kecurigaan'">
        <p v-if="!vv.panel.curiga.length" class="py-10 text-center text-teks3">Tidak ada penanda kecurigaan.</p>
        <ul class="grid gap-3 xl:grid-cols-2">
          <li v-for="c in vv.panel.curiga" :key="c.id" class="kartu flex gap-3 p-4">
            <FotoBerkas v-if="c.ev" :id="c.ev.selfie_id" :alt="`Selfie ${c.nama}`" />
            <div class="min-w-0 flex-1">
              <div class="flex flex-wrap items-center gap-2">
                <p class="flex-1 font-bold">{{ c.nama }}</p>
                <span :class="['lencana', c.status === 'baru' ? 'w-klinik' : c.status === 'wajar' ? 'w-presensi' : 'w-beranda']">{{ { baru: 'Perlu ditinjau', wajar: 'Wajar', pelanggaran: 'Pelanggaran' }[c.status] }}</span>
              </div>
              <p class="text-sm font-semibold" style="color: var(--c)">{{ JENIS_CURIGA[c.jenis]?.n }}</p>
              <p class="text-sm text-teks2">{{ JENIS_CURIGA[c.jenis]?.ket(c.rincian || {}) }}</p>
              <p v-if="c.ev" class="text-xs text-teks3">{{ formatWaktu(c.ev.waktu) }} WITA · {{ c.ev.di_area ? 'di area' : 'luar area' }} {{ c.ev.titik }} ({{ formatJarak(c.ev.jarak_m ?? 0) }})</p>
              <p v-if="c.catatan" class="text-xs text-teks3">Catatan: {{ c.catatan }}</p>
              <div v-if="c.status === 'baru'" class="mt-2 flex gap-2">
                <button class="tombol-garis min-h-[40px] px-4 text-sm" @click="tinjauC(c, 'wajar')">Wajar</button>
                <button class="tombol-utama min-h-[40px] px-4 text-sm" @click="tinjauC(c, 'pelanggaran')">Pelanggaran</button>
              </div>
            </div>
          </li>
        </ul>
      </template>

      <!-- ===== Data presensi ===== -->
      <template v-else>
        <div class="grid gap-4 lg:grid-cols-[22rem_1fr]">
          <div class="kartu p-3">
            <div class="relative"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-teks3" />
              <input v-model="cari" class="isian pl-10" placeholder="Cari nama atau NIY" aria-label="Cari pegawai" /></div>
            <ul class="mt-2 max-h-[50vh] overflow-y-auto">
              <li v-for="p in daftarPeg" :key="p.id">
                <button :class="['w-full rounded-xl px-3 py-2 text-left text-sm', empId === p.id ? 'bg-[color-mix(in_srgb,var(--c)_14%,transparent)] font-bold' : 'hover:bg-permukaan2']" @click="empId = p.id">
                  {{ p.nama_lengkap }}<span class="block text-xs font-normal text-teks3">{{ [p.jabatan_struktural, ...(p.jabatan_fungsional || [])].filter(Boolean).join(', ') }}</span></button>
              </li>
            </ul>
          </div>
          <div class="kartu p-4">
            <div class="max-w-xs"><InputTanggal v-model="tgl" label="Tanggal" /></div>
            <p v-if="!empId" class="py-8 text-center text-teks3">Pilih pegawai untuk melihat presensinya.</p>
            <p v-else-if="memuatH" class="py-8 text-center text-teks3">Memuat…</p>
            <template v-else-if="harian">
              <p class="mt-3 font-bold">{{ pegDipilih?.nama_lengkap }} · {{ formatHari(tgl) }}</p>
              <p v-if="!harian.sesi.length" class="py-6 text-center text-teks3">Tidak ada sesi pada tanggal ini.</p>
              <ul class="mt-2 space-y-2">
                <li v-for="s in harian.sesi" :key="s.session_id + s.tanggal" :class="['rounded-2xl border border-garis p-3', 'w-' + lencanaSesi(s).w]">
                  <div class="flex flex-wrap items-center gap-2">
                    <span class="w-24 font-bold tabular-nums">{{ formatJam(s.mulai) }}–{{ formatJam(s.selesai) }}</span>
                    <span class="flex-1 font-semibold">{{ s.nama_sesi }} <span class="text-xs font-normal text-teks3">· {{ s.nama_pola }}</span></span>
                    <span class="lencana">{{ lencanaSesi(s).n }}</span>
                    <span v-if="s.status_pulang && s.status_pulang !== 'belum'" :class="['lencana', 'w-' + STATUS_PULANG[s.status_pulang].w]">{{ STATUS_PULANG[s.status_pulang].n }}</span>
                  </div>
                  <p v-if="s.datang_pada || s.keterangan" class="mt-1 text-xs text-teks3">
                    <template v-if="s.datang_pada">Datang {{ formatJam(s.datang_pada) }}</template><template v-if="s.pulang_pada"> · Pulang {{ formatJam(s.pulang_pada) }}</template>
                    <template v-if="s.keterangan"> · {{ s.keterangan }}</template></p>
                  <div class="mt-1.5 flex flex-wrap gap-1">
                    <button v-if="s.attendance_id" class="tombol-teks min-h-[36px] px-2 text-sm" @click="lihatRiwayat(s)"><PhClockCounterClockwise :size="16" /> Riwayat</button>
                    <button v-if="s.attendance_id && s.status !== 'menunggu_verval' && !sesi.isSuperadmin" class="tombol-teks min-h-[36px] px-2 text-sm" @click="koreksiS(s)"><PhPencilSimple :size="16" /> Ajukan koreksi</button>
                    <button v-if="s.attendance_id && sesi.isSuperadmin" class="tombol-teks min-h-[36px] px-2 text-sm" @click="ubahS(s)"><PhPencilSimple :size="16" /> Ubah langsung</button>
                    <button v-if="!s.attendance_id && sesi.isSuperadmin" class="tombol-teks min-h-[36px] px-2 text-sm" @click="manualS(s)"><PhPlus :size="16" /> Catat manual</button>
                  </div>
                </li>
              </ul>
            </template>
          </div>
        </div>
      </template>
    </section>

    <LembarKeputusan v-model="lk.buka" :judul="lk.judul" :ringkasan="lk.ringkasan" :pilihan="lk.pilihan || []" :pilihan-pulang="lk.pilihanPulang || null"
      :bawaan="lk.bawaan" :catatan="lk.catatan" :label-tombol="lk.labelTombol" :bahaya="lk.bahaya" :contoh-alasan="lk.contohAlasan" @kirim="kirimKeputusan" />

    <LembarBawah :model-value="!!riwayat" @update:model-value="(v) => !v && (riwayat = null)" :judul="riwayat ? `Riwayat ${riwayat.s.nama_sesi}` : ''">
      <ol v-if="riwayat" class="relative space-y-3 border-l-2 border-garis pb-2 pl-4">
        <li v-for="(h, i) in riwayat.isi" :key="i">
          <p class="text-sm font-bold">{{ JENIS_RIWAYAT[h.jenis] || h.jenis }} · {{ formatWaktu(h.waktu) }}</p>
          <p class="text-sm text-teks2">{{ h.dari ? STATUS_PRESENSI[h.dari]?.n + ' → ' : '' }}{{ STATUS_PRESENSI[h.ke]?.n }}
            <template v-if="h.ke_pulang && h.ke_pulang !== h.dari_pulang"> · {{ STATUS_PULANG[h.ke_pulang]?.n }}</template></p>
          <p v-if="h.alasan" class="text-xs text-teks3">“{{ h.alasan }}”</p>
          <p v-if="h.oleh" class="text-xs text-teks3">Oleh {{ h.oleh }}</p>
        </li>
        <li v-if="!riwayat.isi.length" class="text-sm text-teks3">Belum ada riwayat.</li>
      </ol>
    </LembarBawah>
  </div>
</template>
<style scoped>
.tab.aktif { border-color: color-mix(in srgb, var(--c) 35%, transparent); background: color-mix(in srgb, var(--c) 12%, rgb(var(--permukaan))); }
</style>
