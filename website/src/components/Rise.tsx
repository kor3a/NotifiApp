import { useRef, type CSSProperties, type ReactNode } from "react";
import { ensureMotion, gsap, reducedMotion, useIsoLayoutEffect } from "../lib/motion";

interface RiseProps {
  children: ReactNode;
  /** Stagger delay in ms, matching the old CSS API. */
  delay?: number;
  className?: string;
  style?: CSSProperties;
  from?: "up" | "left" | "right" | "scale";
  distance?: number;
}

const OFFSETS = {
  up: { x: 0, y: 28 },
  left: { x: -36, y: 0 },
  right: { x: 36, y: 0 },
  scale: { x: 0, y: 12 },
} as const;

/**
 * The site's entrance transition, now GSAP-driven. Same contract as before:
 * everything renders visible (SSR-safe, reduced-motion-safe) and only
 * below-the-fold elements are hidden, off-screen, before animating in.
 */
export default function Rise({
  children,
  delay = 0,
  className = "",
  style,
  from = "up",
  distance = 1,
}: RiseProps) {
  const ref = useRef<HTMLDivElement | null>(null);

  useIsoLayoutEffect(() => {
    const node = ref.current;
    if (!node || reducedMotion()) return;
    ensureMotion();

    const { x, y } = OFFSETS[from];
    const fromVars = {
      opacity: 0,
      x: x * distance,
      y: y * distance,
      scale: from === "scale" ? 0.96 : 1,
    };
    const inView = node.getBoundingClientRect().top <= window.innerHeight * 0.94;

    const ctx = gsap.context(() => {
      gsap.set(node, fromVars);
      gsap.to(node, {
        opacity: 1,
        x: 0,
        y: 0,
        scale: 1,
        duration: 0.9,
        delay: delay / 1000,
        ease: "power3.out",
        scrollTrigger: inView
          ? undefined
          : { trigger: node, start: "top 88%", once: true },
      });
    });
    return () => ctx.revert();
  }, []);

  return (
    <div ref={ref} className={className} style={style}>
      {children}
    </div>
  );
}
