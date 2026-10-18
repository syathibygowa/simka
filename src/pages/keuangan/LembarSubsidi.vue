<!-- SIMKA PRO | src/pages/keuangan/LembarSubsidi.vue | v1.1 | 14.2.0: subsidi langsung mengurangi tagihan yang belum lunas | 17/10/2026 -->
<script setup>
// Subsidi (keringanan) seorang santri: persen atau nominal, untuk semua jenis biaya atau satu jenis, berlaku dari–sampai.
// v1.1: subsidi berlaku untuk tagihan yang periodenya beririsan dengan masa berlaku, dan tagihan santri yang belum lunas
//       langsung dihitung ulang saat disimpan (kecuali tagihan yang potongannya diubah manual). Mulai bawaan = awal tahun ajaran aktif.
import { ref, computed, watch } from 'vue'
import { PhFloppyDisk } from '@phosphor-icons/vue'
import { useKeuangan } from '@/stores/keuangan'
import { useUI } from '@/stores/ui'
import { useLembaga } from '@/stores/lembaga'
import { formatPanjang } from '@/lib/tanggal'
import { bacaRupiah, angka } from '@/lib/keuangan'
import LembarBawah from '@/components/LembarBawah.vue'
import InputTanggal from '@/components/InputTanggal.vue'

const props = defineProps({ isi: { type: Object, default: null } })   // { id?, student_id?, nama? ... } · null = tertutup
const emit = defineEmits(['tutup', 'tersimpan'])
const keu = useKeuangan(); const ui = useUI(); const lembaga = useLembaga()
const awalTA = computed(() => lembaga.tahunAktif?.mulai || '')
const buka = computed({ get: () => !!props.isi, set: (v) => !v && emit('tutup') })
const f = ref(null); const daftar = ref([]); const cari = ref('')
watch(() => props.isi, async (x) => {
  if (!x) return
  await lembaga.muat().catch(() => null)
  f.value = { id: x.id || null, student_id: x.student_id || '', nama: x.nama || '', fee_type_id: x.fee_type_id || '', jenis: x.jenis || 'persen',
    nilai: x.nilai ? (x.jenis === 'nominal' ? angka(x.nilai) : String(Number(x.nilai))) : '', mulai: x.mulai || awalTA.value, sampai: x.sampai || '', alasan: x.alasan || '', aktif: x.aktif ?? true }
  cari.value = ''
  if (!x.student_id && !daftar.value.length) { try { daftar.value = await keu.santri({}) } catch { /* abaikan */ } }
}, { immediate: true })
const calon = computed(() => { const q = cari.value.toLowerCase().trim(); return q ? daftar.value.filter((s) => s.nama.toLowerCase().includes(q) || s.nis.startsWith(q)).slice(0, 30) : [] })
const proses = ref(false)
async function simpan() {
  const d = f.value
  const nilai = d.jenis === 'nominal' ? bacaRupiah(d.nilai) : Number(String(d.nilai).replace(',', '.'))
  if (!d.student_id) return ui.toast('Pilih santri.', 'galat')
  if (!nilai || nilai <= 0 || (d.jenis === 'persen' && nilai > 100)) return ui.toast(d.jenis === 'persen' ? 'Isi persen antara 1 dan 100.' : 'Isi nominal potongan.', 'galat')
  if ((d.alasan || '').trim().length < 3) return ui.toast('Tulis alasan subsidi.', 'galat')
  proses.value = true
  try { await keu.simpanSubsidi({ ...d, nilai, fee_type_id: d.fee_type_id || null, sampai: d.sampai || null }); ui.toast('Subsidi disimpan. Tagihan santri ini yang belum lunas sudah ikut disesuaikan.'); emit('tersimpan'); emit('tutup') }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
</script>
<template>
  <LembarBawah v-model="buka" :judul="f?.id ? 'Ubah subsidi' : 'Tambah subsidi santri'">
    <div v-if="f" class="space-y-4 pb-2">
      <div v-if="!isi.student_id">
        <label class="label-isian" for="sb-cari">Santri</label>
        <input id="sb-cari" v-model="cari" type="search" class="isian" placeholder="Cari nama atau NIS" />
        <ul v-if="calon.length" class="mt-2 max-h-48 divide-y divide-garis overflow-y-auto rounded-xl border border-garis">
          <li v-for="s in calon" :key="s.id"><button type="button" :class="['w-full px-3 py-2 text-left text-sm', f.student_id === s.id ? 'bg-permukaan2 font-bold' : 'hover:bg-permukaan2']"
            @click="(f.student_id = s.id), (f.nama = s.nama)">{{ s.nama }} <span class="text-xs font-normal text-teks3">{{ s.nis }} · {{ s.kelas || '–' }}</span></button></li>
        </ul>
      </div>
      <p v-if="f.nama" class="rounded-xl bg-permukaan2 p-3 text-sm">Santri: <b>{{ f.nama }}</b></p>
      <div><label class="label-isian" for="sb-jns">Berlaku untuk</label>
        <select id="sb-jns" v-model="f.fee_type_id" class="isian"><option value="">Semua jenis biaya</option>
          <option v-for="j in keu.jenis" :key="j.id" :value="j.id">{{ j.nama }}</option></select></div>
      <div class="grid grid-cols-[auto_1fr] gap-3">
        <div><span class="label-isian">Bentuk</span>
          <div class="flex rounded-xl bg-permukaan2 p-1" role="radiogroup" aria-label="Bentuk subsidi">
            <button v-for="(n, k) in { persen: 'Persen', nominal: 'Nominal' }" :key="k" type="button" role="radio" :aria-checked="f.jenis === k" @click="(f.jenis = k), (f.nilai = '')"
              :class="['min-h-[40px] rounded-lg px-3 text-sm font-semibold', f.jenis === k ? 'bg-permukaan text-teks shadow-kartu' : 'text-teks2']">{{ n }}</button></div></div>
        <div><label class="label-isian" for="sb-nil">{{ f.jenis === 'persen' ? 'Potongan (%)' : 'Potongan (Rp) per tagihan' }}</label>
          <input id="sb-nil" v-model="f.nilai" inputmode="decimal" class="isian tabular-nums" :placeholder="f.jenis === 'persen' ? '50' : '150.000'" /></div>
      </div>
      <div class="grid gap-3 sm:grid-cols-2">
        <InputTanggal v-model="f.mulai" label="Berlaku mulai" wajib />
        <InputTanggal v-model="f.sampai" label="Sampai (kosong = seterusnya)" bawaan-kosong />
      </div>
      <p class="rounded-xl bg-permukaan2 p-3 text-xs text-teks2">Subsidi mengurangi tagihan yang periodenya masuk masa berlaku ini, termasuk tagihan yang <b>sudah dibuat</b> dan belum lunas.
        Tagihan yang potongannya pernah diubah manual tidak disentuh.<template v-if="awalTA"> Bawaan mulai: awal tahun ajaran aktif ({{ formatPanjang(awalTA) }}).</template></p>
      <div><label class="label-isian" for="sb-als">Alasan</label><input id="sb-als" v-model="f.alasan" class="isian" placeholder="Contoh: Santri yatim; anak pegawai; beasiswa tahfizh" /></div>
      <label v-if="f.id" class="flex items-center gap-3"><input v-model="f.aktif" type="checkbox" class="h-5 w-5" /> Subsidi aktif</label>
      <button class="tombol-utama w-full" :disabled="proses" @click="simpan"><PhFloppyDisk :size="20" weight="duotone" /> Simpan subsidi</button>
    </div>
  </LembarBawah>
</template>
