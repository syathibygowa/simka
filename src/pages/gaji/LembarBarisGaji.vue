<!-- SIMKA PRO | src/pages/gaji/LembarBarisGaji.vue | v1.0 | Fase 11 – Tahap 2 Rincian gaji seorang pegawai dalam periode | 11/10/2026 -->
<script setup>
// Rincian gaji seorang pegawai pada satu periode: data penentu gaji, komponen pendapatan dan potongan (skema vs nominal),
// penyesuaian ketetapan yayasan, dan jumlah diterima. Pengelola gaji (periode draf) dapat:
//   • mengubah nominal komponen atau jam honor (wajib alasan; dipertahankan saat hitung ulang) dan mengembalikannya ke skema,
//   • menambah pendapatan lain/potongan lain, • menetapkan jumlah diterima (penyesuaian dihitung otomatis), • mengeluarkan pegawai dari periode.
import { ref, computed, watch } from 'vue'
import { PhPencilSimple, PhArrowCounterClockwise, PhPlus, PhTrash, PhHandCoins, PhFloppyDisk, PhWarningCircle, PhBank, PhX } from '@phosphor-icons/vue'
import { useGaji } from '@/stores/gaji'
import { useUI } from '@/stores/ui'
import { formatPendek, formatWaktu } from '@/lib/tanggal'
import { KATEGORI_ITEM, SUMBER_ITEM, rupiah, bacaRupiah, terbilang, namaPeriode } from '@/lib/gaji'
import { PENDIDIKAN, STATUS_PEGAWAI } from '@/lib/kepegawaian'
import LembarBawah from '@/components/LembarBawah.vue'

const props = defineProps({ baris: Object, periode: Object, boleh: Boolean })
const emit = defineEmits(['tutup', 'berubah'])
const gaji = useGaji(); const ui = useUI()
const buka = computed({ get: () => !!props.baris, set: (v) => { if (!v) emit('tutup') } })
const b = computed(() => props.baris)
const d = computed(() => b.value?.data || {})
const pendapatan = computed(() => (b.value?.item || []).filter((i) => i.jenis === 'pendapatan'))
const potongan = computed(() => (b.value?.item || []).filter((i) => i.jenis === 'potongan'))
const proses = ref(false)
const mode = ref(''); const ubah = ref(null); const fTerima = ref(null); const fTambah = ref(null)
watch(() => props.baris?.id, () => { mode.value = ''; ubah.value = null })

