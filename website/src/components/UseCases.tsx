import { ListPlus, ChevronRight, Bell, Car } from "lucide-react";
import PhoneFrame from "./PhoneFrame";
import FadeIn from "./FadeIn";

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
          "linear-gradient(to bottom, rgb(242,245,250), rgb(224,235,245))",
      }}
    >
      {/* Nav bar */}
      <div className="flex items-center justify-between px-4 pt-1 pb-2">
        <span className="text-[13px] text-blue-500">Stores</span>
        <span className="text-[13px] text-blue-500">Edit</span>
      </div>

      {/* Header */}
      <div className="px-4 pb-2 flex items-center gap-3">
        <div
          className="w-[40px] h-[40px] rounded-full flex items-center justify-center shrink-0"
          style={{ background: "linear-gradient(135deg, #FBBF24, #2563EB)" }}
        >
          <span className="text-white text-[16px] font-bold">W</span>
        </div>
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
          "linear-gradient(to bottom, rgb(242,245,250), rgb(224,235,245))",
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
              background: "linear-gradient(90deg, #10B981, #059669)",
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
            <div
              className="w-[42px] h-[42px] rounded-full flex items-center justify-center shrink-0"
              style={{ background: "linear-gradient(135deg, #FBBF24, #2563EB)" }}
            >
              <span className="text-white text-[16px] font-bold">W</span>
            </div>
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
            { n: "Whole Foods", l: "W", a: "#34D399", b: "#059669", c: 3 },
            { n: "Costco", l: "C", a: "#60A5FA", b: "#2563EB", c: 8 },
          ].map((s) => (
            <div
              key={s.n}
              className="flex items-center gap-3 px-3 py-2.5 rounded-2xl"
              style={{
                background: "rgba(255,255,255,0.55)",
                border: "1.5px solid rgba(255,255,255,0.5)",
              }}
            >
              <div
                className="w-[42px] h-[42px] rounded-full flex items-center justify-center"
                style={{ background: `linear-gradient(135deg, ${s.a}, ${s.b})` }}
              >
                <span className="text-white text-[16px] font-bold">{s.l}</span>
              </div>
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
          "linear-gradient(135deg, #1e3a8a 0%, #312e81 50%, #1e1b4b 100%)",
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
const flowSteps = [
  {
    n: "01",
    title: "Family adds to a shared list",
    desc: "Mom, Dad, and the kids drop everything they need at Walmart into one shared list throughout the week — milk, bread, paper towels, you name it.",
    accent: "from-amber-400 to-orange-400",
  },
  {
    n: "02",
    title: "Someone heads out",
    desc: "John is driving past Walmart on his way home. He opens Allim and swipes the Walmart store row to the right.",
    accent: "from-emerald-400 to-teal-400",
  },
  {
    n: "03",
    title: "Family gets a heads-up",
    desc: "Everyone sharing the list instantly gets a notification: \"John is going to Walmart and is going to take approximately 7 minutes.\" Time to add those last-minute items.",
    accent: "from-blue-400 to-indigo-400",
  },
];

export default function UseCases() {
  return (
    <section
      id="use-cases"
      className="relative bg-allim-dark py-32 overflow-hidden"
    >
      {/* Background glows */}
      <div className="absolute top-1/4 -left-32 w-[500px] h-[500px] bg-emerald-500/5 rounded-full blur-[60px]" />
      <div className="absolute bottom-1/4 -right-32 w-[500px] h-[500px] bg-amber-500/5 rounded-full blur-[60px]" />

      <div className="relative z-10 max-w-7xl mx-auto px-6">
        {/* Heading */}
        <FadeIn className="text-center mb-16">
          <span className="inline-flex items-center gap-1.5 px-4 py-1.5 rounded-full bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 text-sm font-medium mb-4">
            <Car size={14} />
            Real-World Scenario
          </span>
          <h2 className="text-4xl sm:text-5xl font-bold text-white tracking-tight">
            When Allim{" "}
            <span className="bg-gradient-to-r from-emerald-400 to-amber-400 bg-clip-text text-transparent">
              comes in handy
            </span>
          </h2>
          <p className="mt-4 text-lg text-allim-muted max-w-2xl mx-auto">
            Picture a busy family who all shop at the same store. Here's how
            Allim turns a quick run to Walmart into a coordinated team effort.
          </p>
        </FadeIn>

        {/* Three phones telling the story */}
        <div className="grid md:grid-cols-3 gap-10 md:gap-6 mb-20 items-end">
          {[
            {
              label: "1. Shared Walmart list",
              sub: "Mom, Dad & Sister keep adding items",
              screen: <WalmartListScreen />,
              chip: "from-amber-500/20 to-orange-500/20",
              chipText: "text-amber-300",
              delay: 0,
            },
            {
              label: "2. John swipes right",
              sub: "On his way — notify the family",
              screen: <SwipeStoreScreen />,
              chip: "from-emerald-500/20 to-teal-500/20",
              chipText: "text-emerald-300",
              delay: 150,
            },
            {
              label: "3. Family gets notified",
              sub: '"John is going to Walmart…"',
              screen: <OnMyWayNotificationScreen />,
              chip: "from-blue-500/20 to-indigo-500/20",
              chipText: "text-blue-300",
              delay: 300,
            },
          ].map((stage) => (
            <FadeIn
              key={stage.label}
              delay={stage.delay}
              className="flex flex-col items-center"
            >
              <span
                className={`inline-block px-3 py-1 rounded-full bg-gradient-to-r ${stage.chip} ${stage.chipText} text-xs font-medium mb-4 border border-white/5`}
              >
                {stage.label}
              </span>
              <PhoneFrame>{stage.screen}</PhoneFrame>
              <p className="mt-4 text-sm text-allim-muted text-center max-w-[240px]">
                {stage.sub}
              </p>
            </FadeIn>
          ))}
        </div>

        {/* Flow diagram */}
        <FadeIn delay={200}>
          <div className="relative rounded-3xl bg-white/[0.03] border border-white/[0.06] p-8 md:p-10">
            <div className="grid md:grid-cols-3 gap-8 md:gap-4">
              {flowSteps.map((step, i) => (
                <div key={step.n} className="relative">
                  {/* Connector arrow */}
                  {i < flowSteps.length - 1 && (
                    <div className="hidden md:flex absolute top-7 -right-2 z-10 text-white/20">
                      <ChevronRight size={28} />
                    </div>
                  )}

                  <div className="flex items-start gap-4">
                    <div
                      className={`shrink-0 w-12 h-12 rounded-2xl bg-gradient-to-br ${step.accent} flex items-center justify-center text-white font-bold text-sm shadow-lg`}
                    >
                      {step.n}
                    </div>
                    <div>
                      <h4 className="text-white font-semibold mb-1.5">
                        {step.title}
                      </h4>
                      <p className="text-sm text-allim-muted leading-relaxed">
                        {step.desc}
                      </p>
                    </div>
                  </div>
                </div>
              ))}
            </div>

            {/* Result footer */}
            <div className="mt-8 pt-6 border-t border-white/5 flex flex-col sm:flex-row items-center gap-4 justify-center text-center">
              <div className="flex items-center gap-2.5">
                <div className="w-9 h-9 rounded-xl bg-gradient-to-br from-blue-500 to-violet-500 flex items-center justify-center">
                  <Bell size={16} className="text-white" />
                </div>
                <span className="text-white text-sm font-medium">
                  Result: nobody forgets the milk, and one trip covers everyone.
                </span>
              </div>
            </div>
          </div>
        </FadeIn>
      </div>
    </section>
  );
}
