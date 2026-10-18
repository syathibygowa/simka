<!-- SIMKA PRO | src/pages/keuangan/KelolaRekeningKeu.vue | v1.0 | 14.7.0: daftar rekening bank dan kas tunai (saldo awal, saldo kini, tampil ke wali) | 18/10/2026 -->
<script setup>
// Rekening dan kas lembaga: kas tunai Bendahara dan banyak rekening bank. Saldo awal berlaku pada tanggal tertentu; sejak tanggal itu
// semua pembayaran santri, pengeluaran, pemasukan lain, dan pindah dana menambah/mengurangi saldonya. Rekening bank bertanda
// "tampil ke wali" tercetak di surat tagihan dan pesan WA. Rekening yang sudah dipakai transaksi hanya dapat dinonaktifkan.
import { ref, onMounted } from 'vue'
import { PhBank, PhPlus, PhPencilSimple, PhTrash, PhFloppyDisk, PhWallet, PhEye } from '@phosphor-icons/vue'
import { useKeuangan } from '@/stores/keuangan'
import { useUI } from '@/stores/ui'
import { formatPendek, hariIniISO } from '@/lib/tanggal'
import { rupiah, angka, bacaRupiah } from '@/lib/keuangan'
import LembarBawah from '@/components/LembarBawah.vue'
import InputTanggal from '@/components/InputTanggal.vue'

