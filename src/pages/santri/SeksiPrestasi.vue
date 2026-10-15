<!-- SIMKA PRO | src/pages/santri/SeksiPrestasi.vue | v1.0 | Tahap C: prestasi santri di biodata | 16/10/2026 -->
<script setup>
// Bagian "Prestasi dan capaian" di biodata santri: daftar prestasi, catat/ubah/hapus (sesuai hak), dan terbitkan
// Surat Keterangan Prestasi lewat Persuratan (template keterangan_prestasi, nomor dan tanda tangan elektronik).
import { ref, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { PhTrophy, PhPlus, PhPencilSimple, PhTrash, PhFileText, PhNotebook } from '@phosphor-icons/vue'
import { usePrestasi } from '@/stores/prestasi'
import { useUI } from '@/stores/ui'
import { BIDANG_PRESTASI, TINGKAT_PRESTASI, kalimatPrestasi } from '@/lib/prestasi'
import { formatPanjang } from '@/lib/tanggal'
import LembarPrestasi from '@/pages/prestasi/LembarPrestasi.vue'

const props = defineProps({ santri: { type: Object, required: true }, bolehSurat: Boolean })
const pr = usePrestasi(); const ui = useUI(); const router = useRouter()
const daftar = ref([]); const memuat = ref(true); const lembar = ref(false); const ubah = ref(null)
async function muat() {
  memuat.value = true
  try { daftar.value = await pr.daftar({ santri: props.santri.id }) } catch (e) { ui.toast(e.message, 'galat') } finally { memuat.value = false }
}
onMounted(() => { pr.muatHak().catch(() => {}); muat() })
watch(() => props.santri.id, muat)
function tambah() { ubah.value = null; lembar.value = true }
function sunting(x) { ubah.value = x; lembar.value = true }
async function hapus(x) {
  if (!(await ui.konfirmasi({ judul: 'Hapus prestasi?', pesan: `${x.capaian} · ${x.nama_kegiatan} akan dihapus dari catatan santri.`, ya: 'Hapus', bahaya: true }))) return
  try { await pr.hapus(x.id); ui.toast('Prestasi dihapus.'); muat() } catch (e) { ui.toast(e.message, 'galat') }
}
const suket = (x) => router.push({ path: '/persuratan/keluar', query: { templat: 'keterangan_prestasi', santri: props.santri.id, nis: props.santri.nis, prestasi: kalimatPrestasi(x) } })
</script>
<template>
  <section class="kartu w-prestasi mt-4 p-5">
    <div class="mb-3 flex flex-wrap items-center gap-3">
      <span class="chip-ikon h-10 w-10"><PhTrophy :size="22" weight="duotone" /></span>
      <div class="min-w-0 flex-1"><h3 class="judul-bagian">Prestasi dan capaian</h3><p class="text-sm text-teks3">Prestasi bertanda rapor tampil di rapor semester terkait.</p></div>
      <button v-if="pr.boleh" class="tombol-garis min-h-[40px] px-3 text-sm" @click="tambah"><PhPlus :size="18" weight="bold" /> Catat prestasi</button>
    </div>
    <p v-if="memuat" class="py-3 text-sm text-teks3">Memuat prestasi…</p>
    <ul v-else-if="daftar.length" class="space-y-2">
      <li v-for="x in daftar" :key="x.id" :class="['rounded-2xl border border-garis p-3', 'w-' + (BIDANG_PRESTASI[x.bidang]?.w || 'ekskul')]">
        <div class="flex flex-wrap items-start gap-2">
          <div class="min-w-0 flex-1">
            <p class="font-bold">{{ x.capaian }} · {{ x.nama_kegiatan }}</p>
            <p class="text-sm text-teks2">{{ formatPanjang(x.tanggal) }} · {{ TINGKAT_PRESTASI[x.tingkat] }}{{ x.penyelenggara ? ' · ' + x.penyelenggara : '' }}</p>
            <p class="mt-1 flex flex-wrap gap-1.5 text-xs"><span class="lencana">{{ BIDANG_PRESTASI[x.bidang]?.n }}</span>
              <span v-if="x.masuk_rapor" class="lencana w-laporan"><PhNotebook :size="13" weight="fill" /> Rapor</span>
              <span v-if="x.pencatat" class="text-teks3">dicatat {{ x.pencatat }}</span></p>
          </div>
          <div class="flex shrink-0 gap-1">
            <button v-if="bolehSurat" class="tombol-garis min-h-[40px] px-3 text-sm" @click="suket(x)"><PhFileText :size="18" weight="duotone" /> Suket</button>
            <button v-if="x.boleh_ubah" class="tombol-ikon" aria-label="Ubah prestasi" @click="sunting(x)"><PhPencilSimple :size="20" /></button>
            <button v-if="x.boleh_ubah" class="tombol-ikon" aria-label="Hapus prestasi" @click="hapus(x)"><PhTrash :size="20" /></button>
          </div>
        </div>
      </li>
    </ul>
    <p v-else class="rounded-xl bg-permukaan2 p-3 text-sm text-teks3">Belum ada prestasi tercatat.</p>
    <LembarPrestasi v-model="lembar" :data="ubah" :santri="santri" @selesai="muat" />
  </section>
</template>
