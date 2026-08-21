import { Store, ListChecks, MapPin, Bell } from "lucide-react";
import FadeIn from "./FadeIn";

const steps = [
  {
    step: "01",
    icon: Store,
    title: "Add your stores",
    description:
      "Search for the grocery stores near you and pin the ones you use. Allim looks within a 5 km radius.",
  },
  {
    step: "02",
    icon: ListChecks,
    title: "Fill the lists",
    description:
      "Add what you need at each store. Smart Category groups everything by aisle as you type.",
  },
  {
    step: "03",
    icon: MapPin,
    title: "Get on with your day",
    description:
      "Allim watches your location in the background. Nothing to open, nothing to remember.",
  },
  {
    step: "04",
    icon: Bell,
    title: "Get the nudge",
    description:
      "You're near a store with items waiting. Tap the notification and the list is right there.",
  },
];

export default function HowItWorks() {
  return (
    <section
      id="how-it-works"
      className="border-y border-allim-line bg-allim-surface py-24 md:py-28"
    >
      <div className="mx-auto max-w-6xl px-6">
        <FadeIn>
          <div className="flex flex-col gap-4 md:flex-row md:items-end md:justify-between">
            <div>
              <p className="mb-4 text-[13px] font-medium uppercase tracking-[0.14em] text-allim-accent">
                How it works
              </p>
              <h2 className="text-4xl font-bold tracking-tight text-white sm:text-5xl">
                Set it up once.
              </h2>
            </div>
            <p className="max-w-sm text-[15px] leading-relaxed text-allim-muted md:text-right">
              Roughly a minute of setup, then it runs quietly until it's
              actually useful.
            </p>
          </div>
        </FadeIn>

        {/* Timeline rail */}
        <div className="mt-16">
          <ol className="grid gap-12 sm:grid-cols-2 lg:grid-cols-4 lg:gap-8">
            {steps.map((item, index) => (
              <FadeIn key={item.step} delay={index * 110}>
                <li className="relative list-none">
                  <div className="mb-7 flex h-[52px] items-center">
                    <span className="flex h-[52px] w-[52px] shrink-0 items-center justify-center border border-allim-line-strong bg-allim-dark">
                      <item.icon
                        size={20}
                        strokeWidth={1.75}
                        className="text-allim-accent"
                      />
                    </span>
                    <span className="ml-4 font-display text-sm tabular-nums tracking-[0.1em] text-allim-faint">
                      {item.step}
                    </span>
                    {index < steps.length - 1 && (
                      <span
                        className="ml-4 -mr-8 hidden h-px flex-1 bg-allim-line-strong lg:block"
                        aria-hidden="true"
                      />
                    )}
                  </div>
                  <h3 className="mb-2 text-lg font-semibold text-white">
                    {item.title}
                  </h3>
                  <p className="max-w-xs text-[15px] leading-relaxed text-allim-muted">
                    {item.description}
                  </p>
                </li>
              </FadeIn>
            ))}
          </ol>
        </div>
      </div>
    </section>
  );
}