const keu = useKeuangan(); const ui = useUI()
const f = ref(null); const proses = ref(false)
onMounted(() => keu.muatAkun().catch((e) => ui.toast(e.message, 'galat')))
const baru = (jenis = 'bank') => { f.value = { id: null, nama: '', jenis, bank: '', nomor: '', atas_nama: '', keterangan: '', saldo_awal: '0', tanggal_saldo_awal: hariIniISO(), tampil_wali: jenis === 'bank', aktif: true, urutan: keu.akun.length } }
const ubah = (a) => { f.value = { ...a, saldo_awal: angka(a.saldo_awal), bank: a.bank || '', nomor: a.nomor || '', atas_nama: a.atas_nama || '', keterangan: a.keterangan || '' } }
async function simpan() {
  const d = f.value
  if (d.jenis === 'bank' && !d.nama.trim()) d.nama = `${d.bank} ${d.nomor}`.trim()
  proses.value = true
  try { await keu.simpanAkun({ ...d, saldo_awal: bacaRupiah(d.saldo_awal) || 0 }); ui.toast('Rekening/kas disimpan.'); f.value = null } catch (e) { ui.toast(e.message, 'galat') } finally { proses.value = false }
}
async function hapus(a) {
  if (!(await ui.konfirmasi({ judul: `Hapus ${a.nama}?`, pesan: a.dipakai ? 'Rekening ini sudah dipakai transaksi, sehingga hanya dinonaktifkan; riwayat dan saldonya tetap tercatat.' : 'Rekening akan dihapus.', ya: a.dipakai ? 'Nonaktifkan' : 'Hapus', bahaya: true }))) return
  try { const r = await keu.hapusAkun(a.id); ui.toast(r === 'dihapus' ? 'Rekening dihapus.' : 'Rekening dinonaktifkan.') } catch (e) { ui.toast(e.message, 'galat') }
}
</script>
<template>
  <div class="kartu w-shift p-4 sm:p-5">
    <div class="mb-3 flex flex-wrap items-center gap-2">
      <h3 class="judul-bagian flex flex-1 items-center gap-2"><PhBank :size="20" weight="duotone" style="color: var(--c)" /> Rekening dan kas</h3>
      <template v-if="keu.hak.kelola">
        <button class="tombol-garis min-h-[40px] px-3 text-sm" @click="baru('kas')"><PhWallet :size="18" weight="duotone" /> Kas</button>
        <button class="tombol-utama min-h-[40px] px-3 text-sm" @click="baru('bank')"><PhPlus :size="18" weight="bold" /> Rekening bank</button>
      </template>
    </div>
    <p class="mb-3 text-sm text-teks3">Saldo dihitung dari saldo awal ditambah pembayaran santri dan pemasukan lain, dikurangi pengeluaran, sejak tanggal saldo awal. Rekening pribadi tidak dicatat.</p>
    <ul class="grid gap-2 md:grid-cols-2">
      <li v-for="a in keu.akun" :key="a.id" :class="['rounded-2xl border border-garis p-3', !a.aktif && 'opacity-60']">
        <div class="flex items-start gap-3">
          <span :class="['chip-ikon h-10 w-10 shrink-0', a.jenis === 'kas' ? 'w-keuangan' : 'w-shift']"><component :is="a.jenis === 'kas' ? PhWallet : PhBank" :size="22" weight="duotone" /></span>
          <div class="min-w-0 flex-1">
            <p class="font-bold leading-snug">{{ a.nama }}</p>
            <p v-if="a.jenis === 'bank'" class="truncate text-xs text-teks3">{{ a.bank }} {{ a.nomor }} · a.n. {{ a.atas_nama }}</p>
            <p class="mt-1 text-lg font-extrabold tabular-nums">{{ rupiah(a.saldo) }}</p>
            <p class="text-xs text-teks3">Saldo awal {{ rupiah(a.saldo_awal) }} per {{ formatPendek(a.tanggal_saldo_awal) }}</p>
            <p class="mt-1 flex flex-wrap gap-1"><span v-if="a.tampil_wali && a.jenis === 'bank'" class="lencana w-presensi"><PhEye :size="12" /> Tampil ke wali</span>
              <span v-if="!a.aktif" class="lencana w-hakakses">Nonaktif</span></p>
          </div>
          <div v-if="keu.hak.kelola" class="flex shrink-0 flex-col gap-1">
            <button class="tombol-ikon" :aria-label="'Ubah ' + a.nama" @click="ubah(a)"><PhPencilSimple :size="20" /></button>
            <button class="tombol-ikon text-merah" :aria-label="'Hapus ' + a.nama" @click="hapus(a)"><PhTrash :size="20" /></button>
          </div>
        </div>
      </li>
    </ul>
    <p v-if="!keu.akun.length" class="rounded-xl bg-permukaan2 p-3 text-sm text-teks3">Belum ada rekening atau kas. Jalankan SQL 12000 atau tambahkan di sini.</p>

    <LembarBawah :model-value="!!f" @update:model-value="(v) => !v && (f = null)" :judul="f?.id ? 'Ubah rekening/kas' : f?.jenis === 'kas' ? 'Kas tunai baru' : 'Rekening bank baru'">
      <div v-if="f" class="space-y-3 pb-2">
        <div class="flex rounded-xl bg-permukaan2 p-1" role="radiogroup" aria-label="Jenis">
          <button v-for="(n, k) in { bank: 'Rekening bank', kas: 'Kas tunai' }" :key="k" type="button" role="radio" :aria-checked="f.jenis === k" @click="f.jenis = k"
            :class="['min-h-[40px] flex-1 rounded-lg text-sm font-semibold', f.jenis === k ? 'bg-permukaan text-teks shadow-kartu' : 'text-teks2']">{{ n }}</button></div>
        <template v-if="f.jenis === 'bank'">
          <div class="grid grid-cols-[1fr_1.4fr] gap-3">
            <div><label class="label-isian" for="rk-bank">Bank</label><input id="rk-bank" v-model="f.bank" class="isian" placeholder="BSI" /></div>
            <div><label class="label-isian" for="rk-no">Nomor rekening</label><input id="rk-no" v-model="f.nomor" class="isian tabular-nums" inputmode="numeric" /></div>
          </div>
          <div><label class="label-isian" for="rk-an">Atas nama</label><input id="rk-an" v-model="f.atas_nama" class="isian" /></div>
        </template>
        <div><label class="label-isian" for="rk-nama">Nama tampilan</label><input id="rk-nama" v-model="f.nama" class="isian" :placeholder="f.jenis === 'kas' ? 'Kas Tunai Bendahara' : 'BSI Operasional Pondok'" /></div>
        <div class="grid grid-cols-2 gap-3">
          <div><label class="label-isian" for="rk-sa">Saldo awal (Rp)</label><input id="rk-sa" v-model="f.saldo_awal" class="isian font-bold tabular-nums" inputmode="numeric" /></div>
          <InputTanggal v-model="f.tanggal_saldo_awal" label="Per tanggal" wajib />
        </div>
        <p class="text-xs text-teks3">Isi saldo sesuai buku tabungan/kas pada tanggal itu. Transaksi sebelum tanggal saldo awal tidak dihitung pada saldo.</p>
        <div><label class="label-isian" for="rk-ket">Keterangan</label><input id="rk-ket" v-model="f.keterangan" class="isian" placeholder="Contoh: SPP dan biaya rutin" /></div>
        <label v-if="f.jenis === 'bank'" class="flex items-center gap-3 text-sm"><input v-model="f.tampil_wali" type="checkbox" class="h-5 w-5" /> Tampilkan di surat tagihan dan pesan WA wali sebagai tujuan transfer</label>
        <label v-if="f.id" class="flex items-center gap-3 text-sm"><input v-model="f.aktif" type="checkbox" class="h-5 w-5" /> Aktif</label>
        <button class="tombol-utama w-full" :disabled="proses" @click="simpan"><PhFloppyDisk :size="20" weight="duotone" /> Simpan</button>
      </div>
    </LembarBawah>
  </div>
</template>
