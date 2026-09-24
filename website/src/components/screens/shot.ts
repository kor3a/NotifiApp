/* ---------------------------------------------------------------------------
   Real device screenshots, and the bezel that holds them.

   Every shot the app produces lands at 920x2000, so the frame is derived from
   that rather than guessed: a phone whose screen is a different aspect to the
   image would stretch it.
   --------------------------------------------------------------------------- */

export const SHOT = { width: 920, height: 2000 };

/** What PhoneFrame draws on every side. */
const BEZEL = 3;

/**
 * How wide every screenshot is drawn, in CSS px, when there's room for it; on
 * narrower screens the phone shrinks to fit. 345 is a multiple of 23, so with
 * the shots' 23:50 aspect the screen comes out a whole 750px tall and the swipe
 * band can sit on whole pixels. scripts/shots.mjs mirrors it.
 */
export const SCREEN_WIDTH = 345;

export const SHOT_FRAME = {
  width: SCREEN_WIDTH + BEZEL * 2,
  height: Math.round((SCREEN_WIDTH * SHOT.height) / SHOT.width) + BEZEL * 2,
};

/** The widths scripts/shots.mjs writes: 1x and 2x, then the source itself,
 *  since 3x would be past what the app exported. */
export const SHOT_WIDTHS = [SCREEN_WIDTH, SCREEN_WIDTH * 2, SHOT.width];

/**
 * The copies of a screenshot that scripts/shots.mjs pre-shrinks, so the
 * browser never has to shrink the 920px export itself. `name` is the file in
 * public/ without its extension.
 */
export function shotSources(name: string) {
  const at = (width: number) => `/shots/${name}-${width}.webp`;
  return {
    src: at(SCREEN_WIDTH * 2),
    srcSet: SHOT_WIDTHS.map((w) => `${at(w)} ${w}w`).join(", "),
    sizes: `(max-width: ${SHOT_FRAME.width + 48}px) calc(100vw - 54px), ${SCREEN_WIDTH}px`,
  };
}
