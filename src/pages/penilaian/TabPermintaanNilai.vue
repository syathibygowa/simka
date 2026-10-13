<!-- SIMKA PRO | src/pages/penilaian/TabPermintaanNilai.vue | v1.0 | Fase 12 – Tahap 6 Permintaan ubah nilai | 13/10/2026 -->
<script setup>
// Penilaian → Permintaan: permintaan ubah nilai setelah periode ditutup (nilai mapel dari guru pengampu, nilai UTAS dari
// penguji). Pengelola nilai menyetujui (nilai langsung diperbarui; mode akumulasi memakai nilai koreksi) atau menolak
// dengan alasan. Daftar sekaligus menjadi riwayat perubahan nilai dan dapat dicetak.
import { ref, computed, onMounted } from 'vue'
import { PhCheck, PhX, PhPrinter, PhArrowCounterClockwise, PhInfo } from '@phosphor-icons/vue'
import { useUbahNilai } from '@/stores/ubahNilai'
import { useSesi } from '@/stores/sesi'
import { useUI } from '@/stores/ui'
import { STATUS_UBAH, LABEL_UBAH } from '@/lib/penilaian'
import { formatWaktu, formatPanjang, hariIniISO } from '@/lib/tanggal'
import LembarBawah from '@/components/LembarBawah.vue'
import DokumenCetak from '@/components/cetak/DokumenCetak.vue'
import TandaTangan from '@/components/cetak/TandaTangan.vue'

const un = useUbahNilai(); const sesi = useSesi(); const ui = useUI()
const saring = ref('menunggu'); const galat = ref(''); const proses = ref('')
async function muat() { galat.value = ''; try { await un.muat(saring.value === 'semua' ? null : saring.value) } catch (e) { galat.value = e.message } }
onMounted(muat)
const daftar = computed(() => un.data?.daftar || [])
const SARING = [{ k: 'menunggu', n: 'Menunggu' }, { k: 'disetujui', n: 'Disetujui' }, { k: 'ditolak', n: 'Ditolak' }, { k: 'semua', n: 'Semua' }]
const nilaiTeks = (v) => (v == null || v === '' ? '–' : String(v))

