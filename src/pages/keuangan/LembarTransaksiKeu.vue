<!-- SIMKA PRO | src/pages/keuangan/LembarTransaksiKeu.vue | v1.0 | 14.7.0: catat pengeluaran, pemasukan lain, dan pindah dana antarrekening | 18/10/2026 -->
<script setup>
// Isian transaksi keuangan di luar tagihan santri, dicatat langsung oleh pengelola keuangan (tanpa persetujuan):
//   keluar : pengeluaran (kategori dari Pengaturan), dari rekening/kas, penerima, nomor nota, foto nota (Google Drive)
//   masuk  : pemasukan lain (donasi, bantuan, dll.) ke rekening/kas
//   pindah : pindah dana antarrekening (mis. setor kas tunai ke bank)
// Tanggal bawaan hari ini. Nomor bukti kas (BKK/BKM) terbit otomatis.
import { ref, computed, watch } from 'vue'
import { PhFloppyDisk, PhCamera, PhWarning } from '@phosphor-icons/vue'
import { useKeuangan } from '@/stores/keuangan'
import { useUI } from '@/stores/ui'
import { hariIniISO } from '@/lib/tanggal'
import { rupiah, bacaRupiah, terbilang } from '@/lib/keuangan'
import { MODE_DEMO } from '@/lib/supabase'
import { unggahKeDrive, kompresGambar, namaRapi } from '@/lib/penyimpanan'
import LembarBawah from '@/components/LembarBawah.vue'
import InputTanggal from '@/components/InputTanggal.vue'

