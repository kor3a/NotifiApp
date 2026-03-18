import { Store, ListChecks, MapPin, Bell } from "lucide-react";

const steps = [
  {
    step: "01",
    icon: Store,
    title: "Add Your Stores",
    description:
      "Search for your favorite grocery stores nearby and add them to your list. Allim uses Maps to find stores within a 5 km radius.",
  },
  {
    step: "02",
    icon: ListChecks,
    title: "Create Your List",
    description:
      "Add items you need to buy at each store. Smart Category will auto-organize them by aisle so your trip is efficient.",
  },
  {
    step: "03",
    icon: MapPin,
    title: "Go About Your Day",
    description:
      "Allim monitors your location in the background. When you're near a store with pending items, it knows.",
  },
  {
    step: "04",
    icon: Bell,
    title: "Get Reminded",
    description:
      "Receive a timely notification when you're close to the store. Tap to see your list and start shopping.",
  },
];

export default function HowItWorks() {
  return (
    <section id="how-it-works" className="relative bg-allim-dark py-32">
      <div className="max-w-7xl mx-auto px-6">
        <div className="text-center mb-20">
          <span className="inline-block px-4 py-1.5 rounded-full bg-cyan-500/10 border border-cyan-500/20 text-cyan-400 text-sm font-medium mb-4">
            How It Works
          </span>
          <h2 className="text-4xl sm:text-5xl font-bold text-white tracking-tight">
            Four simple{" "}
            <span className="bg-gradient-to-r from-cyan-400 to-allim-blue bg-clip-text text-transparent">
              steps
            </span>
          </h2>
          <p className="mt-4 text-lg text-allim-muted max-w-2xl mx-auto">
            Getting started with Allim takes less than a minute. Here's how it
            works.
          </p>
        </div>

        <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-6">
          {steps.map((item, index) => (
            <div key={item.step} className="relative group">
              {/* Connector line */}
              {index < steps.length - 1 && (
                <div className="hidden lg:block absolute top-10 left-[calc(50%+40px)] w-[calc(100%-40px)] h-px bg-gradient-to-r from-white/10 to-transparent" />
              )}
              <div className="relative rounded-3xl bg-white/[0.03] border border-white/[0.06] p-8 text-center hover:bg-white/[0.06] transition-all duration-300 h-full">
                <div className="relative mx-auto w-20 h-20 rounded-2xl bg-gradient-to-br from-allim-blue/20 to-allim-purple/20 flex items-center justify-center mb-6 group-hover:scale-105 transition-transform">
                  <item.icon size={32} className="text-allim-blue" />
                  <span className="absolute -top-2 -right-2 w-7 h-7 rounded-full bg-gradient-to-br from-allim-blue to-allim-purple text-white text-xs font-bold flex items-center justify-center">
                    {item.step}
                  </span>
                </div>
                <h3 className="text-lg font-semibold text-white mb-2">
                  {item.title}
                </h3>
                <p className="text-sm text-allim-muted leading-relaxed">
                  {item.description}
                </p>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
