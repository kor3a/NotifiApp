import type { CSSProperties } from "react";

import PhoneFrame from "../PhoneFrame";
import { SCREEN_WIDTH, SHOT, SHOT_FRAME, shotSources } from "./shot";

/* ---------------------------------------------------------------------------
   The swipe, played from two real screenshots.

   One is the stores list at rest, the other the same list with the "On My Way"
   action open — a leading swipe in the app (StoresView.swift), so the row slides
   right and the sage action is uncovered on its left. Because both shots frame
   the phone identically, the interaction can be played back from them with no
   video and no third asset: stack them, clip both to the band the row occupies,
   and slide the resting row off the action sitting underneath. At full travel
   the sliding row lands exactly on the swiped row beneath it, so every frame is
   pixels the app drew.

   CALIBRATION — measured by diffing the two shots: the rows that differ are the
   band, and the horizontal shift that aligns them is the travel (at 920x2000,
   y 340 to 515 and 203px, the row's left edge moving 46 to 249). Kept as shares
   of the image so re-exporting the screenshots at another resolution leaves
   them correct; only the aspect has to hold.
   --------------------------------------------------------------------------- */

const REST = shotSources("allim-swipe-rest");
const ACTION = shotSources("allim-swipe-action");

const ROW = { top: 340 / 2000, height: 176 / 2000 };

/* The travel in whole CSS px (59 of the 268 drawn). As a percentage it came to
   59.14px, and the row then spent every hold of the loop parked off the pixel
   grid, where the browser resamples it and the row's text goes soft next to
   the rest of the screenshot. The 0.14px it gives up is invisible. */
const TRAVEL_PX = Math.round((203 / 920) * SCREEN_WIDTH);

/* Everything below is laid out in whole px of the drawn screen, for the same
   reason as the travel: the band's strip of screenshot has to land on exactly
   the pixels of the full shot behind it, or it reads softer than its
   surroundings. */
const SCREEN_HEIGHT = SHOT_FRAME.height - (SHOT_FRAME.width - SCREEN_WIDTH);
const BAND_TOP = Math.round(ROW.top * SCREEN_HEIGHT);

const band = {
  top: `${BAND_TOP}px`,
  height: `${Math.round(ROW.height * SCREEN_HEIGHT)}px`,
};

/* The clipped band shows one row of a full-height screenshot, so the image
   inside it is the whole screen's height, pulled up until the row lands in
   view. */
const inBand = {
  height: `${SCREEN_HEIGHT}px`,
  top: `${-BAND_TOP}px`,
};

const ALT =
  "The Allim stores list, with the Walmart row swiped to reveal the sage " +
  "“On My Way” action that tells everyone on that list you're heading there.";

/** The full screenshot, positioned so the swiped row fills the clipped band. */
function BandShot({ shot }: { shot: ReturnType<typeof shotSources> }) {
  return (
    <div className="absolute inset-x-0" style={inBand}>
      <img
        {...shot}
        width={SHOT.width}
        height={SHOT.height}
        alt=""
        className="h-full w-full object-cover"
        loading="lazy"
        draggable={false}
      />
    </div>
  );
}

export default function SwipePhone() {
  return (
    <PhoneFrame chrome={false} width={SHOT_FRAME.width} height={SHOT_FRAME.height}>
      <div className="relative h-full w-full overflow-hidden">
        {/* The list at rest, carrying its own status bar and home indicator. */}
        <img
          {...REST}
          width={SHOT.width}
          height={SHOT.height}
          alt={ALT}
          className="absolute inset-0 h-full w-full object-cover"
          /* Three shots this far down the page have no business preloading;
             React emits a preload link for every img that isn't lazy. */
          loading="lazy"
          draggable={false}
        />

        <div className="absolute inset-x-0 overflow-hidden" style={band} aria-hidden="true">
          {/* Underneath: the swiped shot, so what the slide uncovers is the real
              action button rather than a re-drawn one. */}
          <BandShot shot={ACTION} />

          {/* On top: the same row at rest, sliding right off the action. */}
          <div
            className="swipe-shot absolute inset-0"
            style={{ "--swipe-travel": `${TRAVEL_PX}px` } as CSSProperties}
          >
            <BandShot shot={REST} />
          </div>
        </div>
      </div>
    </PhoneFrame>
  );
}
