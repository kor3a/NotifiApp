import Rise from "./Rise";

const steps = [
  {
    n: "01",
    title: "Add your stores",
    description:
      "Search the grocery stores near you and pin the ones you actually shop at. Allim looks within a 5 km radius.",
  },
  {
    n: "02",
    title: "Fill your lists",
    description:
      "Add the groceries you need at each store. Smart Category groups them by aisle as you type.",
  },
  {
    n: "03",
    title: "Get on with your day",
    description:
      "Allim watches your location in the background. Nothing to open, nothing to remember.",
  },
  {
    n: "04",
    title: "Get the nudge",
    description:
      "You're near a store with groceries waiting. Tap the notification and the list is right there.",
  },
];

export default function HowItWorks() {
  return (
    <section id="how-it-works" className="border-b border-line bg-wash py-20 md:py-28">
      <div className="mx-auto max-w-6xl px-6">
        <Rise>
          <h2 className="eyebrow text-teal-deep">How it works</h2>
        </Rise>

        <ol className="mt-12 grid gap-px overflow-hidden border border-line-strong bg-line-strong sm:grid-cols-2 lg:grid-cols-4">
          {steps.map((step, index) => (
            <li key={step.n} className="bg-wash">
              <Rise delay={index * 90} className="flex h-full flex-col p-7 lg:p-8">
                <span className="figure text-[13px] text-teal">{step.n}</span>
                <h3 className="mt-9 text-[20px] font-bold tracking-[-0.02em] text-ink">
                  {step.title}
                </h3>
                <p className="mt-3 text-[15px] leading-relaxed text-on-wash/75">
                  {step.description}
                </p>
              </Rise>
            </li>
          ))}
        </ol>
      </div>
    </section>
  );
}
