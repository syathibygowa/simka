<!-- SIMKA PRO | src/pages/walikelas/TabRaporKelas.vue | v1.3 | Perbaikan 13.6.0: sub-tab bergaris bawah | 15/10/2026 -->
<script setup>
// Wali Kelas → Rapor: isian wali kelas untuk rapor kelas terpilih.
//   Catatan wali kelas : disusun otomatis per santri dari bank kalimat dan keunggulan santri (nilai tertinggi, kehadiran,
//                        hafalan, UTAS, pengembangan diri, sikap) serta dorongan (mapel di bawah KKM, kehadiran); dapat disunting.
//   Kokurikuler (SMA)  : nilai 1–4 per dimensi profil lulusan; deskripsi otomatis dari dimensi tertinggi dan terendah.
//   Cetak (v1.1)       : kelengkapan, sampul, identitas, rapor SMA/Wustha, rapor tahfizh, leger (+Excel), ketercapaian, remidi, tanda terima
//   Nilai wali kelas   : mapel rapor bersumber "Diisi wali kelas" (tampil bila ada)
//   Kenaikan/kelulusan : semester 2
// Pengisian terbuka saat periode penilaian jenjang kelas Dibuka (Penilaian → Periode); pengelola nilai kapan saja.
import { ref, computed, onMounted, watch } from 'vue'
import { PhNotePencil, PhPuzzlePiece, PhInfo, PhFloppyDisk, PhMagicWand, PhPrinter, PhPencilLine, PhGraduationCap } from '@phosphor-icons/vue'
import { useRapor } from '@/stores/rapor'
import { usePenilaian } from '@/stores/penilaian'
import { useWaliKelas } from '@/stores/waliKelas'
import { useUI } from '@/stores/ui'
import { LABEL_SEMESTER } from '@/lib/nilai'
import { predikatDari, sebutanPredikat } from '@/lib/penilaian'
import { faktaWali, susunCatatan, kalimatUntuk, deskripsiKokurikuler, SKALA_KOKURIKULER } from '@/lib/catatanRapor'
import DaftarCatatanRapor from '@/pages/penilaian/DaftarCatatanRapor.vue'
import CetakRaporKelas from '@/pages/penilaian/CetakRaporKelas.vue'
import IsianNilaiManual from './IsianNilaiManual.vue'
import IsianKenaikan from './IsianKenaikan.vue'
import { kelasAkhir } from '@/lib/rapor'

const rp = useRapor(); const pn = usePenilaian(); const wk = useWaliKelas(); const ui = useUI()
const semester = ref(null); const B = ref(null); const D = ref(null); const galat = ref(''); const bagian = ref('cetak')
async function muat(s) {
  galat.value = ''
  try {
    if (!pn.dimuat) await pn.muat()
    semester.value = s || semester.value || pn.ta?.semester || 1
    B.value = await rp.bahanKelas(wk.pilih, semester.value); salinKok()
    D.value = PAKAI_D.includes(bagian.value) ? await rp.dataRapor(wk.pilih, semester.value) : null
  } catch (e) { galat.value = e.message }
}
const PAKAI_D = ['cetak', 'manual', 'kenaikan']
async function muatD() { if (D.value) return; try { D.value = await rp.dataRapor(wk.pilih, semester.value) } catch (e) { galat.value = e.message } }
watch(bagian, (b) => { if (PAKAI_D.includes(b)) muatD() })
onMounted(() => muat())
watch(() => wk.pilih, () => muat())

const jenjang = computed(() => B.value?.kelas?.jenjang)
const bahasa = computed(() => pn.ketentuan?.tahfizh?.bahasa_predikat || 'indonesia')
const sebutUtas = (u) => { if (u?.nilai == null) return null; const t = sebutanPredikat(predikatDari(u.nilai, pn.predikatKelompok('utas')), bahasa.value); return t && bahasa.value === 'arab' ? `_${t}_` : t }
const bank = computed(() => kalimatUntuk(pn.kalimat, 'catatan_wali', jenjang.value))
const kokAktif = computed(() => !!B.value?.kokurikuler?.aktif && (B.value?.kokurikuler?.dimensi || []).length > 0)
const adaManual = computed(() => !!B.value && pn.mapelTingkat(jenjang.value, B.value.kelas.tingkat).some((m) => m.sumber === 'manual' && m.aktif !== false))
const BAGIAN = computed(() => [{ k: 'cetak', n: 'Cetak', ikon: PhPrinter }, { k: 'catatan', n: 'Catatan wali kelas', ikon: PhNotePencil },
  ...(kokAktif.value ? [{ k: 'kokurikuler', n: 'Kokurikuler', ikon: PhPuzzlePiece }] : []), ...(adaManual.value ? [{ k: 'manual', n: 'Nilai wali kelas', ikon: PhPencilLine }] : []),
  ...(semester.value === 2 ? [{ k: 'kenaikan', n: kelasAkhir(B.value?.kelas?.tingkat) ? 'Kelulusan' : 'Kenaikan kelas', ikon: PhGraduationCap }] : [])])
