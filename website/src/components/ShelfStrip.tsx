import { useRef } from "react";
import { gsap, MOTION_OK, ScrollTrigger, useGSAP } from "../lib/gsap";

/* What actually ends up on people's lists, each with the aisle Smart Category
   files it under. Priced the way a shelf strip prices things, in the app's own
   unit of account: whether you remembered it. */
const ITEMS = [
  { name: "Oat milk", dot: "bg-dairy" },
  { name: "Sourdough", dot: "bg-bakery" },
  { name: "Bananas", dot: "bg-produce" },
  { name: "Chicken thighs", dot: "bg-meat" },
  { name: "Gochujang", dot: "bg-pantry" },
  { name: "Frozen dumplings", dot: "bg-frozen" },
  { name: "Sparkling water", dot: "bg-beverages" },
  { name: "Seaweed snacks", dot: "bg-snacks" },
  { name: "Paper towels", dot: "bg-household" },
  { name: "Greek yogurt", dot: "bg-dairy" },
  { name: "Scallions", dot: "bg-produce" },
  { name: "Olive oil", dot: "bg-pantry" },
];

function Row({ hidden = false }: { hidden?: boolean }) {
  return (
    <ul className="flex shrink-0 items-center" aria-hidden={hidden || undefined}>
      {ITEMS.map((item) => (
        <li
          key={item.name}
          className="flex items-center gap-3 border-r border-ink/15 px-7 py-3.5 whitespace-nowrap"
        >
          <span className={`h-2.5 w-2.5 rounded-full ${item.dot}`} aria-hidden="true" />
          <span className="text-[15px] font-semibold text-ink">{item.name}</span>
          <span className="mono text-[12px] font-medium text-ink/55">REMEMBERED</span>
        </li>
      ))}
    </ul>
  );
}

export default function ShelfStrip() {
  const root = useRef<HTMLDivElement>(null);

  useGSAP(
    () => {
      const mm = gsap.matchMedia();
      mm.add(MOTION_OK, () => {
        // Two copies of the row side by side; sliding one full row's width and
        // wrapping makes the loop seamless.
        const loop = gsap.to(".strip-track", {
          xPercent: -50,
          duration: 42,
          ease: "none",
          repeat: -1,
        });
        // Start deep into the repeats so scrolling back up can run it
        // backwards without hitting the beginning and stopping.
        loop.totalTime(loop.duration() * 1000);

        // Scrolling pushes the belt along: faster the harder you scroll, and
        // backwards when you scroll back up. It eases back to its idle pace.
        let direction = 1;
        const st = ScrollTrigger.create({
          trigger: root.current,
          start: "top bottom",
          end: "bottom top",
          onUpdate: (self) => {
            direction = self.direction;
            const boost = gsap.utils.clamp(1, 6, Math.abs(self.getVelocity()) / 250);
            gsap.to(loop, { timeScale: boost * direction, duration: 0.2, overwrite: true });
            gsap.to(loop, { timeScale: direction, duration: 1.2, delay: 0.2, ease: "power2.out" });
          },
        });

        return () => st.kill();
      });
    },
    { scope: root },
  );

  return (
    <div ref={root} className="shelf-strip relative z-10 -ml-[2%] w-[104%] -rotate-1 overflow-hidden">
      <div className="strip-track flex w-max">
        <Row />
        <Row hidden />
      </div>
    </div>
  );
}
