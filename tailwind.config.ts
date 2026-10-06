import type { Config } from 'tailwindcss'

const config: Config = {
  darkMode: ['class'],
  content: [
    './pages/**/*.{js,ts,jsx,tsx,mdx}',
    './components/**/*.{js,ts,jsx,tsx,mdx}',
    './app/**/*.{js,ts,jsx,tsx,mdx}',
    './lib/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        ink:       '#0B1020',
        'off-white': '#F4F1EA',
        amber:     '#FFB020',
        teal:      '#2DD4BF',
        muted:     '#6B7280',
        surface:   '#111827',
        border:    '#1F2937',
      },
      fontFamily: {
        display: ['Space Grotesk', 'sans-serif'],
        sans:    ['Inter', 'sans-serif'],
        mono:    ['JetBrains Mono', 'monospace'],
      },
      spacing: {
        '18': '4.5rem',
        '22': '5.5rem',
        '72': '18rem',
        '84': '21rem',
        '96': '24rem',
      },
      animation: {
        'pulse-slow':  'pulse 3s cubic-bezier(0.4, 0, 0.6, 1) infinite',
        'spin-slow':   'spin 8s linear infinite',
        'fade-in':     'fadeIn 0.5s ease-out forwards',
        'slide-up':    'slideUp 0.4s ease-out forwards',
      },
      keyframes: {
        fadeIn: {
          from: { opacity: '0' },
          to:   { opacity: '1' },
        },
        slideUp: {
          from: { opacity: '0', transform: 'translateY(20px)' },
          to:   { opacity: '1', transform: 'translateY(0)' },
        },
      },
      backgroundImage: {
        'grid-pattern': 'linear-gradient(rgba(255,255,255,0.03) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.03) 1px, transparent 1px)',
        'radial-ink':   'radial-gradient(ellipse at center, #111827 0%, #0B1020 100%)',
      },
      backgroundSize: {
        'grid-sm': '32px 32px',
        'grid-md': '64px 64px',
      },
      borderRadius: {
        xl: '0.75rem',
        '2xl': '1rem',
        '3xl': '1.5rem',
      },
    },
  },
  plugins: [],
}
export default config
