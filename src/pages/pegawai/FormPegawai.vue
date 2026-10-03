<!-- SIMKA PRO | src/pages/pegawai/FormPegawai.vue | v1.0 | Fase 1 – Data pegawai | 03/10/2026 -->
<script setup>
// Tambah dan ubah data pegawai lengkap (Bagian 8 blueprint).
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { PhFloppyDisk, PhIdentificationCard, PhBriefcase, PhPhone, PhInfo } from '@phosphor-icons/vue'
import { usePegawai } from '@/stores/pegawai'
import { useOrganisasi } from '@/stores/organisasi'
import { useUI } from '@/stores/ui'
import { hariIniISO, formatPanjang } from '@/lib/tanggal'
import { STATUS_PEGAWAI, KATEGORI_HONORER, PENDIDIKAN, STATUS_KELUARGA, LEVEL_MUHAFFIZH, KEAKTIFAN, masaKerja } from '@/lib/kepegawaian'
import InputTanggal from '@/components/InputTanggal.vue'

const route = useRoute(); const router = useRouter()
const peg = usePegawai(); const org = useOrganisasi(); const ui = useUI()
const baru = computed(() => !route.params.id)
const f = ref(null); const proses = ref(false)
const lama = ref(null) // salinan awal untuk mendeteksi perubahan yang memengaruhi riwayat

onMounted(async () => {
  await Promise.all([org.muat(), peg.daftar.length ? null : peg.muat()])
  if (baru.value) {
    f.value = { nama_lengkap: '', niy: '', jenis_kelamin: '', tempat_lahir: '', tanggal_lahir: '', tmt_tugas: '', status_kepegawaian: '', kategori_honorer: '',
      pendidikan_terakhir: '', status_keluarga: '', no_hp: '', email: '', org_unit_id: '', fungsional_ids: [], struktural_id: '', unit_struktural_id: '',
      level_muhaffizh: '', status_keaktifan: 'aktif', tanggal_berlaku: '' }
  } else {
    const p = peg.cari(route.params.id)
    if (!p) { ui.toast('Data pegawai tidak ditemukan.', 'galat'); return router.replace('/pegawai') }
    f.value = {
      id: p.id, nama_lengkap: p.nama_lengkap, niy: p.niy || '', jenis_kelamin: p.jenis_kelamin || '', tempat_lahir: p.tempat_lahir || '',
      tanggal_lahir: p.tanggal_lahir || '', tmt_tugas: p.tmt_tugas || '', status_kepegawaian: p.status_kepegawaian || '', kategori_honorer: p.kategori_honorer || '',
      pendidikan_terakhir: p.pendidikan_terakhir || '', status_keluarga: p.status_keluarga || '', no_hp: p.no_hp || '', email: p.email || '',
      org_unit_id: p.org_unit_id || '', fungsional_ids: [...(p.fungsional_ids || [])], struktural_id: p.structural_position_id || '',
      unit_struktural_id: p.unit_struktural_id || '', level_muhaffizh: p.level_muhaffizh || '', status_keaktifan: p.status_keaktifan || 'aktif', tanggal_berlaku: '',
    }
    lama.value = JSON.stringify(f.value)
  }
})

const punyaAkun = computed(() => !baru.value && !!peg.cari(route.params.id)?.user_id)
const fungsionalAktif = computed(() => org.fungsional.filter((j) => j.aktif || f.value?.fungsional_ids.includes(j.id)))
const strukturalAktif = computed(() => [...org.struktural].filter((j) => j.aktif || j.id === f.value?.struktural_id).sort((a, b) => a.tingkat - b.tingkat))
const muhaffizh = computed(() => f.value?.fungsional_ids.some((id) => org.fungsional.find((j) => j.id === id)?.kode === 'MUHAFFIZH'))
const masa = computed(() => masaKerja(f.value?.tmt_tugas))

// Aturan tidak rangkap: jabatan bertanda tanpa_rangkap tidak boleh digabung dengan jabatan lain
function pilihFungsional(j) {
  const ids = new Set(f.value.fungsional_ids)
  if (ids.has(j.id)) { ids.delete(j.id) } else {
    const lainTunggal = [...ids].some((id) => org.fungsional.find((x) => x.id === id)?.tanpa_rangkap)
    if (j.tanpa_rangkap && ids.size) return ui.toast(`${j.nama} tidak dapat dirangkap. Hapus centang jabatan lain lebih dulu.`, 'galat')
    if (lainTunggal) return ui.toast('Jabatan medis atau security tidak dapat dirangkap dengan jabatan lain.', 'galat')
    ids.add(j.id)
  }
  f.value.fungsional_ids = [...ids]
}

