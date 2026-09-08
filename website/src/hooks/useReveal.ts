import { useEffect, useRef } from "react";

const OPTIONS: IntersectionObserverInit = {
  threshold: 0.15,
  rootMargin: "0px 0px -10% 0px",
};

/**
 * Reveals an element once it scrolls into view.
 *
 * The element is rendered *visible* — that is what the server sends, and what
 * a JS-disabled or slow client keeps, so the prerendered page is never a set of
 * blank boxes. Only elements that start below the fold are hidden and animated
 * in, and that happens off-screen where nobody can see the transition run
 * backwards.
 *
 * The visible state is a class on a DOM node, so the observer toggles it on the
 * node directly instead of going through React state: there is nothing here for
 * React to re-render, and driving it from state would cascade a render for
 * every element on the page as it scrolls past.
 */
export function useReveal<T extends HTMLElement = HTMLDivElement>(once = true) {
  const ref = useRef<T | null>(null);

  useEffect(() => {
    const node = ref.current;
    if (!node) return;

    // Already on screen at load: keep the state the server rendered.
    if (node.getBoundingClientRect().top <= window.innerHeight) return;

    node.classList.remove("is-visible");

    const observer = new IntersectionObserver(([entry]) => {
      if (entry.isIntersecting) {
        node.classList.add("is-visible");
        if (once) observer.unobserve(entry.target);
      } else if (!once) {
        node.classList.remove("is-visible");
      }
    }, OPTIONS);

    observer.observe(node);
    return () => observer.disconnect();
  }, [once]);

  return ref;
}
