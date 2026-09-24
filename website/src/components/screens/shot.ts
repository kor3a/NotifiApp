/* ---------------------------------------------------------------------------
   Real device screenshots, and the bezel that holds them.

   Every shot the app produces lands at 920x2000, so the frame is derived from
   that rather than guessed: a phone whose screen is a different aspect to the
   image would stretch it.
   --------------------------------------------------------------------------- */

export const SHOT = { width: 920, height: 2000 };

/** What PhoneFrame draws on every side, and its default outer width. */
const BEZEL = 3;
const WIDTH = 274;

/** How wide every screenshot is drawn, in CSS px. scripts/shots.mjs mirrors it. */
export const SCREEN_WIDTH = WIDTH - BEZEL * 2;

export const SHOT_FRAME = {
  width: WIDTH,
  height: Math.round((SCREEN_WIDTH * SHOT.height) / SHOT.width) + BEZEL * 2,
};

/**
 * The copies of a screenshot that scripts/shots.mjs pre-shrinks to 1x, 2x and
 * 3x the drawn width, so the browser never has to shrink 920px to 268 itself.
 * `name` is the file in public/ without its extension.
 */
export function shotSources(name: string) {
  const at = (density: number) => `/shots/${name}-${SCREEN_WIDTH * density}.webp`;
  return {
    src: at(2),
    srcSet: [1, 2, 3].map((d) => `${at(d)} ${SCREEN_WIDTH * d}w`).join(", "),
    sizes: `${SCREEN_WIDTH}px`,
  };
}
