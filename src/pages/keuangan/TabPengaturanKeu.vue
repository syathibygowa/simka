<!-- SIMKA PRO | src/pages/keuangan/TabPengaturanKeu.vue | v1.1 | Fase 13 – Pelengkap: siklus semesteran dan batas berlaku jenjang/kelas | 11/10/2026 -->
<script setup>
// Pengaturan keuangan santri (satu tab, tiga bagian):
//   Jenis biaya : kode, nama, siklus (bulanan/semesteran/tahunan/sekali), nominal standar, tarif khusus per jenjang/tingkat,
//                 batas berlaku (hanya jenjang/kelas tertentu; santri lain otomatis tidak ditagih),
//                 bawaan "hanya santri baru". Jenis yang sudah dipakai tagihan dinonaktifkan, bukan dihapus.
//   Subsidi     : keringanan per santri (persen/nominal, semua jenis atau jenis tertentu, berjangka).
//   Ketentuan   : rekening lembaga (tercetak di surat tagihan), tanggal jatuh tempo bulanan, batas surat tagihan,
//                 pengingat jatuh tempo, catatan kuitansi dan surat tagihan.
import { ref, computed, onMounted, watch } from 'vue'
import { PhPlus, PhPencilSimple, PhTrash, PhFloppyDisk, PhInvoice, PhPercent, PhListChecks, PhMagnifyingGlass, PhBank } from '@phosphor-icons/vue'
import { useKeuangan } from '@/stores/keuangan'
import { useUI } from '@/stores/ui'
import { formatPendek } from '@/lib/tanggal'
import { rupiah, angka, bacaRupiah, SIKLUS, JENJANG } from '@/lib/keuangan'
import LembarBawah from '@/components/LembarBawah.vue'
import LembarSubsidi from './LembarSubsidi.vue'

const keu = useKeuangan(); const ui = useUI()
const bagian = ref('jenis')
const BAGIAN = [{ k: 'jenis', n: 'Jenis biaya', ikon: PhInvoice }, { k: 'subsidi', n: 'Subsidi santri', ikon: PhPercent }, { k: 'ketentuan', n: 'Ketentuan', ikon: PhListChecks }]

