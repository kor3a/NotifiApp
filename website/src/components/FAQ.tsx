import FadeIn from "./FadeIn";
import { SUPPORT_EMAIL } from "../constants/links";

const faqs = [
  {
    q: "What does “Allim” mean?",
    a: "It's the Korean word for “alarm.” The whole app is one idea: an alarm that goes off because of where you are, not what time it is.",
  },
  {
    q: "Does it drain my battery?",
    a: "Allim uses iOS geofencing rather than continuously polling your GPS. The system wakes the app when you cross into a saved store's radius and it sleeps the rest of the time.",
  },
  {
    q: "Why does it need “Always” location access?",
    a: "A nearby alert has to fire while the app is closed — that's the point of it. Without background location permission, iOS won't hand Allim the crossing event, and the reminder never arrives.",
  },
  {
    q: "What's free and what's paid?",
    a: "Stores, lists, location alerts, and sharing are free. Premium is $0.99/month and adds Smart Recipe, Smart Category, and removes ads.",
  },
  {
    q: "Do the people I share with need Premium?",
    a: "No. Sharing works on the free tier for everyone on the list, in both “can edit” and “view only” modes.",
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
            <p className="mb-4 text-[13px] font-medium uppercase tracking-[0.14em] text-allim-accent">
              Questions
            </p>
            <h2 className="text-4xl font-bold leading-[1.1] tracking-tight text-white sm:text-5xl">
              Before you download.
            </h2>
            <p className="mt-6 max-w-xs text-[15px] leading-relaxed text-allim-muted">
              Anything not covered here, email{" "}
              <a
                href={`mailto:${SUPPORT_EMAIL}`}
                className="text-allim-accent underline underline-offset-4 hover:text-white"
              >
                {SUPPORT_EMAIL}
              </a>{" "}
              — replies usually land within a couple of days.
            </p>
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