async function setujui(d) {
  if (!(await ui.konfirmasi({ judul: 'Setujui perubahan nilai?', pesan: `Nilai ${d.nama} (${d.mapel}) langsung diperbarui dan guru/penguji diberi tahu.`, ya: 'Setujui' }))) return
  proses.value = d.id
  try { await un.putuskan(d.id, true); ui.toast('Perubahan nilai disetujui dan diterapkan.'); await muat() } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = '' }
}
const lembarTolak = ref(false); const dTolak = ref(null); const alasanTolak = ref('')
function bukaTolak(d) { dTolak.value = d; alasanTolak.value = ''; lembarTolak.value = true }
async function tolak() {
  if (alasanTolak.value.trim().length < 3) return ui.toast('Tuliskan alasan penolakan.', 'galat')
  proses.value = dTolak.value.id
  try { await un.putuskan(dTolak.value.id, false, alasanTolak.value.trim()); lembarTolak.value = false; ui.toast('Permintaan ditolak.'); await muat() } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = '' }
}
async function batal(d) {
  if (!(await ui.konfirmasi({ judul: 'Batalkan permintaan?', pesan: 'Permintaan ditarik dan tidak diproses.', ya: 'Batalkan', bahaya: true }))) return
  try { await un.batal(d.id); ui.toast('Permintaan dibatalkan.'); await muat() } catch (e) { ui.toast(e.message, 'galat') }
}
const pratinjau = ref(false)
</script>
<template>
  <div class="space-y-4">
    <div class="kartu flex flex-wrap items-center gap-2 p-3">
      <div class="flex gap-1 overflow-x-auto rounded-2xl bg-permukaan2 p-1" role="radiogroup" aria-label="Saring status">
        <button v-for="s in SARING" :key="s.k" type="button" role="radio" :aria-checked="saring === s.k" @click="saring = s.k; muat()"
          :class="['min-h-[38px] shrink-0 rounded-xl px-3 text-sm font-semibold', saring === s.k ? 'bg-permukaan text-teks shadow-kartu' : 'text-teks2']">{{ s.n }}</button>
      </div>
      <p class="min-w-[200px] flex-1 text-xs text-teks3">Guru/penguji mengajukan perubahan setelah periode ditutup. Persetujuan langsung memperbarui nilai; semua permintaan tersimpan sebagai riwayat.</p>
      <button class="tombol-garis min-h-[40px] px-3 text-sm" :disabled="!daftar.length" @click="pratinjau = true"><PhPrinter :size="18" weight="duotone" /> Cetak</button>
    </div>
    <div v-if="galat" class="kartu w-klinik p-5 text-sm font-semibold" style="color: var(--c)">Permintaan gagal dimuat: {{ galat }} Pastikan migrasi SQL 8800 sudah dijalankan.</div>
    <p v-else-if="un.data && !daftar.length" class="kartu p-8 text-center text-sm text-teks3">Tidak ada permintaan {{ saring === 'semua' ? '' : STATUS_UBAH[saring]?.n.toLowerCase() }}.</p>
    <ul v-else class="grid gap-3 xl:grid-cols-2">
      <li v-for="d in daftar" :key="d.id" :class="['kartu flex flex-col gap-2 p-4', 'w-' + STATUS_UBAH[d.status].w]">
        <div class="flex flex-wrap items-start gap-2">
          <div class="min-w-0 flex-1">
            <p class="font-bold">{{ d.nama }} <span class="text-xs font-normal text-teks3">{{ d.nis }} · {{ d.jenis_kelamin }} · {{ d.kelas || '–' }}</span></p>
            <p class="text-sm text-teks2">{{ d.mapel }} · semester {{ d.semester }}<template v-if="d.mode === 'akumulasi'"> · nilai koreksi (mode akumulasi)</template></p>
          </div>
          <span :class="['lencana', 'w-' + STATUS_UBAH[d.status].w]">{{ STATUS_UBAH[d.status].n }}</span>
        </div>
        <ul class="space-y-1 rounded-xl bg-permukaan2 p-3 text-sm">
          <li v-for="(v, k) in d.perubahan" :key="k" class="flex flex-wrap gap-x-2"><b class="w-28 shrink-0">{{ LABEL_UBAH[k] || k }}</b>
            <span class="text-teks3 line-through">{{ nilaiTeks(v.lama) }}</span><span>→</span><b style="color: var(--c)">{{ nilaiTeks(v.baru) }}</b></li>
        </ul>
        <p class="text-sm"><span class="text-teks3">Alasan:</span> {{ d.alasan }}</p>
        <p class="text-xs text-teks3">Diajukan {{ d.pengaju || '–' }} · {{ formatWaktu(d.diajukan_pada) }}</p>
        <p v-if="d.diputus_pada" class="text-xs text-teks3">{{ STATUS_UBAH[d.status].n }} oleh {{ d.pemutus || '–' }} · {{ formatWaktu(d.diputus_pada) }}{{ d.catatan_putusan ? ` · "${d.catatan_putusan}"` : '' }}</p>
        <div v-if="d.boleh_putus || d.boleh_batal" class="mt-auto flex flex-wrap gap-2 pt-1">
          <template v-if="d.boleh_putus">
            <button class="tombol-utama min-h-[40px] flex-1 px-3 text-sm" :disabled="!!proses" @click="setujui(d)"><PhCheck :size="18" weight="bold" /> Setujui</button>
            <button class="tombol-garis min-h-[40px] flex-1 px-3 text-sm" :disabled="!!proses" @click="bukaTolak(d)"><PhX :size="18" weight="bold" /> Tolak</button>
          </template>
          <button v-if="d.boleh_batal" class="tombol-garis min-h-[40px] px-3 text-sm" @click="batal(d)"><PhArrowCounterClockwise :size="18" /> Batalkan permintaan</button>
        </div>
      </li>
    </ul>

    <LembarBawah v-model="lembarTolak" :judul="dTolak ? `Tolak permintaan · ${dTolak.nama}` : ''">
      <div class="space-y-3 pb-2">
        <p class="flex gap-2 text-sm text-teks2"><PhInfo :size="18" class="mt-0.5 shrink-0" /> Alasan penolakan dikirim ke pengaju sebagai notifikasi.</p>
        <textarea v-model="alasanTolak" rows="3" class="isian" placeholder="Contoh: nilai sudah sesuai berita acara ujian" aria-label="Alasan penolakan" />
        <button class="tombol-utama w-full" :disabled="!!proses" @click="tolak"><PhX :size="18" weight="bold" /> Tolak permintaan</button>
      </div>
    </LembarBawah>

    <DokumenCetak kop="pondok" judul="Riwayat Permintaan Ubah Nilai" :subjudul="`${SARING.find((s) => s.k === saring)?.n} · keadaan ${formatPanjang(hariIniISO())}`" v-model:pratinjau="pratinjau"
      :pencetak="sesi.pengguna?.nama_lengkap" mendatar>
      <table class="tabel kecil"><colgroup><col style="width:4%"><col style="width:9%"><col style="width:8%"><col style="width:15%"><col style="width:6%"><col style="width:12%"><col style="width:15%"><col style="width:15%"><col style="width:16%"></colgroup>
        <thead><tr><th>No.</th><th>Diajukan</th><th>NIS</th><th>Nama</th><th>Kelas</th><th>Mapel</th><th>Perubahan</th><th>Alasan</th><th>Status</th></tr></thead>
        <tbody><tr v-for="(d, i) in daftar" :key="d.id"><td class="tengah">{{ i + 1 }}</td><td>{{ formatWaktu(d.diajukan_pada) }}<br>{{ d.pengaju }}</td><td>{{ d.nis }}</td><td>{{ d.nama }}</td>
          <td class="tengah">{{ d.kelas || '–' }}</td><td>{{ d.mapel }}</td><td>{{ Object.entries(d.perubahan).map(([k, v]) => `${LABEL_UBAH[k] || k}: ${nilaiTeks(v.lama)} → ${nilaiTeks(v.baru)}`).join('; ') }}</td>
          <td>{{ d.alasan }}</td><td>{{ STATUS_UBAH[d.status].n }}{{ d.pemutus ? ` oleh ${d.pemutus}` : '' }}{{ d.catatan_putusan ? `; ${d.catatan_putusan}` : '' }}</td></tr></tbody></table>
      <template #ttd><TandaTangan :kiri="{ pengantar: 'Mengetahui,', jabatan: 'Kepala Sekolah', nama: '' }" :kanan="{ jabatan: 'Pengelola Nilai', nama: sesi.pengguna?.nama_lengkap || '' }" /></template>
    </DokumenCetak>
  </div>
</template>
