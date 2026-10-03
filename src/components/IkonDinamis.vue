<!-- SIMKA PRO | src/components/IkonDinamis.vue | v1.1 | Fase 2 – Tahap 5 Jadwal shift | 03/10/2026 -->
<script setup>
// Ikon berdasarkan nama (dipakai notifikasi dari database, kolom "ikon").
import {
  PhBell, PhUserPlus, PhCheckCircle, PhWarningCircle, PhPrinter, PhCloudArrowUp, PhFingerprint,
  PhListChecks, PhInfo, PhFileText, PhMegaphone, PhKey, PhCalendarCheck, PhShieldCheck, PhArrowsLeftRight, PhMapPin, PhClock,
} from '@phosphor-icons/vue'
const PETA = {
  Bell: PhBell, UserPlus: PhUserPlus, CheckCircle: PhCheckCircle, WarningCircle: PhWarningCircle,
  Printer: PhPrinter, CloudArrowUp: PhCloudArrowUp, Fingerprint: PhFingerprint, ListChecks: PhListChecks,
  Info: PhInfo, FileText: PhFileText, Megaphone: PhMegaphone, Key: PhKey, CalendarCheck: PhCalendarCheck,
  ShieldCheck: PhShieldCheck, ArrowsLeftRight: PhArrowsLeftRight, MapPin: PhMapPin, Clock: PhClock,
}
defineProps({ nama: { type: String, default: 'Bell' }, size: { type: Number, default: 22 } })
</script>
<template>
  <component :is="PETA[nama] || PhBell" :size="size" weight="duotone" aria-hidden="true" />
</template>