// ---------- Jenis biaya ----------
const fj = ref(null); const proses = ref(false)
const baruJenis = () => { fj.value = { id: null, kode: '', nama: '', siklus: 'bulanan', nominal: '', santri_baru: false, keterangan: '', aktif: true, tarif: [], berlaku_jenjang: [], berlaku_tingkat: [] } }
const ubahJenis = (j) => { fj.value = { ...j, berlaku_jenjang: [...(j.berlaku_jenjang || [])], berlaku_tingkat: [...(j.berlaku_tingkat || [])].map(Number), nominal: angka(j.nominal), tarif: j.tarif.map((t) => ({ jenjang: t.jenjang || '', tingkat: t.tingkat || '', nominal: angka(t.nominal) })) } }
async function simpanJenis() {
  const d = fj.value
  if (!/^[A-Z0-9_]{2,20}$/.test(String(d.kode).toUpperCase())) return ui.toast('Kode 2–20 huruf kapital/angka/garis bawah, contoh SPP atau DAFTAR_ULANG.', 'galat')
  if ((d.nama || '').trim().length < 3) return ui.toast('Isi nama jenis biaya.', 'galat')
  proses.value = true
  try { await keu.simpanJenis({ ...d, kode: String(d.kode).toUpperCase(), nominal: bacaRupiah(d.nominal) || 0, tarif: d.tarif.filter((t) => t.jenjang || t.tingkat).map((t) => ({ jenjang: t.jenjang || null, tingkat: t.tingkat || null, nominal: bacaRupiah(t.nominal) || 0 })) })
    ui.toast('Jenis biaya disimpan.'); fj.value = null } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
async function hapusJenis(j) {
  if (!(await ui.konfirmasi({ judul: `Hapus ${j.nama}?`, pesan: j.jumlah_tagihan ? 'Jenis ini sudah dipakai tagihan, sehingga hanya dinonaktifkan.' : 'Jenis biaya akan dihapus.', ya: j.jumlah_tagihan ? 'Nonaktifkan' : 'Hapus', bahaya: true }))) return
  try { const r = await keu.hapusJenis(j.id); ui.toast(r === 'dihapus' ? 'Jenis biaya dihapus.' : 'Jenis biaya dinonaktifkan.') } catch (e) { ui.toast(e.message, 'galat') }
}

// ---------- Subsidi ----------
const subsidi = ref([]); const cari = ref(''); const fs = ref(null)
async function muatSubsidi() { try { subsidi.value = await keu.daftarSubsidi() } catch (e) { ui.toast(e.message, 'galat') } }
watch(bagian, (b) => { if (b === 'subsidi') muatSubsidi() })
const subsidiTampil = computed(() => { const c = cari.value.toLowerCase().trim(); return c ? subsidi.value.filter((x) => x.nama.toLowerCase().includes(c) || x.nis.startsWith(c)) : subsidi.value })
async function hapusSubsidi(x) {
  if (!(await ui.konfirmasi({ judul: `Hapus subsidi ${x.nama}?`, pesan: 'Tagihan yang sudah dibuat tidak berubah.', ya: 'Hapus', bahaya: true }))) return
  try { await keu.hapusSubsidi(x.id); await muatSubsidi() } catch (e) { ui.toast(e.message, 'galat') }
}

// ---------- Ketentuan ----------
const fk = ref(null)
const isiKetentuan = () => { fk.value = JSON.parse(JSON.stringify({ ...keu.pengaturan, rekening: keu.pengaturan.rekening || [] })) }
onMounted(isiKetentuan)
async function simpanKetentuan() {
  proses.value = true
  try { await keu.simpanPengaturan({ ...fk.value, rekening: fk.value.rekening.filter((r) => r.bank || r.nomor || r.atas_nama) }); isiKetentuan(); ui.toast('Ketentuan keuangan disimpan.') }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
const toggle = (arr, v) => { const i = arr.indexOf(v); i >= 0 ? arr.splice(i, 1) : arr.push(v) }
const berlakuTeks = (j) => [...(j.berlaku_jenjang || []).map((k) => JENJANG[k]), ...(j.berlaku_tingkat || []).map((t) => 'kelas ' + t)].join(', ')
const tarifLabel = (t) => (t.tingkat ? `Kelas ${t.tingkat}` : JENJANG[t.jenjang])
</script>
<template>
  <div>
    <div class="mb-4 flex flex-wrap gap-1.5" role="tablist" aria-label="Bagian pengaturan">
      <button v-for="b in BAGIAN" :key="b.k" role="tab" :aria-selected="bagian === b.k" @click="bagian = b.k"
        :class="['flex min-h-[44px] items-center gap-2 rounded-xl border px-3 text-sm font-semibold', bagian === b.k ? 'border-transparent bg-[#5E2A30] text-white dark:bg-[#E8A4AC] dark:text-[#2A1013]' : 'border-garis text-teks2']">
        <component :is="b.ikon" :size="18" weight="duotone" /> {{ b.n }}</button>
    </div>

    <!-- Jenis biaya -->
    <section v-if="bagian === 'jenis'">
      <div class="mb-3 flex flex-wrap items-center gap-2"><p class="flex-1 text-sm text-teks3">Nominal standar dipakai bila tidak ada tarif khusus untuk jenjang/kelas santri. Subsidi santri mengurangi tagihan saat tagihan dibuat.</p>
        <button v-if="keu.hak.kelola" class="tombol-utama" @click="baruJenis"><PhPlus :size="20" weight="bold" /> Jenis biaya</button></div>
      <p v-if="!keu.jenis.length" class="kartu p-6 text-center text-sm text-teks3">Belum ada jenis biaya. Contoh: SPP (bulanan), Daftar ulang (tahunan), Uang pangkal (sekali, santri baru).</p>
      <div class="grid gap-3 lg:grid-cols-2">
        <article v-for="j in keu.jenis" :key="j.id" :class="['kartu p-4', 'w-' + SIKLUS[j.siklus].w, !j.aktif && 'opacity-60']">
          <div class="flex items-start gap-2">
            <div class="min-w-0 flex-1"><p class="font-bold">{{ j.nama }} <span class="text-xs font-normal text-teks3">{{ j.kode }}</span></p>
              <p class="mt-0.5 flex flex-wrap gap-1"><span class="lencana">{{ SIKLUS[j.siklus].n }}</span><span v-if="j.santri_baru" class="lencana w-pengajuan">Santri baru</span>
                <span v-if="!j.aktif" class="lencana w-hakakses">Nonaktif</span></p></div>
            <p class="text-lg font-extrabold tabular-nums">{{ rupiah(j.nominal) }}</p>
          </div>
          <p v-if="berlakuTeks(j)" class="mt-2 text-sm font-semibold" style="color: var(--c)">Hanya untuk: {{ berlakuTeks(j) }}</p>
          <p v-if="j.tarif.length" class="mt-2 text-sm text-teks2">Tarif khusus: {{ j.tarif.map((t) => `${tarifLabel(t)} ${rupiah(t.nominal)}`).join(' · ') }}</p>
          <p v-if="j.keterangan" class="mt-1 text-sm text-teks3">{{ j.keterangan }}</p>
          <div class="mt-2 flex items-center gap-2"><span class="flex-1 text-xs text-teks3">{{ j.jumlah_tagihan }} tagihan</span>
            <template v-if="keu.hak.kelola"><button class="tombol-ikon h-9 w-9" :aria-label="'Ubah ' + j.nama" @click="ubahJenis(j)"><PhPencilSimple :size="18" /></button>
              <button v-if="j.aktif" class="tombol-ikon h-9 w-9 text-merah" :aria-label="'Hapus ' + j.nama" @click="hapusJenis(j)"><PhTrash :size="18" /></button></template></div>
        </article>
      </div>
    </section>

    <!-- Subsidi -->
    <section v-else-if="bagian === 'subsidi'">
      <div class="mb-3 flex flex-wrap items-end gap-2">
        <div class="relative min-w-[200px] flex-1"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-teks3" />
          <input v-model="cari" type="search" class="isian pl-10" placeholder="Cari nama atau NIS" aria-label="Cari santri" /></div>
        <button v-if="keu.hak.kelola" class="tombol-utama" @click="fs = { mulai: '' }"><PhPlus :size="20" weight="bold" /> Subsidi</button>
      </div>
      <p v-if="!subsidiTampil.length" class="kartu p-6 text-center text-sm text-teks3">Belum ada subsidi santri.</p>
      <ul class="space-y-2">
        <li v-for="x in subsidiTampil" :key="x.id" class="kartu flex flex-wrap items-center gap-2 p-3.5">
          <div class="min-w-[180px] flex-1"><p class="font-bold">{{ x.nama }} <span class="text-xs font-normal text-teks3">{{ x.nis }} · {{ x.kelas || '–' }}</span></p>
            <p class="text-sm text-teks2">{{ x.jenis === 'persen' ? Number(x.nilai) + '%' : rupiah(x.nilai) }} · {{ x.jenis_biaya || 'Semua jenis biaya' }} · {{ x.alasan }}</p>
            <p class="text-xs text-teks3">{{ formatPendek(x.mulai) }} s.d. {{ x.sampai ? formatPendek(x.sampai) : 'seterusnya' }}</p></div>
          <span :class="['lencana', x.berlaku ? 'w-presensi' : 'w-hakakses']">{{ x.berlaku ? 'Berlaku' : 'Tidak berlaku' }}</span>
          <template v-if="keu.hak.kelola"><button class="tombol-ikon h-9 w-9" :aria-label="'Ubah subsidi ' + x.nama" @click="fs = { ...x }"><PhPencilSimple :size="18" /></button>
            <button class="tombol-ikon h-9 w-9 text-merah" :aria-label="'Hapus subsidi ' + x.nama" @click="hapusSubsidi(x)"><PhTrash :size="18" /></button></template>
        </li>
      </ul>
      <LembarSubsidi :isi="fs" @tutup="fs = null" @tersimpan="muatSubsidi" />
    </section>

    <!-- Ketentuan -->
    <section v-else-if="fk" class="grid gap-4 xl:grid-cols-2">
      <div class="kartu w-shift p-4 sm:p-5">
        <h3 class="judul-bagian mb-1 flex items-center gap-2"><PhBank :size="20" weight="duotone" style="color: var(--c)" /> Rekening lembaga</h3>
        <p class="mb-3 text-sm text-teks3">Tercetak pada surat tagihan dan pesan WA sebagai tujuan transfer. Rekening pribadi tidak dicatat.</p>
        <div v-for="(r, i) in fk.rekening" :key="i" class="mb-2 grid gap-2 rounded-xl border border-garis p-3 sm:grid-cols-[1fr_1.3fr]">
          <input v-model="r.bank" class="isian" placeholder="Bank (mis. BSI)" :aria-label="'Bank rekening ' + (i + 1)" :disabled="!keu.hak.kelola" />
          <input v-model="r.nomor" class="isian tabular-nums" placeholder="Nomor rekening" inputmode="numeric" :aria-label="'Nomor rekening ' + (i + 1)" :disabled="!keu.hak.kelola" />
          <input v-model="r.atas_nama" class="isian sm:col-span-2" placeholder="Atas nama" :aria-label="'Atas nama rekening ' + (i + 1)" :disabled="!keu.hak.kelola" />
          <div class="flex gap-2 sm:col-span-2"><input v-model="r.keterangan" class="isian flex-1" placeholder="Keterangan (tidak wajib)" :aria-label="'Keterangan rekening ' + (i + 1)" :disabled="!keu.hak.kelola" />
            <button v-if="keu.hak.kelola" class="tombol-ikon h-11 w-11 text-merah" aria-label="Hapus rekening" @click="fk.rekening.splice(i, 1)"><PhTrash :size="20" /></button></div>
        </div>
        <button v-if="keu.hak.kelola" class="tombol-garis" @click="fk.rekening.push({ bank: '', nomor: '', atas_nama: '', keterangan: '' })"><PhPlus :size="18" /> Tambah rekening</button>
      </div>
      <div class="kartu w-pengaturan p-4 sm:p-5">
        <h3 class="judul-bagian mb-3">Jatuh tempo dan dokumen</h3>
        <div class="grid gap-3 sm:grid-cols-3">
          <div><label class="label-isian" for="kk-jt">Jatuh tempo bulanan (tanggal)</label><input id="kk-jt" v-model.number="fk.jatuh_tempo_hari" type="number" min="1" max="28" class="isian" :disabled="!keu.hak.kelola" /></div>
          <div><label class="label-isian" for="kk-bs">Batas surat tagihan (hari)</label><input id="kk-bs" v-model.number="fk.batas_surat_hari" type="number" min="1" max="60" class="isian" :disabled="!keu.hak.kelola" /></div>
          <div><label class="label-isian" for="kk-pg">Pengingat sebelum jatuh tempo (hari)</label><input id="kk-pg" v-model.number="fk.pengingat_hari" type="number" min="0" max="14" class="isian" :disabled="!keu.hak.kelola" /></div>
        </div>
        <div class="mt-3"><label class="label-isian" for="kk-ck">Catatan pada kuitansi</label><textarea id="kk-ck" v-model="fk.catatan_kuitansi" rows="2" class="isian" :disabled="!keu.hak.kelola" /></div>
        <div class="mt-3"><label class="label-isian" for="kk-ct">Catatan pada surat tagihan</label><textarea id="kk-ct" v-model="fk.catatan_tagihan" rows="3" class="isian" :disabled="!keu.hak.kelola" /></div>
        <p class="mt-2 text-xs text-teks3">Setiap pagi pukul 07.05 WITA pengelola keuangan menerima notifikasi tagihan yang akan jatuh tempo; setiap Senin, ringkasan tunggakan. Isi pesan WA ke wali diatur di Setelan → Template WA.</p>
      </div>
      <button v-if="keu.hak.kelola" class="tombol-utama xl:col-span-2" :disabled="proses" @click="simpanKetentuan"><PhFloppyDisk :size="20" weight="duotone" /> Simpan ketentuan</button>
    </section>

    <!-- Formulir jenis biaya -->
    <LembarBawah :model-value="!!fj" @update:model-value="(v) => !v && (fj = null)" :judul="fj?.id ? 'Ubah jenis biaya' : 'Jenis biaya baru'">
      <div v-if="fj" class="space-y-4 pb-2">
        <div class="grid grid-cols-[1fr_2fr] gap-3">
          <div><label class="label-isian" for="jb-kd">Kode</label><input id="jb-kd" v-model="fj.kode" class="isian uppercase" placeholder="SPP" /></div>
          <div><label class="label-isian" for="jb-nm">Nama</label><input id="jb-nm" v-model="fj.nama" class="isian" placeholder="SPP" /></div>
        </div>
        <div><span class="label-isian">Siklus</span>
          <div class="grid grid-cols-2 gap-1.5 sm:grid-cols-4" role="radiogroup" aria-label="Siklus tagihan">
            <button v-for="(s, k) in SIKLUS" :key="k" type="button" role="radio" :aria-checked="fj.siklus === k" @click="fj.siklus = k"
              :class="['min-h-[44px] rounded-xl border text-sm font-semibold', fj.siklus === k ? 'border-transparent bg-[#1572B6] text-white' : 'border-garis text-teks2']">{{ s.n }}</button></div>
          <p class="mt-1 text-xs text-teks3">{{ SIKLUS[fj.siklus].ket }}</p></div>
        <div><label class="label-isian" for="jb-nom">Nominal standar (Rp)</label><input id="jb-nom" v-model="fj.nominal" inputmode="numeric" class="isian text-lg font-bold tabular-nums" placeholder="750.000" /></div>
        <div>
          <p class="label-isian">Tarif khusus per jenjang/kelas (tidak wajib)</p>
          <div v-for="(t, i) in fj.tarif" :key="i" class="mb-2 grid grid-cols-[1fr_1fr_1.2fr_auto] gap-2">
            <select v-model="t.jenjang" class="isian" :aria-label="'Jenjang tarif ' + (i + 1)"><option value="">Jenjang…</option><option v-for="(n, k) in JENJANG" :key="k" :value="k">{{ n }}</option></select>
            <select v-model="t.tingkat" class="isian" :aria-label="'Kelas tarif ' + (i + 1)"><option value="">Semua kelas</option><option v-for="k in [7, 8, 9, 10, 11, 12]" :key="k" :value="k">Kelas {{ k }}</option></select>
            <input v-model="t.nominal" inputmode="numeric" class="isian tabular-nums" placeholder="Nominal" :aria-label="'Nominal tarif ' + (i + 1)" />
            <button class="tombol-ikon h-11 w-11 text-merah" aria-label="Hapus tarif" @click="fj.tarif.splice(i, 1)"><PhTrash :size="20" /></button>
          </div>
          <button type="button" class="tombol-garis min-h-[40px] px-3 text-sm" @click="fj.tarif.push({ jenjang: '', tingkat: '', nominal: '' })"><PhPlus :size="18" /> Tambah tarif khusus</button>
        </div>
        <div>
          <p class="label-isian">Berlaku untuk (kosong = semua santri)</p>
          <div class="flex flex-wrap gap-1.5">
            <button v-for="(n, k) in JENJANG" :key="k" type="button" :aria-pressed="fj.berlaku_jenjang.includes(k)" @click="toggle(fj.berlaku_jenjang, k)"
              :class="['min-h-[40px] rounded-xl border px-3 text-sm font-semibold', fj.berlaku_jenjang.includes(k) ? 'border-transparent bg-[#0B7F81] text-white' : 'border-garis text-teks2']">{{ n }}</button>
            <button v-for="t in [7, 8, 9, 10, 11, 12]" :key="t" type="button" :aria-pressed="fj.berlaku_tingkat.includes(t)" @click="toggle(fj.berlaku_tingkat, t)"
              :class="['min-h-[40px] min-w-[52px] rounded-xl border px-2 text-sm font-semibold', fj.berlaku_tingkat.includes(t) ? 'border-transparent bg-[#0B7F81] text-white' : 'border-garis text-teks2']">Kelas {{ t }}</button>
          </div>
          <p class="mt-1 text-xs text-teks3">Santri di luar jenjang/kelas ini otomatis tidak ditagih saat tagihan massal dibuat.</p>
        </div>
        <label class="flex items-center gap-3"><input v-model="fj.santri_baru" type="checkbox" class="h-5 w-5" /> Bawaan sasaran: hanya santri baru</label>
        <div><label class="label-isian" for="jb-ket">Keterangan (tidak wajib)</label><input id="jb-ket" v-model="fj.keterangan" class="isian" /></div>
        <label v-if="fj.id" class="flex items-center gap-3"><input v-model="fj.aktif" type="checkbox" class="h-5 w-5" /> Aktif (dapat dipakai untuk tagihan baru)</label>
        <button class="tombol-utama w-full" :disabled="proses" @click="simpanJenis"><PhFloppyDisk :size="20" weight="duotone" /> Simpan jenis biaya</button>
      </div>
    </LembarBawah>
  </div>
</template>
