<!-- SIMKA PRO | src/pages/izin/LembarAjukanIzin.vue | v1.0 | Fase 6 – Tahap 2 Status otomatis dan perizinan santri | 06/10/2026 -->
<script setup>
// Ajukan atau ubah izin keluar/pulang santri. Pengusul memilih santri asuhannya (atau santri kamar terpilih),
// peran pengusul (menentukan kepala bidang pemutus), jenis izin, alasan, waktu keluar dan batas kembali, penjemput.
// Izin lebih dari batas hari (Ketentuan) naik ke Direktur/Wadir.
import { ref, computed, watch } from 'vue'
import { PhPaperPlaneTilt, PhMagnifyingGlass, PhHouseLine, PhPersonSimpleWalk, PhInfo, PhFloppyDisk } from '@phosphor-icons/vue'
import { useIzin } from '@/stores/izin'
import { useSantri } from '@/stores/santri'
import { useUI } from '@/stores/ui'
import { PERAN_PENGUSUL, UNIT_IZIN } from '@/lib/izin'
import { hariIniISO } from '@/lib/tanggal'
import LembarBawah from '@/components/LembarBawah.vue'
import InputTanggal from '@/components/InputTanggal.vue'
import InputJam from '@/components/InputJam.vue'

const buka = defineModel({ type: Boolean, default: false })
const props = defineProps({ izin: { type: Object, default: null }, calon: { type: Array, default: null }, peranUtama: { type: String, default: '' } })
const emit = defineEmits(['selesai'])
const iz = useIzin(); const san = useSantri(); const ui = useUI()
const santri = ref(null); const cari = ref(''); const opsi = ref([]); const peran = ref(''); const proses = ref(false)
const isi = ref({}); const tglK = ref(''); const jamK = ref(''); const tglB = ref(''); const jamB = ref('')

const isoLokal = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
const jamLokal = (d) => `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`
const pecah = (iso) => { const d = new Date(new Date(iso).getTime() + (new Date().getTimezoneOffset() + 480) * 60000); return [isoLokal(d), jamLokal(d)] } // WITA
const gabung = (t, j) => new Date(`${t}T${(j || '00:00').slice(0, 5)}:00+08:00`).toISOString()

function aturBatas() {
  const k = new Date(gabung(tglK.value || hariIniISO(), jamK.value || jamLokal(new Date())))
  const b = new Date(k.getTime() + (isi.value.jenis === 'keluar' ? 4 * 3600000 : Number(iz.pengaturan.lama_bawaan_hari || 2) * 86400000));
  [tglB.value, jamB.value] = pecah(b.toISOString())
}
watch(buka, async (v) => {
  if (!v) return
  await san.muat(); cari.value = ''
  if (props.izin) {
    const x = props.izin; santri.value = { id: x.student_id, nama: x.nama }
    isi.value = { jenis: x.jenis, alasan: x.alasan, penjemput: x.penjemput || '', hubungan_penjemput: x.hubungan_penjemput || '', hp_penjemput: x.hp_penjemput || '', catatan: x.catatan || '' };
    [tglK.value, jamK.value] = pecah(x.keluar_pada); [tglB.value, jamB.value] = pecah(x.kembali_batas)
  } else {
    santri.value = null; peran.value = ''; opsi.value = []
    isi.value = { jenis: 'pulang', alasan: '', penjemput: '', hubungan_penjemput: '', hp_penjemput: '', catatan: '' }
    tglK.value = hariIniISO(); jamK.value = ''; aturBatas()
  }
})
watch(() => isi.value.jenis, () => { if (buka.value && !props.izin) aturBatas() })
async function pilih(s) {
  santri.value = { id: s.id, nama: s.nama_lengkap }
  try { opsi.value = await iz.peranPengusul(s.id); peran.value = (opsi.value.find((o) => o.peran === props.peranUtama) || opsi.value[0])?.peran || '' } catch (e) { ui.toast(e.message, 'galat') }
  if (!opsi.value.length) ui.toast('Anda bukan pengasuh santri ini, sehingga tidak dapat mengusulkan izinnya.', 'galat')
}
const daftarCalon = computed(() => {
  const q = cari.value.toLowerCase().trim()
  const sumber = props.calon ? props.calon.map((c) => san.cari(c.id) || { id: c.id, nama_lengkap: c.nama, nis: c.nis }) : san.daftar.filter((s) => s.status === 'aktif')
  return sumber.filter((s) => !q || `${s.nama_lengkap} ${s.nis}`.toLowerCase().includes(q)).slice(0, 50)
})
const lamaHari = computed(() => {
  if (!tglK.value || !tglB.value) return 0
  return Math.max(1, Math.ceil((new Date(gabung(tglB.value, jamB.value)) - new Date(gabung(tglK.value, jamK.value || jamLokal(new Date())))) / 86400000))
})
const perluPimpinan = computed(() => lamaHari.value > Number(iz.pengaturan.batas_hari_bidang || 2))
const unitPilih = computed(() => opsi.value.find((o) => o.peran === peran.value)?.unit)

