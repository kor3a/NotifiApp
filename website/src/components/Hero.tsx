import { MapPin, ShoppingCart } from "lucide-react";
import HeroBackground from "./HeroBackground";
import { APP_STORE_URL } from "../constants/links";

export default function Hero() {
  return (
    <section className="relative min-h-screen flex items-center justify-center overflow-hidden bg-allim-dark pt-16">
      <HeroBackground />

      <div className="relative z-10 mx-auto w-full max-w-7xl px-6 py-24">
        <div className="max-w-2xl text-center lg:max-w-xl lg:text-left">
          {/* Badge */}
          <div className="inline-flex items-center gap-2 mb-8">
            <MapPin size={15} className="text-allim-accent" />
            <span className="text-[13px] font-medium uppercase tracking-[0.14em] text-allim-accent">
              Proximity reminders for real errands
            </span>
          </div>

          {/* Headline */}
          <h1 className="text-5xl sm:text-6xl lg:text-7xl font-bold text-white leading-tight tracking-tight">
            Never forget your{" "}
            <span className="text-allim-accent">lists</span> again
          </h1>

          {/* Subheadline */}
          <p
            className="mt-6 text-lg sm:text-xl text-white/95 max-w-xl mx-auto lg:mx-0 leading-relaxed"
            style={{ textShadow: "0 1px 3px rgba(0,0,0,0.55), 0 0 18px rgba(0,0,0,0.35)" }}
          >
            Your Geolist uses smart proximity reminders to alert you the moment
            you're near your favorite stores, so you never miss a shopping
            trip. Collaborate with family and friends, and let smart AI organize
            your lists.
          </p>

          {/* CTA Buttons */}
          <div className="mt-10 flex flex-col sm:flex-row items-center lg:items-start justify-center lg:justify-start gap-4">
            <a
              href={APP_STORE_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-2 px-8 py-4 rounded-xl bg-allim-accent text-allim-dark font-semibold text-lg hover:bg-white transition-colors"
            >
              <svg
                className="w-6 h-6"
                viewBox="0 0 24 24"
                fill="currentColor"
              >
                <path d="M18.71 19.5C17.88 20.74 17 21.95 15.66 21.97C14.32 21.99 13.89 21.18 12.37 21.18C10.84 21.18 10.37 21.95 9.09997 21.99C7.78997 22.03 6.79997 20.68 5.95997 19.47C4.24997 17 2.93997 12.45 4.69997 9.39C5.56997 7.87 7.12997 6.91 8.81997 6.88C10.1 6.86 11.32 7.75 12.11 7.75C12.89 7.75 14.37 6.68 15.92 6.84C16.57 6.87 18.39 7.1 19.56 8.82C19.47 8.88 17.39 10.1 17.41 12.63C17.44 15.65 20.06 16.66 20.09 16.67C20.06 16.74 19.67 18.11 18.71 19.5ZM13 3.5C13.73 2.67 14.94 2.04 15.94 2C16.07 3.17 15.6 4.35 14.9 5.19C14.21 6.04 13.07 6.7 11.95 6.61C11.8 5.46 12.36 4.26 13 3.5Z" />
              </svg>
              Download for iOS
            </a>
            <a
              href="#features"
              className="inline-flex items-center gap-2 px-8 py-4 rounded-xl border border-white/30 bg-black/20 text-white font-semibold text-lg backdrop-blur-sm hover:bg-black/40 transition-colors"
            >
              <ShoppingCart size={20} />
              See Features
            </a>
          </div>
        </div>
      </div>
    </section>
  );
}
