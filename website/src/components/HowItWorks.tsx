import { useRef } from "react";
import { animate, stagger } from "animejs";
import Rise from "./Rise";
import { gsap, ScrollTrigger, useGsap } from "../lib/motion";

const steps = [
  {
    n: "01",
    title: "Add your stores",
    description:
      "Search the grocery stores near you and pin the ones you actually shop at. Allim looks within a 5 km radius.",
  },
  {
    n: "02",
    title: "Fill your lists",
    description:
      "Add the groceries you need at each store. Smart Category groups them by aisle as you type.",
  },
  {
    n: "03",
    title: "Get on with your day",
    description:
      "Allim watches your location in the background. Nothing to open, nothing to remember.",
  },
  {
    n: "04",
    title: "Get the nudge",
    description:
      "You're near a store with groceries waiting. Tap the notification and the list is right there.",
  },
];

export default function HowItWorks() {
  const sectionRef = useRef<HTMLElement | null>(null);
  const lineRef = useRef<SVGLineElement | null>(null);

  useGsap(() => {
    /* Cards arrive as a batch, each lifting into place. */
    const cards = gsap.utils.toArray<HTMLElement>(".hiw-card");
    gsap.set(cards, { opacity: 0, y: 40 });
    ScrollTrigger.batch(cards, {
      start: "top 88%",
      once: true,
      onEnter: (els) =>
        gsap.to(els, {
          opacity: 1,
          y: 0,
          duration: 0.9,
          stagger: 0.13,
          ease: "power3.out",
          onComplete: () => {
            // Step numerals pop once their card has landed.
            animate(".hiw-num", {
              scale: [0.4, 1],
              opacity: [0, 1],
              delay: stagger(110),
              duration: 520,
              easing: "easeOutBack(2)",
            });
          },
        }),
    });

    /* A teal thread draws across the four steps as you scroll. */
    const line = lineRef.current!;
    const len = line.getTotalLength();
    gsap.set(line, { strokeDasharray: len, strokeDashoffset: len });
    gsap.to(line, {
      strokeDashoffset: 0,
      ease: "none",
      scrollTrigger: {
        trigger: sectionRef.current,
        start: "top 72%",
        end: "bottom 70%",
        scrub: 0.8,
      },
    });
  });

  return (
    <section
      ref={sectionRef}
      id="how-it-works"
      className="border-b border-line bg-wash py-20 md:py-28"
    >
      <div className="mx-auto max-w-6xl px-6">
        <Rise>
          <h2 className="eyebrow text-teal-deep">How it works</h2>
        </Rise>

        <div className="relative mt-12">
          {/* The thread, drawn above the card row on desktop. */}
          <div className="absolute inset-x-0 -top-[1px] hidden lg:block" aria-hidden="true">
            <svg className="h-[3px] w-full" preserveAspectRatio="none" viewBox="0 0 100 3">
              <line
                ref={lineRef}
                x1="0"
                y1="1.5"
                x2="100"
                y2="1.5"
                stroke="#0b7285"
                strokeWidth="3"
                strokeLinecap="round"
              />
            </svg>
          </div>

          <ol className="grid gap-px overflow-hidden border border-line-strong bg-line-strong sm:grid-cols-2 lg:grid-cols-4">
            {steps.map((step) => (
              <li key={step.n} className="hiw-card bg-wash">
                <div className="flex h-full flex-col p-7 lg:p-8">
                  <span className="hiw-num figure inline-block text-[13px] text-teal">
                    {step.n}
                  </span>
                  <h3 className="mt-9 text-[20px] font-bold tracking-[-0.02em] text-ink">
                    {step.title}
                  </h3>
                  <p className="mt-3 text-[15px] leading-relaxed text-on-wash/75">
                    {step.description}
                  </p>
                </div>
              </li>
            ))}
          </ol>
        </div>
      </div>
    </section>
  );
}