const props = defineProps({ jenis: { type: String, default: '' } })   // '' = tertutup; 'keluar' | 'masuk' | 'pindah'
const emit = defineEmits(['tutup', 'tersimpan'])
const keu = useKeuangan(); const ui = useUI()
const buka = computed({ get: () => !!props.jenis, set: (v) => !v && emit('tutup') })
const f = ref({}); const proses = ref(false); const foto = ref(null); const pratinjau = ref('')
const aktif = computed(() => keu.akun.filter((a) => a.aktif))
watch(() => props.jenis, async (j) => {
  if (!j) return
  if (!keu.akun.length) await keu.muatAkun().catch(() => {})
  const kas = aktif.value.find((a) => a.jenis === 'kas') || aktif.value[0]; const bank = aktif.value.find((a) => a.jenis === 'bank')
  f.value = { tanggal: hariIniISO(), account_id: kas?.id || '', kategori: '', uraian: '', jumlah: '', pihak: '', nomor_bukti: '', dari_id: kas?.id || '', ke_id: bank?.id || '', keterangan: '' }
  foto.value = null; pratinjau.value = ''
})
const JUDUL = { keluar: 'Catat pengeluaran', masuk: 'Catat pemasukan lain', pindah: 'Pindah dana antarrekening' }
const kategori = computed(() => (props.jenis === 'keluar' ? keu.pengaturan.kategori_keluar : keu.pengaturan.kategori_masuk) || [])
const jumlah = computed(() => bacaRupiah(f.value.jumlah) || 0)
const akunDipilih = computed(() => keu.akun.find((a) => a.id === (props.jenis === 'pindah' ? f.value.dari_id : f.value.account_id)))
const kurang = computed(() => props.jenis !== 'masuk' && akunDipilih.value && jumlah.value > Number(akunDipilih.value.saldo))
function pilihFoto(e) { const x = e.target.files?.[0]; e.target.value = ''; if (!x) return; if (!/^image\//.test(x.type)) return ui.toast('Pilih berkas foto.', 'galat'); foto.value = x; pratinjau.value = URL.createObjectURL(x) }
async function simpan() {
  if (jumlah.value <= 0) return ui.toast('Isi jumlah.', 'galat')
  if (f.value.tanggal > hariIniISO()) return ui.toast('Tanggal tidak boleh melewati hari ini.', 'galat')
  proses.value = true
  try {
    if (props.jenis === 'pindah') {
      if (!f.value.dari_id || !f.value.ke_id || f.value.dari_id === f.value.ke_id) throw new Error('Pilih rekening asal dan tujuan yang berbeda.')
      await keu.catatPindah({ tanggal: f.value.tanggal, dari_id: f.value.dari_id, ke_id: f.value.ke_id, jumlah: jumlah.value, keterangan: f.value.keterangan })
      ui.toast(`Pindah dana ${rupiah(jumlah.value)} dicatat.`)
    } else {
      if (!f.value.kategori) throw new Error('Pilih kategori.')
      if (f.value.uraian.trim().length < 3) throw new Error('Isi uraian transaksi.')
      let bukti_id = null
      if (foto.value && !MODE_DEMO) {
        const blob = await kompresGambar(foto.value, { maks: 1400, kualitas: 0.7 }); const t = f.value.tanggal
        bukti_id = await unggahKeDrive(blob, { nama: namaRapi(props.jenis === 'keluar' ? 'Nota-keluar' : 'Bukti-masuk', t, Date.now()) + '.jpg', kategori: 'keuangan_kas', folder: `SIMKA PRO/Keuangan/Kas/${t.slice(0, 4)}/${t.slice(5, 7)}`, retensiHari: 3650 })
      }
      const r = await keu.catatTransaksi({ arah: props.jenis, tanggal: f.value.tanggal, account_id: f.value.account_id, kategori: f.value.kategori, uraian: f.value.uraian.trim(),
        jumlah: jumlah.value, pihak: f.value.pihak, nomor_bukti: f.value.nomor_bukti, bukti_id })
      ui.toast(`${props.jenis === 'keluar' ? 'Pengeluaran' : 'Pemasukan'} ${rupiah(jumlah.value)} dicatat (${r.nomor}). Saldo kini ${rupiah(r.saldo)}.`)
    }
    await keu.muatAkun(); emit('tersimpan'); emit('tutup')
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
</script>
<template>
  <LembarBawah v-model="buka" :judul="JUDUL[jenis] || ''">
    <div v-if="jenis" :class="['space-y-3 pb-2', jenis === 'keluar' ? 'w-klinik' : jenis === 'masuk' ? 'w-presensi' : 'w-shift']">
      <InputTanggal v-model="f.tanggal" label="Tanggal" wajib />
      <template v-if="jenis === 'pindah'">
        <div class="grid gap-3 sm:grid-cols-2">
          <div><label class="label-isian" for="tk-dari">Dari</label><select id="tk-dari" v-model="f.dari_id" class="isian"><option v-for="a in aktif" :key="a.id" :value="a.id">{{ a.nama }} ({{ rupiah(a.saldo) }})</option></select></div>
          <div><label class="label-isian" for="tk-ke">Ke</label><select id="tk-ke" v-model="f.ke_id" class="isian"><option v-for="a in aktif" :key="a.id" :value="a.id">{{ a.nama }}</option></select></div>
        </div>
      </template>
      <div v-else><label class="label-isian" for="tk-akun">{{ jenis === 'keluar' ? 'Dibayar dari' : 'Masuk ke' }}</label>
        <select id="tk-akun" v-model="f.account_id" class="isian"><option v-for="a in aktif" :key="a.id" :value="a.id">{{ a.nama }} (saldo {{ rupiah(a.saldo) }})</option></select></div>
      <div><label class="label-isian" for="tk-jml">Jumlah (Rp) <span class="text-merah">*</span></label>
        <input id="tk-jml" v-model="f.jumlah" inputmode="numeric" class="isian text-lg font-bold tabular-nums" placeholder="0" />
        <p v-if="jumlah" class="mt-1 text-xs italic text-teks3">{{ terbilang(jumlah) }}</p>
        <p v-if="kurang" class="mt-1 flex items-center gap-1 text-xs font-semibold text-merah"><PhWarning :size="14" /> Melebihi saldo {{ akunDipilih.nama }} ({{ rupiah(akunDipilih.saldo) }}). Periksa kembali sebelum menyimpan.</p></div>
      <template v-if="jenis !== 'pindah'">
        <div><label class="label-isian" for="tk-kat">Kategori <span class="text-merah">*</span></label>
          <select id="tk-kat" v-model="f.kategori" class="isian"><option value="" disabled>Pilih kategori</option><option v-for="k in kategori" :key="k" :value="k">{{ k }}</option></select></div>
        <div><label class="label-isian" for="tk-ur">Uraian <span class="text-merah">*</span></label>
          <textarea id="tk-ur" v-model="f.uraian" rows="2" class="isian" :placeholder="jenis === 'keluar' ? 'Contoh: belanja bahan makanan pekan pertama' : 'Contoh: infak pembangunan dari alumni'" /></div>
        <div class="grid gap-3 sm:grid-cols-2">
          <div><label class="label-isian" for="tk-ph">{{ jenis === 'keluar' ? 'Dibayarkan kepada' : 'Diterima dari' }}</label><input id="tk-ph" v-model="f.pihak" class="isian" /></div>
          <div><label class="label-isian" for="tk-nb">Nomor nota/bukti (tidak wajib)</label><input id="tk-nb" v-model="f.nomor_bukti" class="isian" /></div>
        </div>
        <div class="flex flex-wrap items-center gap-3">
          <img v-if="pratinjau" :src="pratinjau" alt="Foto nota" class="h-20 w-28 rounded-xl object-cover" />
          <label class="tombol-garis cursor-pointer"><PhCamera :size="20" weight="duotone" /> {{ pratinjau ? 'Ganti foto' : 'Foto nota (opsional)' }}<input type="file" accept="image/*" capture="environment" class="sr-only" @change="pilihFoto" /></label>
        </div>
      </template>
      <div v-else><label class="label-isian" for="tk-ket">Keterangan</label><input id="tk-ket" v-model="f.keterangan" class="isian" placeholder="Contoh: setor tunai SPP ke bank" /></div>
      <p class="text-xs text-teks3">Dicatat langsung tanpa persetujuan dan tercatat di Audit Log. Kesalahan dibatalkan dengan alasan, bukan dihapus.</p>
      <button class="tombol-utama w-full" :disabled="proses" @click="simpan"><PhFloppyDisk :size="20" weight="duotone" /> {{ proses ? 'Menyimpan…' : 'Simpan' }}</button>
    </div>
  </LembarBawah>
</template>
