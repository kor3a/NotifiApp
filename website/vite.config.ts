import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig(({ isSsrBuild }) => ({
  // Build static assets directly into /out for S3 uploads
  build: {
    outDir: "out",
    rollupOptions: isSsrBuild
      ? undefined
      : {
          output: {
            manualChunks: {
              react: ['react', 'react-dom'],
            },
          },
        },
  },
  plugins: [react(), tailwindcss()],
}))
