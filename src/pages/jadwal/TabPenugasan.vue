<!-- SIMKA PRO | src/pages/jadwal/TabPenugasan.vue | v1.0 | Fase 4 – Tahap 5 Jadwal pelajaran dan jurnal mengajar | 04/10/2026 -->
<script setup>
// Penugasan mengajar per kelas: mapel, guru, JP per pekan. Tambah/ubah/hapus, impor dan ekspor Excel.
import { ref, computed, onMounted } from 'vue'
import * as XLSX from 'xlsx'
import { PhPlus, PhPencilSimple, PhFileXls, PhDownloadSimple, PhUploadSimple, PhTrash } from '@phosphor-icons/vue'
import { useJadwal } from '@/stores/jadwal'
import { useKelompokSantri } from '@/stores/kelompokSantri'
import { usePegawai } from '@/stores/pegawai'
import { useOrganisasi } from '@/stores/organisasi'
import { useUI } from '@/stores/ui'
import { judulKelompok } from '@/lib/santri'
import LembarBawah from '@/components/LembarBawah.vue'

const props = defineProps({ bolehAtur: Boolean })
const jd = useJadwal(); const kel = useKelompokSantri(); const peg = usePegawai(); const org = useOrganisasi(); const ui = useUI()
onMounted(async () => { await Promise.all([kel.muat(), jd.muat(), org.muat()]); if (props.bolehAtur && !peg.daftar.length) peg.muat() })
const kelasList = computed(() => kel.dariTA.filter((g) => g.jenis === 'kelas' && g.aktif))
const perKelas = computed(() => kelasList.value.map((g) => ({ g, t: jd.penugasan.filter((x) => x.group_id === g.id) })).filter((x) => x.t.length || props.bolehAtur))
const terjadwal = (id) => jd.jadwal.filter((s) => s.assignment_id === id).length

const lembar = ref(false); const f = ref(null); const proses = ref(false)
function buka(g, t = null) { f.value = t ? { id: t.id, group_id: t.group_id, subject_id: t.subject_id, employee_id: t.employee_id, jp_pekan: t.jp_pekan, catatan: t.catatan || '' } : { group_id: g.id, subject_id: '', employee_id: '', jp_pekan: 2, catatan: '' }; lembar.value = true }
const gF = computed(() => kel.cari(f.value?.group_id))
const mapelF = computed(() => jd.mapel.filter((m) => m.aktif && (m.jenjang === 'semua' || m.jenjang === gF.value?.jenjang)))
const guruId = computed(() => org.fungsional.find((x) => x.kode === 'GURU')?.id)
const guruF = computed(() => peg.daftar.filter((p) => (p.status_keaktifan || 'aktif') === 'aktif')
  .sort((a, b) => Number((b.fungsional_ids || []).includes(guruId.value)) - Number((a.fungsional_ids || []).includes(guruId.value)) || a.nama_lengkap.localeCompare(b.nama_lengkap, 'id')))
