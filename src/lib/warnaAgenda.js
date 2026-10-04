// SIMKA PRO | src/lib/warnaAgenda.js | v1.0 | Fase 3 – Perbaikan P2 (agenda lanjutan) | 04/10/2026
// 24 warna lembut untuk agenda (ala Google Kalender). Di tema gelap warna dicerahkan otomatis (kelas .warna-agenda di token.css).
export const WARNA_AGENDA = [
  ['tomat', 'Tomat', '#C9483E'], ['flamingo', 'Flamingo', '#D97A70'], ['jeruk', 'Jeruk', '#E07B39'], ['mangga', 'Mangga', '#DE9B35'],
  ['pisang', 'Pisang', '#C9A227'], ['zaitun', 'Zaitun', '#8C9A3A'], ['alpukat', 'Alpukat', '#6E9E45'], ['kemangi', 'Kemangi', '#3F8E5C'],
  ['sage', 'Sage', '#5E9C82'], ['tosca', 'Tosca', '#2A9187'], ['merak', 'Merak', '#1F86A6'], ['langit', 'Langit', '#3E8FC9'],
  ['blueberry', 'Blueberry', '#4B68B8'], ['nila', 'Nila', '#5157A8'], ['lavender', 'Lavender', '#7E7FC8'], ['ungu', 'Ungu muda', '#9273BD'],
  ['anggur', 'Anggur', '#83459F'], ['terong', 'Terong', '#6C3D74'], ['mawar', 'Mawar', '#C25E8C'], ['delima', 'Delima', '#A93F5B'],
  ['cokelat', 'Cokelat', '#87644F'], ['kayu', 'Kayu', '#A07A55'], ['grafit', 'Grafit', '#5E6A72'], ['batu', 'Batu', '#848D94'],
]
const PETA = Object.fromEntries(WARNA_AGENDA.map(([k, n, h]) => [k, { n, h }]))
export const hexAgenda = (k) => (PETA[k] || PETA.merak).h
/** Gaya untuk elemen ber-kelas "warna-agenda". */
export const gayaAgenda = (k) => ({ '--c0': hexAgenda(k) })
