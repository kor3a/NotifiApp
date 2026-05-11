export default function NotificationScreen() {
  return (
    <div
      className="flex-1 flex flex-col overflow-hidden relative"
      style={{
        background:
          "linear-gradient(to bottom, rgb(242,245,250), rgb(224,235,245))",
      }}
    >
      {/* Blurred store list behind notification */}
      <div className="px-4 pt-2 pb-1 opacity-40 blur-[1px]">
        <p className="text-[11px] text-black/40">Good morning</p>
        <h2 className="text-[22px] font-bold text-black tracking-tight">
          Hi, Sarah
        </h2>
      </div>

      <div className="flex-1 px-3 space-y-2 opacity-30 blur-[1px]">
        {[
          { name: "Whole Foods", letter: "W", from: "#34D399", to: "#059669", n: 5 },
          { name: "Target", letter: "T", from: "#F87171", to: "#DC2626", n: 3 },
          { name: "Costco", letter: "C", from: "#60A5FA", to: "#2563EB", n: 8 },
        ].map((s) => (
          <div
            key={s.name}
            className="flex items-center gap-3 px-3 py-2.5 rounded-2xl"
            style={{
              background: "rgba(255,255,255,0.55)",
              border: "1.5px solid rgba(255,255,255,0.5)",
            }}
          >
            <div
              className="w-[42px] h-[42px] rounded-full flex items-center justify-center"
              style={{ background: `linear-gradient(135deg, ${s.from}, ${s.to})` }}
            >
              <span className="text-white text-[16px] font-bold">{s.letter}</span>
            </div>
            <span className="text-[15px] text-black/90 flex-1">{s.name}</span>
            <div className="w-[22px] h-[22px] rounded-full bg-red-500 flex items-center justify-center">
              <span className="text-white text-[11px] font-semibold">{s.n}</span>
            </div>
          </div>
        ))}
      </div>

      {/* iOS notification banner */}
      <div className="absolute top-8 left-3 right-3 z-20">
        <div
          className="rounded-[20px] p-3 flex items-start gap-2.5"
          style={{
            background: "rgba(255,255,255,0.92)",
            backdropFilter: "blur(30px)",
            WebkitBackdropFilter: "blur(30px)",
            boxShadow: "0 8px 32px rgba(0,0,0,0.18), 0 2px 8px rgba(0,0,0,0.08)",
          }}
        >
          {/* App icon */}
          <img
            src="/allimIcon.png"
            alt="Allim"
            className="w-[34px] h-[34px] rounded-[8px] shrink-0 object-cover"
          />

          <div className="flex-1 min-w-0">
            <div className="flex items-center justify-between">
              <span className="text-[12px] font-semibold text-black/80">
                Allim
              </span>
              <span className="text-[10px] text-black/40">now</span>
            </div>
            <p className="text-[13px] font-semibold text-black mt-0.5 leading-tight">
              You're near Whole Foods
            </p>
            <p className="text-[11px] text-black/60 mt-0.5 leading-snug">
              You have 5 reminders waiting for you at this store.
            </p>
          </div>
        </div>
      </div>

      {/* Home indicator */}
      <div className="flex justify-center py-2">
        <div className="w-[100px] h-[4px] rounded-full bg-black/20" />
      </div>
    </div>
  );
}
