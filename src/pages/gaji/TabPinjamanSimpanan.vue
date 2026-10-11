<!-- SIMKA PRO | src/pages/gaji/TabPinjamanSimpanan.vue | v1.0 | Fase 11 – Tahap 3 Pinjaman pegawai dan simpanan program | 11/10/2026 -->
<script setup>
// Pinjaman pegawai (cicilan otomatis dipotong setiap periode sampai lunas) dan simpanan program (umrah, kurban, dll.:
// dipotong tiap bulan, disimpan yayasan atas nama pegawai, dicairkan pada waktunya). Pengelola gaji mengubah;
// pembaca gaji hanya melihat. Pembayaran lewat gaji tercatat saat slip terbit; pembayaran di luar gaji dicatat di sini.
import { ref, computed, onMounted } from 'vue'
import * as XLSX from 'xlsx'
import { PhHandCoins, PhPiggyBank, PhPlus, PhPencilSimple, PhMoney, PhXCircle, PhFileXls, PhMagnifyingGlass, PhClockCounterClockwise, PhFloppyDisk,
  PhUserPlus, PhArrowsLeftRight, PhCaretDown } from '@phosphor-icons/vue'
import { useGaji } from '@/stores/gaji'
import { useUI } from '@/stores/ui'
import { formatPendek, hariIniISO, BULAN } from '@/lib/tanggal'
import { rupiah, bacaRupiah, terbilang } from '@/lib/gaji'
import BilahTab from '@/components/BilahTab.vue'
import KartuStatistik from '@/components/KartuStatistik.vue'
import LembarBawah from '@/components/LembarBawah.vue'
import InputTanggal from '@/components/InputTanggal.vue'

const gaji = useGaji(); const ui = useUI()
const boleh = computed(() => !!gaji.hak.kelola)
const bagian = ref('pinjaman')
const SUB = [{ k: 'pinjaman', n: 'Pinjaman', ikon: PhHandCoins, w: 'shift' }, { k: 'simpanan', n: 'Simpanan program', ikon: PhPiggyBank, w: 'berkas' }]
const pinjaman = ref([]); const program = ref([]); const memuat = ref(true); const proses = ref(false); const cari = ref('')
async function muat() {
  try { await gaji.muatPegawai(); [pinjaman.value, program.value] = await Promise.all([gaji.daftarPinjaman(), gaji.daftarSimpanan()]) }
  catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false }
}
onMounted(muat)
async function jalan(fn, pesan) {
  proses.value = true
  try { await fn(); ui.toast(pesan); await muat(); return true } catch (e) { ui.toast(e.message, 'galat'); return false } finally { proses.value = false }
}
const cocok = (x) => { const q = cari.value.toLowerCase().trim(); return !q || [x.nama, x.niy, x.keterangan].join(' ').toLowerCase().includes(q) }
const namaBulan = (iso) => (iso ? `${BULAN[Number(iso.slice(5, 7)) - 1]} ${iso.slice(0, 4)}` : '–')
const bulanIni = hariIniISO().slice(0, 8) + '01'
const pilihanBulan = computed(() => Array.from({ length: 15 }, (_, i) => {
  const d = new Date(Date.UTC(Number(bulanIni.slice(0, 4)), Number(bulanIni.slice(5, 7)) - 3 + i, 1)); return d.toISOString().slice(0, 10)
}))

// ---------- Pinjaman ----------
const STATUS_PJ = { aktif: { n: 'Berjalan', w: 'shift' }, lunas: { n: 'Lunas', w: 'presensi' }, batal: { n: 'Batal', w: 'hakakses' } }
const lihatSelesai = ref(false)
const pjTampil = computed(() => pinjaman.value.filter((x) => (lihatSelesai.value || x.status === 'aktif') && cocok(x)))
const pjRingkas = computed(() => { const a = pinjaman.value.filter((x) => x.status === 'aktif')
  return { n: a.length, sisa: a.reduce((s, x) => s + Number(x.sisa), 0), cicilan: a.reduce((s, x) => s + Math.min(Number(x.cicilan), Number(x.sisa)), 0) } })
