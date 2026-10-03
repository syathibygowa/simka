<!-- SIMKA PRO | src/components/KameraSelfie.vue | v1.0 | Fase 2 – Tahap 4 Halaman presensi | 03/10/2026 -->
<script setup>
// Kamera selfie layar penuh. Foto HANYA dari kamera langsung (bukan galeri), diperkecil
// menjadi sisi terpanjang 720 px (JPEG ±40–70 KB), lalu dibubuhi watermark berisi waktu
// server, nama titik, dan jarak (Bagian 9 blueprint).
import { ref, watch, onBeforeUnmount, nextTick } from 'vue'
import { PhX, PhCamera, PhArrowCounterClockwise, PhCheck, PhCameraRotate, PhWarningCircle } from '@phosphor-icons/vue'

const buka = defineModel({ type: Boolean, default: false })
const props = defineProps({ watermark: { type: Array, default: () => [] }, judul: { type: String, default: 'Ambil selfie' } })
const emit = defineEmits(['ambil'])
const video = ref(null); const hasil = ref(null); const galat = ref(''); const siap = ref(false); const depan = ref(true)
let aliran = null; let blob = null

async function nyalakan() {
  matikan(); galat.value = ''; siap.value = false; hasil.value = null
  if (!navigator.mediaDevices?.getUserMedia) { galat.value = 'Peramban ini tidak mendukung kamera. Gunakan Chrome atau Safari versi terbaru.'; return }
  try {
    aliran = await navigator.mediaDevices.getUserMedia({ video: { facingMode: depan.value ? 'user' : 'environment', width: { ideal: 1280 }, height: { ideal: 1280 } }, audio: false })
    await nextTick()
    video.value.srcObject = aliran
    await video.value.play()
    siap.value = true
  } catch (e) {
    galat.value = e?.name === 'NotAllowedError'
      ? 'Izin kamera ditolak. Buka pengaturan peramban, izinkan kamera untuk aplikasi ini, lalu coba lagi.'
      : 'Kamera tidak dapat dibuka. Tutup aplikasi lain yang memakai kamera lalu coba lagi.'
  }
}
function matikan() { aliran?.getTracks().forEach((t) => t.stop()); aliran = null; siap.value = false }
watch(buka, (v) => { if (v) nyalakan(); else { matikan(); hasil.value = null } })
onBeforeUnmount(matikan)
function balik() { depan.value = !depan.value; nyalakan() }

function gambarWatermark(ctx, w, h) {
  const baris = props.watermark.filter(Boolean)
  const uk = Math.round(w * 0.034); const jarak = Math.round(uk * 1.35); const pad = Math.round(uk * 0.8)
  const tinggi = pad * 2 + jarak * baris.length
  ctx.fillStyle = 'rgba(0,0,0,0.55)'; ctx.fillRect(0, h - tinggi, w, tinggi)
  ctx.fillStyle = '#fff'; ctx.textBaseline = 'top'
  baris.forEach((t, i) => {
    ctx.font = `${i === 0 ? '700' : '500'} ${uk}px "Plus Jakarta Sans", system-ui, sans-serif`
    ctx.fillText(t, pad, h - tinggi + pad + i * jarak, w - pad * 2)
  })
}
async function ambil() {
  const v = video.value; if (!v?.videoWidth) return
  const skala = Math.min(1, 720 / Math.max(v.videoWidth, v.videoHeight))
  const w = Math.round(v.videoWidth * skala); const h = Math.round(v.videoHeight * skala)
  const kanvas = document.createElement('canvas'); kanvas.width = w; kanvas.height = h
  const ctx = kanvas.getContext('2d')
  if (depan.value) { ctx.translate(w, 0); ctx.scale(-1, 1) }   // selfie seperti cermin, sesuai pratinjau
  ctx.drawImage(v, 0, 0, w, h)
  ctx.setTransform(1, 0, 0, 1, 0, 0)
  gambarWatermark(ctx, w, h)
  let mutu = 0.72
  blob = await new Promise((r) => kanvas.toBlob(r, 'image/jpeg', mutu))
  while (blob && blob.size > 150 * 1024 && mutu > 0.4) { mutu -= 0.1; blob = await new Promise((r) => kanvas.toBlob(r, 'image/jpeg', mutu)) }
  hasil.value = URL.createObjectURL(blob)
  matikan()
}
function ulangi() { if (hasil.value) URL.revokeObjectURL(hasil.value); nyalakan() }
function pakai() { emit('ambil', blob); buka.value = false }
</script>
<template>
  <Teleport to="body">
    <div v-if="buka" class="layar-saja fixed inset-0 z-[60] flex flex-col bg-black text-white" role="dialog" aria-modal="true" :aria-label="judul">
      <div class="flex items-center gap-2 px-3 pt-[max(0.5rem,env(safe-area-inset-top))] pb-2">
        <button class="grid h-11 w-11 place-items-center rounded-full bg-white/10" @click="buka = false" aria-label="Tutup kamera"><PhX :size="24" /></button>
        <p class="flex-1 text-center font-bold">{{ judul }}</p>
        <button class="grid h-11 w-11 place-items-center rounded-full bg-white/10" :disabled="!!hasil" @click="balik" aria-label="Ganti kamera depan/belakang"><PhCameraRotate :size="24" /></button>
      </div>
      <div class="relative flex flex-1 items-center justify-center overflow-hidden">
        <video v-show="!hasil && !galat" ref="video" playsinline muted :class="['max-h-full max-w-full object-contain', depan && '-scale-x-100']" />
        <img v-if="hasil" :src="hasil" alt="Pratinjau selfie dengan watermark" class="max-h-full max-w-full object-contain" />
        <div v-if="galat" class="mx-6 max-w-sm rounded-2xl bg-white/10 p-5 text-center">
          <PhWarningCircle :size="40" class="mx-auto mb-2 text-[#FFB074]" />
          <p class="font-semibold">{{ galat }}</p>
          <button class="mt-4 inline-flex min-h-[44px] items-center gap-2 rounded-full bg-white px-5 font-bold text-[#1F1416]" @click="nyalakan">Coba lagi</button>
        </div>
        <p v-if="!siap && !hasil && !galat" class="absolute text-sm text-white/80">Menyalakan kamera…</p>
        <!-- Bingkai wajah -->
        <div v-if="siap && !hasil" class="pointer-events-none absolute h-[52%] aspect-[3/4] rounded-[50%] border-2 border-dashed border-white/60" aria-hidden="true" />
      </div>
      <div class="flex items-center justify-center gap-6 px-4 pt-3 pb-[max(1.25rem,env(safe-area-inset-bottom))]">
        <template v-if="!hasil">
          <button class="grid h-20 w-20 place-items-center rounded-full border-4 border-white bg-white/20 disabled:opacity-40" :disabled="!siap" @click="ambil" aria-label="Ambil foto">
            <PhCamera :size="34" weight="fill" /></button>
        </template>
        <template v-else>
          <button class="inline-flex min-h-[52px] items-center gap-2 rounded-full bg-white/15 px-6 font-bold" @click="ulangi"><PhArrowCounterClockwise :size="22" /> Ulangi</button>
          <button class="inline-flex min-h-[52px] items-center gap-2 rounded-full bg-[#1E7D4F] px-6 font-bold" @click="pakai"><PhCheck :size="22" weight="bold" /> Kirim presensi</button>
        </template>
      </div>
    </div>
  </Teleport>
</template>
