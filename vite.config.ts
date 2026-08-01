import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
      '@/app': path.resolve(__dirname, './src/pages'),
      '@/components': path.resolve(__dirname, './src/components'),
      '@/lib': path.resolve(__dirname, './src/lib'),
      '@/hooks': path.resolve(__dirname, './src/hooks'),
      // Next.js compatibility shims (Vite does not resolve these)
      'next/navigation': path.resolve(__dirname, './src/lib/next/navigation.ts'),
      'next/link': path.resolve(__dirname, './src/lib/next/link.tsx'),
      'next/dynamic': path.resolve(__dirname, './src/lib/next/dynamic.tsx'),
      'next/font/google': path.resolve(__dirname, './src/lib/next/font-google.ts'),
    },
  },
  build: {
    outDir: 'dist',
    emptyOutDir: true,
  },
  server: {
    port: 5178,
    strictPort: true,
  },
})
