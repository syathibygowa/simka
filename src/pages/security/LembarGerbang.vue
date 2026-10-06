<!-- SIMKA PRO | src/pages/security/LembarGerbang.vue | v1.0 | Fase 7 – Tahap 1 Security: gerbang | 06/10/2026 -->
<script setup>
// Lembar gerbang satu santri. Panel besar berwarna: HIJAU = izin disetujui dan berlaku (boleh keluar),
// BIRU = sedang di luar, MERAH = tidak ada izin / belum disetujui / kedaluwarsa / terlambat.
// Aksi petugas Security: Catat keluar (penjemput, foto opsional bersama penjemput, catatan), Catat kembali,
// Tolak di gerbang (alasan wajib; Kepala Bidang Kesantrian dan pengelola izin dinotifikasi).
// Pejabat berwenang (Kepala Bidang Kesantrian, Direktur/Wadir, Plt, superadmin) dapat membuat izin cepat.
import { ref, computed, watch } from 'vue'
import { PhSignOut, PhSignIn, PhProhibit, PhCamera, PhLightning, PhUser, PhPhone, PhX, PhInfo } from '@phosphor-icons/vue'
import { useSecurity } from '@/stores/security'
import { useUI } from '@/stores/ui'
import { MODE_DEMO } from '@/lib/supabase'
import { STATUS_GERBANG, durasi } from '@/lib/security'
import { JENIS_IZIN } from '@/lib/izin'
import { formatWaktu, hariIniISO } from '@/lib/tanggal'
import { unggahKeDrive, kompresGambar, namaRapi } from '@/lib/penyimpanan'
import LembarBawah from '@/components/LembarBawah.vue'
import LembarIzinCepat from './LembarIzinCepat.vue'

const buka = defineModel({ type: Boolean, default: false })
const props = defineProps({ santri: { type: Object, default: null } })
const emit = defineEmits(['selesai'])
const sc = useSecurity(); const ui = useUI()
const data = ref(null); const mode = ref(''); const penjemput = ref(''); const catatan = ref(''); const proses = ref(false)
const foto = ref(null); const pratinjau = ref('')
watch(() => [buka.value, props.santri], () => { if (buka.value) { data.value = props.santri; atur('') } }, { immediate: true })
function atur(m) { mode.value = m; penjemput.value = m === 'keluar' ? data.value?.izin?.penjemput || '' : ''; catatan.value = ''; foto.value = null; pratinjau.value = '' }

const st = computed(() => data.value?.status || { kode: 'tidak_ada', warna: 'merah', label: 'Tidak ada izin' })
const info = computed(() => STATUS_GERBANG[st.value.kode] || STATUS_GERBANG.tidak_ada)
const izin = computed(() => data.value?.izin)
const terlambatMenit = computed(() => (st.value.kode === 'terlambat' && izin.value ? Math.floor((Date.now() - new Date(izin.value.kembali_batas)) / 60000) : 0))

