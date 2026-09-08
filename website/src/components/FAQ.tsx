import { useState } from "react";
import Rise from "./Rise";

const faqs = [
  {
    q: "What does “Allim” mean?",
    a: "Allim (알림) means “to inform” in Korean. It is what the app does: it tells you the thing you would otherwise have forgotten, at the one moment the information is useful.",
  },
  {
    q: "Why does it need “Always” location access?",
    a: "A nearby alert has to fire while the app is closed — that's the point of it. Without background location permission, iOS won't hand Allim the crossing event, and the reminder never arrives.",
  },
  {
    q: "What's free and what's paid?",
    a: "Grocery lists, stores, location alerts, and sharing are free. Premium is $0.99/month and adds Smart Recipe, Smart Category, and removes ads.",
  },
  {
    q: "Do the people I share with need Premium?",
    a: "No. Sharing works on the free tier for everyone on the grocery list, in both “can edit” and “view only” modes.",
  },
  {
    q: "My alerts aren't firing. What now?",
    a: "Nine times out of ten it's permissions: location set to Always, Precise Location on, and notifications enabled for Allim. The support page walks through the rest.",
  },
];

export default function FAQ() {
  // The first answer is open on arrival, so the pattern is legible without a
  // click and the section is never a wall of unexplained headings.
  const [open, setOpen] = useState<number | null>(0);

  return (
    <section id="faq" className="border-b border-line bg-canvas py-20 md:py-28">
      <div className="mx-auto max-w-6xl px-6">
        <div className="grid gap-10 lg:grid-cols-12 lg:gap-16">
          <Rise className="lg:col-span-4">
            <h2 className="eyebrow text-teal">Questions</h2>
            <p className="display mt-5 text-[clamp(1.8rem,4vw,2.4rem)] text-ink">
              Answered plainly.
            </p>
          </Rise>

          <div className="lg:col-span-7 lg:col-start-6">
            <dl className="border-t border-line">
              {faqs.map((faq, index) => {
                const isOpen = open === index;
                return (
                  <div key={faq.q} className="border-b border-line">
                    <dt>
                      <button
                        type="button"
                        onClick={() => setOpen(isOpen ? null : index)}
                        aria-expanded={isOpen}
                        className="flex w-full items-start justify-between gap-6 py-6 text-left"
                      >
                        <span className="text-[17px] font-semibold text-ink">{faq.q}</span>
                        {/* A rule that becomes a cross — the same hairline the
                            page is drawn with, doing double duty. */}
                        <span
                          className="relative mt-2.5 block h-[11px] w-[11px] shrink-0 text-teal"
                          aria-hidden="true"
                        >
                          <span className="absolute top-[5px] left-0 block h-[1.5px] w-full bg-current" />
                          <span
                            className={`absolute top-[5px] left-0 block h-[1.5px] w-full bg-current transition-transform duration-200 ${
                              isOpen ? "rotate-0" : "rotate-90"
                            }`}
                          />
                        </span>
                      </button>
                    </dt>
                    <dd
                      className={`grid transition-[grid-template-rows] duration-300 ease-out ${
                        isOpen ? "grid-rows-[1fr]" : "grid-rows-[0fr]"
                      }`}
                    >
                      <div className="overflow-hidden">
                        <p className="max-w-xl pb-7 text-[15px] leading-relaxed text-ink-2">
                          {faq.a}
                        </p>
                      </div>
                    </dd>
                  </div>
                );
              })}
            </dl>
          </div>
        </div>
      </div>
    </section>
  );
}
