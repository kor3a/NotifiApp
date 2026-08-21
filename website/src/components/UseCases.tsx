import { ListPlus, ChevronRight, Car } from "lucide-react";
import PhoneFrame from "./PhoneFrame";
import FadeIn from "./FadeIn";

function StoreLogo({
  alt,
  className = "w-[42px] h-[42px] rounded-2xl",
  src,
}: {
  alt: string;
  className?: string;
  src: string;
}) {
  return (
    <div
      className={`${className} flex items-center justify-center overflow-hidden bg-white shadow-[0_2px_6px_rgba(0,0,0,0.10)] shrink-0`}
    >
      <img
        src={src}
        alt={alt}
        className="h-full w-full object-cover"
        draggable={false}
      />
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Phone 1 – Family adding items to a shared Walmart list             */
/* ------------------------------------------------------------------ */
function WalmartListScreen() {
  const items = [
    { name: "Milk (2 gallons)", by: "Mom", color: "#EC4899" },
    { name: "Bread", by: "Dad", color: "#3B82F6" },
    { name: "Eggs", by: "Mom", color: "#EC4899" },
    { name: "Bananas", by: "Sister", color: "#8B5CF6" },
    { name: "Paper towels", by: "Dad", color: "#3B82F6" },
  ];
  return (
    <div
      className="flex-1 flex flex-col overflow-hidden"
      style={{
        background:
          "rgb(240,243,248)",
      }}
    >
      {/* Nav bar */}
      <div className="flex items-center justify-between px-4 pt-1 pb-2">
        <span className="text-[13px] text-blue-500">Stores</span>
        <span className="text-[13px] text-blue-500">Edit</span>
      </div>

      {/* Header */}
      <div className="px-4 pb-2 flex items-center gap-3">
        <StoreLogo
          alt="Walmart"
          className="w-[40px] h-[40px] rounded-2xl"
          src="/store-logos/walmart.svg"
        />
        <div>
          <p className="text-[16px] font-bold text-black leading-tight">
            Walmart
          </p>
          <p className="text-[10px] text-gray-500">
            Shared with family · 5 items
          </p>
        </div>
      </div>

      {/* Items list */}
      <div className="flex-1 px-3 space-y-1.5 overflow-hidden">
        {items.map((it) => (
          <div
            key={it.name}
            className="rounded-xl px-3 py-2 flex items-center gap-2.5"
            style={{
              background: "rgba(255,255,255,0.7)",
              backdropFilter: "blur(20px)",
              WebkitBackdropFilter: "blur(20px)",
              border: "1px solid rgba(0,0,0,0.06)",
            }}
          >
            <div className="w-[18px] h-[18px] rounded-full border-[1.5px] border-gray-300 shrink-0" />
            <span className="text-[13px] text-black flex-1">{it.name}</span>
            <div className="flex items-center gap-1.5">
              <div
                className="w-[18px] h-[18px] rounded-full flex items-center justify-center"
                style={{ background: it.color }}
              >
                <span className="text-white text-[9px] font-bold">
                  {it.by[0]}
                </span>
              </div>
              <span className="text-[9px] text-gray-500">{it.by}</span>
            </div>
          </div>
        ))}

        {/* Add item row */}
        <div
          className="rounded-xl px-3 py-2 flex items-center gap-2.5 mt-1"
          style={{
            background: "rgba(59,130,246,0.08)",
            border: "1px dashed rgba(59,130,246,0.3)",
          }}
        >
          <ListPlus size={14} className="text-blue-500" />
          <span className="text-[12px] text-blue-500 font-medium">
            Tap to add an item
          </span>
        </div>
      </div>

      {/* Home indicator */}
      <div className="flex justify-center py-2">
        <div className="w-[100px] h-[4px] rounded-full bg-black/20" />
      </div>
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Phone 2 – Stores list with the Walmart row mid-swipe to the right  */
/* ------------------------------------------------------------------ */
function SwipeStoreScreen() {
  return (
    <div
      className="flex-1 flex flex-col overflow-hidden relative"
      style={{
        background:
          "rgb(240,243,248)",
      }}
    >
      {/* Header */}
      <div className="px-4 pt-1 pb-2">
        <p className="text-[11px] text-black/40">Good afternoon</p>
        <h2 className="text-[22px] font-bold text-black tracking-tight">
          Hi, John
        </h2>
      </div>

      <div className="flex-1 px-3 space-y-2 overflow-hidden">
        {/* Walmart row – revealed action behind */}
        <div className="relative">
          {/* Action background revealed by swipe */}
          <div
            className="absolute inset-0 rounded-2xl flex items-center pl-4 pr-3 gap-2"
            style={{
              background: "#059669",
              boxShadow: "inset 0 1px 2px rgba(255,255,255,0.2)",
            }}
          >
            <Car size={18} className="text-white" />
            <span className="text-white text-[12px] font-semibold">
              Notify family · I'm on my way
            </span>
          </div>

          {/* Foreground row, animated to reveal action */}
          <div
            className="flex items-center gap-3 px-3 py-2.5 rounded-2xl relative animate-swipe-right"
            style={{
              background: "rgba(255,255,255,0.95)",
              backdropFilter: "blur(20px)",
              WebkitBackdropFilter: "blur(20px)",
              border: "1.5px solid rgba(255,255,255,0.5)",
              boxShadow:
                "0 6px 14px rgba(0,0,0,0.18), 0 -2px 2px rgba(255,255,255,0.5)",
            }}
          >
            <StoreLogo alt="Walmart" src="/store-logos/walmart.svg" />
            <span className="text-[15px] text-black/90 flex-1">Walmart</span>
            <svg viewBox="0 0 24 24" className="w-[13px] h-[13px]" fill="#3B82F6">
              <path d="M16 11c1.66 0 2.99-1.34 2.99-3S17.66 5 16 5c-1.66 0-3 1.34-3 3s1.34 3 3 3zm-8 0c1.66 0 2.99-1.34 2.99-3S9.66 5 8 5C6.34 5 5 6.34 5 8s1.34 3 3 3zm0 2c-2.33 0-7 1.17-7 3.5V19h14v-2.5c0-2.33-4.67-3.5-7-3.5zm8 0c-.29 0-.62.02-.97.05 1.16.84 1.97 1.97 1.97 3.45V19h6v-2.5c0-2.33-4.67-3.5-7-3.5z" />
            </svg>
            <div className="w-[22px] h-[22px] rounded-full bg-red-500 flex items-center justify-center">
              <span className="text-white text-[11px] font-semibold">5</span>
            </div>
          </div>

          {/* Swipe indicator arrow */}
          <div className="absolute -bottom-5 right-2 flex items-center gap-1 text-emerald-500 animate-pulse">
            <span className="text-[10px] font-semibold">Swipe right</span>
            <ChevronRight size={14} />
          </div>
        </div>

        {/* Other stores, dimmer */}
        <div className="pt-6 space-y-2 opacity-60">
          {[
            {
              n: "Whole Foods",
              logo: "/store-logos/whole-foods.svg",
              c: 3,
            },
            { n: "Costco", logo: "/store-logos/costco.svg", c: 8 },
          ].map((s) => (
            <div
              key={s.n}
              className="flex items-center gap-3 px-3 py-2.5 rounded-2xl"
              style={{
                background: "rgba(255,255,255,0.55)",
                border: "1.5px solid rgba(255,255,255,0.5)",
              }}
            >
              <StoreLogo alt={s.n} src={s.logo} />
              <span className="text-[15px] text-black/90 flex-1">{s.n}</span>
              <div className="w-[22px] h-[22px] rounded-full bg-red-500 flex items-center justify-center">
                <span className="text-white text-[11px] font-semibold">
                  {s.c}
                </span>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Home indicator */}
      <div className="flex justify-center py-2">
        <div className="w-[100px] h-[4px] rounded-full bg-black/20" />
      </div>
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Phone 3 – Family member's phone receiving the notification         */
/* ------------------------------------------------------------------ */
function OnMyWayNotificationScreen() {
  return (
    <div
      className="flex-1 flex flex-col overflow-hidden relative"
      style={{
        background:
          "#1E1B4B",
      }}
    >
      {/* Lock-screen time */}
      <div className="text-center pt-6 pb-3">
        <p className="text-white/80 text-[12px] font-medium tracking-wide">
          Tuesday, April 30
        </p>
        <p className="text-white text-[60px] font-light leading-none mt-1 tracking-tight">
          2:47
        </p>
      </div>

      {/* Notification banner */}
      <div className="px-3">
        <div
          className="rounded-[20px] p-3 flex items-start gap-2.5"
          style={{
            background: "rgba(255,255,255,0.18)",
            backdropFilter: "blur(30px)",
            WebkitBackdropFilter: "blur(30px)",
            border: "1px solid rgba(255,255,255,0.15)",
            boxShadow: "0 8px 32px rgba(0,0,0,0.3)",
          }}
        >
          {/* App icon */}
          <img
            src="/allimIcon.svg"
            alt="Allim"
            className="w-[34px] h-[34px] rounded-[8px] shrink-0 object-cover"
          />

          <div className="flex-1 min-w-0">
            <div className="flex items-center justify-between">
              <span className="text-[12px] font-semibold text-white">
                Allim
              </span>
              <span className="text-[10px] text-white/70">now</span>
            </div>
            <p className="text-[13px] font-semibold text-white mt-0.5 leading-tight">
              John is going to Walmart
            </p>
            <p className="text-[11px] text-white/85 mt-0.5 leading-snug">
              Arriving in approximately 7 minutes. Add any last-minute items to
              the list.
            </p>
          </div>
        </div>

        {/* Quick action chip */}
        <div className="mt-2 flex items-center justify-center gap-1.5">
          <ListPlus size={12} className="text-white/80" />
          <span className="text-[11px] text-white/80">
            Tap to add to Walmart list
          </span>
        </div>
      </div>

      {/* Bottom flashlight/camera + home indicator */}
      <div className="flex-1 flex flex-col justify-end pb-4 px-8">
        <div className="flex items-center justify-between mb-3">
          <div className="w-[40px] h-[40px] rounded-full bg-white/15 backdrop-blur flex items-center justify-center">
            <svg viewBox="0 0 24 24" className="w-[16px] h-[16px]" fill="white">
              <path d="M9 2v2H7V2H5v2H3v18h18V4h-2V2h-2v2h-2V2H9zm10 6H5V6h14v2zm-7 3a4 4 0 100 8 4 4 0 000-8z" />
            </svg>
          </div>
          <div className="w-[40px] h-[40px] rounded-full bg-white/15 backdrop-blur flex items-center justify-center">
            <svg viewBox="0 0 24 24" className="w-[16px] h-[16px]" fill="white">
              <path d="M12 2L4 5v6c0 5.5 3.8 10.7 8 12 4.2-1.3 8-6.5 8-12V5l-8-3z" />
            </svg>
          </div>
        </div>
        <div className="flex justify-center">
          <div className="w-[100px] h-[4px] rounded-full bg-white/40" />
        </div>
      </div>
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Section                                                            */
/* ------------------------------------------------------------------ */
const stages = [
  {
    n: "01",
    label: "The shared list",
    title: "Everyone adds during the week",
    desc: "Mom, Dad, and Sister add groceries to one shared Walmart list as they run out — milk, bread, paper towels.",
    screen: <WalmartListScreen />,
  },
  {
    n: "02",
    label: "The swipe",
    title: "John is driving past anyway",
    desc: "He opens Allim and swipes the Walmart row to the right. That's the whole interaction.",
    screen: <SwipeStoreScreen />,
  },
  {
    n: "03",
    label: "The heads-up",
    title: "The family gets seven minutes",
    desc: "Everyone on the grocery list is notified that John is going and roughly when he'll arrive — time enough to add one more thing.",
    screen: <OnMyWayNotificationScreen />,
    phoneFrameProps: {
      screenBackgroundStyle: { background: "#1E1B4B" },
      statusBarTone: "light" as const,
    },
  },
];

export default function UseCases() {
  return (
    <section
      id="story"
      className="border-y border-allim-line bg-allim-surface py-24 md:py-28"
    >
      <div className="mx-auto max-w-6xl px-6">
        <FadeIn>
          <div className="grid gap-6 md:grid-cols-12 md:gap-12">
            <div className="md:col-span-6">
              <p className="mb-4 text-[13px] font-medium uppercase tracking-[0.14em] text-allim-accent">
                In practice
              </p>
              <h2 className="text-4xl font-bold leading-[1.1] tracking-tight text-white sm:text-5xl">
                One family,
                <br className="hidden sm:block" /> one trip to Walmart.
              </h2>
            </div>
            <div className="md:col-span-5 md:col-start-8 md:pt-14">
              <p className="text-lg leading-relaxed text-allim-muted">
                This is the scenario Allim was built around: four people, one
                store, and nobody making a second trip for the milk.
              </p>
            </div>
          </div>
        </FadeIn>

        {/* Three beats of the story */}
        <div className="mt-16 grid gap-14 md:grid-cols-3 md:gap-8">
          {stages.map((stage, index) => (
            <FadeIn key={stage.n} delay={index * 150} className="h-full">
              <div className="flex h-full flex-col">
                <div className="flex items-baseline gap-4 border-t border-allim-line-strong pt-5">
                  <span className="font-display text-sm tabular-nums text-allim-accent">
                    {stage.n}
                  </span>
                  <span className="text-[13px] font-medium uppercase tracking-[0.14em] text-allim-muted">
                    {stage.label}
                  </span>
                </div>
                <h3 className="mt-4 text-xl font-semibold leading-snug text-white">
                  {stage.title}
                </h3>
                <p className="mt-3 text-[15px] leading-relaxed text-allim-muted">
                  {stage.desc}
                </p>
                <div className="mt-auto flex justify-center pt-10">
                  <PhoneFrame {...(stage.phoneFrameProps ?? {})}>
                    {stage.screen}
                  </PhoneFrame>
                </div>
              </div>
            </FadeIn>
          ))}
        </div>

        {/* Payoff line */}
        <FadeIn delay={200}>
          <p className="mt-16 border-t border-allim-line pt-8 text-lg text-allim-muted">
            <span className="font-medium text-white">The result:</span> nobody
            forgets the milk, and one trip covers everyone.
          </p>
        </FadeIn>
      </div>
    </section>
  );
}
