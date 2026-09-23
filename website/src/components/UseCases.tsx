import { animate } from "animejs";
import PhoneFrame from "./PhoneFrame";
import Rise from "./Rise";
import ShotPhone from "./screens/ShotPhone";
import SwipePhone from "./screens/SwipePhone";
import { SHOT_FRAME } from "./screens/shot";
import { HomeBar, PushBanner } from "./screens/parts";
import { ScrollTrigger, gsap, useGsap } from "../lib/motion";

/* -- 03 · the heads-up ---------------------------------------------------- */

function LockScreen() {
  return (
    <div className="flex flex-1 flex-col overflow-hidden bg-teal-deep">
      <div className="pt-5 text-center">
        <p className="text-[11.5px] font-medium tracking-[0.03em] text-white/70">
          Tuesday, April 30
        </p>
        <p className="mt-1 text-[58px] font-light leading-none tracking-[-0.03em] text-white">
          2:47
        </p>
      </div>

      <div className="uc-banner mt-6">
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
    n: "01",
    label: "The shared list",
    title: "Everyone adds during the week",
    desc: "Mom, Dad, and Sister put groceries on one shared Walmart list as they run out — milk, sourdough, paper towels.",
    speed: -46,
    phone: (
      <ShotPhone
        src="/allim-reminderview.png"
        alt="A shared Walmart list in Allim, sorted into Bakery, Dairy, Office & Stationery and Produce, each item marked with the initial of whoever added it."
      />
    ),
  },
  {
    n: "02",
    label: "The swipe",
    title: "Mom is driving past anyway",
    desc: "One swipe on the Walmart row, and the list knows. That is the whole interaction.",
    speed: 0,
    phone: <SwipePhone />,
  },
  {
    n: "03",
    label: "The heads-up",
    title: "The family gets seven minutes",
    desc: "Everyone on the list hears that Mom is going, and roughly when — time enough to add one more thing.",
    speed: 46,
    /* Drawn rather than captured — there is no screenshot of someone else's
       lock screen — but sized to match the two real phones beside it. */
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
  useGsap(() => {
    /* The three phones drift at different speeds — parallax, scrubbed. */
    gsap.utils.toArray<HTMLElement>(".uc-phone").forEach((el) => {
      gsap.to(el, {
        y: parseFloat(el.dataset.speed || "0"),
        ease: "none",
        scrollTrigger: {
          trigger: el,
          start: "top bottom",
          end: "bottom top",
          scrub: 1.2,
        },
      });
    });

    /* The heads-up banner hops for attention the first time it's seen. */
    ScrollTrigger.create({
      trigger: ".uc-banner",
      start: "top 80%",
      once: true,
      onEnter: () =>
        animate(".uc-banner", {
          translateY: [0, -14, 0],
          duration: 950,
          easing: "easeOutElastic(1, 0.42)",
        }),
    });
  });

  return (
    <section id="story" className="border-b border-line bg-canvas py-20 md:py-28">
      <div className="mx-auto max-w-6xl px-6">
        <Rise>
          <div className="grid gap-6 border-b border-line pb-10 md:grid-cols-12 md:gap-10">
            <div className="md:col-span-5">
              <h2 className="eyebrow text-teal">In practice</h2>
              <p className="display mt-5 text-[clamp(1.9rem,4.5vw,2.75rem)] text-ink">
                One store, four people, no second trip.
              </p>
            </div>
            <div className="md:col-span-6 md:col-start-7 md:self-end">
              <p className="text-[17px] leading-relaxed text-ink-2">
                This is the afternoon Allim was built around. Nothing here needs
                anyone to open the app at the right moment.
              </p>
            </div>
          </div>
        </Rise>

        <ol className="mt-14 grid gap-14 md:grid-cols-3 md:gap-8">
          {beats.map((beat, index) => (
            <li key={beat.n}>
              <Rise delay={index * 130} className="flex h-full flex-col">
                <div className="flex items-baseline gap-4 border-t-2 border-teal pt-4">
                  <span className="figure text-[13px] text-teal">{beat.n}</span>
                  <span className="eyebrow text-ink-3">{beat.label}</span>
                </div>
                <h3 className="mt-4 text-[21px] font-bold leading-snug tracking-[-0.02em] text-ink">
                  {beat.title}
                </h3>
                <p className="mt-3 text-[15px] leading-relaxed text-ink-2">{beat.desc}</p>
                <div className="mt-auto flex justify-center pt-10">
                  <div className="uc-phone" data-speed={beat.speed}>
                    {beat.phone}
                  </div>
                </div>
              </Rise>
            </li>
          ))}
        </ol>

        <Rise delay={160}>
          <p className="mt-16 border-t border-line pt-8 text-[17px] text-ink-2">
            <span className="font-semibold text-ink">The result:</span> nobody
            forgets the milk, and one trip covers everyone.
          </p>
        </Rise>
      </div>
    </section>
  );
}
