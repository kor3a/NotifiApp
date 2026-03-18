import { Star } from "lucide-react";

const testimonials = [
  {
    name: "Jessica R.",
    text: "I used to drive past the grocery store all the time and forget I needed milk. Allim literally solved that problem on day one. The location alerts are a game-changer.",
    stars: 5,
  },
  {
    name: "Marcus T.",
    text: "My wife and I share our Costco list in Allim. When she's near the store, she gets the alert and can grab everything. We've cut our shopping trips in half.",
    stars: 5,
  },
  {
    name: "Priya K.",
    text: "Smart Category is so satisfying — I just throw items into my list and they automatically sort by aisle. My grocery runs are way faster now.",
    stars: 5,
  },
];

export default function Testimonials() {
  return (
    <section className="relative bg-allim-dark py-32">
      <div className="max-w-7xl mx-auto px-6">
        <div className="text-center mb-16">
          <span className="inline-block px-4 py-1.5 rounded-full bg-amber-500/10 border border-amber-500/20 text-amber-400 text-sm font-medium mb-4">
            Loved by Shoppers
          </span>
          <h2 className="text-4xl sm:text-5xl font-bold text-white tracking-tight">
            What people are{" "}
            <span className="bg-gradient-to-r from-amber-400 to-orange-400 bg-clip-text text-transparent">
              saying
            </span>
          </h2>
        </div>

        <div className="grid md:grid-cols-3 gap-6">
          {testimonials.map((t) => (
            <div
              key={t.name}
              className="rounded-3xl bg-white/[0.03] border border-white/[0.06] p-8 hover:bg-white/[0.06] transition-all duration-300"
            >
              <div className="flex gap-0.5 mb-4">
                {Array.from({ length: t.stars }).map((_, i) => (
                  <Star
                    key={i}
                    size={16}
                    className="text-amber-400 fill-amber-400"
                  />
                ))}
              </div>
              <p className="text-allim-muted leading-relaxed mb-6">
                "{t.text}"
              </p>
              <p className="text-white font-medium text-sm">{t.name}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
