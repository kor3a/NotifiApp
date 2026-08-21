
export default function ShareScreen() {
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
        <span className="text-[13px] text-blue-500">Cancel</span>
        <span className="text-[15px] font-semibold text-black">
          Share Store
        </span>
        <div className="w-[40px]" />
      </div>

      <div className="flex-1 px-3 overflow-hidden space-y-2">
        {/* Store info card */}
        <div
          className="rounded-xl px-3 py-2.5 flex items-center gap-2.5"
          style={{
            background: "rgba(255,255,255,0.55)",
            backdropFilter: "blur(20px)",
            WebkitBackdropFilter: "blur(20px)",
            border: "1px solid rgba(0,0,0,0.08)",
          }}
        >
          <div className="w-[36px] h-[36px] rounded-xl flex items-center justify-center overflow-hidden bg-white shadow-[0_2px_6px_rgba(0,0,0,0.10)] shrink-0">
            <img
              src="/store-logos/whole-foods.svg"
              alt="Whole Foods"
              className="h-full w-full object-cover"
              draggable={false}
            />
          </div>
          <div>
            <p className="text-[13px] font-semibold text-black">Whole Foods</p>
            <p className="text-[10px] text-gray-500">All locations</p>
          </div>
        </div>

        {/* Shared with section */}
        <div>
          <p className="text-[10px] text-gray-500 font-semibold uppercase tracking-wider px-1 mb-1.5">
            Shared with
          </p>

          {[
            { name: "Sarah M.", perm: "Can Edit", color: "#EC4899", letter: "S", status: "Active now" },
            { name: "Dad", perm: "Can Edit", color: "#3B82F6", letter: "D", status: "On my way" },
            { name: "Alex K.", perm: "View Only", color: "#8B5CF6", letter: "A", status: "2h ago" },
          ].map((p) => (
            <div
              key={p.name}
              className="rounded-xl px-3 py-2 mb-1.5 flex items-center gap-2.5"
              style={{
                background: "rgba(255,255,255,0.55)",
                backdropFilter: "blur(20px)",
                WebkitBackdropFilter: "blur(20px)",
                border: "1px solid rgba(0,0,0,0.08)",
              }}
            >
              <div
                className="w-[34px] h-[34px] rounded-full flex items-center justify-center shrink-0"
                style={{ background: p.color }}
              >
                <span className="text-white text-[13px] font-semibold">
                  {p.letter}
                </span>
              </div>
              <div className="flex-1 min-w-0">
                <p className="text-[13px] font-medium text-black">{p.name}</p>
                <p className="text-[9px] text-gray-400">{p.status}</p>
              </div>
              <span
                className="text-[9px] font-medium px-2 py-0.5 rounded-md"
                style={{
                  background:
                    p.perm === "Can Edit"
                      ? "rgba(34,197,94,0.1)"
                      : "rgba(249,115,22,0.1)",
                  color: p.perm === "Can Edit" ? "#16A34A" : "#EA580C",
                }}
              >
                {p.perm}
              </span>
            </div>
          ))}
        </div>

        {/* Email input */}
        <div>
          <p className="text-[10px] text-gray-500 font-semibold uppercase tracking-wider px-1 mb-1.5">
            Invite someone
          </p>
          <div
            className="rounded-xl px-3 py-2"
            style={{
              background: "rgba(255,255,255,0.55)",
              border: "1px solid rgba(0,0,0,0.08)",
            }}
          >
            <span className="text-[12px] text-gray-400">
              Enter email address...
            </span>
          </div>
        </div>

        {/* Permission toggle */}
        <div className="flex items-center gap-1.5">
          <div className="flex-1 rounded-lg bg-blue-500 py-1.5 text-center">
            <span className="text-[10px] font-semibold text-white">
              Can Edit
            </span>
          </div>
          <div
            className="flex-1 rounded-lg py-1.5 text-center"
            style={{ background: "rgba(0,0,0,0.04)" }}
          >
            <span className="text-[10px] font-semibold text-gray-400">
              View Only
            </span>
          </div>
        </div>

        {/* Share button */}
        <div className="rounded-xl bg-blue-500 py-2.5 text-center mt-1">
          <span className="text-[13px] font-semibold text-white">
            Share Store
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
