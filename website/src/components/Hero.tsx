import AppStoreButton from "./AppStoreButton";
import { AisleLegend } from "./AisleDots";
import PhoneFrame from "./PhoneFrame";
import { PushBanner } from "./screens/parts";

/* The hero phone is a real screenshot of the app rather than a rebuilt
   facsimile: it is the actual stores list, with the real retailer marks the app
   pulls in, which is the one place on the page those belong. It carries its own
   status bar and Dynamic Island, so the frame draws neither, and the bezel is
   sized to the image's 920x2000 so nothing is stretched. */
const SHOT = { src: "/allim-stores-screen.webp", width: 920, height: 2000 };

// 274 - 6px of bezel = 268 of screen; 268 / (920/2000) = 583 of screen height.
const FRAME = { width: 274, height: 589 };

export default function Hero() {
  return (
    <section id="top" className="border-b border-line bg-canvas pt-16">
      <div className="mx-auto max-w-6xl px-6">
        <div className="grid items-center gap-14 py-16 md:py-20 lg:grid-cols-12 lg:gap-10 lg:py-24">
          {/* Type */}
          <div className="lg:col-span-7">
            <h1 className="display text-[clamp(2.6rem,8.5vw,4.6rem)] text-ink">
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
              <p className="text-[13px] text-ink-3">Free &middot; iOS 17 and later</p>
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
              chrome={false}
              width={FRAME.width}
              height={FRAME.height}
              screenBackgroundClassName="bg-canvas"
              overlay={
                /* Sits where iOS drops a banner — clear of the Dynamic Island,
                   over the top of the list. */
                <div className="nudge-in pt-10">
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
    </section>
  );
}