async function simpan() {
  const d = f.value
  if ((d.nama_lengkap || '').trim().length < 3) return ui.toast('Nama lengkap bergelar wajib diisi (minimal 3 huruf).', 'galat')
  if (d.no_hp && !/^[0-9+]{9,16}$/.test(d.no_hp.replace(/[\s-]/g, ''))) return ui.toast('Nomor HP harus 9–16 angka.', 'galat')
  if (d.email && !/^\S+@\S+\.\S+$/.test(d.email)) return ui.toast('Format email tidak sah.', 'galat')
  if (d.struktural_id && !d.unit_struktural_id) d.unit_struktural_id = d.org_unit_id
  const isi = { ...d, no_hp: d.no_hp.replace(/[\s-]/g, ''), kategori_honorer: d.status_kepegawaian === 'honorer' ? d.kategori_honorer : '',
    level_muhaffizh: muhaffizh.value ? d.level_muhaffizh : '' }
  if (!baru.value) delete isi.email // email akun diubah lewat menu kelola akun
  proses.value = true
  try {
    const id = await peg.simpan(isi)
    ui.toast(baru.value ? 'Data pegawai ditambahkan.' : 'Perubahan data pegawai disimpan.')
    router.replace(`/pegawai/${id}`)
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
</script>
<template>
  <form v-if="f" class="mx-auto max-w-4xl space-y-4" @submit.prevent="simpan" novalidate>
    <!-- Identitas -->
    <section class="kartu w-pegawai p-5">
      <div class="mb-4 flex items-center gap-3"><span class="chip-ikon h-10 w-10"><PhIdentificationCard :size="22" weight="duotone" /></span><h2 class="judul-bagian">Identitas</h2></div>
      <div class="grid gap-4 sm:grid-cols-2">
        <div class="sm:col-span-2"><label class="label-isian" for="pg-nama">Nama lengkap bergelar <span class="text-merah">*</span></label>
          <input id="pg-nama" v-model="f.nama_lengkap" class="isian" placeholder="Seperti tertulis di dokumen resmi, contoh: Ust. Hasan Basri, Lc." /></div>
        <div><label class="label-isian" for="pg-niy">NIY (Nomor Induk Yayasan)</label><input id="pg-niy" v-model="f.niy" class="isian" inputmode="numeric" /></div>
        <div><p class="label-isian">Jenis kelamin</p>
          <div class="grid grid-cols-2 gap-1 rounded-2xl bg-permukaan2 p-1" role="radiogroup" aria-label="Jenis kelamin">
            <button v-for="j in [{ k: 'L', n: 'Laki-laki' }, { k: 'P', n: 'Perempuan' }]" :key="j.k" type="button" role="radio" :aria-checked="f.jenis_kelamin === j.k" @click="f.jenis_kelamin = j.k"
              :class="['min-h-[44px] rounded-xl text-sm font-semibold', f.jenis_kelamin === j.k ? 'bg-permukaan text-teks shadow-kartu' : 'text-teks2']">{{ j.n }}</button>
          </div></div>
        <div><label class="label-isian" for="pg-tmp">Tempat lahir</label><input id="pg-tmp" v-model="f.tempat_lahir" class="isian" /></div>
        <InputTanggal v-model="f.tanggal_lahir" label="Tanggal lahir" bawaan-kosong />
        <div><label class="label-isian" for="pg-pend">Pendidikan terakhir</label>
          <select id="pg-pend" v-model="f.pendidikan_terakhir" class="isian"><option value="">Belum diisi</option><option v-for="(n, k) in PENDIDIKAN" :key="k" :value="k">{{ n }}</option></select></div>
        <div><label class="label-isian" for="pg-kel">Status keluarga</label>
          <select id="pg-kel" v-model="f.status_keluarga" class="isian"><option value="">Belum diisi</option><option v-for="(n, k) in STATUS_KELUARGA" :key="k" :value="k">{{ n }}</option></select></div>
      </div>
    </section>

    <!-- Kepegawaian dan jabatan -->
    <section class="kartu w-gaji p-5">
      <div class="mb-4 flex items-center gap-3"><span class="chip-ikon h-10 w-10"><PhBriefcase :size="22" weight="duotone" /></span><h2 class="judul-bagian">Kepegawaian dan jabatan</h2></div>
      <div class="grid gap-4 sm:grid-cols-2">
        <InputTanggal v-model="f.tmt_tugas" label="TMT tugas di pondok" :bawaan-kosong="!baru" />
        <div><p class="label-isian">Masa kerja</p><p class="isian flex items-center bg-permukaan2 text-teks2">{{ masa ? masa.teks : 'Terisi otomatis dari TMT' }}</p></div>
        <div><label class="label-isian" for="pg-stat">Status kepegawaian</label>
          <select id="pg-stat" v-model="f.status_kepegawaian" class="isian"><option value="">Belum diisi</option><option v-for="(n, k) in STATUS_PEGAWAI" :key="k" :value="k">{{ n }}</option></select></div>
        <div v-if="f.status_kepegawaian === 'honorer'"><label class="label-isian" for="pg-hon">Kategori honorer</label>
          <select id="pg-hon" v-model="f.kategori_honorer" class="isian"><option value="">Belum diisi</option><option v-for="(n, k) in KATEGORI_HONORER" :key="k" :value="k">{{ n }}</option></select></div>
        <div><label class="label-isian" for="pg-unit">Bidang/unit</label>
          <select id="pg-unit" v-model="f.org_unit_id" class="isian"><option value="">Belum ditentukan</option>
            <option v-for="u in org.datar.filter((x) => x.aktif || x.id === f.org_unit_id)" :key="u.id" :value="u.id">{{ '\u2003'.repeat(u.tingkat) }}{{ u.nama }}</option></select></div>
        <div><label class="label-isian" for="pg-akt">Status keaktifan</label>
          <select id="pg-akt" v-model="f.status_keaktifan" class="isian"><option v-for="(n, k) in KEAKTIFAN" :key="k" :value="k">{{ n }}</option></select></div>

        <div class="sm:col-span-2">
          <p class="label-isian">Jabatan fungsional (boleh lebih dari satu)</p>
          <div class="flex flex-wrap gap-1.5">
            <button v-for="j in fungsionalAktif" :key="j.id" type="button" :aria-pressed="f.fungsional_ids.includes(j.id)" @click="pilihFungsional(j)"
              :class="['min-h-[40px] rounded-full border px-3.5 text-sm font-semibold transition', f.fungsional_ids.includes(j.id) ? 'border-transparent bg-[#1E7D4F] text-white dark:bg-[#5BD69A] dark:text-[#10261B]' : 'border-garis text-teks2 hover:text-teks']">
              {{ j.nama }}<span v-if="j.tanpa_rangkap" class="ml-1 text-xs opacity-80">(tidak rangkap)</span></button>
          </div>
        </div>
        <div v-if="muhaffizh"><label class="label-isian" for="pg-lvl">Level muhaffizh</label>
          <select id="pg-lvl" v-model="f.level_muhaffizh" class="isian"><option value="">Belum diisi</option><option v-for="(n, k) in LEVEL_MUHAFFIZH" :key="k" :value="k">{{ n }}</option></select></div>

        <div><label class="label-isian" for="pg-str">Jabatan struktural (hanya satu)</label>
          <select id="pg-str" v-model="f.struktural_id" class="isian"><option value="">Tidak ada</option><option v-for="j in strukturalAktif" :key="j.id" :value="j.id">{{ j.nama }}</option></select></div>
        <div v-if="f.struktural_id"><label class="label-isian" for="pg-ustr">Cabang yang dipimpin</label>
          <select id="pg-ustr" v-model="f.unit_struktural_id" class="isian"><option value="">Sama dengan bidang/unit pegawai</option>
            <option v-for="u in org.datar" :key="u.id" :value="u.id">{{ '\u2003'.repeat(u.tingkat) }}{{ u.nama }}</option></select></div>
      </div>
      <div v-if="!baru" class="mt-4 rounded-xl bg-permukaan2 p-3">
        <InputTanggal v-model="f.tanggal_berlaku" label="Perubahan berlaku mulai (TMT perubahan)" />
        <p class="mt-1 flex gap-1.5 text-xs text-teks3"><PhInfo :size="14" class="mt-0.5 shrink-0" />Perubahan status, jabatan, pendidikan, level, dan bidang dicatat di riwayat kepegawaian dengan tanggal ini. Gaji mengikuti data yang berlaku pada periodenya.</p>
      </div>
    </section>

    <!-- Kontak -->
    <section class="kartu w-profil p-5">
      <div class="mb-4 flex items-center gap-3"><span class="chip-ikon h-10 w-10"><PhPhone :size="22" weight="duotone" /></span><h2 class="judul-bagian">Kontak</h2></div>
      <div class="grid gap-4 sm:grid-cols-2">
        <div><label class="label-isian" for="pg-hp">Nomor HP/WA</label><input id="pg-hp" v-model="f.no_hp" class="isian" inputmode="tel" placeholder="08xxxxxxxxxx" /></div>
        <div><label class="label-isian" for="pg-email">Email</label>
          <input id="pg-email" v-model="f.email" type="email" class="isian" :disabled="!baru" />
          <p v-if="!baru" class="mt-1 text-xs text-teks3">{{ punyaAkun ? 'Email akun diubah melalui menu Verifikasi Akun.' : 'Email diisi saat pegawai mendaftar.' }}</p></div>
      </div>
    </section>

    <div class="flex flex-wrap justify-end gap-2 pb-4">
      <button type="button" class="tombol-garis" @click="router.back()">Batal</button>
      <button class="tombol-utama" :disabled="proses"><PhFloppyDisk :size="20" weight="duotone" /> {{ proses ? 'Menyimpan…' : baru ? 'Simpan pegawai baru' : 'Simpan perubahan' }}</button>
    </div>
  </form>
  <p v-else class="py-16 text-center text-teks3">Memuat formulir…</p>
</template>
