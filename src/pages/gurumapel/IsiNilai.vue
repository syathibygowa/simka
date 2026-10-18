<!-- SIMKA PRO | src/pages/gurumapel/IsiNilai.vue | v1.3 | 14.3.0: komponen Kehadiran otomatis dari absensi pelajaran | 17/10/2026 -->
<script setup>
// Lembar nilai satu kelas–mapel × semester (Guru Mapel → Nilai). Bagian:
//   Isian nilai : isian per komponen (Harian 1, Harian 2, Ulangan, UTS, UAS, …) yang ditambah guru sendiri; tampilan tabel
//                 (desktop) atau per isian (HP); saran nilai rapor dihitung langsung dari isian berbobot
//   Nilai rapor : saran akumulasi, nilai rapor (tunggal/rekomendasi: guru menetapkan, "Pakai semua saran"; akumulasi: otomatis),
//                 predikat, tuntas terhadap KKM/KKTP, keterampilan (Wustha; kosong = sama dengan pengetahuan), deskripsi
//                 otomatis yang dapat diganti per santri
//   Sikap       : diisi di akhir semester (A/B/C/K)
//   TP          : tujuan pembelajaran (rapor SMA: dipakai pada deskripsi capaian)
// v1.1: periode ditutup/batas pengisian lewat → guru pengampu mengajukan permintaan ubah nilai (AjukanUbahNilai).
// Perubahan disimpan dengan tombol Simpan; meninggalkan halaman dengan perubahan belum tersimpan meminta konfirmasi.
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter, onBeforeRouteLeave } from 'vue-router'
import { PhPlus, PhFloppyDisk, PhPencilSimple, PhTrash, PhTable, PhListBullets, PhLockSimple, PhLink, PhMagicWand, PhInfo, PhCheckCircle, PhWarningCircle, PhTarget, PhSmiley, PhCalculator, PhNotePencil } from '@phosphor-icons/vue'
import { useNilai } from '@/stores/nilai'
import { useUI } from '@/stores/ui'
import { MODE_NILAI, STATUS_PERIODE, ASPEK, predikatDari } from '@/lib/penilaian'
import { hitungAkumulasi, deskripsiOtomatis, LABEL_SEMESTER } from '@/lib/nilai'
import { useAmbang } from '@/stores/ambang'
import { JENJANG_PENDEK } from '@/lib/santri'
import { hariIniISO, formatPendek } from '@/lib/tanggal'
import BilahTab from '@/components/BilahTab.vue'
import LembarBawah from '@/components/LembarBawah.vue'
import InputTanggal from '@/components/InputTanggal.vue'
import AjukanUbahNilai from './AjukanUbahNilai.vue'
import { statusEfektif } from '@/lib/penilaian'

const route = useRoute(); const router = useRouter(); const nl = useNilai(); const ui = useUI()
const galat = ref(''); const proses = ref('')
const L = computed(() => nl.lembar)
const semester = computed(() => Number(route.query.smt) || 1)
async function muat() { galat.value = ''; try { await nl.muatLembar(route.params.id, semester.value); reset() } catch (e) { galat.value = e.message } }
onMounted(muat)

// ---------- Turunan ----------
const boleh = computed(() => !!L.value?.boleh_ubah)
const ket = computed(() => L.value?.ketentuan || {})
const kkm = computed(() => Number(L.value?.kkm ?? 0))
const kategori = computed(() => L.value?.kategori || [])
const kolom = computed(() => L.value?.kolom || [])
const santri = computed(() => L.value?.santri || [])
const akumulasi = computed(() => L.value?.mode === 'akumulasi')
const dua = computed(() => !!ket.value.pakai_keterampilan)
const aspekAda = computed(() => (dua.value ? ['pengetahuan', 'keterampilan'] : ['pengetahuan']))
const kolomAspek = (a) => kategori.value.filter((k) => k.aspek === a).flatMap((k) => kolom.value.filter((c) => c.category_id === k.id).map((c) => ({ ...c, kat: k })))
const namaKat = (id) => kategori.value.find((k) => k.id === id)?.nama || ''
// 14.3.0: komponen Kehadiran (sumber 'kehadiran') dihitung otomatis dari absensi guru mapel pada rentang semester
const kehadiran = computed(() => L.value?.kehadiran?.santri || {})
const katHadir = computed(() => kategori.value.filter((k) => k.sumber === 'kehadiran' && k.aktif))
const amb = useAmbang(); amb.muat()

