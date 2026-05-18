import { Bell } from "lucide-react";

const ROUTE_PATH =
  "M 56 256 L 56 188 Q 56 156 96 156 L 168 156 Q 200 156 200 116 L 200 72 Q 200 44 248 44 L 332 44";

/**
 * Hero background: a looping <video> overlaid on top of an animated SVG map.
 * Drop a file at `website/public/hero-map.mp4` and it covers the animation.
 * Until then (or if the video fails to load) the animated map shows through.
 */
export default function HeroBackground() {
  return (
    <div className="absolute inset-0 z-0 overflow-hidden bg-allim-dark">
      {/* Animated fallback / poster: map with navigation route + arrival toast */}
      <div className="absolute inset-0 animate-map-drift">
        <svg
          className="h-full w-full opacity-50"
          viewBox="0 0 400 300"
          preserveAspectRatio="xMidYMid slice"
          aria-hidden="true"
        >
          <defs>
            <linearGradient id="routeGradient" x1="0" y1="0" x2="1" y2="0">
              <stop offset="0%" stopColor="var(--color-allim-blue)" />
              <stop offset="100%" stopColor="var(--color-allim-purple)" />
            </linearGradient>
          </defs>

          {/* Map blocks */}
          <g stroke="#2A2740" strokeWidth="1" fill="#16142480">
            <rect x="20" y="30" width="90" height="70" rx="4" />
            <rect x="130" y="30" width="120" height="55" rx="4" />
            <rect x="270" y="30" width="110" height="80" rx="4" />
            <rect x="20" y="120" width="70" height="90" rx="4" />
            <rect x="110" y="105" width="110" height="70" rx="4" />
            <rect x="240" y="130" width="140" height="90" rx="4" />
            <rect x="20" y="230" width="160" height="55" rx="4" />
            <rect x="200" y="240" width="180" height="45" rx="4" />
          </g>

          {/* Road grid */}
          <g stroke="#211E36" strokeWidth="6" strokeLinecap="round">
            <line x1="56" y1="0" x2="56" y2="300" />
            <line x1="200" y1="0" x2="200" y2="300" />
            <line x1="332" y1="0" x2="332" y2="300" />
            <line x1="0" y1="44" x2="400" y2="44" />
            <line x1="0" y1="156" x2="400" y2="156" />
            <line x1="0" y1="256" x2="400" y2="256" />
          </g>

          {/* Navigation route */}
          <path
            d={ROUTE_PATH}
            fill="none"
            stroke="url(#routeGradient)"
            strokeWidth="5"
            strokeLinecap="round"
            strokeLinejoin="round"
            pathLength={100}
            className="animate-route-draw"
            style={{ filter: "drop-shadow(0 0 6px rgba(74,144,217,0.6))" }}
          />

          {/* Origin marker */}
          <circle cx="56" cy="256" r="6" fill="#fff" />
          <circle cx="56" cy="256" r="10" fill="none" stroke="#fff" strokeWidth="2" opacity="0.4" />

          {/* Moving navigation puck */}
          <g className="animate-route-puck">
            <circle r="11" fill="var(--color-allim-blue)" opacity="0.25" />
            <circle r="6" fill="#fff" />
            <circle r="3.5" fill="var(--color-allim-blue)" />
          </g>

          {/* Destination pin */}
          <g className="animate-route-pin">
            <path
              d="M 332 26 C 322 26 314 34 314 44 C 314 56 332 70 332 70 C 332 70 350 56 350 44 C 350 34 342 26 332 26 Z"
              fill="var(--color-allim-purple)"
            />
            <circle cx="332" cy="44" r="6" fill="#fff" />
          </g>
        </svg>

        {/* Arrival notification toast */}
        <div className="pointer-events-none absolute right-[8%] top-[14%] animate-arrival-toast">
          <div className="flex items-center gap-3 rounded-2xl border border-white/10 bg-allim-card/90 px-4 py-3 shadow-xl backdrop-blur-sm">
            <div className="flex h-9 w-9 items-center justify-center rounded-full bg-gradient-to-r from-allim-blue to-allim-purple">
              <Bell size={16} className="text-white" />
            </div>
            <div className="leading-tight">
              <p className="text-sm font-semibold text-white">You've arrived</p>
              <p className="text-xs text-allim-muted">
                Don't forget your shopping list
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* Looping background video (covers the animation once provided) */}
      <video
        className="absolute inset-0 h-full w-full object-cover"
        autoPlay
        loop
        muted
        playsInline
        preload="auto"
      >
        <source src="/hero-map.mp4" type="video/mp4" />
        <source src="/hero-map.webm" type="video/webm" />
      </video>

      {/* Readability overlays */}
      <div className="absolute inset-0 bg-allim-dark/70" />
      <div className="absolute top-1/4 -left-32 h-96 w-96 rounded-full bg-allim-blue/20 blur-[60px]" />
      <div className="absolute bottom-1/4 -right-32 h-96 w-96 rounded-full bg-allim-purple/20 blur-[60px]" />
    </div>
  );
}
