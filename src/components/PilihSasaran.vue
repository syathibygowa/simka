<!-- SIMKA PRO | src/components/PilihSasaran.vue | v1.0 | Fase 3 – Tahap 1 Pengumuman, audit log, notifikasi HP | 04/10/2026 -->
<script setup>
// Pemilih sasaran bersama (pengumuman, berkas pegawai, agenda): semua pegawai, atau gabungan
// bidang/unit (beserta cabangnya), jabatan fungsional, jabatan struktural, saringan jenis kelamin,
// dan pegawai tertentu. Jumlah penerima dihitung server (fungsi hitung_sasaran).
import { ref, computed, watch, onMounted } from 'vue'
import { PhUsersThree, PhFunnel, PhMagnifyingGlass, PhX, PhCheck } from '@phosphor-icons/vue'
import { useOrganisasi } from '@/stores/organisasi'
import { usePegawai } from '@/stores/pegawai'

const model = defineModel({ type: Object, default: () => ({ jenis: 'semua' }) })
const props = defineProps({ hitung: Function })
const emit = defineEmits(['ringkasan'])
const org = useOrganisasi(); const peg = usePegawai()
const cari = ref(''); const jumlah = ref(null)
onMounted(async () => { await Promise.all([org.muat(), peg.daftar.length ? null : peg.muat()]); hitungUlang() })

const s = computed(() => ({ unit: [], fungsional: [], struktural: [], pegawai: [], jk: '', ...model.value }))
const atur = (patch) => { model.value = { ...s.value, ...patch } }
const balik = (kunci, id) => { const a = new Set(s.value[kunci]); a.has(id) ? a.delete(id) : a.add(id); atur({ [kunci]: [...a] }) }
const ada = (kunci, id) => s.value[kunci].includes(id)

const calon = computed(() => {
  const q = cari.value.toLowerCase().trim()
  if (q.length < 2) return []
  return peg.daftar.filter((p) => p.status_akun === 'aktif' && !ada('pegawai', p.id) && [p.nama_lengkap, p.niy].join(' ').toLowerCase().includes(q)).slice(0, 8)
})
const namaPegawai = (id) => peg.cari(id)?.nama_lengkap || 'Pegawai'

const ringkasan = computed(() => {
  if (s.value.jenis === 'semua') return 'Semua pegawai'
  const b = []
  const u = s.value.unit.map((id) => org.cariUnit(id)?.nama).filter(Boolean); if (u.length) b.push(u.join(', '))
  const f = s.value.fungsional.map((id) => org.fungsional.find((x) => x.id === id)?.nama).filter(Boolean); if (f.length) b.push(f.join(', '))
  const st = s.value.struktural.map((id) => org.struktural.find((x) => x.id === id)?.nama).filter(Boolean); if (st.length) b.push(st.join(', '))
  if (s.value.jk) b.push(s.value.jk === 'L' ? 'khusus laki-laki' : 'khusus perempuan')
  if (s.value.pegawai.length) b.push(`${s.value.pegawai.length} pegawai tertentu`)
  return b.join('; ') || 'Semua pegawai'
})

