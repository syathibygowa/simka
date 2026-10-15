<!-- SIMKA PRO | src/pages/wali/FormMasukWali.vue | v1.0 | Fase 9 – Tahap 13.0.0 Fondasi Portal Wali | 15/10/2026 -->
<script setup>
// Formulir masuk Portal Wali: NIS atau NISN + tanggal lahir santri + 6 digit terakhir nomor HP ayah/ibu/wali yang terdaftar.
// Dipakai halaman Masuk Portal Wali dan lembar "Tambah anak".
import { ref } from 'vue'
import { PhIdentificationCard, PhDeviceMobile, PhUserCircle } from '@phosphor-icons/vue'
import { usePortalWali } from '@/stores/portalWali'
import { MODE_DEMO } from '@/lib/supabase'
import { contohMasukDemo } from '@/lib/demoPortalWali'
import { formatPendek } from '@/lib/tanggal'
import InputTanggal from '@/components/InputTanggal.vue'

defineProps({ tombol: { type: String, default: 'Masuk' } })
const emit = defineEmits(['selesai'])
const pw = usePortalWali()
const identitas = ref(''); const tglLahir = ref(''); const hp = ref('')
const galat = ref(''); const proses = ref(false)
const contoh = MODE_DEMO ? contohMasukDemo() : []
const uid = Math.random().toString(36).slice(2, 7)

function angka(e, maks) { const v = e.target.value.replace(/\D/g, '').slice(0, maks); e.target.value = v; return v }

async function kirim() {
  galat.value = ''
  if (![7, 10].includes(identitas.value.length)) { galat.value = 'Isi NIS (7 angka) atau NISN (10 angka) santri.'; return }
  if (!tglLahir.value) { galat.value = 'Isi tanggal lahir santri dengan format dd/mm/yyyy.'; return }
  if (hp.value.length !== 6) { galat.value = 'Isi 6 digit terakhir nomor HP ayah, ibu, atau wali yang terdaftar di pondok.'; return }
  proses.value = true
  try {
    const a = await pw.masuk(identitas.value, tglLahir.value, hp.value)
    identitas.value = ''; tglLahir.value = ''; hp.value = ''
    emit('selesai', a)
  } catch (e) { galat.value = e.message }
  finally { proses.value = false }
}
function isiContoh(c) { identitas.value = c.nis; tglLahir.value = c.tanggal_lahir; hp.value = c.hp6; galat.value = '' }
</script>

<template>
  <div>
    <form class="space-y-4" novalidate @submit.prevent="kirim">
      <div>
        <label :for="'wid-' + uid" class="label-isian">NIS atau NISN santri</label>
        <div class="relative">
          <PhIdentificationCard :size="20" weight="duotone" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
          <input :id="'wid-' + uid" :value="identitas" class="isian pl-11 tabular-nums" inputmode="numeric" autocomplete="off" placeholder="7 atau 10 angka"
            @input="identitas = angka($event, 10)" />
        </div>
      </div>
      <InputTanggal v-model="tglLahir" label="Tanggal lahir santri" bawaan-kosong wajib />
      <div>
        <label :for="'whp-' + uid" class="label-isian">6 digit terakhir nomor HP orang tua/wali</label>
        <div class="relative">
          <PhDeviceMobile :size="20" weight="duotone" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
          <input :id="'whp-' + uid" :value="hp" class="isian pl-11 tracking-[0.3em] tabular-nums" inputmode="numeric" autocomplete="off" placeholder="••••••"
            @input="hp = angka($event, 6)" />
        </div>
        <p class="mt-1.5 text-sm text-teks3">Contoh: nomor 0812-3456-7890 → ketik <b class="tabular-nums text-teks2">567890</b>.</p>
      </div>
      <p v-if="galat" class="rounded-xl bg-[#C7332F]/10 px-3.5 py-2.5 text-sm font-semibold text-merah" role="alert">{{ galat }}</p>
      <button class="tombol-utama w-full" :disabled="proses">{{ proses ? 'Memeriksa…' : tombol }}</button>
    </form>

    <div v-if="contoh.length" class="mt-6">
      <p class="font-bold">Mode demo</p>
      <p class="text-sm text-teks2">Ketuk salah satu santri contoh untuk mengisi formulir.</p>
      <div class="mt-2 space-y-2">
        <button v-for="c in contoh" :key="c.nis" type="button" class="kartu w-santri flex w-full items-center gap-3 p-3 text-left hover:bg-permukaan2" @click="isiContoh(c)">
          <span class="chip-ikon h-10 w-10"><PhUserCircle :size="22" weight="duotone" /></span>
          <span class="min-w-0 flex-1"><span class="block font-bold">{{ c.nama }}</span>
            <span class="block text-sm tabular-nums text-teks3">NIS {{ c.nis }} · lahir {{ formatPendek(c.tanggal_lahir) }} · HP …{{ c.hp6 }}</span></span>
        </button>
      </div>
    </div>
  </div>
</template>
