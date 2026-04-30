import type { CSSProperties, ReactNode } from "react";
import { useInView } from "../hooks/useInView";

interface FadeInProps {
  children: ReactNode;
  delay?: number;
  className?: string;
  style?: CSSProperties;
}

export default function FadeIn({ children, delay = 0, className = "", style }: FadeInProps) {
  const { ref, inView } = useInView<HTMLDivElement>();
  return (
    <div
      ref={ref}
      style={{ transitionDelay: `${delay}ms`, ...style }}
      className={`fade-in-up ${inView ? "is-visible" : ""} ${className}`.trim()}
    >
      {children}
    </div>
  );
}
