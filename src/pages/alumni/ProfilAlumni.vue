<!-- SIMKA PRO | src/pages/alumni/ProfilAlumni.vue | v1.0 | 14.25.0: profil alumni (CV berfoto), rencana lanjut studi, jejak semasa aktif | 25/10/2026 -->
<script setup>
// Profil satu alumni (admin/superadmin): CV berfoto, data diri, orang tua, riwayat kelas/halaqah/kamar/ekskul per tahun ajaran
// (dengan tautan Rekam Kesantrian tahun ajaran itu), hafalan resmi, sertifikat, prestasi, rencana lanjut studi, cita-cita,
// motto, kesan dan pesan. Ubah profil lewat lembar isian; cetak satu profil F4 dengan tanda tangan Direktur dan alumni.
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute } from 'vue-router'
import {
  PhGraduationCap, PhPencilSimple, PhPrinter, PhIdentificationCard, PhClockCounterClockwise, PhBookOpenText, PhTrophy, PhBuildings,
  PhUsers, PhCertificate, PhQuotes, PhCaretRight, PhPhone, PhEnvelopeSimple,
} from '@phosphor-icons/vue'
import { useAlumni } from '@/stores/alumni'
import { useSantri } from '@/stores/santri'
import { useUI } from '@/stores/ui'
import { formatPanjang } from '@/lib/tanggal'
import { ttl, JK_PANJANG } from '@/lib/rapor'
import { JENJANG, inisial } from '@/lib/santri'
import { LANJUT, JENIS_PT, STATUS_DAFTAR, JENIS_SERTIFIKAT, riwayatPerTA, rentangTA, profilLengkap } from '@/lib/alumni'
import { BIDANG_PRESTASI, TINGKAT_PRESTASI } from '@/lib/prestasi'
import { namaBerkas } from '@/lib/namaBerkas'
import { ambilPenandaTangan } from '@/lib/penandatangan'
import LembarBawah from '@/components/LembarBawah.vue'
import LembarRapor from '@/components/cetak/rapor/LembarRapor.vue'
import TombolAksi from '@/components/TombolAksi.vue'
import CVAlumni from './CVAlumni.vue'

const route = useRoute(); const al = useAlumni(); const san = useSantri(); const ui = useUI()
const id = computed(() => String(route.params.id || ''))
const p = ref(null); const memuat = ref(true); const foto = ref(''); const pratinjau = ref(false)
const direktur = ref({ jabatan: 'Direktur', nama: '' })
async function muat() {
  memuat.value = true
  try {
    p.value = await al.profil(id.value)
    foto.value = p.value?.santri?.foto_id ? (await san.urlFoto({ id: id.value, foto_id: p.value.santri.foto_id }).catch(() => null)) || '' : ''
  } catch (e) { ui.toast(e.message, 'galat'); p.value = null } finally { memuat.value = false }
}
onMounted(() => { muat(); ambilPenandaTangan('Direktur').then((d) => { direktur.value = d }).catch(() => {}) })
watch(id, muat)

const s = computed(() => p.value?.santri || {})
const a = computed(() => p.value?.alumni || {})
const perTA = computed(() => riwayatPerTA(p.value?.riwayat))
const tautanRekam = (r) => { const x = rentangTA(r.ta, r.ta_mulai); return x ? { path: `/santri/${id.value}/rekam`, query: { mulai: x.mulai, selesai: x.selesai, preset: 'ta-lama' } } : null }
const STUDI = computed(() => [
  ['Rencana', LANJUT[a.value.lanjut]?.n], ['Jenis perguruan tinggi', JENIS_PT[a.value.jenis_pt]], ['Kampus/lembaga', a.value.kampus], ['Fakultas', a.value.fakultas],
  ['Program studi', a.value.prodi], ['Kota/negara', [a.value.kota, a.value.negara].filter(Boolean).join(', ')], ['Jalur masuk', a.value.jalur],
  ['Status', STATUS_DAFTAR[a.value.status_daftar]?.n], ['Tahun mulai', a.value.tahun_mulai], ['Beasiswa', a.value.beasiswa],
].filter((r) => r[1]))
const DIRI = computed(() => [
  ['NIS / NISN', [s.value.nis, s.value.nisn].filter(Boolean).join(' / ')], ['Tempat, tanggal lahir', ttl(s.value) || '–'], ['Jenis kelamin', JK_PANJANG[s.value.jenis_kelamin] || '–'],
  ['Jenjang terakhir', JENJANG[s.value.jenjang] || '–'], ['Masuk pondok', s.value.tanggal_masuk ? formatPanjang(s.value.tanggal_masuk) : '–'], ['Tahun lulus', p.value?.tahun_lulus || '–'],
  ['Alamat asal', [s.value.alamat, s.value.kecamatan, s.value.kota_kab, s.value.provinsi].filter(Boolean).join(', ') || '–'],
])

