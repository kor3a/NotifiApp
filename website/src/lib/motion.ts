import { useEffect, useLayoutEffect } from "react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";

/**
 * Shared motion setup for the Allim site.
 *
 * GSAP drives scroll-linked and timeline animation; anime.js drives
 * micro-interactions (pops, wiggles, accordion easing). Every effect in this
 * codebase follows two rules:
 *
 * 1. The server renders everything visible. Initial hidden states are set
 *    inside effects, so a JS-disabled or slow client never sees blank boxes
 *    and hydration always matches.
 * 2. `prefers-reduced-motion` skips all of it.
 */

let registered = false;

export function ensureMotion() {
  if (!registered) {
    gsap.registerPlugin(ScrollTrigger);
    registered = true;
  }
}

export function reducedMotion(): boolean {
  return (
    typeof window !== "undefined" &&
    window.matchMedia("(prefers-reduced-motion: reduce)").matches
  );
}

export function finePointer(): boolean {
  return (
    typeof window !== "undefined" &&
    window.matchMedia("(pointer: fine)").matches
  );
}

/** useLayoutEffect on the client, useEffect on the server (no SSR warning). */
export const useIsoLayoutEffect =
  typeof window !== "undefined" ? useLayoutEffect : useEffect;

/**
 * Run GSAP code inside a revertible context. The setup runs after
 * ScrollTrigger is registered and is skipped entirely under
 * prefers-reduced-motion. Cleanup reverts everything the context created.
 */
export function useGsap(setup: () => void | (() => void), deps: unknown[] = []) {
  useIsoLayoutEffect(() => {
    if (reducedMotion()) return;
    ensureMotion();
    const ctx = gsap.context(() => {
      const cleanup = setup();
      if (typeof cleanup === "function") return cleanup;
    });
    return () => ctx.revert();
    // deps are the caller's contract, exactly like useEffect's.
  }, deps);
}

export { gsap, ScrollTrigger };