watch(BAGIAN, (v) => { if (!v.some((b) => b.k === bagian.value)) bagian.value = 'cetak' })
async function segarkanD() { D.value = await rp.dataRapor(wk.pilih, semester.value) }

// ---------- Catatan wali kelas ----------
const santriCatatan = computed(() => (B.value?.santri || []).map((s) => {
  const f = faktaWali(s, { sebutUtas })
  const fakta = [
    f.rata != null && { n: `Rata-rata ${f.rata}`, w: 'gurumapel' },
    f.terbaik && { n: `Terbaik: ${f.terbaik.mapel} ${Math.round(f.terbaik.nilai)}`, w: 'presensi' },
    f.lemah.length && { n: `Di bawah KKM: ${f.lemah.length} mapel`, w: 'klinik' },
    f.hadir != null && { n: `Hadir ${f.hadir}%`, w: f.hadir >= 90 ? 'presensi' : f.hadir >= 80 ? 'agenda' : 'klinik' },
    s.tambah_juz > 0 && { n: `+${s.tambah_juz} juz`, w: 'tahfizh' },
    s.utas?.huruf && { n: `UTAS ${s.utas.nilai}`, w: 'tahfizh' },
    (s.pd || []).length && { n: `PD: ${s.pd.map((x) => `${x.kegiatan} ${x.nilai}`).join(', ')}`, w: 'ekskul' },
  ].filter(Boolean)
  return { ...s, fakta, _f: f }
}))
const susun = (s, n) => susunCatatan(bank.value, s._f, `${s.id}|${semester.value}|${n}`)
async function simpanCatatan(isi) { await rp.simpanCatatan(wk.pilih, semester.value, 'wali', isi); await muat() }

// ---------- Kokurikuler ----------
const dimensi = computed(() => B.value?.kokurikuler?.dimensi || [])
const tema = computed(() => B.value?.kokurikuler?.tema || '')
const kok = ref({}); const ubahKok = ref(new Set()); const proses = ref(false); const isiSeragam = ref(3)
function salinKok() { kok.value = Object.fromEntries((B.value?.santri || []).map((s) => [s.id, { dimensi: { ...(s.kokurikuler?.dimensi || {}) }, deskripsi: s.kokurikuler?.deskripsi || '' }])); ubahKok.value = new Set() }
function setDim(s, d, v) { kok.value[s.id].dimensi[d] = v === '' ? undefined : Number(v); if (v === '') delete kok.value[s.id].dimensi[d]; ubahKok.value = new Set([...ubahKok.value, s.id]) }
function setDesk(s, v) { kok.value[s.id].deskripsi = v; ubahKok.value = new Set([...ubahKok.value, s.id]) }
function seragam() { let n = 0; for (const s of B.value.santri) for (const d of dimensi.value) if (kok.value[s.id].dimensi[d] == null) { setDim(s, d, isiSeragam.value); n++ }
  ui.toast(n ? `${n} isian dimensi yang kosong diisi ${isiSeragam.value} (${SKALA_KOKURIKULER[isiSeragam.value].n}).` : 'Semua dimensi sudah terisi.') }
