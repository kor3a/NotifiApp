/* ---------------------------------------------------------------------------
   Pre-shrink the device screenshots to the sizes the phones actually draw.

   Every phone on the page shows its screenshot 268 CSS px wide, less than a
   third of the 920px the app exports. Left to the browser, that shrink happens
   at paint time with a fast filter, and on a 1x screen the app's smaller text
   (tab labels, subtitles) comes out 5-6px tall and smudged. Doing it here with
   Lanczos, at exactly 1x, 2x and 3x the drawn width, keeps it legible; the
   components pick one through srcset.

   Runs at the start of every build, so a replaced screenshot can't leave stale
   copies behind. Output is committed so `npm run dev` works without it.
   --------------------------------------------------------------------------- */

import { mkdir } from "node:fs/promises";
import sharp from "sharp";

// Mirrors SCREEN_WIDTH in src/components/screens/shot.ts.
const SCREEN_WIDTH = 268;
const DENSITIES = [1, 2, 3];

const SOURCES = [
  "allim-stores-screen.webp",
  "allim-reminderview.png",
  "allim-swipe-rest.png",
  "allim-swipe-action.png",
];

const out = new URL("../public/shots/", import.meta.url);
await mkdir(out, { recursive: true });

for (const file of SOURCES) {
  const src = new URL(`../public/${file}`, import.meta.url).pathname;
  const name = file.replace(/\.\w+$/, "");

  for (const density of DENSITIES) {
    const width = SCREEN_WIDTH * density;
    const resized = sharp(src).resize({ width, kernel: "lanczos3" });
    // At 1x the smallest labels are 5-6px tall; a light sharpen brings their
    // strokes back without haloing. Denser copies have the pixels to not need it.
    if (density === 1) resized.sharpen({ sigma: 0.5 });
    await resized
      // Screenshots are flat UI and text: near-lossless keeps edges clean at a
      // fraction of PNG's size, where lossy WebP would smear coloured text.
      .webp({ nearLossless: true, quality: 80, effort: 6 })
      .toFile(new URL(`${name}-${width}.webp`, out).pathname);
  }
}
