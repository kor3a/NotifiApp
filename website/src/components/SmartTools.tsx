import { Sparkles, Tag, Zap } from "lucide-react";
import PhoneFrame from "./PhoneFrame";
import SmartRecipeScreen from "./screens/SmartRecipeScreen";
import ReminderScreen from "./screens/ReminderScreen";
import FadeIn from "./FadeIn";

export default function SmartTools() {
  return (
    <section
      id="smart"
      className="relative bg-allim-dark py-32 overflow-hidden"
    >
      {/* Background accent */}
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[800px] h-[800px] bg-allim-purple/10 rounded-full blur-[60px]" />

      <div className="relative z-10 max-w-7xl mx-auto px-6">
        <FadeIn className="text-center mb-20">
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
        </FadeIn>

        {/* Smart Recipe */}
        <div className="grid lg:grid-cols-2 gap-12 items-center mb-24">
          {/* Phone mockup */}
          <FadeIn className="flex justify-center order-2 lg:order-1">
            <PhoneFrame>
              <SmartRecipeScreen />
            </PhoneFrame>
          </FadeIn>

          {/* Description */}
          <FadeIn delay={200} className="order-1 lg:order-2">
            <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-allim-purple to-pink-500 flex items-center justify-center mb-6 shadow-lg shadow-allim-purple/20">
              <span className="text-2xl">🍳</span>
            </div>
            <h3 className="text-3xl font-bold text-white mb-4">
              Smart Recipe
            </h3>
            <p className="text-allim-muted leading-relaxed text-lg mb-6">
              Ask for any recipe and Allim's AI assistant will provide
              step-by-step instructions. Add all the ingredients directly to
              your store lists with a single tap.
            </p>
            <ul className="space-y-3">
              {[
                "Get recipe ideas for any meal or occasion",
                "Step-by-step cooking instructions",
                "Ingredient substitution suggestions",
                "One-tap to add all ingredients to your store",
              ].map((item) => (
                <li key={item} className="flex items-start gap-3">
                  <div className="w-5 h-5 rounded-full bg-allim-purple/20 flex items-center justify-center shrink-0 mt-0.5">
                    <Sparkles size={10} className="text-allim-purple" />
                  </div>
                  <span className="text-allim-muted text-sm">{item}</span>
                </li>
              ))}
            </ul>
          </FadeIn>
        </div>

        {/* Smart Category */}
        <div className="grid lg:grid-cols-2 gap-12 items-center">
          {/* Description */}
          <FadeIn>
            <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-allim-blue to-cyan-400 flex items-center justify-center mb-6 shadow-lg shadow-allim-blue/20">
              <Tag size={28} className="text-white" />
            </div>
            <h3 className="text-3xl font-bold text-white mb-4">
              Smart Category
            </h3>
            <p className="text-allim-muted leading-relaxed text-lg mb-6">
              Stop wasting time organizing your list. Allim's AI automatically
              categorizes every item you add into store aisle categories, so
              your trip is planned before you arrive.
            </p>
            <ul className="space-y-3">
              {[
                "Automatic aisle-based categorization",
                "Works when adding items or importing recipes",
                "Per-store toggle in settings",
                "Items neatly grouped for faster shopping",
              ].map((item) => (
                <li key={item} className="flex items-start gap-3">
                  <div className="w-5 h-5 rounded-full bg-allim-blue/20 flex items-center justify-center shrink-0 mt-0.5">
                    <Zap size={10} className="text-allim-blue" />
                  </div>
                  <span className="text-allim-muted text-sm">{item}</span>
                </li>
              ))}
            </ul>
          </FadeIn>

          {/* Phone mockup */}
          <FadeIn delay={200} className="flex justify-center">
            <PhoneFrame>
              <ReminderScreen />
            </PhoneFrame>
          </FadeIn>
        </div>
      </div>
    </section>
  );
}
