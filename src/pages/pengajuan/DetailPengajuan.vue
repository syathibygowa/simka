<!-- SIMKA PRO | src/pages/pengajuan/DetailPengajuan.vue | v1.2 | Fase 8 – Tahap 1 QR dan Cek Keabsahan | 10/10/2026 -->
<script setup>
// Rincian satu pengajuan: data pemohon, alur persetujuan (tanda setiap jenjang), lampiran, keputusan
// (setujui/tolak, superadmin dapat memutus atas nama), pembatalan, dan surat F4 berkop untuk diunduh/dicetak.
import { ref, computed, watch } from 'vue'
import { PhCheckCircle, PhXCircle, PhPrinter, PhPaperclip, PhProhibit, PhWarning, PhSealCheck, PhHourglassMedium, PhCircleDashed, PhSkipForward } from '@phosphor-icons/vue'
import { usePengajuan } from '@/stores/pengajuan'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { MODE_DEMO } from '@/lib/supabase'
import { ambilBerkasUrl } from '@/lib/penyimpanan'
import { formatPanjang, formatPendek, formatWaktu, uraiPendek } from '@/lib/tanggal'
import { STATUS_PENGAJUAN, STATUS_JENJANG, KELOMPOK, rentangTanggal } from '@/lib/pengajuan'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'
import CatatanValidasi from '@/components/cetak/CatatanValidasi.vue'
import TombolWA from '@/components/TombolWA.vue'
import { pesanWA, halamanAplikasi } from '@/lib/wa'

const props = defineProps({ id: String })
const emit = defineEmits(['berubah'])
const pg = usePengajuan(); const sesi = useSesi(); const ui = useUI()
const d = ref(null); const memuat = ref(false); const catatan = ref(''); const proses = ref(false); const pratinjau = ref(false)

const kontak = ref([])
async function muat() {
  if (!props.id) return
  memuat.value = true
  try { d.value = await pg.detail(props.id); kontak.value = await pg.kontak(props.id).catch(() => []) } catch (e) { ui.toast(e.message, 'galat'); d.value = null } finally { memuat.value = false }
}
const sayaPemohon = computed(() => d.value?.employee_id === sesi.pengguna?.id)
const pemohonWA = computed(() => kontak.value.find((k) => k.peran === 'pemohon'))
const penyetujuWA = computed(() => kontak.value.filter((k) => k.peran === 'penyetuju' && k.employee_id !== sesi.pengguna?.id))
const dataWA = computed(() => d.value && { jenis: d.value.jenis.nama.toLowerCase(), tanggal: rentangTanggal(d.value, formatPendek), lama: `${d.value.jumlah_hari} hari`,
  status: { menunggu: `menunggu persetujuan ${d.value.jenjang.find((j) => j.status === 'menunggu')?.nama_peran || ''}`.trim(), disetujui: `disetujui (nomor ${d.value.nomor_surat || '-'})`, ditolak: 'ditolak', dibatalkan: 'dibatalkan' }[d.value.status],
  alasan: d.value.alasan_tolak ? `Catatan: ${d.value.alasan_tolak}` : '', pemohon: d.value.pemohon.nama, tautan: halamanAplikasi(`/pengajuan/${d.value.id}`) })
watch(() => props.id, () => { catatan.value = ''; muat() }, { immediate: true })

const IKON = { disetujui: PhSealCheck, ditolak: PhXCircle, menunggu: PhHourglassMedium, antre: PhCircleDashed, dilewati: PhSkipForward }
const kelompok = computed(() => KELOMPOK[d.value?.jenis?.kelompok] || KELOMPOK.izin)
const disetujuiOleh = computed(() => (d.value?.jenjang || []).filter((j) => j.status === 'disetujui'))
const terakhir = computed(() => disetujuiOleh.value[disetujuiOleh.value.length - 1] || null)
const judulSurat = computed(() => ({ sakit: 'Surat Keterangan Sakit Pegawai', izin: 'Surat Izin Pegawai', dinas_luar: 'Surat Keterangan Dinas Luar', cuti: 'Surat Izin Cuti Pegawai' })[d.value?.jenis?.kelompok] || 'Surat Pengajuan Pegawai')

