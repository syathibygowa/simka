<!-- SIMKA PRO | src/pages/profil/KartuSlipProfil.vue | v1.0 | Fase 11 – Tahap 4 Slip gaji di Profil: buka atau minta ke Bendahara | 11/10/2026 -->
<script setup>
// Kartu "Slip gaji" di Profil. Bila slip terbuka untuk akun ini → tautan ke Gaji → Slip saya.
// Bila slip tidak ditampilkan di akun pegawai (arahan yayasan) → pegawai dapat meminta slip kepada Bendahara
// (pilih periode atau semua), lalu melihat status permintaannya. Tidak tampil bila belum pernah ada slip terbit.
import { ref, computed, onMounted } from 'vue'
import { PhReceipt, PhPaperPlaneTilt, PhCaretRight } from '@phosphor-icons/vue'
import { useGaji } from '@/stores/gaji'
import { useUI } from '@/stores/ui'
import { formatPendek } from '@/lib/tanggal'
import LembarBawah from '@/components/LembarBawah.vue'

const gaji = useGaji(); const ui = useUI()
const isi = ref(null); const periode = ref([]); const siap = ref(false)
async function muat() {
  try { [isi.value, periode.value] = await Promise.all([gaji.slipSaya(), gaji.periodeSaya()]) } catch { isi.value = null } finally { siap.value = true }
}
onMounted(muat)
const tampil = computed(() => siap.value && isi.value && (isi.value.slip?.length || periode.value.length || isi.value.permintaan?.length))
const STATUS = { menunggu: 'Menunggu Bendahara', dibuka: 'Dibukakan – lihat di menu Gaji', dicetak: 'Disiapkan tercetak – ambil di Bendahara', ditolak: 'Ditolak' }
const f = ref(null); const proses = ref(false)
async function kirim() {
  proses.value = true
  try { await gaji.mintaSlip(f.value.periode || null, f.value.catatan); ui.toast('Permintaan slip terkirim kepada Bendahara.'); f.value = null; await muat() }
  catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
</script>
<template>
  <section v-if="tampil" class="kartu w-gaji p-5">
    <div class="flex items-center gap-3">
      <span class="chip-ikon h-10 w-10"><PhReceipt :size="22" weight="duotone" /></span>
      <div class="flex-1"><h3 class="judul-bagian">Slip gaji</h3>
        <p class="text-sm text-teks3">{{ isi.slip?.length ? `${isi.slip.length} slip dapat dibuka di akun Anda` : 'Slip gaji tidak ditampilkan di akun pegawai; Anda dapat memintanya kepada Bendahara.' }}</p></div>
    </div>
    <div class="mt-3 flex flex-wrap gap-2">
      <router-link v-if="isi.slip?.length" to="/gaji/slip" class="tombol-utama"><PhReceipt :size="20" weight="duotone" /> Buka slip saya <PhCaretRight :size="16" /></router-link>
      <button v-if="periode.length" class="tombol-garis" @click="f = { periode: '', catatan: '' }"><PhPaperPlaneTilt :size="20" /> Minta slip ke Bendahara</button>
    </div>
    <ul v-if="isi.permintaan?.length" class="mt-3 space-y-1 text-sm">
      <li v-for="r in isi.permintaan.slice(0, 3)" :key="r.id" class="flex flex-wrap justify-between gap-2 rounded-xl bg-permukaan2 px-3 py-2">
        <span>{{ formatPendek(r.created_at) }} · {{ r.periode || 'Semua slip' }}</span>
        <span :class="['font-semibold', r.status === 'ditolak' ? 'text-merah' : '']">{{ STATUS[r.status] }}{{ r.tanggapan ? ': ' + r.tanggapan : '' }}</span>
      </li>
    </ul>
    <LembarBawah :model-value="!!f" @update:model-value="(v) => !v && (f = null)" judul="Minta slip gaji">
      <div v-if="f" class="space-y-4 pb-2">
        <div><label class="label-isian" for="ms-per">Periode</label>
          <select id="ms-per" v-model="f.periode" class="isian"><option value="">Semua slip yang sudah terbit</option>
            <option v-for="p in periode" :key="p.id" :value="p.id">{{ p.nama }}</option></select></div>
        <div><label class="label-isian" for="ms-cat">Keperluan (tidak wajib)</label><input id="ms-cat" v-model="f.catatan" class="isian" placeholder="Contoh: Persyaratan pengajuan pembiayaan" /></div>
        <p class="text-xs text-teks3">Bendahara dapat membukakan slip di akun Anda atau menyiapkannya dalam bentuk tercetak.</p>
        <button class="tombol-utama w-full" :disabled="proses" @click="kirim"><PhPaperPlaneTilt :size="20" weight="duotone" /> Kirim permintaan</button>
      </div>
    </LembarBawah>
  </section>
</template>
