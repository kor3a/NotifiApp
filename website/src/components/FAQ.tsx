import FadeIn from "./FadeIn";

const faqs = [
  {
    q: "What does “Allim” mean?",
    a: "Allim means “to inform” in Korean.",
  },
  {
    q: "Why does it need “Always” location access?",
    a: "A nearby alert has to fire while the app is closed — that's the point of it. Without background location permission, iOS won't hand Allim the crossing event, and the reminder never arrives.",
  },
  {
    q: "What's free and what's paid?",
    a: "Grocery lists, stores, location alerts, and sharing are free. Premium is $0.99/month and adds Smart Recipe, Smart Category, and removes ads.",
  },
  {
    q: "Do the people I share with need Premium?",
    a: "No. Sharing works on the free tier for everyone on the grocery list, in both “can edit” and “view only” modes.",
  },
  {
    q: "My alerts aren't firing. What now?",
    a: "Nine times out of ten it's permissions: location set to Always, Precise Location on, and notifications enabled for Allim. The support page walks through the rest.",
  },
];

export default function FAQ() {
  return (
    <section id="faq" className="bg-allim-dark py-24 md:py-28">
      <div className="mx-auto max-w-6xl px-6">
        <div className="grid gap-12 lg:grid-cols-12 lg:gap-16">
          <FadeIn className="lg:col-span-4">
            <h2 className="text-2xl font-semibold uppercase tracking-[0.08em] text-allim-accent sm:text-3xl">
              FAQs
            </h2>
          </FadeIn>

          <div className="lg:col-span-7 lg:col-start-6">
            <dl className="divide-y divide-allim-line border-y border-allim-line">
              {faqs.map((faq, index) => (
                <FadeIn key={faq.q} delay={index * 70}>
                  <div className="py-7">
                    <dt className="text-lg font-semibold text-white">
                      {faq.q}
                    </dt>
                    <dd className="mt-2.5 max-w-xl text-[15px] leading-relaxed text-allim-muted">
                      {faq.a}
                    </dd>
                  </div>
                </FadeIn>
              ))}
            </dl>
          </div>
        </div>
      </div>
    </section>
  );
}
