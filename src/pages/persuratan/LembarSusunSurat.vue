<!-- SIMKA PRO | src/pages/persuratan/LembarSusunSurat.vue | v1.4 | Perbaikan 13.8.0: naskah surat keluar dengan bilah gaya teks dan daftar otomatis | 16/10/2026 -->
<script setup>
import { namaBerkas, periodeBulan, subjekSurat } from '@/lib/namaBerkas'
// Susun surat keluar dari template: pilih template → isi data surat (tanggal, kop, D/K, perihal, tujuan, lampiran), isian
// template (teks, tanggal, pegawai, santri, daftar), penanda tangan (dari Setelan → Penanda tangan atau pegawai lain; a.n.),
// tembusan dan narahubung. Naskah surat ini boleh disunting tanpa mengubah templatenya. Pratinjau F4 berkop kapan saja.
// Disimpan sebagai draf; pengajuan tanda tangan dilakukan Tata Usaha dari rincian surat. TU dapat mencatat pemohon surat
// (pegawai/pimpinan yang meminta) agar pemohon ikut menerima kabar saat surat terbit.
// v1.2: prop awal = { templat: kode, santri: {id, nis}, prestasi: [teks] } membuka template itu dengan santri terpilih;
//       isian "prestasi" (daftar) terisi dari prestasi santri yang tercatat bila masih kosong.
import { ref, computed, watch } from 'vue'
import { PhMagnifyingGlass, PhArrowLeft, PhEye, PhFloppyDisk, PhPencilSimpleLine, PhPlus, PhTrash, PhWarningCircle, PhInfo } from '@phosphor-icons/vue'
import { usePersuratan } from '@/stores/persuratan'
import { useLembaga } from '@/stores/lembaga'
import { useUI } from '@/stores/ui'
import { KATEGORI_TEMPLATE, nilaiAwal, isianKosong, potretTemplate } from '@/lib/suratKeluar'
import { hariIniISO, formatHijriah } from '@/lib/tanggal'
import LembarBawah from '@/components/LembarBawah.vue'
import InputTanggal from '@/components/InputTanggal.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import SuratResmi from '@/components/cetak/SuratResmi.vue'
import IsianSurat from './IsianSurat.vue'
import IsianTeksKaya from '@/components/IsianTeksKaya.vue'

const buka = defineModel({ type: Boolean, default: false })
const props = defineProps({ surat: { type: Object, default: null }, awal: { type: Object, default: null } })
const emit = defineEmits(['selesai'])
const ps = usePersuratan(); const lembaga = useLembaga(); const ui = useUI()
const langkah = ref('pilih'); const cariT = ref(''); const t = ref(null); const f = ref({}); const nilai = ref({}); const slot = ref([])
const pemohon = ref(null)
const tembusan = ref(''); const suntingNaskah = ref(false); const naskah = ref(''); const proses = ref(false); const pratinjau = ref(false)

