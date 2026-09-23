import { useRef } from "react";
import { gsap, useGSAP } from "../lib/gsap";
import { PushBanner } from "./screens/parts";

const steps = [
  {
    title: "Pin your stores",
    description:
      "Search the grocery stores around you and pin the ones you actually use. Allim looks within 5 km.",
  },
  {
    title: "Fill the lists",
    description:
      "Each store gets its own list. Add things as you run out; Smart Category sorts them by aisle.",
  },
  {
    title: "Go about your day",
    description: "Close the app. Allim keeps an eye on where you are in the background.",
  },
  {
    title: "Get the nudge",
    description:
      "Pass a store with something on its list and your phone buzzes. Tap it and the list is open.",
  },
];

/* The drive home. Work is top left, home bottom right, and the store sits just
   off the route so the road clips its circle. Every coordinate lives in the
   viewBox below; ROUTE_ENTERS is how far along the path (0–1) the road first
   crosses the circle, worked out from the segment lengths (80 + 190 + 110 + 55
   of 760). */
const ROUTE = "M70 80 L70 160 L260 160 L260 270 L530 270 L530 380";
const ROUTE_ENTERS = 435 / 760;
const STORE = { x: 360, y: 205, r: 88 };

function RouteMap() {
  return (
    <svg viewBox="0 0 600 440" className="h-auto w-full" role="img" aria-labelledby="map-title">
      <title id="map-title">
        A map of the drive home from work. The route passes a pinned Walmart, and
        the moment it crosses the circle around the store, Allim sends a
        notification.
      </title>

      {/* Blocks and streets. */}
      <rect width="600" height="440" fill="var(--color-kraft)" />
      <g fill="#f2ede2">
        <rect x="95" y="20" width="140" height="115" rx="6" />
        <rect x="285" y="20" width="220" height="115" rx="6" />
        <rect x="95" y="185" width="140" height="60" rx="6" />
        <rect x="95" y="295" width="140" height="125" rx="6" />
        <rect x="285" y="295" width="220" height="125" rx="6" />
        <rect x="555" y="20" width="45" height="400" rx="6" />
      </g>
      <rect x="285" y="160" width="220" height="85" rx="6" fill="#dfe9d6" />
      <g stroke="#fff" strokeWidth="14" strokeLinecap="round" fill="none" opacity="0.9">
        <path d="M70 10 V430 M260 10 V430 M530 10 V430 M10 160 H590 M10 270 H590" />
      </g>

      {/* The store's geofence, and its pin. */}
      <circle
        className="map-fence"
        cx={STORE.x}
        cy={STORE.y}
        r={STORE.r}
        fill="rgba(11,114,133,0.12)"
        stroke="var(--color-teal)"
        strokeWidth="2"
        strokeDasharray="6 6"
      />
      <g className="map-pin">
        <path
          d={`M${STORE.x} ${STORE.y + 4} c -14 -18 -20 -26 -20 -36 a20 20 0 0 1 40 0 c0 10 -6 18 -20 36z`}
          fill="var(--color-teal-deep)"
        />
        <circle cx={STORE.x} cy={STORE.y - 32} r="7" fill="#fff" />
        <text x={STORE.x + 26} y={STORE.y - 36} className="fill-ink" fontSize="15" fontWeight="700">
          Walmart
        </text>
        <text x={STORE.x + 26} y={STORE.y - 19} className="fill-ink-2" fontSize="12">
          pinned
        </text>
      </g>

      {/* The list waiting at the store. */}
      <g className="map-list">
        <rect x="300" y="318" width="128" height="76" rx="10" fill="#fff" stroke="var(--color-line)" />
        <circle cx="316" cy="338" r="4" fill="var(--color-dairy)" />
        <text x="326" y="342" fontSize="12" className="fill-ink">Milk</text>
        <circle cx="316" cy="357" r="4" fill="var(--color-bakery)" />
        <text x="326" y="361" fontSize="12" className="fill-ink">Sourdough</text>
        <circle cx="316" cy="376" r="4" fill="var(--color-household)" />
        <text x="326" y="380" fontSize="12" className="fill-ink">+ 2 more</text>
      </g>

      {/* The route: the plan in dashes, the drive so far drawn solid over it. */}
      <path d={ROUTE} fill="none" stroke="var(--color-ink-3)" strokeWidth="3" strokeDasharray="2 9" strokeLinecap="round" />
      <path
        id="map-route"
        className="map-drive"
        d={ROUTE}
        fill="none"
        stroke="var(--color-orange)"
        strokeWidth="5"
        strokeLinecap="round"
        strokeLinejoin="round"
      />

      <g fontFamily="var(--font-hand)" fontSize="26" className="fill-ink-2">
        <text x="84" y="68">work</text>
        <text x="462" y="420">home</text>
      </g>
      <circle cx="70" cy="80" r="7" fill="var(--color-ink)" />
      <circle cx="530" cy="380" r="7" fill="var(--color-ink)" />

      {/* You, parked just inside the circle until GSAP takes over. */}
      <g className="map-car" transform="translate(376 270)">
        <circle r="13" fill="var(--color-orange)" opacity="0.25" />
        <circle r="8" fill="var(--color-orange)" stroke="#fff" strokeWidth="3" />
      </g>
    </svg>
  );
}

