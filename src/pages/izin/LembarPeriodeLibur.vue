<!-- SIMKA PRO | src/pages/izin/LembarPeriodeLibur.vue | v1.1 | 14.5.0: cara penentuan bersyarat atau bertingkat (lama libur sesuai syarat) | 18/10/2026 -->
<script setup>
// Buat/ubah periode libur: nama, jenis, waktu pulang dan batas kembali, rentang hitung kehadiran, sasaran (jenjang,
// putra/putri), dan syarat yang dapat diatur (kosongkan kolom bila syarat itu tidak dipakai).
// v1.1: Cara penentuan — "Bersyarat" (boleh/tidak libur) atau "Bertingkat" (semua santri libur; lama libur sesuai syarat
//       yang terpenuhi). Setiap tingkat punya nama, waktu pulang, batas kembali, dan syarat; tingkat terakhir = santri lainnya.
import { ref, watch } from 'vue'
import { PhFloppyDisk, PhInfo, PhPlus, PhTrash } from '@phosphor-icons/vue'
import { useLibur } from '@/stores/libur'
import { useUI } from '@/stores/ui'
import { JENIS_PERIODE, SYARAT_LIBUR } from '@/lib/izin'
import { JENJANG } from '@/lib/santri'
import { hariIniISO } from '@/lib/tanggal'
import LembarBawah from '@/components/LembarBawah.vue'
import InputTanggal from '@/components/InputTanggal.vue'
import InputJam from '@/components/InputJam.vue'