// ---------- Salinan lokal ----------
const skor = ref(new Map()); const ubahSkor = ref(new Map())
const akhir = ref({}); const ubahAkhir = ref(new Set())
const tpTeks = ref(''); const tpUbah = ref(false)
function reset() {
  skor.value = new Map((L.value?.skor || []).map(([c, s, v]) => [`${c}|${s}`, Number(v)])); ubahSkor.value = new Map()
  akhir.value = Object.fromEntries(santri.value.map((s) => { const a = (L.value.akhir || []).find((x) => x.student_id === s.id) || {}
    return [s.id, { nilai: a.nilai ?? '', keterampilan: a.keterampilan ?? '', sikap: a.sikap || '', deskripsi: a.deskripsi || '', deskripsi_2: a.deskripsi_2 || '' }] }))
  ubahAkhir.value = new Set(); tpTeks.value = (L.value?.tp || []).map((t) => t.teks).join('\n'); tpUbah.value = false
}
const nilaiSel = (c, s) => (ubahSkor.value.has(`${c}|${s}`) ? ubahSkor.value.get(`${c}|${s}`) : skor.value.get(`${c}|${s}`) ?? '')
function isiSel(c, s, v) {
  const k = `${c}|${s}`; const lama = skor.value.get(k) ?? ''
  if (v !== '' && (Number(v) < 0 || Number(v) > 100 || Number.isNaN(Number(v)))) return ui.toast('Nilai harus 0–100.', 'galat')
  const m = new Map(ubahSkor.value); if (String(v) === String(lama)) m.delete(k); else m.set(k, v === '' ? '' : Number(v)); ubahSkor.value = m
}
const petaGabung = computed(() => { const m = new Map(skor.value); for (const [k, v] of ubahSkor.value) { if (v === '') m.delete(k); else m.set(k, v) } return m })
const saran = (s, aspek = 'pengetahuan') => hitungAkumulasi({ kategori: kategori.value, kolom: kolom.value, skor: petaGabung.value, santriId: s, aspek, desimal: ket.value.desimal || 0, kehadiran: kehadiran.value })
function setAkhir(s, f, v) { akhir.value[s][f] = v; ubahAkhir.value = new Set([...ubahAkhir.value, s]) }
const nilaiRapor = (s) => (akumulasi.value ? saran(s).nilai : akhir.value[s]?.nilai === '' ? null : Number(akhir.value[s]?.nilai))
const nilaiKet = (s) => { const v = akhir.value[s]?.keterampilan; return v === '' || v == null ? nilaiRapor(s) : Number(v) }
const pred = (n) => predikatDari(n, L.value?.predikat || [])
const tpList = computed(() => tpTeks.value.split('\n').map((x) => x.trim()).filter(Boolean))
const deskripsi = (s, k = false) => (k ? akhir.value[s]?.deskripsi_2 : akhir.value[s]?.deskripsi)
  || deskripsiOtomatis(k ? nilaiKet(s) : nilaiRapor(s), L.value?.predikat || [], { tp: tpList.value, pakaiTp: !!ket.value.pakai_tp && !k, keterampilan: k })
const kotor = computed(() => ubahSkor.value.size + ubahAkhir.value.size + (tpUbah.value ? 1 : 0))
onBeforeRouteLeave(async () => (kotor.value ? ui.konfirmasi({ judul: 'Tinggalkan lembar nilai?', pesan: `Ada ${kotor.value} perubahan yang belum disimpan.`, ya: 'Tinggalkan', bahaya: true }) : true))

// ---------- Tab ----------
const tab = ref('isian')
const TAB = computed(() => [
  { k: 'isian', n: 'Isian nilai', ikon: PhCalculator, w: 'gurumapel', jumlah: kolom.value.length },
  { k: 'rapor', n: 'Nilai rapor', ikon: PhCheckCircle, w: 'rapor', ket: `${santri.value.filter((s) => nilaiRapor(s.id) != null).length}/${santri.value.length}` },
  { k: 'sikap', n: 'Sikap', ikon: PhSmiley, w: 'presensi', ket: `${santri.value.filter((s) => akhir.value[s.id]?.sikap).length}/${santri.value.length}` },
  ...(ket.value.pakai_tp ? [{ k: 'tp', n: 'Tujuan pembelajaran', ikon: PhTarget, w: 'tahfizh', jumlah: tpList.value.length }] : []),
])

