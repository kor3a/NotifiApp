import { useRef } from "react";
import { animate, stagger } from "animejs";
import AppStoreButton from "./AppStoreButton";
import Rise from "./Rise";
import { ScrollTrigger, finePointer, gsap, useGsap } from "../lib/motion";

const free = ["Grocery lists", "Saved stores", "Location alerts", "Sharing"];
const premium = ["Smart Recipe", "Smart Category", "No ads"];

const HEADLINE = "Put it on your phone and forget about it.";

export default function Download() {
  const sectionRef = useRef<HTMLElement | null>(null);
  const buttonWrapRef = useRef<HTMLDivElement | null>(null);

  useGsap(() => {
    const section = sectionRef.current!;

    /* The headline arrives word by word, masked. */
    const words = section.querySelectorAll(".dl-word");
    gsap.set(words, { yPercent: 115 });
    ScrollTrigger.create({
      trigger: section,
      start: "top 72%",
      once: true,
      onEnter: () =>
        gsap.to(words, {
          yPercent: 0,
          duration: 0.9,
          stagger: 0.07,
          ease: "power3.out",
        }),
    });

    /* The price-list rows cascade in with anime.js. */
    const rows = section.querySelectorAll(".dl-row");
    gsap.set(rows, { opacity: 0 });
    ScrollTrigger.create({
      trigger: rows[0],
      start: "top 85%",
      once: true,
      onEnter: () =>
        animate(rows, {
          opacity: [0, 1],
          translateX: [-18, 0],
          delay: stagger(80),
          duration: 600,
          easing: "easeOutCubic",
        }),
    });

    /* The store button breathes — a soft pulse ring on a loop. */
    const ring = section.querySelector(".dl-ring") as HTMLElement;
    animate(ring, {
      scale: [1, 1.35],
      opacity: [0.55, 0],
      duration: 2200,
      easing: "easeOutCubic",
      loop: true,
    });

    /* …and leans toward the cursor like it's magnetic. */
    if (finePointer()) {
      const btn = buttonWrapRef.current!;
      const xTo = gsap.quickTo(btn, "x", { duration: 0.45, ease: "power3" });
      const yTo = gsap.quickTo(btn, "y", { duration: 0.45, ease: "power3" });
      const onMove = (e: MouseEvent) => {
        const r = btn.getBoundingClientRect();
        xTo((e.clientX - (r.left + r.width / 2)) * 0.28);
        yTo((e.clientY - (r.top + r.height / 2)) * 0.38);
      };
      const onLeave = () => {
        xTo(0);
        yTo(0);
      };
      btn.addEventListener("mousemove", onMove);
      btn.addEventListener("mouseleave", onLeave);
      return () => {
        btn.removeEventListener("mousemove", onMove);
        btn.removeEventListener("mouseleave", onLeave);
      };
    }
  });

  return (
    /* The one solid field of brand colour on the page. Everything before this
       is ink on canvas, so arriving here reads as arriving somewhere. */
    <section ref={sectionRef} id="download" className="bg-teal py-20 text-white md:py-28">
      <div className="mx-auto max-w-6xl px-6">
        <div className="grid gap-14 lg:grid-cols-12 lg:gap-16">
          <div className="lg:col-span-7">
            <Rise>
              <h2 className="eyebrow text-wash/80">Free on the App Store</h2>
            </Rise>
            <p
              className="display mt-6 text-[clamp(2.2rem,6vw,3.75rem)]"
              aria-label={HEADLINE}
            >
              {HEADLINE.split(" ").map((word, i) => (
                <span key={i} className="dl-mask" aria-hidden="true">
                  <span className="dl-word">{word}</span>
                  {i < HEADLINE.split(" ").length - 1 ? " " : ""}
                </span>
              ))}
            </p>
            <Rise delay={120}>
              <p className="mt-7 max-w-lg text-[17px] leading-relaxed text-wash/85">
                That is the whole idea. Allim sits in the background until the
                moment a list is worth showing you.
              </p>
            </Rise>

            <Rise delay={200}>
              <div className="mt-10 flex flex-wrap items-center gap-x-6 gap-y-4">
                <div className="relative" ref={buttonWrapRef}>
                  <span
                    className="dl-ring pointer-events-none absolute inset-0 rounded-[3px] bg-white/40"
                    aria-hidden="true"
                  />
                  <AppStoreButton tone="wash" className="relative" />
                </div>
                <p className="text-[13px] text-wash/70">Requires iOS 17.0 or later.</p>
              </div>
            </Rise>
          </div>

          <Rise delay={140} className="lg:col-span-4 lg:col-start-9">
            <dl className="text-[15px]">
              <dt className="eyebrow border-b border-white/25 pb-3 text-wash/70">
                Free, always
              </dt>
              {free.map((item) => (
                <dd key={item} className="dl-row border-b border-white/12 py-2.5 text-wash">
                  {item}
                </dd>
              ))}

              <dt className="eyebrow mt-9 border-b border-white/25 pb-3 text-wash/70">
                Premium · $0.99 / month
              </dt>
              {premium.map((item) => (
                <dd key={item} className="dl-row border-b border-white/12 py-2.5 text-wash">
                  {item}
                </dd>
              ))}
            </dl>
          </Rise>
        </div>
      </div>
    </section>
  );
}
