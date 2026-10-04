<!-- SIMKA PRO | src/pages/agenda/Agenda.vue | v1.1 | Fase 3 – Perbaikan P2 (agenda lanjutan) | 04/10/2026 -->
<script setup>
// Agenda dan kalender pondok. Semua pegawai melihat agenda yang ditujukan kepadanya beserta hari libur pondok
// dalam kalender bulanan. Admin ber-izin kelola_agenda membuat agenda dengan sasaran dan pengingat H-n;
// agenda berjenis libur otomatis masuk kalender libur (izin kalender). Undangan dapat dikirim lewat WA.
// v1.1: berulang (harian/pekanan/bulanan/tahunan), tautan, lampiran, pengingat menit/jam/hari, 24 warna lembut.
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { PhCaretLeft, PhCaretRight, PhPlus, PhCalendarStar, PhUsersThree, PhConfetti, PhDotsThreeCircle, PhSparkle, PhClock, PhMapPin, PhBell, PhPencilSimple, PhTrash, PhWhatsappLogo, PhPrinter, PhCalendarBlank, PhRepeat, PhLink, PhPaperclip, PhX, PhSkipForward, PhCheck } from '@phosphor-icons/vue'
import { useAgenda } from '@/stores/agenda'
import { useLembaga } from '@/stores/lembaga'
import { usePengumuman } from '@/stores/pengumuman'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { hariIniISO, formatPanjang, formatHari, formatPendek } from '@/lib/tanggal'
import { pesanWA, tautanWA } from '@/lib/wa'
import { MODE_DEMO } from '@/lib/supabase'
import { ambilBerkasUrl, unggahKeDrive, kompresGambar, namaRapi } from '@/lib/penyimpanan'
import { WARNA_AGENDA, gayaAgenda } from '@/lib/warnaAgenda'
import LembarBawah from '@/components/LembarBawah.vue'
import TombolAksi from '@/components/TombolAksi.vue'
import InputTanggal from '@/components/InputTanggal.vue'
import PilihSasaran from '@/components/PilihSasaran.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'

