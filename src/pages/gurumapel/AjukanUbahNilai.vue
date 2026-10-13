<!-- SIMKA PRO | src/pages/gurumapel/AjukanUbahNilai.vue | v1.0 | Fase 12 – Tahap 6 Permintaan ubah nilai guru | 13/10/2026 -->
<script setup>
// Lembar nilai terkunci (periode ditutup atau batas pengisian lewat): guru pengampu mengajukan perubahan nilai rapor,
// keterampilan, sikap, atau deskripsi per santri beserta alasan kepada pengelola nilai. Riwayat permintaan kelas–mapel ini
// tampil di bawahnya (menunggu dapat dibatalkan). Disetujui → nilai langsung diperbarui.
import { ref, computed, onMounted } from 'vue'
import { PhPencilLine, PhPaperPlaneTilt, PhArrowCounterClockwise } from '@phosphor-icons/vue'
import { useUbahNilai } from '@/stores/ubahNilai'
import { useUI } from '@/stores/ui'
import { STATUS_UBAH, ringkasUbah } from '@/lib/penilaian'
import { formatWaktu } from '@/lib/tanggal'
import LembarBawah from '@/components/LembarBawah.vue'

const props = defineProps({ L: { type: Object, required: true }, semester: { type: Number, required: true } })
const un = useUbahNilai(); const ui = useUI()
const riwayat = ref([]); const proses = ref(false)
async function muat() { try { riwayat.value = (await un.muat(null, props.L.tugas.assignment_id)).daftar || [] } catch { riwayat.value = [] } }
onMounted(muat)
const dua = computed(() => !!props.L.ketentuan?.pakai_keterampilan)
const lama = (sid) => (props.L.akhir || []).find((a) => a.student_id === sid) || {}
const lembar = ref(false); const f = ref({})
function buka(s = null) { const a = s ? lama(s.id) : {}; f.value = { student_id: s?.id || '', nilai: a.nilai ?? '', keterampilan: a.keterampilan ?? '', sikap: a.sikap || '', deskripsi: a.deskripsi || '', alasan: '' }; lembar.value = true }
function pilihSantri() { const a = lama(f.value.student_id); Object.assign(f.value, { nilai: a.nilai ?? '', keterampilan: a.keterampilan ?? '', sikap: a.sikap || '', deskripsi: a.deskripsi || '' }) }
async function kirim() {
  const v = f.value; const a = lama(v.student_id)
  if (!v.student_id) return ui.toast('Pilih santri.', 'galat')
  if (v.alasan.trim().length < 5) return ui.toast('Alasan perubahan wajib diisi (minimal 5 huruf).', 'galat')
  const p = { jenis: 'mapel', assignment_id: props.L.tugas.assignment_id, semester: props.semester, student_id: v.student_id, alasan: v.alasan.trim() }
  const beda = (x, y) => String(x ?? '') !== String(y ?? '')
  if (beda(v.nilai, a.nilai)) p.nilai = v.nilai === '' ? '' : Number(v.nilai)
  if (dua.value && beda(v.keterampilan, a.keterampilan)) p.keterampilan = v.keterampilan === '' ? '' : Number(v.keterampilan)
  if (beda(v.sikap, a.sikap)) p.sikap = v.sikap
  if (beda(v.deskripsi.trim(), a.deskripsi)) p.deskripsi = v.deskripsi.trim()
  if (Object.keys(p).length === 5) return ui.toast('Tidak ada nilai yang berubah.', 'galat')
  for (const k of ['nilai', 'keterampilan']) if (p[k] !== undefined && p[k] !== '' && !(p[k] >= 0 && p[k] <= 100)) return ui.toast('Nilai harus 0–100.', 'galat')
  proses.value = true
  try {
    const s = props.L.santri.find((x) => x.id === v.student_id)
    await un.ajukan(p, { lama: a, nis: s?.nis, nama: s?.nama, jenis_kelamin: s?.jenis_kelamin, kelas: props.L.tugas.kelas, mapel: props.L.tugas.mapel })
    lembar.value = false; ui.toast('Permintaan ubah nilai dikirim ke pengelola nilai.'); await muat()
  } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
async function batal(d) { try { await un.batal(d.id); ui.toast('Permintaan dibatalkan.'); await muat() } catch (e) { ui.toast(e.message, 'galat') } }
defineExpose({ buka })
</script>
<template>
  <section class="kartu w-pengajuan mt-3 p-4">
    <div class="flex flex-wrap items-center gap-2">
      <p class="min-w-[200px] flex-1 text-sm text-teks2">Periode sudah ditutup. Bila ada nilai yang perlu diperbaiki, ajukan perubahan kepada pengelola nilai beserta alasannya.</p>
      <button class="tombol-utama min-h-[40px] px-3 text-sm" @click="buka()"><PhPencilLine :size="18" weight="duotone" /> Ajukan perubahan nilai</button>
    </div>
    <ul v-if="riwayat.length" class="mt-3 divide-y divide-garis rounded-xl border border-garis">
      <li v-for="d in riwayat" :key="d.id" class="flex flex-wrap items-center gap-2 px-3 py-2 text-sm">
        <span :class="['lencana', 'w-' + STATUS_UBAH[d.status].w]">{{ STATUS_UBAH[d.status].n }}</span>
        <span class="min-w-0 flex-1"><b>{{ d.nama }}</b> · {{ ringkasUbah(d.perubahan) }}<span class="block text-xs text-teks3">{{ formatWaktu(d.diajukan_pada) }} · {{ d.alasan }}{{ d.catatan_putusan ? ` · Putusan: ${d.catatan_putusan}` : '' }}</span></span>
        <button v-if="d.boleh_batal" class="tombol-garis min-h-[34px] px-2 text-xs" @click="batal(d)"><PhArrowCounterClockwise :size="14" /> Batalkan</button>
      </li>
    </ul>

    <LembarBawah v-model="lembar" judul="Ajukan perubahan nilai">
      <div class="space-y-3 pb-2">
        <div><label class="label-isian" for="un-santri">Santri</label>
          <select id="un-santri" v-model="f.student_id" class="isian" @change="pilihSantri"><option value="">Pilih santri</option>
            <option v-for="s in L.santri" :key="s.id" :value="s.id">{{ s.nama }} ({{ s.nis }})</option></select></div>
        <template v-if="f.student_id">
          <p class="text-xs text-teks3">Nilai saat ini: rapor {{ lama(f.student_id).nilai ?? '–' }}{{ dua ? ` · keterampilan ${lama(f.student_id).keterampilan ?? '–'}` : '' }} · sikap {{ lama(f.student_id).sikap || '–' }}. Ubah yang perlu saja.</p>
          <div class="grid grid-cols-2 gap-3 sm:grid-cols-3">
            <div><label class="label-isian" for="un-nilai">Nilai rapor</label><input id="un-nilai" v-model="f.nilai" type="number" min="0" max="100" class="isian tabular-nums" /></div>
            <div v-if="dua"><label class="label-isian" for="un-ket">Keterampilan</label><input id="un-ket" v-model="f.keterampilan" type="number" min="0" max="100" class="isian tabular-nums" /></div>
            <div><label class="label-isian" for="un-sikap">Sikap</label>
              <select id="un-sikap" v-model="f.sikap" class="isian"><option value="">–</option><option v-for="p in L.sikap_pilihan" :key="p.huruf" :value="p.huruf">{{ p.huruf }} · {{ p.sebutan }}</option></select></div>
          </div>
          <div><label class="label-isian" for="un-desk">Deskripsi (kosong = otomatis)</label><textarea id="un-desk" v-model="f.deskripsi" rows="2" class="isian text-sm" /></div>
        </template>
        <div><label class="label-isian" for="un-alasan">Alasan perubahan</label><textarea id="un-alasan" v-model="f.alasan" rows="2" class="isian" placeholder="Contoh: nilai remedial belum dimasukkan" /></div>
        <button class="tombol-utama w-full" :disabled="proses" @click="kirim"><PhPaperPlaneTilt :size="20" weight="duotone" /> {{ proses ? 'Mengirim…' : 'Kirim permintaan' }}</button>
      </div>
    </LembarBawah>
  </section>
</template>
