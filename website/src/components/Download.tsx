import { Sparkles, Shield, ChefHat, Tag } from "lucide-react";

export default function Download() {
  return (
    <section id="download" className="relative bg-allim-dark py-32 overflow-hidden">
      <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[1000px] h-[600px] bg-gradient-to-b from-allim-purple/15 via-allim-blue/10 to-transparent rounded-full blur-[120px]" />

      <div className="relative z-10 max-w-4xl mx-auto px-6 text-center">
        <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-white/5 border border-white/10 mb-8">
          <Sparkles size={14} className="text-allim-purple" />
          <span className="text-sm text-allim-muted">
            Free on the App Store
          </span>
        </div>

        <h2 className="text-4xl sm:text-5xl lg:text-6xl font-bold text-white tracking-tight leading-tight">
          Start shopping{" "}
          <span className="bg-gradient-to-r from-allim-blue to-allim-purple bg-clip-text text-transparent">
            smarter
          </span>{" "}
          today
        </h2>

        <p className="mt-6 text-lg text-allim-muted max-w-xl mx-auto leading-relaxed">
          Download Allim for free and transform how you manage your shopping. Upgrade
          to Premium for just $0.99/month to unlock Smart Recipe, Smart Category,
          and an ad-free experience.
        </p>

        {/* Premium features */}
        <div className="mt-10 flex flex-wrap items-center justify-center gap-4">
          {[
            { icon: ChefHat, label: "Smart Recipe" },
            { icon: Tag, label: "Smart Category" },
            { icon: Shield, label: "Ad-Free Experience" },
          ].map((item) => (
            <div
              key={item.label}
              className="flex items-center gap-2 px-4 py-2 rounded-full bg-white/[0.04] border border-white/[0.08]"
            >
              <item.icon size={16} className="text-allim-purple" />
              <span className="text-white text-sm">{item.label}</span>
            </div>
          ))}
        </div>

        {/* Download button */}
        <div className="mt-12">
          <a
            href="https://apps.apple.com/us/app/allim-smart-shopping-list/id6758680783"
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-3 px-8 py-4 rounded-2xl bg-white text-black font-semibold text-lg hover:bg-gray-100 transition-colors shadow-2xl shadow-white/10"
          >
            <svg
              className="w-7 h-7"
              viewBox="0 0 24 24"
              fill="currentColor"
            >
              <path d="M18.71 19.5C17.88 20.74 17 21.95 15.66 21.97C14.32 21.99 13.89 21.18 12.37 21.18C10.84 21.18 10.37 21.95 9.09997 21.99C7.78997 22.03 6.79997 20.68 5.95997 19.47C4.24997 17 2.93997 12.45 4.69997 9.39C5.56997 7.87 7.12997 6.91 8.81997 6.88C10.1 6.86 11.32 7.75 12.11 7.75C12.89 7.75 14.37 6.68 15.92 6.84C16.57 6.87 18.39 7.1 19.56 8.82C19.47 8.88 17.39 10.1 17.41 12.63C17.44 15.65 20.06 16.66 20.09 16.67C20.06 16.74 19.67 18.11 18.71 19.5ZM13 3.5C13.73 2.67 14.94 2.04 15.94 2C16.07 3.17 15.6 4.35 14.9 5.19C14.21 6.04 13.07 6.7 11.95 6.61C11.8 5.46 12.36 4.26 13 3.5Z" />
            </svg>
            Download on the App Store
          </a>
          <p className="mt-4 text-sm text-allim-muted">
            Requires iOS 17.0 or later. Free with optional Premium upgrade.
          </p>
        </div>
      </div>
    </section>
  );
}
