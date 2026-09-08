import type { CSSProperties, ReactNode } from "react";
import { useReveal } from "../hooks/useReveal";

interface RiseProps {
  children: ReactNode;
  delay?: number;
  className?: string;
  style?: CSSProperties;
}

/**
 * The site's one entrance transition. Everything that animates in uses this and
 * nothing else — a page where every block arrives with its own flourish reads
 * as a template, so the rule is one move, reused.
 */
export default function Rise({
  children,
  delay = 0,
  className = "",
  style,
}: RiseProps) {
  const ref = useReveal<HTMLDivElement>();
  return (
    <div
      ref={ref}
      style={{ transitionDelay: `${delay}ms`, ...style }}
      className={`rise is-visible ${className}`.trim()}
    >
      {children}
    </div>
  );
}
