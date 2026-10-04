<!-- SIMKA PRO | src/pages/santri/FormSantri.vue | v1.1 | Fase 4 – Tahap 2 Kelompok santri | 04/10/2026 -->
<script setup>
// Tambah dan ubah data santri: identitas, pendidikan dan masuk (baru/pindahan), kontak ayah/ibu/wali.
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { PhFloppyDisk, PhIdentificationCard, PhGraduationCap, PhUsersThree, PhInfo, PhMagicWand, PhWhatsappLogo } from '@phosphor-icons/vue'
import { useSantri } from '@/stores/santri'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { TINGKAT, JENJANG, HUBUNGAN, uraiNIS, nisBerikutnya, normalHP } from '@/lib/santri'
import InputTanggal from '@/components/InputTanggal.vue'

const route = useRoute(); const router = useRouter()
const san = useSantri(); const sesi = useSesi(); const ui = useUI()
const baru = computed(() => !route.params.id)
const f = ref(null); const proses = ref(false); const kontakAwal = ref([])

const kosongKontak = (h) => ({ hubungan: h, nama: '', no_hp: '', pekerjaan: '' })
onMounted(async () => {
  await san.muat()
  // Wali kelas boleh memperbarui data santri kelasnya (tidak menambah santri baru)
  const wali = !baru.value && sesi.kelompokSaya.some((k) => k.jenis === 'kelas' && (san.cari(route.params.id)?.kelompok || []).some((x) => x.id === k.id))
  if (!(sesi.bolehAdmin('kelola_santri') || sesi.tingkat('data_santri') >= 2 || wali)) {
    ui.toast('Anda tidak berwenang menambah atau mengubah data santri.', 'galat'); return router.replace(baru.value ? '/santri' : `/santri/${route.params.id}`)
  }
  if (baru.value) {
    f.value = { nis: '', nisn: '', nik: '', nama_lengkap: '', nama_panggilan: '', jenis_kelamin: '', tempat_lahir: '', tanggal_lahir: '', jenjang: 'wustha', tingkat: 7,
      tanggal_masuk: '', jalur_masuk: 'baru', asal_sekolah: '', hafalan_awal_juz: '', anak_ke: '', alamat: '', catatan: '',
      kontak: ['ayah', 'ibu', 'wali'].map(kosongKontak), utama: 'ayah' }
  } else {
    const s = san.cari(route.params.id)
    if (!s) { ui.toast('Data santri tidak ditemukan.', 'galat'); return router.replace('/santri') }
    kontakAwal.value = (s.kontak || []).map((k) => k.hubungan)
    f.value = {
      id: s.id, nis: s.nis, nisn: s.nisn || '', nik: s.nik || '', nama_lengkap: s.nama_lengkap, nama_panggilan: s.nama_panggilan || '', jenis_kelamin: s.jenis_kelamin,
      tempat_lahir: s.tempat_lahir || '', tanggal_lahir: s.tanggal_lahir || '', jenjang: s.jenjang, tingkat: s.tingkat, tanggal_masuk: s.tanggal_masuk || '',
      jalur_masuk: s.jalur_masuk, asal_sekolah: s.asal_sekolah || '', hafalan_awal_juz: s.hafalan_awal_juz ?? '', anak_ke: s.anak_ke || '', alamat: s.alamat || '', catatan: s.catatan || '',
      kontak: ['ayah', 'ibu', 'wali'].map((h) => { const k = (s.kontak || []).find((x) => x.hubungan === h); return k ? { hubungan: h, nama: k.nama || '', no_hp: k.no_hp || '', pekerjaan: k.pekerjaan || '' } : kosongKontak(h) }),
      utama: (s.kontak || []).find((k) => k.utama)?.hubungan || 'ayah',
    }
  }
})

// Kelas mengikuti jenjang
watch(() => f.value?.jenjang, (j) => { if (f.value && !TINGKAT[j].includes(Number(f.value.tingkat))) f.value.tingkat = TINGKAT[j][0] })
const infoNIS = computed(() => uraiNIS(f.value?.nis))
const awalanNIS = computed(() => (/^\d{4}/.test(f.value?.nis || '') ? f.value.nis.slice(0, 4) : ''))
function isiNISBerikutnya() {
  const n = nisBerikutnya(awalanNIS.value, san.daftar.filter((s) => s.id !== f.value.id))
  if (n) f.value.nis = n; else ui.toast('Nomor urut untuk awalan ini sudah habis (999).', 'galat')
}

