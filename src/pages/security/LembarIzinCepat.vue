<!-- SIMKA PRO | src/pages/security/LembarIzinCepat.vue | v1.0 | Fase 7 – Tahap 1 Security: gerbang | 06/10/2026 -->
<script setup>
// Izin cepat: dibuat Kepala Bidang Kesantrian, Direktur/Wadir, Plt, atau superadmin untuk kejadian mendadak di gerbang
// (mis. wali menjemput tanpa izin). Izin langsung berlaku; Security dan pengasuh santri dinotifikasi.
// Izin lebih dari batas hari kepala bidang hanya dapat dibuat Direktur/Wadir atau superadmin.
import { ref, computed, watch } from 'vue'
import { PhLightning, PhHouseLine, PhPersonSimpleWalk, PhInfo } from '@phosphor-icons/vue'
import { useSecurity } from '@/stores/security'
import { useIzin } from '@/stores/izin'
import { useUI } from '@/stores/ui'
import { hariIniISO } from '@/lib/tanggal'
import LembarBawah from '@/components/LembarBawah.vue'
import InputTanggal from '@/components/InputTanggal.vue'
import InputJam from '@/components/InputJam.vue'

const buka = defineModel({ type: Boolean, default: false })
const props = defineProps({ santri: { type: Object, default: null } })
const emit = defineEmits(['selesai'])
const sc = useSecurity(); const iz = useIzin(); const ui = useUI()
const isi = ref({}); const tglB = ref(''); const jamB = ref(''); const proses = ref(false)
const gabung = (t, j) => new Date(`${t}T${(j || '00:00').slice(0, 5)}:00+08:00`).toISOString()
const tambahHari = (iso, n) => { const d = new Date(`${iso}T00:00:00`); d.setDate(d.getDate() + n); return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}` }
function aturBatas() {
  if (isi.value.jenis === 'keluar') {
    const d = new Date(Date.now() + 4 * 3600000 + 8 * 3600000); tglB.value = d.toISOString().slice(0, 10); jamB.value = d.toISOString().slice(11, 16)
  } else { tglB.value = tambahHari(hariIniISO(), 1); jamB.value = '17:00' }
}
watch(buka, async (v) => {
  if (!v) return
  if (!iz.hakDimuat) await iz.muatHak().catch(() => {})
  isi.value = { jenis: 'pulang', alasan: '', penjemput: '', hubungan_penjemput: '', hp_penjemput: '', catatan: '' }; aturBatas()
})
watch(() => isi.value.jenis, () => { if (buka.value) aturBatas() })
const lama = computed(() => (tglB.value ? Math.max(1, Math.ceil((new Date(gabung(tglB.value, jamB.value)) - Date.now()) / 86400000)) : 0))
const lewatBatas = computed(() => lama.value > Number(iz.pengaturan.batas_hari_bidang || 2) && !sc.hak.puncak)

async function simpan() {
  const x = isi.value
  if (x.alasan.trim().length < 5) return ui.toast('Tuliskan alasan izin (minimal 5 huruf).', 'galat')
  if (x.jenis === 'pulang' && x.penjemput.trim().length < 2) return ui.toast('Isi nama penjemput untuk izin pulang.', 'galat')
  if (lewatBatas.value) return ui.toast(`Izin lebih dari ${iz.pengaturan.batas_hari_bidang} hari memerlukan Direktur/Wakil Direktur.`, 'galat')
  proses.value = true
  try {
    const hasil = await sc.izinCepat({ student_id: props.santri.student_id, jenis: x.jenis, alasan: x.alasan.trim(), penjemput: x.penjemput.trim(),
      hubungan_penjemput: x.hubungan_penjemput.trim(), hp_penjemput: x.hp_penjemput.trim(), catatan: x.catatan.trim(), kembali_batas: gabung(tglB.value, jamB.value) })
    ui.toast('Izin cepat berlaku. Security dapat mencatat santri keluar.'); buka.value = false; emit('selesai', hasil)
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
</script>
<template>
  <LembarBawah v-model="buka" judul="Izin cepat">
    <div v-if="santri" class="space-y-3 pb-2">
      <p class="flex items-start gap-2 rounded-xl bg-permukaan2 p-3 text-xs text-teks2"><PhInfo :size="16" class="mt-0.5 shrink-0" />
        Izin cepat langsung berlaku tanpa menunggu persetujuan berjenjang. Gunakan untuk kejadian mendadak di gerbang. Izin yang masih menunggu pada waktu yang sama otomatis digantikan.</p>
      <p class="text-sm"><b>{{ santri.nama }}</b> · {{ santri.nis }} · {{ santri.kelas || '–' }} · {{ santri.kamar || '–' }}</p>
      <div class="grid grid-cols-2 gap-2" role="radiogroup" aria-label="Jenis izin">
        <button v-for="j in [{ k: 'pulang', n: 'Pulang (menginap)', i: PhHouseLine }, { k: 'keluar', n: 'Keluar beberapa jam', i: PhPersonSimpleWalk }]" :key="j.k" type="button" role="radio" :aria-checked="isi.jenis === j.k"
          :class="['flex min-h-[48px] items-center gap-2 rounded-xl border px-3 text-sm font-semibold', isi.jenis === j.k ? 'border-[#3B4CB0] bg-[#3B4CB0]/10 text-teks' : 'border-garis text-teks2']" @click="isi.jenis = j.k">
          <component :is="j.i" :size="20" weight="duotone" /> {{ j.n }}</button>
      </div>
      <div><label class="label-isian" for="ic-al">Alasan<span class="text-merah"> *</span></label><input id="ic-al" v-model="isi.alasan" class="isian" placeholder="Contoh: dijemput mendadak, keluarga sakit" /></div>
      <div class="grid gap-3 sm:grid-cols-2">
        <div><label class="label-isian" for="ic-pj">Penjemput<span v-if="isi.jenis === 'pulang'" class="text-merah"> *</span></label><input id="ic-pj" v-model="isi.penjemput" class="isian" placeholder="Nama penjemput" /></div>
        <div><label class="label-isian" for="ic-hb">Hubungan</label><input id="ic-hb" v-model="isi.hubungan_penjemput" class="isian" placeholder="Ayah, ibu, paman" /></div>
      </div>
      <div><label class="label-isian" for="ic-hp">Nomor HP penjemput</label><input id="ic-hp" v-model="isi.hp_penjemput" inputmode="tel" class="isian" placeholder="08…" /></div>
      <div class="grid gap-3 sm:grid-cols-2"><InputTanggal v-model="tglB" label="Batas kembali (tanggal)" wajib /><InputJam v-model="jamB" label="Batas kembali (jam)" /></div>
      <p class="text-xs" :class="lewatBatas ? 'font-semibold text-merah' : 'text-teks3'">Lama izin {{ lama }} hari{{ lewatBatas ? ` — lebih dari ${iz.pengaturan.batas_hari_bidang} hari hanya dapat dibuat Direktur/Wakil Direktur.` : '. Waktu keluar: sekarang.' }}</p>
      <textarea v-model="isi.catatan" rows="2" class="isian" placeholder="Catatan (opsional)" aria-label="Catatan izin cepat" />
      <button class="tombol-utama w-full" :disabled="proses || lewatBatas" @click="simpan"><PhLightning :size="20" weight="bold" /> {{ proses ? 'Menyimpan…' : 'Berlakukan izin sekarang' }}</button>
    </div>
  </LembarBawah>
</template>
