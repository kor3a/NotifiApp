import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
  // Build static assets directly into /out for S3 uploads
  build: {
    outDir: "out",
  },
  plugins: [react(), tailwindcss()],
})
