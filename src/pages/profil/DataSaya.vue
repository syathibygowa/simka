<!-- SIMKA PRO | src/pages/profil/DataSaya.vue | v1.0 | Fase 5 – Perbaikan: pegawai memperbarui data kepegawaiannya | 05/10/2026 -->
<script setup>
// Data kepegawaian saya: pegawai mengajukan perubahan data diri dan kepegawaian. Diterapkan setelah diverifikasi superadmin.
// Jabatan dan bidang/unit ditetapkan pimpinan lewat admin (tidak diajukan di sini).
import { ref, computed, onMounted } from 'vue'
import { PhIdentificationCard, PhPaperPlaneTilt, PhHourglass, PhCheckCircle, PhXCircle, PhInfo, PhArrowCounterClockwise } from '@phosphor-icons/vue'
import { usePerubahanData } from '@/stores/perubahanData'
import { useUI } from '@/stores/ui'
import { KOLOM_AJUAN, PENDIDIKAN, STATUS_KELUARGA, STATUS_PEGAWAI, KATEGORI_HONORER, LEVEL_MUHAFFIZH } from '@/lib/kepegawaian'
import { nilaiAjuan } from '@/lib/teksAjuan'
import { formatWaktu, hariIniISO } from '@/lib/tanggal'
import InputTanggal from '@/components/InputTanggal.vue'

