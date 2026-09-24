/* ---------------------------------------------------------------------------
   Pre-shrink the device screenshots to the sizes the phones actually draw.

   Every phone on the page shows its screenshot at most 345 CSS px wide, well
   under the 920px the app exports. Left to the browser, that shrink happens
   at paint time with a fast filter, and on a 1x screen the app's smaller text
   (tab labels, subtitles) comes out smudged. Doing it here with Lanczos, at
   exactly 1x and 2x the drawn width (and the full 920 for denser screens),
   keeps it legible; the components pick one through srcset.

   Runs at the start of every build, so a replaced screenshot can't leave stale
   copies behind. Output is committed so `npm run dev` works without it.
   --------------------------------------------------------------------------- */

import { mkdir, rm } from "node:fs/promises";
import sharp from "sharp";

// Mirrors SCREEN_WIDTH and SHOT_WIDTHS in src/components/screens/shot.ts.
const SCREEN_WIDTH = 345;
const WIDTHS = [SCREEN_WIDTH, SCREEN_WIDTH * 2, 920];

const SOURCES = [
  "allim-stores-screen.webp",
  "allim-reminderview.png",
  "allim-swipe-rest.png",
  "allim-swipe-action.png",
];

const out = new URL("../public/shots/", import.meta.url);
// Start clean, so copies at a size no longer used don't linger.
await rm(out, { recursive: true, force: true });
await mkdir(out, { recursive: true });

for (const file of SOURCES) {
  const src = new URL(`../public/${file}`, import.meta.url).pathname;
  const name = file.replace(/\.\w+$/, "");

  for (const width of WIDTHS) {
    const resized = sharp(src).resize({ width, kernel: "lanczos3" });
    // At 1x the smallest labels are only ~8px tall; a light sharpen brings their
    // strokes back without haloing. Denser copies have the pixels to not need it.
    if (width === SCREEN_WIDTH) resized.sharpen({ sigma: 0.5 });
    await resized
      .webp(
        width === 920
          ? // Only 3x phone screens get this one, where lossy WebP's softening
            // is far below a pixel; near-lossless would triple its weight.
            { quality: 90, smartSubsample: true, effort: 6 }
          : // Screenshots are flat UI and text: near-lossless keeps edges clean
            // at a fraction of PNG's size, where lossy would smear coloured text.
            { nearLossless: true, quality: 80, effort: 6 },
      )
      .toFile(new URL(`${name}-${width}.webp`, out).pathname);
  }
}
