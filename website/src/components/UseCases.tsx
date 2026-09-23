import { useRef } from "react";
import { gsap, MOTION_OK, useGSAP } from "../lib/gsap";
import PhoneFrame from "./PhoneFrame";
import ShotPhone from "./screens/ShotPhone";
import SwipePhone from "./screens/SwipePhone";
import { SHOT_FRAME } from "./screens/shot";
import { HomeBar, PushBanner } from "./screens/parts";

/* -- the heads-up, on someone else's lock screen --------------------------- */

function LockScreen() {
  return (
    <div className="flex flex-1 flex-col overflow-hidden bg-teal-deep">
      <div className="pt-5 text-center">
        <p className="text-[11.5px] font-medium tracking-[0.03em] text-white/70">
          Tuesday, April 30
        </p>
        <p className="mt-1 text-[58px] leading-none font-light tracking-[-0.03em] text-white">
          2:47
        </p>
      </div>

      <div className="mt-6">
        <PushBanner
          title="Mom is going to Walmart"
          body="Arriving in about 7 minutes. Add anything you need."
          when="now"
        />
      </div>

      <div className="mt-3 px-6 text-center">
        <p className="text-[10.5px] text-white/60">Tap to add to the Walmart list</p>
      </div>

      <div className="flex-1" />
      <HomeBar tone="light" />
    </div>
  );
}

/* ------------------------------------------------------------------------ */

const beats = [
  {
    when: "all week",
    title: "Everyone adds to one list",
    desc: "Mom, Dad and Sarah put things on the shared Walmart list as they run out. Milk, sourdough, paper towels.",
    phone: (
      <ShotPhone
        src="/allim-reminderview.png"
        alt="A shared Walmart list in Allim, sorted into Bakery, Dairy, Office & Stationery and Produce, each item marked with the initial of whoever added it."
      />
    ),
  },
  {
    when: "tue, 2:47pm",
    title: "Mom's driving past anyway",
    desc: "She swipes the Walmart row. That's the whole interaction.",
    phone: <SwipePhone />,
  },
  {
    when: "same minute",
    title: "The house gets seven minutes",
    desc: "Everyone on the list hears she's going, and roughly when. Plenty of time to add one more thing.",
    /* Drawn rather than captured, since there's no screenshot of someone
       else's lock screen, but sized to match the two real phones. */
    phone: (
      <PhoneFrame
        statusBarTone="light"
        screenBackgroundClassName="bg-teal-deep"
        width={SHOT_FRAME.width}
        height={SHOT_FRAME.height}
      >
        <LockScreen />
      </PhoneFrame>
    ),
  },
];

export default function UseCases() {
  const root = useRef<HTMLElement>(null);

  useGSAP(
    () => {
      const mm = gsap.matchMedia();
      mm.add(MOTION_OK, () => {
        gsap.from(".story-head > *", {
          y: 30,
          autoAlpha: 0,
          duration: 0.9,
          stagger: 0.1,
          ease: "power3.out",
          scrollTrigger: { trigger: ".story-head", start: "top 80%" },
        });

        // The pen line that ties the three moments together draws as you read
        // down past them.
        gsap.from(".story-thread path", {
          drawSVG: 0,
          ease: "none",
          scrollTrigger: { trigger: ".story-beats", start: "top 70%", end: "bottom 60%", scrub: true },
        });

        gsap.utils.toArray<HTMLElement>(".story-beat").forEach((beat, i) => {
          const tl = gsap.timeline({
            scrollTrigger: { trigger: beat, start: "top 78%" },
            defaults: { ease: "power3.out" },
          });
          tl.from(beat.querySelector(".story-when"), { autoAlpha: 0, rotate: -8, y: 10, duration: 0.5 })
            .from(beat.querySelectorAll(".story-text > *"), { y: 20, autoAlpha: 0, stagger: 0.08, duration: 0.6 }, "-=0.2")
            .from(
              beat.querySelector(".story-phone"),
              { y: 80, rotate: i === 1 ? 0 : i === 0 ? -5 : 5, autoAlpha: 0, duration: 1 },
              "-=0.5",
            );
        });
      });
    },
    { scope: root },
  );

  return (
    <section ref={root} id="story" className="relative overflow-hidden py-24 md:py-32">
      <div className="mx-auto max-w-6xl px-6">
        <div className="story-head max-w-3xl">
          <p className="hand -rotate-2 text-[30px] text-orange">a real tuesday</p>
          <h2 className="display mt-3 text-[clamp(2.3rem,5.5vw,3.9rem)] text-ink">
            One store, four people, no second trip.
          </h2>
          <p className="mt-6 max-w-xl text-[17px] leading-relaxed text-ink-2">
            This is the afternoon Allim was built for. At no point does anyone have
            to remember to open the app.
          </p>
        </div>

        <div className="story-beats relative mt-20">
          {/* The thread between the phones, desktop only. */}
          <svg
            className="story-thread pointer-events-none absolute inset-0 hidden h-full w-full md:block"
            viewBox="0 0 1000 800"
            preserveAspectRatio="none"
            aria-hidden="true"
          >
            <path
              d="M150 90 C 250 20, 330 160, 500 180 S 760 250, 850 290"
              fill="none"
              stroke="var(--color-orange)"
              strokeWidth="3.5"
              strokeDasharray="1 11"
              strokeLinecap="round"
            />
          </svg>

          <ol className="relative grid gap-20 md:grid-cols-3 md:gap-8">
            {beats.map((beat, i) => (
              <li
                key={beat.when}
                className={`story-beat flex flex-col ${i === 1 ? "md:pt-24" : i === 2 ? "md:pt-48" : ""}`}
              >
                <p className="story-when hand w-fit text-[34px] text-pen">{beat.when}</p>
                <div className="story-text">
                  <h3 className="mt-2 text-[22px] leading-snug font-bold tracking-[-0.02em] text-ink">
                    {beat.title}
                  </h3>
                  <p className="mt-2 text-[15px] leading-relaxed text-ink-2">{beat.desc}</p>
                </div>
                <div className="story-phone mt-10 flex justify-center">{beat.phone}</div>
              </li>
            ))}
          </ol>
        </div>

        <p className="mt-24 max-w-2xl text-[clamp(1.4rem,3vw,2rem)] leading-snug font-bold tracking-[-0.02em] text-ink">
          Nobody forgets the milk, and one trip covers the whole house.
        </p>
      </div>
    </section>
  );
}
