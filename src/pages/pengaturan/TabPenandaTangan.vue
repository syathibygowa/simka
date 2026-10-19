<!-- SIMKA PRO | src/pages/pengaturan/TabPenandaTangan.vue | v1.3 | 14.15.0: penanda tangan dan kop semua dokumen cetak diatur terpusat di sini | 19/10/2026 -->
<script setup>
import { ref, computed, onMounted } from 'vue'
import { PhPlus, PhPencilSimple, PhFloppyDisk, PhTrash, PhLink, PhMagnifyingGlass, PhArrowCounterClockwise, PhCaretDown, PhInfo } from '@phosphor-icons/vue'
import { KATALOG, KELOMPOK, PERAN, DIATUR_LAIN, peranUntuk } from '@/lib/aturanCetak'
import { useLembaga } from '@/stores/lembaga'
import { useOrganisasi } from '@/stores/organisasi'
import { usePegawai } from '@/stores/pegawai'
import { useUI } from '@/stores/ui'
import LembarBawah from '@/components/LembarBawah.vue'

// v1.2: pejabat yang diisi manual dapat ditautkan ke akun pegawai agar dapat menandatangani laporan resmi secara elektronik.
const lembaga = useLembaga(); const ui = useUI(); const org = useOrganisasi(); const peg = usePegawai()
onMounted(() => { org.muat(); if (!peg.daftar.length) peg.muat() })
function pilihAkun(id) { const p = peg.cari(id); f.value.employee_id = id || null; if (p) { f.value.nama = p.nama_lengkap; f.value.niy = p.niy || '' } }
const namaJabatan = (kode) => org.struktural.find((x) => x.kode === kode)?.nama || kode
const galat = (e) => ui.toast(e.message, 'galat')

// ---------- Daftar pejabat penanda tangan ----------
const lembar = ref(false); const f = ref({})
function buka(s = null) { f.value = s ? { ...s } : { _baru: true, jabatan_tertulis: '', nama: '', niy: '', aktif: true, urutan: lembaga.signatories.length + 1, sumber_jabatan: '', sumber_unit_id: '', employee_id: null }; lembar.value = true }
async function simpan() {
  const s = f.value
  if (!s.jabatan_tertulis?.trim() || (!s.sumber_jabatan && !s.nama?.trim())) return ui.toast('Jabatan dan nama lengkap wajib diisi.', 'galat')
  try {
    await lembaga.simpanBaris('signatories', { id: s.id, jabatan_tertulis: s.jabatan_tertulis.trim(), nama: s.nama?.trim() || '-', niy: s.niy?.trim() || null, aktif: s.aktif, urutan: s.urutan,
      sumber_jabatan: s.sumber_jabatan || null, sumber_unit_id: s.sumber_unit_id || null, employee_id: s.employee_id || null }, { baru: !!s._baru })
    lembar.value = false; ui.toast('Penanda tangan disimpan.')
  } catch (e) { galat(e) }
}
async function hapus(s) {
  const dipakai = lembaga.signer_rules.some((r) => r.kiri === s.id || r.kanan === s.id)
  if (dipakai) return ui.toast('Pejabat ini masih dipakai pada aturan dokumen di bawah. Ganti dulu aturannya, atau nonaktifkan saja.', 'galat')
  if (!(await ui.konfirmasi({ judul: 'Hapus penanda tangan?', pesan: `${s.jabatan_tertulis}: ${s.nama}. Dokumen lama tetap mencetak nama pejabat saat itu.`, ya: 'Hapus', bahaya: true }))) return
  try { await lembaga.hapusBaris('signatories', s.id); ui.toast('Penanda tangan dihapus.') } catch (e) { galat(e) }
}

// ---------- Aturan per jenis dokumen (14.15.0: katalog lib/aturanCetak.js) ----------
const cari = ref(''); const terbuka = ref({ [KELOMPOK[0]]: true })
const aturanDok = (kode) => lembaga.signer_rules.find((r) => r.jenis_dokumen === kode)
const nilai = (dok, kolom) => { const r = aturanDok(dok.kode); const b = { kiri: dok.bawaan.kiri, kanan: dok.bawaan.kanan, kop_kode: null }[kolom]
  return (r ? r[kolom] ?? b : b) || '' }
