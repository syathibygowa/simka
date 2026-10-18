<!-- SIMKA PRO | src/components/PratinjauWA.vue | v1.0 | 14.2.0: pratinjau pesan seperti tampilan WhatsApp | 17/10/2026 -->
<script setup>
// Pratinjau pesan WhatsApp dalam gelembung obrolan, dengan format yang sama seperti di WhatsApp:
//   *tebal*  _miring_  ~coret~  ```monospasi```  `kode`  > kutipan  • butir
// Isian {kurung kurawal} yang belum terisi disorot kuning agar diganti sebelum dikirim.
import { computed } from 'vue'

const props = defineProps({
  teks: { type: String, default: '' },
  jam: { type: String, default: '' },        // kosong = jam sekarang
  ringkas: Boolean,                          // tanpa latar obrolan (mis. di dalam kartu)
})

const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
// Format sebaris mengikuti aturan WhatsApp: penanda harus menempel pada kata (tidak diawali/diakhiri spasi).
function sebaris(t) {
  const kode = []
  t = t.replace(/```([\s\S]+?)```/g, (_, x) => { kode.push(`<code class="mono">${x}</code>`); return `\u0000${kode.length - 1}\u0000` })
  t = t.replace(/`([^`\n]+)`/g, (_, x) => { kode.push(`<code class="kode">${x}</code>`); return `\u0000${kode.length - 1}\u0000` })
  const pola = (c, tag) => new RegExp(`(^|[\\s([{"'.,;:!?-])\\${c}(?=\\S)([^${c}\\n]*?\\S)\\${c}(?=$|[\\s)\\]}"'.,;:!?-])`, 'g')
  for (const [c, tag] of [['*', 'b'], ['_', 'i'], ['~', 's']]) t = t.replace(pola(c, tag), (_, a, x) => `${a}<${tag}>${x}</${tag}>`)
  t = t.replace(/\{[a-z0-9_]+\}/gi, (x) => `<mark>${x}</mark>`)
  return t.replace(/\u0000(\d+)\u0000/g, (_, i) => kode[i])
}
const html = computed(() => esc(props.teks || '').split('\n').map((l) => {
  if (/^&gt; ?/.test(l)) return `<span class="kutip">${sebaris(l.replace(/^&gt; ?/, ''))}</span>`
  return sebaris(l)
}).join('\n'))
const waktu = computed(() => props.jam || new Date().toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit', timeZone: 'Asia/Makassar' }).replace(':', '.'))
const adaIsian = computed(() => /\{[a-z0-9_]+\}/i.test(props.teks || ''))
</script>
<template>
  <div :class="['wa-latar', ringkas && 'ringkas']">
    <div class="wa-gelembung">
      <!-- eslint-disable-next-line vue/no-v-html -- teks sudah di-escape, hanya tag format yang ditambahkan -->
      <div class="wa-isi" v-html="html" />
      <span class="wa-jam">{{ waktu }}</span>
    </div>
    <p v-if="adaIsian" class="wa-catatan">Teks bersorot kuning belum terisi datanya; ubah sebelum mengirim.</p>
  </div>
</template>
<style scoped>
.wa-latar { --latar: #EFEAE2; --gel: #D9FDD3; --teks: #111B21; --jam: #667781; --kutip: #06CF9C;
  background: var(--latar); border-radius: 1rem; padding: .75rem; }
.wa-latar.ringkas { background: transparent; padding: 0; }
.wa-gelembung { position: relative; background: var(--gel); color: var(--teks); border-radius: .75rem .25rem .75rem .75rem;
  padding: .5rem .65rem 1.15rem; box-shadow: 0 1px .5px rgb(0 0 0 / .13); max-width: 100%; margin-left: auto; }
.wa-isi { white-space: pre-wrap; overflow-wrap: anywhere; font-size: .875rem; line-height: 1.45; }
.wa-isi :deep(b) { font-weight: 700; }
.wa-isi :deep(i) { font-style: italic; }
.wa-isi :deep(s) { text-decoration: line-through; }
.wa-isi :deep(code.mono) { font-family: ui-monospace, Menlo, Consolas, monospace; font-size: .8rem; }
.wa-isi :deep(code.kode) { font-family: ui-monospace, Menlo, Consolas, monospace; font-size: .8rem; background: rgb(0 0 0 / .07); padding: 0 .25rem; border-radius: .25rem; }
.wa-isi :deep(.kutip) { display: inline-block; border-left: 3px solid var(--kutip); padding-left: .5rem; opacity: .85; }
.wa-isi :deep(mark) { background: #FFE58A; color: #3D2E00; border-radius: .2rem; padding: 0 .1rem; }
.wa-jam { position: absolute; right: .55rem; bottom: .25rem; font-size: .68rem; color: var(--jam); }
.wa-catatan { margin-top: .4rem; font-size: .72rem; color: var(--jam); }
</style>
<style>
/* Mode gelap seperti WhatsApp (tanpa scoped agar .dark pada <html> terbaca) */
.dark .wa-latar { --latar: #0B141A; --gel: #005C4B; --teks: #E9EDEF; --jam: #A7C1BA; --kutip: #06CF9C; }
</style>
