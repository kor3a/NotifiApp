import AppStoreButton from "./AppStoreButton";
import { AisleLegend } from "./AisleDots";
import PhoneFrame from "./PhoneFrame";
import StoresScreen from "./screens/StoresScreen";
import { PushBanner } from "./screens/parts";

export default function Hero() {
  return (
    <section id="top" className="border-b border-line bg-canvas pt-16">
      <div className="mx-auto max-w-6xl px-6">
        <div className="grid items-center gap-14 py-16 md:py-20 lg:grid-cols-12 lg:gap-10 lg:py-24">
          {/* Type */}
          <div className="lg:col-span-7">
            <p className="eyebrow text-teal">
              Allim &middot; 알림 &middot; Korean for &ldquo;to inform&rdquo;
            </p>

            <h1 className="display mt-6 text-[clamp(2.6rem,8.5vw,4.6rem)] text-ink">
              Never forget your
              <br />
              groceries again.
            </h1>

            <p className="mt-7 max-w-lg text-[17px] leading-relaxed text-ink-2">
              Keep a grocery list for every store you shop at. Allim pings you the
              moment you&apos;re near one, so the milk gets bought on the way home
              instead of on a second trip.
            </p>

            <div className="mt-9 flex flex-wrap items-center gap-x-6 gap-y-4">
              <AppStoreButton />
              <p className="text-[13px] text-ink-3">
                Free &middot; iOS 17 and later
              </p>
            </div>

            {/* The aisle legend, doubling as proof of what Smart Category does. */}
            <div className="mt-14 border-t border-line pt-6">
              <p className="eyebrow mb-4 text-ink-3">Sorted into aisles, automatically</p>
              <AisleLegend />
            </div>
          </div>

          {/* Phone, with the nudge arriving over it */}
          <div className="flex justify-center lg:col-span-5 lg:justify-end">
            <PhoneFrame
              overlay={
                <div className="nudge-in pt-11">
                  <PushBanner
                    title="You're near Walmart"
                    body="5 groceries are waiting on this list."
                  />
                </div>
              }
            >
              <StoresScreen />
            </PhoneFrame>
          </div>
        </div>
      </div>
    </section>
  );
}
