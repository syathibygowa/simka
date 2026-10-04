<!-- SIMKA PRO | src/pages/pengaturan/TabTemplateWA.vue | v1.0 | Fase 3 – Tahap 5 Agenda dan template WA | 04/10/2026 -->
<script setup>
// Template pesan WhatsApp (superadmin). Isian dalam kurung kurawal, misalnya {nama}, diganti otomatis saat pesan dibuat.
// Baris yang hanya berisi isian kosong dibuang. Pratinjau memakai data contoh.
import { ref, computed, onMounted } from 'vue'
import { PhPencilSimple, PhPlus, PhFloppyDisk, PhTrash, PhWhatsappLogo, PhArrowCounterClockwise } from '@phosphor-icons/vue'
import { useTemplatWA } from '@/stores/templatWA'
import { useUI } from '@/stores/ui'
import { isiTemplat, BAWAAN_WA } from '@/lib/wa'
import LembarBawah from '@/components/LembarBawah.vue'

const tw = useTemplatWA(); const ui = useUI()
const f = ref(null); const isian = ref(null)
onMounted(() => tw.muat().catch((e) => ui.toast(e.message, 'galat')))
const CONTOH = { nama: 'Ust. Hasan Basri, Lc.', username: 'hasanbasri', sandi: 'Rahasia#2026', catatan: 'NIY belum sesuai', judul: 'Rapat koordinasi', tanggal: 'Kamis, 08 Oktober 2026',
  waktu: '20.00–21.30 WITA', lokasi: 'Aula Utama', keterangan: 'Membawa catatan program bidang.', pengirim: 'Admin SIMKA PRO', jenis: 'izin', nomor: 'PGJ.007/PPTQ-IAS/X/2026', pesan: 'Isi pesan bebas.' }