export default function HowItWorks() {
  const root = useRef<HTMLElement>(null);

  useGSAP(
    () => {
      const mm = gsap.matchMedia();

      mm.add(
        {
          wide: "(min-width: 768px)",
          motion: "(prefers-reduced-motion: no-preference)",
        },
        (ctx) => {
          const { wide, motion } = ctx.conditions as { wide: boolean; motion: boolean };

          // The car's resting place in the markup-only version: inside the
          // circle, where the nudge fires.
          const park = { path: "#map-route", align: "#map-route", alignOrigin: [0.5, 0.5] as [number, number] };
          if (!motion) {
            gsap.set(".map-car", { motionPath: { ...park, start: 0, end: ROUTE_ENTERS + 0.08 } });
            gsap.set(".map-drive", { drawSVG: `0% ${(ROUTE_ENTERS + 0.08) * 100}%` });
            return;
          }

          const tl = gsap.timeline({
            defaults: { ease: "none" },
            scrollTrigger: wide
              ? {
                  trigger: root.current,
                  start: "top top",
                  end: "+=2400",
                  pin: true,
                  scrub: 0.8,
                }
              : { trigger: ".map-card", start: "top 70%" },
          });

          // Steps only dim and light up where they sit beside the map. On a
          // phone they're read before or after it, so they stay lit.
          const lightStep = (i: number, at: string | number) => {
            if (!wide) return;
            tl.to(`.step-${i}`, { opacity: 1, duration: 0.3 }, at);
            tl.to(`.step-${i} .step-bar`, { scaleY: 1, duration: 0.3 }, at);
            if (i > 0) tl.to(`.step-${i - 1} .step-bar`, { scaleY: 0, duration: 0.3 }, at);
          };

          if (wide) {
            gsap.set(".step", { opacity: 0.3 });
            gsap.set(".step-bar", { scaleY: 0, transformOrigin: "top" });
          }
          gsap.set(".map-car", { motionPath: { ...park, start: 0, end: 0 }, autoAlpha: 0 });

          // 1 · the pin drops, the circle opens around it.
          lightStep(0, 0);
          tl.from(".map-pin", { y: -60, autoAlpha: 0, duration: 0.5, ease: "bounce.out" }, 0)
            .from(".map-fence", { scale: 0, transformOrigin: "50% 50%", duration: 0.6, ease: "back.out(1.6)" }, 0.3)
            // 2 · the list fills in.
            .addLabel("list", 1.1);
          lightStep(1, "list");
          tl.from(".map-list", { y: 14, autoAlpha: 0, duration: 0.5, ease: "power2.out" }, "list")
            .from(".map-list text, .map-list circle", { autoAlpha: 0, stagger: 0.12, duration: 0.2 }, "list+=0.2")
            // 3 · the drive, up to the edge of the circle.
            .addLabel("drive", 2.2);
          lightStep(2, "drive");
          tl.to(".map-car", { autoAlpha: 1, duration: 0.1 }, "drive")
            .fromTo(".map-drive", { drawSVG: "0% 0%" }, { drawSVG: `0% ${ROUTE_ENTERS * 100}%`, duration: 1.6 }, "drive")
            .to(".map-car", { motionPath: { ...park, start: 0, end: ROUTE_ENTERS }, duration: 1.6 }, "drive")
            // 4 · across the line: the circle flashes and the phone buzzes.
            .addLabel("nudge");
          lightStep(3, "nudge");
          tl.to(".map-fence", { fill: "rgba(217,79,22,0.16)", stroke: "var(--color-orange)", duration: 0.2 }, "nudge")
            .from(".map-banner", { yPercent: -120, autoAlpha: 0, duration: 0.5, ease: "back.out(1.4)" }, "nudge")
            .to(".map-drive", { drawSVG: "0% 100%", duration: 1.4 }, "nudge+=0.4")
            .to(".map-car", { motionPath: { ...park, start: ROUTE_ENTERS, end: 1 }, duration: 1.4 }, "nudge+=0.4")
            .to({}, { duration: 0.4 });
        },
      );
    },
    { scope: root },
  );

  return (
    <section ref={root} id="how-it-works" className="relative bg-teal-night text-white md:flex md:min-h-screen md:items-center">
      <div className="mx-auto w-full max-w-6xl px-6 py-24 md:py-16">
        <div className="grid items-center gap-12 md:grid-cols-12 md:gap-10">
          <div className="md:col-span-5">
            <h2 className="display text-[clamp(2.3rem,5vw,3.6rem)]">
              You set it up once.
              <span className="block text-white/55">Then you just drive home.</span>
            </h2>

            <ol className="mt-10 space-y-1">
              {steps.map((step, i) => (
                <li key={step.title} className={`step step-${i} relative py-3 pl-6`}>
                  <span className="absolute top-0 left-0 h-full w-[2px] bg-white/15" aria-hidden="true" />
                  <span
                    className="step-bar absolute top-0 left-0 hidden h-full w-[2px] bg-tag md:block"
                    aria-hidden="true"
                  />
                  <h3 className="text-[19px] font-bold tracking-[-0.015em]">{step.title}</h3>
                  <p className="mt-1 max-w-sm text-[15px] leading-relaxed text-white/70">
                    {step.description}
                  </p>
                </li>
              ))}
            </ol>
          </div>

          <div className="order-first md:order-none md:col-span-7">
            <div className="map-card relative overflow-hidden rounded-[18px] shadow-[0_30px_60px_-30px_rgba(0,0,0,0.6)]">
              <RouteMap />
              <div className="map-banner absolute inset-x-0 top-3 mx-auto max-w-[330px]">
                <PushBanner
                  title="You're near Walmart"
                  body="Milk, sourdough and 2 more are on this list."
                />
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
