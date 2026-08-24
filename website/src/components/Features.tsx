import { useEffect, useRef, useState } from "react";
import { MapPin, Users, Tag, ChefHat } from "lucide-react";

const features = [
  {
    n: "01",
    icon: MapPin,
    title: "Location-based alerts",
    kicker: "You're near Whole Foods.",
    description:
      "Save the grocery stores you actually shop at. Allim watches for them in the background and pings you when you're close enough to stop in — no app to open, nothing to remember.",
  },
  {
    n: "02",
    icon: ChefHat,
    title: "Smart Recipe",
    kicker: "Dinner, minus the planning.",
    description:
      "Ask for a recipe, get the steps, and push every ingredient onto the grocery list for the store you'd buy it at. One tap, no retyping.",
  },
  {
    n: "03",
    icon: Users,
    title: "Shared lists",
    kicker: "One list, whole household.",
    description:
      "Give a grocery list to your partner, roommate, or family. Edits sync live, and you decide who can change things and who can only look.",
  },
  {
    n: "04",
    icon: Tag,
    title: "Smart Category",
    kicker: "Produce with produce.",
    description:
      "Groceries sort themselves into aisle groups as they're added, so the list is already in walking order by the time you're pushing a cart.",
  },
];

export default function Features() {
  const [active, setActive] = useState(0);
  const [pinned, setPinned] = useState(false);
  const stepRefs = useRef<(HTMLDivElement | null)[]>([]);

  // The pinned panel only exists at lg and up. Track that so the
  // cross-fade's aria-hidden matches what is actually on screen.
  useEffect(() => {
    const query = window.matchMedia("(min-width: 1024px)");
    const sync = () => setPinned(query.matches);
    sync();
    query.addEventListener("change", sync);
    return () => query.removeEventListener("change", sync);
  }, []);

  // A step sentinel is "active" while it straddles the middle of the
  // viewport, which is exactly where the pinned panel sits.
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
    <section id="features" className="bg-allim-dark">
      {/* Scroll stage: sticky panel + one sentinel per feature */}
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

        <div className="lg:sticky lg:top-0 lg:flex lg:h-screen lg:items-center">
          <div className="mx-auto w-full max-w-6xl px-6 py-24 lg:py-0">
            <div className="grid gap-12 lg:grid-cols-12 lg:gap-16">
              {/* Persistent frame — intro and rail hold still while
                  the copy on the right swaps out. */}
              <div className="lg:col-span-4">
                <h2 className="mb-4 text-2xl font-semibold uppercase tracking-[0.08em] text-allim-accent sm:text-3xl">
                  What it does
                </h2>
                <p className="max-w-xs text-[15px] leading-relaxed text-allim-muted">
                  A grocery list for every store you shop at, a nudge the
                  moment you're near one, and a shared list the rest of the
                  household can add to.
                </p>

                <ul className="mt-10 hidden space-y-1 lg:block">
                  {features.map((feature, index) => {
                    const isActive = index === active;
                    return (
                      <li key={feature.n}>
                        <div
                          className={`flex items-center gap-4 border-l-2 py-3 pl-5 transition-colors duration-300 ${
                            isActive
                              ? "border-allim-accent"
                              : "border-allim-line"
                          }`}
                        >
                          <span
                            className={`font-display text-sm tabular-nums transition-colors duration-300 ${
                              isActive ? "text-allim-accent" : "text-allim-faint"
                            }`}
                          >
                            {feature.n}
                          </span>
                          <span
                            className={`text-[15px] transition-colors duration-300 ${
                              isActive
                                ? "font-medium text-white"
                                : "text-allim-faint"
                            }`}
                          >
                            {feature.title}
                          </span>
                        </div>
                      </li>
                    );
                  })}
                </ul>
              </div>

              {/* Cross-fading copy. All four stay in the DOM — they stack
                  into one grid cell at lg and flow normally below it. */}
              <div className="grid gap-16 lg:col-span-7 lg:col-start-6 lg:gap-0">
                {features.map((feature, index) => {
                  const isActive = index === active;
                  return (
                    <div
                      key={feature.n}
                      aria-hidden={pinned && !isActive}
                      className={`feature-panel-item lg:col-start-1 lg:row-start-1 ${
                        isActive
                          ? "lg:translate-y-0 lg:opacity-100"
                          : "lg:pointer-events-none lg:translate-y-3 lg:opacity-0"
                      }`}
                    >
                      <div className="flex items-center gap-4">
                        <feature.icon
                          size={22}
                          strokeWidth={1.75}
                          className="text-allim-accent"
                        />
                        <span className="font-display text-sm tabular-nums text-allim-faint lg:hidden">
                          {feature.n}
                        </span>
                      </div>
                      <h3 className="mt-6 text-3xl font-bold leading-tight tracking-tight text-white sm:text-4xl">
                        {feature.title}
                      </h3>
                      <p className="mt-3 text-xl text-allim-accent">
                        {feature.kicker}
                      </p>
                      <p className="mt-6 max-w-lg text-lg leading-relaxed text-allim-muted">
                        {feature.description}
                      </p>
                    </div>
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
