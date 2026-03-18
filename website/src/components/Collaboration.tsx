import { Users, Eye, Pencil, MessageCircle, ArrowRight } from "lucide-react";

export default function Collaboration() {
  return (
    <section className="relative bg-allim-dark py-32 overflow-hidden">
      <div className="absolute bottom-0 left-0 w-[600px] h-[600px] bg-pink-500/5 rounded-full blur-[200px]" />

      <div className="relative z-10 max-w-7xl mx-auto px-6">
        <div className="grid lg:grid-cols-2 gap-16 items-center">
          {/* Left: content */}
          <div>
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
              <div className="flex items-start gap-4">
                <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-pink-500/20 to-rose-500/20 flex items-center justify-center shrink-0">
                  <Pencil size={18} className="text-pink-400" />
                </div>
                <div>
                  <h4 className="text-white font-medium">Can Edit</h4>
                  <p className="text-sm text-allim-muted mt-1">
                    Full ownership — add items, check things off, and changes
                    sync between both users automatically.
                  </p>
                </div>
              </div>
              <div className="flex items-start gap-4">
                <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-violet-500/20 to-purple-500/20 flex items-center justify-center shrink-0">
                  <Eye size={18} className="text-violet-400" />
                </div>
                <div>
                  <h4 className="text-white font-medium">View Only</h4>
                  <p className="text-sm text-allim-muted mt-1">
                    Let someone see what you need without giving them edit
                    access. Great for quick visibility.
                  </p>
                </div>
              </div>
              <div className="flex items-start gap-4">
                <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-amber-500/20 to-orange-500/20 flex items-center justify-center shrink-0">
                  <MessageCircle size={18} className="text-amber-400" />
                </div>
                <div>
                  <h4 className="text-white font-medium">"On My Way" Alerts</h4>
                  <p className="text-sm text-allim-muted mt-1">
                    Get notified when someone you share with is heading to the
                    store, so you can add last-minute items.
                  </p>
                </div>
              </div>
            </div>
          </div>

          {/* Right: mockup */}
          <div className="relative flex justify-center">
            <div className="relative w-80">
              {/* Sharing mockup */}
              <div className="rounded-3xl bg-white/[0.03] border border-white/[0.06] p-6 space-y-4">
                <div className="flex items-center gap-3 mb-2">
                  <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-pink-500 to-rose-400 flex items-center justify-center">
                    <Users size={18} className="text-white" />
                  </div>
                  <div>
                    <h4 className="text-white font-medium text-sm">
                      Shared with
                    </h4>
                    <p className="text-allim-muted text-xs">Whole Foods Market</p>
                  </div>
                </div>

                {[
                  {
                    name: "Sarah M.",
                    role: "Can Edit",
                    avatar: "S",
                    color: "bg-pink-500",
                    status: "Active now",
                  },
                  {
                    name: "Dad",
                    role: "Can Edit",
                    avatar: "D",
                    color: "bg-allim-blue",
                    status: "On my way",
                  },
                  {
                    name: "Alex K.",
                    role: "View Only",
                    avatar: "A",
                    color: "bg-allim-purple",
                    status: "Last seen 2h ago",
                  },
                ].map((person) => (
                  <div
                    key={person.name}
                    className="flex items-center gap-3 bg-white/[0.04] rounded-xl p-3"
                  >
                    <div
                      className={`w-9 h-9 rounded-full ${person.color} flex items-center justify-center text-white text-sm font-medium`}
                    >
                      {person.avatar}
                    </div>
                    <div className="flex-1">
                      <p className="text-white text-sm font-medium">
                        {person.name}
                      </p>
                      <p className="text-allim-muted text-xs">{person.status}</p>
                    </div>
                    <span className="text-xs text-allim-muted bg-white/[0.06] px-2 py-0.5 rounded-md">
                      {person.role}
                    </span>
                  </div>
                ))}

                <button className="w-full flex items-center justify-center gap-2 py-3 rounded-xl bg-gradient-to-r from-pink-500/20 to-rose-500/20 text-pink-400 text-sm font-medium border border-pink-500/20 hover:bg-pink-500/30 transition-colors">
                  Invite more people
                  <ArrowRight size={14} />
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
