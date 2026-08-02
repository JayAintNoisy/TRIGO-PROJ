/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './index.html',
    './src/**/*.{vue,js,ts,jsx,tsx}',
  ],
  theme: {
    extend: {
      colors: {
        brand: {
          blue: {
            light: '#60A5FA',
            base: '#2563EB',
            dark: '#1D4ED8',
            deep: '#1E3A8A',
          },
          green: {
            light: '#D1FAE5',
            base: '#10B981',
            dark: '#059669',
          },
          orange: {
            base: '#F97316',
          },
          yellow: {
            base: '#EAB308',
          },
          purple: {
            light: '#F3E8FF',
            base: '#A855F7',
          },
          slate: {
            50: '#F8FAFC',
            200: '#E2E8F0',
            500: '#64748B',
            900: '#0F172A',
          },
        },
      },
      borderRadius: {
        '2xl': '1.5rem', // 24px
      },
    },
  },
  plugins: [],
};