const props = defineProps({ id: String })
const router = useRouter(); const route = useRoute(); const ag = useAgenda(); const lembaga = useLembaga(); const pg = usePengumuman(); const sesi = useSesi(); const ui = useUI()
const kelola = computed(() => ag.bolehKelola())
const JENIS = { kegiatan: { n: 'Kegiatan', i: PhSparkle, w: 'agenda' }, rapat: { n: 'Rapat', i: PhUsersThree, w: 'pengajuan' }, libur: { n: 'Libur', i: PhConfetti, w: 'beranda' }, lainnya: { n: 'Lainnya', i: PhDotsThreeCircle, w: 'tahfizh' } }
const HARI = ['Ahad', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu']
const BULAN = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember']
const iso = (d) => d.toISOString().slice(0, 10)
const bulan = ref(hariIniISO().slice(0, 7)); const dipilih = ref(hariIniISO())
const awal = computed(() => bulan.value + '-01')
const akhir = computed(() => { const [y, m] = bulan.value.split('-').map(Number); return iso(new Date(Date.UTC(y, m, 0))) })
const judulBulan = computed(() => { const [y, m] = bulan.value.split('-').map(Number); return `${BULAN[m - 1]} ${y}` })
function geser(n) { const [y, m] = bulan.value.split('-').map(Number); const d = new Date(Date.UTC(y, m - 1 + n, 1)); bulan.value = iso(d).slice(0, 7); dipilih.value = bulan.value === hariIniISO().slice(0, 7) ? hariIniISO() : iso(d) }
onMounted(() => lembaga.muat())
watch(bulan, () => ag.muat(awal.value, akhir.value).catch((e) => ui.toast(e.message, 'galat')), { immediate: true })

const sel = computed(() => {
  const [y, m] = bulan.value.split('-').map(Number); const pertama = new Date(Date.UTC(y, m - 1, 1)); const out = []
  for (let i = 0; i < pertama.getUTCDay(); i++) out.push(null)
  for (let d = 1; d <= new Date(Date.UTC(y, m, 0)).getUTCDate(); d++) { const t = iso(new Date(Date.UTC(y, m - 1, d))); out.push({ t, d, acara: ag.daftar.filter((a) => a.mulai <= t && a.selesai >= t) }) }
  return out
})
const acaraHari = computed(() => ag.daftar.filter((a) => a.mulai <= dipilih.value && a.selesai >= dipilih.value))
const urut = computed(() => [...ag.daftar].sort((a, b) => a.mulai.localeCompare(b.mulai) || String(a.jam_mulai || '').localeCompare(String(b.jam_mulai || ''))))
const jam = (v) => (v ? String(v).slice(0, 5).replace(':', '.') : '')
const waktu = (a) => (a.jam_mulai ? `${jam(a.jam_mulai)}${a.jam_selesai ? '–' + jam(a.jam_selesai) : ''} WITA` : 'Sepanjang hari')
const tanggal = (a) => (a.selesai > a.mulai ? `${formatPanjang(a.mulai)} s.d. ${formatPanjang(a.selesai)}` : formatHari(a.mulai))
const NAMA_LIBUR = { libur_pondok: 'Libur pondok', libur_bulanan: 'Libur bulanan', libur_sekolah: 'Libur sekolah', libur_nasional: 'Libur nasional' }
const berlaku = (a) => (a.berlaku_untuk || []).map((k) => (k === 'semua' ? 'semua tugas' : lembaga.holiday_calendars.find((c) => c.jenis_tugas === k)?.nama || k)).join(', ')

// ---------- Detail ----------
const lihatLibur = ref(null)
const terpilih = computed(() => {
  if (!props.id) return lihatLibur.value
  const semua = ag.daftar.filter((a) => a.id === props.id && a.sumber === 'agenda')
  return semua.find((a) => a.mulai === route.query.tanggal) || semua[0] || lihatLibur.value
})
watch(() => [props.id, route.query.tanggal], ([id, t]) => { if (id && t && t.slice(0, 7) !== bulan.value) { bulan.value = t.slice(0, 7); dipilih.value = t } }, { immediate: true })
function buka(a) { if (a.sumber === 'libur') lihatLibur.value = a; else router.push({ path: `/agenda/${a.id}`, query: a.ulang ? { tanggal: a.mulai } : {} }) }
function tutup() { lihatLibur.value = null; if (props.id) router.replace('/agenda') }

// ---------- Formulir ----------
const form = ref(null); const ringkas = ref('Semua pegawai'); const simpanan = ref(false)
const PENGINGAT = [{ m: 0, n: 'Saat dimulai' }, { m: 10, n: '10 menit' }, { m: 30, n: '30 menit' }, { m: 60, n: '1 jam' }, { m: 120, n: '2 jam' }, { m: 1440, n: '1 hari' }, { m: 4320, n: '3 hari' }, { m: 10080, n: '7 hari' }]
const labelMenit = (m) => (m === 0 ? 'saat dimulai' : m % 1440 === 0 ? `${m / 1440} hari` : m % 60 === 0 ? `${m / 60} jam` : `${m} menit`) + (m ? ' sebelumnya' : '')
const FREK = { '': 'Tidak berulang', harian: 'Setiap hari', pekanan: 'Setiap pekan', bulanan: 'Setiap bulan', tahunan: 'Setiap tahun' }
const SATUAN = { harian: 'hari', pekanan: 'pekan', bulanan: 'bulan', tahunan: 'tahun' }
const berkas = ref(null); const lain = ref({ n: '', s: 60 })
function baru() {
  form.value = { judul: '', jenis: 'kegiatan', warna: 'merak', mulai: dipilih.value >= hariIniISO() ? dipilih.value : hariIniISO(), selesai: '', seharian: false, jam_mulai: '08:00', jam_selesai: '',
    lokasi: '', keterangan: '', tautan: '', nama_tautan: '', pengingat_menit: [1440, 60], frek: '', interval: 1, hari: [], akhir: 'tidak', sampai: '', kali: 10,
    jenis_libur: 'libur_pondok', berlaku_untuk: ['semua'], sasaran: { jenis: 'semua' } }
  berkas.value = null
}
function ubah(a) {
  const u = a.ulang || {}
  form.value = { id: a.id, judul: a.judul, jenis: a.jenis, warna: a.warna || 'merak', mulai: a.mulai_seri || a.mulai, selesai: a.selesai_seri || a.selesai, seharian: !a.jam_mulai,
    jam_mulai: jam(a.jam_mulai).replace('.', ':'), jam_selesai: jam(a.jam_selesai).replace('.', ':'), lokasi: a.lokasi || '', keterangan: a.keterangan || '',
    tautan: a.tautan || '', nama_tautan: a.nama_tautan || '', nama_lampiran: a.nama_lampiran, pengingat_menit: [...(a.pengingat_menit || [])],
    frek: u.frek || '', interval: u.interval || 1, hari: u.hari || [], akhir: u.sampai ? 'tanggal' : u.kali ? 'kali' : 'tidak', sampai: u.sampai || '', kali: u.kali || 10,
    jenis_libur: a.jenis_libur || 'libur_pondok', berlaku_untuk: a.berlaku_untuk || ['semua'] }
  berkas.value = null
}
watch(() => form.value?.mulai, (m) => { if (form.value && m && (!form.value.selesai || form.value.selesai < m)) form.value.selesai = m })
watch(() => form.value?.jenis, (j) => { if (form.value && !form.value.id) form.value.warna = { libur: 'tomat', rapat: 'lavender', lainnya: 'pisang', kegiatan: 'merak' }[j] })
watch(() => form.value?.frek, (f) => { if (form.value && f === 'pekanan' && !form.value.hari.length) form.value.hari = [new Date(form.value.mulai + 'T00:00:00Z').getUTCDay()] })
function balikPengingat(m) { const s = new Set(form.value.pengingat_menit); s.has(m) ? s.delete(m) : s.add(m); form.value.pengingat_menit = [...s].sort((a, b) => b - a) }
function tambahPengingat() { const m = Math.round(Number(lain.value.n) * Number(lain.value.s)); if (!(m > 0) || m > 43200) return ui.toast('Isi angka pengingat (paling lama 30 hari).', 'galat'); if (!form.value.pengingat_menit.includes(m)) balikPengingat(m); lain.value.n = '' }
function balikHari(h) { const s = new Set(form.value.hari); s.has(h) ? s.delete(h) : s.add(h); form.value.hari = [...s].sort() }
function pilihBerkas(e) { const b = e.target.files?.[0]; e.target.value = ''; if (!b) return; if (!/^image\/|application\/pdf/.test(b.type)) return ui.toast('Lampiran harus PDF atau foto.', 'galat'); if (b.type === 'application/pdf' && b.size > 5242880) return ui.toast('Ukuran PDF paling besar 5 MB.', 'galat'); berkas.value = b }
const ringkasUlang = computed(() => {
  const f = form.value; if (!f?.frek) return ''
  const hari = f.frek === 'pekanan' ? ` (${(f.hari.length ? f.hari : [new Date(f.mulai + 'T00:00:00Z').getUTCDay()]).map((h) => HARI[h]).join(', ')})` : ''
  const akhir = f.akhir === 'tanggal' && f.sampai ? ` sampai ${formatPendek(f.sampai)}` : f.akhir === 'kali' ? `, ${f.kali} kali` : ''
  return `Setiap ${f.interval > 1 ? f.interval + ' ' : ''}${SATUAN[f.frek]}${hari}${akhir}`
})
const membuka = ref(false)
async function bukaLampiran(a) {
  if (MODE_DEMO) return ui.toast('Mode demo: lampiran contoh tidak tersedia.', 'info')
  membuka.value = true
  try { const u = await ambilBerkasUrl(a.lampiran_id); const el = document.createElement('a'); el.href = u; el.target = '_blank'; el.rel = 'noopener'; el.click() } catch (e) { ui.toast(e.message, 'galat') } finally { membuka.value = false }
}
async function lewati(a) {
  if (!(await ui.konfirmasi({ judul: 'Tiadakan kegiatan tanggal ini?', pesan: `${a.judul}, ${formatHari(a.mulai)}. Kejadian lain tetap berjalan; penerima diberi tahu.`, ya: 'Tiadakan', bahaya: true }))) return
  try { await ag.lewati(a.id, a.mulai); tutup(); ui.toast('Kegiatan pada tanggal itu ditiadakan.', 'info') } catch (e) { ui.toast(e.message, 'galat') }
}
function balikBerlaku(k) {
  let s = new Set(form.value.berlaku_untuk)
  if (k === 'semua') s = new Set(['semua']); else { s.delete('semua'); s.has(k) ? s.delete(k) : s.add(k); if (!s.size) s.add('semua') }
  form.value.berlaku_untuk = [...s]
}
async function simpan() {
  const f = form.value
  if (f.judul.trim().length < 3) return ui.toast('Judul agenda minimal 3 karakter.', 'galat')
  if (f.selesai < f.mulai) return ui.toast('Tanggal selesai tidak boleh sebelum tanggal mulai.', 'galat')
  if (!f.seharian && f.jenis !== 'libur' && f.jam_selesai && f.jam_selesai <= f.jam_mulai && f.selesai === f.mulai) return ui.toast('Jam selesai harus setelah jam mulai.', 'galat')
  if (f.tautan.trim() && !/^https?:\/\//.test(f.tautan.trim())) return ui.toast('Tautan harus diawali https://', 'galat')
  if (f.frek && f.akhir === 'tanggal' && (!f.sampai || f.sampai < f.mulai)) return ui.toast('Isi tanggal akhir pengulangan (tidak sebelum tanggal mulai).', 'galat')
  if (!f.id && !(await ui.konfirmasi({ judul: 'Simpan agenda?', pesan: `Sasaran: ${ringkas.value}. ${f.frek ? ringkasUlang.value + '. ' : ''}Penerima mendapat notifikasi sekarang dan pengingat ${f.pengingat_menit.map(labelMenit).join(', ') || 'tidak ada'}.`, ya: 'Simpan' }))) return
  simpanan.value = true
  try {
    const seharian = f.seharian || f.jenis === 'libur'
    const isi = { ...f, jam_mulai: seharian ? null : f.jam_mulai, jam_selesai: seharian ? null : f.jam_selesai || null, ringkasan: ringkas.value,
      ulang: f.frek && f.jenis !== 'libur' ? { frek: f.frek, interval: f.interval, hari: f.hari, sampai: f.akhir === 'tanggal' ? f.sampai : null, kali: f.akhir === 'kali' ? f.kali : null } : null }
    delete isi.nama_lampiran
    if (berkas.value) {
      if (MODE_DEMO) { isi.lampiran_id = 'demo'; isi.nama_lampiran = berkas.value.name }
      else {
        const blob = berkas.value.type === 'application/pdf' ? berkas.value : await kompresGambar(berkas.value, { maks: 2000, kualitas: 0.8 })
        isi.lampiran_id = await unggahKeDrive(blob, { nama: namaRapi('Agenda', f.judul.slice(0, 40), f.mulai) + (blob.type === 'application/pdf' ? '.pdf' : '.jpg'), kategori: 'lampiran_agenda', folder: `SIMKA PRO/Agenda/${f.mulai.slice(0, 4)}` })
      }
    }
    const id = await ag.simpan(isi)
    form.value = null; ui.toast('Agenda disimpan.', 'info'); if (id) router.replace(`/agenda/${id}`)
  } catch (e) { ui.toast(e.message, 'galat') } finally { simpanan.value = false }
}
async function hapus(a) {
  if (!(await ui.konfirmasi({ judul: 'Hapus agenda?', pesan: `"${a.judul}"${a.jenis === 'libur' ? ' beserta hari liburnya di kalender pondok' : ''} akan dihapus.`, ya: 'Hapus', bahaya: true }))) return
  try { await ag.hapus(a.id); tutup(); ui.toast('Agenda dihapus.', 'info') } catch (e) { ui.toast(e.message, 'galat') }
}

// ---------- WA ----------
const wa = ref(null)
async function bukaWA(a) { try { wa.value = { a, daftar: await ag.penerima(a.id) } } catch (e) { ui.toast(e.message, 'galat') } }
const pesan = (a, p) => pesanWA('undangan_agenda', { nama: p.nama, judul: a.judul, tanggal: tanggal(a), waktu: waktu(a), lokasi: a.lokasi, keterangan: [a.keterangan, a.tautan && `${a.nama_tautan || 'Tautan'}: ${a.tautan}`].filter(Boolean).join('\n'), tautan: a.tautan, unit: p.unit })

// ---------- Cetak ----------
const pratinjau = ref(false)
const direktur = computed(() => lembaga.signatories.find((s) => s.sumber_jabatan === 'DIREKTUR' || /^direktur/i.test(s.jabatan_tertulis)) || {})
</script>
<template>
  <div class="w-agenda mx-auto max-w-5xl">
    <div class="layar-saja">
      <div class="kartu mb-3 flex items-center gap-2 p-2">
        <button class="tombol-ikon" aria-label="Bulan sebelumnya" @click="geser(-1)"><PhCaretLeft :size="22" weight="bold" /></button>
        <p class="flex-1 text-center text-lg font-bold">{{ judulBulan }}</p>
        <button class="tombol-ikon" aria-label="Bulan berikutnya" @click="geser(1)"><PhCaretRight :size="22" weight="bold" /></button>
        <button class="tombol-garis hidden min-h-[40px] text-sm sm:inline-flex" @click="pratinjau = true"><PhPrinter :size="18" weight="duotone" /> Cetak</button>
        <button v-if="kelola" class="tombol-utama hidden min-h-[40px] text-sm lg:inline-flex" @click="baru"><PhPlus :size="18" weight="bold" /> Agenda</button>
      </div>

      <div class="grid gap-4 lg:grid-cols-[1fr_22rem]">
        <section class="kartu p-2 sm:p-3" aria-label="Kalender bulanan">
          <div class="grid grid-cols-7 text-center text-xs font-bold text-teks3"><span v-for="(h, i) in ['Ahd', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab']" :key="h" :class="['py-1.5', i === 0 && 'text-[rgb(var(--merah))]']">{{ h }}</span></div>
          <div class="grid grid-cols-7 gap-1">
            <template v-for="(c, i) in sel" :key="i">
              <span v-if="!c" />
              <button v-else type="button" :aria-label="`${formatHari(c.t)}, ${c.acara.length} agenda`" :aria-pressed="dipilih === c.t" @click="dipilih = c.t"
                :class="['hari flex min-h-[52px] flex-col items-stretch rounded-lg p-1 text-left sm:min-h-[84px]', dipilih === c.t && 'pilih', c.t === hariIniISO() && 'kini', c.acara.some((a) => a.jenis === 'libur') && 'libur']">
                <span class="text-sm font-bold tabular-nums">{{ c.d }}</span>
                <span class="mt-0.5 hidden space-y-0.5 sm:block">
                  <span v-for="a in c.acara.slice(0, 2)" :key="a.id + a.mulai" class="warna-agenda block truncate rounded px-1 text-[11px] font-semibold" :style="[gayaAgenda(a.warna), { background: 'color-mix(in srgb, var(--c) 18%, transparent)', color: 'var(--c)' }]">{{ a.jam_mulai ? jam(a.jam_mulai) + ' ' : '' }}{{ a.judul }}</span>
                  <span v-if="c.acara.length > 2" class="block text-[11px] text-teks3">+{{ c.acara.length - 2 }} lagi</span>
                </span>
                <span class="mt-auto flex gap-0.5 sm:hidden"><span v-for="a in c.acara.slice(0, 3)" :key="a.id + a.mulai" class="warna-agenda h-1.5 w-1.5 rounded-full" :style="[gayaAgenda(a.warna), { background: 'var(--c)' }]" /></span>
              </button>
            </template>
          </div>
          <div class="mt-2 flex flex-wrap gap-3 px-1 text-xs text-teks2">
            <span class="flex items-center gap-1"><PhRepeat :size="14" /> agenda berulang</span><span>Warna mengikuti pilihan pembuat agenda</span>
          </div>
        </section>

        <section>
          <h3 class="mb-2 font-bold">{{ formatHari(dipilih) }}</h3>
          <ul class="space-y-2">
            <li v-for="a in acaraHari" :key="a.id + a.mulai">
              <button type="button" class="kartu warna-agenda kartu-ag flex w-full items-start gap-3 p-3 text-left hover:bg-permukaan2" :style="gayaAgenda(a.warna)" @click="buka(a)">
                <span class="chip-ikon h-9 w-9 shrink-0"><component :is="JENIS[a.jenis].i" :size="20" weight="duotone" /></span>
                <span class="min-w-0"><span class="block font-semibold leading-snug">{{ a.judul }}</span><span class="block text-xs text-teks3">{{ a.sumber === 'libur' ? NAMA_LIBUR[a.jenis_libur] || 'Libur' : waktu(a) }}{{ a.lokasi ? ' · ' + a.lokasi : '' }}</span>
                  <span v-if="a.ulang" class="flex items-center gap-1 text-xs text-teks3"><PhRepeat :size="13" /> {{ a.ringkasan_ulang }}</span></span>
              </button>
            </li>
            <li v-if="!acaraHari.length" class="flex items-center gap-2 py-3 text-sm text-teks3"><PhCalendarBlank :size="20" /> Tidak ada agenda.</li>
          </ul>
          <h3 class="mb-2 mt-5 font-bold">Agenda {{ judulBulan }}</h3>
          <ul class="kartu divide-y divide-garis">
            <li v-for="a in urut" :key="a.id + a.mulai">
              <button type="button" class="flex w-full items-center gap-3 p-3 text-left hover:bg-permukaan2" @click="buka(a); dipilih = a.mulai < awal ? awal : a.mulai">
                <span class="warna-agenda w-11 shrink-0 text-center" :style="gayaAgenda(a.warna)"><span class="block text-lg font-extrabold leading-none" style="color: var(--c)">{{ a.mulai.slice(8) }}</span><span class="text-[11px] text-teks3">{{ ['Ahd', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'][new Date(a.mulai + 'T00:00:00Z').getUTCDay()] }}</span></span>
                <span class="min-w-0"><span class="block truncate text-sm font-semibold">{{ a.judul }}<PhRepeat v-if="a.ulang" :size="13" class="ml-1 inline text-teks3" /></span><span class="block text-xs text-teks3">{{ a.sumber === 'libur' ? NAMA_LIBUR[a.jenis_libur] || 'Libur' : waktu(a) }}</span></span>
              </button>
            </li>
            <li v-if="!urut.length" class="p-3 text-sm text-teks3">{{ ag.memuat ? 'Memuat…' : 'Belum ada agenda bulan ini.' }}</li>
          </ul>
        </section>
      </div>
      <TombolAksi v-if="kelola" label="Agenda" :ikon="PhPlus" warna="agenda" @klik="baru" />
    </div>

    <!-- Detail -->
    <LembarBawah :model-value="!!terpilih && !form && !wa" @update:model-value="(v) => !v && tutup()" :judul="terpilih?.sumber === 'libur' ? 'Hari libur' : 'Rincian agenda'">
      <div v-if="terpilih" class="warna-agenda pb-2" :style="gayaAgenda(terpilih.warna)">
        <span class="lencana">{{ terpilih.sumber === 'libur' ? NAMA_LIBUR[terpilih.jenis_libur] || 'Libur' : JENIS[terpilih.jenis].n }}</span>
        <h3 class="mt-2 text-xl font-extrabold leading-snug">{{ terpilih.judul }}</h3>
        <ul class="mt-3 space-y-1.5 text-sm">
          <li class="flex gap-2"><PhCalendarStar :size="20" class="shrink-0 text-teks3" />{{ tanggal(terpilih) }}</li>
          <li v-if="terpilih.sumber !== 'libur'" class="flex gap-2"><PhClock :size="20" class="shrink-0 text-teks3" />{{ waktu(terpilih) }}</li>
          <li v-if="terpilih.lokasi" class="flex gap-2"><PhMapPin :size="20" class="shrink-0 text-teks3" />{{ terpilih.lokasi }}</li>
          <li v-if="terpilih.berlaku_untuk" class="flex gap-2"><PhConfetti :size="20" class="shrink-0 text-teks3" />Libur berlaku untuk {{ berlaku(terpilih) }}</li>
          <li v-if="terpilih.ulang" class="flex gap-2"><PhRepeat :size="20" class="shrink-0 text-teks3" />{{ terpilih.ringkasan_ulang }} (mulai {{ formatPendek(terpilih.mulai_seri) }})</li>
          <li v-if="terpilih.pengingat_menit?.length" class="flex gap-2"><PhBell :size="20" class="shrink-0 text-teks3" />Pengingat {{ terpilih.pengingat_menit.map(labelMenit).join(', ') }}{{ terpilih.jam_mulai ? '' : ' (acuan pukul 06.00 WITA)' }}</li>
        </ul>
        <p v-if="terpilih.keterangan" class="mt-3 whitespace-pre-line">{{ terpilih.keterangan }}</p>
        <div v-if="terpilih.tautan || terpilih.lampiran_id" class="mt-3 space-y-2">
          <a v-if="terpilih.tautan" :href="terpilih.tautan" target="_blank" rel="noopener" class="flex items-center gap-3 rounded-xl border border-garis p-3 hover:bg-permukaan2">
            <span class="chip-ikon h-10 w-10 shrink-0"><PhLink :size="20" weight="duotone" /></span>
            <span class="min-w-0 flex-1"><span class="block truncate font-semibold">{{ terpilih.nama_tautan || 'Buka tautan' }}</span><span class="block truncate text-xs text-teks3">{{ terpilih.tautan }}</span></span></a>
          <button v-if="terpilih.lampiran_id" class="flex w-full items-center gap-3 rounded-xl border border-garis p-3 text-left hover:bg-permukaan2" :disabled="membuka" @click="bukaLampiran(terpilih)">
            <span class="chip-ikon h-10 w-10 shrink-0"><PhPaperclip :size="20" weight="duotone" /></span>
            <span class="min-w-0 flex-1"><span class="block truncate font-semibold">{{ terpilih.nama_lampiran || 'Lampiran' }}</span><span class="block text-xs text-teks3">{{ membuka ? 'Mengambil berkas…' : 'Ketuk untuk membuka' }}</span></span></button>
        </div>
        <p v-if="kelola && terpilih.sumber === 'agenda'" class="mt-3 text-sm text-teks2">Sasaran: {{ terpilih.ringkasan_sasaran }}<template v-if="terpilih.penerima != null"> · {{ terpilih.penerima }} penerima</template></p>
        <p v-if="terpilih.sumber === 'libur'" class="mt-3 text-sm text-teks3">Diatur di Pengaturan → Tahun ajaran dan kalender.</p>
        <div v-if="kelola && terpilih.sumber === 'agenda'" class="mt-4 flex flex-wrap gap-2">
          <button class="tombol-garis" @click="bukaWA(terpilih)"><PhWhatsappLogo :size="20" weight="duotone" /> Kirim WA</button>
          <button class="tombol-garis" @click="ubah(terpilih)"><PhPencilSimple :size="20" weight="duotone" /> {{ terpilih.ulang ? 'Ubah seri' : 'Ubah' }}</button>
          <button v-if="terpilih.ulang" class="tombol-garis" @click="lewati(terpilih)"><PhSkipForward :size="20" weight="duotone" /> Tiadakan tanggal ini</button>
          <button class="tombol-garis w-beranda" style="color: var(--c)" @click="hapus(terpilih)"><PhTrash :size="20" weight="duotone" /> Hapus</button>
        </div>
      </div>
    </LembarBawah>

    <!-- Formulir -->
    <LembarBawah :model-value="!!form" @update:model-value="(v) => !v && (form = null)" :judul="form?.id ? 'Ubah agenda' : 'Agenda baru'">
      <form v-if="form" class="w-agenda space-y-3 pb-2" @submit.prevent="simpan">
        <div><label class="label-isian" for="ag-judul">Judul</label><input id="ag-judul" v-model="form.judul" class="isian" maxlength="150" placeholder="Contoh: Rapat koordinasi seluruh pegawai" /></div>
        <fieldset><legend class="label-isian">Jenis</legend>
          <div class="grid grid-cols-2 gap-2 sm:grid-cols-4">
            <button v-for="(j, k) in JENIS" :key="k" type="button" :aria-pressed="form.jenis === k" @click="form.jenis = k"
              :class="['jenis flex min-h-[48px] items-center gap-2 rounded-xl border px-2.5 text-sm font-semibold', 'w-' + j.w, form.jenis === k ? 'aktif' : 'border-garis bg-permukaan text-teks2']">
              <component :is="j.i" :size="20" weight="duotone" style="color: var(--c)" />{{ j.n }}</button>
          </div></fieldset>
        <fieldset><legend class="label-isian">Warna agenda</legend>
          <div class="grid grid-cols-8 gap-2 sm:grid-cols-12">
            <button v-for="[k, n] in WARNA_AGENDA" :key="k" type="button" class="warna-agenda grid h-8 w-8 place-items-center rounded-full" :style="[gayaAgenda(k), { background: 'var(--c)' }]" :title="n" :aria-label="`Warna ${n}`" :aria-pressed="form.warna === k" @click="form.warna = k">
              <PhCheck v-if="form.warna === k" :size="16" weight="bold" class="text-white dark:text-[#1a1214]" /></button>
          </div></fieldset>
        <div class="grid gap-3 sm:grid-cols-2"><InputTanggal v-model="form.mulai" label="Tanggal mulai" wajib /><InputTanggal v-model="form.selesai" label="Tanggal selesai" wajib /></div>
        <template v-if="form.jenis !== 'libur'">
          <label class="flex min-h-[44px] items-center gap-3 font-semibold"><input v-model="form.seharian" type="checkbox" class="h-5 w-5 accent-[#1572B6]" /> Sepanjang hari (tanpa jam)</label>
          <div v-if="!form.seharian" class="grid gap-3 sm:grid-cols-2">
            <div><label class="label-isian" for="ag-jm">Jam mulai</label><input id="ag-jm" v-model="form.jam_mulai" type="time" class="isian" /></div>
            <div><label class="label-isian" for="ag-js">Jam selesai (opsional)</label><input id="ag-js" v-model="form.jam_selesai" type="time" class="isian" /></div>
          </div>
          <div><label class="label-isian" for="ag-lok">Tempat</label><input id="ag-lok" v-model="form.lokasi" class="isian" placeholder="Contoh: Aula Utama" /></div>
          <fieldset class="rounded-xl border border-garis p-3"><legend class="label-isian px-1"><PhRepeat :size="16" class="mr-1 inline" />Pengulangan</legend>
            <select v-model="form.frek" class="isian" aria-label="Pola pengulangan"><option v-for="(n, k) in FREK" :key="k" :value="k">{{ n }}</option></select>
            <template v-if="form.frek">
              <div class="mt-2 flex items-center gap-2 text-sm"><span>Setiap</span><input v-model.number="form.interval" type="number" min="1" max="99" class="isian w-20" aria-label="Selang" /><span>{{ SATUAN[form.frek] }}</span></div>
              <div v-if="form.frek === 'pekanan'" class="mt-2 flex flex-wrap gap-1.5"><button v-for="(h, i) in HARI" :key="h" type="button" :class="['chip', form.hari.includes(i) && 'pilih']" @click="balikHari(i)">{{ h }}</button></div>
              <div class="mt-2 space-y-1.5 text-sm">
                <label class="flex min-h-[40px] items-center gap-2"><input v-model="form.akhir" type="radio" value="tidak" class="h-5 w-5" /> Tanpa akhir</label>
                <label class="flex min-h-[40px] flex-wrap items-center gap-2"><input v-model="form.akhir" type="radio" value="tanggal" class="h-5 w-5" /> Sampai tanggal
                  <input v-if="form.akhir === 'tanggal'" v-model="form.sampai" type="date" class="isian w-44" aria-label="Tanggal akhir pengulangan" /></label>
                <label class="flex min-h-[40px] items-center gap-2"><input v-model="form.akhir" type="radio" value="kali" class="h-5 w-5" /> Setelah
                  <input v-model.number="form.kali" type="number" min="1" max="500" class="isian w-20" :disabled="form.akhir !== 'kali'" aria-label="Jumlah kejadian" /> kali</label>
              </div>
              <p class="mt-1 text-xs font-semibold text-teks2">{{ ringkasUlang }}</p>
            </template>
          </fieldset>
        </template>
        <template v-else>
          <div><label class="label-isian" for="ag-jl">Jenis libur</label>
            <select id="ag-jl" v-model="form.jenis_libur" class="isian"><option v-for="(n, k) in NAMA_LIBUR" :key="k" :value="k">{{ n }}</option></select></div>
          <fieldset><legend class="label-isian">Libur berlaku untuk</legend>
            <div class="flex flex-wrap gap-1.5">
              <button type="button" :class="['chip', form.berlaku_untuk.includes('semua') && 'pilih']" @click="balikBerlaku('semua')">Semua tugas</button>
              <button v-for="c in lembaga.holiday_calendars" :key="c.jenis_tugas" type="button" :class="['chip', form.berlaku_untuk.includes(c.jenis_tugas) && 'pilih']" @click="balikBerlaku(c.jenis_tugas)">{{ c.nama }}</button>
            </div>
            <p class="mt-1 text-xs text-teks3">Hari libur ditulis ke kalender pondok, sehingga sesi presensi pada tanggal tersebut tidak dibuka bagi tugas yang diliburkan.</p></fieldset>
        </template>
        <div><label class="label-isian" for="ag-ket">Keterangan</label><textarea id="ag-ket" v-model="form.keterangan" class="isian min-h-[4.5rem] py-2" placeholder="Hal yang perlu disiapkan peserta" /></div>
        <div class="grid gap-3 sm:grid-cols-[1fr_12rem]">
          <div><label class="label-isian" for="ag-tautan">Tautan (Zoom, Google Meet, Maps, dll.)</label><input id="ag-tautan" v-model="form.tautan" class="isian" inputmode="url" placeholder="https://" /></div>
          <div><label class="label-isian" for="ag-ntautan">Nama tautan</label><input id="ag-ntautan" v-model="form.nama_tautan" class="isian" placeholder="Contoh: Zoom rapat" /></div>
        </div>
        <div>
          <p class="label-isian">Lampiran (opsional, PDF atau foto maks. 5 MB)</p>
          <div v-if="berkas || form.nama_lampiran" class="flex items-center gap-3 rounded-xl border border-garis p-3"><PhPaperclip :size="22" class="text-teks2" />
            <span class="min-w-0 flex-1 truncate text-sm font-semibold">{{ berkas ? berkas.name : form.nama_lampiran }}</span>
            <label class="tombol-teks cursor-pointer text-sm">Ganti<input type="file" accept="application/pdf,image/*" class="sr-only" @change="pilihBerkas" /></label>
            <button v-if="berkas" type="button" class="tombol-ikon" aria-label="Batalkan lampiran" @click="berkas = null"><PhX :size="20" /></button></div>
          <label v-else class="tombol-garis w-full cursor-pointer justify-center"><PhPaperclip :size="20" weight="duotone" /> Pilih berkas<input type="file" accept="application/pdf,image/*" class="sr-only" @change="pilihBerkas" /></label>
        </div>
        <fieldset><legend class="label-isian">Pengingat sebelum mulai{{ form.seharian || form.jenis === 'libur' ? ' (acuan pukul 06.00 WITA)' : '' }}</legend>
          <div class="flex flex-wrap gap-1.5">
            <button v-for="p in PENGINGAT" :key="p.m" type="button" :class="['chip', form.pengingat_menit.includes(p.m) && 'pilih']" :aria-pressed="form.pengingat_menit.includes(p.m)" @click="balikPengingat(p.m)">{{ p.n }}</button>
            <button v-for="m in form.pengingat_menit.filter((x) => !PENGINGAT.some((p) => p.m === x))" :key="m" type="button" class="chip pilih" @click="balikPengingat(m)">{{ labelMenit(m).replace(' sebelumnya', '') }} <PhX :size="12" /></button>
          </div>
          <div class="mt-2 flex items-center gap-2 text-sm"><span>Lainnya:</span><input v-model="lain.n" type="number" min="1" class="isian w-20" aria-label="Jumlah" />
            <select v-model.number="lain.s" class="isian w-28" aria-label="Satuan"><option :value="1">menit</option><option :value="60">jam</option><option :value="1440">hari</option></select>
            <button type="button" class="tombol-garis min-h-[40px] px-3 text-sm" @click="tambahPengingat">Tambah</button></div>
        </fieldset>
        <div v-if="!form.id"><p class="label-isian">Sasaran</p><PilihSasaran v-model="form.sasaran" :hitung="pg.hitungSasaran" @ringkasan="ringkas = $event" /></div>
        <p v-else class="text-sm text-teks3">Sasaran tidak dapat diubah. Bila tanggal diubah, penerima diberi tahu dan pengingat dijadwalkan ulang.</p>
        <button class="tombol-utama w-full" :disabled="simpanan">{{ simpanan ? 'Menyimpan…' : 'Simpan agenda' }}</button>
      </form>
    </LembarBawah>

    <!-- WA -->
    <LembarBawah :model-value="!!wa" @update:model-value="(v) => !v && (wa = null)" judul="Kirim undangan lewat WA">
      <div v-if="wa" class="pb-2">
        <p class="mb-2 text-sm text-teks2">{{ wa.a.judul }} · template "Undangan/pengingat agenda" (dapat diubah superadmin di Pengaturan → Template WA).</p>
        <ul class="divide-y divide-garis">
          <li v-for="p in wa.daftar" :key="p.employee_id" class="flex items-center gap-3 py-2.5">
            <div class="min-w-0 flex-1"><p class="font-semibold">{{ p.nama }}</p><p class="text-xs text-teks3">{{ p.unit || '–' }}{{ p.no_hp ? '' : ' · nomor HP belum diisi' }}</p></div>
            <a v-if="p.no_hp" :href="tautanWA(p.no_hp, pesan(wa.a, p))" target="_blank" rel="noopener" class="tombol-garis min-h-[40px] px-3 text-sm"><PhWhatsappLogo :size="18" weight="duotone" /> WA</a>
          </li>
        </ul>
      </div>
    </LembarBawah>

    <DokumenCetak v-model:pratinjau="pratinjau" judul="Agenda Pondok" :subjudul="`Bulan ${judulBulan}`" :pencetak="sesi.pengguna?.nama_lengkap">
      <table class="tabel">
        <colgroup><col style="width:6%"><col style="width:22%"><col style="width:15%"><col style="width:35%"><col style="width:22%"></colgroup>
        <thead><tr><th>No.</th><th>Hari, tanggal</th><th>Waktu</th><th>Agenda</th><th>Tempat/keterangan</th></tr></thead>
        <tbody><tr v-for="(a, i) in urut" :key="a.id">
          <td class="tengah">{{ i + 1 }}</td><td>{{ a.selesai > a.mulai ? `${formatPendek(a.mulai)} s.d. ${formatPendek(a.selesai)}` : formatHari(a.mulai) }}</td>
          <td>{{ a.sumber === 'libur' || a.jenis === 'libur' ? 'Libur' : waktu(a) }}</td><td>{{ a.judul }}</td><td>{{ a.lokasi || (a.sumber === 'libur' ? NAMA_LIBUR[a.jenis_libur] : '') || '–' }}</td></tr></tbody>
      </table>
      <template #ttd><TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: direktur.jabatan_tertulis || 'Direktur', nama: direktur.nama || '', niy: direktur.niy }" :kanan="{ jabatan: 'Pembuat', nama: sesi.pengguna?.nama_lengkap || '' }" /></template>
    </DokumenCetak>
  </div>
</template>
<style scoped>
.hari { border: 1px solid transparent; }
.hari:hover { background: rgb(var(--permukaan-2)); }
.hari.libur { background: color-mix(in srgb, #C7332F 8%, transparent); }
.hari.kini { border-color: var(--c); }
.hari.pilih { background: color-mix(in srgb, var(--c) 16%, rgb(var(--permukaan))); box-shadow: inset 0 0 0 2px var(--c); }
.jenis.aktif { border-color: transparent; color: rgb(var(--teks)); background: color-mix(in srgb, var(--c) 13%, rgb(var(--permukaan))); box-shadow: inset 0 0 0 2px var(--c); }
.chip { display: inline-flex; min-height: 36px; align-items: center; border-radius: 9999px; border: 1px solid rgb(var(--garis)); background: rgb(var(--permukaan)); padding: 0 .8rem; font-size: .8125rem; font-weight: 600; color: rgb(var(--teks-2)); }
.chip.pilih { border-color: transparent; color: rgb(var(--teks)); background: color-mix(in srgb, var(--c) 14%, rgb(var(--permukaan))); box-shadow: inset 0 0 0 1.5px var(--c); }
.kartu-ag { box-shadow: inset 4px 0 0 var(--c); }
</style>
