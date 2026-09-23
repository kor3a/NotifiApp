import { useRef } from "react";
import { gsap, MOTION_OK, SplitText, useGSAP } from "../lib/gsap";
import AppStoreButton from "./AppStoreButton";

const free = ["Grocery lists", "Saved stores", "Location alerts", "Sharing"];
const premium = ["Smart Recipe", "Smart Category", "No ads"];

// A fixed pattern, so the server and the client draw the same barcode.
const BARS = [3, 1, 2, 1, 1, 3, 1, 2, 2, 1, 3, 1, 1, 2, 1, 3, 2, 1, 1, 2, 3, 1, 2, 1, 1, 1, 3, 2, 1, 2, 1, 3, 1, 1, 2, 2, 1, 3];

function Line({ left, right, strong = false }: { left: string; right?: string; strong?: boolean }) {
  return (
    <div className={`flex justify-between gap-4 ${strong ? "text-[15px] font-semibold" : ""}`}>
      <span>{left}</span>
      {right && <span className="tabular-nums">{right}</span>}
    </div>
  );
}

export default function Download() {
  const root = useRef<HTMLElement>(null);

  useGSAP(
    () => {
      const mm = gsap.matchMedia();
      mm.add(MOTION_OK, () => {
        const split = SplitText.create(".download-title", { type: "lines", mask: "lines" });

        const tl = gsap.timeline({ scrollTrigger: { trigger: root.current, start: "top 65%" } });
        tl.from(split.lines, { yPercent: 105, duration: 0.9, stagger: 0.12, ease: "power4.out" })
          .from(".download-copy", { y: 20, autoAlpha: 0, duration: 0.6, stagger: 0.1, ease: "power3.out" }, "-=0.5")
          // The receipt feeds out of the slot in little jerks, like a real
          // thermal printer.
          .from(".receipt", { yPercent: -100, duration: 2.2, ease: "steps(26)" }, 0.2)
          .from(".receipt-total", { scale: 1.25, color: "#d94f16", duration: 0.5, ease: "back.out(2)" }, "-=0.2");

        return () => split.revert();
      });
    },
    { scope: root },
  );

  return (
    <section ref={root} id="download" className="relative overflow-hidden bg-teal text-white">
      <div className="mx-auto max-w-6xl px-6 py-24 md:py-32">
        <div className="grid items-start gap-16 lg:grid-cols-12">
          <div className="lg:col-span-7 lg:pt-10">
            <h2 className="download-title display text-[clamp(2.6rem,7vw,4.8rem)]">
              Put it on your phone and forget about it.
            </h2>
            <p className="download-copy mt-8 max-w-lg text-[18px] leading-relaxed text-white/80">
              Really, that&apos;s the idea. Allim stays out of the way until the
              one moment a list is worth showing you.
            </p>
            <div className="download-copy mt-10 flex flex-wrap items-center gap-x-6 gap-y-4">
              <AppStoreButton tone="wash" />
              <p className="text-[14px] text-white/70">Needs iOS 17.0 or later.</p>
            </div>
          </div>

          <div className="relative mx-auto w-full max-w-[340px] lg:col-span-4 lg:col-start-9">
            {/* The printer's slot. The receipt is clipped to everything below it. */}
            <div className="relative z-10 h-4 rounded-full bg-teal-night shadow-[inset_0_3px_4px_rgba(0,0,0,0.5)]" aria-hidden="true" />
            <div className="-mt-2 overflow-hidden px-3 pb-6">
              <div className="receipt mono rotate-[0.6deg] px-6 pt-8 pb-10 text-[13px] leading-[1.9] shadow-[0_20px_40px_-20px_rgba(0,0,0,0.55)]">
                <p className="text-center text-[17px] font-semibold tracking-[0.2em]">ALLIM</p>
                <p className="text-center text-[11px] tracking-[0.1em] text-black/55">
                  EVERY STORE YOU SHOP AT
                </p>
                <p className="mt-2 text-center text-[11px] text-black/55">TUE 04/30 &middot; 2:47 PM</p>

                <div className="receipt-rule my-3" />
                <p className="text-[11px] tracking-[0.1em] text-black/55">FREE, ALWAYS</p>
                {free.map((item) => (
                  <Line key={item} left={item} right="0.00" />
                ))}

                <div className="receipt-rule my-3" />
                <p className="text-[11px] tracking-[0.1em] text-black/55">PREMIUM, IF YOU WANT IT</p>
                {premium.map((item) => (
                  <Line key={item} left={item} />
                ))}
                <Line left="per month" right="0.99" />

                <div className="receipt-rule my-3" />
                <div className="receipt-total origin-left">
                  <Line left="TOTAL TODAY" right="$0.00" strong />
                </div>
                <Line left="Second trips" right="0" />

                <div className="mt-6 flex h-12 items-stretch justify-center gap-[2px]" aria-hidden="true">
                  {BARS.map((w, i) => (
                    <span key={i} className="bg-black/85" style={{ width: w * 1.6 }} />
                  ))}
                </div>
                <p className="mt-4 text-center text-[11px] leading-relaxed tracking-[0.08em] text-black/60">
                  THANK YOU. COME BACK
                  <br />
                  WHEN YOU&apos;RE NEARBY.
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
