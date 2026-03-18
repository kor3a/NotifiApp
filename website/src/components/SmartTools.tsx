import { ChefHat, Sparkles, Tag, Zap } from "lucide-react";

export default function SmartTools() {
  return (
    <section id="smart" className="relative bg-allim-dark py-32 overflow-hidden">
      {/* Background accent */}
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[800px] h-[800px] bg-allim-purple/10 rounded-full blur-[200px]" />

      <div className="relative z-10 max-w-7xl mx-auto px-6">
        <div className="text-center mb-20">
          <span className="inline-flex items-center gap-1.5 px-4 py-1.5 rounded-full bg-allim-purple/10 border border-allim-purple/20 text-allim-purple text-sm font-medium mb-4">
            <Sparkles size={14} />
            AI-Powered
          </span>
          <h2 className="text-4xl sm:text-5xl font-bold text-white tracking-tight">
            Meet your{" "}
            <span className="bg-gradient-to-r from-allim-purple to-pink-500 bg-clip-text text-transparent">
              smart tools
            </span>
          </h2>
          <p className="mt-4 text-lg text-allim-muted max-w-2xl mx-auto">
            Powered by AI, Allim's smart features take the manual work out of
            meal planning and list organization.
          </p>
        </div>

        <div className="grid lg:grid-cols-2 gap-8">
          {/* Smart Recipe Card */}
          <div className="relative rounded-3xl bg-gradient-to-br from-allim-purple/10 to-pink-500/10 border border-allim-purple/20 p-8 lg:p-10 overflow-hidden">
            <div className="absolute top-0 right-0 w-48 h-48 bg-allim-purple/10 rounded-full blur-[80px]" />
            <div className="relative">
              <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-allim-purple to-pink-500 flex items-center justify-center mb-6 shadow-lg shadow-allim-purple/20">
                <ChefHat size={28} className="text-white" />
              </div>
              <h3 className="text-2xl font-bold text-white mb-3">
                Smart Recipe
              </h3>
              <p className="text-allim-muted leading-relaxed mb-8">
                Ask for any recipe and Allim's AI assistant will provide
                step-by-step instructions. The best part? Add all the
                ingredients directly to your store lists with a single tap.
              </p>

              {/* Recipe mockup */}
              <div className="bg-white/[0.05] rounded-2xl p-5 border border-white/[0.08]">
                <div className="flex items-start gap-3 mb-4">
                  <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-allim-purple to-pink-500 flex items-center justify-center shrink-0">
                    <Sparkles size={14} className="text-white" />
                  </div>
                  <div className="bg-white/[0.05] rounded-xl rounded-tl-none p-3 text-left">
                    <p className="text-white text-sm font-medium mb-2">
                      Quick Weeknight Pasta Dinner
                    </p>
                    <p className="text-allim-muted text-xs leading-relaxed">
                      Here's a simple garlic butter pasta recipe! Ready in 20
                      minutes with just a few ingredients...
                    </p>
                  </div>
                </div>
                <div className="flex gap-2">
                  <div className="flex-1 bg-allim-purple/20 rounded-xl px-3 py-2 text-center">
                    <p className="text-allim-purple text-xs font-medium">
                      Add 6 ingredients to store
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* Smart Category Card */}
          <div className="relative rounded-3xl bg-gradient-to-br from-allim-blue/10 to-cyan-500/10 border border-allim-blue/20 p-8 lg:p-10 overflow-hidden">
            <div className="absolute top-0 right-0 w-48 h-48 bg-allim-blue/10 rounded-full blur-[80px]" />
            <div className="relative">
              <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-allim-blue to-cyan-400 flex items-center justify-center mb-6 shadow-lg shadow-allim-blue/20">
                <Tag size={28} className="text-white" />
              </div>
              <h3 className="text-2xl font-bold text-white mb-3">
                Smart Category
              </h3>
              <p className="text-allim-muted leading-relaxed mb-8">
                Stop wasting time organizing your list. Allim's AI
                automatically categorizes every item you add into store aisle
                categories, so your trip is planned before you even arrive.
              </p>

              {/* Category mockup */}
              <div className="bg-white/[0.05] rounded-2xl p-5 border border-white/[0.08]">
                <div className="space-y-2.5">
                  {[
                    {
                      category: "Produce",
                      items: ["Bananas", "Spinach", "Avocados"],
                      color: "text-green-400 bg-green-400/10",
                    },
                    {
                      category: "Dairy",
                      items: ["Whole Milk", "Greek Yogurt"],
                      color: "text-blue-400 bg-blue-400/10",
                    },
                    {
                      category: "Bakery",
                      items: ["Sourdough Bread"],
                      color: "text-amber-400 bg-amber-400/10",
                    },
                  ].map((cat) => (
                    <div key={cat.category} className="flex items-center gap-3">
                      <span
                        className={`text-[10px] font-semibold px-2 py-0.5 rounded-md ${cat.color} uppercase tracking-wider shrink-0 w-16 text-center`}
                      >
                        {cat.category}
                      </span>
                      <div className="flex gap-1.5 flex-wrap">
                        {cat.items.map((item) => (
                          <span
                            key={item}
                            className="text-white/80 text-xs bg-white/[0.06] px-2.5 py-1 rounded-lg"
                          >
                            {item}
                          </span>
                        ))}
                      </div>
                    </div>
                  ))}
                </div>
                <div className="mt-4 flex items-center gap-2 text-allim-blue text-xs">
                  <Zap size={12} />
                  <span className="font-medium">
                    Auto-categorized by AI
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
