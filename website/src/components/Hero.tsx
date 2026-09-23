import { useRef } from "react";
import { animate, stagger } from "animejs";
import AppStoreButton from "./AppStoreButton";
import { AisleLegend } from "./AisleDots";
import PhoneFrame from "./PhoneFrame";
import { PushBanner } from "./screens/parts";
import { finePointer, gsap, useGsap } from "../lib/motion";

/* The hero phone is a real screenshot of the app rather than a rebuilt
   facsimile: it is the actual stores list, with the real retailer marks the app
   pulls in, which is the one place on the page those belong. It carries its own
   status bar and Dynamic Island, so the frame draws neither, and the bezel is
   sized to the image's 920x2000 so nothing is stretched. */
const SHOT = { src: "/allim-stores-screen.webp", width: 920, height: 2000 };

// 274 - 6px of bezel = 268 of screen; 268 / (920/2000) = 583 of screen height.
const FRAME = { width: 274, height: 589 };

export default function Hero() {
  const sectionRef = useRef<HTMLElement | null>(null);

  useGsap(() => {
    const section = sectionRef.current!;

    /* ---- Load choreography ------------------------------------------- */
    const tl = gsap.timeline({ defaults: { ease: "power3.out" } });
    tl.from(".hero-line", { yPercent: 118, duration: 1.15, stagger: 0.13 }, 0.15)
      .from(".hero-sub", { y: 26, opacity: 0, duration: 0.9 }, 0.55)
      .from(".hero-cta", { y: 26, opacity: 0, duration: 0.9 }, 0.7)
      .from(".hero-legend", { y: 22, opacity: 0, duration: 0.85 }, 0.85)
      .from(
        ".hero-phone",
        { y: 90, opacity: 0, rotation: 6, duration: 1.4, ease: "expo.out" },
        0.5
      )
      .from(
        ".hero-banner",
        { y: -120, opacity: 0, duration: 1.25, ease: "elastic.out(1, 0.55)" },
        1.3
      );

    /* ---- Aisle dots pop in with anime.js ------------------------------ */
    gsap.set(".hero-legend li", { opacity: 0, scale: 0.5 });
    animate(".hero-legend li", {
      opacity: [0, 1],
      scale: [0.5, 1],
      delay: stagger(60, { start: 1100 }),
      duration: 520,
      easing: "easeOutBack(2.2)",
    });

    /* ---- Ambient loops ------------------------------------------------ */
    gsap.to(".hero-phone-float", {
      y: -13,
      duration: 2.9,
      yoyo: true,
      repeat: -1,
      ease: "sine.inOut",
      delay: 1.8,
    });
    // The banner settles, then breathes — the way a real notification sits.
    gsap.to(".hero-banner", {
      y: -8,
      duration: 2.3,
      yoyo: true,
      repeat: -1,
      ease: "sine.inOut",
      delay: 3,
    });
    gsap.to(".hero-blob-a", {
      x: 70, y: 46, duration: 15, yoyo: true, repeat: -1, ease: "sine.inOut",
    });
    gsap.to(".hero-blob-b", {
      x: -60, y: -38, duration: 18, yoyo: true, repeat: -1, ease: "sine.inOut",
    });

    /* ---- Scroll parallax ---------------------------------------------- */
    gsap.to(".hero-copy", {
      yPercent: -7,
      ease: "none",
      scrollTrigger: { trigger: section, start: "top top", end: "bottom top", scrub: 1 },
    });
    gsap.to(".hero-phone-wrap", {
      yPercent: 9,
      ease: "none",
      scrollTrigger: { trigger: section, start: "top top", end: "bottom top", scrub: 1 },
    });

    /* ---- Pointer tilt on the phone (fine pointers only) --------------- */
    if (finePointer()) {
      const tilt = section.querySelector(".hero-phone-tilt") as HTMLElement;
      const rX = gsap.quickTo(tilt, "rotationX", { duration: 0.7, ease: "power2.out" });
      const rY = gsap.quickTo(tilt, "rotationY", { duration: 0.7, ease: "power2.out" });
      const onMove = (e: MouseEvent) => {
        const r = section.getBoundingClientRect();
        const px = (e.clientX - r.left) / r.width - 0.5;
        const py = (e.clientY - r.top) / r.height - 0.5;
        rY(px * 10);
        rX(-py * 8);
      };
      const onLeave = () => { rX(0); rY(0); };
      section.addEventListener("mousemove", onMove);
      section.addEventListener("mouseleave", onLeave);
      return () => {
        section.removeEventListener("mousemove", onMove);
        section.removeEventListener("mouseleave", onLeave);
      };
    }
  });

  return (
    <section
      ref={sectionRef}
      id="top"
      className="relative overflow-hidden border-b border-line bg-canvas pt-16"
    >
      {/* Ambient aisle-wash blobs, drifting behind everything. */}
      <div
        className="hero-blob-a pointer-events-none absolute -top-24 right-[8%] h-[420px] w-[420px] rounded-full opacity-60 blur-[90px]"
        style={{ background: "radial-gradient(circle, #e0f1f4 0%, transparent 70%)" }}
        aria-hidden="true"
      />
      <div
        className="hero-blob-b pointer-events-none absolute bottom-[-140px] left-[-80px] h-[380px] w-[380px] rounded-full opacity-50 blur-[90px]"
        style={{ background: "radial-gradient(circle, #fceae1 0%, transparent 70%)" }}
        aria-hidden="true"
      />

      <div className="relative mx-auto max-w-6xl px-6">
        <div className="grid items-center gap-14 py-16 md:py-20 lg:grid-cols-12 lg:gap-10 lg:py-24">
          {/* Type */}
          <div className="hero-copy lg:col-span-7">
            <h1 className="display text-[clamp(2.6rem,8.5vw,4.6rem)] text-ink">
              <span className="hero-mask">
                <span className="hero-line">Never forget your</span>
              </span>
              <span className="hero-mask">
                <span className="hero-line">groceries again.</span>
              </span>
            </h1>

            <p className="hero-sub mt-7 max-w-lg text-[17px] leading-relaxed text-ink-2">
              Keep a grocery list for every store you shop at. Allim pings you the
              moment you&apos;re near one, so the milk gets bought on the way home
              instead of on a second trip.
            </p>

            <div className="hero-cta mt-9 flex flex-wrap items-center gap-x-6 gap-y-4">
              <AppStoreButton />
              <p className="text-[13px] text-ink-3">Free &middot; iOS 17 and later</p>
            </div>

            {/* The aisle legend, doubling as proof of what Smart Category does. */}
            <div className="hero-legend mt-14 border-t border-line pt-6">
              <p className="eyebrow mb-4 text-ink-3">Sorted into aisles, automatically</p>
              <AisleLegend />
            </div>
          </div>

          {/* Phone, with the nudge arriving over it */}
          <div className="hero-phone-wrap flex justify-center lg:col-span-5 lg:justify-end">
            <div className="hero-phone-tilt" style={{ perspective: 1200 }}>
              <div className="hero-phone-float">
                <div className="hero-phone">
                  <PhoneFrame
                    chrome={false}
                    width={FRAME.width}
                    height={FRAME.height}
                    screenBackgroundClassName="bg-canvas"
                    overlay={
                      /* Sits where iOS drops a banner — clear of the Dynamic
                         Island, over the top of the list. */
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
        </div>
      </div>
    </section>
  );
}
