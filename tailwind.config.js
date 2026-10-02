/** Warna memakai variabel CSS (src/styles/token.css) agar tema terang/gelap cukup ditukar di satu tempat. */
const v = (n) => `rgb(var(--${n}) / <alpha-value>)`
export default {
  content: ['./index.html', './src/**/*.{vue,js}'],
  darkMode: 'class',
  theme: {
    extend: {
      fontFamily: { sans: ['"Plus Jakarta Sans"', 'system-ui', 'Segoe UI', 'Roboto', 'sans-serif'] },
      colors: {
        latar: v('latar'), permukaan: v('permukaan'), permukaan2: v('permukaan-2'),
        garis: v('garis'), teks: v('teks'), teks2: v('teks-2'), teks3: v('teks-3'),
        merah: v('merah'), aksen: v('aksen'),
      },
      borderRadius: { kartu: '1.125rem' },
      boxShadow: {
        kartu: '0 1px 2px rgb(var(--bayang) / .06), 0 6px 20px -8px rgb(var(--bayang) / .14)',
        apung: '0 8px 24px -6px rgb(var(--bayang) / .35)',
      },
      screens: { cetak: { raw: 'print' } },
    },
  },
  plugins: [],
}
