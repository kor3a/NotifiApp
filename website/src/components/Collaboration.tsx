import { Users, Eye, Pencil, MessageCircle } from "lucide-react";
import PhoneFrame from "./PhoneFrame";
import FadeIn from "./FadeIn";

export function ShareScreen() {
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
          <div
            className="w-[36px] h-[36px] rounded-full flex items-center justify-center shrink-0"
            style={{ background: "linear-gradient(135deg, #34D399, #059669)" }}
          >
            <span className="text-white text-[14px] font-bold">W</span>
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

export default function Collaboration() {
  return (
    <section className="relative bg-allim-dark py-32 overflow-hidden">
      <div className="absolute bottom-0 left-0 w-[600px] h-[600px] bg-pink-500/5 rounded-full blur-[60px]" />

      <div className="relative z-10 max-w-7xl mx-auto px-6">
        <div className="grid lg:grid-cols-2 gap-16 items-center">
          {/* Left: content */}
          <FadeIn>
            <span className="inline-flex items-center gap-1.5 px-4 py-1.5 rounded-full bg-pink-500/10 border border-pink-500/20 text-pink-400 text-sm font-medium mb-4">
              <Users size={14} />
              Collaboration
            </span>
            <h2 className="text-4xl sm:text-5xl font-bold text-white tracking-tight leading-tight">
              Shop together,{" "}
              <span className="bg-gradient-to-r from-pink-500 to-rose-400 bg-clip-text text-transparent">
                even apart
              </span>
            </h2>
            <p className="mt-6 text-lg text-allim-muted leading-relaxed">
              Share your store lists with anyone — your partner, roommates, or
              family. Everyone stays in sync with real-time updates, and you can
              choose who gets to edit.
            </p>

            <div className="mt-8 space-y-4">
              {[
                {
                  icon: Pencil,
                  iconClass: "text-pink-400",
                  bgClass: "from-pink-500/20 to-rose-500/20",
                  title: "Can Edit",
                  desc: "Full ownership — add items, check things off, and changes sync between both users automatically.",
                },
                {
                  icon: Eye,
                  iconClass: "text-violet-400",
                  bgClass: "from-violet-500/20 to-purple-500/20",
                  title: "View Only",
                  desc: "Let someone see what you need without giving them edit access. Great for quick visibility.",
                },
                {
                  icon: MessageCircle,
                  iconClass: "text-amber-400",
                  bgClass: "from-amber-500/20 to-orange-500/20",
                  title: '"On My Way" Alerts',
                  desc: "Get notified when someone you share with is heading to the store, so you can add last-minute items.",
                },
              ].map((item, i) => (
                <FadeIn key={item.title} delay={200 + i * 120} className="flex items-start gap-4">
                  <div className={`w-10 h-10 rounded-xl bg-gradient-to-br ${item.bgClass} flex items-center justify-center shrink-0`}>
                    <item.icon size={18} className={item.iconClass} />
                  </div>
                  <div>
                    <h4 className="text-white font-medium">{item.title}</h4>
                    <p className="text-sm text-allim-muted mt-1">{item.desc}</p>
                  </div>
                </FadeIn>
              ))}
            </div>
          </FadeIn>

          {/* Right: phone mockup */}
          <FadeIn delay={200} className="flex justify-center">
            <PhoneFrame>
              <ShareScreen />
            </PhoneFrame>
          </FadeIn>
        </div>
      </div>
    </section>
  );
}
