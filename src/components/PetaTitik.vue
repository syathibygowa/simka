<!-- SIMKA PRO | src/components/PetaTitik.vue | v1.0 | Fase 2 – Tahap 3 Pengaturan presensi | 03/10/2026 -->
<script setup>
// Peta titik GPS (Leaflet + OpenStreetMap / citra satelit Esri, tanpa kunci API).
// Menampilkan semua titik beserta radiusnya. Bila prop "pilihan" diisi, peta dapat diketuk
// untuk memindahkan titik yang sedang diubah (emit "ketuk").
import { ref, watch, onMounted, onBeforeUnmount, nextTick } from 'vue'
import L from 'leaflet'
import 'leaflet/dist/leaflet.css'
import { PhMapTrifold, PhGlobeHemisphereEast, PhCrosshair } from '@phosphor-icons/vue'

const props = defineProps({
  titik: { type: Array, default: () => [] },     // [{ id, nama, lat, lng, radius_m, aktif }]
  pilihan: { type: Object, default: null },      // { id?, lat, lng, radius_m } titik yang sedang diubah
  posisiSaya: { type: Object, default: null },   // { lat, lng, akurasi }
  tinggi: { type: String, default: '320px' },
})
const emit = defineEmits(['ketuk'])
const wadah = ref(null)
const lapisan = ref('peta')
let peta, tileOSM, tileSat, grupTitik, grupPilihan, grupSaya
const BAWAAN = [-5.2135, 119.4745] // sekitar Somba Opu, Gowa

function gambarTitik() {
  if (!peta) return
  grupTitik.clearLayers()
  props.titik.filter((t) => t.id !== props.pilihan?.id).forEach((t) => {
    const warna = t.aktif ? '#1E7D4F' : '#8A7A7C'
    L.circle([t.lat, t.lng], { radius: t.radius_m, color: warna, weight: 2, fillOpacity: 0.12, dashArray: t.aktif ? null : '6 6' }).addTo(grupTitik)
    L.circleMarker([t.lat, t.lng], { radius: 6, color: '#fff', weight: 2, fillColor: warna, fillOpacity: 1 })
      .bindTooltip(`${t.nama} (${t.radius_m} m)${t.aktif ? '' : ' – nonaktif'}`, { direction: 'top', offset: [0, -6] }).addTo(grupTitik)
  })
}
function gambarPilihan() {
  if (!peta) return
  grupPilihan.clearLayers()
  const p = props.pilihan
  if (p && Number.isFinite(p.lat) && Number.isFinite(p.lng)) {
    L.circle([p.lat, p.lng], { radius: Number(p.radius_m) || 100, color: '#C7332F', weight: 2.5, fillOpacity: 0.15 }).addTo(grupPilihan)
    L.circleMarker([p.lat, p.lng], { radius: 8, color: '#fff', weight: 3, fillColor: '#C7332F', fillOpacity: 1 }).addTo(grupPilihan)
  }
}
function gambarSaya() {
  if (!peta) return
  grupSaya.clearLayers()
  const s = props.posisiSaya
  if (s) {
    if (s.akurasi) L.circle([s.lat, s.lng], { radius: s.akurasi, color: '#2F5FA8', weight: 1, fillOpacity: 0.1 }).addTo(grupSaya)
    L.circleMarker([s.lat, s.lng], { radius: 7, color: '#fff', weight: 3, fillColor: '#2F5FA8', fillOpacity: 1 }).bindTooltip('Posisi Anda').addTo(grupSaya)
  }
}
function pas() {
  if (!peta) return
  const p = props.pilihan
  if (p && Number.isFinite(p.lat)) { peta.setView([p.lat, p.lng], Math.max(peta.getZoom(), 17)); return }
  const titik = props.titik.map((t) => [t.lat, t.lng])
  if (props.posisiSaya) titik.push([props.posisiSaya.lat, props.posisiSaya.lng])
  if (titik.length === 1) peta.setView(titik[0], 17)
  else if (titik.length) peta.fitBounds(L.latLngBounds(titik).pad(0.3), { maxZoom: 18 })
  else peta.setView(BAWAAN, 14)
}
function gantiLapisan(k) {
  lapisan.value = k
  if (k === 'satelit') { peta.removeLayer(tileOSM); tileSat.addTo(peta) } else { peta.removeLayer(tileSat); tileOSM.addTo(peta) }
}

