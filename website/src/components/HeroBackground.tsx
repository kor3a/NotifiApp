import PhoneFrame from "./PhoneFrame";

const mapImage = "/apple-maps-reference.png";
const allimIcon = "/allimIcon.svg";

function RouteOverlay({
  className = "",
  compact = false,
}: {
  className?: string;
  compact?: boolean;
}) {
  const route = compact
    ? "M68 548 L178 548 Q214 548 240 522 L286 476 Q312 450 312 412 L312 314 Q312 278 338 252 L430 160"
    : "M455 505 L590 505 Q648 505 688 466 L742 414 Q778 380 778 326 L778 258 Q778 222 812 206 L662 206";
  const pin = compact ? "translate(430 160)" : "translate(662 206)";

  return (
    <svg
      className={`pointer-events-none absolute inset-0 h-full w-full ${className}`}
      viewBox="0 0 1200 786"
      aria-hidden="true"
    >
      <defs>
        <filter id={compact ? "phoneRouteGlow" : "heroRouteGlow"} x="-25%" y="-25%" width="150%" height="150%">
          <feDropShadow dx="0" dy="2" floodColor="#004b9e" floodOpacity="0.28" stdDeviation="3" />
        </filter>
        <filter id={compact ? "phoneMapPinShadow" : "heroMapPinShadow"} x="-60%" y="-60%" width="220%" height="220%">
          <feDropShadow dx="0" dy="8" floodColor="#2b3440" floodOpacity="0.35" stdDeviation="8" />
        </filter>
      </defs>

      <path
        d={route}
        fill="none"
        stroke="#ffffff"
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth={compact ? "19" : "25"}
      />
      <path
        className={compact ? "hero-phone-route" : "hero-route-line"}
        d={route}
        fill="none"
        filter={`url(#${compact ? "phoneRouteGlow" : "heroRouteGlow"})`}
        stroke="#147EFB"
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth={compact ? "12" : "16"}
      />

      <g className={compact ? "hero-phone-dot" : "hero-driver-dot"}>
        <circle r={compact ? "16" : "24"} fill="#147EFB" opacity="0.2" />
        <circle r={compact ? "9" : "12"} fill="#ffffff" />
        <circle r={compact ? "5" : "7"} fill="#147EFB" />
      </g>

      <g
        className={compact ? undefined : "hero-destination-pin"}
        filter={`url(#${compact ? "phoneMapPinShadow" : "heroMapPinShadow"})`}
        transform={pin}
      >
        <path
          d="M0 -70 C-34 -70 -60 -44 -60 -11 C-60 33 0 86 0 86 C0 86 60 33 60 -11 C60 -44 34 -70 0 -70Z"
          fill="#FF3B30"
        />
        <circle cx="0" cy="-10" r="23" fill="#ffffff" opacity="0.92" />
        <circle cx="0" cy="-10" r="10" fill="#FF3B30" />
      </g>
    </svg>
  );
}

function AllimNotification() {
  return (
    <div className="hero-phone-notification rounded-2xl border border-black/10 bg-white/92 p-3 shadow-2xl shadow-black/18 backdrop-blur-md">
      <div className="flex items-start gap-3">
        <div className="flex h-9 w-9 shrink-0 items-center justify-center overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-black/5">
          <img src={allimIcon} alt="" className="h-8 w-8" draggable={false} />
        </div>
        <div className="min-w-0">
          <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">
            Allim
          </p>
          <p className="mt-0.5 text-sm font-semibold leading-snug text-slate-950">
            You're near by Target and you have 3 reminder items
          </p>
        </div>
      </div>
    </div>
  );
}

function HeroPhoneScreen() {
  return (
    <div className="relative flex-1 overflow-hidden bg-[#f4f1e9]">
      <div className="absolute inset-0 origin-center scale-[2.12]">
        <img
          src={mapImage}
          alt=""
          className="h-full w-full object-cover object-[67%_50%]"
          draggable={false}
        />
        <RouteOverlay compact />
      </div>
      <div className="absolute inset-x-0 top-0 h-28 bg-gradient-to-b from-white/58 to-transparent" />
      <div className="absolute left-4 right-4 top-8">
        <AllimNotification />
      </div>
    </div>
  );
}

export default function HeroBackground() {
  return (
    <div
      className="absolute inset-0 z-0 overflow-hidden bg-[#f4f1e9]"
      aria-hidden="true"
    >
      <div className="absolute inset-0">
        <div className="absolute inset-0 origin-center scale-[1.2]">
          <img
            src={mapImage}
            alt=""
            className="h-full w-full object-cover object-[72%_50%]"
            draggable={false}
          />
          <RouteOverlay />
        </div>
      </div>

      <video
        className="absolute inset-0 z-10 h-full w-full object-cover opacity-90"
        autoPlay
        loop
        muted
        playsInline
        preload="auto"
      >
        <source src="/hero-map.mp4" type="video/mp4" />
        <source src="/hero-map.webm" type="video/webm" />
      </video>

      <div className="absolute inset-0 z-20 bg-[linear-gradient(90deg,rgba(8,18,31,0.92)_0%,rgba(8,18,31,0.62)_36%,rgba(8,18,31,0.18)_72%,rgba(8,18,31,0.04)_100%),linear-gradient(180deg,rgba(15,13,26,0.04)_0%,rgba(15,13,26,0.02)_45%,rgba(15,13,26,0.54)_100%)]" />

      <div className="absolute bottom-[-84px] right-[-30px] z-30 hidden rotate-[-6deg] opacity-95 drop-shadow-[0_38px_74px_rgba(0,0,0,0.50)] sm:block md:right-[5%] lg:bottom-[-64px] lg:right-[10%] xl:right-[13%]">
        <PhoneFrame className="mx-0 scale-[1.08] lg:scale-[1.18] origin-bottom-right">
          <HeroPhoneScreen />
        </PhoneFrame>
      </div>
    </div>
  );
}
