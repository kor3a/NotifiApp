import { MapPin, Users, Bell, Share2 } from "lucide-react";
import PhoneFrame from "./PhoneFrame";
import NotificationScreen from "./screens/NotificationScreen";
import { useInView } from "../hooks/useInView";

const features = [
  {
    icon: MapPin,
    title: "Location-Based Alerts",
    description:
      "Get notified automatically when you're near one of your saved stores. Allim uses geofencing to remind you about your shopping list — so you never drive past the store again.",
    gradient: "from-blue-500 to-cyan-400",
  },
  {
    icon: Bell,
    title: "Smart Notifications",
    description:
      "Receive timely, non-intrusive alerts when you're within range of a store with pending items. Works in the background and even supports CarPlay for hands-free reminders.",
    gradient: "from-violet-500 to-purple-400",
  },
  {
    icon: Users,
    title: "Family & Friends Collaboration",
    description:
      "Share your store lists with family and friends. Collaborate in real-time — they can add items, check things off, and even get notified when someone is heading to the store.",
    gradient: "from-pink-500 to-rose-400",
  },
  {
    icon: Share2,
    title: "Shared Store Lists",
    description:
      "Assign edit or view-only permissions when sharing stores. Send share requests through in-app messages, and keep everyone in sync with real-time updates.",
    gradient: "from-amber-500 to-orange-400",
  },
];

type Feature = (typeof features)[number];

function FeatureCard({ feature, index }: { feature: Feature; index: number }) {
  const { ref, inView } = useInView<HTMLDivElement>();
  return (
    <div
      ref={ref}
      style={{ transitionDelay: `${index * 120}ms` }}
      className={`fade-in-up ${inView ? "is-visible" : ""}`}
    >
      <div className="group relative h-full rounded-3xl bg-white/[0.03] border border-white/[0.06] p-8 hover:bg-white/[0.06] transition-all duration-300">
        <div
          className={`w-14 h-14 rounded-2xl bg-gradient-to-br ${feature.gradient} flex items-center justify-center mb-6 shadow-lg`}
        >
          <feature.icon size={24} className="text-white" />
        </div>
        <h3 className="text-xl font-semibold text-white mb-3">{feature.title}</h3>
        <p className="text-allim-muted leading-relaxed text-sm">
          {feature.description}
        </p>
      </div>
    </div>
  );
}

export default function Features() {
  return (
    <section id="features" className="relative bg-allim-dark py-32">
      <div className="absolute inset-0 bg-gradient-to-b from-allim-dark via-allim-dark/95 to-allim-dark" />
      <div className="relative z-10 max-w-7xl mx-auto px-6">
        <div className="text-center mb-20">
          <span className="inline-block px-4 py-1.5 rounded-full bg-allim-blue/10 border border-allim-blue/20 text-allim-blue text-sm font-medium mb-4">
            Features
          </span>
          <h2 className="text-4xl sm:text-5xl font-bold text-white tracking-tight">
            Shopping made{" "}
            <span className="bg-gradient-to-r from-allim-blue to-allim-purple bg-clip-text text-transparent">
              effortless
            </span>
          </h2>
          <p className="mt-4 text-lg text-allim-muted max-w-2xl mx-auto">
            Allim combines location awareness with smart collaboration to
            transform how you manage your shopping.
          </p>
        </div>

        <div className="grid lg:grid-cols-[1fr_auto] gap-12 items-center">
          {/* Feature cards */}
          <div className="grid sm:grid-cols-2 gap-6">
            {features.map((feature, index) => (
              <FeatureCard key={feature.title} feature={feature} index={index} />
            ))}
          </div>

          {/* Phone showing notification */}
          <div className="hidden lg:flex justify-center">
            <PhoneFrame>
              <NotificationScreen />
            </PhoneFrame>
          </div>
        </div>
      </div>
    </section>
  );
}