// ---------- Isian (kolom) ----------
const tampil = ref(typeof window !== 'undefined' && window.innerWidth < 768 ? 'per' : 'tabel')
const kolomPilih = ref('')
watch(kolom, (k) => { if (!k.some((c) => c.id === kolomPilih.value)) kolomPilih.value = k[0]?.id || '' }, { immediate: true })
const lembarKolom = ref(false); const fk = ref(null)
const kapital = (t) => t.charAt(0).toUpperCase() + t.slice(1)
function bukaKolom(kat, c = null) {
  if (c) { fk.value = { id: c.id, category_id: c.category_id, nama: c.nama, tanggal: c.tanggal || '' } }
  else { const n = kolom.value.filter((x) => x.category_id === kat.id).length; fk.value = { category_id: kat.id, nama: kat.berulang ? `${kapital(kat.nama.replace(/^Nilai\s+/i, ''))} ${n + 1}` : kat.nama, tanggal: hariIniISO() } }
  lembarKolom.value = true
}
async function simpanKolom() {
  if (!fk.value.nama.trim()) return ui.toast('Nama isian wajib diisi.', 'galat')
  proses.value = 'kolom'
  try { await nl.simpanKolom({ ...fk.value, nama: fk.value.nama.trim() }); const id = fk.value.id; lembarKolom.value = false; reset(); if (!id) kolomPilih.value = kolom.value[kolom.value.length - 1]?.id; ui.toast('Isian disimpan.') }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = '' }
}
async function hapusKolom() {
  if (!(await ui.konfirmasi({ judul: `Hapus isian ${fk.value.nama}?`, pesan: 'Semua nilai santri pada isian ini ikut terhapus.', ya: 'Hapus', bahaya: true }))) return
  try { await nl.hapusKolom(fk.value.id); lembarKolom.value = false; reset(); ui.toast('Isian dihapus.') } catch (e) { ui.toast(e.message, 'galat') }
}
const bolehTambah = (k) => k.sumber !== 'kehadiran' && k.aktif && (k.berulang || !kolom.value.some((c) => c.category_id === k.id))

// ---------- Simpan ----------
async function simpanSemua() {
  const isi = [...ubahAkhir.value].map((s) => { const a = akhir.value[s]; return { student_id: s, ...(akumulasi.value ? {} : { nilai: a.nilai === '' ? '' : Number(a.nilai) }),
    keterampilan: a.keterampilan === '' ? '' : Number(a.keterampilan), sikap: a.sikap, deskripsi: a.deskripsi, deskripsi_2: a.deskripsi_2 } })
  for (const x of isi) for (const f of ['nilai', 'keterampilan']) if (x[f] !== '' && x[f] != null && !(x[f] >= 0 && x[f] <= 100)) return ui.toast('Nilai harus 0–100.', 'galat')
  const per = {}
  for (const [k, v] of ubahSkor.value) { const [c, s] = k.split('|'); (per[c] ||= []).push({ student_id: s, nilai: v }) }
  proses.value = 'simpan'
  try {
    if (Object.keys(per).length) await nl.simpanSkor(per)
    if (isi.length) await nl.simpanAkhir(isi)
    reset(); ui.toast('Nilai disimpan.')
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = '' }
}
function pakaiSaran(semua) {
  let n = 0
  for (const s of santri.value) { const v = saran(s.id).nilai; if (v == null) continue; if (!semua && akhir.value[s.id].nilai !== '') continue; if (Number(akhir.value[s.id].nilai) !== v) { setAkhir(s.id, 'nilai', v); n++ } }
  ui.toast(n ? `${n} nilai rapor diisi dari saran. Tekan Simpan.` : 'Tidak ada nilai yang berubah.')
}
function sikapSemua(h) { for (const s of santri.value) if (!akhir.value[s.id].sikap) setAkhir(s.id, 'sikap', h) }
async function simpanTP() {
  if (tpList.value.length > 20) return ui.toast('Paling banyak 20 tujuan pembelajaran.', 'galat')
  proses.value = 'tp'
  try { await nl.simpanTP(tpList.value); reset(); ui.toast('Tujuan pembelajaran disimpan.') } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = '' }
}

