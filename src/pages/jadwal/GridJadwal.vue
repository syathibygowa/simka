<!-- SIMKA PRO | src/pages/jadwal/GridJadwal.vue | v1.0 | Fase 4 – Tahap 5 Jadwal pelajaran dan jurnal mengajar | 04/10/2026 -->
<script setup>
// Kisi jadwal pekanan (Senin–Sabtu; Jumat memakai jam pelajaran Jumat). Mode "kelas": sel berisi mapel dan guru;
// mode "guru": sel berisi kelas dan mapel (gabungan jenjang Wustha dan SMA). Sel dapat diketuk bila boleh diubah.
import { computed, ref } from 'vue'
import { HARI } from '@/lib/tanggal'
import { HARI_SEKOLAH, jenisHari, jamPendek } from '@/lib/jadwal'
import { useJadwal } from '@/stores/jadwal'
import { useKelompokSantri } from '@/stores/kelompokSantri'

const props = defineProps({ mode: { type: String, default: 'kelas' }, groupId: String, employeeId: String, jenjang: { type: String, default: 'wustha' }, bolehUbah: Boolean })
const emit = defineEmits(['sel'])
// HP: satu hari per tampilan (pilih hari); desktop: enam kolom
const hariIni = new Date(Date.now() + 8 * 3600000).getUTCDay()
const hariHP = ref(hariIni >= 1 && hariIni <= 6 ? hariIni : 1)
const jd = useJadwal(); const kel = useKelompokSantri()
const WARNA = ['laporan', 'tahfizh', 'santri', 'pegawai', 'pengajuan', 'gaji', 'agenda', 'klinik', 'shift', 'berkas', 'verval', 'rekap']
const warnaMapel = (id) => WARNA[Math.abs([...String(id)].reduce((n, c) => n * 31 + c.charCodeAt(0), 7)) % WARNA.length]
const singkat = (nama) => String(nama || '').replace(/^(Ust\.|Ustzh\.)\s*/, '').split(',')[0]

const kolom = computed(() => HARI_SEKOLAH.map((h) => {
  if (props.mode === 'kelas') {
    const jam = jd.jamUntuk(props.jenjang, jenisHari(h))
    return { hari: h, sel: jam.map((p) => ({ p, s: jd.jadwal.find((x) => x.group_id === props.groupId && x.hari === h && x.period_id === p.id) })) }
  }
  // Mode guru: semua jam yang diisi guru ini pada hari itu, urut jam mulai
  const isi = jd.jadwal.filter((x) => x.employee_id === props.employeeId && x.hari === h)
    .map((s) => ({ p: jd.jam.find((p) => p.id === s.period_id), s })).filter((x) => x.p).sort((a, b) => a.p.jam_mulai.localeCompare(b.p.jam_mulai))
  return { hari: h, sel: isi }
}))
function info(s) {
  const t = jd.cariPenugasan(s.assignment_id); const m = jd.cariMapel(t?.subject_id)
  return { mapel: m?.nama || '–', kode: m?.kode || '', guru: singkat(t?.nama_guru), kelas: kel.cari(t?.group_id)?.nama || '', warna: warnaMapel(t?.subject_id) }
}
</script>
<template>
  <div>
    <div class="mb-3 flex gap-1.5 overflow-x-auto pb-1 sm:hidden" role="tablist" aria-label="Pilih hari">
      <button v-for="h in HARI_SEKOLAH" :key="h" role="tab" :aria-selected="hariHP === h" @click="hariHP = h"
        :class="['min-h-[40px] shrink-0 rounded-full border px-3.5 text-sm font-semibold', hariHP === h ? 'border-transparent bg-[#0F5E8C] text-white dark:bg-[#7DD3FC] dark:text-[#082F49]' : 'border-garis bg-permukaan text-teks2']">{{ HARI[h] }}</button>
    </div>
    <div class="sm:overflow-x-auto">
      <div class="sm:grid sm:min-w-[760px] sm:grid-cols-6 sm:gap-2">
        <div v-for="k in kolom" :key="k.hari" :class="['space-y-1.5', k.hari !== hariHP && 'hidden sm:block']">
          <p :class="['hidden rounded-xl py-2 text-center text-sm font-bold sm:block', k.hari === 5 ? 'bg-[#1E7D4F]/10 text-[#1E7D4F] dark:text-[#5BD69A]' : 'bg-permukaan2 text-teks2']">{{ HARI[k.hari] }}</p>
          <template v-for="c in k.sel" :key="c.p.id">
            <p v-if="c.p.jenis === 'istirahat'" class="rounded-lg px-2 py-1 text-center text-[11px] text-teks3" style="background: repeating-linear-gradient(45deg, transparent 0 6px, rgb(var(--garis)) 6px 7px)">
              {{ jamPendek(c.p.jam_mulai) }} {{ c.p.nama }}</p>
            <button v-else type="button" :disabled="!bolehUbah" @click="emit('sel', { hari: k.hari, period: c.p, sesi: c.s })"
              :class="['block w-full rounded-xl border p-2 text-left transition', c.s ? 'w-' + info(c.s).warna : 'border-dashed border-garis', bolehUbah && 'hover:shadow-kartu']"
              :style="c.s ? 'border-color: color-mix(in srgb, var(--c) 40%, transparent); background: color-mix(in srgb, var(--c) 10%, rgb(var(--permukaan)))' : ''">
              <span class="block text-[11px] tabular-nums text-teks3">{{ c.p.nama.replace('Jam ke-', 'Ke-') }} · {{ jamPendek(c.p.jam_mulai) }}–{{ jamPendek(c.p.jam_selesai) }}</span>
              <template v-if="c.s">
                <span class="block truncate text-sm font-bold" style="color: var(--c)" :title="info(c.s).mapel">{{ mode === 'guru' ? info(c.s).kelas : info(c.s).mapel }}</span>
                <span class="block truncate text-xs text-teks2">{{ mode === 'guru' ? info(c.s).mapel : info(c.s).guru }}</span>
              </template>
              <span v-else class="block text-xs text-teks3">{{ bolehUbah ? '+ Isi' : 'Kosong' }}</span>
            </button>
          </template>
          <p v-if="!k.sel.length" class="py-3 text-center text-xs text-teks3">{{ mode === 'guru' ? 'Tidak mengajar' : 'Belum ada jam' }}</p>
        </div>
      </div>
    </div>
  </div>
</template>
