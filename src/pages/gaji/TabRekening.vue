<!-- SIMKA PRO | src/pages/gaji/TabRekening.vue | v1.2 | Perbaikan 13.6.0: sub-tab bergaris bawah | 15/10/2026 -->
<script setup>
// Rekening penerimaan gaji setiap pegawai aktif: cara bayar (transfer/tunai), bank, nomor rekening, atas nama.
// Tampil di slip gaji. Diubah pengelola gaji (satu per satu atau impor Excel); pembaca gaji hanya melihat.
// Ekspor Excel memakai susunan yang sama dengan impor, sehingga dapat dilengkapi lalu diimpor kembali.
import { ref, computed } from 'vue'
import * as XLSX from 'xlsx'
import { PhMagnifyingGlass, PhFileXls, PhUploadSimple, PhEye, PhPencilSimple, PhFloppyDisk, PhTrash, PhBank, PhMoney, PhWarningCircle, PhUsersThree } from '@phosphor-icons/vue'
import { useGaji } from '@/stores/gaji'
import { useLembaga } from '@/stores/lembaga'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { formatPendek, hariIniISO } from '@/lib/tanggal'
import LembarBawah from '@/components/LembarBawah.vue'
import KartuStatistik from '@/components/KartuStatistik.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'

const gaji = useGaji(); const lembaga = useLembaga(); const sesi = useSesi(); const ui = useUI()
const boleh = computed(() => !!gaji.hak.kelola)
const BANK = ['BSI (Bank Syariah Indonesia)', 'BRI', 'BNI', 'Bank Mandiri', 'BCA', 'Bank Sulselbar', 'Bank Sulselbar Syariah', 'BTN', 'Bank Muamalat', 'CIMB Niaga Syariah']

const cari = ref(''); const saring = ref(''); const pratinjau = ref(false)
const SARING = [{ k: '', n: 'Semua' }, { k: 'belum', n: 'Belum diisi' }, { k: 'transfer', n: 'Transfer' }, { k: 'tunai', n: 'Tunai' }]
const jumlah = computed(() => {
  const d = gaji.pegawai
  return { semua: d.length, transfer: d.filter((p) => p.rekening?.cara_bayar === 'transfer').length,
    tunai: d.filter((p) => p.rekening?.cara_bayar === 'tunai').length, belum: d.filter((p) => !p.rekening).length }
})
const tampil = computed(() => {
  const q = cari.value.toLowerCase().trim()
  return gaji.pegawai.filter((p) => (!q || [p.nama_lengkap, p.niy, p.rekening?.bank, p.rekening?.nomor_rekening, p.rekening?.atas_nama].join(' ').toLowerCase().includes(q))
    && (!saring.value || (saring.value === 'belum' ? !p.rekening : p.rekening?.cara_bayar === saring.value)))
})
const caraTeks = (r) => (!r ? 'Belum diisi' : r.cara_bayar === 'tunai' ? 'Tunai' : 'Transfer')