const otomatis = (s) => deskripsiKokurikuler(kok.value[s.id]?.dimensi, tema.value)
const lengkap = computed(() => (B.value?.santri || []).filter((s) => dimensi.value.every((d) => kok.value[s.id]?.dimensi[d] != null)).length)
async function simpanKok() {
  proses.value = true
  try {
    const isi = [...ubahKok.value].map((id) => ({ student_id: id, dimensi: Object.fromEntries(Object.entries(kok.value[id].dimensi).filter(([, v]) => v != null)), deskripsi: (kok.value[id].deskripsi || '').trim() }))
    await rp.simpanKokurikuler(wk.pilih, semester.value, isi); ui.toast(`Kokurikuler ${isi.length} santri disimpan.`); await muat()
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
</script>
<template>
  <div class="w-rapor space-y-4">
    <div class="kartu flex flex-wrap items-center gap-3 p-4">
      <div class="bilah-tab kecil" role="tablist" aria-label="Semester">
        <button v-for="s in [1, 2]" :key="s" type="button" role="tab" :aria-selected="semester === s" @click="muat(s)"
          :class="['tab-garis', semester === s && 'aktif']">{{ LABEL_SEMESTER[s] }}</button>
      </div>
      <p class="min-w-[200px] flex-1 text-xs text-teks3">Nilai mapel diisi guru mapel, pengembangan diri oleh pembina ekskul, dan UTAS oleh penguji; wali kelas melengkapi catatan{{ kokAktif ? ', kokurikuler' : '' }}{{ semester === 2 ? ', keputusan akhir tahun' : '' }}, lalu mencetak.</p>
      <div class="bilah-tab kecil w-full" role="tablist" aria-label="Bagian rapor">
        <button v-for="b in BAGIAN" :key="b.k" type="button" role="tab" :aria-selected="bagian === b.k" @click="bagian = b.k"
          :class="['tab-garis', bagian === b.k && 'aktif']"><component :is="b.ikon" :size="18" weight="duotone" /><span>{{ b.n }}</span></button>
      </div>
    </div>
    <div v-if="galat" class="kartu w-klinik p-5 text-sm font-semibold" style="color: var(--c)">Bahan rapor gagal dimuat: {{ galat }} Pastikan migrasi SQL 8500 sudah dijalankan.</div>
    <template v-else-if="B">
      <template v-if="PAKAI_D.includes(bagian)">
        <p v-if="!D" class="kartu p-6 text-center text-sm text-teks3">Memuat data rapor…</p>
        <CetakRaporKelas v-else-if="bagian === 'cetak'" :key="'ct' + wk.pilih + semester" :D="D" />
        <IsianNilaiManual v-else-if="bagian === 'manual'" :D="D" @tersimpan="segarkanD" />
        <IsianKenaikan v-else :D="D" @tersimpan="segarkanD" />
      </template>
      <template v-else>
      <p v-if="!B.boleh" class="flex gap-2 rounded-2xl bg-permukaan2 p-3 text-sm text-teks2"><PhInfo :size="18" class="mt-0.5 shrink-0" />
        <span>Pengisian belum/tidak terbuka: periode penilaian {{ jenjang === 'sma' ? 'SMA' : 'Wustha' }} {{ LABEL_SEMESTER[semester]?.toLowerCase() }} belum dibuka atau sudah ditutup (Penilaian → Periode), atau Anda bukan wali kelas ini.</span></p>

      <DaftarCatatanRapor v-if="bagian === 'catatan'" :key="'c' + wk.pilih + semester" :santri="santriCatatan" :boleh="B.boleh" :susun="susun" :simpan="simpanCatatan"
        label="Catatan wali kelas" :kosong-bank="!bank.length" />

      <template v-else>
        <div class="kartu flex flex-wrap items-center gap-2 p-3 text-sm">
          <p class="min-w-[200px] flex-1"><b>Tema:</b> {{ tema || 'belum diatur (Penilaian → Periode)' }} · <b class="tabular-nums">{{ lengkap }}/{{ B.santri.length }}</b> <span class="text-teks3">santri lengkap</span></p>
          <template v-if="B.boleh">
            <select v-model.number="isiSeragam" class="isian w-auto" aria-label="Nilai seragam"><option v-for="v in [4, 3, 2, 1]" :key="v" :value="v">{{ v }} · {{ SKALA_KOKURIKULER[v].n }}</option></select>
            <button class="tombol-garis min-h-[40px] px-3 text-sm" @click="seragam"><PhMagicWand :size="18" /> Isi yang kosong</button>
          </template>
        </div>
        <p class="text-xs text-teks3">Skala: {{ [4, 3, 2, 1].map((v) => `${v} = ${SKALA_KOKURIKULER[v].n}`).join(' · ') }}. Deskripsi kosong = disusun otomatis dari dimensi tertinggi dan terendah.</p>
        <ul class="space-y-3">
          <li v-for="(s, i) in B.santri" :key="s.id" class="kartu p-4">
            <p class="font-semibold"><span class="text-teks3 tabular-nums">{{ i + 1 }}.</span> {{ s.nama }} <span class="text-xs font-normal text-teks3">{{ s.nis }} · {{ s.jenis_kelamin }}</span></p>
            <div class="mt-2 grid grid-cols-2 gap-2 sm:grid-cols-4">
              <label v-for="d in dimensi" :key="d" class="text-xs text-teks3">{{ d }}
                <select :value="kok[s.id]?.dimensi[d] ?? ''" :disabled="!B.boleh" :aria-label="`${d} ${s.nama}`" :class="['isian mt-0.5 py-1.5 text-sm', ubahKok.has(s.id) ? 'border-[color:var(--c)]' : '']" @change="setDim(s, d, $event.target.value)">
                  <option value="">–</option><option v-for="v in [4, 3, 2, 1]" :key="v" :value="v">{{ v }} · {{ SKALA_KOKURIKULER[v].n }}</option></select></label>
            </div>
            <textarea :value="kok[s.id]?.deskripsi" rows="2" :disabled="!B.boleh" class="isian mt-2 text-sm" :placeholder="otomatis(s) || 'Deskripsi otomatis tampil setelah dimensi diisi'"
              :aria-label="`Deskripsi kokurikuler ${s.nama}`" @input="setDesk(s, $event.target.value)" />
          </li>
        </ul>
        <div v-if="ubahKok.size" class="sticky bottom-[84px] z-20 lg:bottom-4">
          <div class="kartu mx-auto flex max-w-2xl flex-wrap items-center gap-2 p-3 shadow-xl">
            <p class="flex-1 text-sm font-semibold">{{ ubahKok.size }} santri belum disimpan</p>
            <button class="tombol-garis min-h-[40px] px-3 text-sm" :disabled="proses" @click="salinKok">Batal</button>
            <button class="tombol-utama min-h-[40px] px-3 text-sm" :disabled="proses" @click="simpanKok"><PhFloppyDisk :size="18" weight="duotone" /> {{ proses ? 'Menyimpan…' : 'Simpan kokurikuler' }}</button>
          </div>
        </div>
      </template>
      </template>
    </template>
    <p v-else class="kartu p-6 text-center text-sm text-teks3">Memuat bahan rapor…</p>
  </div>
</template>
