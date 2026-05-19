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
    ? "M446 582 L446 506 L536 506 L536 432 L612 432 L612 350 L662 350 L662 206"
    : "M446 582 L446 506 L536 506 L536 432 L612 432 L612 350 L662 350 L662 206";
  const pin = "translate(662 206)";

  return (
    <svg
      className={`pointer-events-none absolute inset-0 h-full w-full ${className}`}
      viewBox="0 0 1200 675"
      preserveAspectRatio="xMidYMid slice"
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
        strokeWidth={compact ? "9" : "12"}
      />
      <path
        className={compact ? "hero-phone-route" : "hero-route-line"}
        d={route}
        fill="none"
        filter={`url(#${compact ? "phoneRouteGlow" : "heroRouteGlow"})`}
        stroke="#147EFB"
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth={compact ? "5.5" : "7"}
      />

      <g>
        <circle r={compact ? "9" : "13"} fill="#147EFB" opacity="0.2" />
        <circle r={compact ? "6" : "8"} fill="#ffffff" />
        <circle r={compact ? "3.5" : "4.5"} fill="#147EFB" />
        <animateMotion
          dur="8s"
          repeatCount="indefinite"
          path={route}
          keyPoints="0;1;1;0"
          keyTimes="0;0.62;0.78;1"
          calcMode="linear"
        />
        <animate
          attributeName="opacity"
          dur="8s"
          repeatCount="indefinite"
          values="0;1;1;0"
          keyTimes="0;0.08;0.78;1"
          calcMode="linear"
        />
      </g>

      <g
        className={compact ? undefined : "hero-destination-pin"}
        filter={`url(#${compact ? "phoneMapPinShadow" : "heroMapPinShadow"})`}
        transform={pin}
      >
        <path
          d="M0 -30 C-15 -30 -27 -18 -27 -4 C-27 15 0 39 0 39 C0 39 27 15 27 -4 C27 -18 15 -30 0 -30Z"
          fill="#FF3B30"
        />
        <circle cx="0" cy="-4" r="10.5" fill="#ffffff" opacity="0.92" />
        <circle cx="0" cy="-4" r="4.5" fill="#FF3B30" />
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
      <div className="absolute inset-0 origin-center scale-[1.56]">
        <img
          src={mapImage}
          alt=""
          className="h-full w-full object-cover object-[45%_42%]"
          draggable={false}
        />
        <RouteOverlay compact />
      </div>
      <div className="absolute inset-x-0 top-0 h-28 bg-gradient-to-b from-white/58 to-transparent" />
      <div className="absolute left-4 right-4 top-12">
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
        <div className="absolute inset-0 origin-center scale-[1.24]">
          <img
            src={mapImage}
            alt=""
            className="h-full w-full object-cover object-center"
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

      <div className="absolute bottom-[-72px] right-[-20px] z-30 hidden rotate-[-6deg] opacity-95 drop-shadow-[0_38px_74px_rgba(0,0,0,0.50)] sm:block md:right-[5%] lg:bottom-[-52px] lg:right-[10%] xl:right-[13%]">
        <PhoneFrame className="mx-0 scale-[0.98] lg:scale-[1.05] origin-bottom-right">
          <HeroPhoneScreen />
        </PhoneFrame>
      </div>
    </div>
  );
}
