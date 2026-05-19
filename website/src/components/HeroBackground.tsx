import PhoneFrame from "./PhoneFrame";

const heroRoute =
  "M164 650 L270 650 Q304 650 328 626 L396 558 Q420 534 454 534 L562 534 Q596 534 620 510 L704 426 Q728 402 762 402 L850 402 Q884 402 908 378 L1000 286 Q1028 258 1072 258 L1134 258";

const phoneRoute =
  "M44 616 L94 616 Q118 616 134 598 L174 552 Q190 534 216 534 L250 534 Q274 534 290 514 L310 488 Q322 472 322 448 L322 176";

function RouteShield({
  x,
  y,
  label,
  kind = "interstate",
}: {
  x: number;
  y: number;
  label: string;
  kind?: "interstate" | "state";
}) {
  const fill = kind === "interstate" ? "#2d7ff9" : "#00a878";
  const stroke = kind === "interstate" ? "#f34545" : "#ffffff";

  return (
    <g fontFamily="system-ui, -apple-system, sans-serif" fontSize="14" fontWeight="800">
      <rect x={x} y={y} width="42" height="25" rx="7" fill={fill} stroke={stroke} strokeWidth="2" />
      <text x={x + 21} y={y + 18} textAnchor="middle" fill="#ffffff">
        {label}
      </text>
    </g>
  );
}