const variabel = computed(() => [...new Set((f.value?.isi.match(/\{(\w+)\}/g) || []).map((x) => x.slice(1, -1)))])
const pratinjau = computed(() => (f.value ? isiTemplat(f.value.isi, CONTOH) : ''))
function ubah(t) { f.value = { ...t } }
function baru() { f.value = { _baru: true, kode: '', nama: '', isi: "Assalamu'alaikum warahmatullahi wabarakatuh, {nama}.\n\n{pesan}\n\nJazakumullahu khairan.\n{pengirim}", keterangan: '', aktif: true } }
function sisip(v) {
  const el = isian.value; const a = el?.selectionStart ?? f.value.isi.length; const b = el?.selectionEnd ?? a
  f.value.isi = f.value.isi.slice(0, a) + `{${v}}` + f.value.isi.slice(b)
}
async function simpan() {
  const t = { ...f.value, variabel: variabel.value }
  if (t._baru) t.kode = (t.kode || t.nama).toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_|_$/g, '').slice(0, 40)
  if (t.nama.trim().length < 3 || t.isi.trim().length < 5) return ui.toast('Nama dan isi template wajib diisi.', 'galat')
  try { await tw.simpan(t); f.value = null; ui.toast('Template WA disimpan.', 'info') } catch (e) { ui.toast(e.message, 'galat') }
}
async function hapus(t) {
  if (BAWAAN_WA[t.kode]) return ui.toast('Template bawaan sistem tidak dapat dihapus; nonaktifkan atau ubah isinya.', 'galat')
  if (!(await ui.konfirmasi({ judul: 'Hapus template?', pesan: t.nama, ya: 'Hapus', bahaya: true }))) return
  try { await tw.hapus(t.kode); f.value = null } catch (e) { ui.toast(e.message, 'galat') }
}
const VAR_UMUM = ['nama', 'pengirim', 'alamat_aplikasi', 'pesan', 'tanggal', 'judul']
</script>
<template>
  <div class="space-y-3">
    <div class="flex flex-wrap items-center gap-2">
      <p class="flex-1 text-sm text-teks2">Pesan dikirim admin melalui tombol WA (wa.me) dari HP-nya sendiri. Isian seperti <code>{nama}</code> terisi otomatis.</p>
      <button class="tombol-garis" @click="baru"><PhPlus :size="18" weight="bold" /> Template baru</button>
    </div>
    <ul class="grid gap-3 md:grid-cols-2">
      <li v-for="t in tw.daftar" :key="t.kode" :class="['kartu w-presensi p-4', !t.aktif && 'opacity-60']">
        <div class="flex items-start gap-2">
          <span class="chip-ikon h-9 w-9 shrink-0 rounded-lg"><PhWhatsappLogo :size="20" weight="duotone" /></span>
          <div class="min-w-0 flex-1"><p class="font-bold">{{ t.nama }}</p><p class="text-xs text-teks3">{{ t.kode }}{{ t.aktif ? '' : ' · nonaktif' }}</p></div>
          <button class="tombol-ikon -mr-2 -mt-1" :aria-label="`Ubah ${t.nama}`" @click="ubah(t)"><PhPencilSimple :size="20" /></button>
        </div>
        <p class="mt-2 line-clamp-4 whitespace-pre-line text-sm text-teks2">{{ t.isi }}</p>
        <p v-if="t.keterangan" class="mt-1 text-xs text-teks3">{{ t.keterangan }}</p>
      </li>
    </ul>

    <LembarBawah :model-value="!!f" @update:model-value="(v) => !v && (f = null)" :judul="f?._baru ? 'Template WA baru' : 'Ubah template WA'">
      <form v-if="f" class="space-y-3 pb-2" @submit.prevent="simpan">
        <div><label class="label-isian" for="tw-nama">Nama template</label><input id="tw-nama" v-model="f.nama" class="isian" /></div>
        <div>
          <label class="label-isian" for="tw-isi">Isi pesan</label>
          <textarea id="tw-isi" ref="isian" v-model="f.isi" class="isian min-h-[11rem] py-2 font-mono text-sm" />
          <div class="mt-1.5 flex flex-wrap gap-1.5"><span class="text-xs text-teks3">Sisipkan:</span>
            <button v-for="v in [...new Set([...(f.variabel || []), ...VAR_UMUM])]" :key="v" type="button" class="rounded-full border border-garis px-2.5 py-1 text-xs font-semibold text-teks2" @click="sisip(v)">{{ '{' + v + '}' }}</button></div>
          <p class="mt-1 text-xs text-teks3">Tulis *teks* untuk huruf tebal di WhatsApp.</p>
        </div>
        <div class="rounded-xl bg-permukaan2 p-3"><p class="mb-1 text-xs font-bold text-teks3">Pratinjau (data contoh)</p><p class="whitespace-pre-line text-sm">{{ pratinjau }}</p></div>
        <div><label class="label-isian" for="tw-ket">Keterangan penggunaan</label><input id="tw-ket" v-model="f.keterangan" class="isian" /></div>
        <label class="flex min-h-[44px] items-center gap-3 font-semibold"><input v-model="f.aktif" type="checkbox" class="h-5 w-5 accent-[#1E7D4F]" /> Aktif (bila nonaktif, isi bawaan sistem yang dipakai)</label>
        <div class="flex flex-wrap gap-2">
          <button class="tombol-utama flex-1"><PhFloppyDisk :size="20" weight="duotone" /> Simpan</button>
          <button v-if="BAWAAN_WA[f.kode]" type="button" class="tombol-garis" @click="f.isi = BAWAAN_WA[f.kode]"><PhArrowCounterClockwise :size="18" /> Isi bawaan</button>
          <button v-if="!f._baru && !BAWAAN_WA[f.kode]" type="button" class="tombol-garis" @click="hapus(f)"><PhTrash :size="18" /> Hapus</button>
        </div>
      </form>
    </LembarBawah>
  </div>
</template>
