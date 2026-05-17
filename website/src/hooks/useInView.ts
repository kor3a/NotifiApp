import { useEffect, useRef, useState } from "react";

const DEFAULT_OPTIONS: IntersectionObserverInit = {
  threshold: 0.15,
  rootMargin: "0px 0px -10% 0px",
};

export function useInView<T extends HTMLElement = HTMLDivElement>(
  options: IntersectionObserverInit = DEFAULT_OPTIONS,
  once = true,
) {
  const ref = useRef<T | null>(null);
  // Visible by default so prerendered content paints with the HTML/CSS,
  // independent of JS. Only elements that start below the fold get hidden
  // and animated in — that happens off-screen, so there is never a blank
  // or flashing region the user can actually see.
  const [inView, setInView] = useState(true);

  useEffect(() => {
    const node = ref.current;
    if (!node) return;

    const belowFold =
      node.getBoundingClientRect().top > window.innerHeight;
    if (!belowFold) return; // already visible at load: keep it shown

    setInView(false);

    const observer = new IntersectionObserver(([entry]) => {
      if (entry.isIntersecting) {
        setInView(true);
        if (once) observer.unobserve(entry.target);
      } else if (!once) {
        setInView(false);
      }
    }, options);

    observer.observe(node);
    return () => observer.disconnect();
  }, [once, options]);

  return { ref, inView };
}
