<!-- SIMKA PRO | src/pages/gaji/TabPenetapan.vue | v1.0 | Fase 11 – Tahap 2 Penetapan gaji oleh yayasan | 11/10/2026 -->
<script setup>
// Penetapan gaji oleh Ketua Yayasan (hak prerogatif) per pegawai, bertanggal berlaku. Dipakai otomatis setiap periode:
//   • Jumlah tetap : jumlah pendapatan pegawai ditetapkan, berapa pun hasil skema (penyesuaian = penetapan − skema).
//   • Selisih      : tambahan atau pengurangan tetap dari hasil skema setiap bulan.
// Untuk perbedaan satu bulan saja, pakai "Tetapkan jumlah diterima" di rincian periode.
import { ref, computed, onMounted } from 'vue'
import { PhPlus, PhPencilSimple, PhTrash, PhFloppyDisk, PhScales, PhMagnifyingGlass, PhInfo } from '@phosphor-icons/vue'
import { useGaji } from '@/stores/gaji'
import { useUI } from '@/stores/ui'
import { formatPendek, hariIniISO } from '@/lib/tanggal'
import { rupiah, bacaRupiah, terbilang } from '@/lib/gaji'
import LembarBawah from '@/components/LembarBawah.vue'
import InputTanggal from '@/components/InputTanggal.vue'

const gaji = useGaji(); const ui = useUI()
const boleh = computed(() => !!gaji.hak.kelola)
const daftar = ref([]); const memuat = ref(true); const cari = ref(''); const semua = ref(false)
async function muat() {
  memuat.value = true
  try { await gaji.muatPegawai(); daftar.value = await gaji.daftarPenetapan() } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false }
}
onMounted(muat)
const tampil = computed(() => {
  const q = cari.value.toLowerCase().trim()
  return daftar.value.filter((x) => (semua.value || x.aktif || x.berlaku_mulai > hariIniISO()) && (!q || [x.nama, x.niy, x.keterangan].join(' ').toLowerCase().includes(q)))
})
const teksNilai = (x) => (x.mode === 'total' ? `Jumlah tetap ${rupiah(x.nilai)}` : `${Number(x.nilai) > 0 ? 'Tambahan' : 'Pengurangan'} ${rupiah(Math.abs(x.nilai))} dari skema`)
const status = (x) => (x.berlaku_mulai > hariIniISO() ? { n: 'Akan berlaku', w: 'shift' } : x.aktif ? { n: 'Berlaku', w: 'presensi' } : { n: 'Berakhir', w: 'hakakses' })

