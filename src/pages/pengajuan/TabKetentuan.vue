<!-- SIMKA PRO | src/pages/pengajuan/TabKetentuan.vue | v1.1 | Fase 8 – Tahap 0b Kepala Unit tidak lagi menyetujui pengajuan | 10/10/2026 -->
<script setup>
// Ketentuan pengajuan: dibaca semua pegawai; diubah admin ber-izin "atur_pengajuan" dan superadmin.
// Berisi jenis pengajuan beserta aturannya, jenjang persetujuan menurut lama hari, dan penunjukan Plt.
import { ref, computed, onMounted } from 'vue'
import { PhPencilSimple, PhPlus, PhTrash, PhFloppyDisk, PhInfo, PhUserSwitch, PhStairs, PhListBullets } from '@phosphor-icons/vue'
import { usePengajuan } from '@/stores/pengajuan'
import { useOrganisasi } from '@/stores/organisasi'
import { usePegawai } from '@/stores/pegawai'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { KELOMPOK, PERAN_JENJANG, kalimatAturan } from '@/lib/pengajuan'
import { formatPanjang, hariIniISO } from '@/lib/tanggal'
import LembarBawah from '@/components/LembarBawah.vue'
import InputTanggal from '@/components/InputTanggal.vue'

const pg = usePengajuan(); const org = useOrganisasi(); const peg = usePegawai(); const sesi = useSesi(); const ui = useUI()
const boleh = computed(() => sesi.bolehAdmin('atur_pengajuan'))
onMounted(async () => { await Promise.all([pg.muatKetentuan(), org.muat()]); if (boleh.value && !peg.daftar.length) peg.muat() })

// ---------- Jenis ----------
const fj = ref(null)
const ANGKA = ['maks_hari', 'kuota_tahunan_hari', 'batas_bulanan_hari', 'batas_bulanan_kali', 'lampiran_wajib_min_hari', 'maju_maks_hari']
function ubahJenis(j) { fj.value = j ? { ...j } : { _baru: true, kode: '', nama: '', kelompok: 'cuti', status_presensi: 'cuti', keterangan: '', aturan_kuota: 'tolak', mundur_maks_hari: 0, maju_min_hari: 0, aktif: true, urutan: pg.jenis.length + 1 } }
async function simpanJenis() {
  const j = { ...fj.value }
  if (j.nama.trim().length < 3) return ui.toast('Nama jenis minimal 3 karakter.', 'galat')
  if (j._baru) j.kode = (j.kode || j.nama).toUpperCase().replace(/[^A-Z0-9]+/g, '_').replace(/^_|_$/g, '').slice(0, 30)
  for (const k of ANGKA) j[k] = j[k] === '' || j[k] == null ? null : Number(j[k])
  j.mundur_maks_hari = Number(j.mundur_maks_hari || 0); j.maju_min_hari = Number(j.maju_min_hari || 0)
  j.status_presensi = j.kelompok; j.khusus_jk = j.khusus_jk || null
  try { await pg.simpanJenis(j); fj.value = null; ui.toast('Jenis pengajuan disimpan.', 'info') } catch (e) { ui.toast(e.message, 'galat') }
}

// ---------- Jenjang ----------
const edJenjang = ref(null)
function ubahJenjang() { edJenjang.value = pg.jenjang.map((t) => ({ ...t, langkah: [...t.langkah] })) }
function balikLangkah(t, p) {
  const s = new Set(t.langkah); s.has(p) ? s.delete(p) : s.add(p)
  t.langkah = Object.keys(PERAN_JENJANG).filter((k) => s.has(k))
}
async function simpanJenjang() {
  const d = edJenjang.value.map((t) => ({ ...t, mulai_hari: Number(t.mulai_hari), sampai_hari: t.sampai_hari === '' || t.sampai_hari == null ? null : Number(t.sampai_hari) }))
  if (d.some((t) => !t.langkah.length || !(t.mulai_hari >= 1) || (t.sampai_hari != null && t.sampai_hari < t.mulai_hari))) return ui.toast('Periksa kembali: setiap aturan wajib memiliki jenjang dan rentang hari yang benar.', 'galat')
  try { await pg.simpanJenjang(d.sort((a, b) => a.mulai_hari - b.mulai_hari)); edJenjang.value = null; ui.toast('Jenjang persetujuan disimpan.', 'info') } catch (e) { ui.toast(e.message, 'galat') }
}
const rentang = (t) => (t.sampai_hari == null ? `${t.mulai_hari} hari atau lebih` : t.mulai_hari === t.sampai_hari ? `${t.mulai_hari} hari` : `${t.mulai_hari}–${t.sampai_hari} hari`)

