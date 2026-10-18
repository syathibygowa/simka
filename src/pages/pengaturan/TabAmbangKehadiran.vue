<!-- SIMKA PRO | src/pages/pengaturan/TabAmbangKehadiran.vue | v1.0 | 14.3.0: pengaturan ambang warna kehadiran | 17/10/2026 -->
<script setup>
// Ambang kehadiran: baris pegawai/santri dengan persentase kehadiran di bawah batas diwarnai merah otomatis
// (laporan kehadiran, rekap absensi, rekap per mapel, lembar nilai). Warna dapat ikut pada cetakan dan unduhan Excel.
import { ref, onMounted } from 'vue'
import { PhTrafficSignal, PhFloppyDisk } from '@phosphor-icons/vue'
import { useAmbang } from '@/stores/ambang'
import { useUI } from '@/stores/ui'

const amb = useAmbang(); const ui = useUI()
const f = ref(null); const proses = ref(false)
onMounted(async () => { f.value = { ...(await amb.muat(true)) } })
async function simpan() {
  for (const k of ['batas_pegawai', 'batas_santri']) { const n = Number(f.value[k]); if (!Number.isInteger(n) || n < 1 || n > 100) return ui.toast('Batas kehadiran harus 1–100%.', 'galat') }
  proses.value = true
  try { f.value = { ...(await amb.simpan({ ...f.value, batas_pegawai: Number(f.value.batas_pegawai), batas_santri: Number(f.value.batas_santri) })) }; ui.toast('Ambang kehadiran disimpan.') }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
const contoh = [96, 84, 78, 61]
</script>
<template>
  <section v-if="f" class="kartu w-beranda max-w-3xl p-4 sm:p-5">
    <h2 class="judul-bagian flex items-center gap-2"><PhTrafficSignal :size="22" weight="duotone" style="color: var(--c)" /> Ambang kehadiran</h2>
    <p class="mt-1 text-sm text-teks2">Baris dengan persentase kehadiran <b>di bawah batas</b> otomatis berwarna merah di laporan kehadiran pegawai dan santri, rekap absensi, rekap kehadiran per mapel, dan lembar nilai.</p>
    <div class="mt-4 grid gap-3 sm:grid-cols-2">
      <div><label class="label-isian" for="ab-peg">Batas kehadiran pegawai (%)</label><input id="ab-peg" v-model="f.batas_pegawai" type="number" min="1" max="100" class="isian tabular-nums" /></div>
      <div><label class="label-isian" for="ab-san">Batas kehadiran santri (%)</label><input id="ab-san" v-model="f.batas_santri" type="number" min="1" max="100" class="isian tabular-nums" /></div>
    </div>
    <div class="mt-3 space-y-2">
      <label class="flex min-h-[52px] items-center gap-3 rounded-xl border border-garis px-3 text-sm"><input v-model="f.aktif" type="checkbox" class="h-5 w-5 shrink-0 accent-[#C7332F]" />
        <span><b>Aktifkan warna otomatis</b><span class="block text-xs text-teks3">Matikan bila tidak ingin ada pewarnaan sama sekali.</span></span></label>
      <label :class="['flex min-h-[52px] items-center gap-3 rounded-xl border border-garis px-3 text-sm', !f.aktif && 'opacity-50']"><input v-model="f.cetak" type="checkbox" class="h-5 w-5 shrink-0 accent-[#C7332F]" :disabled="!f.aktif" />
        <span><b>Warna ikut pada cetakan</b><span class="block text-xs text-teks3">Baris terkait berlatar merah muda di dokumen F4 (perlu printer berwarna; di printer hitam-putih tampil abu-abu).</span></span></label>
      <label :class="['flex min-h-[52px] items-center gap-3 rounded-xl border border-garis px-3 text-sm', !f.aktif && 'opacity-50']"><input v-model="f.unduh" type="checkbox" class="h-5 w-5 shrink-0 accent-[#C7332F]" :disabled="!f.aktif" />
        <span><b>Warna ikut pada unduhan Excel</b><span class="block text-xs text-teks3">Baris terkait berlatar merah muda di berkas .xlsx.</span></span></label>
    </div>
    <div class="mt-4 rounded-xl border border-garis p-3">
      <p class="mb-2 text-xs font-bold text-teks3">Contoh (batas santri {{ f.batas_santri }}%)</p>
      <table class="w-full text-sm"><tbody>
        <tr v-for="(p, i) in contoh" :key="p" :class="f.aktif && p < Number(f.batas_santri) ? 'baris-ambang' : ''"><td class="px-2 py-1.5">Santri contoh {{ i + 1 }}</td>
          <td :class="['px-2 py-1.5 text-right tabular-nums', f.aktif && p < Number(f.batas_santri) ? 'persen-ambang' : '']">{{ p }}%</td></tr>
      </tbody></table>
    </div>
    <button class="tombol-utama mt-4" :disabled="proses" @click="simpan"><PhFloppyDisk :size="20" weight="duotone" /> Simpan</button>
  </section>
  <p v-else class="py-10 text-center text-teks3">Memuat…</p>
</template>
