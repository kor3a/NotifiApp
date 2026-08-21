import { MapPin, Users, Tag, ChefHat } from "lucide-react";
import FadeIn from "./FadeIn";

const features = [
  {
    n: "01",
    icon: MapPin,
    title: "Location-based alerts",
    description:
      "Save the stores you actually shop at. Allim watches for them in the background and pings you when you're close enough to stop in.",
  },
  {
    n: "02",
    icon: ChefHat,
    title: "Smart Recipe",
    description:
      "Ask for a recipe, get the steps, and push every ingredient onto the right store list in one tap. No retyping.",
  },
  {
    n: "03",
    icon: Users,
    title: "Shared lists",
    description:
      "Give a list to your partner, roommate, or family. Edits sync live, and you decide who can change things and who can only look.",
  },
  {
    n: "04",
    icon: Tag,
    title: "Smart Category",
    description:
      "Items sort themselves into aisle groups as they're added, so the list is already in walking order when you get there.",
  },
];

export default function Features() {
  return (
    <section id="features" className="bg-allim-dark py-24 md:py-28">
      <div className="mx-auto max-w-6xl px-6">
        {/* Asymmetric header: title left, context right */}
        <FadeIn>
          <div className="grid gap-6 border-b border-allim-line pb-12 md:grid-cols-12 md:gap-12">
            <div className="md:col-span-6">
              <p className="mb-4 text-[13px] font-medium uppercase tracking-[0.14em] text-allim-accent">
                What it does
              </p>
              <h2 className="text-4xl font-bold leading-[1.1] tracking-tight text-white sm:text-5xl">
                Four things, done
                <br className="hidden sm:block" /> properly.
              </h2>
            </div>
            <div className="md:col-span-5 md:col-start-8 md:pt-14">
              <p className="text-lg leading-relaxed text-allim-muted">
                Allim isn't trying to be your whole life. It keeps a list per
                store, tells you when you're near one, and lets other people
                add to it.
              </p>
            </div>
          </div>
        </FadeIn>

        {/* Hairline module grid — no floating cards */}
        <div className="mt-px grid gap-px border-b border-allim-line bg-allim-line sm:grid-cols-2">
          {features.map((feature, index) => (
            <FadeIn key={feature.title} delay={index * 90}>
              <div className="group h-full bg-allim-dark p-8 transition-colors duration-300 hover:bg-allim-surface md:p-10">
                <div className="mb-6 flex items-baseline gap-4">
                  <span className="font-display text-sm tabular-nums text-allim-faint">
                    {feature.n}
                  </span>
                  <feature.icon
                    size={20}
                    strokeWidth={1.75}
                    className="self-center text-allim-accent"
                  />
                </div>
                <h3 className="mb-3 text-xl font-semibold text-white">
                  {feature.title}
                </h3>
                <p className="max-w-md text-[15px] leading-relaxed text-allim-muted">
                  {feature.description}
                </p>
              </div>
            </FadeIn>
          ))}
        </div>
      </div>
    </section>
  );
}