watch(buka, async (v) => {
  if (!v) return
  pratinjau.value = false; suntingNaskah.value = false
  try { await Promise.all([ps.muatTemplat(), ps.muatKonteks(), ps.muatPenandaTangan(), lembaga.muat()]) } catch (e) { ui.toast(e.message, 'galat') }
  const s = props.surat
  if (s) {
    const tp = ps.templat.find((x) => x.id === s.template_id) || { id: s.template_id, nama: s.jenis_nama, ...s.tampilan, kategori: s.kategori }
    t.value = { ...tp, ...s.tampilan, id: s.template_id, nama: s.jenis_nama }
    f.value = { tanggal_surat: s.tanggal_surat, kop_kode: s.kop_kode, dk: s.dk, perihal: s.perihal, kepada: s.kepada || '', lampiran: s.lampiran || '', narahubung: s.narahubung || '' }
    pemohon.value = s.pemohon_id ? { id: s.pemohon_id, nama: s.pemohon } : null
    nilai.value = JSON.parse(JSON.stringify(s.nilai || {})); tembusan.value = (s.tembusan || []).join('\n'); naskah.value = s.tampilan?.isi || ''
    slot.value = (s.penanda || []).map((p, i) => ({ sumber: p.signatory_id ? 'ttd' : 'pegawai', signatory_id: p.signatory_id || '', pegawai: p.signatory_id ? null : { id: p.employee_id, nama: p.nama, niy: p.niy },
      jabatan: p.jabatan, pengantar: p.pengantar || (t.value.penanda?.[i]?.pengantar || ''), an: p.an || '' }))
    langkah.value = 'isi'
  } else {
    t.value = null; langkah.value = 'pilih'; cariT.value = ''
    const a = props.awal; const x = a?.templat ? ps.templat.find((y) => y.kode === a.templat && y.aktif) : null
    if (a?.templat && !x) ui.toast('Template surat tersebut belum tersedia atau nonaktif.', 'galat')
    if (x) {
      pilihTemplat(x)
      const kS = (x.isian || []).find((i) => i.jenis === 'santri')?.kunci
      if (kS && a.santri?.nis) {
        try {
          const p = (await ps.cariSantri(a.santri.nis)).find((y) => y.id === a.santri.id)
          if (p) nilai.value[kS] = { id: p.id, nama: p.nama, nis: p.nis, nisn: p.nisn, jk: p.jk, tempat_lahir: p.tempat_lahir, tanggal_lahir: p.tanggal_lahir, jenjang: p.jenjang,
            tingkat: p.tingkat, kelas: p.kelas, wali: p.wali, alamat: p.alamat, ayah: p.ayah || '', ibu: p.ibu || '', hafalan: p.hafalan ?? null, tanggal_masuk: p.tanggal_masuk || null, prestasi: p.prestasi || [] }
        } catch (e) { ui.toast(e.message, 'galat') }
      }
      if (a.prestasi?.length && (x.isian || []).some((i) => i.kunci === 'prestasi')) nilai.value.prestasi = [...a.prestasi]
    }
  }
})
// Isian "prestasi" terisi dari prestasi santri terpilih bila masih kosong
const kunciSantri = computed(() => (t.value?.isian || []).find((i) => i.jenis === 'santri')?.kunci)
watch(() => (kunciSantri.value ? nilai.value[kunciSantri.value]?.id : null), () => {
  if (!(t.value?.isian || []).some((i) => i.kunci === 'prestasi' && i.jenis === 'daftar')) return
  const sumber = nilai.value[kunciSantri.value]?.prestasi || []
  if (sumber.length && !(nilai.value.prestasi || []).some((x) => String(x).trim())) nilai.value.prestasi = [...sumber]
})
const daftarT = computed(() => {
  const q = cariT.value.toLowerCase().trim()
  return Object.entries(KATEGORI_TEMPLATE).map(([k, v]) => ({ k, ...v, isi: ps.templat.filter((x) => x.aktif && x.kategori === k && (!q || `${x.nama} ${x.perihal_kode}`.toLowerCase().includes(q))) }))
    .filter((g) => g.isi.length)
})
function pilihTemplat(x) {
  t.value = { ...x }
  f.value = { tanggal_surat: hariIniISO(), kop_kode: x.kop_kode, dk: x.dk, perihal: x.hal_bawaan || x.nama, kepada: x.kepada_bawaan || '', lampiran: '–', narahubung: '' }
  nilai.value = nilaiAwal(x.isian || [], hariIniISO()); tembusan.value = ''; if (!props.surat) pemohon.value = null; naskah.value = x.isi
  slot.value = (x.penanda?.length ? x.penanda : [{ jabatan: 'Direktur' }]).map((p) => {
    const cocok = ps.penandaTangan.find((g) => g.jabatan.toLowerCase() === String(p.jabatan || '').toLowerCase())
      || ps.penandaTangan.find((g) => g.jabatan.toLowerCase().includes(String(p.jabatan || '').toLowerCase()) && p.jabatan)
    return { sumber: cocok ? 'ttd' : 'pegawai', signatory_id: cocok?.id || '', pegawai: null, jabatan: p.jabatan || cocok?.jabatan || '', pengantar: p.pengantar || '', an: '' }
  })
  langkah.value = 'isi'
}
function gantiTtd(s) {
  if (s.signatory_id === '__pegawai') { s.sumber = 'pegawai'; s.signatory_id = ''; return }
  s.sumber = 'ttd'; const g = ps.penandaTangan.find((x) => x.id === s.signatory_id); if (g) s.jabatan = g.jabatan
}
const ttdTampil = computed(() => slot.value.map((s) => {
  const g = s.sumber === 'ttd' ? ps.penandaTangan.find((x) => x.id === s.signatory_id) : null
  return { posisi: slot.value.length === 1 ? 'kanan' : '', nama: g?.nama || s.pegawai?.nama || '', niy: g?.niy || s.pegawai?.niy || '', jabatan: s.jabatan, pengantar: s.pengantar, an: s.an }
}))
const tampilan = computed(() => (t.value ? { ...potretTemplate(t.value), isi: naskah.value } : {}))
// Tanggal Hijriah pratinjau dari server (sama dengan yang dibekukan saat surat diajukan)
const hijriah = ref('')
watch(() => f.value.tanggal_surat, async (tg) => { if (!tg) return; hijriah.value = (await lembaga.hijriahServer(tg).catch(() => null)) || formatHijriah(tg, lembaga.hijriah?.koreksi_hari || 0) })
const suratPratinjau = computed(() => ({ ...f.value, tampilan: tampilan.value, nilai: nilai.value, penanda: ttdTampil.value, tembusan: tembusan.value.split('\n'),
  tanggal_hijriah: hijriah.value }))
