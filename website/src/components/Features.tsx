import { useEffect, useRef, useState } from "react";

const features = [
  {
    n: "01",
    title: "Location alerts",
    kicker: "You're near Whole Foods.",
    description:
      "Save the grocery stores you actually shop at. Allim watches for them in the background and pings you when you're close enough to stop in — no app to open, nothing to remember.",
    dot: "bg-beverages",
  },
  {
    n: "02",
    title: "Smart Recipe",
    kicker: "Dinner, minus the planning.",
    description:
      "Ask for a recipe, get the steps, and push every ingredient onto the grocery list for the store you'd buy it at. One tap, no retyping.",
    dot: "bg-meat",
  },
  {
    n: "03",
    title: "Shared lists",
    kicker: "One list, whole household.",
    description:
      "Give a grocery list to your partner, roommate, or family. Edits sync live, and you decide who can change things and who can only look.",
    dot: "bg-dairy",
  },
  {
    n: "04",
    title: "Smart Category",
    kicker: "Produce with produce.",
    description:
      "Groceries sort themselves into aisle groups as they're added, so the list is already in walking order by the time you're pushing a cart.",
    dot: "bg-produce",
  },
];

export default function Features() {
  const [active, setActive] = useState(0);
  const [pinned, setPinned] = useState(false);
  const stepRefs = useRef<(HTMLDivElement | null)[]>([]);

  // The pinned panel only exists at lg and up. Track that so the cross-fade's
  // aria-hidden matches what is actually on screen.
  useEffect(() => {
    const query = window.matchMedia("(min-width: 1024px)");
    const sync = () => setPinned(query.matches);
    sync();
    query.addEventListener("change", sync);
    return () => query.removeEventListener("change", sync);
  }, []);

  // A step sentinel is "active" while it straddles the middle of the viewport,
  // which is exactly where the pinned panel sits.
  useEffect(() => {
    if (!pinned) return;

    const observer = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (!entry.isIntersecting) continue;
          const index = stepRefs.current.indexOf(entry.target as HTMLDivElement);
          if (index !== -1) setActive(index);
        }
      },
      { rootMargin: "-50% 0px -50% 0px", threshold: 0 },
    );

    for (const step of stepRefs.current) {
      if (step) observer.observe(step);
    }
    return () => observer.disconnect();
  }, [pinned]);

  return (
    <section id="features" className="border-b border-line bg-canvas">
      <div
        className="feature-stage relative"
        style={{ "--step-count": features.length } as React.CSSProperties}
      >
        {/* Sentinels drive the active index. Desktop only; they carry no
            content, so hiding them below lg simply parks active at 0. */}
        <div className="absolute inset-0 hidden lg:block" aria-hidden="true">
          {features.map((feature, index) => (
            <div
              key={feature.n}
              ref={(el) => {
                stepRefs.current[index] = el;
              }}
              className="feature-step"
            />
          ))}
        </div>

        <div className="lg:sticky lg:top-16 lg:flex lg:h-[calc(100vh-4rem)] lg:items-center">
          <div className="mx-auto w-full max-w-6xl px-6 py-20 lg:py-0">
            <div className="grid gap-14 lg:grid-cols-12 lg:gap-12">
              {/* The frame holds still while the copy swaps out. */}
              <div className="lg:col-span-4">
                <h2 className="eyebrow text-teal">What it does</h2>
                <p className="mt-5 max-w-xs text-[15px] leading-relaxed text-ink-2">
                  A grocery list for every store you shop at, a nudge the moment
                  you&apos;re near one, and a shared list the rest of the household
                  can add to.
                </p>

                <ol className="mt-10 hidden lg:block">
                  {features.map((feature, index) => {
                    const isActive = index === active;
                    return (
                      <li key={feature.n}>
                        <div
                          className={`flex items-center gap-4 border-l-2 py-3 pl-5 transition-colors duration-300 ${
                            isActive ? "border-teal" : "border-line"
                          }`}
                        >
                          <span
                            className={`figure text-[13px] transition-colors duration-300 ${
                              isActive ? "text-teal" : "text-ink-3"
                            }`}
                          >
                            {feature.n}
                          </span>
                          <span
                            className={`text-[15px] transition-colors duration-300 ${
                              isActive ? "font-semibold text-ink" : "text-ink-3"
                            }`}
                          >
                            {feature.title}
                          </span>
                        </div>
                      </li>
                    );
                  })}
                </ol>
              </div>

              {/* Cross-fading copy. All four stay in the DOM — they stack into
                  one grid cell at lg and flow normally below it. */}
              <div className="grid gap-14 lg:col-span-7 lg:col-start-6 lg:gap-0">
                {features.map((feature, index) => {
                  const isActive = index === active;
                  return (
                    <article
                      key={feature.n}
                      aria-hidden={pinned && !isActive}
                      className={`feature-panel-item lg:col-start-1 lg:row-start-1 ${
                        isActive
                          ? "lg:translate-y-0 lg:opacity-100"
                          : "lg:pointer-events-none lg:translate-y-2 lg:opacity-0"
                      }`}
                    >
                      <div className="flex items-center gap-3 border-b border-line pb-4">
                        <span
                          className={`h-2.5 w-2.5 rounded-full ${feature.dot}`}
                          aria-hidden="true"
                        />
                        <span className="figure text-[13px] text-ink-3">{feature.n}</span>
                      </div>

                      <h3 className="display mt-7 text-[clamp(2rem,5.5vw,3.25rem)] text-ink">
                        {feature.title}
                      </h3>
                      <p className="mt-4 text-[19px] font-medium text-teal">
                        {feature.kicker}
                      </p>
                      <p className="mt-6 max-w-lg text-[17px] leading-relaxed text-ink-2">
                        {feature.description}
                      </p>
                    </article>
                  );
                })}
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
