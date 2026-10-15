<!-- SIMKA PRO | src/pages/penilaian/TabKalimatRapor.vue | v1.2 | Perbaikan 13.6.0: sub-tab bergaris bawah | 15/10/2026 -->
<script setup>
// Bank kalimat rapor: catatan wali kelas dan catatan muhaffizh disusun otomatis dari pembuka + apresiasi kelebihan santri
// (dipicu data: mapel nilai tertinggi, kehadiran, hafalan, UTAS, pengembangan diri, sikap) + dorongan + penutup,
// sehingga setiap santri mendapat catatan yang berbeda (tetap dapat disunting wali kelas). Catatan kehadiran dipilih
// menurut persentase kehadiran. Istilah Arab ditulis Latin dengan _miring_.
import { ref, computed } from 'vue'
import { PhPlus, PhPencilSimple, PhTrash, PhFloppyDisk, PhInfo, PhEyeSlash } from '@phosphor-icons/vue'
import { usePenilaian } from '@/stores/penilaian'
import { useUI } from '@/stores/ui'
import { KATEGORI_KALIMAT, BAGIAN_KALIMAT, KUNCI_KALIMAT, ISIAN_KALIMAT, JENIS_RAPOR } from '@/lib/penilaian'
import { teksKaya } from '@/lib/teksKaya'
import LembarBawah from '@/components/LembarBawah.vue'

const pn = usePenilaian(); const ui = useUI(); const proses = ref(false)
const kat = ref('catatan_wali')
const ambang = computed(() => KATEGORI_KALIMAT[kat.value].bagian.includes('ambang'))
const jenisKehadiran = ref('wustha')
const boleh = computed(() => !pn.terkunci && (pn.hak.atur_umum || (kat.value === 'catatan_muhaffizh' || kat.value === 'kehadiran_halaqah' ? pn.bolehAtur('tahfizh')
  : kat.value === 'kehadiran' ? pn.bolehAtur(jenisKehadiran.value) : pn.bolehAtur('sma') || pn.bolehAtur('wustha'))))
const daftar = computed(() => pn.kalimat.filter((k) => k.kategori === kat.value && (kat.value !== 'kehadiran' || k.jenis === jenisKehadiran.value)))
const kunciLabel = (k) => KUNCI_KALIMAT[kat.value]?.[k.bagian]?.[k.kunci] || k.kunci
const kelompok = computed(() => KATEGORI_KALIMAT[kat.value].bagian.map((b) => {
  const item = daftar.value.filter((k) => k.bagian === b)
  const sub = KUNCI_KALIMAT[kat.value]?.[b]
  return { b, item: sub ? Object.keys(sub).flatMap((kc) => item.filter((k) => k.kunci === kc)).concat(item.filter((k) => !sub[k.kunci])) : item.sort((x, y) => Number(y.min_nilai ?? 0) - Number(x.min_nilai ?? 0) || x.urutan - y.urutan) }
}))
const jumlahKat = (k) => pn.kalimat.filter((x) => x.kategori === k && x.aktif).length

