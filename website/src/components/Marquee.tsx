import { useRef } from "react";
import { gsap, useGsap } from "../lib/motion";

/* A ticker of groceries filing themselves into aisles — the Smart Category
   story as a marquee. GSAP loops it seamlessly; it pauses on hover. */

const ITEMS = [
  { name: "Milk", dot: "bg-dairy" },
  { name: "Sourdough", dot: "bg-bakery" },
  { name: "Eggs", dot: "bg-dairy" },
  { name: "Honeycrisp apples", dot: "bg-produce" },
  { name: "Chicken thighs", dot: "bg-meat" },
  { name: "Basmati rice", dot: "bg-pantry" },
  { name: "Vanilla ice cream", dot: "bg-frozen" },
  { name: "Cold brew", dot: "bg-beverages" },
  { name: "Sea salt chips", dot: "bg-snacks" },
  { name: "Paper towels", dot: "bg-household" },
  { name: "Cherry tomatoes", dot: "bg-produce" },
  { name: "Greek yogurt", dot: "bg-dairy" },
];

function Row({ ariaHidden = false }: { ariaHidden?: boolean }) {
  return (
    <div className="marquee-row" aria-hidden={ariaHidden || undefined}>
      {ITEMS.map((item) => (
        <span key={item.name} className="marquee-item">
          <span className={`h-2 w-2 rounded-full ${item.dot}`} aria-hidden="true" />
          {item.name}
        </span>
      ))}
    </div>
  );
}

export default function Marquee() {
  const ref = useRef<HTMLDivElement | null>(null);

  useGsap(() => {
    const track = ref.current!.querySelector(".marquee-track") as HTMLElement;
    const loop = gsap.to(track, {
      xPercent: -50,
      ease: "none",
      duration: 36,
      repeat: -1,
    });
    const el = ref.current!;
    const pause = () => loop.pause();
    const play = () => loop.play();
    el.addEventListener("mouseenter", pause);
    el.addEventListener("mouseleave", play);
    return () => {
      el.removeEventListener("mouseenter", pause);
      el.removeEventListener("mouseleave", play);
    };
  });

  return (
    <div ref={ref} className="marquee border-b border-line bg-card" role="presentation">
      <div className="marquee-track">
        <Row />
        <Row ariaHidden />
      </div>
    </div>
  );
}
