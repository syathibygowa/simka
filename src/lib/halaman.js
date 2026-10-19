// SIMKA PRO | src/lib/halaman.js | v1.0 | 14.14.0: lanjutkan otomatis jawaban server yang terpotong 1.000 baris | 19/10/2026
// 14.14.0: server Supabase membatasi setiap jawaban berbaris paling banyak 1.000 baris (Max rows). Tanpa penanganan,
// daftar yang lebih panjang (mis. rekap absensi semua santri) terpotong diam-diam sehingga sebagian santri tampak
// "tanpa absensi". Setiap pembacaan (select tabel atau RPC berbaris) yang tidak memakai limit/range sendiri dan
// menerima tepat 1.000 baris otomatis dilanjutkan per halaman sampai habis.
export const BARIS_PER_HALAMAN = 1000
const HALAMAN_MAKS = 200
export function pasangHalamanOtomatis(supabase) {
  let proto = Object.getPrototypeOf(supabase.rpc('_cek_halaman'))
  while (proto && !Object.prototype.hasOwnProperty.call(proto, 'then')) proto = Object.getPrototypeOf(proto)
  if (proto && !proto._halamanOtomatis) {
    const thenAsli = proto.then
    const bolehLanjut = (b) => {
      if (b._halaman || !b.url || !b.headers) return false
      const rpc = b.method === 'POST' && b.url.pathname.includes('/rpc/')
      if (b.method !== 'GET' && !rpc) return false
      if (b.url.searchParams.has('limit') || b.url.searchParams.has('offset') || b.isMaybeSingle) return false
      const terima = b.headers.get('Accept') || ''
      return !terima.includes('object+json') && !terima.includes('csv')
    }
    const salin = (b, dari) => {
      const c = Object.create(Object.getPrototypeOf(b)); Object.assign(c, b)
      c.url = new URL(b.url); c.headers = new Headers(b.headers); c._halaman = true
      return c.range(dari, dari + BARIS_PER_HALAMAN - 1)
    }
    proto.then = function (ok, gagal) {
      if (!bolehLanjut(this)) return thenAsli.call(this, ok, gagal)
      const b = this
      const jalan = async () => {
        const r = await thenAsli.call(b)
        if (r?.error || !Array.isArray(r?.data) || r.data.length !== BARIS_PER_HALAMAN) return r
        let semua = r.data
        for (let i = 1; i < HALAMAN_MAKS; i++) {
          const s = await thenAsli.call(salin(b, i * BARIS_PER_HALAMAN))
          if (s?.error) { if (s.status === 416) break; return s }
          if (!Array.isArray(s?.data) || !s.data.length) break
          // Fungsi yang mengembalikan satu nilai JSON (bukan baris) tidak berhalaman: jawabannya sama dengan halaman pertama
          if (i === 1 && JSON.stringify(s.data[0]) === JSON.stringify(r.data[0])) break
          semua = semua.concat(s.data)
          if (s.data.length < BARIS_PER_HALAMAN) break
        }
        return { ...r, data: semua }
      }
      return jalan().then(ok, gagal)
    }
    proto._halamanOtomatis = true
  }
}
