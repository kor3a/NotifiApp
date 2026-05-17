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
  // Start visible so server-prerendered content paints immediately with the
  // HTML/CSS, instead of staying opacity:0 until the JS bundle downloads,
  // hydrates, and an observer fires. JS becomes progressive enhancement.
  const [inView, setInView] = useState(true);

  useEffect(() => {
    // Default callers (once=true) keep the content shown; nothing to watch.
    if (once) return;

    const node = ref.current;
    if (!node) return;

    const observer = new IntersectionObserver(
      ([entry]) => setInView(entry.isIntersecting),
      options,
    );

    observer.observe(node);
    return () => observer.disconnect();
  }, [once, options]);

  return { ref, inView };
}