const fPj = ref(null); const fBayar = ref(null); const riwayatPj = ref(null)
function bukaPj(x = null) {
  fPj.value = x ? { ...x, pokokT: String(Number(x.pokok)), cicilanT: String(Number(x.cicilan)) }
    : { employee_id: '', keterangan: '', pokokT: '', cicilanT: '', tanggal: hariIniISO(), mulai_potong: bulanIni, catatan: '' }
}
const lamaCicil = computed(() => { const p = bacaRupiah(fPj.value?.pokokT), c = bacaRupiah(fPj.value?.cicilanT); return p && c ? Math.ceil(p / c) : null })
async function simpanPj() {
  const x = fPj.value; const pokok = bacaRupiah(x.pokokT), cicilan = bacaRupiah(x.cicilanT)
  if (!x.employee_id) return ui.toast('Pilih pegawai.', 'galat')
  if (!pokok || !cicilan) return ui.toast('Isi nilai pinjaman dan cicilan.', 'galat')
  if (await jalan(() => gaji.simpanPinjaman({ id: x.id || null, employee_id: x.employee_id, keterangan: x.keterangan, pokok, cicilan, tanggal: x.tanggal, mulai_potong: x.mulai_potong, catatan: x.catatan }),
    'Pinjaman tersimpan. Cicilan masuk periode gaji yang dibuat atau dihitung ulang.')) fPj.value = null
}
async function bayar() {
  const n = bacaRupiah(fBayar.value.nilai)
  if (!n || n <= 0) return ui.toast('Isi nominal pembayaran.', 'galat')
  if (await jalan(() => gaji.bayarPinjaman(fBayar.value.x.id, n, fBayar.value.tanggal, fBayar.value.ket), 'Pembayaran pinjaman tercatat.')) fBayar.value = null
}
async function batalPj(x) {
  const alasan = await ui.konfirmasi({ judul: 'Tutup pinjaman?', pesan: `${x.nama}: sisa ${rupiah(x.sisa)}. Pinjaman tanpa pembayaran menjadi Batal; yang sudah dibayar sebagian ditutup. Cicilan tidak lagi dipotong.`, ya: 'Tutup pinjaman', bahaya: true })
  if (alasan) jalan(() => gaji.batalkanPinjaman(x.id, 'Ditutup oleh Bendahara'), 'Pinjaman ditutup.')
}

// ---------- Simpanan ----------
const bukaProg = ref({})
const fProg = ref(null); const fAng = ref(null); const fTx = ref(null); const riwayatAng = ref(null)
const totalSimpanan = computed(() => program.value.reduce((s, p) => s + Number(p.saldo), 0))
const pesertaAktif = computed(() => program.value.reduce((s, p) => s + p.anggota.filter((a) => a.aktif).length, 0))
const setoranBulan = computed(() => program.value.filter((p) => p.aktif).reduce((s, p) => s + p.anggota.filter((a) => a.aktif).reduce((x, a) => x + Number(a.setoran), 0), 0))
function bukaAng(p, a = null) {
  fAng.value = { program: p, employee_id: a?.employee_id || '', baru: !a, setoranT: String(Number(a?.setoran ?? p.setoran_bawaan ?? 0)), mulai: a?.mulai || bulanIni, aktif: a ? a.aktif : true, catatan: a?.catatan || '' }
}
async function simpanAng() {
  const x = fAng.value; const n = bacaRupiah(x.setoranT)
  if (!x.employee_id) return ui.toast('Pilih pegawai.', 'galat')
  if (n == null || n < 0) return ui.toast('Isi setoran per bulan.', 'galat')
  if (await jalan(() => gaji.simpanAnggota({ program_id: x.program.id, employee_id: x.employee_id, setoran: n, mulai: x.mulai, aktif: x.aktif, catatan: x.catatan }),
    'Keanggotaan simpanan tersimpan.')) fAng.value = null
}
const JENIS_TX = { setoran_awal: 'Setoran awal / saldo lama', pencairan: 'Pencairan', koreksi: 'Koreksi saldo' }
async function simpanTx() {
  const x = fTx.value; let n = bacaRupiah(x.nilai)
  if (!n) return ui.toast('Isi nominal.', 'galat')
  if (x.jenis !== 'koreksi') n = Math.abs(n)
  if (await jalan(() => gaji.catatTransaksi({ program_id: x.p.id, employee_id: x.a.employee_id, jenis: x.jenis, besaran: n, tanggal: x.tanggal, keterangan: x.ket }),
    `${JENIS_TX[x.jenis]} tercatat.`)) fTx.value = null
}
async function simpanProg() {
  if ((fProg.value.nama || '').trim().length < 3) return ui.toast('Isi nama program.', 'galat')
  if (await jalan(() => gaji.simpanProgram({ ...fProg.value, setoran_bawaan: bacaRupiah(fProg.value.setoranT) || 0 }), 'Program simpanan tersimpan.')) fProg.value = null
}

