<!-- SIMKA PRO | src/pages/gaji/Gaji.vue | v1.1 | Fase 11 – Tahap 2 Tab Periode dan Penetapan yayasan | 11/10/2026 -->
<script setup>
// Menu Gaji (Blueprint Bagian 36), satu menu bertab (menggantikan menu Skema Tunjangan):
//   Periode        : periode gaji bulanan; nominal yang benar-benar diterima (skema + penyesuaian ketetapan yayasan)
//   Penetapan      : gaji yang ditetapkan Ketua Yayasan per pegawai (jumlah tetap atau selisih dari skema)
//   Peta tunjangan : jabatan per pegawai, perkiraan tunjangan tetap, dan kekurangan data penentu gaji
//   Per jabatan    : tarif, jumlah pemegang, dan total per jabatan
//   Tarif          : tarif komponen bertanggal berlaku (diubah pengelola gaji)
//   Rekening       : cara bayar, bank, nomor rekening, atas nama (tampil di slip)
//   Ketentuan      : slip tampil di akun pegawai, TTD Direktur, pembulatan, sakelar potongan, dll.
// Pengelola: superadmin, Bendahara, admin ber-izin kelola_gaji. Pembaca: + admin ber-izin lihat_gaji.
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { PhTable, PhIdentificationBadge, PhCoins, PhBank, PhListChecks, PhInfo, PhReceipt, PhLockSimple, PhCalendarCheck, PhScales } from '@phosphor-icons/vue'
import { useGaji } from '@/stores/gaji'
import { useTunjangan } from '@/stores/tunjangan'
import { useOrganisasi } from '@/stores/organisasi'
import { useLembaga } from '@/stores/lembaga'
import { useSesi } from '@/stores/sesi'
import { hariIniISO } from '@/lib/tanggal'
import { petaTarif, hitungTunjangan } from '@/lib/tunjangan'
import BilahTab from '@/components/BilahTab.vue'
import TabPeta from '@/pages/tunjangan/TabPeta.vue'
import TabPerJabatan from '@/pages/tunjangan/TabPerJabatan.vue'
import TabTarif from '@/pages/tunjangan/TabTarif.vue'
import TabRekening from './TabRekening.vue'
import TabKetentuanGaji from './TabKetentuanGaji.vue'
import TabPeriode from './TabPeriode.vue'
import TabPenetapan from './TabPenetapan.vue'

const props = defineProps({ tab: { type: String, default: '' } })
const router = useRouter()
const gaji = useGaji(); const tunj = useTunjangan(); const org = useOrganisasi(); const lembaga = useLembaga(); const sesi = useSesi()
const siap = ref(false); const galat = ref('')
const tanggal = ref(hariIniISO())

const TAB = computed(() => [
  ...(gaji.hak.slip_saya && !gaji.hak.lihat ? [{ k: 'slip', n: 'Slip saya', ikon: PhReceipt, w: 'gaji' }] : []),
  ...(gaji.hak.lihat ? [
    { k: 'periode', n: 'Periode gaji', ikon: PhCalendarCheck, w: 'agenda' },
    { k: 'penetapan', n: 'Penetapan yayasan', ikon: PhScales, w: 'verifikasi' },
    { k: 'peta', n: 'Peta tunjangan', ikon: PhTable, w: 'gaji', lencana: kurang.value || 0 },
    { k: 'jabatan', n: 'Per jabatan', ikon: PhIdentificationBadge, w: 'presensi' },
    { k: 'tarif', n: 'Tarif', ikon: PhCoins, w: 'tahfizh' },
    { k: 'rekening', n: 'Rekening', ikon: PhBank, w: 'shift', lencana: tanpaRekening.value || 0 },
    { k: 'ketentuan', n: 'Ketentuan', ikon: PhListChecks, w: 'pengaturan' },
  ] : []),
])
const aktif = computed(() => (TAB.value.some((t) => t.k === props.tab) ? props.tab : TAB.value[0]?.k || ''))