const pd = usePerubahanData(); const ui = useUI()
const f = ref(null); const asli = ref({}); const alasan = ref(''); const berlaku = ref(hariIniISO()); const proses = ref(false)
async function muat() {
  try {
    const d = await pd.muatDataSaya(); await pd.muat(null)
    asli.value = Object.fromEntries(Object.keys(KOLOM_AJUAN).map((k) => [k, d[k] ?? '']))
    const tunggu = pd.daftar.find((r) => r.status === 'menunggu')
    f.value = { ...asli.value, ...(tunggu?.data || {}) }
    if (tunggu) { alasan.value = tunggu.alasan || ''; berlaku.value = tunggu.tanggal_berlaku || hariIniISO() }
  } catch (e) { ui.toast(e.message, 'galat') }
}
onMounted(muat)
const menunggu = computed(() => pd.daftar.find((r) => r.status === 'menunggu'))
const riwayat = computed(() => pd.daftar.filter((r) => r.status !== 'menunggu').slice(0, 10))
const berubah = computed(() => (f.value ? Object.keys(KOLOM_AJUAN).filter((k) => String(f.value[k] ?? '') !== String(asli.value[k] ?? '')) : []))
const STATUS = { disetujui: { n: 'Disetujui', w: 'presensi', i: PhCheckCircle }, ditolak: { n: 'Ditolak', w: 'klinik', i: PhXCircle }, dibatalkan: { n: 'Dibatalkan', w: 'hakakses', i: PhArrowCounterClockwise } }
async function ajukan() {
  if (!berubah.value.length) return ui.toast('Belum ada data yang diubah.', 'galat')
  if (alasan.value.trim().length < 5) return ui.toast('Tuliskan alasan/keterangan perubahan (minimal 5 huruf).', 'galat')
  proses.value = true
  try {
    await pd.ajukan(Object.fromEntries(berubah.value.map((k) => [k, f.value[k]])), alasan.value.trim(), berlaku.value)
    ui.toast('Pengajuan terkirim. Superadmin menerima notifikasi untuk memverifikasi.'); await muat()
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
async function batalkan() {
  if (!(await ui.konfirmasi({ judul: 'Batalkan pengajuan?', pesan: 'Pengajuan yang menunggu verifikasi dibatalkan.', ya: 'Batalkan', bahaya: true }))) return
  try { await pd.batalkan(menunggu.value.id); ui.toast('Pengajuan dibatalkan.'); await muat() } catch (e) { ui.toast(e.message, 'galat') }
}
</script>
<template>
  <div class="mx-auto max-w-3xl space-y-4 pb-6">
    <div class="kartu w-pegawai flex gap-3 p-4">
      <span class="chip-ikon h-11 w-11 shrink-0"><PhInfo :size="24" weight="duotone" /></span>
      <p class="text-sm text-teks2">Ubah data yang perlu diperbarui lalu kirim pengajuan. Data baru berlaku setelah <b class="text-teks">diverifikasi superadmin</b>. Jabatan dan bidang/unit ditetapkan pimpinan melalui admin.</p>
    </div>

    <div v-if="menunggu" class="kartu w-pengajuan flex flex-wrap items-center gap-3 p-4">
      <span class="chip-ikon h-11 w-11"><PhHourglass :size="24" weight="duotone" /></span>
      <div class="min-w-[200px] flex-1"><p class="font-bold">Menunggu verifikasi superadmin</p>
        <p class="text-sm text-teks3">Diajukan {{ formatWaktu(menunggu.diajukan_pada) }} WITA · {{ Object.keys(menunggu.data).map((k) => KOLOM_AJUAN[k]).join(', ') }}. Mengirim lagi akan memperbarui pengajuan ini.</p></div>
      <button class="tombol-garis" @click="batalkan">Batalkan</button>
    </div>

    <section v-if="f" class="kartu w-pegawai p-5">
      <div class="mb-4 flex items-center gap-3"><span class="chip-ikon h-10 w-10"><PhIdentificationCard :size="22" weight="duotone" /></span><h2 class="judul-bagian">Data diri dan kepegawaian</h2></div>
      <div class="grid gap-4 sm:grid-cols-2">
        <div class="sm:col-span-2"><label class="label-isian" for="ds-nama">Nama lengkap</label><input id="ds-nama" v-model="f.nama_lengkap" class="isian" /></div>
        <div><label class="label-isian" for="ds-niy">NIY</label><input id="ds-niy" v-model="f.niy" class="isian" inputmode="numeric" /></div>
        <div><label class="label-isian" for="ds-jk">Jenis kelamin</label><select id="ds-jk" v-model="f.jenis_kelamin" class="isian"><option value="L">Laki-laki</option><option value="P">Perempuan</option></select></div>
        <div><label class="label-isian" for="ds-tmp">Tempat lahir</label><input id="ds-tmp" v-model="f.tempat_lahir" class="isian" /></div>
        <InputTanggal v-model="f.tanggal_lahir" label="Tanggal lahir" bawaan-kosong />
        <div><label class="label-isian" for="ds-pend">Pendidikan terakhir</label><select id="ds-pend" v-model="f.pendidikan_terakhir" class="isian"><option value="">Belum diisi</option><option v-for="(n, k) in PENDIDIKAN" :key="k" :value="k">{{ n }}</option></select></div>
        <div><label class="label-isian" for="ds-kel">Status keluarga</label><select id="ds-kel" v-model="f.status_keluarga" class="isian"><option value="">Belum diisi</option><option v-for="(n, k) in STATUS_KELUARGA" :key="k" :value="k">{{ n }}</option></select></div>
        <InputTanggal v-model="f.tmt_tugas" label="TMT tugas di pondok" bawaan-kosong />
        <div><label class="label-isian" for="ds-stat">Status kepegawaian</label><select id="ds-stat" v-model="f.status_kepegawaian" class="isian"><option value="">Belum diisi</option><option v-for="(n, k) in STATUS_PEGAWAI" :key="k" :value="k">{{ n }}</option></select></div>
        <div v-if="f.status_kepegawaian === 'honorer'"><label class="label-isian" for="ds-hon">Kategori honorer</label><select id="ds-hon" v-model="f.kategori_honorer" class="isian"><option value="">Belum diisi</option><option v-for="(n, k) in KATEGORI_HONORER" :key="k" :value="k">{{ n }}</option></select></div>
        <div v-if="asli.level_muhaffizh || f.level_muhaffizh"><label class="label-isian" for="ds-lvl">Level muhaffizh</label><select id="ds-lvl" v-model="f.level_muhaffizh" class="isian"><option value="">Belum diisi</option><option v-for="(n, k) in LEVEL_MUHAFFIZH" :key="k" :value="k">{{ n }}</option></select></div>
        <div><label class="label-isian" for="ds-hp">Nomor HP/WA</label><input id="ds-hp" v-model="f.no_hp" class="isian" inputmode="tel" placeholder="08xxxxxxxxxx" /></div>
      </div>

      <div v-if="berubah.length" class="mt-4 rounded-xl bg-permukaan2 p-3 text-sm">
        <p class="mb-1 font-bold">Yang akan diajukan ({{ berubah.length }})</p>
        <ul class="space-y-0.5 text-teks2"><li v-for="k in berubah" :key="k">{{ KOLOM_AJUAN[k] }}: {{ nilaiAjuan(k, asli[k]) }} → <b class="text-teks">{{ nilaiAjuan(k, f[k]) }}</b></li></ul>
      </div>
      <div class="mt-4 grid gap-4 sm:grid-cols-2">
        <div class="sm:col-span-2"><label class="label-isian" for="ds-alasan">Alasan/keterangan <span class="text-merah">*</span></label>
          <textarea id="ds-alasan" v-model="alasan" rows="2" class="isian" placeholder="Contoh: lulus S2 Juli 2026, ijazah sudah diserahkan ke tata usaha" /></div>
        <InputTanggal v-model="berlaku" label="Berlaku mulai" />
      </div>
      <button class="tombol-utama mt-4 w-full" :disabled="proses || !berubah.length" @click="ajukan"><PhPaperPlaneTilt :size="20" weight="duotone" /> {{ proses ? 'Mengirim…' : menunggu ? 'Perbarui pengajuan' : 'Kirim pengajuan' }}</button>
    </section>
    <p v-else class="py-12 text-center text-teks3">Memuat data…</p>

    <section v-if="riwayat.length" class="kartu p-5">
      <h2 class="judul-bagian mb-3">Riwayat pengajuan</h2>
      <ul class="divide-y divide-garis text-sm">
        <li v-for="r in riwayat" :key="r.id" class="py-2.5" :class="'w-' + STATUS[r.status].w">
          <p class="flex items-center gap-2"><component :is="STATUS[r.status].i" :size="18" weight="duotone" style="color: var(--c)" /><b>{{ STATUS[r.status].n }}</b><span class="text-teks3">· {{ formatWaktu(r.diputuskan_pada || r.diajukan_pada) }}</span></p>
          <p class="text-teks2">{{ Object.keys(r.data).map((k) => `${KOLOM_AJUAN[k]}: ${nilaiAjuan(k, r.data[k])}`).join(' · ') }}</p>
          <p v-if="r.catatan_verifikator" class="text-teks3">Catatan: {{ r.catatan_verifikator }}</p>
        </li>
      </ul>
    </section>
  </div>
</template>