// ---------- Plt ----------
const fp = ref(null)
const pltTampil = computed(() => pg.plt.filter((p) => p.sampai >= hariIniISO()))
function tambahPlt() { fp.value = { employee_id: '', structural_position_id: '', org_unit_id: '', mulai: hariIniISO(), sampai: hariIniISO(), catatan: '' } }
async function simpanPlt() {
  const p = fp.value
  if (!p.employee_id || !p.structural_position_id) return ui.toast('Pilih pegawai dan jabatan yang dijabat sebagai Plt.', 'galat')
  if (p.sampai < p.mulai) return ui.toast('Tanggal selesai tidak boleh sebelum tanggal mulai.', 'galat')
  const sp = org.struktural.find((x) => x.id === p.structural_position_id)
  if (sp && ['KEPALA_BIDANG', 'KEPALA_UNIT'].includes(sp.kode) && !p.org_unit_id) return ui.toast('Pilih bidang/unit yang dipimpin Plt.', 'galat')
  try {
    await pg.simpanPlt({ ...p, employees: { nama_lengkap: peg.cari(p.employee_id)?.nama_lengkap }, structural_positions: { nama: sp?.nama }, org_units: p.org_unit_id ? { nama: org.cariUnit(p.org_unit_id)?.nama } : null })
    fp.value = null; ui.toast('Plt ditetapkan.', 'info')
  } catch (e) { ui.toast(e.message, 'galat') }
}
async function hapusPlt(p) {
  if (!(await ui.konfirmasi({ judul: 'Akhiri penunjukan Plt?', pesan: `${p.employees?.nama_lengkap} sebagai Plt. ${p.structural_positions?.nama}.`, ya: 'Hapus', bahaya: true }))) return
  try { await pg.hapusPlt(p.id); ui.toast('Penunjukan Plt dihapus.', 'info') } catch (e) { ui.toast(e.message, 'galat') }
}
</script>
<template>
  <div class="space-y-5">
    <section class="kartu w-pengajuan p-5">
      <div class="mb-3 flex flex-wrap items-center gap-3">
        <span class="chip-ikon h-10 w-10"><PhListBullets :size="22" weight="duotone" /></span>
        <div class="flex-1"><h3 class="judul-bagian">Jenis pengajuan dan aturannya</h3><p class="text-sm text-teks3">Lama hari dihitung hari kalender.</p></div>
        <button v-if="boleh" class="tombol-garis" @click="ubahJenis(null)"><PhPlus :size="18" weight="bold" /> Tambah jenis</button>
      </div>
      <ul class="grid gap-3 md:grid-cols-2">
        <li v-for="j in pg.jenis" :key="j.id" :class="['rounded-2xl border border-garis p-4', 'w-' + KELOMPOK[j.kelompok].w, !j.aktif && 'opacity-60']">
          <div class="flex items-start gap-2">
            <span class="chip-ikon h-9 w-9 shrink-0 rounded-lg"><component :is="KELOMPOK[j.kelompok].ikon" :size="20" weight="duotone" /></span>
            <div class="min-w-0 flex-1"><p class="font-bold">{{ j.nama }}</p><p class="text-xs text-teks3">{{ KELOMPOK[j.kelompok].n }}{{ j.aktif ? '' : ' · nonaktif' }}</p></div>
            <button v-if="boleh" class="tombol-ikon -mr-2 -mt-1" :aria-label="`Ubah ${j.nama}`" @click="ubahJenis(j)"><PhPencilSimple :size="20" /></button>
          </div>
          <p v-if="j.keterangan" class="mt-2 text-sm text-teks2">{{ j.keterangan }}</p>
          <ul class="mt-1.5 list-disc space-y-0.5 pl-5 text-sm text-teks2"><li v-for="k in kalimatAturan(j)" :key="k">{{ k }}</li>
            <li v-if="!kalimatAturan(j).length">Tanpa batasan khusus.</li></ul>
        </li>
      </ul>
    </section>

    <section class="kartu w-verifikasi p-5">
      <div class="mb-3 flex flex-wrap items-center gap-3">
        <span class="chip-ikon h-10 w-10"><PhStairs :size="22" weight="duotone" /></span>
        <div class="flex-1"><h3 class="judul-bagian">Jenjang persetujuan</h3><p class="text-sm text-teks3">Naik ke jenjang berikutnya setelah jenjang sebelumnya menyetujui.</p></div>
        <button v-if="boleh && !edJenjang" class="tombol-garis" @click="ubahJenjang"><PhPencilSimple :size="18" /> Ubah</button>
      </div>
      <ul v-if="!edJenjang" class="divide-y divide-garis">
        <li v-for="t in pg.jenjang" :key="t.id" class="flex flex-wrap items-center gap-2 py-2.5">
          <span class="w-36 font-semibold">{{ rentang(t) }}</span>
          <span class="flex flex-wrap items-center gap-1.5 text-sm"><template v-for="(p, i) in t.langkah" :key="p"><span v-if="i" class="text-teks3">→</span><span class="lencana">{{ PERAN_JENJANG[p] }}</span></template></span>
        </li>
      </ul>
      <div v-else class="space-y-3">
        <div v-for="(t, i) in edJenjang" :key="i" class="rounded-xl border border-garis p-3">
          <div class="flex flex-wrap items-end gap-2">
            <div class="w-28"><label class="label-isian" :for="`jj-m${i}`">Dari (hari)</label><input :id="`jj-m${i}`" v-model="t.mulai_hari" type="number" min="1" class="isian" /></div>
            <div class="w-32"><label class="label-isian" :for="`jj-s${i}`">Sampai (kosong = seterusnya)</label><input :id="`jj-s${i}`" v-model="t.sampai_hari" type="number" min="1" class="isian" /></div>
            <button class="tombol-ikon ml-auto" :aria-label="`Hapus aturan ${i + 1}`" @click="edJenjang.splice(i, 1)"><PhTrash :size="20" /></button>
          </div>
          <div class="mt-2 flex flex-wrap gap-3">
            <label v-for="(n, k) in PERAN_JENJANG" :key="k" class="flex min-h-[40px] items-center gap-2 text-sm font-semibold"><input type="checkbox" class="h-5 w-5 accent-[#2F5FA8]" :checked="t.langkah.includes(k)" @change="balikLangkah(t, k)" />{{ n }}</label>
          </div>
        </div>
        <div class="flex flex-wrap gap-2">
          <button class="tombol-garis" @click="edJenjang.push({ mulai_hari: '', sampai_hari: '', langkah: ['kepala_bidang'] })"><PhPlus :size="18" /> Tambah aturan</button>
          <button class="tombol-utama" @click="simpanJenjang"><PhFloppyDisk :size="20" weight="duotone" /> Simpan</button>
          <button class="tombol-teks" @click="edJenjang = null">Batal</button>
        </div>
      </div>
      <p class="mt-3 flex gap-2 text-sm text-teks3"><PhInfo :size="18" class="mt-0.5 shrink-0" />
        Kepala Bidang adalah kepala bidang tempat unit pemohon bernaung (Kepala Unit tidak menyetujui pengajuan). Direktur dan Wakil Direktur berwenang sama; salah satunya cukup. Wakil kepala bidang menyetujui hanya bila ditunjuk sebagai Plt. Jenjang tanpa pejabat dilewati, dan bila semua kosong pengajuan naik ke jenjang lebih tinggi.</p>
    </section>

    <section class="kartu w-shift p-5">
      <div class="mb-3 flex flex-wrap items-center gap-3">
        <span class="chip-ikon h-10 w-10"><PhUserSwitch :size="22" weight="duotone" /></span>
        <div class="flex-1"><h3 class="judul-bagian">Pelaksana tugas (Plt)</h3><p class="text-sm text-teks3">Plt berwenang menyetujui seperti pejabat definitif selama masa tugasnya.</p></div>
        <button v-if="boleh" class="tombol-garis" @click="tambahPlt"><PhPlus :size="18" weight="bold" /> Tetapkan Plt</button>
      </div>
      <ul class="divide-y divide-garis">
        <li v-for="p in pltTampil" :key="p.id" class="flex items-center gap-3 py-2.5">
          <div class="min-w-0 flex-1"><p class="font-semibold">{{ p.employees?.nama_lengkap }}</p>
            <p class="text-sm text-teks2">Plt. {{ p.structural_positions?.nama }}{{ p.org_units?.nama ? ' ' + p.org_units.nama : '' }}</p>
            <p class="text-xs text-teks3">{{ formatPanjang(p.mulai) }} s.d. {{ formatPanjang(p.sampai) }}{{ p.catatan ? ' · ' + p.catatan : '' }}</p></div>
          <button v-if="boleh" class="tombol-ikon" :aria-label="`Hapus Plt ${p.employees?.nama_lengkap}`" @click="hapusPlt(p)"><PhTrash :size="20" /></button>
        </li>
        <li v-if="!pltTampil.length" class="py-3 text-sm text-teks3">Tidak ada Plt yang berlaku.</li>
      </ul>
    </section>

    <!-- Lembar ubah jenis -->
    <LembarBawah :model-value="!!fj" @update:model-value="(v) => !v && (fj = null)" :judul="fj?._baru ? 'Tambah jenis pengajuan' : 'Ubah jenis pengajuan'">
      <form v-if="fj" class="space-y-3 pb-2" @submit.prevent="simpanJenis">
        <div class="grid gap-3 sm:grid-cols-2">
          <div><label class="label-isian" for="jn-nama">Nama</label><input id="jn-nama" v-model="fj.nama" class="isian" required /></div>
          <div><label class="label-isian" for="jn-kel">Dicatat di presensi sebagai</label>
            <select id="jn-kel" v-model="fj.kelompok" class="isian"><option v-for="(k, kode) in KELOMPOK" :key="kode" :value="kode">{{ k.n }}</option></select></div>
        </div>
        <div><label class="label-isian" for="jn-ket">Penjelasan untuk pegawai</label><textarea id="jn-ket" v-model="fj.keterangan" class="isian min-h-[4.5rem] py-2" /></div>
        <div class="grid grid-cols-2 gap-3 sm:grid-cols-3">
          <div><label class="label-isian" for="jn-maks">Lama maksimal (hari)</label><input id="jn-maks" v-model="fj.maks_hari" type="number" min="1" class="isian" placeholder="Tanpa batas" /></div>
          <div><label class="label-isian" for="jn-kt">Kuota per tahun (hari)</label><input id="jn-kt" v-model="fj.kuota_tahunan_hari" type="number" min="0" class="isian" placeholder="Tanpa kuota" /></div>
          <div><label class="label-isian" for="jn-bh">Batas per bulan (hari)</label><input id="jn-bh" v-model="fj.batas_bulanan_hari" type="number" min="0" class="isian" placeholder="Tanpa batas" /></div>
          <div><label class="label-isian" for="jn-bk">Batas per bulan (kali)</label><input id="jn-bk" v-model="fj.batas_bulanan_kali" type="number" min="0" class="isian" placeholder="Tanpa batas" /></div>
          <div class="col-span-2"><label class="label-isian" for="jn-ak">Bila melebihi kuota/batas</label>
            <select id="jn-ak" v-model="fj.aturan_kuota" class="isian"><option value="tolak">Tidak dapat diajukan</option><option value="peringatan">Tetap dapat diajukan dengan tanda peringatan</option></select></div>
        </div>
        <div class="grid grid-cols-2 gap-3 sm:grid-cols-3">
          <div><label class="label-isian" for="jn-min">Diajukan paling lambat H-</label><input id="jn-min" v-model="fj.maju_min_hari" type="number" min="0" class="isian" /></div>
          <div><label class="label-isian" for="jn-mj">Mulai paling jauh (hari ke depan)</label><input id="jn-mj" v-model="fj.maju_maks_hari" type="number" min="0" class="isian" placeholder="Bebas; 0 = hari ini" /></div>
          <div><label class="label-isian" for="jn-mn">Boleh susulan (hari)</label><input id="jn-mn" v-model="fj.mundur_maks_hari" type="number" min="0" class="isian" /></div>
        </div>
        <div class="grid gap-3 sm:grid-cols-2">
          <div><label class="label-isian" for="jn-lw">Lampiran wajib bila lama ≥ (hari)</label><input id="jn-lw" v-model="fj.lampiran_wajib_min_hari" type="number" min="1" class="isian" placeholder="Kosong = opsional" /></div>
          <div><label class="label-isian" for="jn-lk">Jenis lampiran</label><input id="jn-lk" v-model="fj.lampiran_keterangan" class="isian" placeholder="Contoh: surat keterangan dokter" /></div>
          <div><label class="label-isian" for="jn-jk">Khusus jenis kelamin</label>
            <select id="jn-jk" v-model="fj.khusus_jk" class="isian"><option :value="null">Semua</option><option value="L">Laki-laki</option><option value="P">Perempuan</option></select></div>
          <div><label class="label-isian" for="jn-ur">Urutan tampil</label><input id="jn-ur" v-model.number="fj.urutan" type="number" class="isian" /></div>
        </div>
        <label class="flex min-h-[44px] items-center gap-3 font-semibold"><input v-model="fj.aktif" type="checkbox" class="h-5 w-5 accent-[#6D44B8]" /> Aktif (dapat dipilih pegawai)</label>
        <button class="tombol-utama w-full"><PhFloppyDisk :size="20" weight="duotone" /> Simpan</button>
      </form>
    </LembarBawah>

    <!-- Lembar Plt -->
    <LembarBawah :model-value="!!fp" @update:model-value="(v) => !v && (fp = null)" judul="Tetapkan Plt">
      <form v-if="fp" class="space-y-3 pb-2" @submit.prevent="simpanPlt">
        <div><label class="label-isian" for="plt-peg">Pegawai yang ditunjuk</label>
          <select id="plt-peg" v-model="fp.employee_id" class="isian"><option value="">Pilih pegawai</option>
            <option v-for="p in peg.daftar.filter((x) => x.status_akun === 'aktif')" :key="p.id" :value="p.id">{{ p.nama_lengkap }}</option></select></div>
        <div><label class="label-isian" for="plt-jab">Sebagai Plt. jabatan</label>
          <select id="plt-jab" v-model="fp.structural_position_id" class="isian"><option value="">Pilih jabatan</option>
            <option v-for="j in org.struktural" :key="j.id" :value="j.id">{{ j.nama }}</option></select></div>
        <div><label class="label-isian" for="plt-unit">Bidang (untuk Kepala Bidang)</label>
          <select id="plt-unit" v-model="fp.org_unit_id" class="isian"><option value="">–</option>
            <option v-for="u in org.datar" :key="u.id" :value="u.id">{{ '— '.repeat(u.tingkat) }}{{ u.nama }}</option></select></div>
        <div class="grid gap-3 sm:grid-cols-2"><InputTanggal v-model="fp.mulai" label="Mulai" /><InputTanggal v-model="fp.sampai" label="Sampai" /></div>
        <div><label class="label-isian" for="plt-cat">Keterangan</label><input id="plt-cat" v-model="fp.catatan" class="isian" placeholder="Contoh: Kepala bidang sedang cuti" /></div>
        <button class="tombol-utama w-full"><PhFloppyDisk :size="20" weight="duotone" /> Simpan</button>
      </form>
    </LembarBawah>
  </div>
</template>
