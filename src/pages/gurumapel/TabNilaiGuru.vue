<!-- SIMKA PRO | src/pages/gurumapel/TabNilaiGuru.vue | v1.3 | 14.27.0: urutan Sebelumnya/Berikutnya untuk halaman isian | 26/10/2026 -->
<script setup>
// Tab Nilai di menu Guru Mapel: kelas–mapel yang diampu (guru) atau semua (pengelola nilai/pimpinan) untuk satu semester,
// beserta status periode, cara menentukan nilai, dan kemajuan pengisian (nilai rapor dan sikap). Ketuk kartu → lembar nilai.
import { aturUrutan } from '@/lib/urutan'
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { PhExam, PhMagnifyingGlass, PhLockSimple, PhLockSimpleOpen, PhHourglassMedium, PhCaretRight, PhLink } from '@phosphor-icons/vue'
import { useNilai } from '@/stores/nilai'
import { MODE_NILAI, STATUS_PERIODE } from '@/lib/penilaian'
import { LABEL_SEMESTER } from '@/lib/nilai'
import { JENJANG_PENDEK } from '@/lib/santri'
import { warnaJenjang } from '@/lib/jadwal'
import SubTabJenjang from '@/components/SubTabJenjang.vue'

const nl = useNilai(); const router = useRouter()
const semester = ref(null); const cari = ref(''); const galat = ref(''); const jenjang = ref('')
async function muat(s) { galat.value = ''; try { await nl.muatDaftar(s); semester.value = nl.semester } catch (e) { galat.value = e.message } }
onMounted(() => muat(nl.semester))
function ganti(s) { semester.value = s; muat(s) }
const daftar = computed(() => { const q = cari.value.toLowerCase().trim(); return nl.daftar.filter((x) => (!jenjang.value || x.jenjang === jenjang.value) && (!q || `${x.kelas} ${x.mapel} ${x.guru}`.toLowerCase().includes(q))) })
const jumlahJ = computed(() => ({ '': nl.daftar.length, wustha: nl.daftar.filter((x) => x.jenjang === 'wustha').length, sma: nl.daftar.filter((x) => x.jenjang === 'sma').length }))
const milik = computed(() => daftar.value.filter((x) => x.milik_saya))
const lain = computed(() => daftar.value.filter((x) => !x.milik_saya))
const IKON = { disiapkan: PhHourglassMedium, dibuka: PhLockSimpleOpen, ditutup: PhLockSimple }
const persen = (x) => (x.santri ? Math.round((x.terisi / x.santri) * 100) : 0)
const keLembar = (x) => ({ path: `/guru-mapel/nilai/${x.assignment_id}`, query: { smt: semester.value } })
const buka = (x) => { aturUrutan('nilai', [...milik.value, ...lain.value].map((y) => ({ ke: keLembar(y), label: `${y.mapel} · ${y.kelas}` }))); router.push(keLembar(x)) }
</script>
<template>
  <div class="space-y-4">
    <SubTabJenjang v-model="jenjang" :jumlah="jumlahJ" label="Saring jenjang" />
    <div class="kartu flex flex-wrap items-end gap-3 p-4">
      <div class="bilah-tab kecil" role="tablist" aria-label="Semester">
        <button v-for="s in [1, 2]" :key="s" type="button" role="tab" :aria-selected="semester === s" @click="ganti(s)"
          :class="['tab-garis', semester === s && 'aktif']">{{ LABEL_SEMESTER[s] }}</button>
      </div>
      <div v-if="nl.daftar.length > 6" class="relative min-w-[200px] flex-1"><PhMagnifyingGlass :size="18" class="absolute left-3 top-1/2 -translate-y-1/2 text-teks3" />
        <input v-model="cari" type="search" class="isian pl-10" placeholder="Cari kelas, mapel, atau guru" aria-label="Cari" /></div>
    </div>
    <div v-if="galat" class="kartu w-klinik p-5 text-sm font-semibold" style="color: var(--c)">Data nilai gagal dimuat: {{ galat }} Pastikan migrasi SQL 8300 sudah dijalankan.</div>
    <template v-else>
      <template v-for="kel in [{ n: 'Mapel yang saya ampu', d: milik }, { n: 'Semua kelas dan mapel', d: lain }]" :key="kel.n">
        <section v-if="kel.d.length">
          <p class="mb-2 text-sm font-bold text-teks2">{{ kel.n }} · {{ kel.d.length }}</p>
          <div class="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
            <button v-for="x in kel.d" :key="x.assignment_id" type="button" :class="['kartu kartu-jenjang flex flex-col gap-2 p-4 text-left transition hover:shadow-lg', 'w-' + warnaJenjang(x.jenjang)]" @click="buka(x)">
              <div class="flex items-start gap-3">
                <span class="chip-ikon h-11 w-11"><PhExam :size="24" weight="duotone" /></span>
                <div class="min-w-0 flex-1"><p class="truncate font-bold">{{ x.mapel }}</p>
                  <p class="truncate text-sm text-teks2">Kelas {{ x.kelas }} · <b class="font-semibold" style="color: var(--c)">{{ JENJANG_PENDEK[x.jenjang] }}</b>{{ x.milik_saya ? '' : ` · ${x.guru}` }}</p></div>
                <PhCaretRight :size="18" class="mt-1 text-teks3" />
              </div>
              <div class="flex flex-wrap gap-1.5">
                <span :class="['lencana', 'w-' + STATUS_PERIODE[x.status].w]"><component :is="IKON[x.status]" :size="12" weight="bold" /> {{ STATUS_PERIODE[x.status].n }}</span>
                <span class="lencana w-rapor">{{ MODE_NILAI[x.mode]?.n }}</span>
                <span v-for="r in x.mapel_rapor.filter((n) => n !== x.mapel)" :key="r" class="lencana w-penilaian"><PhLink :size="12" /> rapor: {{ r }}</span>
              </div>
              <div>
                <div class="flex justify-between text-xs text-teks3"><span>Nilai rapor {{ x.terisi }}/{{ x.santri }} · sikap {{ x.sikap }}/{{ x.santri }} · {{ x.kolom }} isian</span><span class="font-bold tabular-nums">{{ persen(x) }}%</span></div>
                <div class="mt-1 h-2 overflow-hidden rounded-full bg-permukaan2"><div class="h-full rounded-full" :style="{ width: persen(x) + '%', background: 'var(--c)' }" /></div>
              </div>
            </button>
          </div>
        </section>
      </template>
      <p v-if="nl.dimuat && !daftar.length" class="kartu p-6 text-center text-sm text-teks3">Belum ada kelas dan mapel yang dapat Anda nilai. Penugasan mengajar diatur di menu Jadwal Pelajaran → Penugasan.</p>
      <p v-else-if="!nl.dimuat" class="kartu p-6 text-center text-sm text-teks3">Memuat…</p>
    </template>
  </div>
</template>
<style scoped>
/* Warna kartu mengikuti jenjang kelas (Wustha jingga-emas, SMA biru) */
.kartu-jenjang { border-left: 4px solid var(--c); background: linear-gradient(135deg, color-mix(in srgb, var(--c) 7%, rgb(var(--permukaan))) 0%, rgb(var(--permukaan)) 60%); }
</style>