async function simpan() {
  const x = isi.value
  if (x.alasan.trim().length < 5) return ui.toast('Tuliskan alasan izin (minimal 5 huruf).', 'galat')
  const keluar = gabung(tglK.value, jamK.value || jamLokal(new Date())); const kembali = gabung(tglB.value, jamB.value || '17:00')
  if (new Date(kembali) <= new Date(keluar)) return ui.toast('Batas kembali harus setelah waktu keluar.', 'galat')
  if (x.jenis === 'pulang' && !x.penjemput.trim()) return ui.toast('Isi nama penjemput untuk izin pulang.', 'galat')
  proses.value = true
  try {
    const data = { ...x, keluar_pada: keluar, kembali_batas: kembali }
    if (props.izin) { await iz.ubah(props.izin.id, data); ui.toast('Izin diperbarui.') }
    else {
      if (!peran.value) throw new Error('Pilih peran pengusul.')
      await iz.ajukan({ ...data, student_id: santri.value.id, peran: peran.value })
      ui.toast(`Izin diajukan ke ${perluPimpinan.value ? UNIT_IZIN[unitPilih.value] + ', lalu Direktur/Wadir' : UNIT_IZIN[unitPilih.value]}.`)
    }
    buka.value = false; emit('selesai')
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
</script>
<template>
  <LembarBawah v-model="buka" :judul="izin ? 'Ubah izin santri' : 'Ajukan izin santri'">
    <div class="space-y-3 pb-2">
      <template v-if="!santri">
        <div class="relative"><PhMagnifyingGlass :size="20" class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-teks3" />
          <input v-model="cari" type="search" class="isian pl-11" placeholder="Cari nama atau NIS santri" aria-label="Cari santri" /></div>
        <ul class="max-h-[50dvh] divide-y divide-garis overflow-y-auto rounded-xl border border-garis">
          <li v-for="s in daftarCalon" :key="s.id"><button type="button" class="flex min-h-[50px] w-full items-center gap-3 px-3 text-left text-sm hover:bg-permukaan2" @click="pilih(s)">
            <span class="min-w-0 flex-1"><b class="block truncate">{{ s.nama_lengkap }}</b><span class="text-xs text-teks3">{{ s.nis }}</span></span></button></li>
          <li v-if="!daftarCalon.length" class="p-4 text-center text-sm text-teks3">Santri tidak ditemukan.</li>
        </ul>
      </template>
      <template v-else>
        <div class="flex items-center gap-2 rounded-xl bg-permukaan2 p-3">
          <b class="min-w-0 flex-1 truncate">{{ santri.nama }}</b>
          <button v-if="!izin" class="tombol-garis min-h-[36px] px-3 text-xs" @click="santri = null">Ganti</button>
        </div>
        <div v-if="!izin && opsi.length > 1"><label class="label-isian" for="iz-peran">Diusulkan sebagai</label>
          <select id="iz-peran" v-model="peran" class="isian"><option v-for="o in opsi" :key="o.peran" :value="o.peran">{{ PERAN_PENGUSUL[o.peran] }}{{ o.kelompok ? ' · ' + o.kelompok : '' }} → {{ UNIT_IZIN[o.unit] }}</option></select></div>
        <p v-else-if="!izin && unitPilih" class="text-xs text-teks3">Diusulkan sebagai {{ PERAN_PENGUSUL[peran].toLowerCase() }}; diputus {{ UNIT_IZIN[unitPilih] }}.</p>

        <div class="grid grid-cols-2 gap-1 rounded-2xl bg-permukaan2 p-1" role="radiogroup" aria-label="Jenis izin">
          <button v-for="j in [{ k: 'pulang', n: 'Pulang (menginap)', ikon: PhHouseLine }, { k: 'keluar', n: 'Keluar beberapa jam', ikon: PhPersonSimpleWalk }]" :key="j.k" type="button" role="radio"
            :aria-checked="isi.jenis === j.k" @click="isi.jenis = j.k"
            :class="['flex min-h-[44px] items-center justify-center gap-2 rounded-xl px-2 text-sm font-semibold', isi.jenis === j.k ? 'bg-permukaan text-teks shadow-kartu' : 'text-teks2']"><component :is="j.ikon" :size="20" weight="duotone" /> {{ j.n }}</button>
        </div>
        <div><label class="label-isian" for="iz-alasan">Alasan <span class="text-merah">*</span></label>
          <textarea id="iz-alasan" v-model="isi.alasan" rows="2" class="isian" placeholder="Contoh: menghadiri pernikahan kakak kandung" /></div>
        <div class="grid gap-3 sm:grid-cols-2"><InputTanggal v-model="tglK" label="Tanggal keluar" wajib /><InputJam v-model="jamK" label="Jam keluar" /></div>
        <div class="grid gap-3 sm:grid-cols-2"><InputTanggal v-model="tglB" label="Batas kembali (tanggal)" wajib /><InputJam v-model="jamB" label="Batas kembali (jam)" /></div>
        <p class="flex items-start gap-2 rounded-xl bg-permukaan2 p-3 text-xs text-teks2"><PhInfo :size="18" class="shrink-0" />
          Lama izin {{ lamaHari }} hari. {{ perluPimpinan ? `Lebih dari ${iz.pengaturan.batas_hari_bidang} hari: setelah kepala bidang, naik ke Direktur/Wakil Direktur.` : 'Cukup disetujui kepala bidang.' }}
          Selama izin berlaku, santri otomatis berstatus Izin di semua absensi.</p>
        <div class="grid gap-3 sm:grid-cols-3">
          <div><label class="label-isian" for="iz-pj">Penjemput<span v-if="isi.jenis === 'pulang'" class="text-merah"> *</span></label><input id="iz-pj" v-model="isi.penjemput" class="isian" placeholder="Nama penjemput" /></div>
          <div><label class="label-isian" for="iz-hb">Hubungan</label><input id="iz-hb" v-model="isi.hubungan_penjemput" class="isian" placeholder="Ayah, ibu, paman" /></div>
          <div><label class="label-isian" for="iz-hp">HP penjemput</label><input id="iz-hp" v-model="isi.hp_penjemput" inputmode="tel" class="isian" placeholder="08…" /></div>
        </div>
        <div><label class="label-isian" for="iz-cat">Catatan</label><input id="iz-cat" v-model="isi.catatan" class="isian" placeholder="Opsional" /></div>
        <button class="tombol-utama w-full" :disabled="proses || (!izin && !peran)" @click="simpan">
          <component :is="izin ? PhFloppyDisk : PhPaperPlaneTilt" :size="20" weight="duotone" /> {{ izin ? 'Simpan perubahan' : 'Ajukan izin' }}</button>
      </template>
    </div>
  </LembarBawah>
</template>