let jeda = null
function hitungUlang() {
  clearTimeout(jeda)
  jeda = setTimeout(async () => { jumlah.value = props.hitung ? await props.hitung(model.value) : null }, 400)
}
watch(model, () => { hitungUlang(); emit('ringkasan', ringkasan.value) }, { deep: true })
watch(ringkasan, (v) => emit('ringkasan', v), { immediate: true })
</script>
<template>
  <div class="space-y-3">
    <div class="grid grid-cols-2 gap-2" role="radiogroup" aria-label="Jenis sasaran">
      <button v-for="j in [{ k: 'semua', n: 'Semua pegawai', i: PhUsersThree }, { k: 'pilihan', n: 'Pilih sasaran', i: PhFunnel }]" :key="j.k" type="button" role="radio" :aria-checked="s.jenis === j.k"
        :class="['flex min-h-[48px] items-center justify-center gap-2 rounded-xl border text-sm font-semibold', s.jenis === j.k ? 'border-transparent bg-[#C7332F] text-white' : 'border-garis bg-permukaan text-teks2']"
        @click="atur({ jenis: j.k })"><component :is="j.i" :size="20" weight="duotone" />{{ j.n }}</button>
    </div>

    <template v-if="s.jenis === 'pilihan'">
      <fieldset>
        <legend class="label-isian">Bidang/unit (termasuk unit di bawahnya)</legend>
        <div class="flex max-h-44 flex-wrap gap-1.5 overflow-y-auto rounded-xl border border-garis p-2">
          <button v-for="u in org.datar" :key="u.id" type="button" @click="balik('unit', u.id)"
            :class="['chip', ada('unit', u.id) && 'pilih']"><PhCheck v-if="ada('unit', u.id)" :size="14" weight="bold" />{{ u.nama }}</button>
          <p v-if="!org.datar.length" class="p-1 text-sm text-teks3">Belum ada bidang/unit.</p>
        </div>
      </fieldset>
      <fieldset>
        <legend class="label-isian">Jabatan fungsional</legend>
        <div class="flex flex-wrap gap-1.5">
          <button v-for="f in org.fungsional" :key="f.id" type="button" @click="balik('fungsional', f.id)"
            :class="['chip', ada('fungsional', f.id) && 'pilih']"><PhCheck v-if="ada('fungsional', f.id)" :size="14" weight="bold" />{{ f.nama }}</button>
        </div>
      </fieldset>
      <fieldset>
        <legend class="label-isian">Jabatan struktural</legend>
        <div class="flex flex-wrap gap-1.5">
          <button v-for="f in org.struktural" :key="f.id" type="button" @click="balik('struktural', f.id)"
            :class="['chip', ada('struktural', f.id) && 'pilih']"><PhCheck v-if="ada('struktural', f.id)" :size="14" weight="bold" />{{ f.nama }}</button>
        </div>
      </fieldset>
      <fieldset>
        <legend class="label-isian">Jenis kelamin</legend>
        <div class="flex gap-1.5">
          <button v-for="j in [{ k: '', n: 'Semua' }, { k: 'L', n: 'Laki-laki' }, { k: 'P', n: 'Perempuan' }]" :key="j.k" type="button" @click="atur({ jk: j.k })"
            :class="['chip', s.jk === j.k && 'pilih']">{{ j.n }}</button>
        </div>
      </fieldset>
      <div>
        <label class="label-isian" for="ps-cari">Pegawai tertentu (selalu ikut menerima)</label>
        <div class="relative"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-teks3" />
          <input id="ps-cari" v-model="cari" class="isian pl-10" placeholder="Ketik minimal 2 huruf nama atau NIY" autocomplete="off" /></div>
        <ul v-if="calon.length" class="mt-1 overflow-hidden rounded-xl border border-garis">
          <li v-for="p in calon" :key="p.id"><button type="button" class="flex min-h-[44px] w-full items-center gap-2 px-3 text-left text-sm hover:bg-permukaan2"
            @click="balik('pegawai', p.id); cari = ''"><span class="flex-1 font-semibold">{{ p.nama_lengkap }}</span><span class="text-xs text-teks3">{{ p.nama_unit }}</span></button></li>
        </ul>
        <div v-if="s.pegawai.length" class="mt-2 flex flex-wrap gap-1.5">
          <span v-for="id in s.pegawai" :key="id" class="chip pilih">{{ namaPegawai(id) }}
            <button type="button" class="-mr-1 rounded-full p-0.5" :aria-label="`Hapus ${namaPegawai(id)}`" @click="balik('pegawai', id)"><PhX :size="14" weight="bold" /></button></span>
        </div>
      </div>
      <p class="text-xs text-teks3">Bidang, jabatan fungsional, dan jabatan struktural digabung (salah satu cocok). Bila ketiganya kosong, berlaku untuk semua pegawai sesuai saringan jenis kelamin. Sasaran wali santri tersedia mulai Fase 9.</p>
    </template>

    <p class="rounded-xl bg-permukaan2 p-3 text-sm text-teks2"><span class="font-bold text-teks">Sasaran:</span> {{ ringkasan }}
      <template v-if="jumlah != null"> · <span class="font-bold text-teks">{{ jumlah }}</span> penerima berakun aktif</template></p>
  </div>
</template>
<style scoped>
.chip { display: inline-flex; min-height: 36px; align-items: center; gap: .3rem; border-radius: 9999px; border: 1px solid rgb(var(--garis)); background: rgb(var(--permukaan));
  padding: 0 .75rem; font-size: .8125rem; font-weight: 600; color: rgb(var(--teks-2)); }
.chip.pilih { border-color: transparent; background: color-mix(in srgb, #A13A86 14%, rgb(var(--permukaan))); color: rgb(var(--teks)); box-shadow: inset 0 0 0 1.5px #A13A86; }
:global(.dark) .chip.pilih { box-shadow: inset 0 0 0 1.5px #F49AD9; }
</style>