// ---------- Deskripsi khusus ----------
const lembarDes = ref(false); const fd = ref(null)
function bukaDes(s) { fd.value = { s, nama: s.nama, d1: akhir.value[s.id].deskripsi, d2: akhir.value[s.id].deskripsi_2 }; lembarDes.value = true }
function terapDes() { setAkhir(fd.value.s.id, 'deskripsi', fd.value.d1.trim()); if (dua.value) setAkhir(fd.value.s.id, 'deskripsi_2', fd.value.d2.trim()); lembarDes.value = false }
const ringkasSaran = computed(() => { const v = santri.value.map((s) => saran(s.id)); return { ada: v.filter((x) => x.nilai != null).length, lengkap: v.filter((x) => x.lengkap).length } })
</script>
<template>
  <div class="w-gurumapel pb-24">
    <div v-if="galat" class="kartu w-klinik flex flex-wrap items-center gap-3 p-5">
      <p class="min-w-[200px] flex-1 text-sm font-semibold" style="color: var(--c)">{{ galat }}</p>
      <button class="tombol-garis" @click="router.push('/guru-mapel/nilai')">Kembali</button>
    </div>
    <template v-else-if="L">
      <section class="kartu kepala mb-4 p-4 sm:p-5">
        <div class="flex flex-wrap items-start gap-3">
          <div class="min-w-0 flex-1 basis-[60%]">
            <h2 class="text-lg font-bold">{{ L.tugas.mapel }} · Kelas {{ L.tugas.kelas }}</h2>
            <p class="text-sm text-teks2">{{ JENJANG_PENDEK[L.tugas.jenjang] }} · {{ LABEL_SEMESTER[L.semester] }} · {{ L.tugas.guru }}</p>
            <div class="mt-2 flex flex-wrap gap-1.5">
              <span :class="['lencana', 'w-' + STATUS_PERIODE[statusEfektif(L.periode)].w]">Periode {{ STATUS_PERIODE[statusEfektif(L.periode)].n.toLowerCase() }}</span>
              <span class="lencana w-rapor">{{ MODE_NILAI[L.mode].n }}</span>
              <span class="lencana w-pengajuan">{{ ket.label_ambang }} {{ kkm }}</span>
              <span v-for="r in L.mapel_rapor" :key="r.id" class="lencana w-penilaian"><PhLink :size="12" /> rapor: {{ r.nama }}</span>
              <span v-if="!L.mapel_rapor.length" class="lencana w-klinik">Belum dipakai di mapel rapor mana pun</span>
            </div>
          </div>
          <div class="bilah-tab kecil" role="tablist" aria-label="Semester">
            <button v-for="s in [1, 2]" :key="s" type="button" role="tab" :aria-selected="L.semester === s" :class="['tab-garis', L.semester === s && 'aktif']"
              @click="router.replace({ query: { smt: s } }).then(muat)">Smt {{ s }}</button>
          </div>
        </div>
        <p v-if="!boleh" class="mt-3 flex items-start gap-2 rounded-xl bg-permukaan2 p-3 text-sm text-teks2"><PhLockSimple :size="18" class="mt-0.5 shrink-0" /><span>Baca saja. {{ L.alasan }}</span></p>
        <AjukanUbahNilai v-if="!boleh && L.tugas?.milik_saya && statusEfektif(L.periode) === 'ditutup'" :key="'un' + semester" :L="L" :semester="semester" />
        <p v-else-if="!L.tugas.milik_saya" class="mt-3 flex items-start gap-2 rounded-xl bg-permukaan2 p-3 text-sm text-teks2"><PhInfo :size="18" class="mt-0.5 shrink-0" /><span>Anda mengisi atas nama guru pengampu sebagai pengelola nilai.</span></p>
      </section>

      <BilahTab v-model="tab" class="mb-4" :tab="TAB" label="Bagian lembar nilai" />

      <!-- ================= ISIAN NILAI ================= -->
      <template v-if="tab === 'isian'">
        <section class="kartu mb-4 p-4">
          <div v-for="a in aspekAda" :key="a" class="mb-2">
            <p v-if="dua" class="mb-1 text-xs font-bold uppercase text-teks3">{{ ASPEK[a] }}</p>
            <div class="flex flex-wrap gap-2">
              <div v-for="k in kategori.filter((x) => x.aspek === a)" :key="k.id" :class="['rounded-xl border border-garis p-2', !k.aktif && 'opacity-60']">
                <p class="mb-1 flex items-center gap-2 text-xs font-bold text-teks2">{{ k.nama }} <span class="font-normal text-teks3">{{ Number(k.bobot) }}%</span></p>
                <div class="flex flex-wrap gap-1">
                  <button v-for="c in kolom.filter((x) => x.category_id === k.id)" :key="c.id" type="button" :class="['flex min-h-[34px] items-center gap-1 rounded-lg border px-2 text-xs font-semibold', kolomPilih === c.id && tampil === 'per' ? 'border-[color:var(--c)] bg-permukaan2' : 'border-garis']"
                    @click="kolomPilih = c.id; tampil = 'per'">{{ c.nama }}<PhPencilSimple v-if="boleh" :size="12" class="text-teks3" @click.stop="bukaKolom(k, c)" /></button>
                  <span v-if="k.sumber === 'kehadiran'" class="text-xs text-teks3">Otomatis dari absensi pelajaran{{ L.kehadiran ? ` (${formatPendek(L.kehadiran.mulai)} – ${formatPendek(L.kehadiran.selesai)})` : '' }}</span>
                  <button v-if="boleh && bolehTambah(k)" type="button" class="flex min-h-[34px] items-center gap-1 rounded-lg border border-dashed border-garis px-2 text-xs font-semibold text-teks2" @click="bukaKolom(k)"><PhPlus :size="12" weight="bold" /> Isian</button>
                </div>
              </div>
            </div>
          </div>
          <p class="mt-2 text-xs text-teks3">Tambah isian sendiri pada setiap komponen (mis. Harian 1, Harian 2). Nilai komponen = rata-rata isiannya; saran nilai rapor = jumlah rata-rata komponen × bobot (bobot dibagi ulang di antara komponen yang sudah berisi).</p>
        </section>

        <div v-if="kolom.length" class="mb-3 flex flex-wrap items-center gap-2">
          <div class="bilah-tab kecil" role="tablist" aria-label="Tampilan">
            <button v-for="t in [{ k: 'tabel', n: 'Tabel', i: PhTable }, { k: 'per', n: 'Per isian', i: PhListBullets }]" :key="t.k" type="button" role="tab" :aria-selected="tampil === t.k" @click="tampil = t.k"
              :class="['tab-garis', tampil === t.k && 'aktif']"><component :is="t.i" :size="16" /> {{ t.n }}</button>
          </div>
          <p class="text-xs text-teks3">Saran tersedia {{ ringkasSaran.ada }}/{{ santri.length }} santri · lengkap semua komponen {{ ringkasSaran.lengkap }}</p>
        </div>
        <p v-if="!kolom.length" class="kartu p-6 text-center text-sm text-teks3">Belum ada isian nilai. {{ boleh ? 'Tekan "+ Isian" pada komponen di atas.' : '' }}</p>

        <!-- Tabel -->
        <div v-else-if="tampil === 'tabel'" class="kartu overflow-auto">
          <table class="w-full min-w-[640px] text-sm">
            <thead class="sticky top-0 z-10 bg-permukaan2 text-xs text-teks2">
              <tr><th class="sticky left-0 z-20 bg-permukaan2 px-2 py-2 text-left">NIS</th><th class="px-2 text-left">Nama</th>
                <th v-for="c in aspekAda.flatMap(kolomAspek)" :key="c.id" class="px-1 text-center" :title="`${c.kat.nama}${c.tanggal ? ' · ' + formatPendek(c.tanggal) : ''}`">{{ c.nama }}</th>
                <th v-if="katHadir.length" class="px-2 text-center" title="Persentase kehadiran pelajaran (otomatis)">Hadir</th>
                <th class="px-2 text-center">Saran</th><th v-if="dua" class="px-2 text-center">Saran ket.</th></tr></thead>
            <tbody class="divide-y divide-garis">
              <tr v-for="s in santri" :key="s.id" :class="!s.aktif && 'opacity-60'">
                <td class="sticky left-0 bg-permukaan px-2 py-1 tabular-nums text-teks2">{{ s.nis }}</td>
                <td class="max-w-[220px] truncate px-2 font-semibold">{{ s.nama }}</td>
                <td v-for="c in aspekAda.flatMap(kolomAspek)" :key="c.id" class="px-1 py-1">
                  <input :value="nilaiSel(c.id, s.id)" type="number" min="0" max="100" inputmode="decimal" :disabled="!boleh"
                    :class="['h-9 w-16 rounded-lg border bg-permukaan px-1 text-center tabular-nums', ubahSkor.has(`${c.id}|${s.id}`) ? 'border-[color:var(--c)] bg-permukaan2' : 'border-garis']"
                    :aria-label="`${c.nama} ${s.nama}`" @change="isiSel(c.id, s.id, $event.target.value)" /></td>
                <td v-if="katHadir.length" :class="['px-2 text-center tabular-nums', amb.bawah(kehadiran[s.id]?.persen) && 'persen-ambang']"
                  :title="kehadiran[s.id] ? `Hadir ${kehadiran[s.id].h}/${kehadiran[s.id].p} pertemuan` : 'Belum ada absensi pelajaran'">{{ kehadiran[s.id]?.p ? kehadiran[s.id].persen : '–' }}</td>
                <td class="px-2 text-center font-bold tabular-nums">{{ saran(s.id).nilai ?? '–' }}</td>
                <td v-if="dua" class="px-2 text-center font-bold tabular-nums">{{ saran(s.id, 'keterampilan').nilai ?? '–' }}</td>
              </tr>
            </tbody>
          </table>
        </div>

        <!-- Per isian -->
        <div v-else class="kartu p-3">
          <select v-model="kolomPilih" class="isian mb-3" aria-label="Pilih isian"><option v-for="c in kolom" :key="c.id" :value="c.id">{{ namaKat(c.category_id) }} – {{ c.nama }}{{ c.tanggal ? ` (${formatPendek(c.tanggal)})` : '' }}</option></select>
          <ul class="divide-y divide-garis">
            <li v-for="(s, i) in santri" :key="s.id" class="flex items-center gap-3 py-2">
              <span class="w-6 text-right text-xs text-teks3 tabular-nums">{{ i + 1 }}</span>
              <div class="min-w-0 flex-1"><p class="truncate text-sm font-semibold">{{ s.nama }}</p><p class="text-xs text-teks3">{{ s.nis }} · saran {{ saran(s.id).nilai ?? '–' }}<template v-if="katHadir.length"> · hadir <span :class="amb.bawah(kehadiran[s.id]?.persen) && 'persen-ambang'">{{ kehadiran[s.id]?.p ? kehadiran[s.id].persen + '%' : '–' }}</span></template></p></div>
              <input :value="nilaiSel(kolomPilih, s.id)" type="number" min="0" max="100" inputmode="decimal" :disabled="!boleh"
                :class="['h-11 w-20 rounded-xl border bg-permukaan text-center text-base tabular-nums', ubahSkor.has(`${kolomPilih}|${s.id}`) ? 'border-[color:var(--c)] bg-permukaan2' : 'border-garis']"
                :aria-label="`Nilai ${s.nama}`" @change="isiSel(kolomPilih, s.id, $event.target.value)" />
            </li>
          </ul>
        </div>
      </template>

      <!-- ================= NILAI RAPOR ================= -->
      <template v-else-if="tab === 'rapor'">
        <section class="kartu mb-3 flex flex-wrap items-center gap-2 p-3 text-sm">
          <p class="min-w-[220px] flex-1 text-teks2">{{ MODE_NILAI[L.mode].ket }}</p>
          <template v-if="boleh && !akumulasi">
            <button class="tombol-garis min-h-[38px] px-3 text-sm" @click="pakaiSaran(false)"><PhMagicWand :size="16" weight="duotone" /> Isi yang kosong dari saran</button>
            <button class="tombol-garis min-h-[38px] px-3 text-sm" @click="pakaiSaran(true)">Pakai semua saran</button>
          </template>
        </section>
        <div class="kartu overflow-auto">
          <table class="w-full min-w-[720px] text-sm">
            <thead class="bg-permukaan2 text-xs text-teks2"><tr><th class="px-2 py-2 text-left">NIS</th><th class="px-2 text-left">Nama</th><th class="px-2">Saran</th>
              <th class="px-2">{{ dua ? 'Pengetahuan' : 'Nilai rapor' }}</th><th v-if="dua" class="px-2">Keterampilan</th><th class="px-2">Pred.</th><th class="px-2 text-left">Deskripsi</th></tr></thead>
            <tbody class="divide-y divide-garis">
              <tr v-for="s in santri" :key="s.id" class="align-top">
                <td class="px-2 py-2 tabular-nums text-teks2">{{ s.nis }}</td>
                <td class="max-w-[200px] px-2 py-2 font-semibold">{{ s.nama }}</td>
                <td class="px-2 py-2 text-center tabular-nums">{{ saran(s.id).nilai ?? '–' }}<span v-if="saran(s.id).nilai != null && !saran(s.id).lengkap" class="block text-[10px] text-teks3">belum lengkap</span></td>
                <td class="px-2 py-1 text-center">
                  <span v-if="akumulasi" class="font-bold tabular-nums">{{ nilaiRapor(s.id) ?? '–' }}</span>
                  <input v-else :value="akhir[s.id].nilai" type="number" min="0" max="100" :disabled="!boleh" :aria-label="`Nilai rapor ${s.nama}`"
                    :class="['h-9 w-16 rounded-lg border bg-permukaan text-center font-bold tabular-nums', ubahAkhir.has(s.id) ? 'border-[color:var(--c)] bg-permukaan2' : 'border-garis']"
                    @change="setAkhir(s.id, 'nilai', $event.target.value === '' ? '' : Number($event.target.value))" />
                  <span v-if="nilaiRapor(s.id) != null" :class="['mt-0.5 block text-[11px] font-semibold', nilaiRapor(s.id) >= kkm ? 'text-[#1E7D4F] dark:text-[#5BD69A]' : 'text-merah']">{{ nilaiRapor(s.id) >= kkm ? 'Tuntas' : 'Belum tuntas' }}</span>
                </td>
                <td v-if="dua" class="px-2 py-1 text-center">
                  <input :value="akhir[s.id].keterampilan" type="number" min="0" max="100" :disabled="!boleh" :placeholder="nilaiRapor(s.id) ?? ''" :aria-label="`Keterampilan ${s.nama}`"
                    :class="['h-9 w-16 rounded-lg border bg-permukaan text-center tabular-nums placeholder:text-teks3', ubahAkhir.has(s.id) ? 'border-[color:var(--c)]' : 'border-garis']"
                    @change="setAkhir(s.id, 'keterampilan', $event.target.value === '' ? '' : Number($event.target.value))" />
                  <span v-if="akhir[s.id].keterampilan === ''" class="block text-[10px] text-teks3">= pengetahuan</span></td>
                <td class="px-2 py-2 text-center font-bold">{{ pred(nilaiRapor(s.id))?.huruf || '–' }}</td>
                <td class="min-w-[220px] px-2 py-2 text-xs text-teks2">
                  <p>{{ deskripsi(s.id) || '–' }}</p><p v-if="dua" class="mt-1 border-t border-garis pt-1">{{ deskripsi(s.id, true) || '–' }}</p>
                  <button v-if="boleh" type="button" class="mt-1 flex items-center gap-1 text-[11px] font-semibold" style="color: var(--c)" @click="bukaDes(s)">
                    <PhNotePencil :size="12" /> {{ akhir[s.id].deskripsi || akhir[s.id].deskripsi_2 ? 'Deskripsi khusus' : 'Ubah deskripsi' }}</button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
        <p class="mt-2 text-xs text-teks3">Predikat dan deskripsi otomatis mengikuti tabel predikat {{ JENJANG_PENDEK[L.tugas.jenjang] }}{{ ket.pakai_tp ? ' dan daftar tujuan pembelajaran' : '' }}. {{ dua ? 'Keterampilan kosong berarti sama dengan nilai pengetahuan.' : '' }}</p>
      </template>

      <!-- ================= SIKAP ================= -->
      <template v-else-if="tab === 'sikap'">
        <section class="kartu mb-3 flex flex-wrap items-center gap-2 p-3 text-sm">
          <p class="min-w-[220px] flex-1 text-teks2">Diisi di akhir semester. {{ ket.sikap_di_rapor ? 'Dicetak di rapor per mapel.' : 'Tidak dicetak di rapor; tampil di leger.' }}</p>
          <template v-if="boleh"><span class="text-xs text-teks3">Isi yang kosong:</span>
            <button v-for="p in L.sikap_pilihan" :key="p.huruf" class="tombol-garis min-h-[36px] px-3 text-sm" @click="sikapSemua(p.huruf)">{{ p.huruf }}</button></template>
        </section>
        <ul class="kartu divide-y divide-garis">
          <li v-for="(s, i) in santri" :key="s.id" class="flex flex-wrap items-center gap-3 px-4 py-2">
            <span class="w-6 text-right text-xs text-teks3 tabular-nums">{{ i + 1 }}</span>
            <div class="min-w-0 flex-1"><p class="truncate text-sm font-semibold">{{ s.nama }}</p><p class="text-xs text-teks3">{{ s.nis }}</p></div>
            <div class="flex gap-1" role="radiogroup" :aria-label="`Sikap ${s.nama}`">
              <button v-for="p in L.sikap_pilihan" :key="p.huruf" type="button" role="radio" :aria-checked="akhir[s.id].sikap === p.huruf" :disabled="!boleh" :title="p.sebutan"
                :class="['h-10 w-10 rounded-xl border text-sm font-bold', akhir[s.id].sikap === p.huruf ? 'border-transparent text-white' : 'border-garis text-teks2']"
                :style="akhir[s.id].sikap === p.huruf ? { background: 'var(--c)' } : {}" @click="setAkhir(s.id, 'sikap', akhir[s.id].sikap === p.huruf ? '' : p.huruf)">{{ p.huruf }}</button>
            </div>
          </li>
        </ul>
        <p class="mt-2 text-xs text-teks3">{{ L.sikap_pilihan.map((p) => `${p.huruf} = ${p.sebutan}`).join(' · ') }}</p>
      </template>

      <!-- ================= TP ================= -->
      <template v-else-if="tab === 'tp'">
        <section class="kartu p-4">
          <label class="label-isian" for="tp-isi">Tujuan pembelajaran semester ini (satu per baris)</label>
          <textarea id="tp-isi" v-model="tpTeks" rows="8" class="isian" :disabled="!boleh" placeholder="Contoh:&#10;Demokrasi&#10;Hak dan kewajiban warga negara" @input="tpUbah = true" />
          <p class="mt-1 text-xs text-teks3">Dipakai pada deskripsi capaian rapor SMA, mis. "{{ (L.predikat[L.predikat.length - 1]?.deskripsi) || 'Perlu bimbingan…' }} {{ tpList.slice(0, 3).join(', ') || 'Demokrasi' }}". Paling banyak 20.</p>
          <button v-if="boleh" class="tombol-utama mt-3 w-full" :disabled="!!proses || !tpUbah" @click="simpanTP"><PhFloppyDisk :size="20" weight="duotone" /> {{ proses === 'tp' ? 'Menyimpan…' : 'Simpan tujuan pembelajaran' }}</button>
        </section>
      </template>

      <!-- Bilah simpan -->
      <div v-if="boleh && tab !== 'tp' && kotor" class="fixed inset-x-0 bottom-[76px] z-30 flex justify-center px-4 lg:bottom-6 lg:pl-[280px]">
        <div class="kartu flex w-full max-w-xl items-center gap-3 p-3 shadow-xl">
          <PhWarningCircle :size="20" class="shrink-0" style="color: var(--c)" />
          <p class="flex-1 text-sm font-semibold">{{ kotor }} perubahan belum disimpan</p>
          <button class="tombol-garis min-h-[40px] px-3 text-sm" :disabled="!!proses" @click="reset">Batal</button>
          <button class="tombol-utama min-h-[40px] px-4 text-sm" :disabled="!!proses" @click="simpanSemua">
            <PhFloppyDisk :size="18" weight="duotone" /> {{ proses ? 'Menyimpan…' : 'Simpan' }}</button>
        </div>
      </div>
    </template>
    <p v-else class="kartu p-8 text-center text-sm text-teks3">Memuat lembar nilai…</p>

    <LembarBawah v-model="lembarKolom" :judul="fk?.id ? 'Ubah isian' : `Isian baru · ${namaKat(fk?.category_id)}`">
      <form v-if="fk" class="space-y-3 pb-2" novalidate @submit.prevent="simpanKolom">
        <div><label class="label-isian" for="k-nama">Nama isian</label><input id="k-nama" v-model="fk.nama" class="isian" maxlength="40" placeholder="Contoh: Harian 1, Kuis Bab 2" /></div>
        <InputTanggal v-model="fk.tanggal" label="Tanggal penilaian" bawaan-kosong />
        <div class="flex gap-2">
          <button v-if="fk.id" type="button" class="tombol-garis" @click="hapusKolom"><PhTrash :size="18" /> Hapus</button>
          <button class="tombol-utama flex-1" :disabled="!!proses"><PhFloppyDisk :size="20" weight="duotone" /> {{ proses === 'kolom' ? 'Menyimpan…' : 'Simpan isian' }}</button>
        </div>
      </form>
    </LembarBawah>

    <LembarBawah v-model="lembarDes" :judul="fd ? `Deskripsi · ${fd.nama}` : ''">
      <div v-if="fd" class="space-y-3 pb-2">
        <div><label class="label-isian" for="d-1">Deskripsi {{ dua ? 'pengetahuan' : 'capaian' }}</label>
          <textarea id="d-1" v-model="fd.d1" rows="3" class="isian" :placeholder="deskripsiOtomatis(nilaiRapor(fd.s.id), L.predikat, { tp: tpList, pakaiTp: !!ket.pakai_tp })" /></div>
        <div v-if="dua"><label class="label-isian" for="d-2">Deskripsi keterampilan</label>
          <textarea id="d-2" v-model="fd.d2" rows="3" class="isian" :placeholder="deskripsiOtomatis(nilaiKet(fd.s.id), L.predikat, { keterampilan: true })" /></div>
        <p class="text-xs text-teks3">Kosongkan untuk memakai deskripsi otomatis (ditampilkan samar).</p>
        <button class="tombol-utama w-full" @click="terapDes">Terapkan</button>
      </div>
    </LembarBawah>
  </div>
</template>
<style scoped>
.kepala { background: linear-gradient(135deg, color-mix(in srgb, var(--c) 12%, rgb(var(--permukaan))), rgb(var(--permukaan)) 70%); }
</style>
