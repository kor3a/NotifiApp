import { useRef } from "react";
import { gsap, MOTION_OK, SplitText, useGSAP } from "../lib/gsap";
import AppStoreButton from "./AppStoreButton";
import PhoneFrame from "./PhoneFrame";
import { PushBanner } from "./screens/parts";
import { SHOT_FRAME, shotSources } from "./screens/shot";

/* The hero phone is a real screenshot of the app: the actual stores list, with
   the real retailer marks the app pulls in. It carries its own status bar and
   Dynamic Island, so the frame draws neither, and the bezel is sized to the
   image's 920x2000 so nothing is stretched. */
const SHOT = { ...shotSources("allim-stores-screen"), width: 920, height: 2000 };

/** The list on the fridge, the thing Allim replaces. `done` gets a pen line
 *  through it once the hero has played in; `circled` gets a ring. */
const LIST: { item: string; done?: boolean; circled?: boolean }[] = [
  { item: "milk !!", circled: true },
  { item: "eggs", done: true },
  { item: "bananas", done: true },
  { item: "paper towels" },
  { item: "gochujang", done: true },
  { item: "rice? ask mom" },
];

export default function Hero() {
  const root = useRef<HTMLElement>(null);

  useGSAP(
    () => {
      const mm = gsap.matchMedia();

      mm.add(MOTION_OK, () => {
        const split = SplitText.create(".hero-title", {
          type: "lines,words",
          mask: "lines",
        });

        const intro = gsap.timeline({ defaults: { ease: "power3.out" } });
        intro
          .set(".pre-reveal", { visibility: "visible" })
          .from(split.words, { yPercent: 110, duration: 0.9, stagger: 0.045 })
          .from(".hero-marker path", { drawSVG: 0, duration: 0.6, ease: "power2.inOut" }, "-=0.3")
          .from(".hero-copy", { y: 16, autoAlpha: 0, duration: 0.7, stagger: 0.08 }, "-=0.5")
          .from(
            ".hero-note",
            { y: 60, rotate: -14, autoAlpha: 0, duration: 1.1, ease: "back.out(1.4)" },
            0.35,
          )
          .from(".hero-phone", { y: 90, rotate: 6, autoAlpha: 0, duration: 1.1 }, 0.5)
          .from(".hero-strike", { drawSVG: 0, duration: 0.35, stagger: 0.28, ease: "power1.in" }, "-=0.2")
          .from(".hero-ring", { drawSVG: 0, duration: 0.6, ease: "power2.inOut" }, "-=0.1")
          .from(".hero-scrawl", { autoAlpha: 0, x: -8, duration: 0.4 }, "-=0.2");

        // The banner drops in the way iOS delivers one, sits, and goes, on a
        // loop that starts once the list has been worked through.
        const banner = gsap.timeline({ repeat: -1, repeatDelay: 2.2, delay: intro.duration() - 0.4 });
        banner
          .fromTo(
            ".hero-banner",
            { yPercent: -140, autoAlpha: 0 },
            { yPercent: 0, autoAlpha: 1, duration: 0.55, ease: "back.out(1.2)" },
          )
          .to(".hero-phone", { rotate: -1.2, duration: 0.08, repeat: 5, yoyo: true, ease: "none" }, "<")
          .to(".hero-phone", { rotate: 0, duration: 0.1 })
          .to(".hero-banner", { yPercent: -140, autoAlpha: 0, duration: 0.45, ease: "power2.in" }, "+=3.2");

        // On the way out, the note and the phone part at different speeds.
        gsap.to(".hero-note", {
          yPercent: -18,
          rotate: -7,
          ease: "none",
          scrollTrigger: { trigger: root.current, start: "top top", end: "bottom top", scrub: true },
        });
        gsap.to(".hero-phone", {
          yPercent: 12,
          ease: "none",
          scrollTrigger: { trigger: root.current, start: "top top", end: "bottom top", scrub: true },
        });

        return () => split.revert();
      });
    },
    { scope: root },
  );

  return (
    <section ref={root} id="top" className="relative overflow-hidden pt-16">
      <div className="mx-auto max-w-6xl px-6">
        <div className="grid items-center gap-16 py-14 md:py-20 lg:grid-cols-12 lg:gap-8 lg:py-24">
          <div className="lg:col-span-7">
            <h1 className="hero-title pre-reveal display text-[clamp(2.8rem,7.4vw,4.7rem)] text-ink">
              The list shows up when{" "}
              <span className="marker">
                the store
                <svg
                  className="hero-marker"
                  viewBox="0 0 200 20"
                  preserveAspectRatio="none"
                  aria-hidden="true"
                >
                  <path
                    d="M3 12 C 40 6, 90 15, 130 9 S 185 8, 197 11"
                    fill="none"
                    stroke="var(--color-tag)"
                    strokeWidth="16"
                    strokeLinecap="round"
                  />
                </svg>
              </span>{" "}
              does.
            </h1>

            <p className="hero-copy pre-reveal mt-8 max-w-[34rem] text-[18px] leading-[1.6] text-ink-2">
              Allim keeps a separate grocery list for every store you shop at, and
              taps you on the shoulder when you&apos;re driving past one. The milk
              gets bought on the way home instead of on a second trip.
            </p>

            <div className="hero-copy pre-reveal mt-10 flex flex-wrap items-center gap-x-6 gap-y-4">
              <AppStoreButton />
              <p className="text-[14px] text-ink-3">Free on iPhone &middot; iOS 17+</p>
            </div>
          </div>

          <div className="relative flex min-h-[600px] justify-center lg:col-span-5 lg:justify-end">
            {/* The paper list it replaces, pinned behind the phone. */}
            <div
              className="hero-note pre-reveal notepad absolute top-6 left-1/2 w-[250px] -translate-x-[88%] -rotate-3 px-6 pt-5 pb-7 sm:-translate-x-[95%] lg:left-auto lg:right-[236px] lg:translate-x-0"
              aria-hidden="true"
            >
              <p className="hand pl-6 text-[30px] text-pen">costco run</p>
              <ul className="mt-2 pl-6">
                {LIST.map(({ item, done, circled }) => (
                  <li key={item} className="relative h-[34px] w-fit pr-2 text-[27px] leading-[34px]">
                    <span className="hand text-pen">{item}</span>
                    {done && (
                      <svg
                        className="absolute inset-x-[-4px] top-[14px] h-[10px] w-[calc(100%+8px)] overflow-visible"
                        viewBox="0 0 100 10"
                        preserveAspectRatio="none"
                      >
                        <path
                          className="hero-strike"
                          d="M1 6 C 25 3, 55 8, 99 4"
                          fill="none"
                          stroke="var(--color-pen)"
                          strokeWidth="2.2"
                          strokeLinecap="round"
                        />
                      </svg>
                    )}
                    {circled && (
                      <svg
                        className="absolute top-[-2px] left-[-12px] h-[38px] w-[calc(100%+22px)] overflow-visible"
                        viewBox="0 0 110 40"
                        preserveAspectRatio="none"
                      >
                        <path
                          className="hero-ring"
                          d="M20 7 C 50 -2, 104 3, 106 18 C 108 34, 50 40, 20 35 C 2 31, 0 16, 14 9 C 22 5, 34 4, 44 5"
                          fill="none"
                          stroke="var(--color-orange)"
                          strokeWidth="2"
                          strokeLinecap="round"
                        />
                      </svg>
                    )}
                  </li>
                ))}
              </ul>
              <p className="hero-scrawl hand mt-3 pl-6 text-[22px] text-orange">
                don&apos;t forget this time &rarr;
              </p>
            </div>

            <div
              className="hero-phone pre-reveal relative z-10 mt-20 translate-x-[17%] sm:translate-x-[36%] lg:mt-0 lg:translate-x-0"
              style={{ width: `min(${SHOT_FRAME.width}px, 100%)` }}
            >
              <PhoneFrame
                chrome={false}
                width={SHOT_FRAME.width}
                height={SHOT_FRAME.height}
                fluid
                screenBackgroundClassName="bg-canvas"
                overlay={
                  /* Where iOS drops a banner: clear of the Dynamic Island, over
                     the top of the list. */
                  <div className="hero-banner pt-10">
                    <PushBanner
                      title="You're near Costco Wholesale"
                      body="14 groceries are waiting on this list."
                    />
                  </div>
                }
              >
                <img
                  src={SHOT.src}
                  srcSet={SHOT.srcSet}
                  sizes={SHOT.sizes}
                  width={SHOT.width}
                  height={SHOT.height}
                  alt="The Allim stores screen: Costco Wholesale, Walmart, Trader Joe's, H Mart and other saved stores, each showing how many groceries are still on its list."
                  className="h-full w-full object-cover"
                  fetchPriority="high"
                  draggable={false}
                />
              </PhoneFrame>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
