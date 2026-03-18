import { MapPin, ShoppingCart } from "lucide-react";

export default function Hero() {
  return (
    <section className="relative min-h-screen flex items-center justify-center overflow-hidden bg-allim-dark pt-16">
      {/* Background gradient orbs */}
      <div className="absolute top-1/4 -left-32 w-96 h-96 bg-allim-blue/20 rounded-full blur-[128px]" />
      <div className="absolute bottom-1/4 -right-32 w-96 h-96 bg-allim-purple/20 rounded-full blur-[128px]" />

      <div className="relative z-10 max-w-7xl mx-auto px-6 py-24 text-center">
        {/* Badge */}
        <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-white/5 border border-white/10 mb-8">
          <MapPin size={14} className="text-allim-blue" />
          <span className="text-sm text-allim-muted">
            Location-aware shopping, reimagined
          </span>
        </div>

        {/* Headline */}
        <h1 className="text-5xl sm:text-6xl lg:text-7xl font-bold text-white leading-tight tracking-tight max-w-4xl mx-auto">
          Never forget your{" "}
          <span className="bg-gradient-to-r from-allim-blue to-allim-purple bg-clip-text text-transparent">
            groceries
          </span>{" "}
          again
        </h1>

        {/* Subheadline */}
        <p className="mt-6 text-lg sm:text-xl text-allim-muted max-w-2xl mx-auto leading-relaxed">
          Allim alerts you when you're near your favorite stores so you never
          miss a shopping trip. Collaborate with family and friends, and let
          smart AI organize your lists.
        </p>

        {/* CTA Buttons */}
        <div className="mt-10 flex flex-col sm:flex-row items-center justify-center gap-4">
          <a
            href="#download"
            className="inline-flex items-center gap-2 px-8 py-4 rounded-2xl bg-gradient-to-r from-allim-blue to-allim-purple text-white font-semibold text-lg hover:opacity-90 transition-opacity shadow-lg shadow-allim-purple/25"
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
            className="inline-flex items-center gap-2 px-8 py-4 rounded-2xl border border-white/10 text-white font-semibold text-lg hover:bg-white/5 transition-colors"
          >
            <ShoppingCart size={20} />
            See Features
          </a>
        </div>

        {/* Phone mockup */}
        <div className="mt-20 relative mx-auto max-w-xs">
          <div className="relative w-72 h-[580px] mx-auto">
            {/* Phone frame */}
            <div className="absolute inset-0 rounded-[3rem] bg-gradient-to-b from-gray-800 to-gray-900 shadow-2xl shadow-black/50 p-2">
              <div className="w-full h-full rounded-[2.5rem] bg-gradient-to-b from-[#1a1535] to-[#0f0d1a] overflow-hidden flex flex-col">
                {/* Status bar */}
                <div className="flex justify-between items-center px-6 pt-4 pb-2">
                  <span className="text-white/60 text-xs">9:41</span>
                  <div className="w-20 h-5 bg-black rounded-full" />
                  <div className="flex gap-1">
                    <div className="w-4 h-2.5 rounded-sm bg-white/60" />
                  </div>
                </div>

                {/* App content mockup */}
                <div className="flex-1 px-4 py-2 flex flex-col gap-3">
                  <div className="text-left">
                    <h3 className="text-white font-bold text-lg">My Stores</h3>
                  </div>

                  {/* Store cards */}
                  {[
                    {
                      name: "Whole Foods",
                      items: 5,
                      color: "from-green-500/20 to-green-600/10",
                      icon: "🥬",
                      alert: true,
                    },
                    {
                      name: "Target",
                      items: 3,
                      color: "from-red-500/20 to-red-600/10",
                      icon: "🎯",
                      alert: false,
                    },
                    {
                      name: "Costco",
                      items: 8,
                      color: "from-blue-500/20 to-blue-600/10",
                      icon: "📦",
                      alert: false,
                    },
                    {
                      name: "Trader Joe's",
                      items: 2,
                      color: "from-orange-500/20 to-orange-600/10",
                      icon: "🌻",
                      alert: false,
                    },
                  ].map((store) => (
                    <div
                      key={store.name}
                      className={`bg-gradient-to-r ${store.color} rounded-2xl p-3.5 flex items-center gap-3 border border-white/5`}
                    >
                      <div className="w-10 h-10 rounded-xl bg-white/10 flex items-center justify-center text-lg">
                        {store.icon}
                      </div>
                      <div className="flex-1 text-left">
                        <p className="text-white text-sm font-medium">
                          {store.name}
                        </p>
                        <p className="text-white/50 text-xs">
                          {store.items} items
                        </p>
                      </div>
                      {store.alert && (
                        <div className="px-2 py-0.5 rounded-full bg-allim-blue/30 text-allim-blue text-[10px] font-medium">
                          Nearby
                        </div>
                      )}
                    </div>
                  ))}

                  {/* Notification overlay */}
                  <div className="mt-auto mb-2 bg-white/10 backdrop-blur-md rounded-2xl p-3 border border-white/10">
                    <div className="flex items-start gap-2">
                      <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-allim-blue to-allim-purple flex items-center justify-center shrink-0 mt-0.5">
                        <MapPin size={14} className="text-white" />
                      </div>
                      <div className="text-left">
                        <p className="text-white text-xs font-semibold">
                          You're near Whole Foods
                        </p>
                        <p className="text-white/60 text-[10px] mt-0.5">
                          You have 5 reminders waiting for you at this store.
                        </p>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
