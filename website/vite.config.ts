import { existsSync } from 'node:fs'
import { fileURLToPath } from 'node:url'

import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

/* The In practice swipe is played from two real screenshots (see
   src/components/screens/SwipePhone.tsx). Whether they are in public/ is
   settled here, at build time, rather than probed in the browser: the page is
   prerendered, so a runtime check would ship markup pointing at files that
   aren't there and swap it out only after hydration — a flash of broken images
   on every visit. Deciding here keeps the client and SSR builds agreeing, and
   means the drawn fallback is what gets prerendered while the shots are
   missing. Adding the files takes a restart in dev, since this runs once. */
const swipeShots = ['allim-swipe-rest.webp', 'allim-swipe-action.webp'].every((file) =>
  existsSync(fileURLToPath(new URL(`public/${file}`, import.meta.url))),
)

export default defineConfig(({ isSsrBuild }) => ({
  define: {
    __SWIPE_SHOTS__: JSON.stringify(swipeShots),
  },
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