async function simpan() {
  const d = f.value
  if (!/^\d{7}$/.test(d.nis.trim())) return ui.toast('NIS harus 7 angka, contoh 2211010 (masuk 2022, angkatan 11, nomor 010).', 'galat')
  if (d.nama_lengkap.trim().length < 3) return ui.toast('Nama lengkap santri wajib diisi (minimal 3 huruf).', 'galat')
  if (!d.jenis_kelamin) return ui.toast('Pilih jenis kelamin santri.', 'galat')
  if (d.nisn && !/^\d{10}$/.test(d.nisn.trim())) return ui.toast('NISN harus 10 angka.', 'galat')
  if (d.nik && !/^\d{16}$/.test(d.nik.trim())) return ui.toast('NIK harus 16 angka.', 'galat')
  if (d.hafalan_awal_juz !== '' && (Number(d.hafalan_awal_juz) < 0 || Number(d.hafalan_awal_juz) > 30)) return ui.toast('Hafalan awal harus 0–30 juz.', 'galat')
  if (d.jalur_masuk === 'pindahan' && !d.asal_sekolah.trim()) return ui.toast('Asal sekolah wajib diisi untuk santri pindahan.', 'galat')
  const kontak = []
  for (const k of d.kontak) {
    const hp = normalHP(k.no_hp)
    if (k.no_hp && !/^[0-9+]{9,16}$/.test(hp)) return ui.toast(`Nomor HP ${HUBUNGAN[k.hubungan].toLowerCase()} harus 9–16 angka.`, 'galat')
    const kosong = !k.nama.trim() && !hp
    if (kosong) { if (kontakAwal.value.includes(k.hubungan)) kontak.push({ hubungan: k.hubungan, hapus: true }); continue }
    kontak.push({ hubungan: k.hubungan, nama: k.nama.trim(), no_hp: hp, pekerjaan: k.pekerjaan.trim(), utama: d.utama === k.hubungan })
  }
  if (!kontak.some((k) => !k.hapus)) return ui.toast('Isi sedikitnya satu kontak orang tua atau wali.', 'galat')
  if (!kontak.some((k) => k.utama && k.no_hp)) {
    const ada = kontak.find((k) => !k.hapus && k.no_hp)
    if (ada) { ada.utama = true; d.utama = ada.hubungan }
  }
  const { utama, ...isi } = d
  Object.assign(isi, { nis: d.nis.trim(), nisn: d.nisn.trim(), nik: d.nik.trim(), tingkat: Number(d.tingkat), kontak })
  proses.value = true
  try {
    const id = await san.simpan(isi)
    ui.toast(baru.value ? 'Data santri ditambahkan.' : 'Perubahan data santri disimpan.')
    router.replace(`/santri/${id}`)
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
const WARNA_KONTAK = { ayah: 'pegawai', ibu: 'klinik', wali: 'tahfizh' }
</script>
<template>
  <form v-if="f" class="mx-auto max-w-4xl space-y-4" novalidate @submit.prevent="simpan">
    <!-- Identitas -->
    <section class="kartu w-santri p-5">
      <div class="mb-4 flex items-center gap-3"><span class="chip-ikon h-10 w-10"><PhIdentificationCard :size="22" weight="duotone" /></span><h2 class="judul-bagian">Identitas santri</h2></div>
      <div class="grid gap-4 sm:grid-cols-2">
        <div>
          <label class="label-isian" for="s-nis">NIS (7 digit) <span class="text-merah">*</span></label>
          <div class="flex gap-2">
            <input id="s-nis" v-model="f.nis" class="isian tabular-nums" inputmode="numeric" maxlength="7" placeholder="Contoh 2211010" />
            <button v-if="awalanNIS" type="button" class="tombol-garis shrink-0 px-3" :title="`Nomor berikutnya untuk awalan ${awalanNIS}`" @click="isiNISBerikutnya">
              <PhMagicWand :size="20" weight="duotone" /><span class="hidden sm:inline">Nomor berikutnya</span></button>
          </div>
          <p class="mt-1 text-xs" :class="infoNIS ? 'text-teks2' : 'text-teks3'">
            {{ infoNIS ? `Masuk ${infoNIS.tahun} · Angkatan ${infoNIS.angkatan} · Nomor ${infoNIS.nomor}` : 'Ketik 4 digit awal (tahun + angkatan) lalu ketuk Nomor berikutnya.' }}</p>
        </div>
        <div><label class="label-isian" for="s-nisn">NISN (10 digit)</label><input id="s-nisn" v-model="f.nisn" class="isian tabular-nums" inputmode="numeric" maxlength="10" /></div>
        <div class="sm:col-span-2"><label class="label-isian" for="s-nama">Nama lengkap <span class="text-merah">*</span></label>
          <input id="s-nama" v-model="f.nama_lengkap" class="isian" placeholder="Sesuai akta kelahiran/ijazah" /></div>
        <div><label class="label-isian" for="s-pgl">Nama panggilan</label><input id="s-pgl" v-model="f.nama_panggilan" class="isian" /></div>
        <div><p class="label-isian">Jenis kelamin <span class="text-merah">*</span></p>
          <div class="grid grid-cols-2 gap-1 rounded-2xl bg-permukaan2 p-1" role="radiogroup" aria-label="Jenis kelamin">
            <button v-for="j in [{ k: 'L', n: 'Laki-laki' }, { k: 'P', n: 'Perempuan' }]" :key="j.k" type="button" role="radio" :aria-checked="f.jenis_kelamin === j.k" @click="f.jenis_kelamin = j.k"
              :class="['min-h-[44px] rounded-xl text-sm font-semibold', f.jenis_kelamin === j.k ? 'bg-permukaan text-teks shadow-kartu' : 'text-teks2']">{{ j.n }}</button>
          </div></div>
        <div><label class="label-isian" for="s-tmp">Tempat lahir</label><input id="s-tmp" v-model="f.tempat_lahir" class="isian" /></div>
        <InputTanggal v-model="f.tanggal_lahir" label="Tanggal lahir" bawaan-kosong />
        <div><label class="label-isian" for="s-nik">NIK (16 digit)</label><input id="s-nik" v-model="f.nik" class="isian tabular-nums" inputmode="numeric" maxlength="16" /></div>
        <div><label class="label-isian" for="s-anak">Anak ke-</label><input id="s-anak" v-model="f.anak_ke" class="isian" type="number" min="1" max="30" /></div>
        <div class="sm:col-span-2"><label class="label-isian" for="s-almt">Alamat rumah</label><textarea id="s-almt" v-model="f.alamat" class="isian min-h-[72px]" rows="2" /></div>
      </div>
    </section>

    <!-- Pendidikan dan masuk -->
    <section class="kartu w-laporan p-5">
      <div class="mb-4 flex items-center gap-3"><span class="chip-ikon h-10 w-10"><PhGraduationCap :size="22" weight="duotone" /></span><h2 class="judul-bagian">Jenjang dan masuk pondok</h2></div>
      <div class="grid gap-4 sm:grid-cols-2">
        <div><p class="label-isian">Jenjang sekolah <span class="text-merah">*</span></p>
          <div class="grid grid-cols-2 gap-1 rounded-2xl bg-permukaan2 p-1" role="radiogroup" aria-label="Jenjang">
            <button v-for="(n, k) in JENJANG" :key="k" type="button" role="radio" :aria-checked="f.jenjang === k" @click="f.jenjang = k"
              :class="['min-h-[44px] rounded-xl text-sm font-semibold', f.jenjang === k ? 'bg-permukaan text-teks shadow-kartu' : 'text-teks2']">{{ n }}</button>
          </div></div>
        <div><p class="label-isian">Kelas <span class="text-merah">*</span></p>
          <div class="grid grid-cols-3 gap-1 rounded-2xl bg-permukaan2 p-1" role="radiogroup" aria-label="Kelas">
            <button v-for="t in TINGKAT[f.jenjang]" :key="t" type="button" role="radio" :aria-checked="Number(f.tingkat) === t" @click="f.tingkat = t"
              :class="['min-h-[44px] rounded-xl text-sm font-semibold tabular-nums', Number(f.tingkat) === t ? 'bg-permukaan text-teks shadow-kartu' : 'text-teks2']">Kelas {{ t }}</button>
          </div>
          <p class="mt-1 text-xs text-teks3">Rombel (mis. 7A) dan kamar/halaqah diatur di Kelompok Santri.</p></div>
        <div><p class="label-isian">Jalur masuk</p>
          <div class="grid grid-cols-2 gap-1 rounded-2xl bg-permukaan2 p-1" role="radiogroup" aria-label="Jalur masuk">
            <button v-for="j in [{ k: 'baru', n: 'Santri baru' }, { k: 'pindahan', n: 'Pindahan' }]" :key="j.k" type="button" role="radio" :aria-checked="f.jalur_masuk === j.k" @click="f.jalur_masuk = j.k"
              :class="['min-h-[44px] rounded-xl text-sm font-semibold', f.jalur_masuk === j.k ? 'bg-permukaan text-teks shadow-kartu' : 'text-teks2']">{{ j.n }}</button>
          </div></div>
        <InputTanggal v-model="f.tanggal_masuk" label="Tanggal masuk pondok" :bawaan-kosong="!baru" />
        <div><label class="label-isian" for="s-asal">Asal sekolah <span v-if="f.jalur_masuk === 'pindahan'" class="text-merah">*</span></label>
          <input id="s-asal" v-model="f.asal_sekolah" class="isian" :placeholder="f.jalur_masuk === 'pindahan' ? 'Sekolah/pondok sebelumnya' : 'SD/MI atau SMP/MTs asal'" /></div>
        <div><label class="label-isian" for="s-hfz">Hafalan awal (juz)</label>
          <input id="s-hfz" v-model="f.hafalan_awal_juz" class="isian" type="number" min="0" max="30" step="0.5" placeholder="Contoh 2,5" />
          <p class="mt-1 text-xs text-teks3">Hafalan saat masuk; capaian resmi dicatat di menu Tahfizh.</p></div>
      </div>
      <p v-if="f.jalur_masuk === 'pindahan'" class="mt-3 flex gap-1.5 rounded-xl bg-permukaan2 p-3 text-xs text-teks2"><PhInfo :size="14" class="mt-0.5 shrink-0" />Data pindahan otomatis tercatat sebagai mutasi masuk (asal sekolah, tanggal masuk, kelas penempatan, hafalan awal).</p>
    </section>

    <!-- Kontak -->
    <section class="kartu w-pegawai p-5">
      <div class="mb-1 flex items-center gap-3"><span class="chip-ikon h-10 w-10"><PhUsersThree :size="22" weight="duotone" /></span><h2 class="judul-bagian">Orang tua dan wali</h2></div>
      <p class="mb-4 text-sm text-teks3">Nomor HP dipakai untuk pesan WA dan kelak login portal wali. Pilih satu sebagai penerima WA utama.</p>
      <div class="grid gap-3 lg:grid-cols-3">
        <div v-for="k in f.kontak" :key="k.hubungan" :class="['rounded-2xl border border-garis p-4', 'w-' + WARNA_KONTAK[k.hubungan]]">
          <p class="mb-3 font-bold" style="color: var(--c)">{{ HUBUNGAN[k.hubungan] }}</p>
          <div class="space-y-3">
            <div><label class="label-isian" :for="`k-n-${k.hubungan}`">Nama</label><input :id="`k-n-${k.hubungan}`" v-model="k.nama" class="isian" /></div>
            <div><label class="label-isian" :for="`k-h-${k.hubungan}`">Nomor HP/WA</label><input :id="`k-h-${k.hubungan}`" v-model="k.no_hp" class="isian tabular-nums" inputmode="tel" placeholder="08xxxxxxxxxx" /></div>
            <div><label class="label-isian" :for="`k-p-${k.hubungan}`">Pekerjaan</label><input :id="`k-p-${k.hubungan}`" v-model="k.pekerjaan" class="isian" /></div>
            <label class="flex min-h-[44px] cursor-pointer items-center gap-2 text-sm font-semibold">
              <input v-model="f.utama" type="radio" name="utama" :value="k.hubungan" class="h-5 w-5 accent-[#1E7D4F]" />
              <PhWhatsappLogo :size="18" weight="duotone" style="color: var(--c)" /> Penerima WA utama</label>
          </div>
        </div>
      </div>
    </section>

    <section class="kartu p-5">
      <label class="label-isian" for="s-cat">Catatan (opsional)</label>
      <textarea id="s-cat" v-model="f.catatan" class="isian min-h-[72px]" rows="2" placeholder="Catatan administrasi; jangan menulis data kesehatan di sini." />
    </section>

    <div class="flex flex-wrap justify-end gap-2 pb-4">
      <button type="button" class="tombol-garis" @click="router.back()">Batal</button>
      <button class="tombol-utama" :disabled="proses"><PhFloppyDisk :size="20" weight="duotone" /> {{ proses ? 'Menyimpan…' : baru ? 'Simpan santri baru' : 'Simpan perubahan' }}</button>
    </div>
  </form>
  <p v-else class="py-16 text-center text-teks3">Memuat formulir…</p>
</template>
