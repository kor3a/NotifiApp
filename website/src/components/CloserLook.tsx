import type { ReactNode } from "react";
import { useRef } from "react";
import { gsap, MOTION_OK, ScrollTrigger, useGSAP } from "../lib/gsap";
import PhoneFrame from "./PhoneFrame";
import ReminderScreen from "./screens/ReminderScreen";
import ShareScreen from "./screens/ShareScreen";
import SmartRecipeScreen from "./screens/SmartRecipeScreen";

type Row = {
  id: string;
  label: string;
  title: string;
  lead: string;
  points: { title: string; desc: string; dot: string }[];
  screen: ReactNode;
};

const rows: Row[] = [
  {
    id: "sharing",
    label: "sharing",
    title: "Shop together, even when you're apart",
    lead: "Hand a store's list to anyone: partner, roommates, your mom. Everyone sees the same list, and you decide who can change it.",
    points: [
      { title: "Can edit", desc: "Add things, check them off, and it syncs both ways.", dot: "bg-dairy" },
      { title: "View only", desc: "Let someone see the list without touching it.", dot: "bg-household" },
      {
        title: "“On my way”",
        desc: "When someone heads to the store, everyone else gets a chance to add one more thing.",
        dot: "bg-snacks",
      },
    ],
    screen: <ShareScreen />,
  },
  {
    id: "recipe",
    label: "smart recipe",
    title: "From “what's for dinner?” to a full list",
    lead: "Ask for a recipe in plain words. Allim writes out the steps and puts every ingredient on the list for the store you'd buy it at.",
    points: [
      { title: "Ask like a person", desc: "“Something spicy, 30 minutes, uses the chicken.” That works.", dot: "bg-meat" },
      { title: "Steps and swaps", desc: "Full instructions, plus what to use if you're missing something.", dot: "bg-bakery" },
      { title: "One tap to the list", desc: "Ingredients land on the right store's list.", dot: "bg-pantry" },
    ],
    screen: <SmartRecipeScreen />,
  },
  {
    id: "category",
    label: "smart category",
    title: "The list sorts itself",
    lead: "Groceries get grouped by aisle the moment they're added, whether you typed them or pulled them from a recipe.",
    points: [
      { title: "By aisle", desc: "Produce with produce, dairy with dairy. No dragging rows around.", dot: "bg-produce" },
      { title: "Imports too", desc: "Recipe ingredients get filed the same way.", dot: "bg-frozen" },
      { title: "Per store", desc: "Turn it off for the shop where you already know the layout.", dot: "bg-beverages" },
    ],
    screen: <ReminderScreen />,
  },
];

export default function CloserLook() {
  const root = useRef<HTMLElement>(null);

  useGSAP(
    () => {
      const mm = gsap.matchMedia();

      // The sticky phone swaps screens as each block reaches the middle of
      // the viewport. With reduced motion it still swaps, just without the
      // tumble.
      mm.add(
        { wide: "(min-width: 1024px)", motion: MOTION_OK },
        (ctx) => {
          const { wide, motion } = ctx.conditions as { wide: boolean; motion: boolean };

          if (motion) {
            gsap.utils.toArray<HTMLElement>(".closer-block").forEach((block) => {
              gsap.from(block.querySelectorAll(".closer-in"), {
                y: 28,
                autoAlpha: 0,
                stagger: 0.07,
                duration: 0.8,
                ease: "power3.out",
                scrollTrigger: { trigger: block, start: "top 72%" },
              });
            });
          }

          if (!wide) return;

          const screens = gsap.utils.toArray<HTMLElement>(".closer-screen");
          gsap.set(screens, { autoAlpha: 0 });
          gsap.set(screens[0], { autoAlpha: 1 });
          let current = 0;

          const show = (next: number) => {
            if (next === current) return;
            const down = next > current;
            gsap.to(screens[current], {
              autoAlpha: 0,
              yPercent: motion ? (down ? -8 : 8) : 0,
              rotate: motion ? (down ? -4 : 4) : 0,
              duration: motion ? 0.45 : 0,
              ease: "power2.in",
              overwrite: true,
            });
            gsap.fromTo(
              screens[next],
              { autoAlpha: 0, yPercent: motion ? (down ? 10 : -10) : 0, rotate: motion ? (down ? 5 : -5) : 0 },
              { autoAlpha: 1, yPercent: 0, rotate: 0, duration: motion ? 0.7 : 0, delay: motion ? 0.15 : 0, ease: "power3.out", overwrite: true },
            );
            current = next;
          };

          const triggers = gsap.utils.toArray<HTMLElement>(".closer-block").map((block, i) =>
            ScrollTrigger.create({
              trigger: block,
              start: "top center",
              end: "bottom center",
              onToggle: (self) => self.isActive && show(i),
            }),
          );

          return () => triggers.forEach((t) => t.kill());
        },
      );
    },
    { scope: root },
  );

  return (
    <section ref={root} id="capabilities" className="relative bg-paper py-24 md:py-32">
      <div className="mx-auto max-w-6xl px-6">
        <h2 className="display max-w-2xl text-[clamp(2.3rem,5.5vw,3.9rem)] text-ink">
          The parts people ask about.
        </h2>

        <div className="mt-8 grid gap-10 lg:grid-cols-12">
          <div className="lg:col-span-6">
            {rows.map((row) => (
              <div
                key={row.id}
                className="closer-block border-t border-line py-16 lg:flex lg:min-h-[85vh] lg:flex-col lg:justify-center lg:border-t-0"
              >
                <p className="closer-in hand text-[36px] text-orange">{row.label}</p>
                <h3 className="closer-in display mt-2 max-w-md text-[clamp(1.9rem,4vw,2.7rem)] text-ink">
                  {row.title}
                </h3>
                <p className="closer-in mt-5 max-w-md text-[17px] leading-relaxed text-ink-2">
                  {row.lead}
                </p>

                <ul className="mt-8 space-y-4">
                  {row.points.map((point) => (
                    <li key={point.title} className="closer-in flex gap-4">
                      <span
                        className={`mt-[7px] h-2.5 w-2.5 shrink-0 rounded-full ${point.dot}`}
                        aria-hidden="true"
                      />
                      <p className="max-w-sm text-[15px] leading-relaxed text-ink-2">
                        <span className="font-semibold text-ink">{point.title}.</span> {point.desc}
                      </p>
                    </li>
                  ))}
                </ul>

                {/* Below lg (and with JS off) each block carries its own phone. */}
                <div className="closer-inline mt-12 flex justify-center">
                  <PhoneFrame>{row.screen}</PhoneFrame>
                </div>
              </div>
            ))}
          </div>

          {/* At lg, one phone holds still and its screen changes underneath you. */}
          <div className="closer-sticky lg:col-span-5 lg:col-start-8" aria-hidden="true">
            <div className="sticky top-0 flex h-screen items-center justify-center">
              <div className="relative h-[560px] w-[274px]">
                <div className="absolute -inset-10 -rotate-3 rounded-[48px] bg-kraft" />
                {rows.map((row) => (
                  <div key={row.id} className="closer-screen absolute inset-0">
                    <PhoneFrame>{row.screen}</PhoneFrame>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
