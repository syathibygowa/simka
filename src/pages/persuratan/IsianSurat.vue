<!-- SIMKA PRO | src/pages/persuratan/IsianSurat.vue | v1.1 | Tahap C: data santri surat ditambah orang tua, hafalan, tanggal masuk, prestasi | 16/10/2026 -->
<script setup>
// Satu isian surat sesuai jenisnya: teks, teks panjang (tebal/miring), tanggal, hari-tanggal, jam, angka, pilih pegawai,
// pilih santri (data diambil dari Data Santri), daftar butir, atau daftar pegawai.
import { ref, computed, watch } from 'vue'
import { PhMagnifyingGlass, PhX, PhPlus, PhTrash, PhUser, PhStudent } from '@phosphor-icons/vue'
import { usePersuratan } from '@/stores/persuratan'
import { useUI } from '@/stores/ui'
import { ttlSantri } from '@/lib/suratKeluar'
import InputTanggal from '@/components/InputTanggal.vue'
import InputJam from '@/components/InputJam.vue'
import IsianTeksKaya from '@/components/IsianTeksKaya.vue'

const nilai = defineModel({ default: null })
const props = defineProps({ isian: { type: Object, required: true } })
const ps = usePersuratan(); const ui = useUI()
const id = 'is-' + props.isian.kunci
const cari = ref(''); const hasil = ref([]); const buka = ref(false)
const jenisOrang = computed(() => ['pegawai', 'daftar_pegawai'].includes(props.isian.jenis) ? 'pegawai' : props.isian.jenis === 'santri' ? 'santri' : null)
let tunda
watch(cari, (q) => {
  clearTimeout(tunda)
  if (!jenisOrang.value) return
  tunda = setTimeout(async () => {
    try {
      if (jenisOrang.value === 'santri') { hasil.value = q.trim().length >= 2 ? await ps.cariSantri(q) : []; return }
      const semua = await ps.muatPegawaiLengkap(); const t = q.toLowerCase().trim()
      hasil.value = semua.filter((p) => !t || `${p.nama} ${p.jabatan || ''} ${p.unit || ''} ${p.niy || ''}`.toLowerCase().includes(t)).slice(0, 20)
    } catch (e) { ui.toast(e.message, 'galat') }
  }, 250)
})
function pilihOrang(p) {
  const x = jenisOrang.value === 'santri' ? { id: p.id, nama: p.nama, nis: p.nis, nisn: p.nisn, jk: p.jk, tempat_lahir: p.tempat_lahir, tanggal_lahir: p.tanggal_lahir,
    jenjang: p.jenjang, tingkat: p.tingkat, kelas: p.kelas, wali: p.wali, alamat: p.alamat,
    ayah: p.ayah || '', ibu: p.ibu || '', hafalan: p.hafalan ?? null, tanggal_masuk: p.tanggal_masuk || null, prestasi: p.prestasi || [] } : { id: p.id, nama: p.nama, niy: p.niy || '', jabatan: p.jabatan || '', unit: p.unit || '' }
  if (props.isian.jenis === 'daftar_pegawai') { const a = Array.isArray(nilai.value) ? nilai.value : []; if (!a.some((y) => y.id === x.id)) nilai.value = [...a, x] }
  else nilai.value = x
  cari.value = ''; hasil.value = []; buka.value = false
}
const butir = computed(() => (Array.isArray(nilai.value) ? nilai.value : ['']))
function ubahButir(i, v) { const a = [...butir.value]; a[i] = v; nilai.value = a }
const tambahButir = () => { nilai.value = [...butir.value, ''] }
const hapusButir = (i) => { const a = butir.value.filter((_, j) => j !== i); nilai.value = a.length ? a : [''] }
</script>
<template>
  <div>
    <InputTanggal v-if="isian.jenis === 'tanggal' || isian.jenis === 'hari_tanggal'" v-model="nilai" :label="isian.label" :wajib="isian.wajib" />
    <InputJam v-else-if="isian.jenis === 'jam'" v-model="nilai" :label="isian.label" :wajib="isian.wajib" />
    <template v-else>
      <label class="label-isian" :for="id">{{ isian.label }}<span v-if="isian.wajib" class="text-merah"> *</span></label>
      <IsianTeksKaya v-if="isian.jenis === 'panjang'" :id="id" v-model="nilai" tinggi="6rem" />
      <input v-else-if="isian.jenis === 'teks' || isian.jenis === 'angka'" :id="id" v-model="nilai" :inputmode="isian.jenis === 'angka' ? 'numeric' : 'text'" class="isian" />

      <div v-else-if="isian.jenis === 'daftar'" class="space-y-2">
        <div v-for="(b, i) in butir" :key="i" class="flex items-center gap-2">
          <span class="w-6 shrink-0 text-right text-sm tabular-nums text-teks3">{{ isian.gaya === 'huruf' ? 'abcdefghijklmnopqrstuvwxyz'[i] + '.' : isian.gaya === 'poin' ? '•' : i + 1 + '.' }}</span>
          <input :id="i === 0 ? id : undefined" :value="b" class="isian" :aria-label="`${isian.label} butir ${i + 1}`" @input="ubahButir(i, $event.target.value)" @keydown.enter.prevent="tambahButir" />
          <button type="button" class="tombol-ikon shrink-0" :aria-label="`Hapus butir ${i + 1}`" @click="hapusButir(i)"><PhTrash :size="18" /></button>
        </div>
        <button type="button" class="tombol-teks -ml-3 px-3 text-sm" @click="tambahButir"><PhPlus :size="16" /> Tambah butir</button>
      </div>

      <div v-else-if="jenisOrang">
        <div v-if="isian.jenis === 'daftar_pegawai' && butir.length && typeof butir[0] === 'object'" class="mb-2 space-y-1.5">
          <p v-for="(p, i) in nilai" :key="p.id" class="flex items-center gap-2 rounded-xl bg-permukaan2 px-3 py-2 text-sm">
            <span class="w-5 text-teks3">{{ i + 1 }}.</span><span class="min-w-0 flex-1"><b>{{ p.nama }}</b> <span class="text-xs text-teks3">{{ p.jabatan }}</span></span>
            <button type="button" :aria-label="`Hapus ${p.nama}`" @click="nilai = nilai.filter((x) => x.id !== p.id)"><PhX :size="16" /></button></p>
        </div>
        <div v-if="isian.jenis !== 'daftar_pegawai' && nilai?.nama" class="flex items-center gap-3 rounded-xl border border-garis px-3 py-2">
          <component :is="jenisOrang === 'santri' ? PhStudent : PhUser" :size="22" weight="duotone" class="text-teks2" />
          <span class="min-w-0 flex-1 text-sm"><b class="block truncate">{{ nilai.nama }}</b>
            <span class="text-xs text-teks3">{{ jenisOrang === 'santri' ? `NIS ${nilai.nis} · ${nilai.kelas || '–'} · ${ttlSantri(nilai)}` : `${nilai.jabatan}${nilai.niy ? ' · NIY ' + nilai.niy : ''}` }}</span></span>
          <button type="button" class="tombol-teks px-2 text-sm" @click="nilai = null">Ganti</button>
        </div>
        <div v-else class="relative">
          <PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3.5 top-[23px] -translate-y-1/2 text-teks3" />
          <input :id="id" v-model="cari" type="search" class="isian pl-11" :placeholder="jenisOrang === 'santri' ? 'Ketik nama atau NIS santri (min. 2 huruf)' : 'Cari nama atau jabatan pegawai'"
            @focus="buka = true; cari === '' && jenisOrang === 'pegawai' && (cari = ' ')" />
          <ul v-if="hasil.length && buka" class="mt-1 max-h-56 divide-y divide-garis overflow-y-auto rounded-xl border border-garis bg-permukaan">
            <li v-for="p in hasil" :key="p.id"><button type="button" class="flex min-h-[46px] w-full items-center gap-2 px-3 text-left text-sm hover:bg-permukaan2" @click="pilihOrang(p)">
              <span class="min-w-0 flex-1"><b class="block truncate">{{ p.nama }}</b>
                <span class="block truncate text-xs text-teks3">{{ jenisOrang === 'santri' ? `${p.nis} · ${p.kelas || p.jenjang}` : `${p.jabatan || ''}${p.unit ? ' · ' + p.unit : ''}` }}</span></span></button></li>
          </ul>
        </div>
      </div>
    </template>
  </div>
</template>
