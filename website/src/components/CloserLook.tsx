import type { ReactNode } from "react";
import PhoneFrame from "./PhoneFrame";
import Rise from "./Rise";
import ReminderScreen from "./screens/ReminderScreen";
import ShareScreen from "./screens/ShareScreen";
import SmartRecipeScreen from "./screens/SmartRecipeScreen";

type Row = {
  id: string;
  label: string;
  title: string;
  lead: string;
  points: { title: string; desc: string; dot: string }[];
  screen: ReactNode;
};

const rows: Row[] = [
  {
    id: "sharing",
    label: "Sharing",
    title: "Shop together, even apart",
    lead: "Hand a grocery list to anyone — partner, roommates, family. Everyone sees the same list, and you decide who can change it.",
    points: [
      {
        title: "Can edit",
        desc: "Add groceries, check things off, and every change syncs both ways.",
        dot: "bg-dairy",
      },
      {
        title: "View only",
        desc: "Let someone see what you need without handing over the keys.",
        dot: "bg-household",
      },
      {
        title: "“On my way” alerts",
        desc: "When a sharer heads to the store, everyone gets a chance to add one more thing.",
        dot: "bg-snacks",
      },
    ],
    screen: <ShareScreen />,
  },
  {
    id: "recipe",
    label: "Smart Recipe",
    title: "From “what's for dinner” to a full list",
    lead: "Ask for any recipe and Allim writes out the steps, then drops every ingredient onto the grocery list for the store you buy it at.",
    points: [
      {
        title: "Any meal, any occasion",
        desc: "Ask in plain language and get a meal you can actually shop for.",
        dot: "bg-meat",
      },
      {
        title: "Steps and substitutions",
        desc: "Full instructions, plus swaps when you're missing something.",
        dot: "bg-bakery",
      },
      {
        title: "One tap to the list",
        desc: "Every ingredient lands on the grocery list for the store you'd buy it from.",
        dot: "bg-pantry",
      },
    ],
    screen: <SmartRecipeScreen />,
  },
  {
    id: "category",
    label: "Smart Category",
    title: "Your grocery list sorts itself",
    lead: "Groceries get grouped into aisle categories the moment they're added — whether you typed them in or pulled them from a recipe.",
    points: [
      {
        title: "Aisle-based grouping",
        desc: "Produce with produce, dairy with dairy. No dragging rows around.",
        dot: "bg-produce",
      },
      {
        title: "Works on imports too",
        desc: "Recipe ingredients get filed the same way as anything you type.",
        dot: "bg-frozen",
      },
      {
        title: "Per-store toggle",
        desc: "Turn it off for the shop where you already know the layout.",
        dot: "bg-beverages",
      },
    ],
    screen: <ReminderScreen />,
  },
];

export default function CloserLook() {
  return (
    <section id="capabilities" className="border-b border-line bg-canvas py-20 md:py-28">
      <div className="mx-auto max-w-6xl px-6">
        <Rise>
          <h2 className="eyebrow border-b border-line pb-8 text-teal">A closer look</h2>
        </Rise>

        <div className="divide-y divide-line">
          {rows.map((row, index) => {
            const flipped = index % 2 === 1;
            return (
              <div key={row.id} className="py-16 md:py-20">
                <div className="grid items-center gap-12 lg:grid-cols-12 lg:gap-16">
                  <Rise
                    className={`lg:col-span-6 ${flipped ? "lg:order-2 lg:col-start-7" : ""}`}
                  >
                    <div className="flex items-baseline gap-4">
                      <span className="figure text-[13px] text-ink-3">
                        {String(index + 1).padStart(2, "0")}
                      </span>
                      <span className="eyebrow text-ink-3">{row.label}</span>
                    </div>

                    <h3 className="display mt-5 max-w-md text-[clamp(1.8rem,4vw,2.6rem)] text-ink">
                      {row.title}
                    </h3>
                    <p className="mt-5 max-w-md text-[17px] leading-relaxed text-ink-2">
                      {row.lead}
                    </p>

                    <dl className="mt-9 space-y-6">
                      {row.points.map((point) => (
                        <div key={point.title} className="border-l-2 border-line pl-5">
                          <dt className="flex items-center gap-2.5 text-[15px] font-semibold text-ink">
                            <span
                              className={`h-[7px] w-[7px] shrink-0 rounded-full ${point.dot}`}
                              aria-hidden="true"
                            />
                            {point.title}
                          </dt>
                          <dd className="mt-1.5 max-w-sm text-[15px] leading-relaxed text-ink-2">
                            {point.desc}
                          </dd>
                        </div>
                      ))}
                    </dl>
                  </Rise>

                  <Rise
                    delay={140}
                    className={`flex justify-center lg:col-span-5 ${
                      flipped ? "lg:order-1 lg:col-start-1" : "lg:col-start-8"
                    }`}
                  >
                    <PhoneFrame>{row.screen}</PhoneFrame>
                  </Rise>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </section>
  );
}
