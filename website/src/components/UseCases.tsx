import PhoneFrame from "./PhoneFrame";
import Rise from "./Rise";
import {
  CountBadge,
  GroceryRow,
  HomeBar,
  PushBanner,
  ScreenHeader,
  StoreLogo,
} from "./screens/parts";

/* -- 01 · the shared list ------------------------------------------------- */

const shared = [
  { name: "Milk (2 gallons)", dot: "bg-dairy", by: { initial: "M", className: "bg-snacks" } },
  { name: "Sourdough", dot: "bg-bakery", by: { initial: "D", className: "bg-dairy" } },
  { name: "Eggs", dot: "bg-dairy", by: { initial: "M", className: "bg-snacks" } },
  { name: "Bananas", dot: "bg-produce", by: { initial: "S", className: "bg-household" } },
  { name: "Paper towels", dot: "bg-household", by: { initial: "D", className: "bg-dairy" } },
];

function SharedListScreen() {
  return (
    <div className="flex flex-1 flex-col overflow-hidden bg-canvas">
      <div className="flex items-center justify-between px-4 pb-1 text-[12px] text-teal">
        <span>Stores</span>
        <span>Edit</span>
      </div>

      <div className="flex items-center gap-3 px-4 pb-3">
        <StoreLogo name="Walmart" />
        <div>
          <p className="text-[15px] font-bold tracking-[-0.01em] text-ink">Walmart</p>
          <p className="text-[10.5px] text-ink-3">Shared with family · 5 items</p>
        </div>
      </div>

      <div className="flex-1 overflow-hidden px-3">
        <div className="overflow-hidden rounded-[14px] bg-card ring-1 ring-line">
          {shared.map((item) => (
            <GroceryRow key={item.name} {...item} />
          ))}
        </div>
        <p className="mt-3 px-1 text-[10.5px] text-ink-3">
          Everyone on the list can add. Edits sync live.
        </p>
      </div>

      <HomeBar />
    </div>
  );
}

/* -- 02 · the swipe ------------------------------------------------------- */

function SwipeScreen() {
  return (
    <div className="flex flex-1 flex-col overflow-hidden bg-canvas">
      <ScreenHeader eyebrow="Good afternoon" title="Your stores" />

      <div className="flex-1 overflow-hidden px-3">
        <div className="relative overflow-hidden rounded-[14px]">
          {/* The action the swipe reveals, sitting behind the row. */}
          <div className="absolute inset-0 flex items-center gap-2 bg-teal pl-4">
            <svg viewBox="0 0 24 24" className="h-4 w-4 shrink-0 text-white" fill="currentColor" aria-hidden="true">
              <path d="M18.92 6.01A1.5 1.5 0 0017.5 5h-11a1.5 1.5 0 00-1.42 1.01L3 12v8a1 1 0 001 1h1a1 1 0 001-1v-1h12v1a1 1 0 001 1h1a1 1 0 001-1v-8l-2.08-5.99zM6.85 7h10.3l1.04 3H5.81l1.04-3zM6.5 16a1.5 1.5 0 110-3 1.5 1.5 0 010 3zm11 0a1.5 1.5 0 110-3 1.5 1.5 0 010 3z" />
            </svg>
            <span className="text-[11.5px] font-semibold text-white">
              Notify family · on my way
            </span>
          </div>

          <div className="swipe-right relative flex items-center gap-3 bg-card px-3 py-2.5 ring-1 ring-line">
            <StoreLogo name="Walmart" />
            <div className="min-w-0 flex-1">
              <p className="truncate text-[14px] font-medium text-ink">Walmart</p>
              <p className="truncate text-[10.5px] text-ink-3">Shared · 3 people</p>
            </div>
            <CountBadge n={5} />
          </div>
        </div>

        <p className="mt-3 px-1 text-[10.5px] text-ink-3">Swipe a store to tell the list you&apos;re going.</p>

        <div className="mt-3 overflow-hidden rounded-[14px] bg-card opacity-55 ring-1 ring-line">
          {[
            { n: "Whole Foods", c: 3 },
            { n: "Costco", c: 8 },
          ].map((store) => (
            <div
              key={store.n}
              className="flex items-center gap-3 border-b border-line px-3 py-2.5 last:border-b-0"
            >
              <StoreLogo name={store.n} />
              <span className="flex-1 truncate text-[14px] text-ink">{store.n}</span>
              <CountBadge n={store.c} />
            </div>
          ))}
        </div>
      </div>

      <HomeBar />
    </div>
  );
}

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

      <div className="mt-6">
        <PushBanner
          title="John is going to Walmart"
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
    screen: <SharedListScreen />,
  },
  {
    n: "02",
    label: "The swipe",
    title: "John is driving past anyway",
    desc: "He opens Allim and swipes the Walmart row. That is the whole interaction.",
    screen: <SwipeScreen />,
  },
  {
    n: "03",
    label: "The heads-up",
    title: "The family gets seven minutes",
    desc: "Everyone on the list hears that John is going and roughly when he'll arrive — time enough to add one more thing.",
    screen: <LockScreen />,
    frame: { statusBarTone: "light" as const, screenBackgroundClassName: "bg-teal-deep" },
  },
];

export default function UseCases() {
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
                  <PhoneFrame {...(beat.frame ?? {})}>{beat.screen}</PhoneFrame>
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