async function muat() {
  galat.value = ''
  try {
    if (!gaji.hakDimuat) await gaji.muatHak()
    if (gaji.hak.lihat) await Promise.all([tunj.muat(), org.muat(), lembaga.muat(), gaji.muatPegawai()])
  } catch (e) { galat.value = e.message }
  siap.value = true
}
onMounted(muat)
watch(aktif, (k) => { if (k && k !== props.tab) router.replace({ path: `/gaji/${k}`, query: router.currentRoute.value.query }) })

const tarif = computed(() => petaTarif(tunj.tarif, tanggal.value))
const opsi = computed(() => ({ honorerJabatan: gaji.pengaturan.honorer_tunjangan_jabatan !== false }))
const hasil = computed(() => gaji.pegawai.map((p) => ({ p, h: hitungTunjangan(p, tarif.value, org, tanggal.value, opsi.value) })))
const kurang = computed(() => hasil.value.filter((x) => x.h.catatan.length).length)
const tanpaRekening = computed(() => gaji.pegawai.filter((p) => !p.rekening).length)
const penandaKanan = computed(() => (gaji.hak.bendahara ? 'Bendahara' : sesi.isSuperadmin ? 'Pengelola Sistem' : 'Petugas'))
</script>
<template>
  <div>
    <p v-if="galat" class="kartu mb-4 p-4 text-sm font-semibold text-merah">{{ galat }} Pastikan SQL gaji dasar v1.0 sudah dijalankan di Supabase.</p>
    <p v-if="!siap" class="kartu p-8 text-center text-sm text-teks3">Memuat…</p>
    <div v-else-if="!TAB.length" class="kartu w-gaji flex flex-col items-center gap-3 p-8 text-center">
      <span class="chip-ikon h-14 w-14"><PhLockSimple :size="30" weight="duotone" /></span>
      <p class="font-bold">Menu gaji tidak tersedia untuk akun Anda</p>
      <p class="max-w-md text-sm text-teks3">Bila memerlukan slip gaji, silakan menghubungi Bendahara.</p>
    </div>
    <template v-else>
      <BilahTab class="mb-3" :tab="TAB" :model-value="aktif" label="Bagian gaji" @update:model-value="(k) => router.replace(`/gaji/${k}`)" />
      <p v-if="['peta', 'jabatan'].includes(aktif)" class="mb-4 flex gap-2 text-sm text-teks3"><PhInfo :size="18" class="mt-0.5 shrink-0" />
        Angka di sini perkiraan tunjangan tetap menurut tarif yang berlaku. Honor per jam dan potongan kehadiran dihitung pada periode gaji.</p>
      <div :class="'w-' + (TAB.find((t) => t.k === aktif)?.w || 'gaji')">
        <TabPeriode v-if="aktif === 'periode'" />
        <TabPenetapan v-else-if="aktif === 'penetapan'" />
        <TabPeta v-else-if="aktif === 'peta'" v-model:tanggal="tanggal" :hasil="hasil" :boleh-ubah="sesi.bolehAdmin('kelola_pegawai')" :penanda-kanan="penandaKanan" @berubah="gaji.muatPegawai(true)" />
        <TabPerJabatan v-else-if="aktif === 'jabatan'" :hasil="hasil" :tarif="tarif" />
        <TabTarif v-else-if="aktif === 'tarif'" :boleh-ubah="!!gaji.hak.kelola" />
        <TabRekening v-else-if="aktif === 'rekening'" />
        <TabKetentuanGaji v-else-if="aktif === 'ketentuan'" />
        <div v-else-if="aktif === 'slip'" class="kartu w-gaji flex flex-col items-center gap-3 p-8 text-center">
          <span class="chip-ikon h-14 w-14"><PhReceipt :size="30" weight="duotone" /></span>
          <p class="font-bold">Belum ada slip gaji</p>
          <p class="max-w-md text-sm text-teks3">Slip gaji Anda tampil di sini setelah Bendahara menerbitkannya.</p>
        </div>
      </div>
    </template>
  </div>
</template>
