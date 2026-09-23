import { gsap } from "gsap";
import { useGSAP } from "@gsap/react";
import { DrawSVGPlugin } from "gsap/DrawSVGPlugin";
import { MotionPathPlugin } from "gsap/MotionPathPlugin";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import { SplitText } from "gsap/SplitText";

// The prerenderer imports every component in Node, where there is no window
// for ScrollTrigger to measure. Registering only in the browser keeps that
// import side-effect free.
if (typeof window !== "undefined") {
  gsap.registerPlugin(useGSAP, ScrollTrigger, SplitText, DrawSVGPlugin, MotionPathPlugin);
  // Mobile browsers resize the viewport as the address bar hides; without
  // this every pinned section would re-measure mid-scroll and jump.
  ScrollTrigger.config({ ignoreMobileResize: true });
  // Three webfonts change line lengths, and so the height of everything
  // below them, after the first measure. Pins are placed from that measure.
  document.fonts?.ready.then(() => ScrollTrigger.refresh());
}

/**
 * Every animation on the site runs inside this query. With reduced motion the
 * page is simply the prerendered markup: fully laid out and fully visible.
 */
export const MOTION_OK = "(prefers-reduced-motion: no-preference)";

export { gsap, useGSAP, ScrollTrigger, SplitText };
