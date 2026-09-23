import type { ReactNode } from "react";
import { useRef } from "react";
import { gsap, useGSAP } from "../lib/gsap";
import { PushBanner } from "./screens/parts";

type Aisle = {
  n: number;
  title: string;
  stocks: string;
  kicker: string;
  description: string;
  premium?: boolean;
  shelf: ReactNode;
};

/* -- What sits on each shelf: a small, literal picture of the feature. ------ */

function NudgeShelf() {
  return (
    <div className="rounded-[22px] bg-teal-deep/95 py-4">
      <PushBanner title="You're near Whole Foods" body="Oat milk, sourdough and 3 more." />
    </div>
  );
}

function RecipeShelf() {
  return (
    <div className="space-y-2.5">
      <p className="hand w-fit -rotate-1 rounded-[14px] rounded-bl-[3px] bg-field px-4 py-2 text-[22px] text-ink-2">
        something spicy w/ the chicken in the fridge
      </p>
      <div className="flex flex-wrap gap-1.5 pl-6">
        {[
          ["Gochujang", "bg-pantry"],
          ["Scallions", "bg-produce"],
          ["Short-grain rice", "bg-pantry"],
          ["Sesame oil", "bg-pantry"],
        ].map(([name, dot]) => (
          <span
            key={name}
            className="recipe-chip flex items-center gap-1.5 rounded-full bg-card px-3 py-1 text-[13px] font-medium text-ink ring-1 ring-line"
          >
            <span className={`h-1.5 w-1.5 rounded-full ${dot}`} />
            {name}
          </span>
        ))}
      </div>
    </div>
  );
}

function ShareShelf() {
  const people = [
    { name: "Sarah", role: "Can edit", fill: "bg-snacks" },
    { name: "Dad", role: "Can edit", fill: "bg-dairy" },
    { name: "Grandma", role: "View only", fill: "bg-produce" },
  ];
  return (
    <ul className="divide-y divide-line overflow-hidden rounded-[14px] bg-card ring-1 ring-line">
      {people.map((p) => (
        <li key={p.name} className="flex items-center gap-3 px-4 py-2.5">
          <span
            className={`flex h-7 w-7 items-center justify-center rounded-full text-[12px] font-bold text-white ${p.fill}`}
          >
            {p.name[0]}
          </span>
          <span className="flex-1 text-[14px] text-ink">{p.name}</span>
          <span className="text-[12px] text-ink-3">{p.role}</span>
        </li>
      ))}
    </ul>
  );
}

function CategoryShelf() {
  const groups = [
    { label: "Produce", dot: "bg-produce", items: ["Bananas", "Spinach"] },
    { label: "Dairy", dot: "bg-dairy", items: ["Milk", "Yogurt"] },
    { label: "Bakery", dot: "bg-bakery", items: ["Sourdough"] },
  ];
  return (
    <div className="grid grid-cols-3 gap-2">
      {groups.map((g) => (
        <div key={g.label} className="rounded-[12px] bg-card p-2.5 ring-1 ring-line">
          <p className="flex items-center gap-1.5 text-[11px] font-semibold text-ink-2">
            <span className={`h-2 w-2 rounded-full ${g.dot}`} />
            {g.label}
          </p>
          <ul className="mt-2 space-y-1">
            {g.items.map((i) => (
              <li key={i} className="category-item text-[13px] text-ink">
                {i}
              </li>
            ))}
          </ul>
        </div>
      ))}
    </div>
  );
}

const aisles: Aisle[] = [
  {
    n: 1,
    title: "Location alerts",
    stocks: "Stores · Nudges",
    kicker: "Drive past the store, get the list.",
    description:
      "Pin the stores you actually go to. Allim watches for them in the background and pings you when you're close enough to stop in. You don't open anything.",
    shelf: <NudgeShelf />,
  },
  {
    n: 2,
    title: "Smart Recipe",
    stocks: "Recipes · Ingredients",
    kicker: "Ask for dinner, get a shopping list.",
    description:
      "Describe what you feel like eating. You get the steps, plus every ingredient dropped onto the list for the store you'd buy it at. No retyping.",
    premium: true,
    shelf: <RecipeShelf />,
  },
  {
    n: 3,
    title: "Shared lists",
    stocks: "Family · Roommates",
    kicker: "One list for the whole house.",
    description:
      "Share a store's list with whoever you live with. Edits sync live, and you pick who can change it and who can only look.",
    shelf: <ShareShelf />,
  },
  {
    n: 4,
    title: "Smart Category",
    stocks: "Produce · Dairy · Bakery",
    kicker: "Already in walking order.",
    description:
      "Groceries sort themselves into aisles as you add them, so by the time you're pushing a cart the list reads front of store to back.",
    premium: true,
    shelf: <CategoryShelf />,
  },
];

