// Tautan WhatsApp wa.me dari WA pribadi pegawai (Bagian 25)
export function nomorWA(hp) {
  let n = String(hp || '').replace(/[^0-9]/g, '');
  if (n.startsWith('0')) n = '62' + n.slice(1);
  else if (n.startsWith('8')) n = '62' + n;
  return n;
}
export function tautanWA(hp, pesan) {
  return `https://wa.me/${nomorWA(hp)}?text=${encodeURIComponent(pesan)}`;
}
export function bukaWA(hp, pesan) {
  window.open(tautanWA(hp, pesan), '_blank', 'noopener');
}