const lembar = ref(false); const f = ref(null)
function buka(k = null, bagian = null) {
  f.value = k ? { ...k, min_nilai: k.min_nilai ?? '' } : { kategori: kat.value, jenis: kat.value === 'kehadiran' ? jenisKehadiran.value : kat.value === 'catatan_wali' ? null : 'tahfizh',
    bagian: bagian || KATEGORI_KALIMAT[kat.value].bagian[0], kunci: '', min_nilai: '', teks: '', aktif: true }
  lembar.value = true
}
const pilihanKunci = computed(() => KUNCI_KALIMAT[f.value?.kategori]?.[f.value?.bagian] || null)
function sisip(x) { f.value.teks = `${f.value.teks || ''}${f.value.teks && !/\s$/.test(f.value.teks) ? ' ' : ''}${x}` }
async function simpan() {
  const d = f.value
  if (String(d.teks).trim().length < 5) return ui.toast('Teks kalimat terlalu pendek.', 'galat')
  if (pilihanKunci.value && !d.kunci) return ui.toast('Pilih pemicu kalimat ini.', 'galat')
  if (d.bagian === 'ambang' && !(Number(d.min_nilai) >= 0 && Number(d.min_nilai) <= 100 && d.min_nilai !== '')) return ui.toast('Isi persentase kehadiran minimal (0–100).', 'galat')
  proses.value = true
  try { await pn.simpanKalimat({ ...d, teks: d.teks.trim(), min_nilai: d.bagian === 'ambang' ? Number(d.min_nilai) : '' }); lembar.value = false; ui.toast('Kalimat disimpan.') }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
async function hapus(k) {
  if (!(await ui.konfirmasi({ judul: 'Hapus kalimat?', pesan: 'Kalimat ini tidak dipakai lagi saat catatan disusun. Untuk sementara, cukup nonaktifkan.', ya: 'Hapus', bahaya: true }))) return
  try { await pn.hapusKalimat(k.id); ui.toast('Kalimat dihapus.') } catch (e) { ui.toast(e.message, 'galat') }
}
async function alihAktif(k) { try { await pn.simpanKalimat({ id: k.id, teks: k.teks, aktif: !k.aktif }) } catch (e) { ui.toast(e.message, 'galat') } }
</script>
<template>
  <div class="space-y-4">
    <div class="bilah-tab kecil" role="tablist" aria-label="Jenis catatan">
      <button v-for="(k, kode) in KATEGORI_KALIMAT" :key="kode" type="button" role="tab" :aria-selected="kat === kode" @click="kat = kode"
        :class="['tab-garis', kat === kode && 'aktif']">
        <span>{{ k.n }}</span> <span class="angka-tab">{{ jumlahKat(kode) }}</span></button>
    </div>
    <p class="flex gap-2 rounded-2xl bg-permukaan2 p-3 text-sm text-teks2"><PhInfo :size="18" class="mt-0.5 shrink-0" />
      <span v-if="ambang">Kalimat dipilih menurut <b>persentase kehadiran</b>: yang dipakai adalah ambang tertinggi yang dicapai santri.</span>
      <span v-else>Catatan disusun otomatis per santri: satu <b>pembuka</b>, satu–dua <b>apresiasi kelebihan</b> yang benar-benar dicapai santri, satu <b>dorongan</b>, dan satu <b>penutup</b>, dipilih acak di antara kalimat yang cocok sehingga catatan santri berbeda-beda. Wali kelas dapat menyusun ulang atau menyunting.</span></p>
    <div v-if="kat === 'kehadiran'" class="bilah-tab kecil" role="tablist" aria-label="Rapor">
      <button v-for="j in ['wustha', 'sma']" :key="j" type="button" role="tab" :aria-selected="jenisKehadiran === j" @click="jenisKehadiran = j"
        :class="['tab-garis', jenisKehadiran === j && 'aktif']">{{ JENIS_RAPOR[j].n }}</button>
    </div>

    <section v-for="g in kelompok" :key="g.b" :class="['kartu p-4', 'w-' + KATEGORI_KALIMAT[kat].w]">
      <div class="mb-2 flex items-center gap-2"><p class="flex-1 font-bold" style="color: var(--c)">{{ BAGIAN_KALIMAT[g.b] }}</p>
        <button v-if="boleh" class="tombol-garis min-h-[36px] px-3 text-sm" @click="buka(null, g.b)"><PhPlus :size="16" weight="bold" /> Kalimat</button></div>
      <ul class="divide-y divide-garis">
        <li v-for="k in g.item" :key="k.id" :class="['flex items-start gap-2 py-2', !k.aktif && 'opacity-55']">
          <div class="min-w-0 flex-1">
            <p class="flex flex-wrap gap-1"><span v-if="k.kunci" class="lencana">{{ kunciLabel(k) }}</span><span v-if="g.b === 'ambang'" class="lencana">≥ {{ Number(k.min_nilai) }}%</span>
              <span v-if="!k.aktif" class="lencana w-hakakses"><PhEyeSlash :size="12" /> nonaktif</span></p>
            <p class="mt-0.5 text-sm" v-html="teksKaya(k.teks)" />
          </div>
          <template v-if="boleh">
            <button class="tombol-garis min-h-[32px] px-2 text-xs" @click="alihAktif(k)">{{ k.aktif ? 'Nonaktifkan' : 'Aktifkan' }}</button>
            <button class="tombol-ikon h-9 w-9" aria-label="Ubah kalimat" @click="buka(k)"><PhPencilSimple :size="16" /></button>
            <button class="tombol-ikon h-9 w-9" aria-label="Hapus kalimat" @click="hapus(k)"><PhTrash :size="16" /></button>
          </template>
        </li>
        <li v-if="!g.item.length" class="py-3 text-sm text-teks3">Belum ada kalimat.</li>
      </ul>
    </section>

    <LembarBawah v-model="lembar" :judul="f?.id ? 'Ubah kalimat' : `Kalimat baru · ${BAGIAN_KALIMAT[f?.bagian] || ''}`">
      <form v-if="f" class="space-y-3 pb-2" novalidate @submit.prevent="simpan">
        <div v-if="!ambang"><label class="label-isian" for="kl-bag">Bagian</label>
          <select id="kl-bag" v-model="f.bagian" class="isian" @change="f.kunci = ''"><option v-for="b in KATEGORI_KALIMAT[f.kategori].bagian" :key="b" :value="b">{{ BAGIAN_KALIMAT[b] }}</option></select></div>
        <div v-if="pilihanKunci"><label class="label-isian" for="kl-kunci">Dipakai bila</label>
          <select id="kl-kunci" v-model="f.kunci" class="isian"><option value="">Pilih pemicu…</option><option v-for="(n, k) in pilihanKunci" :key="k" :value="k">{{ n }}</option></select></div>
        <div v-if="ambang"><label class="label-isian" for="kl-min">Berlaku bila kehadiran sekurang-kurangnya (%)</label>
          <input id="kl-min" v-model="f.min_nilai" type="number" min="0" max="100" class="isian tabular-nums" /></div>
        <div><label class="label-isian" for="kl-teks">Teks</label><textarea id="kl-teks" v-model="f.teks" rows="3" class="isian" /></div>
        <div v-if="!ambang"><p class="label-isian">Sisipkan isian otomatis</p>
          <div class="flex flex-wrap gap-1.5"><button v-for="x in ISIAN_KALIMAT" :key="x" type="button" class="rounded-lg border border-garis px-2 py-1 text-xs font-semibold text-teks2 hover:bg-permukaan2" @click="sisip(x)">{{ x }}</button></div>
          <p class="mt-1 text-xs text-teks3">Tulis istilah Arab dengan huruf Latin di antara garis bawah agar dicetak miring, mis. _Barakallahu fiik_.</p></div>
        <div v-if="f.teks" class="rounded-xl bg-permukaan2 p-3 text-sm"><p class="text-xs text-teks3">Pratinjau</p><p v-html="teksKaya(f.teks)" /></div>
        <button class="tombol-utama w-full" :disabled="proses"><PhFloppyDisk :size="20" weight="duotone" /> {{ proses ? 'Menyimpan…' : 'Simpan kalimat' }}</button>
      </form>
    </LembarBawah>
  </div>
</template>