async function simpan() {
  if (!f.value.subject_id || !f.value.employee_id) return ui.toast('Pilih mapel dan guru.', 'galat')
  proses.value = true
  try { await jd.simpanPenugasan({ ...f.value, jp_pekan: Number(f.value.jp_pekan) }, peg.cari(f.value.employee_id)?.nama_lengkap); ui.toast('Penugasan disimpan. Jam Guru Mapel di Beban Kerja diperbarui dari jadwal.'); lembar.value = false }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
async function hapus() {
  if (!(await ui.konfirmasi({ judul: 'Hapus penugasan?', pesan: 'Jadwal pelajaran dari penugasan ini ikut terhapus.', ya: 'Hapus', bahaya: true }))) return
  try { await jd.hapusPenugasan(f.value.id); lembar.value = false; ui.toast('Penugasan dihapus.') } catch (e) { ui.toast(e.message, 'galat') }
}

// ---------- Excel ----------
function ekspor() {
  const isi = [['Guru (NIY atau nama)', 'Mapel (kode atau nama)', 'Kelas', 'JP per pekan', 'Info: JP terjadwal'],
    ...jd.penugasan.map((t) => [t.niy_guru || t.nama_guru, jd.cariMapel(t.subject_id)?.kode, kel.cari(t.group_id)?.nama, t.jp_pekan, terjadwal(t.id)])]
  const ws = XLSX.utils.aoa_to_sheet(isi); ws['!cols'] = [{ wch: 30 }, { wch: 22 }, { wch: 10 }, { wch: 12 }, { wch: 16 }]
  const wb = XLSX.utils.book_new(); XLSX.utils.book_append_sheet(wb, ws, 'Penugasan')
  const ref_ = XLSX.utils.aoa_to_sheet([['Kode mapel', 'Nama mapel', 'Jenjang'], ...jd.mapel.filter((m) => m.aktif).map((m) => [m.kode, m.nama, m.jenjang])])
  XLSX.utils.book_append_sheet(wb, ref_, 'Daftar mapel')
  XLSX.writeFile(wb, 'Penugasan-Mengajar-SIMKA.xlsx')
}
const hasil = ref(null)
async function impor(e) {
  const b = e.target.files?.[0]; e.target.value = ''; if (!b) return
  try {
    const wb = XLSX.read(await b.arrayBuffer())
    const aoa = XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]], { header: 1, defval: '', raw: false })
    const baris = aoa.slice(1).filter((r) => r[0] && r[1] && r[2]).map((r) => ({ guru: String(r[0]).trim(), mapel: String(r[1]).trim(), kelas: String(r[2]).trim(), jp: String(r[3] || '').trim() }))
    if (!baris.length) return ui.toast('Tidak ada baris penugasan. Kolom: Guru, Mapel, Kelas, JP per pekan.', 'galat')
    if (!(await ui.konfirmasi({ judul: `Impor ${baris.length} penugasan?`, pesan: 'Penugasan dengan kelas dan mapel yang sama akan diperbarui (guru dan JP).', ya: 'Impor' }))) return
    hasil.value = await jd.imporPenugasan(baris)
    const gagal = hasil.value.filter((h) => !h.ok).length
    ui.toast(gagal ? `${hasil.value.length - gagal} berhasil, ${gagal} gagal (lihat rincian).` : `${hasil.value.length} penugasan diimpor.`, gagal ? 'galat' : 'info')
  } catch { ui.toast('Berkas tidak dapat dibaca.', 'galat') }
}
</script>
<template>
  <div>
    <div class="-mx-4 mb-4 flex gap-2 overflow-x-auto px-4 pb-1 lg:mx-0 lg:px-0">
      <button class="w-santri tombol-garis shrink-0 px-4 text-sm" @click="ekspor"><PhDownloadSimple :size="20" weight="duotone" style="color: var(--c)" /> {{ bolehAtur ? 'Ekspor / templat Excel' : 'Ekspor Excel' }}</button>
      <label v-if="bolehAtur" class="w-gaji tombol-garis shrink-0 cursor-pointer px-4 text-sm"><PhUploadSimple :size="20" weight="duotone" style="color: var(--c)" /> Impor Excel
        <input type="file" accept=".xlsx,.xls,.csv" class="sr-only" @change="impor" /></label>
    </div>
    <ul v-if="hasil?.some((h) => !h.ok)" class="kartu w-klinik mb-4 space-y-1 p-4 text-sm">
      <li v-for="h in hasil.filter((x) => !x.ok)" :key="h.baris"><b>Baris {{ h.baris + 1 }}:</b> <span style="color: var(--c)">{{ h.pesan }}</span></li>
    </ul>
    <div class="grid gap-3 lg:grid-cols-2">
      <section v-for="x in perKelas" :key="x.g.id" class="kartu w-laporan p-4">
        <div class="mb-2 flex items-center gap-2">
          <p class="flex-1 font-bold">{{ judulKelompok(x.g) }} <span class="text-sm font-normal text-teks3">· {{ x.t.reduce((n, t) => n + t.jp_pekan, 0) }} JP/pekan</span></p>
          <button v-if="bolehAtur" class="tombol-garis min-h-[36px] px-3 text-sm" @click="buka(x.g)"><PhPlus :size="16" weight="bold" /> Mapel</button>
        </div>
        <ul class="divide-y divide-garis">
          <li v-for="t in x.t" :key="t.id" class="flex items-center gap-2 py-2 text-sm">
            <span class="min-w-0 flex-1"><b class="block">{{ jd.cariMapel(t.subject_id)?.nama }}</b><span class="block truncate text-xs text-teks3">{{ t.nama_guru }}</span></span>
            <span :class="['tabular-nums font-semibold', terjadwal(t.id) < t.jp_pekan ? 'text-merah' : 'text-teks2']">{{ terjadwal(t.id) }}/{{ t.jp_pekan }} JP</span>
            <button v-if="bolehAtur" class="tombol-ikon h-9 w-9" :aria-label="`Ubah ${jd.cariMapel(t.subject_id)?.nama}`" @click="buka(x.g, t)"><PhPencilSimple :size="18" /></button>
          </li>
          <li v-if="!x.t.length" class="py-3 text-sm text-teks3">Belum ada penugasan.</li>
        </ul>
      </section>
    </div>
    <p v-if="!perKelas.length && !jd.memuat" class="kartu py-10 text-center text-sm text-teks3">Belum ada penugasan mengajar. Kelas dibuat di Kelompok Santri.</p>

    <LembarBawah v-model="lembar" :judul="f?.id ? 'Ubah penugasan' : `Tambah mapel ${judulKelompok(gF || {})}`">
      <div v-if="f" class="space-y-3 pb-2">
        <div><label class="label-isian" for="pn-m">Mata pelajaran *</label>
          <select id="pn-m" v-model="f.subject_id" class="isian"><option value="">Pilih mapel</option><option v-for="m in mapelF" :key="m.id" :value="m.id">{{ m.nama }} ({{ m.kode }})</option></select></div>
        <div><label class="label-isian" for="pn-g">Guru *</label>
          <select id="pn-g" v-model="f.employee_id" class="isian"><option value="">Pilih guru</option>
            <option v-for="p in guruF" :key="p.id" :value="p.id">{{ p.nama_lengkap }}{{ (p.fungsional_ids || []).includes(guruId) ? '' : ' (bukan jabatan Guru mapel)' }}</option></select>
          <p v-if="!peg.daftar.length" class="mt-1 text-xs text-teks3">Daftar pegawai hanya tersedia untuk admin.</p></div>
        <div><label class="label-isian" for="pn-jp">JP per pekan</label><input id="pn-jp" v-model.number="f.jp_pekan" type="number" min="0" max="40" class="isian" /></div>
        <div class="grid grid-cols-2 gap-2">
          <button v-if="f.id" class="tombol-garis" @click="hapus"><PhTrash :size="18" /> Hapus</button>
          <button :class="['tombol-utama', !f.id && 'col-span-2']" :disabled="proses" @click="simpan">{{ proses ? 'Menyimpan…' : 'Simpan' }}</button>
        </div>
      </div>
    </LembarBawah>
  </div>
</template>
