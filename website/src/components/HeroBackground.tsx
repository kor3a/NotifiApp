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
    ? "M526 632 L526 588 L616 588 L616 412 L612 394 L612 220 L662 220"
    : "M463 632 L463 540 L576 540 L576 412 L573 394 L573 215 L610 215";
  const pin = compact ? "translate(662 215)" : "translate(610 206)";

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
        className={compact ? "hero-phone-route" : "hero-route-line"}
        d={route}
        fill="none"
        filter={`url(#${compact ? "phoneRouteGlow" : "heroRouteGlow"})`}
        stroke="#147EFB"
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth={compact ? "4.25" : "5"}
      />

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
    <div
      className="hero-phone-notification rounded-[20px] p-3 flex items-start gap-2.5"
      style={{
        background: "rgba(255,255,255,0.92)",
        backdropFilter: "blur(30px)",
        WebkitBackdropFilter: "blur(30px)",
        boxShadow:
          "0 8px 32px rgba(0,0,0,0.18), 0 2px 8px rgba(0,0,0,0.08)",
      }}
    >
      <img
        src={allimIcon}
        alt="Allim"
        className="w-[34px] h-[34px] rounded-[8px] shrink-0 object-cover"
        draggable={false}
      />

      <div className="flex-1 min-w-0">
        <div className="flex items-center justify-between">
          <span className="text-[12px] font-semibold text-black/80">
            Allim
          </span>
          <span className="text-[10px] text-black/40">now</span>
        </div>
        <p className="text-[13px] font-semibold text-black mt-0.5 leading-tight">
          You're near Target
        </p>
        <p className="text-[11px] text-black/60 mt-0.5 leading-snug">
          You have 3 reminders waiting for you at this store.
        </p>
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
      <div className="absolute top-8 left-3 right-3 z-20">
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
        <div className="absolute inset-0 origin-center scale-[1.45]">
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
        <PhoneFrame
          className="mx-0 scale-[0.98] lg:scale-[1.05] origin-bottom-right"
          screenClassName="pt-0"
        >
          <HeroPhoneScreen />
        </PhoneFrame>
      </div>
    </div>
  );
}
