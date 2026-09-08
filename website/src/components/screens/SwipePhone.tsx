import { useEffect, useState } from "react";
import type { CSSProperties, ReactNode } from "react";

import PhoneFrame from "../PhoneFrame";

/* ---------------------------------------------------------------------------
   The swipe, rebuilt from two real screenshots.

   Screenshot one is the stores list at rest. Screenshot two is the same list
   with the "On My Way" action open — in the app that is a leading swipe
   (StoresView.swift), so the row slides right and the sage action is uncovered
   on its left. Because both shots frame the phone identically, the swipe can be
   played back from them with no video and no third asset: stack them, clip both
   to the band the row occupies, and slide the rest shot's copy of that band to
   the right. What it uncovers is the action already sitting underneath, and at
   full travel the sliding row lands exactly on the swiped row beneath it. The
   pixels the animation shows are, at every frame, pixels the app drew.

   CALIBRATION — the four numbers below are measured off the screenshots, in
   source-image pixels. Open either shot in any image viewer and read off:
     SHOT          the pixel size of the images (both must match)
     ROW.top       the y of the top edge of the store row being swiped
     ROW.height    the height of that row, including the gap the action fills
     TRAVEL        how far the row moved — the width of the revealed action,
                   i.e. the x of the row's left edge in the swiped shot
   Everything else scales off those, so nothing needs touching if the phone or
   the section is resized later.
   --------------------------------------------------------------------------- */

const REST = "/allim-swipe-rest.webp";
const ACTION = "/allim-swipe-action.webp";

/* Provisional, measured off the stores screenshot the hero already uses: at
   920x2000 its rows are 151 tall, the second one starting at y=717. Re-measure
   against the two shots when they land — nothing else here needs changing. */
const SHOT = { width: 920, height: 2000 };
const ROW = { top: 717, height: 151 };
const TRAVEL = 200;

/** The bezel PhoneFrame draws on every side, in CSS px. */
const BEZEL = 3;

/** Frame sized to the screenshot so the image is never stretched. */
const FRAME = (() => {
  const width = 274;
  const screen = width - BEZEL * 2;
  return { width, height: Math.round((screen * SHOT.height) / SHOT.width) + BEZEL * 2 };
})();

const band = {
  top: `${(ROW.top / SHOT.height) * 100}%`,
  height: `${(ROW.height / SHOT.height) * 100}%`,
};

/* The clipped band shows one row of a full-height screenshot, so the image
   inside it is blown up to the whole screen's height and pulled up until the
   row lands in view. */
const inBand = {
  height: `${(SHOT.height / ROW.height) * 100}%`,
  top: `${-(ROW.top / ROW.height) * 100}%`,
};

const ALT =
  "The Allim stores list, with a store's row swiped to reveal the sage " +
  "“On My Way” action that tells everyone on that list you're heading there.";

interface Props {
  /** Drawn in a plain frame if either screenshot is missing, so the section
   *  survives the files not being in place rather than breaking. */
  fallback: ReactNode;
}

export default function SwipePhone({ fallback }: Props) {
  const [shotsPresent, setShotsPresent] = useState(true);

  /* The markup is prerendered, so a missing file has already failed by the time
     React hydrates and no onError of ours would ever fire. Ask the browser
     directly instead — both shots are in cache by then, so this costs nothing. */
  useEffect(() => {
    let live = true;
    const loads = (src: string) =>
      new Promise<boolean>((resolve) => {
        const probe = new Image();
        probe.onload = () => resolve(true);
        probe.onerror = () => resolve(false);
        probe.src = src;
      });

    Promise.all([loads(REST), loads(ACTION)]).then((found) => {
      if (live && !found.every(Boolean)) setShotsPresent(false);
    });

    return () => {
      live = false;
    };
  }, []);

  if (!shotsPresent) return <PhoneFrame>{fallback}</PhoneFrame>;

  return (
    <PhoneFrame chrome={false} width={FRAME.width} height={FRAME.height}>
      <div className="relative h-full w-full overflow-hidden">
        {/* The list at rest, carrying its own status bar and home indicator. */}
        <img
          src={REST}
          width={SHOT.width}
          height={SHOT.height}
          alt={ALT}
          className="absolute inset-0 h-full w-full object-cover"
          draggable={false}
        />

        <div className="absolute inset-x-0 overflow-hidden" style={band} aria-hidden="true">
          {/* Underneath: the swiped shot, so what the slide uncovers is the real
              action button rather than a re-drawn one. */}
          <div className="absolute inset-x-0" style={inBand}>
            <img
              src={ACTION}
              width={SHOT.width}
              height={SHOT.height}
              alt=""
              className="h-full w-full object-cover"
              draggable={false}
            />
          </div>

          {/* On top: the same row at rest, sliding right off the action. */}
          <div
            className="swipe-shot absolute inset-0"
            style={{ "--swipe-travel": `${(TRAVEL / SHOT.width) * 100}%` } as CSSProperties}
          >
            <div className="absolute inset-x-0" style={inBand}>
              <img
                src={REST}
                width={SHOT.width}
                height={SHOT.height}
                alt=""
                className="h-full w-full object-cover"
                draggable={false}
              />
            </div>
          </div>
        </div>
      </div>
    </PhoneFrame>
  );
}
