import { useRef, useState } from "react";
import { gsap, MOTION_OK, useGSAP } from "../lib/gsap";

const faqs = [
  {
    q: "What does “Allim” mean?",
    a: "Allim (알림) means \u201cto inform\u201d in Korean. That's the job: it tells you the thing you'd otherwise forget, at the one moment it's useful.",
  },
  {
    q: "Why does it want “Always” location access?",
    a: "Because the alert has to fire while the app is closed, which is the entire point. Without background location, iOS never tells Allim you've crossed into a store's area, and the reminder never arrives.",
  },
  {
    q: "What's free and what's paid?",
    a: "Lists, stores, location alerts and sharing are free. Premium is $0.99 a month and adds Smart Recipe and Smart Category, and removes the ads.",
  },
  {
    q: "Do the people I share with need Premium?",
    a: "No. Sharing works on the free tier for everyone on the list, in both “can edit” and “view only”.",
  },
  {
    q: "My alerts aren't showing up. What now?",
    a: "Almost always permissions: location set to Always, Precise Location on, and notifications allowed for Allim. The support page walks through the rest.",
  },
];

export default function FAQ() {
  // The first answer starts open, so it's obvious the questions expand.
  const [open, setOpen] = useState<number | null>(0);
  const root = useRef<HTMLElement>(null);

  useGSAP(
    () => {
      const mm = gsap.matchMedia();
      mm.add(MOTION_OK, () => {
        gsap.from(".faq-row", {
          x: -24,
          autoAlpha: 0,
          stagger: 0.07,
          duration: 0.7,
          ease: "power3.out",
          scrollTrigger: { trigger: ".faq-list", start: "top 80%" },
        });
      });
    },
    { scope: root },
  );

  return (
    <section ref={root} id="faq" className="py-24 md:py-32">
      <div className="mx-auto max-w-6xl px-6">
        <div className="grid gap-12 lg:grid-cols-12 lg:gap-16">
          <div className="lg:col-span-4">
            <h2 className="display text-[clamp(2.3rem,5vw,3.4rem)] text-ink">
              Questions people actually ask.
            </h2>
            <p className="mt-6 max-w-xs text-[15px] leading-relaxed text-ink-2">
              Anything else,{" "}
              <a href="/support" className="font-semibold text-teal underline decoration-2 underline-offset-4">
                the support page
              </a>{" "}
              has it, or you can email.
            </p>
          </div>

          <dl className="faq-list lg:col-span-8">
            {faqs.map((faq, index) => {
              const isOpen = open === index;
              return (
                <div key={faq.q} className="faq-row border-b-2 border-ink/80 first:border-t-2">
                  <dt>
                    <button
                      type="button"
                      onClick={() => setOpen(isOpen ? null : index)}
                      aria-expanded={isOpen}
                      className="group flex w-full items-center justify-between gap-6 py-6 text-left"
                    >
                      <span className="text-[clamp(1.1rem,2.2vw,1.35rem)] font-bold tracking-[-0.015em] text-ink transition-colors group-hover:text-teal">
                        {faq.q}
                      </span>
                      <span
                        className={`flex h-9 w-9 shrink-0 items-center justify-center rounded-full border-2 border-ink text-[20px] leading-none font-bold transition-[transform,background-color,color] duration-300 ${
                          isOpen ? "rotate-45 bg-ink text-canvas" : "text-ink"
                        }`}
                        aria-hidden="true"
                      >
                        +
                      </span>
                    </button>
                  </dt>
                  <dd
                    className={`grid transition-[grid-template-rows] duration-400 ease-[cubic-bezier(0.22,1,0.36,1)] ${
                      isOpen ? "grid-rows-[1fr]" : "grid-rows-[0fr]"
                    }`}
                  >
                    <div className="overflow-hidden">
                      <p className="max-w-2xl pb-7 text-[16px] leading-relaxed text-ink-2">{faq.a}</p>
                    </div>
                  </dd>
                </div>
              );
            })}
          </dl>
        </div>
      </div>
    </section>
  );
}
