import { Shield, ChefHat, Tag } from "lucide-react";
import FadeIn from "./FadeIn";
import { APP_STORE_URL } from "../constants/links";

const premium = [
  { icon: ChefHat, label: "Smart Recipe" },
  { icon: Tag, label: "Smart Category" },
  { icon: Shield, label: "No ads" },
];

export default function Download() {
  return (
    <section
      id="download"
      className="border-t border-allim-line bg-allim-surface py-24 md:py-28"
    >
      <div className="mx-auto max-w-6xl px-6">
        <div className="grid gap-12 lg:grid-cols-12 lg:items-end lg:gap-16">
          <FadeIn className="lg:col-span-7">
            <p className="mb-4 text-[13px] font-medium uppercase tracking-[0.14em] text-allim-accent">
              Free on the App Store
            </p>
            <h2 className="text-4xl font-bold leading-[1.05] tracking-tight text-white sm:text-5xl lg:text-6xl">
              Start shopping
              <br /> smarter today.
            </h2>
            <p className="mt-6 max-w-lg text-lg leading-relaxed text-allim-muted">
              Grocery lists, stores, location alerts, and sharing cost nothing. Premium
              is $0.99/month if you want the AI tools and an ad-free app.
            </p>
          </FadeIn>

          <FadeIn delay={150} className="lg:col-span-5">
            <a
              href={APP_STORE_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex w-full items-center justify-center gap-3 rounded-xl bg-allim-accent px-8 py-4 text-lg font-semibold text-allim-dark transition-colors hover:bg-white sm:w-auto"
            >
              <svg className="h-7 w-7" viewBox="0 0 24 24" fill="currentColor">
                <path d="M18.71 19.5C17.88 20.74 17 21.95 15.66 21.97C14.32 21.99 13.89 21.18 12.37 21.18C10.84 21.18 10.37 21.95 9.09997 21.99C7.78997 22.03 6.79997 20.68 5.95997 19.47C4.24997 17 2.93997 12.45 4.69997 9.39C5.56997 7.87 7.12997 6.91 8.81997 6.88C10.1 6.86 11.32 7.75 12.11 7.75C12.89 7.75 14.37 6.68 15.92 6.84C16.57 6.87 18.39 7.1 19.56 8.82C19.47 8.88 17.39 10.1 17.41 12.63C17.44 15.65 20.06 16.66 20.09 16.67C20.06 16.74 19.67 18.11 18.71 19.5ZM13 3.5C13.73 2.67 14.94 2.04 15.94 2C16.07 3.17 15.6 4.35 14.9 5.19C14.21 6.04 13.07 6.7 11.95 6.61C11.8 5.46 12.36 4.26 13 3.5Z" />
              </svg>
              Download on the App Store
            </a>
            <p className="mt-4 text-sm text-allim-faint">
              Requires iOS 17.0 or later.
            </p>

            <dl className="mt-10 space-y-3 border-t border-allim-line pt-6">
              <dt className="text-[13px] font-medium uppercase tracking-[0.14em] text-allim-muted">
                In Premium
              </dt>
              {premium.map((item) => (
                <dd
                  key={item.label}
                  className="flex items-center gap-3 text-[15px] text-white"
                >
                  <item.icon
                    size={16}
                    strokeWidth={1.75}
                    className="text-allim-accent"
                  />
                  {item.label}
                </dd>
              ))}
            </dl>
          </FadeIn>
        </div>
      </div>
    </section>
  );
}