const kosong = computed(() => (t.value ? isianKosong(t.value.isian, nilai.value) : []))

async function simpan() {
  if (!f.value.perihal?.trim()) return ui.toast('Isi perihal surat.', 'galat')
  if (t.value.bentuk === 'kiri' && !f.value.kepada.trim()) return ui.toast('Isi tujuan surat (Kepada Yth.).', 'galat')
  for (const [i, s] of slot.value.entries()) {
    if (s.sumber === 'ttd' && !s.signatory_id) return ui.toast(`Pilih penanda tangan ke-${i + 1}.`, 'galat')
    if (s.sumber === 'pegawai' && !s.pegawai?.id) return ui.toast(`Pilih pegawai penanda tangan ke-${i + 1}.`, 'galat')
    if ((s.jabatan || '').trim().length < 3) return ui.toast(`Isi jabatan penanda tangan ke-${i + 1}.`, 'galat')
  }
  proses.value = true
  try {
    const id = await ps.simpanKeluar({ id: props.surat?.id || null, template_id: t.value.id, ...f.value, tembusan: tembusan.value.split('\n').map((x) => x.trim()).filter(Boolean),
      nilai: nilai.value, tampilan: tampilan.value, pemohon_id: pemohon.value?.id || null,
      penanda: slot.value.map((s) => ({ signatory_id: s.sumber === 'ttd' ? s.signatory_id : null, employee_id: s.sumber === 'pegawai' ? s.pegawai?.id : null,
        nama: s.pegawai?.nama, niy: s.pegawai?.niy, jabatan: s.jabatan.trim(), pengantar: s.pengantar, an: s.an })) })
    ui.toast(kosong.value.length ? `Draf tersimpan. Masih kosong: ${kosong.value.join(', ')}.` : 'Draf surat tersimpan.')
    buka.value = false; emit('selesai', id)
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
</script>
<template>
  <LembarBawah v-model="buka" :judul="langkah === 'pilih' ? 'Pilih template surat' : surat ? 'Ubah surat keluar' : t?.nama || 'Susun surat'" lebar>
    <div v-if="langkah === 'pilih'" class="space-y-4 pb-2">
      <div class="relative"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
        <input v-model="cariT" type="search" class="isian pl-11" placeholder="Cari template, mis. undangan, keterangan" aria-label="Cari template" /></div>
      <section v-for="g in daftarT" :key="g.k">
        <h3 class="judul-bagian mb-2">{{ g.n }}</h3>
        <div class="grid gap-2 sm:grid-cols-2">
          <button v-for="x in g.isi" :key="x.id" type="button" :class="['kartu flex items-center gap-3 p-3 text-left hover:shadow-apung', 'w-' + g.w]" @click="pilihTemplat(x)">
            <span class="chip-ikon h-10 w-10 text-xs font-extrabold">{{ x.perihal_kode }}</span>
            <span class="min-w-0 flex-1"><b class="block leading-snug">{{ x.nama }}</b>
              <span class="text-xs text-teks3">{{ x.bentuk === 'tengah' ? 'Judul di tengah' : 'Nomor/Hal di kiri' }} · {{ x.format_nomor === 'sk' ? 'Nomor SK' : x.dk === 'K' ? 'Khariji (keluar)' : 'Dakhily (internal)' }}</span></span>
          </button>
        </div>
      </section>
      <p v-if="!daftarT.length" class="kartu p-6 text-center text-sm text-teks3">Belum ada template aktif.</p>
    </div>

    <div v-else-if="t" class="space-y-4 pb-2">
      <div class="flex flex-wrap items-center justify-between gap-2">
        <button v-if="!surat" type="button" class="tombol-teks -ml-3 px-3" @click="langkah = 'pilih'"><PhArrowLeft :size="18" /> Ganti template</button>
        <button type="button" class="tombol-garis w-rekap min-h-[40px] px-3 text-sm" @click="pratinjau = true"><PhEye :size="18" style="color: var(--c)" /> Pratinjau F4</button>
      </div>

      <section class="grid gap-3 sm:grid-cols-3">
        <InputTanggal v-model="f.tanggal_surat" label="Tanggal surat" wajib />
        <div><label class="label-isian" for="sk-kop">Kop surat</label>
          <select id="sk-kop" v-model="f.kop_kode" class="isian"><option v-for="k in lembaga.letterheads.filter((x) => x.aktif !== false)" :key="k.kode" :value="k.kode">{{ k.nama }}</option></select></div>
        <div><label class="label-isian" for="sk-dk">Jenis surat</label>
          <select id="sk-dk" v-model="f.dk" class="isian" :disabled="t.format_nomor === 'sk'"><option value="D">D – Dakhily (internal)</option><option value="K">K – Khariji (keluar organisasi)</option></select></div>
      </section>
      <section class="grid gap-3 sm:grid-cols-[2fr_1fr]">
        <div><label class="label-isian" for="sk-hal">Perihal <span class="text-merah">*</span></label><input id="sk-hal" v-model="f.perihal" class="isian" /></div>
        <div><label class="label-isian" for="sk-lamp">Lampiran</label><input id="sk-lamp" v-model="f.lampiran" class="isian" placeholder="–" /></div>
      </section>
      <div v-if="t.bentuk === 'kiri'"><label class="label-isian" for="sk-kpd">Kepada Yth. <span class="text-merah">*</span> <span class="font-normal text-teks3">(satu baris per baris surat)</span></label>
        <textarea id="sk-kpd" v-model="f.kepada" rows="2" class="isian py-2.5" placeholder="Bapak Kepala Kantor Kementerian Agama&#10;Kabupaten Gowa" /></div>
      <div v-else><label class="label-isian" for="sk-kpd2">Ditujukan kepada <span class="font-normal text-teks3">(untuk buku agenda)</span></label>
        <input id="sk-kpd2" v-model="f.kepada" class="isian" /></div>

      <IsianSurat v-if="ps.hak.kelola" v-model="pemohon" :isian="{ kunci: 'pemohon', label: 'Atas permintaan (pemohon surat, opsional)', jenis: 'pegawai' }" />
      <p v-else class="flex items-start gap-2 rounded-xl bg-permukaan2 px-3 py-2 text-xs text-teks2"><PhInfo :size="16" class="mt-0.5 shrink-0" />
        Draf Anda dikirim ke Tata Usaha untuk diperiksa, diajukan tanda tangan, dan diberi nomor.</p>
      <section v-if="t.isian?.length" class="space-y-3 rounded-2xl border border-garis p-3 sm:p-4">
        <h3 class="judul-bagian">Isian surat</h3>
        <IsianSurat v-for="i in t.isian" :key="i.kunci" v-model="nilai[i.kunci]" :isian="i" />
      </section>

      <section class="space-y-3 rounded-2xl border border-garis p-3 sm:p-4">
        <div class="flex items-center justify-between"><h3 class="judul-bagian">Penanda tangan</h3>
          <button v-if="slot.length < 2" type="button" class="tombol-teks px-2 text-sm" @click="slot.push({ sumber: 'ttd', signatory_id: '', pegawai: null, jabatan: '', pengantar: 'Mengetahui,', an: '' })"><PhPlus :size="16" /> Tambah</button></div>
        <div v-for="(s, i) in slot" :key="i" class="grid gap-2 rounded-xl bg-permukaan2 p-3 sm:grid-cols-2">
          <div class="sm:col-span-2 flex items-center justify-between"><b class="text-sm">{{ slot.length > 1 ? (i === 0 ? 'Kiri' : 'Kanan') : 'Penanda tangan' }}</b>
            <button v-if="slot.length > 1" type="button" class="tombol-ikon h-8 w-8" aria-label="Hapus penanda tangan" @click="slot.splice(i, 1)"><PhTrash :size="16" /></button></div>
          <div><label class="label-isian" :for="'ttd-' + i">Pejabat</label>
            <select :id="'ttd-' + i" v-model="s.signatory_id" class="isian" @change="gantiTtd(s)">
              <option value="" disabled>{{ s.sumber === 'pegawai' ? 'Pegawai lain (pilih di bawah)' : 'Pilih penanda tangan' }}</option>
              <option v-for="g in ps.penandaTangan" :key="g.id" :value="g.id">{{ g.jabatan }} – {{ g.nama }}{{ g.employee_id ? '' : ' (TTD basah)' }}</option>
              <option value="__pegawai">Pegawai lain…</option></select></div>
          <div><label class="label-isian" :for="'jab-' + i">Jabatan tertulis</label><input :id="'jab-' + i" v-model="s.jabatan" class="isian" /></div>
          <IsianSurat v-if="s.sumber === 'pegawai'" v-model="s.pegawai" class="sm:col-span-2" :isian="{ kunci: 'ttd' + i, label: 'Pegawai penanda tangan', jenis: 'pegawai', wajib: true }" />
          <div><label class="label-isian" :for="'ant-' + i">Kata pengantar</label><input :id="'ant-' + i" v-model="s.pengantar" class="isian" placeholder="Mis. Mengetahui," /></div>
          <div><label class="label-isian" :for="'an-' + i">Atas nama (a.n.)</label><input :id="'an-' + i" v-model="s.an" class="isian" placeholder="Mis. Direktur" /></div>
        </div>
        <p class="flex items-start gap-2 text-xs text-teks3"><PhInfo :size="15" class="mt-0.5 shrink-0" /> Tanda tangan elektronik memerlukan pejabat yang terhubung ke akun pegawai (Setelan → Penanda tangan).</p>
      </section>

      <section v-if="t.opsi?.tembusan || t.opsi?.narahubung" class="grid gap-3 sm:grid-cols-2">
        <div v-if="t.opsi?.tembusan"><label class="label-isian" for="sk-tem">Tembusan <span class="font-normal text-teks3">(satu per baris)</span></label>
          <textarea id="sk-tem" v-model="tembusan" rows="3" class="isian py-2.5" placeholder="Ketua Yayasan&#10;Arsip" /></div>
        <div v-if="t.opsi?.narahubung"><label class="label-isian" for="sk-nara">Narahubung</label><input id="sk-nara" v-model="f.narahubung" class="isian" placeholder="Nama (nomor HP)" /></div>
      </section>

      <section class="rounded-2xl border border-dashed border-garis p-3">
        <button type="button" class="flex w-full items-center gap-2 text-left text-sm font-semibold" @click="suntingNaskah = !suntingNaskah">
          <PhPencilSimpleLine :size="18" /> {{ suntingNaskah ? 'Tutup penyuntingan naskah' : 'Sunting naskah surat ini' }}<span class="font-normal text-teks3">(tidak mengubah template)</span></button>
        <div v-if="suntingNaskah" class="mt-2">
          <IsianTeksKaya id="sk-naskah" v-model="naskah" tinggi="18rem" kelas="font-mono text-sm" />
          <button type="button" class="tombol-teks -ml-3 mt-1 px-3 text-sm" @click="naskah = t.isi">Kembalikan seperti template</button>
        </div>
      </section>

      <p v-if="kosong.length" class="flex items-start gap-2 rounded-xl bg-[#FFF1B8] px-3 py-2 text-xs text-[#7A4E00]"><PhWarningCircle :size="16" class="mt-0.5 shrink-0" />
        Isian wajib belum lengkap: {{ kosong.join(', ') }}. Draf tetap dapat disimpan, tetapi harus lengkap sebelum diajukan.</p>
      <button class="tombol-utama w-full" :disabled="proses" @click="simpan"><PhFloppyDisk :size="20" weight="duotone" /> {{ proses ? 'Menyimpan…' : 'Simpan draf' }}</button>
      <DokumenCetak :kop="f.kop_kode" :judul="`${t.nama} (pratinjau)`" :nama-berkas="namaBerkas(subjekSurat({ nilai, kepada: f.kepada }), t.nama, 'draf', periodeBulan(f.tanggal_surat))" v-model:pratinjau="pratinjau" sembunyikan-judul tanpa-catatan>
        <SuratResmi :surat="suratPratinjau" :lembaga="ps.konteks || {}" />
      </DokumenCetak>
    </div>
  </LembarBawah>
</template>