async function jalan(fn, pesan) {
  proses.value = true
  try { await fn(); ui.toast(pesan); mode.value = ''; emit('berubah') } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
function bukaUbah(i) {
  ubah.value = { i, besaran: String(Number(i.besaran)), jumlah: i.jumlah != null ? String(Number(i.jumlah)) : '', alasan: i.sumber === 'manual' ? i.alasan || '' : '' }
  mode.value = 'ubah'
}
function simpanUbah() {
  const u = ubah.value; const honor = u.i.kategori === 'honor'
  const besaran = honor ? null : bacaRupiah(u.besaran); const jumlah = honor ? Number(String(u.jumlah).replace(',', '.')) : null
  if (!honor && (besaran == null || besaran < 0)) return ui.toast('Isi nominal yang benar.', 'galat')
  if (honor && (isNaN(jumlah) || jumlah < 0)) return ui.toast('Isi jumlah jam yang benar.', 'galat')
  if (u.alasan.trim().length < 3) return ui.toast('Alasan perubahan wajib diisi.', 'galat')
  jalan(() => gaji.ubahItem(u.i.id, besaran, jumlah, u.alasan.trim()), `${u.i.label} diperbarui.`)
}
const kembalikan = (i) => jalan(() => gaji.kembalikanItem(i.id), `${i.label} kembali sesuai skema.`)
async function hapusItem(i) {
  if (!(await ui.konfirmasi({ judul: `Hapus ${i.label}?`, pesan: 'Komponen ini dihapus dari periode.', ya: 'Hapus', bahaya: true }))) return
  jalan(() => gaji.hapusItem(i.id), 'Komponen dihapus.')
}
function bukaTerima() {
  fTerima.value = { nilai: b.value.target_diterima != null ? String(Number(b.value.target_diterima)) : String(Number(b.value.diterima)), alasan: b.value.alasan_target || 'Ketetapan Ketua Yayasan' }
  mode.value = 'terima'
}
/** Jumlah diterima hasil hitung sebelum penyesuaian. */
const dasarTerima = computed(() => Number(b.value?.diterima || 0) - Number(b.value?.total_penyesuaian || 0))
function simpanTerima() {
  const n = bacaRupiah(fTerima.value.nilai)
  if (n == null || n < 0) return ui.toast('Isi jumlah diterima yang benar.', 'galat')
  if (fTerima.value.alasan.trim().length < 3) return ui.toast('Isi keterangan.', 'galat')
  jalan(() => gaji.aturDiterima(b.value.id, n, fTerima.value.alasan.trim()), 'Jumlah diterima ditetapkan.')
}
const hapusTerima = () => jalan(() => gaji.aturDiterima(b.value.id, null, null), 'Penetapan jumlah diterima dihapus; gaji kembali dihitung otomatis.')
function bukaTambah(jenis) { fTambah.value = { jenis, label: '', besaran: '', alasan: '' }; mode.value = 'tambah' }
function simpanTambah() {
  const t = fTambah.value; const n = bacaRupiah(t.besaran)
  if (t.label.trim().length < 3) return ui.toast('Isi nama komponen.', 'galat')
  if (!n || n <= 0) return ui.toast('Isi nominal lebih dari nol.', 'galat')
  jalan(() => gaji.tambahItem(b.value.id, { jenis: t.jenis, label: t.label.trim(), besaran: n, alasan: t.alasan.trim() }), `${t.label} ditambahkan.`)
}
async function keluarkan() {
  if (!(await ui.konfirmasi({ judul: `Keluarkan ${d.value.nama} dari periode?`, pesan: 'Pegawai ini tidak menerima gaji pada periode ini. Hitung ulang periode akan memasukkannya kembali bila masih aktif.', ya: 'Keluarkan', bahaya: true }))) return
  try { await gaji.hapusBaris(b.value.id); ui.toast('Pegawai dikeluarkan dari periode.'); emit('tutup'); emit('berubah') } catch (e) { ui.toast(e.message, 'galat') }
}
const beda = (i) => i.besaran_skema != null && Number(i.besaran_skema) !== Number(i.besaran)
</script>
<template>
  <LembarBawah v-model="buka" :judul="d.nama ? `${d.nama} – ${namaPeriode(periode)}` : ''" lebar>
    <div v-if="b" class="space-y-4 pb-2">
      <!-- Data penentu gaji -->
      <div class="grid gap-x-4 gap-y-1 rounded-xl bg-permukaan2 p-3 text-sm sm:grid-cols-2">
        <p><span class="text-teks3">NIY:</span> {{ d.niy || '–' }}</p>
        <p><span class="text-teks3">Status:</span> {{ STATUS_PEGAWAI[d.status] || '–' }}{{ d.status === 'honorer' && d.kategori_honorer ? ` (${d.kategori_honorer})` : '' }}</p>
        <p class="sm:col-span-2"><span class="text-teks3">Jabatan:</span> {{ [d.jabatan_struktural, ...(d.jabatan_fungsional || [])].filter(Boolean).join(', ') || '–' }}</p>
        <p><span class="text-teks3">Pendidikan:</span> {{ PENDIDIKAN[d.pendidikan] || '–' }}</p>
        <p><span class="text-teks3">Masa kerja:</span> {{ d.tmt ? `${d.masa_kerja_tahun} tahun ${d.masa_kerja_bulan} bulan` : '–' }}</p>
        <p class="flex items-center gap-1.5 sm:col-span-2"><PhBank :size="16" class="text-teks3" />
          <template v-if="d.rekening?.cara_bayar === 'transfer'">{{ d.rekening.bank }} {{ d.rekening.nomor_rekening }} a.n. {{ d.rekening.atas_nama }}</template>
          <template v-else-if="d.rekening?.cara_bayar === 'tunai'">Dibayar tunai</template><template v-else>Rekening belum diisi</template></p>
      </div>
      <ul v-if="d.catatan?.length" class="w-klinik space-y-0.5 rounded-xl p-3 text-sm font-semibold" style="color: var(--c); background: color-mix(in srgb, var(--c) 10%, transparent)">
        <li v-for="c in d.catatan" :key="c" class="flex gap-1.5"><PhWarningCircle :size="16" class="mt-0.5 shrink-0" /> {{ c }}</li>
      </ul>

      <!-- Pendapatan -->
      <section>
        <div class="mb-1 flex items-center justify-between"><h3 class="judul-bagian">Pendapatan</h3>
          <button v-if="boleh" class="tombol-teks min-h-[36px] text-sm" @click="bukaTambah('pendapatan')"><PhPlus :size="16" weight="bold" /> Pendapatan lain</button></div>
        <ul class="divide-y divide-garis rounded-xl border border-garis">
          <li v-for="i in pendapatan" :key="i.id" :class="['flex items-start gap-2 px-3 py-2.5', 'w-' + (KATEGORI_ITEM[i.kategori]?.w || 'beranda')]">
            <span class="mt-1.5 h-2.5 w-2.5 shrink-0 rounded-full" style="background: var(--c)" />
            <div class="min-w-0 flex-1">
              <p class="font-semibold">{{ i.label }}</p>
              <p v-if="i.kategori === 'honor'" class="text-xs text-teks3">{{ Number(i.jumlah) }} jam × {{ rupiah(i.tarif) }}<template v-if="i.rincian?.sumber"> · {{ i.rincian.sumber }}</template>
                <template v-if="i.rincian?.jam_otomatis != null && Number(i.rincian.jam_otomatis) !== Number(i.jumlah)"> (otomatis {{ Number(i.rincian.jam_otomatis) }} jam)</template></p>
              <p class="mt-0.5 flex flex-wrap items-center gap-1 text-xs">
                <span :class="['lencana', 'w-' + SUMBER_ITEM[i.sumber].w]">{{ i.kategori === 'penyesuaian' && i.sumber === 'manual' ? 'Jumlah diterima ditetapkan' : SUMBER_ITEM[i.sumber].n }}</span>
                <span v-if="beda(i)" class="text-teks3">skema <s>{{ rupiah(i.besaran_skema) }}</s></span>
                <span v-if="i.alasan" class="text-teks2">{{ i.alasan }}</span>
                <span v-if="i.diubah_oleh" class="text-teks3">· {{ i.diubah_oleh }}{{ i.diubah_pada ? ', ' + formatWaktu(i.diubah_pada) : '' }}</span></p>
            </div>
            <p :class="['shrink-0 font-bold tabular-nums', Number(i.besaran) < 0 && 'text-merah']">{{ rupiah(i.besaran) }}</p>
            <div v-if="boleh" class="flex shrink-0">
              <button v-if="i.kategori !== 'penyesuaian'" class="tombol-ikon h-9 w-9" @click="bukaUbah(i)" :aria-label="`Ubah ${i.label}`"><PhPencilSimple :size="16" /></button>
              <button v-if="i.sumber === 'manual' && i.besaran_skema != null" class="tombol-ikon h-9 w-9" @click="kembalikan(i)" :aria-label="`Kembalikan ${i.label} ke skema`"><PhArrowCounterClockwise :size="16" /></button>
              <button v-if="i.kategori === 'tambahan'" class="tombol-ikon h-9 w-9" @click="hapusItem(i)" :aria-label="`Hapus ${i.label}`"><PhTrash :size="16" /></button>
            </div>
          </li>
          <li v-if="!pendapatan.length" class="px-3 py-3 text-sm text-teks3">Belum ada komponen. Lengkapi data pegawai atau tarif, atau tetapkan jumlah diterima.</li>
        </ul>
      </section>

      <!-- Potongan -->
      <section>
        <div class="mb-1 flex items-center justify-between"><h3 class="judul-bagian">Potongan</h3>
          <button v-if="boleh" class="tombol-teks min-h-[36px] text-sm" @click="bukaTambah('potongan')"><PhPlus :size="16" weight="bold" /> Potongan lain</button></div>
        <ul class="divide-y divide-garis rounded-xl border border-garis">
          <li v-for="i in potongan" :key="i.id" class="flex items-start gap-2 px-3 py-2.5">
            <div class="min-w-0 flex-1"><p class="font-semibold">{{ i.label }}</p><p v-if="i.alasan" class="text-xs text-teks3">{{ i.alasan }}</p></div>
            <p class="shrink-0 font-bold tabular-nums">{{ rupiah(i.besaran) }}</p>
            <div v-if="boleh" class="flex shrink-0">
              <button class="tombol-ikon h-9 w-9" @click="bukaUbah(i)" :aria-label="`Ubah ${i.label}`"><PhPencilSimple :size="16" /></button>
              <button v-if="i.kategori === 'potongan_lain'" class="tombol-ikon h-9 w-9" @click="hapusItem(i)" :aria-label="`Hapus ${i.label}`"><PhTrash :size="16" /></button>
            </div>
          </li>
          <li v-if="!potongan.length" class="px-3 py-3 text-sm text-teks3">Tidak ada potongan.</li>
        </ul>
      </section>

      <!-- Jumlah -->
      <div class="w-presensi rounded-xl p-4" style="background: color-mix(in srgb, var(--c) 10%, rgb(var(--permukaan)))">
        <div class="grid grid-cols-3 gap-2 text-sm">
          <p><span class="block text-teks3">Menurut skema</span><span class="font-semibold tabular-nums">{{ rupiah(b.total_skema) }}</span></p>
          <p><span class="block text-teks3">Pendapatan</span><span class="font-semibold tabular-nums">{{ rupiah(b.total_pendapatan) }}</span></p>
          <p><span class="block text-teks3">Potongan</span><span class="font-semibold tabular-nums">{{ rupiah(b.total_potongan) }}</span></p>
        </div>
        <p class="mt-3 text-sm text-teks3">Jumlah diterima</p>
        <p class="text-3xl font-extrabold tabular-nums" style="color: var(--c)">{{ rupiah(b.diterima) }}</p>
        <p class="text-sm italic text-teks2">{{ terbilang(b.diterima) }}</p>
        <p v-if="b.target_diterima != null" class="mt-1 text-xs text-teks2">Ditetapkan langsung: {{ b.alasan_target }}</p>
      </div>

      <!-- Formulir -->
      <div v-if="mode === 'ubah' && ubah" class="space-y-3 rounded-xl border border-garis p-3">
        <div class="flex items-center justify-between"><p class="font-bold">Ubah {{ ubah.i.label }}</p><button class="tombol-ikon h-9 w-9" @click="mode = ''" aria-label="Batal"><PhX :size="18" /></button></div>
        <div v-if="ubah.i.kategori === 'honor'"><label class="label-isian" for="bg-jam">Jumlah jam</label>
          <input id="bg-jam" v-model="ubah.jumlah" inputmode="decimal" class="isian tabular-nums" />
          <p class="mt-1 text-xs text-teks3">× {{ rupiah(ubah.i.tarif) }} = {{ rupiah(Math.round(Number(String(ubah.jumlah).replace(',', '.')) * ubah.i.tarif) || 0) }}</p></div>
        <div v-else><label class="label-isian" for="bg-nom">Nominal</label>
          <input id="bg-nom" v-model="ubah.besaran" inputmode="numeric" class="isian tabular-nums" />
          <p class="mt-1 text-xs text-teks3">{{ ubah.i.besaran_skema != null ? `Menurut skema ${rupiah(ubah.i.besaran_skema)}. ` : '' }}Isi 0 bila tidak diberikan.</p></div>
        <div><label class="label-isian" for="bg-als">Alasan perubahan</label><input id="bg-als" v-model="ubah.alasan" class="isian" placeholder="Contoh: Ketetapan Ketua Yayasan" /></div>
        <button class="tombol-utama w-full" :disabled="proses" @click="simpanUbah"><PhFloppyDisk :size="20" weight="duotone" /> Simpan perubahan</button>
      </div>
      <div v-else-if="mode === 'terima' && fTerima" class="space-y-3 rounded-xl border border-garis p-3">
        <div class="flex items-center justify-between"><p class="font-bold">Tetapkan jumlah diterima</p><button class="tombol-ikon h-9 w-9" @click="mode = ''" aria-label="Batal"><PhX :size="18" /></button></div>
        <p class="text-sm text-teks2">Isi nominal yang benar-benar diterima. Selisihnya dengan hasil hitung ({{ rupiah(dasarTerima) }}) tampil sebagai "{{ gaji.pengaturan.label_penyesuaian }}".</p>
        <div><label class="label-isian" for="bg-trm">Jumlah diterima</label><input id="bg-trm" v-model="fTerima.nilai" inputmode="numeric" class="isian text-lg font-bold tabular-nums" />
          <p class="mt-1 text-xs text-teks3">{{ bacaRupiah(fTerima.nilai) != null ? terbilang(bacaRupiah(fTerima.nilai)) : '' }}</p></div>
        <div><label class="label-isian" for="bg-tal">Keterangan</label><input id="bg-tal" v-model="fTerima.alasan" class="isian" /></div>
        <div class="flex gap-2">
          <button v-if="b.target_diterima != null" class="tombol-garis" :disabled="proses" @click="hapusTerima">Hapus penetapan</button>
          <button class="tombol-utama flex-1" :disabled="proses" @click="simpanTerima"><PhFloppyDisk :size="20" weight="duotone" /> Simpan</button>
        </div>
      </div>
      <div v-else-if="mode === 'tambah' && fTambah" class="space-y-3 rounded-xl border border-garis p-3">
        <div class="flex items-center justify-between"><p class="font-bold">{{ fTambah.jenis === 'pendapatan' ? 'Tambah pendapatan lain' : 'Tambah potongan lain' }}</p>
          <button class="tombol-ikon h-9 w-9" @click="mode = ''" aria-label="Batal"><PhX :size="18" /></button></div>
        <div><label class="label-isian" for="bg-lbl">Nama komponen</label><input id="bg-lbl" v-model="fTambah.label" class="isian" :placeholder="fTambah.jenis === 'pendapatan' ? 'Contoh: Insentif panitia ujian' : 'Contoh: Iuran koperasi'" /></div>
        <div><label class="label-isian" for="bg-bsr">Nominal</label><input id="bg-bsr" v-model="fTambah.besaran" inputmode="numeric" class="isian tabular-nums" /></div>
        <div><label class="label-isian" for="bg-tal2">Keterangan (tidak wajib)</label><input id="bg-tal2" v-model="fTambah.alasan" class="isian" /></div>
        <button class="tombol-utama w-full" :disabled="proses" @click="simpanTambah"><PhPlus :size="20" weight="bold" /> Tambahkan</button>
      </div>

      <div v-if="boleh && !mode" class="flex flex-wrap gap-2">
        <button class="tombol-utama flex-1" @click="bukaTerima"><PhHandCoins :size="20" weight="duotone" /> Tetapkan jumlah diterima</button>
        <button class="tombol-garis" @click="keluarkan"><PhTrash :size="20" /> Keluarkan dari periode</button>
      </div>
      <p v-else-if="!boleh" class="text-sm text-teks3">{{ periode?.status === 'draf' ? 'Hanya pengelola gaji yang dapat mengubah.' : 'Periode ini tidak lagi dapat diubah.' }}
        Dibayar {{ formatPendek(periode?.tanggal_bayar) }}.</p>
    </div>
  </LembarBawah>
</template>
