<!-- SIMKA PRO | src/pages/pengajuan/FormPengajuan.vue | v1.0 | Fase 3 – Tahap 2 Pengajuan berjenjang | 04/10/2026 -->
<script setup>
// Formulir pengajuan izin, sakit, dinas luar, dan cuti. Aturan (lama, kuota, batas tanggal, lampiran, jenjang)
// diperiksa langsung oleh server saat isian berubah, sehingga pegawai tahu sebelum mengirim.
import { ref, computed, watch } from 'vue'
import { PhPaperclip, PhWarningCircle, PhWarning, PhCheckCircle, PhArrowRight, PhX, PhFilePdf, PhImage } from '@phosphor-icons/vue'
import { usePengajuan } from '@/stores/pengajuan'
import { useLembaga } from '@/stores/lembaga'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { MODE_DEMO } from '@/lib/supabase'
import { hariIniISO, formatPanjang } from '@/lib/tanggal'
import { KELOMPOK, kalimatAturan, hitungHari } from '@/lib/pengajuan'
import { unggahKeDrive, kompresGambar, namaRapi } from '@/lib/penyimpanan'
import InputTanggal from '@/components/InputTanggal.vue'

const emit = defineEmits(['selesai'])
const pg = usePengajuan(); const lembaga = useLembaga(); const sesi = useSesi(); const ui = useUI()
const f = ref({ leave_type_id: '', mulai: hariIniISO(), selesai: hariIniISO(), alasan: '', alamat_selama: '', kop_kode: 'pondok' })
const berkas = ref(null); const cek = ref(null); const memeriksa = ref(false); const kirim = ref(false)

const jenisTampil = computed(() => pg.jenisAktif.filter((j) => !j.khusus_jk || !sesi.pengguna?.jenis_kelamin || j.khusus_jk === sesi.pengguna.jenis_kelamin))
const jenis = computed(() => pg.jenis.find((j) => j.id === f.value.leave_type_id))
const jumlah = computed(() => hitungHari(f.value.mulai, f.value.selesai))

function pilih(j) {
  f.value.leave_type_id = j.id
  if (j.maju_maks_hari === 0) f.value.mulai = hariIniISO()
  if (j.maju_min_hari > 0 && f.value.mulai < tambah(hariIniISO(), j.maju_min_hari)) f.value.mulai = tambah(hariIniISO(), j.maju_min_hari)
  if (f.value.selesai < f.value.mulai) f.value.selesai = f.value.mulai
}
const tambah = (iso, n) => new Date(Date.parse(iso + 'T00:00:00Z') + n * 86400000).toISOString().slice(0, 10)
watch(() => f.value.mulai, (m) => { if (m && f.value.selesai < m) f.value.selesai = m })

let jeda = null
watch(() => [f.value.leave_type_id, f.value.mulai, f.value.selesai], () => {
  clearTimeout(jeda)
  if (!f.value.leave_type_id || !f.value.mulai || !f.value.selesai) { cek.value = null; return }
  jeda = setTimeout(async () => {
    memeriksa.value = true
    try { cek.value = await pg.periksa({ leave_type_id: f.value.leave_type_id, mulai: f.value.mulai, selesai: f.value.selesai }) }
    catch (e) { cek.value = { galat: [e.message], jenjang: [] } } finally { memeriksa.value = false }
  }, 350)
})

function pilihBerkas(e) {
  const b = e.target.files?.[0]; e.target.value = ''
  if (!b) return
  if (!/^image\/|application\/pdf/.test(b.type)) return ui.toast('Lampiran harus berupa foto atau PDF.', 'galat')
  if (b.type === 'application/pdf' && b.size > 5 * 1024 * 1024) return ui.toast('Ukuran PDF paling besar 5 MB.', 'galat')
  berkas.value = b
}

const bisaKirim = computed(() => cek.value && !cek.value.galat?.length && f.value.alasan.trim().length >= 5
  && (!cek.value.lampiran_wajib || berkas.value) && cek.value.jenjang?.length && !memeriksa.value)

