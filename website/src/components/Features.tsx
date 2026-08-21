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

/* A fixed map-grid backdrop: fine blocks, a couple of heavier "roads",
   and three pins. It sits inside the sticky panel so it holds still while
   the feature copy swaps, and is masked so it fades out at the top and
   bottom instead of meeting the neighbouring sections as a hard edge.
   Road coordinates run well past any realistic viewport so they never
   truncate mid-air on a wide or tall screen. */
function FeatureBackdrop() {
  return (
    <div
      className="feature-backdrop pointer-events-none absolute inset-0 overflow-hidden"
      aria-hidden="true"
    >
      <svg className="h-full w-full">
        <defs>
          <pattern
            id="allim-map-grid"
            width="56"
            height="56"
            patternUnits="userSpaceOnUse"
          >
            <path
              d="M56 0H0V56"
              fill="none"
              stroke="currentColor"
              strokeWidth="1"
            />
          </pattern>
        </defs>

        <rect
          width="100%"
          height="100%"
          fill="url(#allim-map-grid)"
          className="text-allim-line"
        />

        {/* Heavier roads cutting across the grid */}
        <g className="text-allim-line-strong" stroke="currentColor" fill="none">
          <path d="M0 224H4000" strokeWidth="6" />
          <path d="M392 0V2400" strokeWidth="6" />
          <path d="M0 616H4000" strokeWidth="3" />
          <path d="M1064 0V2400" strokeWidth="3" />
        </g>

        {/* Store pins */}
        <g className="text-allim-accent" fill="currentColor">
          <circle cx="392" cy="224" r="7" />
          <circle cx="1064" cy="616" r="5" opacity="0.55" />
          <circle cx="1064" cy="224" r="4" opacity="0.35" />
        </g>
      </svg>
    </div>
  );
}

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

        <div className="relative lg:sticky lg:top-0 lg:flex lg:h-screen lg:items-center">
          <FeatureBackdrop />
          <div className="relative mx-auto w-full max-w-6xl px-6 py-24 lg:py-0">
            <h2 className="sr-only">Features</h2>
            <div className="grid gap-12 lg:grid-cols-12 lg:gap-16">
              {/* Persistent rail — holds still while the copy swaps out. */}
              <div className="lg:col-span-4">
                <ul className="hidden space-y-1 lg:block">
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
                          size={26}
                          strokeWidth={1.75}
                          className="text-allim-accent"
                        />
                        <span className="font-display text-sm tabular-nums text-allim-faint lg:hidden">
                          {feature.n}
                        </span>
                      </div>
                      <h3 className="mt-6 text-4xl font-bold leading-[1.1] tracking-tight text-white sm:text-5xl">
                        {feature.title}
                      </h3>
                      <p className="mt-4 text-2xl text-allim-accent">
                        {feature.kicker}
                      </p>
                      <p className="mt-7 max-w-xl text-xl leading-relaxed text-allim-muted">
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
