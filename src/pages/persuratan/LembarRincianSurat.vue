<!-- SIMKA PRO | src/pages/persuratan/LembarRincianSurat.vue | v1.2 | Perbaikan 13.8.0: ringkasan dan catatan disposisi tampil dengan gaya teks | 16/10/2026 -->
<script setup>
// Rincian surat masuk: data surat, pindaian, alur disposisi berjenjang, dan tindakan sesuai peran:
//   pimpinan penerima : Disposisikan, Cukup diketahui (tutup tanpa disposisi)
//   penerima disposisi: Teruskan ke staf, Tandai selesai (laporan tindak lanjut)
//   pemberi disposisi : Tarik kembali (bila belum dibaca diteruskan/selesai)
//   Tata Usaha        : Ubah (selama belum didisposisi), Batalkan pencatatan
//   Cetak lembar disposisi F4.
// Membuka rincian otomatis menandai disposisi saya "dibaca".
import { ref, watch, computed } from 'vue'
import { PhStamp, PhPrinter, PhPencilSimple, PhProhibit, PhTrash, PhCheckCircle, PhArrowBendDownRight, PhShareFat, PhArrowUUpLeft, PhPaperclip,
  PhClock, PhEyeSlash, PhArrowLeft, PhCheck } from '@phosphor-icons/vue'
import { usePersuratan } from '@/stores/persuratan'
import { useUI } from '@/stores/ui'
import { SIFAT_SURAT, STATUS_SURAT, STATUS_DISPOSISI, namaCara, pohonDisposisi } from '@/lib/persuratan'
import { formatPanjang, formatPendek, formatWaktu } from '@/lib/tanggal'
import { MODE_DEMO } from '@/lib/supabase'
import { ambilBerkasUrl } from '@/lib/penyimpanan'
import { teksKaya } from '@/lib/teksKaya'
import LembarBawah from '@/components/LembarBawah.vue'
import FormDisposisi from './FormDisposisi.vue'
import CetakDisposisi from './CetakDisposisi.vue'

const buka = defineModel({ type: Boolean, default: false })
const props = defineProps({ id: { type: String, default: '' }, versi: { type: Number, default: 0 } })
const emit = defineEmits(['berubah', 'ubah'])
const ps = usePersuratan(); const ui = useUI()
const s = ref(null); const memuat = ref(false); const mode = ref('rincian'); const induk = ref(null); const pilihD = ref(null)
const teks = ref(''); const proses = ref(false); const cetak = ref(false); const rapikan = ref(true)
const bolehHapus = computed(() => !!(ps.hak.kelola || ps.hak.superadmin))
async function muat() {
  if (!props.id) return
  memuat.value = true
  try { s.value = await ps.rincian(props.id) } catch (e) { ui.toast(e.message, 'galat'); buka.value = false } finally { memuat.value = false }
}
watch(() => [buka.value, props.id], ([b]) => { if (b) { mode.value = 'rincian'; cetak.value = false; s.value = null; muat() } }, { immediate: true })
watch(() => props.versi, () => { if (buka.value && mode.value === 'rincian') muat() })
const alur = computed(() => pohonDisposisi(s.value?.disposisi || []))
const dispSaya = computed(() => (s.value?.disposisi || []).filter((d) => d.saya_penerima && d.status !== 'selesai'))

