import AppStoreButton from "./AppStoreButton";
import Rise from "./Rise";

const free = ["Grocery lists", "Saved stores", "Location alerts", "Sharing"];
const premium = ["Smart Recipe", "Smart Category", "No ads"];

export default function Download() {
  return (
    /* The one solid field of brand colour on the page. Everything before this
       is ink on canvas, so arriving here reads as arriving somewhere. */
    <section id="download" className="bg-teal py-20 text-white md:py-28">
      <div className="mx-auto max-w-6xl px-6">
        <div className="grid gap-14 lg:grid-cols-12 lg:gap-16">
          <Rise className="lg:col-span-7">
            <h2 className="eyebrow text-wash/80">Free on the App Store</h2>
            <p className="display mt-6 text-[clamp(2.2rem,6vw,3.75rem)]">
              Put it on your phone
              <br />
              and forget about it.
            </p>
            <p className="mt-7 max-w-lg text-[17px] leading-relaxed text-wash/85">
              That is the whole idea. Allim sits in the background until the
              moment a list is worth showing you.
            </p>

            <div className="mt-10 flex flex-wrap items-center gap-x-6 gap-y-4">
              <AppStoreButton tone="wash" />
              <p className="text-[13px] text-wash/70">Requires iOS 17.0 or later.</p>
            </div>
          </Rise>

          <Rise delay={140} className="lg:col-span-4 lg:col-start-9">
            <dl className="text-[15px]">
              <dt className="eyebrow border-b border-white/25 pb-3 text-wash/70">
                Free, always
              </dt>
              {free.map((item) => (
                <dd key={item} className="border-b border-white/12 py-2.5 text-wash">
                  {item}
                </dd>
              ))}

              <dt className="eyebrow mt-9 border-b border-white/25 pb-3 text-wash/70">
                Premium · $0.99 / month
              </dt>
              {premium.map((item) => (
                <dd key={item} className="border-b border-white/12 py-2.5 text-wash">
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