async function ajukan() {
  if (!bisaKirim.value) return
  if (!(await ui.konfirmasi({ judul: 'Kirim pengajuan?', pesan: `${jenis.value.nama} ${jumlah.value} hari (${formatPanjang(f.value.mulai)}${jumlah.value > 1 ? ' s.d. ' + formatPanjang(f.value.selesai) : ''}). Pengajuan diteruskan kepada ${cek.value.jenjang[0].nama_peran}.`, ya: 'Kirim' }))) return
  kirim.value = true
  try {
    let lampiran_id = null
    if (berkas.value && !MODE_DEMO) {
      const blob = berkas.value.type === 'application/pdf' ? berkas.value : await kompresGambar(berkas.value, { maks: 1600, kualitas: 0.7 })
      const t = hariIniISO()
      lampiran_id = await unggahKeDrive(blob, { nama: namaRapi('Pengajuan', jenis.value.kode, sesi.pengguna?.niy || sesi.namaPendek, t) + (blob.type === 'application/pdf' ? '.pdf' : '.jpg'),
        kategori: 'pengajuan', folder: `SIMKA PRO/Pengajuan/${t.slice(0, 4)}/${t.slice(5, 7)}` })
    }
    const id = await pg.ajukan({ ...f.value, lampiran_id })
    ui.toast('Pengajuan terkirim. Anda akan mendapat notifikasi setiap ada keputusan.', 'info')
    emit('selesai', id)
  } catch (e) { ui.toast(e.message, 'galat') } finally { kirim.value = false }
}
</script>
<template>
  <form class="space-y-4 pb-2" @submit.prevent="ajukan">
    <fieldset>
      <legend class="label-isian">Jenis pengajuan</legend>
      <div class="grid grid-cols-2 gap-2 sm:grid-cols-3">
        <button v-for="j in jenisTampil" :key="j.id" type="button" @click="pilih(j)" :aria-pressed="f.leave_type_id === j.id"
          :class="['jenis flex min-h-[56px] items-center gap-2 rounded-xl border px-2.5 text-left text-sm font-semibold', 'w-' + KELOMPOK[j.kelompok].w, f.leave_type_id === j.id ? 'aktif' : 'border-garis bg-permukaan text-teks2']">
          <span class="chip-ikon h-8 w-8 shrink-0 rounded-lg"><component :is="KELOMPOK[j.kelompok].ikon" :size="18" weight="duotone" /></span>{{ j.nama }}</button>
      </div>
    </fieldset>

    <div v-if="jenis" :class="['rounded-xl p-3 text-sm', 'w-' + KELOMPOK[jenis.kelompok].w]" style="background: color-mix(in srgb, var(--c) 9%, rgb(var(--permukaan)))">
      <p v-if="jenis.keterangan" class="text-teks">{{ jenis.keterangan }}</p>
      <ul class="mt-1 list-disc space-y-0.5 pl-5 text-teks2"><li v-for="k in kalimatAturan(jenis)" :key="k">{{ k }}</li></ul>
    </div>

    <template v-if="jenis">
      <div class="grid gap-3 sm:grid-cols-2">
        <InputTanggal v-model="f.mulai" label="Tanggal mulai" wajib />
        <InputTanggal v-model="f.selesai" label="Tanggal selesai" wajib />
      </div>
      <p class="text-sm font-semibold text-teks2">Lama: <span class="text-teks">{{ jumlah > 0 ? jumlah + ' hari' : '–' }}</span> (dihitung hari kalender)</p>
      <div><label class="label-isian" for="pj-alasan">Alasan</label>
        <textarea id="pj-alasan" v-model="f.alasan" class="isian min-h-[6rem] py-2" required :placeholder="jenis.kelompok === 'sakit' ? 'Contoh: demam tinggi dan disarankan istirahat oleh dokter.' : 'Tuliskan keperluan dengan jelas.'" /></div>
      <div v-if="jenis.kelompok === 'cuti' || jumlah > 3"><label class="label-isian" for="pj-alamat">Alamat/kontak selama {{ jenis.kelompok === 'cuti' ? 'cuti' : 'izin' }} (opsional)</label>
        <input id="pj-alamat" v-model="f.alamat_selama" class="isian" placeholder="Contoh: Jl. Poros Malino, Gowa · 0812…" /></div>

      <div>
        <p class="label-isian">Lampiran bukti <span v-if="cek?.lampiran_wajib" class="font-bold text-[rgb(var(--merah))]">(wajib)</span><span v-else class="text-teks3">(opsional)</span></p>
        <div v-if="berkas" class="flex items-center gap-3 rounded-xl border border-garis p-3">
          <component :is="berkas.type === 'application/pdf' ? PhFilePdf : PhImage" :size="26" weight="duotone" class="text-teks2" />
          <span class="min-w-0 flex-1 truncate text-sm font-semibold">{{ berkas.name }}</span>
          <button type="button" class="tombol-ikon" aria-label="Hapus lampiran" @click="berkas = null"><PhX :size="20" /></button>
        </div>
        <label v-else class="tombol-garis w-full cursor-pointer justify-center"><PhPaperclip :size="20" weight="duotone" /> Pilih foto atau PDF
          <input type="file" accept="image/*,application/pdf" class="sr-only" @change="pilihBerkas" /></label>
        <p v-if="cek?.lampiran_keterangan" class="mt-1 text-xs text-teks3">{{ cek.lampiran_keterangan }}. Foto dikompres otomatis; PDF paling besar 5 MB.</p>
      </div>

      <details class="rounded-xl border border-garis p-3 text-sm">
        <summary class="cursor-pointer font-semibold text-teks2">Kop surat dokumen</summary>
        <select v-model="f.kop_kode" class="isian mt-2" aria-label="Kop surat"><option v-for="k in lembaga.letterheads" :key="k.kode" :value="k.kode">{{ k.nama }}</option></select>
      </details>

      <!-- Hasil pemeriksaan server -->
      <div v-if="cek" class="space-y-2" aria-live="polite">
        <p v-for="g in cek.galat" :key="g" class="w-beranda flex gap-2 rounded-xl p-3 text-sm font-semibold text-teks" style="background: color-mix(in srgb, var(--c) 10%, rgb(var(--permukaan)))">
          <PhWarningCircle :size="20" weight="duotone" class="mt-0.5 shrink-0" style="color: var(--c)" />{{ g }}</p>
        <p v-for="g in cek.peringatan" :key="g" class="w-tahfizh flex gap-2 rounded-xl p-3 text-sm text-teks" style="background: color-mix(in srgb, var(--c) 10%, rgb(var(--permukaan)))">
          <PhWarning :size="20" weight="duotone" class="mt-0.5 shrink-0" style="color: var(--c)" />{{ g }} Pengajuan tetap dapat dikirim dengan tanda melebihi kuota.</p>
        <div v-if="!cek.galat?.length && cek.jenjang?.length" class="rounded-xl border border-garis p-3">
          <p class="mb-2 text-sm font-bold">Alur persetujuan</p>
          <ol class="space-y-2">
            <li v-for="s in cek.jenjang" :key="s.urutan" class="flex gap-2 text-sm">
              <span class="grid h-6 w-6 shrink-0 place-items-center rounded-full bg-permukaan2 text-xs font-bold">{{ s.urutan }}</span>
              <span class="min-w-0"><span :class="['font-semibold', !s.ada_pejabat && 'text-teks3 line-through']">{{ s.nama_peran }}</span>
                <span v-if="s.ada_pejabat" class="block text-xs text-teks3">{{ s.pejabat.join(' · ') }}</span>
                <span v-else class="block text-xs text-teks3">Dilewati karena belum ada pejabat untuk Anda</span></span>
            </li>
          </ol>
        </div>
        <p v-else-if="!cek.galat?.length && !memeriksa" class="text-sm font-semibold text-teks2">Belum ada pejabat penyetuju yang terdaftar. Hubungi admin agar jabatan struktural diisi di Data Pegawai.</p>
      </div>

      <button class="tombol-utama w-full" :disabled="!bisaKirim || kirim">
        <component :is="bisaKirim ? PhCheckCircle : PhArrowRight" :size="20" weight="duotone" />
        {{ kirim ? 'Mengirim…' : memeriksa ? 'Memeriksa aturan…' : 'Kirim pengajuan' }}</button>
    </template>
    <p v-else class="text-sm text-teks3">Pilih jenis pengajuan untuk melihat aturannya.</p>
  </form>
</template>
<style scoped>
.jenis.aktif { border-color: transparent; color: rgb(var(--teks)); background: color-mix(in srgb, var(--c) 13%, rgb(var(--permukaan))); box-shadow: inset 0 0 0 2px var(--c); }
</style>