function pilihFoto(e) {
  const f = e.target.files?.[0]; e.target.value = ''
  if (!f) return
  if (!/^image\//.test(f.type)) return ui.toast('Pilih berkas foto.', 'galat')
  foto.value = f; pratinjau.value = URL.createObjectURL(f)
}
async function simpan() {
  const aksi = mode.value
  if (aksi === 'ditolak' && catatan.value.trim().length < 5) return ui.toast('Tuliskan alasan penolakan (minimal 5 huruf).', 'galat')
  proses.value = true
  try {
    let fotoId = null
    if (foto.value && !MODE_DEMO) {
      const blob = await kompresGambar(foto.value, { maks: 720, kualitas: 0.6 }); const t = hariIniISO()
      fotoId = await unggahKeDrive(blob, { nama: namaRapi(data.value.nama, data.value.nis, aksi === 'kembali' ? 'Kembali' : aksi === 'ditolak' ? 'Ditolak' : 'Keluar', t.replaceAll('-', ''), Date.now() % 1000) + '.jpg',
        kategori: 'foto_gerbang', folder: `SIMKA PRO/Security/Gerbang/${t.slice(0, 4)}/${t.slice(5, 7)}`, retensiHari: 183 })
    }
    data.value = await sc.catat({ aksi, permit_id: aksi === 'ditolak' ? null : st.value.permit_id, student_id: data.value.student_id,
      foto_id: fotoId, penjemput: penjemput.value.trim() || null, catatan: catatan.value.trim() || null })
    ui.toast(aksi === 'keluar' ? `${props.santri.nama} dicatat keluar.` : aksi === 'kembali' ? `${props.santri.nama} dicatat kembali.` : 'Penolakan dicatat. Kepala Bidang Kesantrian telah dikabari.')
    atur(''); emit('selesai')
    if (aksi !== 'ditolak') buka.value = false
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
const lembarCepat = ref(false)
function hasilCepat(x) { data.value = x; atur(''); emit('selesai') }
</script>
<template>
  <LembarBawah v-model="buka" judul="Gerbang santri">
    <div v-if="data" class="space-y-4 pb-2">
      <!-- Panel status besar -->
      <div :class="['panel-gerbang rounded-2xl p-4 text-white', 'pg-' + st.warna]" role="status">
        <div class="flex items-center gap-3">
          <span class="grid h-14 w-14 shrink-0 place-items-center rounded-2xl bg-white/20"><component :is="info.ikon" :size="34" weight="fill" /></span>
          <div class="min-w-0">
            <p class="text-xl font-extrabold leading-tight">{{ info.n }}</p>
            <p class="text-sm font-medium text-white/90">{{ st.label }}<template v-if="terlambatMenit"> · {{ durasi(terlambatMenit) }}</template></p>
          </div>
        </div>
      </div>

      <div class="flex items-start gap-3">
        <span class="chip-ikon w-santri h-11 w-11 shrink-0"><PhUser :size="24" weight="duotone" /></span>
        <div class="min-w-0">
          <p class="font-bold leading-tight">{{ data.nama }}</p>
          <p class="text-sm text-teks2">{{ data.nis }} · {{ data.jenis_kelamin === 'P' ? 'Putri' : 'Putra' }}</p>
          <p class="text-sm text-teks2">Kelas {{ data.kelas || '–' }} · {{ data.kamar || 'Kamar –' }}</p>
        </div>
      </div>

      <div v-if="izin" class="rounded-xl border border-garis p-3 text-sm">
        <p class="font-bold">{{ JENIS_IZIN[izin.jenis] }} · {{ izin.lama_hari }} hari</p>
        <p class="text-teks2">{{ izin.alasan }}</p>
        <dl class="mt-2 grid grid-cols-[auto_1fr] gap-x-3 gap-y-1 text-xs">
          <dt class="text-teks3">Keluar</dt><dd>{{ formatWaktu(izin.keluar_pada) }} WITA<span v-if="izin.keluar_aktual" class="text-teks2"> (tercatat {{ formatWaktu(izin.keluar_aktual) }})</span></dd>
          <dt class="text-teks3">Batas kembali</dt><dd :class="st.kode === 'terlambat' ? 'font-bold text-merah' : ''">{{ formatWaktu(izin.kembali_batas) }} WITA</dd>
          <dt class="text-teks3">Penjemput</dt><dd>{{ izin.penjemput || '–' }}{{ izin.hubungan_penjemput ? ' (' + izin.hubungan_penjemput + ')' : '' }}</dd>
          <template v-if="izin.hp_penjemput"><dt class="text-teks3">HP</dt><dd><a :href="'tel:' + izin.hp_penjemput" class="inline-flex items-center gap-1 font-semibold text-merah"><PhPhone :size="14" /> {{ izin.hp_penjemput }}</a></dd></template>
          <dt class="text-teks3">Disetujui</dt><dd>{{ izin.disetujui_oleh || '–' }}</dd>
        </dl>
      </div>

      <!-- Aksi -->
      <template v-if="!mode">
        <div v-if="sc.hak.gerbang" class="grid gap-2">
          <button v-if="st.kode === 'boleh'" class="tombol-utama aksi-hijau w-full" @click="atur('keluar')"><PhSignOut :size="22" weight="bold" /> Catat keluar</button>
          <button v-if="['di_luar', 'terlambat'].includes(st.kode)" class="tombol-utama aksi-biru w-full" @click="atur('kembali')"><PhSignIn :size="22" weight="bold" /> Catat kembali</button>
          <button v-if="!['di_luar', 'terlambat', 'boleh'].includes(st.kode)" class="tombol-garis w-full" @click="atur('ditolak')"><PhProhibit :size="20" /> Catat ditolak di gerbang</button>
        </div>
        <button v-if="sc.hak.izin_cepat && !['di_luar', 'terlambat', 'boleh'].includes(st.kode)" class="tombol-garis w-security w-full" @click="lembarCepat = true">
          <PhLightning :size="20" weight="duotone" style="color: var(--c)" /> Buat izin cepat (langsung berlaku)</button>
        <p v-if="!sc.hak.gerbang" class="flex items-start gap-2 rounded-xl bg-permukaan2 p-3 text-xs text-teks2"><PhInfo :size="16" class="mt-0.5 shrink-0" /> Pencatatan keluar dan kembali dilakukan petugas Security di gerbang.</p>
      </template>

      <div v-else class="space-y-3 rounded-2xl border border-garis p-3">
        <div class="flex items-center justify-between">
          <p class="font-bold">{{ mode === 'keluar' ? 'Catat keluar' : mode === 'kembali' ? 'Catat kembali' : 'Tolak di gerbang' }}</p>
          <button class="tombol-teks min-h-[36px] px-2" @click="atur('')" aria-label="Batal"><PhX :size="18" /></button>
        </div>
        <div v-if="mode !== 'kembali'">
          <label class="label-isian" for="gb-pj">{{ mode === 'keluar' ? 'Penjemput saat keluar' : 'Penjemput/yang datang (bila ada)' }}</label>
          <input id="gb-pj" v-model="penjemput" class="isian" placeholder="Nama dan hubungan, contoh: Hasan (ayah)" />
        </div>
        <div>
          <label class="label-isian" for="gb-ct">{{ mode === 'ditolak' ? 'Alasan penolakan' : 'Catatan (opsional)' }}<span v-if="mode === 'ditolak'" class="text-merah"> *</span></label>
          <textarea id="gb-ct" v-model="catatan" rows="2" class="isian" :placeholder="mode === 'ditolak' ? 'Contoh: dijemput paman tanpa izin dari pondok' : 'Contoh: dijemput dengan mobil, membawa koper'" />
        </div>
        <div class="flex flex-wrap items-center gap-3">
          <label class="tombol-garis cursor-pointer"><PhCamera :size="20" weight="duotone" /> {{ pratinjau ? 'Ganti foto' : 'Foto (opsional)' }}
            <input type="file" accept="image/*" capture="environment" class="sr-only" @change="pilihFoto" /></label>
          <img v-if="pratinjau" :src="pratinjau" alt="Pratinjau foto gerbang" class="h-16 w-16 rounded-xl object-cover" />
        </div>
        <p v-if="mode === 'keluar'" class="text-xs text-teks3">Foto bersama penjemput sebagai dokumentasi. Disimpan 6 bulan.</p>
        <button class="tombol-utama w-full" :class="mode === 'keluar' ? 'aksi-hijau' : mode === 'kembali' ? 'aksi-biru' : ''" :disabled="proses" @click="simpan">
          <component :is="mode === 'keluar' ? PhSignOut : mode === 'kembali' ? PhSignIn : PhProhibit" :size="20" weight="bold" />
          {{ proses ? 'Menyimpan…' : mode === 'keluar' ? 'Simpan keluar' : mode === 'kembali' ? 'Simpan kembali' : 'Simpan penolakan' }}</button>
      </div>
    </div>
  </LembarBawah>
  <LembarIzinCepat v-model="lembarCepat" :santri="data" @selesai="hasilCepat" />
</template>
<style scoped>
.pg-hijau { background: linear-gradient(135deg, #156B42, #1E7D4F); }
.pg-merah { background: linear-gradient(135deg, #9A2320, #C7332F); }
.pg-biru  { background: linear-gradient(135deg, #24498A, #2F5FA8); }
.aksi-hijau { background: #1E7D4F; } .aksi-hijau:hover { background: #156B42; }
.aksi-biru  { background: #2F5FA8; } .aksi-biru:hover { background: #24498A; }
</style>
