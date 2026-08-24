import {
  Eye,
  ListPlus,
  MessageCircle,
  Pencil,
  Replace,
  Sparkles,
  Tag,
  Zap,
} from "lucide-react";
import type { ReactNode } from "react";
import PhoneFrame from "./PhoneFrame";
import ShareScreen from "./screens/ShareScreen";
import SmartRecipeScreen from "./screens/SmartRecipeScreen";
import ReminderScreen from "./screens/ReminderScreen";
import FadeIn from "./FadeIn";

type Row = {
  id: string;
  label: string;
  title: string;
  lead: string;
  points: { icon: typeof Eye; title: string; desc: string }[];
  screen: ReactNode;
  phoneProps?: Record<string, unknown>;
};

const rows: Row[] = [
  {
    id: "sharing",
    label: "Sharing",
    title: "Shop together, even apart",
    lead: "Hand a grocery list to anyone — partner, roommates, family. Everyone sees the same list, and you decide who can change it.",
    points: [
      {
        icon: Pencil,
        title: "Can edit",
        desc: "Add groceries, check things off, and every change syncs both ways.",
      },
      {
        icon: Eye,
        title: "View only",
        desc: "Let someone see what you need without handing over the keys.",
      },
      {
        icon: MessageCircle,
        title: "“On my way” alerts",
        desc: "When a sharer heads to the store, everyone gets a chance to add one more thing.",
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
        icon: Sparkles,
        title: "Any meal, any occasion",
        desc: "Ask in plain language and get a meal you can actually shop for.",
      },
      {
        icon: Replace,
        title: "Steps and substitutions",
        desc: "Full instructions, plus swaps when you're missing something.",
      },
      {
        icon: ListPlus,
        title: "One tap to the list",
        desc: "Every ingredient lands on the grocery list for the store you'd buy it from.",
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
        icon: Tag,
        title: "Aisle-based grouping",
        desc: "Produce with produce, dairy with dairy. No dragging rows around.",
      },
      {
        icon: Zap,
        title: "Works on imports too",
        desc: "Recipe ingredients get filed the same way as anything you type.",
      },
      {
        icon: Zap,
        title: "Per-store toggle",
        desc: "Turn it off for the shop where you already know the layout.",
      },
    ],
    screen: <ReminderScreen />,
  },
];

export default function CloserLook() {
  return (
    <section id="capabilities" className="bg-allim-dark py-24 md:py-28">
      <div className="mx-auto max-w-6xl px-6">
        <FadeIn>
          <div className="border-b border-allim-line pb-12">
            <h2 className="text-2xl font-semibold uppercase tracking-[0.08em] text-allim-accent sm:text-3xl">
              A closer look
            </h2>
          </div>
        </FadeIn>

        <div className="divide-y divide-allim-line">
          {rows.map((row, index) => (
            <div key={row.id} className="py-16 md:py-20">
              <div className="grid items-center gap-12 lg:grid-cols-12 lg:gap-16">
                {/* Copy — alternates side on large screens */}
                <FadeIn
                  className={`lg:col-span-6 ${
                    index % 2 === 1 ? "lg:order-2 lg:col-start-7" : ""
                  }`}
                >
                  <div className="flex items-baseline gap-4">
                    <span className="font-display text-sm tabular-nums text-allim-faint">
                      {String(index + 1).padStart(2, "0")}
                    </span>
                    <span className="text-[13px] font-medium uppercase tracking-[0.14em] text-allim-muted">
                      {row.label}
                    </span>
                  </div>
                  <h3 className="mt-4 max-w-md text-3xl font-bold leading-tight tracking-tight text-white">
                    {row.title}
                  </h3>
                  <p className="mt-5 max-w-md text-lg leading-relaxed text-allim-muted">
                    {row.lead}
                  </p>

                  <dl className="mt-9 space-y-6 border-l border-allim-line pl-6">
                    {row.points.map((point) => (
                      <div key={point.title}>
                        <dt className="flex items-center gap-2.5 font-medium text-white">
                          <point.icon
                            size={15}
                            strokeWidth={2}
                            className="text-allim-accent"
                          />
                          {point.title}
                        </dt>
                        <dd className="mt-1.5 max-w-sm text-[15px] leading-relaxed text-allim-muted">
                          {point.desc}
                        </dd>
                      </div>
                    ))}
                  </dl>
                </FadeIn>

                {/* Phone */}
                <FadeIn
                  delay={160}
                  className={`flex justify-center lg:col-span-5 ${
                    index % 2 === 1 ? "lg:order-1 lg:col-start-1" : "lg:col-start-8"
                  }`}
                >
                  <PhoneFrame {...row.phoneProps}>{row.screen}</PhoneFrame>
                </FadeIn>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