// ---------- Ubah profil alumni ----------
const lembar = ref(false); const f = ref({}); const proses = ref(false)
const KOSONG = { tahun_lulus: '', lanjut: '', jenis_pt: '', kampus: '', fakultas: '', prodi: '', kota: '', negara: 'Indonesia', jalur: '', status_daftar: '', tahun_mulai: '', beasiswa: '',
  hp: '', email: '', alamat_kini: '', cita_cita: '', motto: '', kesan_pesan: '', catatan: '' }
function ubah() {
  const x = a.value || {}; f.value = Object.fromEntries(Object.keys(KOSONG).map((k) => [k, x[k] ?? KOSONG[k]]))
  if (!f.value.tahun_lulus) f.value.tahun_lulus = p.value?.tahun_lulus || ''
  if (!f.value.tahun_mulai && f.value.tahun_lulus) f.value.tahun_mulai = f.value.tahun_lulus
  lembar.value = true
}
const kuliah = computed(() => f.value.lanjut === 'kuliah')
async function simpan() {
  if (f.value.email && !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(f.value.email)) return ui.toast('Format e-mail tidak sah.', 'galat')
  const isi = { ...f.value }; if (!kuliah.value) isi.jenis_pt = ''
  proses.value = true
  try { await al.simpan(id.value, isi); ui.toast('Profil alumni disimpan.'); lembar.value = false; await muat() } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
const ttd = computed(() => ({ kiri: { pengantar: 'Mengetahui,', jabatan: direktur.value.jabatan || 'Direktur', nama: direktur.value.nama }, kanan: { jabatan: 'Alumni,', nama: s.value.nama_lengkap } }))
</script>
<template>
  <div class="w-alumni">
    <p v-if="memuat" class="py-10 text-center text-teks3">Memuat profil alumni…</p>
    <div v-else-if="!p" class="kartu p-8 text-center text-sm text-teks3">Profil alumni tidak dapat dibuka.</div>
    <template v-else>
      <section class="kartu overflow-hidden">
        <div class="h-20" style="background: linear-gradient(120deg, color-mix(in srgb, var(--c) 30%, transparent), color-mix(in srgb, var(--c2) 22%, transparent))" />
        <div class="-mt-12 flex flex-col gap-4 px-5 pb-5 sm:flex-row sm:items-end">
          <span class="grid h-32 w-24 shrink-0 place-items-center overflow-hidden rounded-2xl border-4 border-permukaan text-2xl font-bold" style="background: color-mix(in srgb, var(--c) 18%, rgb(var(--permukaan))); color: var(--c)">
            <img v-if="foto" :src="foto" alt="Pas foto alumni" class="h-full w-full object-cover" /><template v-else>{{ inisial(s.nama_lengkap) }}</template></span>
          <div class="min-w-0 flex-1">
            <p class="lencana mb-1 inline-flex"><PhGraduationCap :size="14" weight="fill" /> Alumni {{ p.tahun_lulus || '' }}</p>
            <h2 class="text-xl font-bold leading-tight">{{ s.nama_lengkap }}</h2>
            <p class="text-sm text-teks3">{{ s.nis }} · {{ JENJANG[s.jenjang] }} · {{ p.hafalan?.total_juz || 0 }} juz</p>
            <p v-if="a.motto" class="mt-1 text-sm italic text-teks2">“{{ a.motto }}”</p>
          </div>
          <div class="flex flex-wrap gap-2">
            <button class="tombol-garis px-4 text-sm" @click="ubah"><PhPencilSimple :size="18" /> Ubah profil</button>
            <button class="w-pengajuan tombol-garis px-4 text-sm" @click="pratinjau = true"><PhPrinter :size="18" weight="duotone" style="color: var(--c)" /> Cetak profil</button>
          </div>
        </div>
        <p v-if="!profilLengkap(a)" class="w-laporan mx-5 mb-5 rounded-xl px-3 py-2 text-sm" style="background: color-mix(in srgb, var(--c) 12%, transparent)">Rencana lanjut studi belum diisi. Ketuk <b>Ubah profil</b> untuk melengkapinya.</p>
      </section>

      <div class="mt-3 grid gap-3 lg:grid-cols-2">
        <section class="kartu w-rapor p-4">
          <h3 class="mb-2 flex items-center gap-2 font-bold"><PhBuildings :size="20" weight="duotone" style="color: var(--c)" /> Rencana lanjut studi</h3>
          <dl v-if="STUDI.length" class="grid grid-cols-[minmax(0,40%)_1fr] gap-x-3 gap-y-1.5 text-sm">
            <template v-for="[k, v] in STUDI" :key="k"><dt class="text-teks3">{{ k }}</dt><dd class="font-semibold">{{ v }}</dd></template>
          </dl>
          <p v-else class="text-sm text-teks3">Belum diisi.</p>
          <div v-if="a.hp || a.email || a.alamat_kini || a.cita_cita" class="mt-3 space-y-1 border-t border-garis pt-3 text-sm">
            <p v-if="a.cita_cita"><span class="text-teks3">Cita-cita:</span> <b>{{ a.cita_cita }}</b></p>
            <p v-if="a.hp" class="flex items-center gap-1.5"><PhPhone :size="16" class="text-teks3" /> {{ a.hp }}</p>
            <p v-if="a.email" class="flex items-center gap-1.5"><PhEnvelopeSimple :size="16" class="text-teks3" /> {{ a.email }}</p>
            <p v-if="a.alamat_kini" class="text-teks2">{{ a.alamat_kini }}</p>
          </div>
        </section>
        <section class="kartu w-santri p-4">
          <h3 class="mb-2 flex items-center gap-2 font-bold"><PhIdentificationCard :size="20" weight="duotone" style="color: var(--c)" /> Data diri</h3>
          <dl class="grid grid-cols-[minmax(0,40%)_1fr] gap-x-3 gap-y-1.5 text-sm">
            <template v-for="[k, v] in DIRI" :key="k"><dt class="text-teks3">{{ k }}</dt><dd class="font-semibold">{{ v }}</dd></template>
          </dl>
          <h4 class="mb-1 mt-3 flex items-center gap-2 text-sm font-bold"><PhUsers :size="18" weight="duotone" style="color: var(--c)" /> Orang tua</h4>
          <ul class="space-y-1 text-sm"><li v-for="k in p.kontak" :key="k.hubungan"><span class="text-teks3">{{ k.hubungan === 'ayah' ? 'Ayah' : k.hubungan === 'ibu' ? 'Ibu' : 'Wali' }}:</span> <b>{{ k.nama }}</b>{{ k.pekerjaan ? ' · ' + k.pekerjaan : '' }}{{ k.no_hp ? ' · ' + k.no_hp : '' }}</li>
            <li v-if="!p.kontak?.length" class="text-teks3">Belum tercatat.</li></ul>
          <router-link :to="`/santri/${id}`" class="mt-3 flex min-h-[44px] items-center gap-2 rounded-xl bg-permukaan2 px-3 text-sm font-semibold">Biodata lengkap semasa aktif <PhCaretRight :size="16" class="ml-auto" /></router-link>
        </section>
      </div>

      <section class="kartu w-kelompoksantri mt-3 p-4">
        <h3 class="mb-1 flex items-center gap-2 font-bold"><PhClockCounterClockwise :size="20" weight="duotone" style="color: var(--c)" /> Riwayat di pondok</h3>
        <p class="mb-3 text-xs text-teks3">Buka Rekam Kesantrian per tahun ajaran untuk membaca absensi, catatan hafalan, kedisiplinan, perizinan, klinik, dan rapor semasa aktif.</p>
        <ul class="grid gap-2 md:grid-cols-2 xl:grid-cols-3">
          <li v-for="r in perTA" :key="r.ta" class="rounded-2xl border border-garis p-3">
            <p class="font-bold">Tahun ajaran {{ r.ta }}</p>
            <p v-for="j in ['kelas', 'halaqah', 'kamar', 'ekskul']" v-show="r[j].length" :key="j" class="text-sm">
              <span class="text-teks3">{{ { kelas: 'Kelas', halaqah: 'Halaqah', kamar: 'Kamar', ekskul: 'Ekskul' }[j] }}:</span> {{ r[j].map((x) => x.nama).join(', ') }}
              <span v-if="r[j][0]?.pengasuh" class="text-teks3"> · {{ r[j].map((x) => x.pengasuh).filter(Boolean).join(', ') }}</span></p>
            <router-link v-if="tautanRekam(r)" :to="tautanRekam(r)" class="mt-2 inline-flex min-h-[40px] items-center gap-1 text-sm font-semibold" style="color: var(--c)">Rekam Kesantrian {{ r.ta }} <PhCaretRight :size="14" /></router-link>
          </li>
          <li v-if="!perTA.length" class="text-sm text-teks3">Riwayat kelompok belum tercatat di SIMKA.</li>
        </ul>
      </section>

      <div class="mt-3 grid gap-3 lg:grid-cols-2">
        <section class="kartu w-tahfizh p-4">
          <h3 class="mb-2 flex items-center gap-2 font-bold"><PhBookOpenText :size="20" weight="duotone" style="color: var(--c)" /> Hafalan dan sertifikat</h3>
          <p class="text-sm">Total hafalan resmi <b>{{ p.hafalan?.total_juz || 0 }} juz</b><span v-if="p.hafalan?.terakhir" class="text-teks3"> · penetapan terakhir {{ formatPanjang(p.hafalan.terakhir) }}</span></p>
          <p v-if="p.hafalan?.juz?.length" class="mt-1 text-xs text-teks3">Juz {{ p.hafalan.juz.join(', ') }}</p>
          <ul class="mt-2 space-y-1.5 text-sm"><li v-for="c in p.sertifikat" :key="c.nomor" class="flex items-start gap-2"><PhCertificate :size="18" weight="duotone" class="mt-0.5 shrink-0" style="color: var(--c)" />
            <span>{{ JENIS_SERTIFIKAT[c.jenis] || c.jenis }}{{ c.jenjang_juz ? ' ' + c.jenjang_juz + ' juz' : '' }}{{ c.predikat ? ' · ' + c.predikat : '' }}<br /><span class="text-xs text-teks3">{{ c.nomor }} · {{ formatPanjang(c.tanggal) }}</span></span></li></ul>
        </section>
        <section class="kartu w-prestasi p-4">
          <h3 class="mb-2 flex items-center gap-2 font-bold"><PhTrophy :size="20" weight="duotone" style="color: var(--c)" /> Prestasi</h3>
          <ul class="space-y-1.5 text-sm"><li v-for="(x, i) in p.prestasi" :key="i"><b>{{ x.capaian }}</b> · {{ x.kegiatan }}<br /><span class="text-xs text-teks3">{{ formatPanjang(x.tanggal) }} · {{ BIDANG_PRESTASI[x.bidang]?.n || x.bidang }} · {{ TINGKAT_PRESTASI[x.tingkat] || x.tingkat }}</span></li>
            <li v-if="!p.prestasi?.length" class="text-teks3">Belum ada prestasi tercatat.</li></ul>
        </section>
      </div>

      <section v-if="a.kesan_pesan" class="kartu w-pengumuman mt-3 p-4">
        <h3 class="mb-2 flex items-center gap-2 font-bold"><PhQuotes :size="20" weight="duotone" style="color: var(--c)" /> Kesan dan pesan</h3>
        <p class="whitespace-pre-line text-sm text-teks2">{{ a.kesan_pesan }}</p>
      </section>

      <TombolAksi class="lg:hidden" label="Ubah" :ikon="PhPencilSimple" warna="alumni" @klik="ubah" />

      <LembarRapor v-model:pratinjau="pratinjau" judul="Profil Alumni" :keterangan="s.nama_lengkap" :nama-berkas="namaBerkas(s.nama_lengkap, 'Profil Alumni', 'Lulusan ' + (p.tahun_lulus || ''))">
        <CVAlumni :p="p" :foto="foto" :ttd="ttd" />
      </LembarRapor>
    </template>

    <LembarBawah v-model="lembar" judul="Ubah profil alumni" lebar>
      <div class="space-y-4 pb-2">
        <div class="grid gap-3 sm:grid-cols-2">
          <div><label class="label-isian" for="pa-lulus">Tahun lulus</label><input id="pa-lulus" v-model="f.tahun_lulus" type="number" inputmode="numeric" min="2000" max="2100" class="isian" /></div>
          <div><label class="label-isian" for="pa-mulai">Tahun mulai studi lanjut</label><input id="pa-mulai" v-model="f.tahun_mulai" type="number" inputmode="numeric" min="2000" max="2100" class="isian" /></div>
        </div>
        <div><p class="label-isian">Rencana setelah lulus</p>
          <div class="flex flex-wrap gap-1.5">
            <button v-for="(v, k) in LANJUT" :key="k" type="button" :aria-pressed="f.lanjut === k" @click="f.lanjut = f.lanjut === k ? '' : k"
              :class="['min-h-[40px] rounded-xl border-2 px-3 text-sm font-semibold', 'w-' + v.w, f.lanjut === k ? 'text-teks' : 'border-garis text-teks2']"
              :style="f.lanjut === k ? 'border-color: var(--c); background: color-mix(in srgb, var(--c) 16%, transparent)' : ''">{{ v.n }}</button>
          </div></div>
        <div v-if="kuliah"><label class="label-isian" for="pa-pt">Jenis perguruan tinggi</label>
          <select id="pa-pt" v-model="f.jenis_pt" class="isian"><option value="">Pilih</option><option v-for="(n, k) in JENIS_PT" :key="k" :value="k">{{ n }}</option></select></div>
        <div><label class="label-isian" for="pa-kampus">{{ kuliah ? 'Kampus' : 'Lembaga/tempat tujuan' }}</label><input id="pa-kampus" v-model="f.kampus" class="isian" :placeholder="kuliah ? 'Contoh: UIN Alauddin Makassar' : 'Contoh: Pondok Pesantren Wahdah Islamiyah'" /></div>
        <div v-if="kuliah" class="grid gap-3 sm:grid-cols-2">
          <div><label class="label-isian" for="pa-fak">Fakultas</label><input id="pa-fak" v-model="f.fakultas" class="isian" /></div>
          <div><label class="label-isian" for="pa-prodi">Program studi</label><input id="pa-prodi" v-model="f.prodi" class="isian" /></div>
        </div>
        <div class="grid gap-3 sm:grid-cols-2">
          <div><label class="label-isian" for="pa-kota">Kota</label><input id="pa-kota" v-model="f.kota" class="isian" /></div>
          <div><label class="label-isian" for="pa-negara">Negara</label><input id="pa-negara" v-model="f.negara" class="isian" /></div>
          <div><label class="label-isian" for="pa-jalur">Jalur masuk</label><input id="pa-jalur" v-model="f.jalur" class="isian" placeholder="SNBP, SNBT, SPAN-PTKIN, mandiri, beasiswa" /></div>
          <div><label class="label-isian" for="pa-status">Status</label>
            <select id="pa-status" v-model="f.status_daftar" class="isian"><option value="">Pilih</option><option v-for="(v, k) in STATUS_DAFTAR" :key="k" :value="k">{{ v.n }}</option></select></div>
        </div>
        <div><label class="label-isian" for="pa-beasiswa">Beasiswa</label><input id="pa-beasiswa" v-model="f.beasiswa" class="isian" placeholder="Opsional" /></div>
        <div class="grid gap-3 sm:grid-cols-2">
          <div><label class="label-isian" for="pa-hp">Nomor HP alumni</label><input id="pa-hp" v-model="f.hp" type="tel" inputmode="tel" class="isian" /></div>
          <div><label class="label-isian" for="pa-email">E-mail</label><input id="pa-email" v-model="f.email" type="email" class="isian" /></div>
        </div>
        <div><label class="label-isian" for="pa-alamat">Alamat sekarang</label><input id="pa-alamat" v-model="f.alamat_kini" class="isian" /></div>
        <div><label class="label-isian" for="pa-cita">Cita-cita</label><input id="pa-cita" v-model="f.cita_cita" class="isian" /></div>
        <div><label class="label-isian" for="pa-motto">Motto hidup</label><input id="pa-motto" v-model="f.motto" class="isian" maxlength="160" /></div>
        <div><label class="label-isian" for="pa-kesan">Kesan dan pesan untuk pondok</label><textarea id="pa-kesan" v-model="f.kesan_pesan" class="isian min-h-[90px]" rows="3" maxlength="900" /></div>
        <div><label class="label-isian" for="pa-cat">Catatan admin</label><textarea id="pa-cat" v-model="f.catatan" class="isian min-h-[60px]" rows="2" placeholder="Tidak dicetak" /></div>
        <button class="tombol-utama w-full" :disabled="proses" @click="simpan">{{ proses ? 'Menyimpan…' : 'Simpan profil alumni' }}</button>
      </div>
    </LembarBawah>
  </div>
</template>