async function putuskan(setuju) {
  const c = catatan.value.trim()
  if (!setuju && c.length < 5) return ui.toast('Tuliskan alasan penolakan (minimal 5 karakter).', 'galat')
  if (d.value.atas_nama && c.length < 5) return ui.toast('Superadmin yang memutus atas nama pejabat wajib menuliskan catatan.', 'galat')
  if (!(await ui.konfirmasi({ judul: setuju ? 'Setujui pengajuan?' : 'Tolak pengajuan?', pesan: `${d.value.pemohon.nama} – ${d.value.jenis.nama} ${d.value.jumlah_hari} hari.`, ya: setuju ? 'Setujui' : 'Tolak', bahaya: !setuju }))) return
  proses.value = true
  try {
    const h = await pg.putuskan(props.id, setuju, c)
    ui.toast(h === 'disetujui' ? 'Pengajuan disetujui penuh. Surat terbit dan presensi terisi otomatis.' : h === 'naik' ? 'Disetujui. Pengajuan diteruskan ke jenjang berikutnya.' : 'Pengajuan ditolak dan pemohon diberi tahu.', 'info')
    catatan.value = ''; await muat(); emit('berubah')
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
async function batalkan() {
  const sa = sesi.isSuperadmin && d.value.employee_id !== sesi.pengguna?.id
  if (sa && catatan.value.trim().length < 5) return ui.toast('Tuliskan alasan pembatalan pada kolom catatan.', 'galat')
  if (!(await ui.konfirmasi({ judul: 'Batalkan pengajuan?', pesan: d.value.status === 'disetujui' ? 'Status presensi yang terisi dari pengajuan ini akan dihapus.' : 'Pengajuan ditarik dan tidak diproses lagi.', ya: 'Batalkan', bahaya: true }))) return
  proses.value = true
  try { await pg.batalkan(props.id, catatan.value.trim()); ui.toast('Pengajuan dibatalkan.', 'info'); await muat(); emit('berubah') }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
async function lihatLampiran() {
  if (MODE_DEMO) return ui.toast('Mode demo: lampiran contoh tidak tersedia.', 'info')
  try { const u = await ambilBerkasUrl(d.value.lampiran_id); window.open(u, '_blank', 'noopener') } catch (e) { ui.toast(e.message, 'galat') }
}
</script>
<template>
  <div class="pb-2">
    <p v-if="memuat && !d" class="py-8 text-center text-teks3">Memuat pengajuan…</p>
    <template v-else-if="d">
      <div class="flex items-start gap-3">
        <span :class="['chip-ikon h-11 w-11 shrink-0', 'w-' + kelompok.w]"><component :is="kelompok.ikon" :size="24" weight="duotone" /></span>
        <div class="min-w-0 flex-1">
          <p class="text-lg font-extrabold leading-snug">{{ d.jenis.nama }} · {{ d.jumlah_hari }} hari</p>
          <p class="text-sm text-teks2">{{ rentangTanggal(d, formatPanjang) }}</p>
        </div>
        <span :class="['lencana shrink-0', 'w-' + STATUS_PENGAJUAN[d.status].w]">{{ STATUS_PENGAJUAN[d.status].n }}</span>
      </div>

      <dl class="mt-4 grid grid-cols-[7.5rem_1fr] gap-x-3 gap-y-1.5 text-sm">
        <dt class="text-teks3">Pemohon</dt><dd class="font-semibold">{{ d.pemohon.nama }}</dd>
        <dt class="text-teks3">NIY</dt><dd>{{ d.pemohon.niy || '–' }}</dd>
        <dt class="text-teks3">Jabatan</dt><dd>{{ d.pemohon.jabatan || '–' }}</dd>
        <dt class="text-teks3">Bidang/Unit</dt><dd>{{ d.pemohon.unit || '–' }}</dd>
        <dt class="text-teks3">Alasan</dt><dd class="whitespace-pre-line">{{ d.alasan }}</dd>
        <template v-if="d.alamat_selama"><dt class="text-teks3">Alamat/kontak</dt><dd>{{ d.alamat_selama }}</dd></template>
        <dt class="text-teks3">Diajukan</dt><dd>{{ formatWaktu(d.created_at) }} WITA</dd>
        <template v-if="d.nomor_surat"><dt class="text-teks3">Nomor surat</dt><dd class="font-semibold">{{ d.nomor_surat }}</dd>
          <dt class="text-teks3">Kode validasi</dt><dd class="font-mono font-semibold tracking-wider">{{ d.kode_validasi }}</dd></template>
        <template v-if="d.status === 'disetujui'"><dt class="text-teks3">Presensi</dt><dd>{{ d.sesi_terisi }} sesi terisi otomatis</dd></template>
        <template v-if="d.alasan_tolak"><dt class="text-teks3">{{ d.status === 'ditolak' ? 'Alasan ditolak' : 'Alasan batal' }}</dt><dd class="font-semibold">{{ d.alasan_tolak }}</dd></template>
      </dl>
      <p v-if="d.melebihi_kuota" class="w-tahfizh mt-3 flex gap-2 rounded-xl p-3 text-sm text-teks" style="background: color-mix(in srgb, var(--c) 10%, rgb(var(--permukaan)))">
        <PhWarning :size="20" weight="duotone" class="mt-0.5 shrink-0" style="color: var(--c)" />Melebihi kuota. {{ d.catatan_kuota }}</p>
      <button v-if="d.lampiran_id" class="tombol-garis mt-3" @click="lihatLampiran"><PhPaperclip :size="20" weight="duotone" /> Lihat lampiran bukti</button>

      <h4 class="mb-2 mt-5 text-sm font-bold text-teks3">Alur persetujuan</h4>
      <ol class="relative space-y-3 border-l-2 border-garis pl-5">
        <li v-for="j in d.jenjang" :key="j.urutan" :class="['relative', 'w-' + STATUS_JENJANG[j.status].w]">
          <span class="chip-ikon absolute -left-[2.15rem] top-0 h-8 w-8 rounded-full bg-permukaan"><component :is="IKON[j.status]" :size="18" weight="duotone" /></span>
          <p class="font-semibold">{{ j.nama_peran }} <span class="lencana ml-1">{{ STATUS_JENJANG[j.status].n }}</span></p>
          <p v-if="j.nama" class="text-sm text-teks2">{{ j.jabatan_tertulis }}: {{ j.nama }}<template v-if="j.atas_nama"> (diputus superadmin atas nama pejabat)</template></p>
          <p v-if="j.waktu" class="text-xs text-teks3">{{ formatWaktu(j.waktu) }} WITA</p>
          <p v-if="j.calon?.length" class="text-xs text-teks3">Menunggu: {{ j.calon.join(' · ') }}</p>
          <p v-if="j.catatan" class="mt-0.5 text-sm italic text-teks2">“{{ j.catatan }}”</p>
        </li>
      </ol>

      <div v-if="d.boleh_putuskan || d.boleh_batal" class="mt-5 space-y-2 rounded-2xl border border-garis p-3">
        <p v-if="d.atas_nama" class="text-sm text-teks2">Anda memutus sebagai superadmin <strong>atas nama</strong> pejabat jenjang ini. Catatan wajib diisi.</p>
        <template v-if="d.boleh_putuskan || (sesi.isSuperadmin && d.employee_id !== sesi.pengguna?.id)">
        <label class="label-isian" for="pj-catatan">{{ d.boleh_putuskan ? 'Catatan (wajib bila menolak)' : 'Alasan pembatalan' }}</label>
        <textarea id="pj-catatan" v-model="catatan" class="isian min-h-[4.5rem] py-2" :placeholder="d.boleh_putuskan ? 'Contoh: silakan, tugas digantikan Ust. …' : 'Tuliskan alasan pembatalan'" />
        </template>
        <p v-else class="text-sm text-teks2">Pengajuan yang belum diputus dapat Anda tarik kembali.</p>
        <div class="flex flex-wrap gap-2">
          <template v-if="d.boleh_putuskan">
            <button class="tombol-utama flex-1" :disabled="proses" @click="putuskan(true)"><PhCheckCircle :size="20" weight="duotone" /> Setujui</button>
            <button class="tombol-garis w-beranda flex-1" style="color: var(--c)" :disabled="proses" @click="putuskan(false)"><PhXCircle :size="20" weight="duotone" /> Tolak</button>
          </template>
          <button v-if="d.boleh_batal" class="tombol-garis" :disabled="proses" @click="batalkan"><PhProhibit :size="20" weight="duotone" /> Batalkan pengajuan</button>
        </div>
      </div>

      <div v-if="(!sayaPemohon && pemohonWA) || penyetujuWA.length" class="mt-4 rounded-2xl border border-garis p-3">
        <p class="mb-2 text-sm font-bold">Hubungi lewat WA</p>
        <div class="flex flex-wrap gap-2">
          <TombolWA v-if="!sayaPemohon && pemohonWA" kecil :hp="pemohonWA.no_hp" label="Kabari pemohon" :pesan="pesanWA('pengajuan_status', { ...dataWA, nama: pemohonWA.nama })" />
          <template v-if="d.status === 'menunggu'">
            <TombolWA v-for="p in penyetujuWA" :key="p.employee_id" kecil :hp="p.no_hp" :label="`Ingatkan ${p.jabatan || 'penyetuju'}`" :pesan="pesanWA('pengajuan_pengingat', { ...dataWA, nama: p.nama, jabatan: p.jabatan })" />
          </template>
        </div>
      </div>

      <button v-if="d.status === 'disetujui'" class="tombol-utama mt-4 w-full" @click="pratinjau = true"><PhPrinter :size="20" weight="duotone" /> Unduh / cetak surat</button>

      <DokumenCetak v-if="d.status === 'disetujui'" v-model:pratinjau="pratinjau" :kop="d.kop_kode" :judul="judulSurat" :nomor="d.nomor_surat" :pencetak="sesi.pengguna?.nama_lengkap">
        <p>Yang bertanda tangan di bawah ini menerangkan bahwa pengajuan pegawai berikut telah disetujui:</p>
        <table class="data" style="margin: 6pt 0 8pt 12pt">
          <tbody>
            <tr><td style="width: 38mm">Nama</td><td style="width: 4mm">:</td><td>{{ d.pemohon.nama }}</td></tr>
            <tr><td>NIY</td><td>:</td><td>{{ d.pemohon.niy || '–' }}</td></tr>
            <tr><td>Jabatan</td><td>:</td><td>{{ d.pemohon.jabatan || '–' }}</td></tr>
            <tr><td>Bidang/Unit</td><td>:</td><td>{{ d.pemohon.unit || '–' }}</td></tr>
            <tr><td>Jenis pengajuan</td><td>:</td><td>{{ d.jenis.nama }}</td></tr>
            <tr><td>Tanggal</td><td>:</td><td>{{ rentangTanggal(d, formatPanjang) }} ({{ d.jumlah_hari }} hari)</td></tr>
            <tr><td>Alasan</td><td>:</td><td>{{ d.alasan }}</td></tr>
            <tr v-if="d.alamat_selama"><td>Alamat/kontak</td><td>:</td><td>{{ d.alamat_selama }}</td></tr>
          </tbody>
        </table>
        <p style="margin-bottom: 4pt">Riwayat persetujuan:</p>
        <table class="tabel">
          <colgroup><col style="width:6%"><col style="width:22%"><col style="width:32%"><col style="width:14%"><col style="width:26%"></colgroup>
          <thead><tr><th>No.</th><th>Jenjang</th><th>Pejabat</th><th>Keputusan</th><th>Waktu dan catatan</th></tr></thead>
          <tbody>
            <tr v-for="(j, i) in d.jenjang" :key="j.urutan">
              <td class="tengah">{{ i + 1 }}</td><td>{{ j.nama_peran }}</td>
              <td>{{ j.nama ? `${j.nama} (${j.jabatan_tertulis})` : '–' }}</td>
              <td class="tengah">{{ j.status === 'disetujui' ? '✓ Disetujui' : STATUS_JENJANG[j.status].n }}</td>
              <td>{{ j.waktu ? formatWaktu(j.waktu) + ' WITA' : '' }}{{ j.catatan ? (j.waktu ? '; ' : '') + j.catatan : '' }}</td>
            </tr>
          </tbody>
        </table>
        <p style="margin-top: 8pt; text-align: justify">Selama masa tersebut, presensi yang bersangkutan dicatat sebagai {{ d.jenis.nama.toLowerCase() }}. Demikian surat ini dibuat untuk dipergunakan sebagaimana mestinya.</p>
        <template #ttd>
          <TandaTangan :tanggal="uraiPendek(formatPendek(d.diputus_pada))"
            :kiri="{ pengantar: 'Menyetujui,', jabatan: terakhir?.jabatan_tertulis || '', nama: terakhir?.nama || '', niy: terakhir?.niy,
                     kode: d.kode_validasi, waktu: terakhir?.waktu }"
            :kanan="{ jabatan: 'Pemohon', nama: d.pemohon.nama, niy: d.pemohon.niy }" />
          <CatatanValidasi :kode="d.kode_validasi" :draf="!d.kode_validasi" />
        </template>
      </DokumenCetak>
    </template>
  </div>
</template>