// ---------- Ubah satu rekening ----------
const f = ref(null); const proses = ref(false)
function buka(p) {
  const r = p.rekening || {}
  f.value = { p, cara_bayar: r.cara_bayar || 'transfer', bank: r.bank || '', nomor_rekening: r.nomor_rekening || '', atas_nama: r.atas_nama || p.nama_lengkap.replace(/^(Ust\.|Ustzh\.)\s*/, '').split(',')[0], catatan: r.catatan || '' }
}
async function simpan() {
  const d = f.value
  if (d.cara_bayar === 'transfer') {
    if (!d.bank.trim() || !d.nomor_rekening.trim() || !d.atas_nama.trim()) return ui.toast('Isi nama bank, nomor rekening, dan atas nama.', 'galat')
    if (!/^[0-9][0-9 .-]{3,29}$/.test(d.nomor_rekening.trim())) return ui.toast('Nomor rekening hanya berisi angka.', 'galat')
  }
  proses.value = true
  try {
    await gaji.simpanRekening({ employee_id: d.p.id, cara_bayar: d.cara_bayar, bank: d.bank, nomor_rekening: d.nomor_rekening, atas_nama: d.atas_nama, catatan: d.catatan })
    ui.toast(`Rekening ${d.p.nama_lengkap} tersimpan.`); f.value = null
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
async function hapus() {
  const p = f.value.p
  if (!(await ui.konfirmasi({ judul: 'Kosongkan rekening?', pesan: `Data rekening ${p.nama_lengkap} dihapus. Slip berikutnya tidak memuat rekening sampai diisi lagi.`, ya: 'Kosongkan', bahaya: true }))) return
  try { await gaji.hapusRekening(p.id); ui.toast('Rekening dikosongkan.'); f.value = null } catch (e) { ui.toast(e.message, 'galat') }
}

// ---------- Excel ----------
const JUDUL = ['NIY', 'Nama', 'JK', 'Cara bayar (transfer/tunai)', 'Bank', 'Nomor rekening', 'Atas nama', 'Catatan']
function ekspor() {
  const baris = tampil.value.map((p) => [p.niy || '', p.nama_lengkap, p.jenis_kelamin || '', p.rekening?.cara_bayar || '', p.rekening?.bank || '',
    p.rekening?.nomor_rekening || '', p.rekening?.atas_nama || '', p.rekening?.catatan || ''])
  const ws = XLSX.utils.aoa_to_sheet([JUDUL, ...baris])
  // Nomor rekening dan NIY sebagai teks agar angka 0 di depan tidak hilang
  for (let r = 1; r <= baris.length; r++) for (const c of [0, 5]) { const a = XLSX.utils.encode_cell({ r, c }); if (ws[a]) { ws[a].t = 's'; ws[a].z = '@' } }
  ws['!cols'] = [12, 34, 5, 24, 26, 22, 30, 30].map((wch) => ({ wch }))
  const wb = XLSX.utils.book_new(); XLSX.utils.book_append_sheet(wb, ws, 'Rekening')
  XLSX.writeFile(wb, `Rekening-Gaji-Pegawai-${formatPendek(hariIniISO()).replace(/\//g, '-')}.xlsx`)
}
const masukan = ref(null); const impor = ref(null)
const bersih = (v) => String(v ?? '').trim()
async function bacaBerkas(e) {
  const berkas = e.target.files?.[0]; e.target.value = ''
  if (!berkas) return
  try {
    const wb = XLSX.read(await berkas.arrayBuffer())
    const aoa = XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]], { header: 1, raw: false, defval: '' })
    const iJudul = aoa.findIndex((r) => r.some((c) => /^niy$/i.test(bersih(c))))
    if (iJudul < 0) throw new Error('Kolom NIY tidak ditemukan. Pakai berkas hasil tombol Ekspor Excel.')
    const j = aoa[iJudul].map((c) => bersih(c).toLowerCase())
    const kol = (awal) => j.findIndex((c) => c.startsWith(awal))
    const k = { niy: kol('niy'), nama: kol('nama'), cara: kol('cara'), bank: kol('bank'), no: kol('nomor'), an: kol('atas'), cat: kol('catatan') }
    const baris = aoa.slice(iJudul + 1).filter((r) => bersih(r[k.niy]) && (bersih(r[k.cara]) || bersih(r[k.bank]) || bersih(r[k.no])))
      .map((r) => ({ niy: bersih(r[k.niy]), nama: bersih(r[k.nama]), cara_bayar: bersih(r[k.cara]).toLowerCase() || (bersih(r[k.no]) ? 'transfer' : ''),
        bank: bersih(r[k.bank]), nomor_rekening: bersih(r[k.no]), atas_nama: bersih(r[k.an]), catatan: k.cat >= 0 ? bersih(r[k.cat]) : '' }))
    if (!baris.length) throw new Error('Tidak ada baris rekening yang terisi.')
    impor.value = { baris, hasil: null }
  } catch (err) { ui.toast(err.message, 'galat') }
}
async function jalankanImpor() {
  proses.value = true
  try {
    impor.value.hasil = await gaji.simpanRekening(impor.value.baris)
    ui.toast(`${impor.value.hasil.disimpan} rekening tersimpan.`)
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}

const direktur = computed(() => lembaga.signatories.find((s) => /^direktur$/i.test(s.jabatan_tertulis)) || {})
</script>
<template>
  <div>
    <div class="-mx-4 mb-4 flex snap-x gap-3 overflow-x-auto px-4 pb-1 sm:mx-0 sm:grid sm:grid-cols-4 sm:overflow-visible sm:px-0">
      <KartuStatistik class="w-[44%] shrink-0 snap-start sm:w-auto" judul="Pegawai aktif" :nilai="jumlah.semua" :ikon="PhUsersThree" warna="pegawai" keterangan="Penerima gaji" />
      <KartuStatistik class="w-[44%] shrink-0 snap-start sm:w-auto" judul="Transfer" :nilai="jumlah.transfer" :ikon="PhBank" warna="shift" keterangan="Rekening lengkap" />
      <KartuStatistik class="w-[44%] shrink-0 snap-start sm:w-auto" judul="Tunai" :nilai="jumlah.tunai" :ikon="PhMoney" warna="presensi" keterangan="Dibayar langsung" />
      <KartuStatistik class="w-[44%] shrink-0 snap-start sm:w-auto" judul="Belum diisi" :nilai="jumlah.belum" :ikon="PhWarningCircle" warna="klinik" keterangan="Perlu dilengkapi" />
    </div>

    <div class="mb-4 flex flex-wrap items-center gap-2">
      <div class="relative min-w-[220px] flex-1"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
        <input v-model="cari" type="search" class="isian pl-11" placeholder="Cari nama, NIY, bank, atau nomor rekening" aria-label="Cari rekening" /></div>
      <div class="flex gap-1.5 overflow-x-auto" role="group" aria-label="Saring cara bayar">
        <div class="bilah-tab kecil" role="tablist" aria-label="Saring cara bayar">
          <button v-for="s in SARING" :key="s.k" type="button" @click="saring = s.k"
          :class="['tab-garis', (saring === s.k) && 'aktif']" role="tab" :aria-selected="saring === s.k">{{ s.n }}</button>
        </div>
      </div>
      <button class="tombol-garis" @click="ekspor"><PhFileXls :size="20" weight="duotone" /> Ekspor Excel</button>
      <button v-if="boleh" class="tombol-garis" @click="masukan.click()"><PhUploadSimple :size="20" weight="duotone" /> Impor Excel</button>
      <input ref="masukan" type="file" accept=".xlsx,.xls" class="hidden" @change="bacaBerkas" />
      <button class="tombol-garis" @click="pratinjau = true"><PhEye :size="20" weight="duotone" /> Pratinjau cetak</button>
    </div>

    <p v-if="!tampil.length" class="kartu p-8 text-center text-sm text-teks3">Tidak ada pegawai yang sesuai.</p>
    <!-- Tabel desktop -->
    <div v-else class="kartu hidden overflow-x-auto lg:block">
      <table class="w-full text-left text-sm">
        <thead class="border-b border-garis bg-permukaan2 text-teks2"><tr>
          <th class="px-3 py-3 font-bold">NIY</th><th class="px-3 py-3 font-bold">Nama</th><th class="px-3 py-3 font-bold">Cara bayar</th>
          <th class="px-3 py-3 font-bold">Bank</th><th class="px-3 py-3 font-bold">Nomor rekening</th><th class="px-3 py-3 font-bold">Atas nama</th><th class="w-12" /></tr></thead>
        <tbody class="divide-y divide-garis">
          <tr v-for="p in tampil" :key="p.id" class="hover:bg-permukaan2">
            <td class="px-3 py-2.5 tabular-nums text-teks2">{{ p.niy || '–' }}</td>
            <td class="px-3 py-2.5"><p class="font-semibold">{{ p.nama_lengkap }}</p><p class="text-xs text-teks3">{{ p.nama_unit || '–' }}</p></td>
            <td class="px-3 py-2.5"><span :class="['lencana', !p.rekening ? 'w-klinik' : p.rekening.cara_bayar === 'tunai' ? 'w-presensi' : 'w-shift']">{{ caraTeks(p.rekening) }}</span></td>
            <td class="px-3 py-2.5">{{ p.rekening?.bank || '–' }}</td>
            <td class="px-3 py-2.5 font-semibold tabular-nums">{{ p.rekening?.nomor_rekening || '–' }}</td>
            <td class="px-3 py-2.5">{{ p.rekening?.atas_nama || '–' }}</td>
            <td class="pr-2"><button v-if="boleh" class="tombol-ikon h-9 w-9" @click="buka(p)" :aria-label="`Ubah rekening ${p.nama_lengkap}`"><PhPencilSimple :size="18" /></button></td>
          </tr>
        </tbody>
      </table>
    </div>
    <!-- Kartu HP -->
    <ul class="space-y-2.5 lg:hidden">
      <li v-for="p in tampil" :key="p.id">
        <component :is="boleh ? 'button' : 'div'" class="kartu w-full p-4 text-left active:bg-permukaan2" @click="boleh && buka(p)">
          <div class="flex items-start gap-2">
            <div class="min-w-0 flex-1"><p class="font-bold">{{ p.nama_lengkap }}</p><p class="text-sm text-teks3">NIY {{ p.niy || '–' }}</p></div>
            <span :class="['lencana shrink-0', !p.rekening ? 'w-klinik' : p.rekening.cara_bayar === 'tunai' ? 'w-presensi' : 'w-shift']">{{ caraTeks(p.rekening) }}</span>
          </div>
          <p v-if="p.rekening?.cara_bayar === 'transfer'" class="mt-2 text-sm"><span class="font-semibold">{{ p.rekening.bank }}</span>
            <span class="tabular-nums"> · {{ p.rekening.nomor_rekening }}</span><span class="text-teks3"> · a.n. {{ p.rekening.atas_nama }}</span></p>
        </component>
      </li>
    </ul>

    <!-- Ubah rekening -->
    <LembarBawah :model-value="!!f" @update:model-value="(x) => !x && (f = null)" :judul="f ? `Rekening ${f.p.nama_lengkap}` : ''">
      <div v-if="f" class="space-y-4 pb-2">
        <div><p class="label-isian">Cara bayar</p>
          <div class="grid grid-cols-2 gap-2">
            <button v-for="c in [['transfer', 'Transfer bank', PhBank], ['tunai', 'Tunai', PhMoney]]" :key="c[0]" type="button" @click="f.cara_bayar = c[0]" :aria-pressed="f.cara_bayar === c[0]"
              :class="['flex min-h-[48px] items-center justify-center gap-2 rounded-xl border font-semibold', f.cara_bayar === c[0] ? 'border-transparent bg-[#C7332F] text-white' : 'border-garis text-teks2']">
              <component :is="c[2]" :size="20" weight="duotone" /> {{ c[1] }}</button>
          </div></div>
        <template v-if="f.cara_bayar === 'transfer'">
          <div><label class="label-isian" for="rk-bank">Nama bank</label>
            <input id="rk-bank" v-model="f.bank" list="rk-daftar-bank" class="isian" placeholder="Contoh: BSI" />
            <datalist id="rk-daftar-bank"><option v-for="b in BANK" :key="b" :value="b" /></datalist></div>
          <div><label class="label-isian" for="rk-no">Nomor rekening</label><input id="rk-no" v-model="f.nomor_rekening" inputmode="numeric" class="isian tabular-nums" placeholder="Angka saja" /></div>
          <div><label class="label-isian" for="rk-an">Atas nama</label><input id="rk-an" v-model="f.atas_nama" class="isian" placeholder="Nama sesuai buku tabungan" />
            <p class="mt-1 text-xs text-teks3">Isi sesuai nama di buku tabungan, termasuk bila rekening atas nama keluarga.</p></div>
        </template>
        <div><label class="label-isian" for="rk-cat">Catatan (tidak wajib)</label><input id="rk-cat" v-model="f.catatan" class="isian" placeholder="Contoh: rekening istri" /></div>
        <div class="flex gap-2">
          <button v-if="f.p.rekening" class="tombol-garis" :disabled="proses" @click="hapus"><PhTrash :size="20" /> Kosongkan</button>
          <button class="tombol-utama flex-1" :disabled="proses" @click="simpan"><PhFloppyDisk :size="20" weight="duotone" /> {{ proses ? 'Menyimpan…' : 'Simpan rekening' }}</button>
        </div>
      </div>
    </LembarBawah>

    <!-- Pratinjau impor -->
    <LembarBawah :model-value="!!impor" @update:model-value="(x) => !x && (impor = null)" judul="Impor rekening dari Excel" lebar>
      <div v-if="impor" class="space-y-4 pb-2">
        <p class="text-sm text-teks2">{{ impor.baris.length }} baris terbaca. Pegawai dicocokkan dengan NIY; baris yang gagal tidak disimpan dan ditampilkan alasannya.</p>
        <div class="max-h-[45dvh] overflow-auto rounded-xl border border-garis">
          <table class="w-full text-left text-sm">
            <thead class="sticky top-0 bg-permukaan2"><tr><th class="px-2 py-2">No.</th><th class="px-2 py-2">NIY</th><th class="px-2 py-2">Nama</th><th class="px-2 py-2">Cara</th><th class="px-2 py-2">Bank</th><th class="px-2 py-2">Nomor</th><th class="px-2 py-2">Atas nama</th><th class="px-2 py-2">Hasil</th></tr></thead>
            <tbody class="divide-y divide-garis">
              <tr v-for="(b, i) in impor.baris" :key="i">
                <td class="px-2 py-1.5">{{ i + 1 }}</td><td class="px-2 py-1.5 tabular-nums">{{ b.niy }}</td><td class="px-2 py-1.5">{{ b.nama }}</td>
                <td class="px-2 py-1.5">{{ b.cara_bayar || '–' }}</td><td class="px-2 py-1.5">{{ b.bank || '–' }}</td><td class="px-2 py-1.5 tabular-nums">{{ b.nomor_rekening || '–' }}</td><td class="px-2 py-1.5">{{ b.atas_nama || '–' }}</td>
                <td class="px-2 py-1.5 text-xs font-semibold">
                  <template v-if="impor.hasil"><span v-if="impor.hasil.gagal.find((g) => g.baris === i + 1)" class="w-klinik" style="color: var(--c)">{{ impor.hasil.gagal.find((g) => g.baris === i + 1).pesan }}</span>
                    <span v-else class="w-presensi" style="color: var(--c)">Tersimpan</span></template>
                  <span v-else class="text-teks3">Belum</span></td>
              </tr>
            </tbody>
          </table>
        </div>
        <button v-if="!impor.hasil" class="tombol-utama w-full" :disabled="proses" @click="jalankanImpor"><PhUploadSimple :size="20" weight="duotone" /> {{ proses ? 'Menyimpan…' : 'Simpan semua rekening' }}</button>
        <button v-else class="tombol-garis w-full" @click="impor = null">Selesai</button>
      </div>
    </LembarBawah>

    <!-- Cetak F4 -->
    <DokumenCetak v-model:pratinjau="pratinjau" judul="Daftar Rekening Penerimaan Gaji Pegawai" :subjudul="`Keadaan per ${formatPendek(hariIniISO())}`" :pencetak="sesi.pengguna?.nama_lengkap">
      <table class="tabel">
        <colgroup><col style="width:6%"><col style="width:14%"><col style="width:25%"><col style="width:9%"><col style="width:13%"><col style="width:15%"><col style="width:18%"></colgroup>
        <thead><tr><th>No.</th><th>NIY</th><th>Nama</th><th>Cara bayar</th><th>Bank</th><th>Nomor rekening</th><th>Atas nama</th></tr></thead>
        <tbody>
          <tr v-for="(p, i) in tampil" :key="p.id">
            <td class="tengah">{{ i + 1 }}</td><td class="tengah">{{ p.niy || '–' }}</td><td>{{ p.nama_lengkap }}</td><td class="tengah">{{ caraTeks(p.rekening) }}</td>
            <td>{{ p.rekening?.bank || '–' }}</td><td class="tengah">{{ p.rekening?.nomor_rekening || '–' }}</td><td>{{ p.rekening?.atas_nama || '–' }}</td>
          </tr>
        </tbody>
      </table>
      <template #ttd>
        <TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: direktur.jabatan_tertulis || 'Direktur', nama: direktur.nama || '', niy: direktur.niy }"
          :kanan="{ jabatan: gaji.jabatanSaya, nama: sesi.pengguna?.nama_lengkap || '', niy: sesi.pengguna?.niy }" :tanggal="hariIniISO()" />
      </template>
    </DokumenCetak>
  </div>
</template>