export default function Features() {
  const root = useRef<HTMLElement>(null);

  useGSAP(
    () => {
      const mm = gsap.matchMedia();

      mm.add(
        {
          wide: "(min-width: 1024px)",
          motion: "(prefers-reduced-motion: no-preference)",
        },
        (ctx) => {
          const { wide, motion } = ctx.conditions as { wide: boolean; motion: boolean };
          if (!motion) return;

          const signs = gsap.utils.toArray<HTMLElement>(".aisle-sign");
          const panels = gsap.utils.toArray<HTMLElement>(".aisle-panel");

          if (wide) {
            // Pin the section and walk the aisles sideways while the page
            // scrolls down. The distance is re-measured on every refresh.
            const wrap = root.current!.querySelector<HTMLElement>(".aisle-track-wrap")!;
            const track = root.current!.querySelector<HTMLElement>(".aisle-track")!;
            wrap.classList.add("is-pinned");
            const distance = () => track.scrollWidth - wrap.clientWidth;

            const walk = gsap.to(track, {
              x: () => -distance(),
              ease: "none",
              scrollTrigger: {
                trigger: root.current,
                start: "top top",
                end: () => `+=${distance()}`,
                pin: true,
                scrub: 0.6,
                invalidateOnRefresh: true,
              },
            });

            gsap.to(".aisle-progress", {
              scaleX: 1,
              ease: "none",
              scrollTrigger: {
                trigger: root.current,
                start: "top top",
                end: () => `+=${distance()}`,
                scrub: true,
              },
            });

            // Each sign swings on its wires as it comes into view, driven by
            // the sideways walk rather than the page scroll.
            signs.forEach((sign, i) => {
              gsap.from(sign, {
                rotation: i % 2 ? 10 : -10,
                duration: 2,
                ease: "elastic.out(1, 0.3)",
                scrollTrigger: {
                  trigger: panels[i],
                  containerAnimation: walk,
                  start: "left 92%",
                  toggleActions: "play none none reset",
                },
              });
            });

            return () => wrap.classList.remove("is-pinned");
          }

          signs.forEach((sign, i) => {
            gsap.from(sign, {
              rotation: i % 2 ? 9 : -9,
              duration: 2,
              ease: "elastic.out(1, 0.3)",
              scrollTrigger: { trigger: sign, start: "top 85%" },
            });
          });
          panels.forEach((panel) => {
            gsap.from(panel.querySelector(".aisle-body"), {
              y: 30,
              autoAlpha: 0,
              duration: 0.8,
              ease: "power3.out",
              scrollTrigger: { trigger: panel, start: "top 75%" },
            });
          });
        },
      );
    },
    { scope: root },
  );

  return (
    <section ref={root} id="features" className="relative lg:flex lg:min-h-screen lg:flex-col lg:justify-center">
      <div className="mx-auto w-full max-w-6xl px-6 pt-24 pb-12 lg:pt-20 lg:pb-8">
        <h2 className="display text-[clamp(2.4rem,6vw,4rem)] text-ink">Walk the aisles.</h2>
      </div>

      <div className="aisle-track-wrap">
        <ol className="aisle-track flex flex-col gap-16 px-6 pb-24 lg:w-max lg:flex-row lg:gap-10 lg:px-[max(1.5rem,calc((100vw-72rem)/2+1.5rem))] lg:pb-10">
          {aisles.map((aisle) => (
            <li key={aisle.n} className="aisle-panel mx-auto w-full max-w-[440px] lg:mx-0 lg:w-[420px]">
              {/* The wires it hangs from, then the sign itself. */}
              <div className="aisle-sign">
                <div className="flex justify-between px-12" aria-hidden="true">
                  <span className="h-8 w-px bg-ink/30" />
                  <span className="h-8 w-px bg-ink/30" />
                </div>
                <div className="flex items-center gap-4 rounded-[6px] bg-teal-deep px-5 py-4 text-white shadow-[0_14px_24px_-14px_rgba(5,63,71,0.8)]">
                  <span className="flex h-12 w-12 shrink-0 items-center justify-center rounded-full bg-white text-[24px] font-black text-teal-deep">
                    {aisle.n}
                  </span>
                  <div className="min-w-0">
                    <h3 className="text-[22px] leading-tight font-extrabold tracking-[-0.02em]">
                      {aisle.title}
                    </h3>
                    <p className="mono mt-0.5 text-[11px] tracking-[0.08em] text-white/65 uppercase">
                      {aisle.stocks}
                    </p>
                  </div>
                </div>
              </div>

              <div className="aisle-body mt-8">
                <p className="text-[26px] leading-[1.15] font-bold tracking-[-0.025em] text-ink">
                  {aisle.kicker}
                </p>
                <p className="mt-3 text-[16px] leading-relaxed text-ink-2">{aisle.description}</p>

                <div className="mt-6">{aisle.shelf}</div>

                {/* The shelf edge, and the tag clipped to it. */}
                <div className="mt-5 flex items-start gap-3 border-t-[5px] border-kraft pt-0">
                  <span
                    className={`shelf-tag mono -mt-[1px] inline-flex items-baseline gap-2 px-3 py-1.5 text-[12px] font-semibold ${
                      aisle.premium ? "is-premium" : ""
                    }`}
                  >
                    {aisle.premium ? (
                      <>
                        PREMIUM <span className="text-[15px]">$0.99</span>/mo
                      </>
                    ) : (
                      <>
                        FREE <span className="text-[15px]">$0.00</span>
                      </>
                    )}
                  </span>
                </div>
              </div>
            </li>
          ))}
        </ol>
      </div>

      <div className="aisle-meter mx-auto hidden w-full max-w-6xl px-6 pb-10 lg:block" aria-hidden="true">
        <div className="h-[3px] bg-line">
          <div className="aisle-progress h-full origin-left scale-x-0 bg-teal" />
        </div>
      </div>
    </section>
  );
}