onMounted(async () => {
  await nextTick()
  peta = L.map(wadah.value, { zoomControl: true, attributionControl: true })
  tileOSM = L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', { maxZoom: 19, attribution: '© OpenStreetMap' })
  tileSat = L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', { maxZoom: 19, attribution: 'Citra © Esri' })
  tileOSM.addTo(peta)
  grupTitik = L.layerGroup().addTo(peta); grupPilihan = L.layerGroup().addTo(peta); grupSaya = L.layerGroup().addTo(peta)
  peta.on('click', (e) => { if (props.pilihan) emit('ketuk', { lat: +e.latlng.lat.toFixed(7), lng: +e.latlng.lng.toFixed(7) }) })
  gambarTitik(); gambarPilihan(); gambarSaya(); pas()
  // Peta di dalam lembar bawah perlu diukur ulang setelah animasi selesai
  setTimeout(() => { peta?.invalidateSize(); pas() }, 320)
})
onBeforeUnmount(() => { peta?.remove(); peta = null })
watch(() => props.titik, gambarTitik, { deep: true })
watch(() => props.pilihan, gambarPilihan, { deep: true })
watch(() => [props.pilihan?.lat, props.pilihan?.lng], () => { if (props.pilihan && peta && !peta.getBounds().contains([props.pilihan.lat, props.pilihan.lng])) pas() })
watch(() => props.posisiSaya, () => { gambarSaya(); if (props.posisiSaya && !props.pilihan) pas() }, { deep: true })
defineExpose({ pas })
</script>
<template>
  <div class="relative isolate overflow-hidden rounded-2xl border border-garis">
    <div ref="wadah" :style="{ height: tinggi }" :class="['peta z-0', pilihan && 'cursor-crosshair']" role="application" aria-label="Peta titik lokasi presensi" />
    <div class="absolute right-2 top-2 z-[400] flex gap-1 rounded-xl bg-permukaan/95 p-1 shadow-kartu">
      <button type="button" @click="gantiLapisan('peta')" :class="['flex min-h-[36px] items-center gap-1 rounded-lg px-2.5 text-xs font-semibold', lapisan === 'peta' ? 'bg-[#C7332F] text-white' : 'text-teks2']">
        <PhMapTrifold :size="16" weight="duotone" /> Peta</button>
      <button type="button" @click="gantiLapisan('satelit')" :class="['flex min-h-[36px] items-center gap-1 rounded-lg px-2.5 text-xs font-semibold', lapisan === 'satelit' ? 'bg-[#C7332F] text-white' : 'text-teks2']">
        <PhGlobeHemisphereEast :size="16" weight="duotone" /> Satelit</button>
      <button type="button" @click="pas" class="flex min-h-[36px] items-center rounded-lg px-2 text-teks2" aria-label="Pusatkan peta" title="Pusatkan peta">
        <PhCrosshair :size="18" weight="duotone" /></button>
    </div>
    <p v-if="pilihan" class="pointer-events-none absolute bottom-2 left-2 z-[400] rounded-lg bg-black/65 px-2.5 py-1 text-xs font-semibold text-white">
      Ketuk peta untuk memindahkan titik</p>
  </div>
</template>
<style scoped>
.peta :deep(.leaflet-control-attribution) { font-size: 10px; }
.peta :deep(.leaflet-tooltip) { font-family: inherit; font-weight: 600; }
</style>