const f = ref(null); const proses = ref(false)
function bukaForm(x = null) {
  f.value = x ? { ...x, nilaiTeks: String(Math.abs(Number(x.nilai))), arah: Number(x.nilai) < 0 ? '-' : '+', berlaku_sampai: x.berlaku_sampai || '' }
    : { employee_id: '', mode: 'total', nilaiTeks: '', arah: '+', keterangan: 'Ketetapan Ketua Yayasan', dasar: '', berlaku_mulai: hariIniISO().slice(0, 8) + '01', berlaku_sampai: '' }
}
const pegawaiPilih = computed(() => gaji.pegawai.find((p) => p.id === f.value?.employee_id))
const nilaiAkhir = computed(() => { const n = bacaRupiah(f.value?.nilaiTeks); return n == null ? null : f.value.mode === 'selisih' && f.value.arah === '-' ? -Math.abs(n) : Math.abs(n) })
async function simpan() {
  const x = f.value
  if (!x.employee_id) return ui.toast('Pilih pegawai.', 'galat')
  if (nilaiAkhir.value == null || (x.mode === 'selisih' && !nilaiAkhir.value)) return ui.toast('Isi nominal penetapan.', 'galat')
  if ((x.keterangan || '').trim().length < 3) return ui.toast('Isi keterangan penetapan.', 'galat')
  proses.value = true
  try {
    await gaji.simpanPenetapan({ id: x.id || null, employee_id: x.employee_id, mode: x.mode, nilai: nilaiAkhir.value, keterangan: x.keterangan.trim(),
      dasar: x.dasar, berlaku_mulai: x.berlaku_mulai, berlaku_sampai: x.berlaku_sampai || null })
    ui.toast('Penetapan tersimpan. Berlaku pada periode gaji yang dibuat atau dihitung ulang.'); f.value = null; await muat()
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
async function hapus(x) {
  if (!(await ui.konfirmasi({ judul: 'Hapus penetapan?', pesan: `${x.nama}: ${teksNilai(x)}. Periode yang sudah terbit tidak berubah; periode draf berubah setelah dihitung ulang.`, ya: 'Hapus', bahaya: true }))) return
  try { await gaji.hapusPenetapan(x.id); ui.toast('Penetapan dihapus.'); await muat() } catch (e) { ui.toast(e.message, 'galat') }
}
</script>
<template>
  <div>
    <div class="kartu w-verifikasi mb-4 flex gap-3 p-4">
      <span class="chip-ikon h-11 w-11 shrink-0"><PhScales :size="24" weight="duotone" /></span>
      <div class="text-sm text-teks2">
        <p class="font-bold text-teks">Gaji yang ditetapkan Ketua Yayasan</p>
        <p>Bila gaji seorang pegawai ditetapkan berbeda dari skema, catat di sini sekali. Setiap periode gaji otomatis memakai penetapan ini, dan slip
          menampilkan nominal yang benar-benar diterima dengan baris "{{ gaji.pengaturan.label_penyesuaian }}".</p>
        <p class="mt-1 text-teks3">Perbedaan yang hanya terjadi satu bulan: buka periode gaji → pegawai → Tetapkan jumlah diterima.</p>
      </div>
    </div>
    <div class="mb-4 flex flex-wrap items-center gap-2">
      <div class="relative min-w-[200px] flex-1"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
        <input v-model="cari" type="search" class="isian pl-11" placeholder="Cari nama atau keterangan" aria-label="Cari penetapan" /></div>
      <label class="flex min-h-[44px] items-center gap-2 text-sm font-semibold"><input type="checkbox" v-model="semua" class="h-5 w-5 accent-[#C7332F]" /> Tampilkan yang berakhir</label>
      <button v-if="boleh" class="tombol-utama" @click="bukaForm()"><PhPlus :size="20" weight="bold" /> Tambah penetapan</button>
    </div>
    <p v-if="memuat" class="kartu p-8 text-center text-sm text-teks3">Memuat…</p>
    <p v-else-if="!tampil.length" class="kartu p-8 text-center text-sm text-teks3">Belum ada penetapan gaji yang berlaku.</p>
    <ul v-else class="grid gap-3 md:grid-cols-2">
      <li v-for="x in tampil" :key="x.id" :class="['kartu p-4', 'w-' + status(x).w]">
        <div class="flex items-start gap-2">
          <div class="min-w-0 flex-1"><p class="font-bold">{{ x.nama }}</p><p class="text-xs text-teks3">NIY {{ x.niy || '–' }}</p></div>
          <span class="lencana">{{ status(x).n }}</span>
        </div>
        <p class="mt-2 text-lg font-extrabold tabular-nums">{{ teksNilai(x) }}</p>
        <p class="text-sm text-teks2">{{ x.keterangan }}<template v-if="x.dasar"> · {{ x.dasar }}</template></p>
        <p class="text-xs text-teks3">Berlaku {{ formatPendek(x.berlaku_mulai) }}{{ x.berlaku_sampai ? ' s.d. ' + formatPendek(x.berlaku_sampai) : ' dan seterusnya' }}</p>
        <div v-if="boleh" class="mt-2 flex justify-end gap-1">
          <button class="tombol-ikon h-10 w-10" @click="bukaForm(x)" :aria-label="`Ubah penetapan ${x.nama}`"><PhPencilSimple :size="18" /></button>
          <button class="tombol-ikon h-10 w-10" @click="hapus(x)" :aria-label="`Hapus penetapan ${x.nama}`"><PhTrash :size="18" /></button>
        </div>
      </li>
    </ul>

    <LembarBawah :model-value="!!f" @update:model-value="(v) => !v && (f = null)" :judul="f?.id ? 'Ubah penetapan gaji' : 'Tambah penetapan gaji'">
      <div v-if="f" class="space-y-4 pb-2">
        <div><label class="label-isian" for="pt-peg">Pegawai</label>
          <select id="pt-peg" v-model="f.employee_id" class="isian" :disabled="!!f.id"><option value="">Pilih pegawai</option>
            <option v-for="p in gaji.pegawai" :key="p.id" :value="p.id">{{ p.niy ? p.niy + ' – ' : '' }}{{ p.nama_lengkap }}</option></select></div>
        <div><p class="label-isian">Bentuk penetapan</p>
          <div class="grid gap-2 sm:grid-cols-2">
            <button v-for="m in [['total', 'Jumlah tetap', 'Gaji ditetapkan sekian, berapa pun hasil skema'], ['selisih', 'Selisih dari skema', 'Ditambah atau dikurangi sekian setiap bulan']]" :key="m[0]"
              type="button" @click="f.mode = m[0]" :aria-pressed="f.mode === m[0]"
              :class="['rounded-xl border p-3 text-left', f.mode === m[0] ? 'border-[#C7332F] bg-[#C7332F]/10' : 'border-garis']">
              <p class="font-bold">{{ m[1] }}</p><p class="text-xs text-teks3">{{ m[2] }}</p></button>
          </div></div>
        <div v-if="f.mode === 'selisih'" class="grid grid-cols-2 gap-2">
          <button v-for="a in [['+', 'Ditambah'], ['-', 'Dikurangi']]" :key="a[0]" type="button" @click="f.arah = a[0]" :aria-pressed="f.arah === a[0]"
            :class="['min-h-[44px] rounded-xl border font-semibold', f.arah === a[0] ? 'border-transparent bg-[#C7332F] text-white' : 'border-garis text-teks2']">{{ a[1] }}</button>
        </div>
        <div><label class="label-isian" for="pt-nil">{{ f.mode === 'total' ? 'Jumlah pendapatan per bulan' : 'Besar selisih per bulan' }}</label>
          <input id="pt-nil" v-model="f.nilaiTeks" inputmode="numeric" class="isian text-lg font-bold tabular-nums" placeholder="Contoh: 3500000" />
          <p class="mt-1 text-xs text-teks3">{{ nilaiAkhir != null ? terbilang(nilaiAkhir) : '' }}{{ f.mode === 'total' ? ' (sebelum potongan)' : '' }}</p></div>
        <div><label class="label-isian" for="pt-ket">Keterangan (tampil di slip sebagai alasan penyesuaian)</label><input id="pt-ket" v-model="f.keterangan" class="isian" /></div>
        <div><label class="label-isian" for="pt-das">Dasar penetapan (tidak wajib)</label><input id="pt-das" v-model="f.dasar" class="isian" placeholder="Contoh: Arahan lisan Ketua Yayasan 01/07/2026" /></div>
        <div class="grid gap-3 sm:grid-cols-2">
          <InputTanggal v-model="f.berlaku_mulai" label="Berlaku mulai" wajib />
          <div><InputTanggal v-model="f.berlaku_sampai" label="Berlaku sampai (tidak wajib)" bawaan-kosong /></div>
        </div>
        <p v-if="pegawaiPilih" class="flex gap-2 text-xs text-teks3"><PhInfo :size="16" class="shrink-0" /> Penetapan dipakai pada periode draf setelah tombol Hitung ulang, dan pada periode baru.</p>
        <button class="tombol-utama w-full" :disabled="proses" @click="simpan"><PhFloppyDisk :size="20" weight="duotone" /> {{ proses ? 'Menyimpan…' : 'Simpan penetapan' }}</button>
      </div>
    </LembarBawah>
  </div>
</template>
