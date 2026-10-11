<!-- SIMKA PRO | src/pages/verval/VervalPresensi.vue | v1.2 | Fase 3 – Tab Data presensi dipindah ke menu Data Presensi | 12/10/2026 -->
<script setup>
// Verval Presensi (admin ber-izin verval_presensi dan superadmin):
//   Antrian verval (luar area, pulang luar area, izin sesi) → keputusan final beralasan
//   Koreksi bertingkat (admin mengajukan → superadmin memutuskan)
//   Panel kecurigaan (koordinat identik, akurasi tidak wajar, perangkat bersama, selfie identik)
//   v1.2: data presensi per pegawai dipindah ke menu tersendiri (Presensi → Data Presensi).
//   v1.1: setelah verval, admin dapat mengabari pegawai lewat WA; tombol WA di setiap antrian.
import { ref, computed, onMounted, nextTick } from 'vue'
import { useRouter } from 'vue-router'
import { PhTray, PhListChecks, PhWarningOctagon, PhMapPin, PhArrowSquareOut, PhCheck, PhX, PhInfo, PhArrowClockwise } from '@phosphor-icons/vue'
import { useVerval } from '@/stores/verval'
import { usePegawai } from '@/stores/pegawai'
import { useAturPresensi } from '@/stores/aturPresensi'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { formatHari, formatPendek, formatJam, formatRelatif, formatWaktu } from '@/lib/tanggal'
import { STATUS_PRESENSI, STATUS_PULANG, formatJarak } from '@/lib/presensi'
import FotoBerkas from '@/components/FotoBerkas.vue'
import LembarBawah from '@/components/LembarBawah.vue'
import LembarKeputusan from './LembarKeputusan.vue'
import TombolWA from '@/components/TombolWA.vue'
import { pesanWA, halamanAplikasi } from '@/lib/wa'

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
]
const aktif = computed(() => TAB.find((t) => t.k === props.tab) || TAB[0])

const P = (k) => ({ k, n: STATUS_PRESENSI[k].n, w: STATUS_PRESENSI[k].w })
const PILIH_DATANG = ['hadir', 'terlambat', 'dinas_luar', 'izin', 'sakit', 'tanpa_keterangan'].map(P)
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
    aksi: async ({ status, alasan }) => {
      await vv.verval(a.id, a.bagian, status, alasan)
      const p = peg.cari(a.employee_id)
      waSetelah.value = { nama: a.nama, hp: p?.no_hp, pesan: pesanWA('verval_presensi', { nama: a.nama, sesi: a.nama_sesi, tanggal: formatHari(a.tanggal),
        status_presensi: (datang ? STATUS_PRESENSI[status] : STATUS_PULANG[status])?.n || status, catatan_verval: alasan, unit: p?.nama_unit }) }
    } })
}
const waSetelah = ref(null)
const hpPegawai = (id) => peg.cari(id)?.no_hp
const pesanTanya = (a) => pesanWA('umum', { nama: a.nama, pesan: `Mohon konfirmasi presensi Anda pada sesi ${a.nama_sesi}, ${formatHari(a.tanggal)} (${usulan(a).toLowerCase()}). Silakan balas pesan ini atau buka ${halamanAplikasi('/presensi')}.` })
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
              <div class="mt-2 flex flex-wrap gap-2">
                <button class="tombol-utama min-h-[40px] px-4 text-sm" @click="vervalA(a)"><PhCheck :size="18" weight="bold" /> Verval</button>
                <TombolWA kecil :hp="hpPegawai(a.employee_id)" label="Tanya via WA" :pesan="pesanTanya(a)" />
              </div>
            </div>
          </li>
        </ul>
      </template>

      <!-- ===== Koreksi ===== -->
      <template v-else-if="aktif.k === 'koreksi'">
        <p class="mb-3 flex gap-2 text-sm text-teks3"><PhInfo :size="18" class="mt-0.5 shrink-0" /> <span>Ajukan koreksi dari menu <router-link to="/data-presensi" class="font-semibold underline">Data Presensi</router-link>. Koreksi berlaku setelah disetujui superadmin.</span></p>
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
      <template v-else>
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

    </section>

    <LembarKeputusan v-model="lk.buka" :judul="lk.judul" :ringkasan="lk.ringkasan" :pilihan="lk.pilihan || []" :pilihan-pulang="lk.pilihanPulang || null"
      :bawaan="lk.bawaan" :catatan="lk.catatan" :label-tombol="lk.labelTombol" :bahaya="lk.bahaya" :contoh-alasan="lk.contohAlasan" @kirim="kirimKeputusan" />

    <LembarBawah :model-value="!!waSetelah" @update:model-value="(v) => !v && (waSetelah = null)" judul="Kabari pegawai lewat WA">
      <div v-if="waSetelah" class="space-y-3 pb-2">
        <p class="text-sm text-teks2">Verval tersimpan dan {{ waSetelah.nama }} sudah mendapat notifikasi di aplikasi. Bila perlu, kabari juga lewat WA:</p>
        <p class="whitespace-pre-line rounded-xl bg-permukaan2 p-3 text-sm">{{ waSetelah.pesan }}</p>
        <div class="flex gap-2"><TombolWA :hp="waSetelah.hp" label="Kirim WA" :pesan="waSetelah.pesan" /><button class="tombol-garis" @click="waSetelah = null">Tidak perlu</button></div>
      </div>
    </LembarBawah>
  </div>
</template>
<style scoped>
.tab.aktif { border-color: color-mix(in srgb, var(--c) 35%, transparent); background: color-mix(in srgb, var(--c) 12%, rgb(var(--permukaan))); }
</style>