// ---------- Excel ----------
function ekspor() {
  const wb = XLSX.utils.book_new()
  const pj = [['NIY', 'Nama', 'Keterangan', 'Tanggal pinjam', 'Mulai dipotong', 'Pokok', 'Cicilan/bulan', 'Sudah dibayar', 'Sisa', 'Status'],
    ...pinjaman.value.map((x) => [x.niy || '', x.nama, x.keterangan || '', formatPendek(x.tanggal), namaBulan(x.mulai_potong), Number(x.pokok), Number(x.cicilan), Number(x.dibayar), Number(x.sisa), STATUS_PJ[x.status].n])]
  XLSX.utils.book_append_sheet(wb, XLSX.utils.aoa_to_sheet(pj), 'Pinjaman')
  const sm = [['Program', 'NIY', 'Nama', 'Setoran/bulan', 'Mulai', 'Status', 'Saldo']]
  for (const p of program.value) for (const a of p.anggota) sm.push([p.nama, a.niy || '', a.nama, Number(a.setoran), namaBulan(a.mulai), a.aktif ? 'Aktif' : 'Berhenti', Number(a.saldo)])
  XLSX.utils.book_append_sheet(wb, XLSX.utils.aoa_to_sheet(sm), 'Simpanan')
  XLSX.writeFile(wb, `Pinjaman-Simpanan-Pegawai-${formatPendek(hariIniISO()).replace(/\//g, '-')}.xlsx`)
}
</script>
<template>
  <div>
    <div class="mb-4 flex flex-wrap items-center gap-2">
      <BilahTab v-model="bagian" :tab="SUB" :tepi="false" label="Pinjaman atau simpanan" />
      <div class="relative min-w-[200px] flex-1"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
        <input v-model="cari" type="search" class="isian pl-11" placeholder="Cari nama atau NIY" aria-label="Cari" /></div>
      <button class="tombol-garis" @click="ekspor"><PhFileXls :size="20" weight="duotone" /> Ekspor Excel</button>
    </div>
    <p v-if="memuat" class="kartu p-8 text-center text-sm text-teks3">Memuat…</p>

    <!-- ================= PINJAMAN ================= -->
    <div v-else-if="bagian === 'pinjaman'">
      <div class="-mx-4 mb-4 flex snap-x gap-3 overflow-x-auto px-4 pb-1 sm:mx-0 sm:grid sm:grid-cols-3 sm:overflow-visible sm:px-0">
        <KartuStatistik class="w-[44%] shrink-0 snap-start sm:w-auto" judul="Pinjaman berjalan" :nilai="pjRingkas.n" :ikon="PhHandCoins" warna="shift" keterangan="Pegawai yang masih mencicil" />
        <KartuStatistik class="w-[72%] shrink-0 snap-start sm:w-auto" judul="Sisa pinjaman" :nilai="rupiah(pjRingkas.sisa)" :ikon="PhMoney" warna="klinik" keterangan="Belum dibayar" />
        <KartuStatistik class="w-[72%] shrink-0 snap-start sm:w-auto" judul="Cicilan per bulan" :nilai="rupiah(pjRingkas.cicilan)" :ikon="PhArrowsLeftRight" warna="presensi" keterangan="Dipotong dari gaji" />
      </div>
      <div class="mb-3 flex flex-wrap items-center gap-2">
        <label class="flex min-h-[44px] flex-1 items-center gap-2 text-sm font-semibold"><input type="checkbox" v-model="lihatSelesai" class="h-5 w-5 accent-[#C7332F]" /> Tampilkan yang lunas/batal</label>
        <button v-if="boleh" class="tombol-utama" @click="bukaPj()"><PhPlus :size="20" weight="bold" /> Catat pinjaman</button>
      </div>
      <p v-if="!pjTampil.length" class="kartu p-8 text-center text-sm text-teks3">Tidak ada pinjaman berjalan.</p>
      <ul v-else class="grid gap-3 md:grid-cols-2">
        <li v-for="x in pjTampil" :key="x.id" :class="['kartu p-4', 'w-' + STATUS_PJ[x.status].w]">
          <div class="flex items-start gap-2">
            <div class="min-w-0 flex-1"><p class="font-bold">{{ x.nama }}</p><p class="text-xs text-teks3">NIY {{ x.niy || '–' }}{{ x.keterangan ? ' · ' + x.keterangan : '' }}</p></div>
            <span class="lencana">{{ STATUS_PJ[x.status].n }}</span>
          </div>
          <div class="mt-3 flex items-end justify-between gap-2">
            <div><p class="text-xs text-teks3">Sisa</p><p class="text-xl font-extrabold tabular-nums">{{ rupiah(x.sisa) }}</p></div>
            <p class="text-right text-sm text-teks2">dari {{ rupiah(x.pokok) }}<br />cicilan {{ rupiah(x.cicilan) }}/bulan</p>
          </div>
          <div class="mt-2 h-2.5 overflow-hidden rounded-full bg-permukaan2" role="progressbar" :aria-valuenow="Math.round(x.dibayar / x.pokok * 100)" aria-valuemin="0" aria-valuemax="100">
            <div class="h-full rounded-full" style="background: var(--c)" :style="{ width: Math.min(100, x.dibayar / x.pokok * 100) + '%' }" /></div>
          <p class="mt-1 text-xs text-teks3">Dibayar {{ rupiah(x.dibayar) }} · mulai dipotong {{ namaBulan(x.mulai_potong) }}</p>
          <div class="mt-2 flex flex-wrap justify-end gap-1">
            <button class="tombol-ikon h-10 w-10" @click="riwayatPj = x" :aria-label="`Riwayat pembayaran ${x.nama}`"><PhClockCounterClockwise :size="18" /></button>
            <template v-if="boleh && x.status === 'aktif'">
              <button class="tombol-ikon h-10 w-10" @click="fBayar = { x, nilai: String(Number(x.sisa)), tanggal: hariIniISO(), ket: '' }" :aria-label="`Catat pembayaran ${x.nama}`"><PhMoney :size="18" /></button>
              <button class="tombol-ikon h-10 w-10" @click="bukaPj(x)" :aria-label="`Ubah pinjaman ${x.nama}`"><PhPencilSimple :size="18" /></button>
              <button class="tombol-ikon h-10 w-10" @click="batalPj(x)" :aria-label="`Tutup pinjaman ${x.nama}`"><PhXCircle :size="18" /></button>
            </template>
          </div>
        </li>
      </ul>
    </div>

    <!-- ================= SIMPANAN ================= -->
    <div v-else>
      <div class="-mx-4 mb-4 flex snap-x gap-3 overflow-x-auto px-4 pb-1 sm:mx-0 sm:grid sm:grid-cols-3 sm:overflow-visible sm:px-0">
        <KartuStatistik class="w-[72%] shrink-0 snap-start sm:w-auto" judul="Saldo simpanan" :nilai="rupiah(totalSimpanan)" :ikon="PhPiggyBank" warna="berkas" keterangan="Disimpan yayasan" />
        <KartuStatistik class="w-[44%] shrink-0 snap-start sm:w-auto" judul="Peserta aktif" :nilai="pesertaAktif" :ikon="PhUserPlus" warna="pegawai" keterangan="Semua program" />
        <KartuStatistik class="w-[72%] shrink-0 snap-start sm:w-auto" judul="Setoran per bulan" :nilai="rupiah(setoranBulan)" :ikon="PhArrowsLeftRight" warna="presensi" keterangan="Dipotong dari gaji" />
      </div>
      <div v-if="boleh" class="mb-3 flex justify-end"><button class="tombol-garis" @click="fProg = { nama: '', keterangan: '', setoranT: '', aktif: true }"><PhPlus :size="20" weight="bold" /> Program baru</button></div>
      <section v-for="p in program" :key="p.id" class="kartu w-berkas mb-3 p-4">
        <div class="flex flex-wrap items-start gap-2">
          <button class="flex min-w-0 flex-1 items-center gap-3 text-left" @click="bukaProg[p.id] = !bukaProg[p.id]" :aria-expanded="!!bukaProg[p.id]">
            <span class="chip-ikon h-11 w-11 shrink-0"><PhPiggyBank :size="24" weight="duotone" /></span>
            <span class="min-w-0"><span class="block font-bold">{{ p.nama }} <span v-if="!p.aktif" class="lencana w-hakakses">Nonaktif</span></span>
              <span class="block text-sm text-teks3">{{ p.anggota.filter((a) => a.aktif).length }} peserta · saldo {{ rupiah(p.saldo) }}</span></span>
            <PhCaretDown :size="18" :class="['ml-auto shrink-0 text-teks3 transition', bukaProg[p.id] && 'rotate-180']" />
          </button>
          <div v-if="boleh" class="flex gap-1">
            <button class="tombol-ikon h-10 w-10" @click="bukaAng(p)" :aria-label="`Tambah peserta ${p.nama}`"><PhUserPlus :size="18" /></button>
            <button class="tombol-ikon h-10 w-10" @click="fProg = { ...p, setoranT: String(Number(p.setoran_bawaan)) }" :aria-label="`Ubah program ${p.nama}`"><PhPencilSimple :size="18" /></button>
          </div>
        </div>
        <div v-if="bukaProg[p.id]" class="mt-3">
          <p v-if="p.keterangan" class="mb-2 text-sm text-teks2">{{ p.keterangan }}</p>
          <p v-if="!p.anggota.filter(cocok).length" class="rounded-xl bg-permukaan2 p-3 text-sm text-teks3">Belum ada peserta.</p>
          <ul v-else class="divide-y divide-garis rounded-xl border border-garis">
            <li v-for="a in p.anggota.filter(cocok)" :key="a.employee_id" class="flex flex-wrap items-center gap-2 px-3 py-2.5">
              <div class="min-w-[160px] flex-1"><p class="font-semibold">{{ a.nama }}</p>
                <p class="text-xs text-teks3">NIY {{ a.niy || '–' }} · {{ rupiah(a.setoran) }}/bulan sejak {{ namaBulan(a.mulai) }}<template v-if="!a.aktif"> · berhenti</template></p></div>
              <p class="font-bold tabular-nums">{{ rupiah(a.saldo) }}</p>
              <div class="flex">
                <button class="tombol-ikon h-9 w-9" @click="riwayatAng = { p, a }" :aria-label="`Riwayat simpanan ${a.nama}`"><PhClockCounterClockwise :size="16" /></button>
                <template v-if="boleh">
                  <button class="tombol-ikon h-9 w-9" @click="fTx = { p, a, jenis: 'pencairan', nilai: '', tanggal: hariIniISO(), ket: '' }" :aria-label="`Transaksi simpanan ${a.nama}`"><PhArrowsLeftRight :size="16" /></button>
                  <button class="tombol-ikon h-9 w-9" @click="bukaAng(p, a)" :aria-label="`Ubah keanggotaan ${a.nama}`"><PhPencilSimple :size="16" /></button>
                </template>
              </div>
            </li>
          </ul>
        </div>
      </section>
    </div>

    <!-- Lembar: pinjaman -->
    <LembarBawah :model-value="!!fPj" @update:model-value="(v) => !v && (fPj = null)" :judul="fPj?.id ? 'Ubah pinjaman' : 'Catat pinjaman'">
      <div v-if="fPj" class="space-y-4 pb-2">
        <div><label class="label-isian" for="pj-peg">Pegawai</label>
          <select id="pj-peg" v-model="fPj.employee_id" class="isian" :disabled="!!fPj.id"><option value="">Pilih pegawai</option>
            <option v-for="p in gaji.pegawai" :key="p.id" :value="p.id">{{ p.niy ? p.niy + ' – ' : '' }}{{ p.nama_lengkap }}</option></select></div>
        <div><label class="label-isian" for="pj-ket">Keperluan (tidak wajib)</label><input id="pj-ket" v-model="fPj.keterangan" class="isian" placeholder="Contoh: Biaya sekolah anak" /></div>
        <div class="grid gap-3 sm:grid-cols-2">
          <div><label class="label-isian" for="pj-pok">Nilai pinjaman</label><input id="pj-pok" v-model="fPj.pokokT" inputmode="numeric" class="isian tabular-nums" />
            <p class="mt-1 text-xs text-teks3">{{ bacaRupiah(fPj.pokokT) ? terbilang(bacaRupiah(fPj.pokokT)) : '' }}</p></div>
          <div><label class="label-isian" for="pj-cic">Cicilan per bulan</label><input id="pj-cic" v-model="fPj.cicilanT" inputmode="numeric" class="isian tabular-nums" />
            <p class="mt-1 text-xs text-teks3">{{ lamaCicil ? `± ${lamaCicil} bulan` : '' }}</p></div>
          <InputTanggal v-model="fPj.tanggal" label="Tanggal pinjam" />
          <div><label class="label-isian" for="pj-mul">Mulai dipotong</label>
            <select id="pj-mul" v-model="fPj.mulai_potong" class="isian"><option v-for="b in pilihanBulan" :key="b" :value="b">Gaji {{ namaBulan(b) }}</option></select></div>
        </div>
        <div><label class="label-isian" for="pj-cat">Catatan (tidak wajib)</label><input id="pj-cat" v-model="fPj.catatan" class="isian" /></div>
        <button class="tombol-utama w-full" :disabled="proses" @click="simpanPj"><PhFloppyDisk :size="20" weight="duotone" /> Simpan pinjaman</button>
      </div>
    </LembarBawah>
    <LembarBawah :model-value="!!fBayar" @update:model-value="(v) => !v && (fBayar = null)" :judul="fBayar ? `Pembayaran pinjaman ${fBayar.x.nama}` : ''">
      <div v-if="fBayar" class="space-y-4 pb-2">
        <p class="text-sm text-teks2">Untuk pembayaran langsung kepada Bendahara (di luar gaji). Cicilan lewat gaji tercatat otomatis saat slip terbit. Sisa saat ini {{ rupiah(fBayar.x.sisa) }}.</p>
        <div><label class="label-isian" for="by-nil">Nominal</label><input id="by-nil" v-model="fBayar.nilai" inputmode="numeric" class="isian tabular-nums" /></div>
        <InputTanggal v-model="fBayar.tanggal" label="Tanggal bayar" />
        <div><label class="label-isian" for="by-ket">Keterangan</label><input id="by-ket" v-model="fBayar.ket" class="isian" placeholder="Contoh: Pelunasan tunai" /></div>
        <button class="tombol-utama w-full" :disabled="proses" @click="bayar"><PhMoney :size="20" weight="duotone" /> Catat pembayaran</button>
      </div>
    </LembarBawah>
    <LembarBawah :model-value="!!riwayatPj" @update:model-value="(v) => !v && (riwayatPj = null)" :judul="riwayatPj ? `Riwayat pinjaman ${riwayatPj.nama}` : ''">
      <div v-if="riwayatPj" class="space-y-2 pb-2">
        <p class="text-sm text-teks2">Pinjaman {{ rupiah(riwayatPj.pokok) }} tanggal {{ formatPendek(riwayatPj.tanggal) }}{{ riwayatPj.catatan ? ' · ' + riwayatPj.catatan : '' }}</p>
        <p v-if="!(riwayatPj.riwayat || []).length" class="rounded-xl bg-permukaan2 p-3 text-sm text-teks3">Belum ada pembayaran.</p>
        <ul v-else class="divide-y divide-garis rounded-xl border border-garis">
          <li v-for="(r, i) in riwayatPj.riwayat" :key="i" class="flex justify-between gap-2 px-3 py-2 text-sm">
            <span>{{ formatPendek(r.tanggal) }} · {{ r.periode ? 'Gaji ' + r.periode : r.keterangan }}</span><span class="font-semibold tabular-nums">{{ rupiah(r.besaran) }}</span></li>
        </ul>
      </div>
    </LembarBawah>

    <!-- Lembar: simpanan -->
    <LembarBawah :model-value="!!fProg" @update:model-value="(v) => !v && (fProg = null)" :judul="fProg?.id ? 'Ubah program simpanan' : 'Program simpanan baru'">
      <div v-if="fProg" class="space-y-4 pb-2">
        <div><label class="label-isian" for="pg-nm">Nama program</label><input id="pg-nm" v-model="fProg.nama" class="isian" placeholder="Contoh: Umrah" /></div>
        <div><label class="label-isian" for="pg-kt">Keterangan</label><input id="pg-kt" v-model="fProg.keterangan" class="isian" /></div>
        <div><label class="label-isian" for="pg-st">Setoran bawaan per bulan</label><input id="pg-st" v-model="fProg.setoranT" inputmode="numeric" class="isian tabular-nums" /></div>
        <label class="flex min-h-[44px] items-center gap-3"><input type="checkbox" v-model="fProg.aktif" class="h-5 w-5 accent-[#C7332F]" /><span class="text-sm font-semibold">Program aktif (setoran dipotong dari gaji)</span></label>
        <button class="tombol-utama w-full" :disabled="proses" @click="simpanProg"><PhFloppyDisk :size="20" weight="duotone" /> Simpan program</button>
      </div>
    </LembarBawah>
    <LembarBawah :model-value="!!fAng" @update:model-value="(v) => !v && (fAng = null)" :judul="fAng ? `Peserta ${fAng.program.nama}` : ''">
      <div v-if="fAng" class="space-y-4 pb-2">
        <div><label class="label-isian" for="an-peg">Pegawai</label>
          <select id="an-peg" v-model="fAng.employee_id" class="isian" :disabled="!fAng.baru"><option value="">Pilih pegawai</option>
            <option v-for="p in gaji.pegawai" :key="p.id" :value="p.id">{{ p.niy ? p.niy + ' – ' : '' }}{{ p.nama_lengkap }}</option></select></div>
        <div class="grid gap-3 sm:grid-cols-2">
          <div><label class="label-isian" for="an-st">Setoran per bulan</label><input id="an-st" v-model="fAng.setoranT" inputmode="numeric" class="isian tabular-nums" /></div>
          <div><label class="label-isian" for="an-ml">Mulai dipotong</label>
            <select id="an-ml" v-model="fAng.mulai" class="isian"><option v-for="b in pilihanBulan" :key="b" :value="b">Gaji {{ namaBulan(b) }}</option></select></div>
        </div>
        <label class="flex min-h-[44px] items-center gap-3"><input type="checkbox" v-model="fAng.aktif" class="h-5 w-5 accent-[#C7332F]" /><span class="text-sm font-semibold">Masih aktif menyetor</span></label>
        <div><label class="label-isian" for="an-ct">Catatan (tidak wajib)</label><input id="an-ct" v-model="fAng.catatan" class="isian" /></div>
        <p v-if="fAng.baru" class="text-xs text-teks3">Saldo lama (sebelum memakai SIMKA) dicatat sesudahnya lewat tombol transaksi → Setoran awal.</p>
        <button class="tombol-utama w-full" :disabled="proses" @click="simpanAng"><PhFloppyDisk :size="20" weight="duotone" /> Simpan</button>
      </div>
    </LembarBawah>
    <LembarBawah :model-value="!!fTx" @update:model-value="(v) => !v && (fTx = null)" :judul="fTx ? `Simpanan ${fTx.p.nama} – ${fTx.a.nama}` : ''">
      <div v-if="fTx" class="space-y-4 pb-2">
        <p class="text-sm text-teks2">Saldo saat ini {{ rupiah(fTx.a.saldo) }}.</p>
        <div class="grid grid-cols-3 gap-2">
          <button v-for="(n, k) in JENIS_TX" :key="k" type="button" @click="fTx.jenis = k" :aria-pressed="fTx.jenis === k"
            :class="['min-h-[44px] rounded-xl border px-2 text-sm font-semibold', fTx.jenis === k ? 'border-transparent bg-[#C7332F] text-white' : 'border-garis text-teks2']">{{ n }}</button>
        </div>
        <div><label class="label-isian" for="tx-nil">Nominal{{ fTx.jenis === 'koreksi' ? ' (awali tanda minus untuk mengurangi)' : '' }}</label>
          <input id="tx-nil" v-model="fTx.nilai" inputmode="numeric" class="isian tabular-nums" /></div>
        <InputTanggal v-model="fTx.tanggal" label="Tanggal" />
        <div><label class="label-isian" for="tx-ket">Keterangan</label><input id="tx-ket" v-model="fTx.ket" class="isian" :placeholder="fTx.jenis === 'pencairan' ? 'Contoh: Berangkat umrah Januari' : ''" /></div>
        <button class="tombol-utama w-full" :disabled="proses" @click="simpanTx"><PhFloppyDisk :size="20" weight="duotone" /> Catat</button>
      </div>
    </LembarBawah>
    <LembarBawah :model-value="!!riwayatAng" @update:model-value="(v) => !v && (riwayatAng = null)" :judul="riwayatAng ? `${riwayatAng.p.nama} – ${riwayatAng.a.nama}` : ''">
      <div v-if="riwayatAng" class="space-y-2 pb-2">
        <p class="text-sm text-teks2">Saldo {{ rupiah(riwayatAng.a.saldo) }}</p>
        <p v-if="!(riwayatAng.a.riwayat || []).length" class="rounded-xl bg-permukaan2 p-3 text-sm text-teks3">Belum ada transaksi.</p>
        <ul v-else class="divide-y divide-garis rounded-xl border border-garis">
          <li v-for="(t, i) in riwayatAng.a.riwayat" :key="i" class="flex justify-between gap-2 px-3 py-2 text-sm">
            <span>{{ formatPendek(t.tanggal) }} · {{ JENIS_TX[t.jenis] || 'Setoran dari gaji' }}<span v-if="t.keterangan" class="text-teks3"> – {{ t.keterangan }}</span></span>
            <span :class="['font-semibold tabular-nums', t.jenis === 'pencairan' && 'text-merah']">{{ t.jenis === 'pencairan' ? '−' : '' }}{{ rupiah(t.besaran) }}</span></li>
        </ul>
      </div>
    </LembarBawah>
  </div>
</template>