const ubahan = (dok) => ['kiri', 'kanan', 'kop_kode'].some((k) => nilai(dok, k) !== ({ kiri: dok.bawaan.kiri, kanan: dok.bawaan.kanan, kop_kode: null }[k] || ''))
const tampil = computed(() => { const q = cari.value.toLowerCase().trim()
  return KELOMPOK.map((k) => ({ k, dok: KATALOG.filter((d) => d.kelompok === k && (!q || `${d.nama} ${d.menu}`.toLowerCase().includes(q))) })).filter((x) => x.dok.length) })
const pejabatAktif = computed(() => lembaga.signatories.filter((x) => x.aktif))
async function simpanAturan(dok, ubah) {
  const ada = aturanDok(dok.kode)
  try {
    await lembaga.simpanBaris('signer_rules', { jenis_dokumen: dok.kode, nama_dokumen: dok.nama, urutan: dok.urutan,
      ...(ada ? {} : { kiri: dok.bawaan.kiri, kanan: dok.bawaan.kanan, kop_kode: null }), ...ubah }, { pk: 'jenis_dokumen', baru: !ada })
    ui.toast(`Aturan cetak ${dok.nama} diperbarui.`)
  } catch (e) { galat(e) }
}
const ubahAturan = (dok, kolom, v) => simpanAturan(dok, { [kolom]: v || null })
const kembalikan = (dok) => simpanAturan(dok, { kiri: dok.bawaan.kiri, kanan: dok.bawaan.kanan, kop_kode: null })
</script>
<template>
  <div class="space-y-5">
    <section class="kartu p-5">
      <div class="mb-3 flex flex-wrap items-center justify-between gap-2">
        <div><h3 class="judul-bagian">Pejabat penanda tangan</h3><p class="text-sm text-teks3">Pejabat yang ditautkan ke jabatan struktural mengikuti Data Pegawai secara otomatis; yang lain diubah manual di sini.</p></div>
        <button class="tombol-garis" @click="buka()"><PhPlus :size="18" weight="bold" /> Tambah pejabat</button>
      </div>
      <ul class="divide-y divide-garis">
        <li v-for="s in lembaga.signatories" :key="s.id" class="flex items-center gap-3 py-3">
          <div class="min-w-0 flex-1">
            <p class="text-sm text-teks3">{{ s.jabatan_tertulis }}</p>
            <p :class="['font-semibold', !s.aktif && 'text-teks3 line-through']">{{ s.nama }}</p>
            <p class="text-sm text-teks3">NIY {{ s.niy || '–' }}<template v-if="!s.aktif"> – nonaktif</template></p>
            <p v-if="!s.employee_id" class="mt-0.5 text-xs font-semibold text-[rgb(var(--merah))]">Belum terhubung akun pegawai – hanya untuk tanda tangan basah</p>
            <p v-if="s.sumber_jabatan" class="w-pegawai mt-0.5 flex items-center gap-1 text-xs font-semibold" style="color: var(--c)"><PhLink :size="14" weight="bold" /> Mengikuti jabatan {{ namaJabatan(s.sumber_jabatan) }}{{ s.sumber_unit_id ? ' – ' + (org.cariUnit(s.sumber_unit_id)?.nama || '') : '' }}</p>
          </div>
          <button class="tombol-ikon" @click="buka(s)" :aria-label="`Ubah ${s.nama}`"><PhPencilSimple :size="20" /></button>
          <button class="tombol-ikon" @click="hapus(s)" :aria-label="`Hapus ${s.nama}`"><PhTrash :size="20" /></button>
        </li>
      </ul>
    </section>

    <section class="kartu p-5">
      <h3 class="judul-bagian">Penanda tangan dan kop per dokumen cetak</h3>
      <p class="mb-3 text-sm text-teks3">Kolom kiri untuk pimpinan atau atasan ("Mengetahui"), kolom kanan untuk pegawai terkait. Perubahan langsung berlaku pada cetakan berikutnya.</p>
      <ul class="mb-3 list-disc space-y-0.5 pl-5 text-xs text-teks3">
        <li><b>Kepala sekolah sesuai jenjang</b>: Kepala Wustha atau Kepala SMA menurut kelas/santri pada dokumen; bila dokumen mencakup dua jenjang, Direktur.</li>
        <li><b>Pimpinan sesuai kelompok</b>: kelas → kepala sekolah jenjangnya; halaqah → Kepala Bidang Tahfizh; asrama dan ekskul → Kepala Bidang Kesantrian.</li>
        <li><b>Penanggung jawab kelompok/mapel</b>: wali kelas, guru mapel, muhaffizh, musyrif, atau pembina pada dokumen tersebut.</li>
        <li><b>Kop sesuai unit</b>: kop Wustha atau SMA bila dokumen milik satu jenjang; selain itu kop pondok.</li>
      </ul>
      <div class="relative mb-3"><PhMagnifyingGlass :size="18" class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-teks3" />
        <input v-model="cari" class="isian pl-10" placeholder="Cari dokumen atau menu" aria-label="Cari dokumen cetak" /></div>
      <div class="space-y-2">
        <div v-for="g in tampil" :key="g.k" class="rounded-xl border border-garis">
          <button type="button" class="flex min-h-[48px] w-full items-center gap-2 px-4 text-left font-semibold" :aria-expanded="!!(terbuka[g.k] || cari)" @click="terbuka[g.k] = !terbuka[g.k]">
            <span class="flex-1">{{ g.k }}</span><span class="lencana">{{ g.dok.length }}</span>
            <PhCaretDown :size="18" :class="['transition-transform', (terbuka[g.k] || cari) && 'rotate-180']" /></button>
          <div v-if="terbuka[g.k] || cari" class="divide-y divide-garis border-t border-garis">
            <div v-for="dok in g.dok" :key="dok.kode" class="p-3">
              <div class="mb-2 flex items-start gap-2">
                <div class="min-w-0 flex-1"><p class="font-semibold">{{ dok.nama }}</p><p class="text-xs text-teks3">{{ dok.menu }}</p></div>
                <button v-if="ubahan(dok)" type="button" class="tombol-garis min-h-[36px] shrink-0 px-3 text-xs" @click="kembalikan(dok)"><PhArrowCounterClockwise :size="16" /> Bawaan</button>
              </div>
              <div class="grid gap-2 sm:grid-cols-3">
                <label v-for="k in ['kiri', 'kanan']" :key="k" class="text-xs font-semibold text-teks3">{{ k === 'kiri' ? 'Kolom kiri' : 'Kolom kanan' }}
                  <select class="isian mt-1 text-sm font-normal text-teks" :value="nilai(dok, k)" @change="ubahAturan(dok, k, $event.target.value)">
                    <optgroup label="Sesuai peran"><option v-for="p in peranUntuk(dok)" :key="p" :value="p">{{ PERAN[p].n }}{{ p === dok.bawaan[k] ? ' (bawaan)' : '' }}</option></optgroup>
                    <optgroup v-if="pejabatAktif.length" label="Pejabat tetap"><option v-for="x in pejabatAktif" :key="x.id" :value="x.id">{{ x.jabatan_tertulis }} – {{ x.nama }}</option></optgroup>
                  </select></label>
                <label class="text-xs font-semibold text-teks3">Kop surat
                  <select class="isian mt-1 text-sm font-normal text-teks" :value="nilai(dok, 'kop_kode')" @change="ubahAturan(dok, 'kop_kode', $event.target.value)">
                    <option value="">Sesuai unit dokumen (bawaan)</option>
                    <option v-for="x in lembaga.letterheads" :key="x.kode" :value="x.kode">{{ x.nama }}</option>
                  </select></label>
              </div>
            </div>
          </div>
        </div>
        <p v-if="!tampil.length" class="py-6 text-center text-sm text-teks3">Tidak ada dokumen yang cocok.</p>
      </div>
    </section>

    <section class="kartu p-5">
      <h3 class="judul-bagian flex items-center gap-2"><PhInfo :size="20" weight="duotone" /> Dokumen dengan penanda tangan dari alur lain</h3>
      <p class="mb-3 text-sm text-teks3">Dokumen berikut ditandatangani oleh pejabat yang memproses atau menyetujuinya (tanda tangan elektronik), sehingga diatur di tempatnya masing-masing.</p>
      <ul class="divide-y divide-garis text-sm">
        <li v-for="x in DIATUR_LAIN" :key="x.nama" class="py-2"><p class="font-semibold">{{ x.nama }}</p><p class="text-teks3">{{ x.tempat }}</p></li>
      </ul>
    </section>

    <LembarBawah v-model="lembar" :judul="f._baru ? 'Tambah pejabat' : 'Ubah pejabat'">
      <div class="space-y-4 pb-2">
        <div><label class="label-isian" for="pt-jab">Jabatan (seperti tertulis di dokumen)</label><input id="pt-jab" v-model="f.jabatan_tertulis" class="isian" placeholder="Contoh: Wakil Direktur" /></div>
        <div><label class="label-isian" for="pt-sumber">Ambil nama dari jabatan struktural</label>
          <select id="pt-sumber" v-model="f.sumber_jabatan" class="isian"><option value="">Tidak – isi nama manual</option>
            <option v-for="j in org.struktural" :key="j.id" :value="j.kode">{{ j.nama }}</option></select>
          <p class="mt-1 text-xs text-teks3">Nama dan NIY otomatis mengikuti pegawai yang memegang jabatan ini di Data Pegawai.</p></div>
        <div v-if="f.sumber_jabatan"><label class="label-isian" for="pt-unit">Untuk bidang/unit (opsional)</label>
          <select id="pt-unit" v-model="f.sumber_unit_id" class="isian"><option value="">Bidang/unit mana saja</option>
            <option v-for="u in org.datar" :key="u.id" :value="u.id">{{ '— '.repeat(u.tingkat) }}{{ u.nama }}</option></select></div>
        <template v-if="!f.sumber_jabatan">
          <div><label class="label-isian" for="pt-akun">Akun pegawai (untuk tanda tangan elektronik)</label>
            <select id="pt-akun" class="isian" :value="f.employee_id || ''" @change="pilihAkun($event.target.value)"><option value="">Tidak ditautkan</option>
              <option v-for="p in peg.daftar.filter((x) => x.status_akun === 'aktif')" :key="p.id" :value="p.id">{{ p.niy ? p.niy + ' – ' : '' }}{{ p.nama_lengkap }}</option></select>
            <p class="mt-1 text-xs text-teks3">Pejabat yang tertaut dapat menyetujui laporan resmi dari akunnya sendiri.</p></div>
          <div><label class="label-isian" for="pt-nama">Nama lengkap bergelar</label><input id="pt-nama" v-model="f.nama" class="isian" /></div>
          <div><label class="label-isian" for="pt-niy">NIY/NIP</label><input id="pt-niy" v-model="f.niy" class="isian" inputmode="numeric" /></div>
        </template>
        <p v-else class="rounded-xl bg-permukaan2 p-3 text-sm text-teks2">Saat ini: {{ f.nama || '–' }} (NIY {{ f.niy || '–' }}). Bila belum ada pemegang jabatan, nama terakhir tetap dipakai.</p>
        <label class="flex min-h-[44px] items-center gap-3 font-semibold"><input v-model="f.aktif" type="checkbox" class="h-5 w-5 accent-[#C7332F]" /> Aktif sebagai penanda tangan</label>
        <button class="tombol-utama w-full" @click="simpan"><PhFloppyDisk :size="20" weight="duotone" /> Simpan</button>
      </div>
    </LembarBawah>
  </div>
</template>
