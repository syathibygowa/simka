<!-- SIMKA PRO | src/pages/gaji/LembarImporKomponen.vue | v1.0 | Fase 11 – Pelengkap: impor Excel jam honor, potongan lain, dan tambahan | 11/10/2026 -->
<script setup>
// Impor komponen gaji dari Excel untuk satu periode (draf):
//   Jam guru / Jam muhaffizh → mengganti jumlah jam honor (honor dihitung ulang × tarif honorer)
//   Potongan lain / Tambahan → komponen manual berlabel keterangannya; impor ulang mengganti hasil impor sebelumnya (tidak menumpuk)
// Kolom kosong = tidak diubah. Setiap perubahan tercatat di log audit dengan alasan "Impor Excel".
import { ref, computed } from 'vue'
import * as XLSX from 'xlsx'
import { PhDownloadSimple, PhUploadSimple, PhCheckCircle } from '@phosphor-icons/vue'
import { useGaji } from '@/stores/gaji'
import { useUI } from '@/stores/ui'
import { namaPeriode, bacaRupiah, angka } from '@/lib/gaji'
import LembarBawah from '@/components/LembarBawah.vue'

const props = defineProps({ periode: { type: Object, default: null }, baris: { type: Array, default: () => [] } })
const emit = defineEmits(['tutup', 'selesai'])
const gaji = useGaji(); const ui = useUI()
const buka = computed({ get: () => !!props.periode, set: (v) => !v && ((isi.value = null), (hasil.value = null), emit('tutup')) })
const isi = ref(null); const hasil = ref(null); const proses = ref(false); const masukan = ref(null)
const KOLOM = ['NIY', 'Nama', 'Jam guru', 'Jam muhaffizh', 'Potongan lain (Rp)', 'Keterangan potongan', 'Tambahan (Rp)', 'Keterangan tambahan']
const jam = (b, kode) => { const i = b.item.find((x) => x.kategori === 'honor' && x.kode === kode); return i ? Number(i.jumlah) : '' }
const impor = (b, kat) => b.item.filter((x) => x.kategori === kat && x.alasan === 'Impor Excel')

