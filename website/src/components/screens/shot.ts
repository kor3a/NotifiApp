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

export const SHOT_FRAME = {
  width: WIDTH,
  height: Math.round(((WIDTH - BEZEL * 2) * SHOT.height) / SHOT.width) + BEZEL * 2,
};