const buka = defineModel({ type: Boolean, default: false })
const props = defineProps({ periode: { type: Object, default: null } })
const emit = defineEmits(['tersimpan'])
const lb = useLibur(); const ui = useUI()
const f = ref({}); const proses = ref(false)
const wita = (iso) => new Date(new Date(iso).getTime() + 8 * 3600000).toISOString()
const tambahHari = (iso, n) => { const d = new Date(`${iso}T00:00:00`); d.setDate(d.getDate() + n); return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}` }
watch(buka, (v) => {
  if (!v) return
  const h = props.periode; const t = hariIniISO()
  if (h) {
    const p = wita(h.pulang_pada); const k = wita(h.kembali_batas)
    f.value = { id: h.id, nama: h.nama, jenis: h.jenis, tglP: p.slice(0, 10), jamP: p.slice(11, 16), tglK: k.slice(0, 10), jamK: k.slice(11, 16), mulai: h.hitung_mulai, selesai: h.hitung_selesai,
      jenjang: [...(h.jenjang || [])], jk: h.jenis_kelamin || '', syarat: { ...lb.syarat, ...h.syarat }, catatan: h.catatan || '', mode: h.mode || 'syarat',
      tingkat: (h.tingkat || []).map((t) => { const a = wita(t.pulang_pada); const b = wita(t.kembali_batas); return { nama: t.nama, tglP: a.slice(0, 10), jamP: a.slice(11, 16), tglK: b.slice(0, 10), jamK: b.slice(11, 16), syarat: { ...(t.syarat || {}) } } }) }
  } else {
    f.value = { id: null, nama: '', jenis: 'bulanan', tglP: tambahHari(t, 3), jamP: '08:00', tglK: tambahHari(t, 5), jamK: '17:00', mulai: t.slice(0, 8) + '01', selesai: t,
      jenjang: [], jk: '', syarat: { ...lb.syarat }, catatan: '', mode: 'syarat', tingkat: [] }
  }
})
const gabung = (t, j) => new Date(`${t}T${(j || '00:00').slice(0, 5)}:00+08:00`).toISOString()
const SYARAT_TINGKAT = SYARAT_LIBUR.filter((x) => x.k !== 'margin')
function tingkatBawaan() {
  const x = f.value; const k = { tglK: x.tglK, jamK: x.jamK }
  return [
    { nama: 'Libur 3 hari', tglP: x.tglP, jamP: x.jamP, ...k, syarat: { kelas_min: 90, halaqah_min: 90, asrama_min: 90, izin_maks: 1, terlambat_maks: 0 } },
    { nama: 'Libur 2 hari', tglP: tambahHari(x.tglP, 1), jamP: x.jamP, ...k, syarat: { kelas_min: 80, halaqah_min: 80, asrama_min: 80, izin_maks: 2 } },
    { nama: 'Libur 1 hari', tglP: tambahHari(x.tglP, 2), jamP: x.jamP, ...k, syarat: {} },
  ]
}
function pilihMode(m) { f.value.mode = m; if (m === 'bertingkat' && f.value.tingkat.length < 2) f.value.tingkat = tingkatBawaan() }
function tambahTingkat() { const t = f.value.tingkat; const akhir = t.at(-1); t.splice(t.length - 1, 0, { nama: 'Libur ' + (t.length + 1), tglP: akhir.tglP, jamP: akhir.jamP, tglK: akhir.tglK, jamK: akhir.jamK, syarat: { kelas_min: 75 } }) }
function alihJenjang(j) { f.value.jenjang = f.value.jenjang.includes(j) ? f.value.jenjang.filter((x) => x !== j) : [...f.value.jenjang, j] }
async function simpan() {
  const x = f.value
  if (x.nama.trim().length < 3) return ui.toast('Isi nama periode libur.', 'galat')
  proses.value = true
  try {
    const syarat = Object.fromEntries(Object.entries(x.syarat).map(([k, v]) => [k, v === '' || v == null ? null : typeof v === 'boolean' ? v : Number(v)]))
    const bersih = (o) => Object.fromEntries(Object.entries(o || {}).map(([k, v]) => [k, v === '' || v == null ? null : Number(v)]))
    const tingkat = x.mode === 'bertingkat' ? x.tingkat.map((t, i) => ({ nama: t.nama.trim(), pulang_pada: gabung(t.tglP, t.jamP), kembali_batas: gabung(t.tglK, t.jamK),
      syarat: i < x.tingkat.length - 1 ? bersih(t.syarat) : {} })) : []
    if (x.mode === 'bertingkat' && tingkat.some((t) => t.nama.length < 2 || t.kembali_batas <= t.pulang_pada)) { proses.value = false; return ui.toast('Periksa nama dan waktu setiap tingkat (batas kembali setelah waktu pulang).', 'galat') }
    const id = await lb.simpanPeriode({ id: x.id, nama: x.nama.trim(), jenis: x.jenis, pulang_pada: gabung(x.tglP, x.jamP), kembali_batas: gabung(x.tglK, x.jamK),
      hitung_mulai: x.mulai, hitung_selesai: x.selesai, jenjang: x.jenjang, jenis_kelamin: x.jk || null, syarat, catatan: x.catatan.trim(), mode: x.mode, tingkat })
    ui.toast('Periode libur tersimpan. Lanjutkan dengan menilai santri.'); buka.value = false; emit('tersimpan', id)
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
</script>
<template>
  <LembarBawah v-model="buka" :judul="f.id ? 'Ubah periode libur' : 'Periode libur baru'">
    <div v-if="f.syarat" class="space-y-4 pb-2">
      <div class="grid gap-3 sm:grid-cols-[2fr_1fr]">
        <div><label class="label-isian" for="pl-nm">Nama periode<span class="text-merah"> *</span></label><input id="pl-nm" v-model="f.nama" class="isian" placeholder="Contoh: Libur Bulanan Oktober 2026" /></div>
        <div><label class="label-isian" for="pl-jn">Jenis</label><select id="pl-jn" v-model="f.jenis" class="isian"><option v-for="(n, k) in JENIS_PERIODE" :key="k" :value="k">{{ n }}</option></select></div>
      </div>
      <div>
        <p class="label-isian">Cara penentuan</p>
        <div class="grid grid-cols-2 gap-1 rounded-2xl bg-permukaan2 p-1" role="radiogroup" aria-label="Cara penentuan libur">
          <button v-for="m in [{ k: 'syarat', n: 'Bersyarat', ket: 'Boleh / tidak libur' }, { k: 'bertingkat', n: 'Bertingkat', ket: 'Semua libur, lama sesuai syarat' }]" :key="m.k" type="button" role="radio"
            :aria-checked="f.mode === m.k" :class="['min-h-[48px] rounded-xl px-2 text-sm font-semibold', f.mode === m.k ? 'bg-permukaan text-teks shadow-kartu' : 'text-teks2']" @click="pilihMode(m.k)">
            {{ m.n }}<span class="block text-xs font-normal text-teks3">{{ m.ket }}</span></button>
        </div>
      </div>
      <template v-if="f.mode !== 'bertingkat'">
        <div class="grid gap-3 sm:grid-cols-2"><InputTanggal v-model="f.tglP" label="Tanggal pulang" wajib /><InputJam v-model="f.jamP" label="Jam pulang" /></div>
        <div class="grid gap-3 sm:grid-cols-2"><InputTanggal v-model="f.tglK" label="Batas kembali" wajib /><InputJam v-model="f.jamK" label="Jam kembali" /></div>
      </template>
      <fieldset v-else class="space-y-3 rounded-2xl border border-garis p-3">
        <legend class="px-1 text-sm font-bold">Tingkat libur</legend>
        <p class="flex items-start gap-1.5 text-xs text-teks3"><PhInfo :size="14" class="mt-0.5 shrink-0" /> Santri mendapat tingkat terbaik yang syaratnya terpenuhi (diperiksa dari atas). Tingkat terakhir untuk santri lainnya.
          Waktu pulang dan kembali tiap tingkat dapat berbeda (contoh: semua kembali bersamaan, yang lebih singkat pulang belakangan).</p>
        <div v-for="(t, i) in f.tingkat" :key="i" class="rounded-xl border border-garis p-3">
          <div class="flex items-center gap-2">
            <span class="grid h-8 w-8 shrink-0 place-items-center rounded-lg bg-permukaan2 text-sm font-bold">{{ String.fromCharCode(65 + i) }}</span>
            <input v-model="t.nama" class="isian min-h-[42px] flex-1" :aria-label="`Nama tingkat ${i + 1}`" placeholder="Contoh: Libur 3 hari" />
            <button v-if="f.tingkat.length > 2" type="button" class="tombol-ikon h-10 w-10" :aria-label="`Hapus tingkat ${t.nama}`" @click="f.tingkat.splice(i, 1)"><PhTrash :size="18" /></button>
          </div>
          <div class="mt-2 grid grid-cols-2 gap-2">
            <InputTanggal v-model="t.tglP" label="Pulang" wajib /><InputJam v-model="t.jamP" label="Jam" />
            <InputTanggal v-model="t.tglK" label="Kembali" wajib /><InputJam v-model="t.jamK" label="Jam" />
          </div>
          <div v-if="i < f.tingkat.length - 1" class="mt-2 grid grid-cols-2 gap-2 sm:grid-cols-3">
            <div v-for="sy2 in SYARAT_TINGKAT" :key="sy2.k"><label class="label-isian text-xs" :for="`tk${i}-${sy2.k}`">{{ sy2.n }} ({{ sy2.s }})</label>
              <input :id="`tk${i}-${sy2.k}`" v-model="t.syarat[sy2.k]" type="number" min="0" class="isian min-h-[40px] tabular-nums" placeholder="–" /></div>
          </div>
          <p v-else class="mt-2 text-xs text-teks3">Tanpa syarat: santri yang tidak memenuhi tingkat di atasnya.</p>
        </div>
        <button v-if="f.tingkat.length < 6" type="button" class="tombol-garis min-h-[40px] px-3 text-sm" @click="tambahTingkat"><PhPlus :size="16" /> Tambah tingkat</button>
      </fieldset>
      <div>
        <p class="label-isian">Rentang hitung kehadiran dan izin</p>
        <div class="grid grid-cols-2 gap-3"><InputTanggal v-model="f.mulai" label="Dari" wajib /><InputTanggal v-model="f.selesai" label="Sampai" wajib /></div>
      </div>
      <div class="grid gap-3 sm:grid-cols-2">
        <div><p class="label-isian">Jenjang (kosong = semua)</p>
          <div class="flex flex-wrap gap-2"><button v-for="(n, k) in JENJANG" :key="k" type="button" :aria-pressed="f.jenjang.includes(k)" @click="alihJenjang(k)"
            :class="['min-h-[40px] rounded-xl border px-3 text-sm font-semibold', f.jenjang.includes(k) ? 'border-[#3B4CB0] bg-[#3B4CB0]/10 text-teks' : 'border-garis text-teks2']">{{ n }}</button></div></div>
        <div><label class="label-isian" for="pl-jk">Santri</label><select id="pl-jk" v-model="f.jk" class="isian"><option value="">Putra dan putri</option><option value="L">Putra saja</option><option value="P">Putri saja</option></select></div>
      </div>
      <fieldset v-if="f.mode !== 'bertingkat'" class="rounded-2xl border border-garis p-3">
        <legend class="px-1 text-sm font-bold">Syarat libur</legend>
        <p class="mb-3 flex items-start gap-1.5 text-xs text-teks3"><PhInfo :size="14" class="mt-0.5 shrink-0" /> Kosongkan kolom bila syarat itu tidak dipakai. Ekskul tidak dihitung.</p>
        <div class="grid gap-3 sm:grid-cols-2">
          <div v-for="s in SYARAT_LIBUR" :key="s.k">
            <label class="label-isian" :for="'sy-' + s.k">{{ s.n }} ({{ s.s }})</label>
            <input :id="'sy-' + s.k" v-model="f.syarat[s.k]" type="number" min="0" :max="s.s === '%' ? 100 : 600" class="isian tabular-nums" placeholder="Tidak dipakai" />
          </div>
        </div>
        <label class="mt-3 flex items-center gap-2 text-sm"><input v-model="f.syarat.abaikan_izin_sakit" type="checkbox" class="h-5 w-5 accent-[#C7332F]" /> Izin dan sakit tidak mengurangi persentase kehadiran</label>
      </fieldset>
      <textarea v-model="f.catatan" rows="2" class="isian" placeholder="Catatan (opsional)" aria-label="Catatan periode" />
      <button class="tombol-utama w-full" :disabled="proses" @click="simpan"><PhFloppyDisk :size="20" weight="duotone" /> {{ proses ? 'Menyimpan…' : 'Simpan periode' }}</button>
    </div>
  </LembarBawah>
</template>