function templat() {
  const data = props.baris.map((b) => { const p = impor(b, 'potongan_lain')[0]; const t = impor(b, 'tambahan')[0]
    return [b.data.niy || '', b.data.nama, jam(b, 'guru'), jam(b, 'muhaffizh'), p ? Number(p.besaran) : '', p?.label || '', t ? Number(t.besaran) : '', t?.label || ''] })
  const ws = XLSX.utils.aoa_to_sheet([KOLOM, ...data])
  for (let i = 1; i <= data.length; i++) { const a = XLSX.utils.encode_cell({ r: i, c: 0 }); if (ws[a]) { ws[a].t = 's'; ws[a].z = '@' } }
  ws['!cols'] = [12, 32, 10, 13, 16, 26, 14, 26].map((wch) => ({ wch }))
  const wb = XLSX.utils.book_new(); XLSX.utils.book_append_sheet(wb, ws, 'Komponen'); XLSX.writeFile(wb, `Templat-Komponen-Gaji-${namaPeriode(props.periode).replace(' ', '-')}.xlsx`)
}
async function bacaBerkas(e) {
  const berkas = e.target.files?.[0]; e.target.value = ''
  if (!berkas) return
  try {
    const wb = XLSX.read(await berkas.arrayBuffer())
    const aoa = XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]], { header: 1, raw: false, defval: '' })
    const iJ = aoa.findIndex((x) => x.some((c) => /^niy$/i.test(String(c).trim())))
    if (iJ < 0) throw new Error('Kolom NIY tidak ditemukan. Pakai berkas dari tombol "Unduh templat".')
    const j = aoa[iJ].map((c) => String(c).trim().toLowerCase())
    const k = (awal) => j.findIndex((c) => c.startsWith(awal))
    const kk = { niy: j.indexOf('niy'), nama: k('nama'), jg: k('jam guru'), jm: k('jam muhaffizh'), pot: k('potongan'), kp: k('keterangan potongan'), tam: k('tambahan'), kt: k('keterangan tambahan') }
    const sel = (x, i) => (i >= 0 ? String(x[i] ?? '').trim() : '')
    const baris = aoa.slice(iJ + 1).filter((x) => sel(x, kk.niy)).map((x) => ({ niy: sel(x, kk.niy), nama: sel(x, kk.nama),
      jam_guru: sel(x, kk.jg) || null, jam_muhaffizh: sel(x, kk.jm) || null,
      potongan: sel(x, kk.pot) !== '' ? String(bacaRupiah(sel(x, kk.pot)) ?? 0) : null, ket_potongan: sel(x, kk.kp),
      tambahan: sel(x, kk.tam) !== '' ? String(bacaRupiah(sel(x, kk.tam)) ?? 0) : null, ket_tambahan: sel(x, kk.kt) }))
      .filter((x) => x.jam_guru || x.jam_muhaffizh || x.potongan != null || x.tambahan != null)
    if (!baris.length) throw new Error('Tidak ada baris yang terisi.')
    isi.value = baris; hasil.value = null
  } catch (err) { ui.toast(err.message, 'galat') }
}
async function jalankan() {
  proses.value = true
  try { hasil.value = await gaji.imporKomponen(props.periode.id, isi.value); ui.toast(`${hasil.value.filter((x) => x.hasil === 'diubah').length} pegawai diperbarui.`); emit('selesai') }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
const hasilNiy = (niy) => hasil.value?.find((x) => x.niy === niy)
</script>
<template>
  <LembarBawah v-model="buka" judul="Impor jam honor, potongan, dan tambahan" lebar>
    <div class="space-y-4 pb-2">
      <p class="text-sm text-teks2">Unduh templat (berisi isian saat ini), ubah di Excel, lalu unggah kembali. Kolom kosong tidak mengubah apa pun.
        Isi 0 pada potongan/tambahan untuk menghapus hasil impor sebelumnya.</p>
      <div class="flex flex-wrap gap-2">
        <button class="tombol-garis" @click="templat"><PhDownloadSimple :size="20" /> Unduh templat</button>
        <button class="tombol-utama" @click="masukan.click()"><PhUploadSimple :size="20" weight="duotone" /> Pilih berkas Excel</button>
        <input ref="masukan" type="file" accept=".xlsx,.xls" class="hidden" @change="bacaBerkas" />
      </div>
      <div v-if="isi" class="max-h-80 overflow-auto rounded-xl border border-garis">
        <table class="w-full text-left text-sm">
          <thead class="sticky top-0 bg-permukaan2"><tr><th class="px-2 py-2">NIY</th><th class="px-2 py-2">Nama</th><th class="px-2 py-2 text-right">Jam guru</th><th class="px-2 py-2 text-right">Jam muhaffizh</th>
            <th class="px-2 py-2 text-right">Potongan</th><th class="px-2 py-2 text-right">Tambahan</th><th class="px-2 py-2">Hasil</th></tr></thead>
          <tbody class="divide-y divide-garis"><tr v-for="x in isi" :key="x.niy">
            <td class="px-2 py-1.5 tabular-nums">{{ x.niy }}</td><td class="px-2 py-1.5">{{ x.nama }}</td>
            <td class="px-2 py-1.5 text-right tabular-nums">{{ x.jam_guru ?? '–' }}</td><td class="px-2 py-1.5 text-right tabular-nums">{{ x.jam_muhaffizh ?? '–' }}</td>
            <td class="px-2 py-1.5 text-right tabular-nums">{{ x.potongan != null ? angka(x.potongan) : '–' }}</td><td class="px-2 py-1.5 text-right tabular-nums">{{ x.tambahan != null ? angka(x.tambahan) : '–' }}</td>
            <td class="px-2 py-1.5 text-xs"><template v-if="hasilNiy(x.niy)"><span :class="['font-semibold', hasilNiy(x.niy).hasil === 'diubah' ? 'w-presensi' : 'w-klinik']" style="color: var(--c)">
              {{ hasilNiy(x.niy).hasil === 'diubah' ? 'Tersimpan' : hasilNiy(x.niy).hasil === 'lewati' ? 'Dilewati' : 'Galat' }}</span> {{ hasilNiy(x.niy).ket }}</template></td>
          </tr></tbody>
        </table>
      </div>
      <button v-if="isi && !hasil" class="tombol-utama w-full" :disabled="proses" @click="jalankan"><PhUploadSimple :size="20" weight="duotone" /> {{ proses ? 'Menyimpan…' : `Simpan ${isi.length} baris` }}</button>
      <button v-else-if="hasil" class="tombol-garis w-full" @click="buka = false"><PhCheckCircle :size="20" /> Selesai</button>
    </div>
  </LembarBawah>
</template>