function AppleMapsSvg({ compact = false }: { compact?: boolean }) {
  const viewBox = compact ? "0 0 360 780" : "0 0 1280 860";
  const route = compact ? phoneRoute : heroRoute;

  return (
    <svg
      className="h-full w-full"
      viewBox={viewBox}
      role="img"
      aria-label="Apple Maps style navigation route"
    >
      <defs>
        <filter id={compact ? "phoneRouteShadow" : "heroRouteShadow"} x="-20%" y="-20%" width="140%" height="140%">
          <feDropShadow dx="0" dy="2" floodColor="#0b4f9f" floodOpacity="0.24" stdDeviation="3" />
        </filter>
        <filter id={compact ? "phonePinShadow" : "heroPinShadow"} x="-60%" y="-60%" width="220%" height="220%">
          <feDropShadow dx="0" dy="8" floodColor="#2b3440" floodOpacity="0.28" stdDeviation="8" />
        </filter>
      </defs>

      <rect width="1280" height="860" fill="#f4f1e9" />

      <g fill="#e9e4d8" opacity="0.62">
        <rect x="236" y="174" width="176" height="92" rx="6" />
        <rect x="474" y="198" width="136" height="84" rx="6" />
        <rect x="728" y="160" width="170" height="96" rx="6" />
        <rect x="838" y="488" width="170" height="88" rx="6" />
        <rect x="120" y="458" width="150" height="90" rx="6" />
        <rect x="980" y="350" width="160" height="86" rx="6" />
      </g>

      <path
        d="M-60 0 H1280 V108 C1180 132 1058 94 964 128 C856 166 772 82 654 110 C560 132 504 72 390 92 C246 118 142 42 -60 88Z"
        fill="#86d8eb"
      />
      <path
        d="M350 0 C376 44 448 34 462 92 C474 140 408 154 420 202 C432 252 520 218 540 266 C560 312 494 348 432 336 C350 320 286 244 292 168 C298 92 318 38 350 0Z"
        fill="#b9e7a4"
      />
      <path
        d="M-60 692 C92 628 190 732 342 694 C490 658 618 608 782 666 C932 720 1084 704 1340 612 V920 H-60Z"
        fill="#c7e9b5"
      />
      <path
        d="M1048 38 C1108 84 1184 90 1280 68 V242 C1194 240 1140 196 1098 150 C1060 108 1018 86 1048 38Z"
        fill="#d1efbd"
      />
      <path
        d="M-60 616 C58 574 124 620 214 590 S394 520 514 548"
        fill="none"
        stroke="#9bcd8b"
        strokeWidth="18"
        strokeLinecap="round"
        opacity="0.85"
      />

      <g strokeLinecap="round" strokeLinejoin="round">
        <g stroke="#d5d8d5" strokeWidth="3">
          <path d="M-40 212 L160 212 Q210 212 244 246 L318 320 Q350 352 398 352 L616 352 Q668 352 704 316 L778 242 Q814 206 866 206 L1340 206" />
          <path d="M-40 308 L110 308 Q158 308 192 342 L260 410 Q294 444 342 444 L546 444 Q598 444 636 408 L708 340 Q744 306 794 306 L1340 306" />
          <path d="M-30 502 L142 502 Q188 502 222 536 L300 616 Q334 650 382 650 L1320 650" />
          <path d="M-28 588 L126 588 Q172 588 204 556 L304 456 Q338 422 386 422 L564 422 Q610 422 644 388 L742 290" />
          <path d="M96 -20 L96 168 Q96 216 130 250 L194 316 Q228 350 228 398 L228 900" />
          <path d="M332 -20 L332 170 Q332 218 366 252 L430 316 Q464 350 464 398 L464 900" />
          <path d="M594 -20 L594 180 Q594 228 628 262 L700 334 Q734 368 734 416 L734 900" />
          <path d="M940 -20 L940 196 Q940 244 906 280 L844 344 Q812 378 812 426 L812 900" />
          <path d="M1118 -20 L1118 210 Q1118 260 1084 296 L1018 366 Q986 400 986 448 L986 900" />
        </g>

        <g stroke="#ffffff" strokeWidth="9">
          <path d="M-40 212 L160 212 Q210 212 244 246 L318 320 Q350 352 398 352 L616 352 Q668 352 704 316 L778 242 Q814 206 866 206 L1340 206" />
          <path d="M-40 308 L110 308 Q158 308 192 342 L260 410 Q294 444 342 444 L546 444 Q598 444 636 408 L708 340 Q744 306 794 306 L1340 306" />
          <path d="M-30 502 L142 502 Q188 502 222 536 L300 616 Q334 650 382 650 L1320 650" />
          <path d="M96 -20 L96 168 Q96 216 130 250 L194 316 Q228 350 228 398 L228 900" />
          <path d="M332 -20 L332 170 Q332 218 366 252 L430 316 Q464 350 464 398 L464 900" />
          <path d="M594 -20 L594 180 Q594 228 628 262 L700 334 Q734 368 734 416 L734 900" />
          <path d="M940 -20 L940 196 Q940 244 906 280 L844 344 Q812 378 812 426 L812 900" />
          <path d="M1118 -20 L1118 210 Q1118 260 1084 296 L1018 366 Q986 400 986 448 L986 900" />
        </g>

        <g stroke="#a8b0b7" strokeWidth="19">
          <path d="M-70 138 L180 148 Q252 150 304 198 L416 302 Q464 346 532 348 L1340 348" />
          <path d="M-40 654 L164 654 Q232 654 282 608 L388 506 Q438 458 508 458 L1320 458" />
          <path d="M704 -40 L704 122 Q704 202 758 258 L854 358 Q908 414 908 494 L908 920" />
        </g>
        <g stroke="#ffffff" strokeWidth="5" opacity="0.52">
          <path d="M-70 138 L180 148 Q252 150 304 198 L416 302 Q464 346 532 348 L1340 348" />
          <path d="M-40 654 L164 654 Q232 654 282 608 L388 506 Q438 458 508 458 L1320 458" />
          <path d="M704 -40 L704 122 Q704 202 758 258 L854 358 Q908 414 908 494 L908 920" />
        </g>

        <g stroke="#f8f4ea" strokeWidth={compact ? "20" : "28"}>
          <path d={route} />
        </g>
        <g stroke="#ffffff" strokeWidth={compact ? "14" : "20"}>
          <path d={route} />
        </g>
        <path
          className={compact ? "hero-phone-route" : "hero-route-line"}
          d={route}
          fill="none"
          filter={`url(#${compact ? "phoneRouteShadow" : "heroRouteShadow"})`}
          stroke="#147EFB"
          strokeWidth={compact ? "8" : "14"}
        />
      </g>

      <g fill="#3f474f" fontFamily="system-ui, -apple-system, sans-serif" fontWeight="700">
        <text x="246" y="300" fontSize="29">Mountain View</text>
        <text x="396" y="412" fontSize="30">Sunnyvale</text>
        <text x="724" y="492" fontSize="28">Santa Clara</text>
        <text x="952" y="568" fontSize="37">San Jose</text>
        <text x="926" y="108" fontSize="27">Milpitas</text>
        <text x="402" y="662" fontSize="27">Cupertino</text>
      </g>
      <g fill="#6c737a" fontFamily="system-ui, -apple-system, sans-serif" fontSize="15" fontWeight="600">
        <text x="204" y="234" transform="rotate(24 204 234)">CENTRAL EXPY</text>
        <text x="816" y="292">NORTH SANTA CLARA</text>
        <text x="772" y="612">BURBANK</text>
        <text x="1020" y="398" transform="rotate(-43 1020 398)">MABURY RD</text>
        <text x="1072" y="710">WILLOW GLEN</text>
      </g>

      <RouteShield x={318} y={252} label="85" kind="state" />
      <RouteShield x={586} y={282} label="101" kind="interstate" />
      <RouteShield x={786} y={380} label="87" kind="state" />
      <RouteShield x={910} y={336} label="880" kind="interstate" />
      <RouteShield x={478} y={604} label="280" kind="interstate" />

      <g fill="#128a39" fontFamily="system-ui, -apple-system, sans-serif" fontSize="14" fontWeight="700">
        <circle cx="290" cy="114" r="8" fill="#23b33b" />
        <text x="306" y="120">Shoreline Park</text>
        <circle cx="1204" cy="252" r="8" fill="#23b33b" />
        <text x="1220" y="258">Alum Rock</text>
      </g>

      <g className={compact ? "hero-phone-dot" : "hero-driver-dot"}>
        <circle r={compact ? "16" : "24"} fill="#147EFB" opacity="0.2" />
        <circle r={compact ? "9" : "12"} fill="#ffffff" />
        <circle r={compact ? "5" : "7"} fill="#147EFB" />
      </g>

      <g
        className={compact ? undefined : "hero-destination-pin"}
        filter={`url(#${compact ? "phonePinShadow" : "heroPinShadow"})`}
        transform={compact ? "translate(322 176)" : "translate(1134 258)"}
      >
        <path
          d="M0 -70 C-34 -70 -60 -44 -60 -11 C-60 33 0 86 0 86 C0 86 60 33 60 -11 C60 -44 34 -70 0 -70Z"
          fill="#FF3B30"
        />
        <circle cx="0" cy="-10" r="23" fill="#ffffff" />
        <circle cx="0" cy="-10" r="10" fill="#FF3B30" />
      </g>
    </svg>
  );
}