async function lihatBerkas(id, i) {
  if (MODE_DEMO) return ui.toast('Mode demo: pindaian tidak tersedia.')
  try { ui.toast(`Membuka pindaian ${i + 1}…`); window.open(await ambilBerkasUrl(id), '_blank', 'noopener') } catch (e) { ui.toast(e.message, 'galat') }
}
function keDisposisi(d = null) { induk.value = d; mode.value = 'disposisi' }
function keTeks(m, d = null) { pilihD.value = d; teks.value = ''; mode.value = m }
async function jalankan(fn, pesan) {
  proses.value = true
  try { await fn(); ui.toast(pesan); emit('berubah'); mode.value = 'rincian'; await muat() } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
function kirimTeks() {
  const t = teks.value.trim()
  if (mode.value === 'selesai') {
    if (t.length < 5) return ui.toast('Tuliskan laporan tindak lanjut (minimal 5 huruf).', 'galat')
    return jalankan(() => ps.selesaiDisposisi(pilihD.value.id, t), 'Disposisi ditandai selesai. Pemberi disposisi mendapat notifikasi.')
  }
  if (mode.value === 'tutup') return jalankan(() => ps.tutup(s.value.id, t), 'Surat ditutup (cukup diketahui).')
  if (mode.value === 'batal') {
    if (t.length < 5) return ui.toast('Tuliskan alasan pembatalan (minimal 5 huruf).', 'galat')
    return jalankan(() => ps.batal(s.value.id, t), 'Pencatatan surat dibatalkan.')
  }
  if (mode.value === 'hapus') return hapus(t)
}
async function hapus(t) {
  if (t.length < 5) return ui.toast('Tuliskan alasan penghapusan (minimal 5 huruf).', 'galat')
  if (!(await ui.konfirmasi({ judul: 'Hapus surat ini?', pesan: `Surat ${s.value.nomor_agenda} beserta disposisinya dihapus permanen dari buku agenda.${rapikan.value ? ' Nomor agenda sesudahnya digeser naik.' : ''}`, ya: 'Hapus', bahaya: true }))) return
  proses.value = true
  try { const h = await ps.hapusMasuk(s.value.id, t, rapikan.value); ui.toast(`Surat dihapus${h?.digeser ? `; ${h.digeser} nomor agenda sesudahnya dirapikan` : ''}.`); emit('berubah'); buka.value = false }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
const tarik = (d) => jalankan(() => ps.tarik(d.id), `Disposisi kepada ${d.kepada} ditarik kembali.`)
const JUDUL_TEKS = { selesai: 'Tandai disposisi selesai', tutup: 'Cukup diketahui', batal: 'Batalkan pencatatan surat', hapus: 'Hapus surat salah catat' }
</script>
<template>
  <LembarBawah v-model="buka" :judul="s ? `Surat ${s.nomor_agenda}` : 'Rincian surat'" lebar>
    <p v-if="!s" class="py-10 text-center text-sm text-teks3">{{ memuat ? 'Memuat…' : '' }}</p>
    <div v-else-if="mode === 'rincian'" class="space-y-4 pb-2" :class="'w-' + SIFAT_SURAT[s.sifat].w">
      <div class="flex items-start gap-3">
        <span class="chip-ikon h-12 w-12"><component :is="SIFAT_SURAT[s.sifat].ikon" :size="26" weight="duotone" /></span>
        <div class="min-w-0 flex-1">
          <p class="flex flex-wrap items-center gap-1.5"><span class="lencana" :class="'w-' + STATUS_SURAT[s.status].w">{{ STATUS_SURAT[s.status].n }}</span>
            <span class="lencana" :class="'w-' + SIFAT_SURAT[s.sifat].w">{{ SIFAT_SURAT[s.sifat].n }}</span>
            <span v-if="s.lewat_batas" class="lencana w-klinik"><PhClock :size="12" weight="bold" /> Ada disposisi lewat batas</span></p>
          <h3 class="mt-1 text-lg font-bold leading-snug [overflow-wrap:anywhere]">{{ s.perihal }}</h3>
          <p class="text-sm text-teks2 [overflow-wrap:anywhere]">{{ s.pengirim }}{{ s.alamat_pengirim ? ', ' + s.alamat_pengirim : '' }}</p>
        </div>
      </div>

      <dl class="grid gap-x-4 gap-y-2 rounded-2xl bg-permukaan2 p-3 text-sm sm:grid-cols-2">
        <div><dt class="text-xs text-teks3">Nomor surat</dt><dd>{{ s.nomor_surat || '–' }}</dd></div>
        <div><dt class="text-xs text-teks3">Tanggal surat</dt><dd>{{ s.tanggal_surat ? formatPanjang(s.tanggal_surat) : '–' }}</dd></div>
        <div><dt class="text-xs text-teks3">Diterima</dt><dd>{{ formatPanjang(s.tanggal_terima) }} · {{ namaCara(s.cara) }}</dd></div>
        <div><dt class="text-xs text-teks3">Lampiran</dt><dd>{{ s.lampiran || '–' }}</dd></div>
        <div class="sm:col-span-2" v-if="s.ringkasan"><dt class="text-xs text-teks3">Ringkasan</dt><dd class="whitespace-pre-line" v-html="teksKaya(s.ringkasan)" /></div>
        <div><dt class="text-xs text-teks3">Diteruskan kepada</dt><dd>{{ s.tujuan ? `${s.tujuan} (${s.tujuan_jabatan})` : 'Diarsipkan tanpa disposisi' }}
          <span v-if="s.tujuan" class="block text-xs text-teks3">{{ s.dibaca_tujuan ? 'Dibaca ' + formatWaktu(s.dibaca_tujuan) : 'Belum dibaca' }}</span></dd></div>
        <div><dt class="text-xs text-teks3">Dicatat oleh</dt><dd>{{ s.dicatat_oleh || '–' }} <span class="block text-xs text-teks3">{{ formatWaktu(s.created_at) }}</span></dd></div>
        <div class="sm:col-span-2" v-if="s.catatan"><dt class="text-xs text-teks3">Catatan Tata Usaha</dt><dd>{{ s.catatan }}</dd></div>
        <div class="sm:col-span-2" v-if="s.catatan_selesai"><dt class="text-xs text-teks3">{{ s.status === 'batal' ? 'Alasan pembatalan' : 'Catatan penutup' }}</dt><dd>{{ s.catatan_selesai }}</dd></div>
      </dl>

      <div v-if="s.berkas_ids?.length" class="flex flex-wrap gap-2">
        <button v-for="(b, i) in s.berkas_ids" :key="b" type="button" class="tombol-garis min-h-[40px] px-3 text-sm" @click="lihatBerkas(b, i)">
          <PhPaperclip :size="18" /> Pindaian {{ i + 1 }}</button>
      </div>
      <p v-else class="flex items-center gap-1.5 text-xs text-teks3"><PhEyeSlash :size="14" /> Tidak ada pindaian surat.</p>

      <section>
        <h4 class="judul-bagian mb-2 flex items-center gap-2"><PhStamp :size="20" weight="duotone" class="text-[#B5501A]" /> Alur disposisi</h4>
        <p v-if="!alur.length" class="rounded-xl border border-dashed border-garis p-4 text-center text-sm text-teks3">
          {{ s.status === 'diteruskan' ? 'Menunggu disposisi pimpinan.' : 'Tidak ada disposisi.' }}</p>
        <ol v-else class="space-y-2">
          <li v-for="d in alur" :key="d.id" :style="{ marginLeft: Math.min(d.tingkat, 3) * 1.25 + 'rem' }"
            :class="['rounded-2xl border p-3 text-sm', d.saya_penerima && d.status !== 'selesai' ? 'border-[#C7332F] bg-[#C7332F]/5' : 'border-garis']">
            <p class="flex flex-wrap items-center gap-1.5">
              <PhArrowBendDownRight v-if="d.tingkat" :size="16" class="text-teks3" />
              <b>{{ d.dari }}</b><span class="text-teks3">→</span><b>{{ d.kepada }}</b>
              <span class="lencana" :class="'w-' + STATUS_DISPOSISI[d.status].w">{{ STATUS_DISPOSISI[d.status].n }}</span>
              <span v-if="d.lewat" class="lencana w-klinik">Lewat batas</span></p>
            <p class="text-xs text-teks3">{{ d.kepada_jabatan }} · {{ formatWaktu(d.created_at) }}<template v-if="d.batas"> · batas {{ formatPendek(d.batas) }}</template></p>
            <p v-if="d.instruksi?.length" class="mt-1.5 flex flex-wrap gap-1"><span v-for="t in d.instruksi" :key="t" class="lencana w-shift">{{ t }}</span></p>
            <p v-if="d.catatan" class="mt-1 whitespace-pre-line" v-html="teksKaya(d.catatan)" />
            <p v-if="d.laporan" class="mt-2 rounded-lg bg-permukaan2 px-2.5 py-1.5 text-xs"><b>Tindak lanjut ({{ formatWaktu(d.selesai_pada) }}):</b> {{ d.laporan }}</p>
            <div v-if="(d.saya_penerima && d.status !== 'selesai') || d.boleh_tarik" class="mt-2 flex flex-wrap gap-2">
              <template v-if="d.saya_penerima && d.status !== 'selesai'">
                <button class="tombol-garis min-h-[38px] px-3 text-sm" @click="keDisposisi(d)"><PhShareFat :size="18" /> Teruskan</button>
                <button class="tombol-utama min-h-[38px] px-3 text-sm" @click="keTeks('selesai', d)"><PhCheckCircle :size="18" weight="duotone" /> Tandai selesai</button>
              </template>
              <button v-if="d.boleh_tarik" class="tombol-teks min-h-[38px] px-3 text-sm" :disabled="proses" @click="tarik(d)"><PhArrowUUpLeft :size="18" /> Tarik</button>
            </div>
          </li>
        </ol>
      </section>

      <div class="flex flex-wrap gap-2 border-t border-garis pt-4">
        <button v-if="s.boleh.disposisi" class="tombol-utama" @click="keDisposisi(null)"><PhStamp :size="20" weight="duotone" /> {{ alur.some((d) => !d.induk_id) ? 'Tambah disposisi' : 'Disposisikan' }}</button>
        <button v-if="s.boleh.tutup" class="tombol-garis" @click="keTeks('tutup')"><PhCheck :size="20" /> Cukup diketahui</button>
        <button v-if="s.boleh.cetak" class="tombol-garis w-rekap" @click="cetak = true"><PhPrinter :size="20" style="color: var(--c)" /> Lembar disposisi</button>
        <button v-if="s.boleh.ubah" class="tombol-garis" @click="emit('ubah', s)"><PhPencilSimple :size="20" /> Ubah</button>
        <button v-if="s.boleh.batal" class="tombol-teks" @click="keTeks('batal')"><PhProhibit :size="20" /> Batalkan pencatatan</button>
        <button v-if="bolehHapus" class="tombol-teks text-merah" @click="rapikan = true; keTeks('hapus')"><PhTrash :size="20" /> Hapus (salah catat)</button>
      </div>
      <p v-if="dispSaya.length" class="text-xs text-teks3">Tandai selesai setelah tindak lanjut dilakukan; pemberi disposisi mendapat notifikasi.</p>
      <CetakDisposisi v-model:pratinjau="cetak" :surat="s" />
    </div>

    <FormDisposisi v-else-if="mode === 'disposisi'" :surat="s" :induk="induk" class="pb-2" @batal="mode = 'rincian'" @selesai="mode = 'rincian'; emit('berubah'); muat()" />

    <div v-else class="space-y-3 pb-2">
      <button type="button" class="tombol-teks -ml-3 px-3" @click="mode = 'rincian'"><PhArrowLeft :size="18" /> Kembali ke rincian</button>
      <h3 class="judul-bagian">{{ JUDUL_TEKS[mode] }}</h3>
      <p class="text-sm text-teks2">{{ s.perihal }}</p>
      <p v-if="mode === 'selesai'" class="rounded-xl bg-permukaan2 px-3 py-2 text-xs text-teks2">Disposisi dari {{ pilihD.dari }}: {{ [...(pilihD.instruksi || []), pilihD.catatan].filter(Boolean).join(' · ') }}</p>
      <template v-if="mode === 'hapus'">
        <p class="rounded-xl bg-[#C7332F]/10 p-3 text-sm text-teks2">Gunakan hanya untuk surat yang salah dicatat (mis. tercatat dua kali). Surat dan disposisinya terhapus permanen; penghapusan tercatat di Audit Log.</p>
        <label class="flex min-h-[44px] items-center gap-3 rounded-xl border border-garis px-3 text-sm"><input v-model="rapikan" type="checkbox" class="h-5 w-5 shrink-0" />
          <span><b>Rapikan nomor agenda</b><span class="block text-xs text-teks3">Nomor agenda surat sesudahnya pada tahun yang sama digeser naik agar buku agenda kembali berurutan.</span></span></label>
      </template>
      <textarea v-model="teks" rows="3" class="isian py-2.5" aria-label="Isian"
        :placeholder="mode === 'hapus' ? 'Alasan penghapusan (wajib), mis. tercatat dua kali' : mode === 'selesai' ? 'Laporan tindak lanjut (wajib), mis. rapat sudah dihadiri' : mode === 'tutup' ? 'Catatan (opsional)' : 'Alasan pembatalan (wajib), mis. surat tercatat dua kali'" />
      <button :class="[['batal', 'hapus'].includes(mode) ? 'tombol-garis' : 'tombol-utama', 'w-full', mode === 'hapus' && 'text-merah']" :disabled="proses" @click="kirimTeks">
        <component :is="mode === 'hapus' ? PhTrash : mode === 'batal' ? PhProhibit : PhCheckCircle" :size="20" weight="duotone" /> {{ proses ? 'Menyimpan…' : JUDUL_TEKS[mode] }}</button>
    </div>
  </LembarBawah>
</template>
