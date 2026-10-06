<!-- SIMKA PRO | src/pages/santri/SeksiLayananSantri.vue | v1.0 | Fase 6 – Tahap 5 Penutup fase klinik dan lapor | 06/10/2026 -->
<script setup>
// Bagian profil santri terpadu (Fase 6): riwayat Kesehatan (Klinik), Perizinan, dan Laporan yang menyangkut santri.
// Pengasuh melihat ringkasan kesehatan saja (tanggal, keluhan umum, status); diagnosis hanya bagi tenaga klinik/pimpinan.
// Tombol: Rujuk ke klinik dan Ajukan izin.
import { ref, watch } from 'vue'
import { PhFirstAidKit, PhSignOut, PhMegaphone, PhPaperPlaneTilt, PhFileText } from '@phosphor-icons/vue'
import { useLayanan } from '@/stores/layanan'
import { labelKasus } from '@/lib/klinik'
import { labelIzin, JENIS_IZIN, rentangIzin } from '@/lib/izin'
import { STATUS_LAPOR, gayaKategori } from '@/lib/lapor'
import { formatPendek } from '@/lib/tanggal'
import LembarRujuk from '@/pages/klinik/LembarRujuk.vue'

const props = defineProps({ santri: { type: Object, required: true } })
const ly = useLayanan(); const d = ref(null); const galat = ref('')
async function muat() { galat.value = ''; try { d.value = await ly.riwayatSantri(props.santri.id) } catch (e) { galat.value = e.message } }
watch(() => props.santri?.id, (v) => v && muat(), { immediate: true })
const lembarRujuk = ref(false)
</script>
<template>
  <section class="kartu w-klinik mt-4 p-5">
    <div class="mb-3 flex flex-wrap items-center gap-3"><span class="chip-ikon h-10 w-10"><PhFirstAidKit :size="22" weight="duotone" /></span>
      <div class="min-w-0 flex-1"><h3 class="judul-bagian">Kesehatan, perizinan, dan laporan</h3><p class="text-sm text-teks3">Riwayat Klinik, izin keluar/pulang, dan laporan ke bidang terkait.</p></div>
      <button class="tombol-garis min-h-[40px] px-3 text-sm" @click="lembarRujuk = true"><PhPaperPlaneTilt :size="18" /> Rujuk ke klinik</button>
      <router-link to="/izin-santri/menunggu" class="tombol-garis min-h-[40px] px-3 text-sm"><PhSignOut :size="18" /> Perizinan</router-link>
    </div>
    <p v-if="galat" class="text-sm text-teks3">{{ galat }}</p>
    <div v-else-if="d" class="grid gap-4 lg:grid-cols-3">
      <div>
        <h4 class="mb-2 flex items-center gap-2 text-sm font-bold"><PhFirstAidKit :size="18" weight="duotone" /> Klinik ({{ d.klinik.length }})</h4>
        <ul class="divide-y divide-garis rounded-xl border border-garis text-sm">
          <li v-for="k in d.klinik" :key="k.id" class="px-3 py-2">
            <p class="flex flex-wrap items-center gap-1.5"><span class="flex-1 font-semibold">{{ k.keluhan }}</span><span class="lencana" :class="'w-' + labelKasus(k).w">{{ labelKasus(k).n }}</span></p>
            <p class="text-xs text-teks3">{{ formatPendek(k.dibuka_pada) }}{{ k.selesai_pada ? ' s.d. ' + formatPendek(k.selesai_pada) : '' }}{{ k.diagnosis ? ' · ' + k.diagnosis : '' }}
              <template v-if="k.surat"> · <PhFileText :size="12" class="inline" /> {{ k.surat }} surat</template></p></li>
          <li v-if="!d.klinik.length" class="px-3 py-3 text-center text-xs text-teks3">Belum pernah ke klinik.</li>
        </ul>
      </div>
      <div>
        <h4 class="mb-2 flex items-center gap-2 text-sm font-bold"><PhSignOut :size="18" weight="duotone" /> Perizinan ({{ d.izin.length }})</h4>
        <ul class="divide-y divide-garis rounded-xl border border-garis text-sm">
          <li v-for="x in d.izin" :key="x.id" class="px-3 py-2">
            <p class="flex flex-wrap items-center gap-1.5"><span class="flex-1 font-semibold">{{ x.alasan }}</span><span class="lencana" :class="'w-' + labelIzin(x).w">{{ labelIzin(x).n }}</span></p>
            <p class="text-xs text-teks3">{{ JENIS_IZIN[x.jenis] }} · {{ rentangIzin(x) }}{{ x.kembali_pada ? ' · kembali ' + formatPendek(x.kembali_pada) : '' }}</p></li>
          <li v-if="!d.izin.length" class="px-3 py-3 text-center text-xs text-teks3">Belum ada izin.</li>
        </ul>
      </div>
      <div>
        <h4 class="mb-2 flex items-center gap-2 text-sm font-bold"><PhMegaphone :size="18" weight="duotone" /> Laporan ({{ d.laporan.length }})</h4>
        <ul class="divide-y divide-garis rounded-xl border border-garis text-sm">
          <li v-for="r in d.laporan" :key="r.id" class="px-3 py-2" :class="'w-' + gayaKategori(r.kode).w">
            <p class="flex flex-wrap items-center gap-1.5"><b style="color: var(--c)">{{ r.kategori }}</b><span class="lencana" :class="'w-' + STATUS_LAPOR[r.status].w">{{ STATUS_LAPOR[r.status].n }}</span></p>
            <p class="text-xs text-teks2">{{ r.uraian }}</p>
            <p class="text-xs text-teks3">{{ formatPendek(r.created_at) }} · {{ r.pelapor || 'pelapor anonim' }}</p></li>
          <li v-if="!d.laporan.length" class="px-3 py-3 text-center text-xs text-teks3">Belum ada laporan.</li>
        </ul>
      </div>
    </div>
    <LembarRujuk v-model="lembarRujuk" :santri-awal="{ id: santri.id, nama: santri.nama_lengkap, nis: santri.nis, jenis_kelamin: santri.jenis_kelamin }" @selesai="muat" />
  </section>
</template>