function HeroPhoneScreen() {
  return (
    <div className="relative flex-1 overflow-hidden bg-[#f4f1e9]">
      <div className="absolute inset-0 scale-[1.06]">
        <AppleMapsSvg compact />
      </div>
      <div className="absolute inset-x-0 top-0 h-32 bg-gradient-to-b from-white/70 to-transparent" />

      <div className="hero-phone-notification absolute left-4 right-4 top-8 rounded-2xl border border-black/10 bg-white/92 p-3 shadow-2xl shadow-black/18 backdrop-blur-md">
        <div className="flex items-start gap-3">
          <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-[#147EFB]/12 text-[#147EFB]">
            <svg
              className="h-5 w-5"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              strokeWidth="2"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                d="M15 17h5l-1.4-1.4A2 2 0 0 1 18 14.2V11a6 6 0 1 0-12 0v3.2c0 .5-.2 1-.6 1.4L4 17h5m6 0a3 3 0 0 1-6 0"
              />
            </svg>
          </div>
          <div className="min-w-0">
            <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">
              NotifiApp
            </p>
            <p className="mt-0.5 text-sm font-semibold text-slate-950">
              You arrived at Target
            </p>
            <p className="mt-1 text-xs leading-4 text-slate-600">
              Milk, eggs, coffee, and 4 more items are nearby.
            </p>
          </div>
        </div>
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
      <div className="hero-map-drift absolute left-1/2 top-[58%] h-[760px] w-[1120px] max-w-none -translate-x-1/2 -translate-y-1/2 opacity-95 sm:h-[900px] sm:w-[1340px] lg:left-[57%] lg:top-[57%]">
        <AppleMapsSvg />
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
