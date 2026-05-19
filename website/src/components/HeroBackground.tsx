export default function HeroBackground() {
  return (
    <div
      className="absolute inset-0 z-0 overflow-hidden bg-[#08121f]"
      aria-hidden="true"
    >
      <div className="absolute inset-0 bg-[radial-gradient(circle_at_18%_22%,rgba(74,144,217,0.24),transparent_28%),radial-gradient(circle_at_82%_30%,rgba(139,92,246,0.16),transparent_24%),linear-gradient(135deg,#07111d_0%,#101827_48%,#090d18_100%)]" />

      <div className="hero-map-drift absolute left-1/2 top-1/2 h-[760px] w-[1120px] max-w-none -translate-x-1/2 -translate-y-1/2 opacity-95 sm:h-[860px] sm:w-[1280px]">
        <svg
          className="h-full w-full"
          viewBox="0 0 1280 860"
          role="img"
          aria-label="Animated navigation route to a saved store"
        >
          <defs>
            <linearGradient id="routeBlue" x1="0" x2="1" y1="0" y2="1">
              <stop offset="0%" stopColor="#78C7FF" />
              <stop offset="52%" stopColor="#4A90D9" />
              <stop offset="100%" stopColor="#8B5CF6" />
            </linearGradient>
            <filter id="routeGlow" x="-40%" y="-40%" width="180%" height="180%">
              <feGaussianBlur stdDeviation="8" result="blur" />
              <feMerge>
                <feMergeNode in="blur" />
                <feMergeNode in="SourceGraphic" />
              </feMerge>
            </filter>
            <filter id="pinShadow" x="-60%" y="-60%" width="220%" height="220%">
              <feDropShadow
                dx="0"
                dy="10"
                floodColor="#000614"
                floodOpacity="0.35"
                stdDeviation="10"
              />
            </filter>
          </defs>

          <g opacity="0.2" stroke="#D8E9FF" strokeLinecap="round">
            <path d="M-20 174 C170 150 270 250 445 218 S760 138 942 206 1135 298 1320 242" />
            <path d="M-10 390 C126 355 252 434 392 408 S645 306 804 346 1084 496 1305 418" />
            <path d="M-20 642 C170 594 322 682 512 640 S782 512 966 562 1156 678 1318 618" />
            <path d="M112 0 C144 142 94 264 148 408 S270 614 220 872" />
            <path d="M414 -20 C448 116 386 250 452 386 S588 592 546 890" />
            <path d="M764 -20 C724 124 790 276 724 426 S596 642 626 890" />
            <path d="M1052 -30 C986 126 1052 264 1008 422 S918 652 980 890" />
          </g>

          <g opacity="0.34">
            <path
              d="M96 118 L268 78 L438 132 L612 88 L802 142 L1012 90 L1198 136 L1164 340 L1216 548 L1094 742 L882 706 L682 782 L474 708 L276 754 L96 670 L138 456 Z"
              fill="none"
              stroke="#A7CFFF"
              strokeWidth="2"
            />
            <path
              d="M198 238 L404 206 L552 276 L742 230 L938 292 L1112 252"
              fill="none"
              stroke="#E8F3FF"
              strokeWidth="3"
            />
            <path
              d="M158 508 L332 470 L492 528 L670 488 L852 540 L1096 498"
              fill="none"
              stroke="#E8F3FF"
              strokeWidth="3"
            />
            <path
              d="M342 112 L360 318 L320 510 L372 724"
              fill="none"
              stroke="#E8F3FF"
              strokeWidth="3"
            />
            <path
              d="M686 112 L660 308 L704 502 L676 760"
              fill="none"
              stroke="#E8F3FF"
              strokeWidth="3"
            />
            <path
              d="M1008 126 L966 308 L1002 514 L942 724"
              fill="none"
              stroke="#E8F3FF"
              strokeWidth="3"
            />
          </g>

          <g opacity="0.22" fill="#FFFFFF">
            <circle cx="238" cy="292" r="5" />
            <circle cx="496" cy="212" r="4" />
            <circle cx="824" cy="286" r="5" />
            <circle cx="1092" cy="438" r="4" />
            <circle cx="436" cy="574" r="5" />
            <circle cx="792" cy="626" r="4" />
          </g>

          <path
            className="hero-route-base"
            d="M186 684 C254 592 314 590 366 518 S458 388 552 420 642 514 726 450 770 284 888 294 966 364 1038 294"
            fill="none"
            stroke="#153A62"
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth="28"
          />
          <path
            className="hero-route-line"
            d="M186 684 C254 592 314 590 366 518 S458 388 552 420 642 514 726 450 770 284 888 294 966 364 1038 294"
            fill="none"
            filter="url(#routeGlow)"
            stroke="url(#routeBlue)"
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth="15"
          />

          <g className="hero-driver-dot">
            <circle r="24" fill="#4A90D9" opacity="0.2" />
            <circle r="12" fill="#DDF1FF" />
            <circle r="7" fill="#4A90D9" />
          </g>

          <g
            className="hero-destination-pin"
            filter="url(#pinShadow)"
            transform="translate(1038 294)"
          >
            <path
              d="M0 -72 C-35 -72 -62 -45 -62 -11 C-62 34 0 88 0 88 C0 88 62 34 62 -11 C62 -45 35 -72 0 -72Z"
              fill="#FF4D6D"
            />
            <circle cx="0" cy="-10" r="24" fill="#FFFFFF" />
            <circle cx="0" cy="-10" r="11" fill="#FF4D6D" />
          </g>
        </svg>
      </div>

      <div className="hero-arrival-toast absolute right-6 top-24 hidden w-[min(320px,calc(100vw-48px))] rounded-2xl border border-white/15 bg-[#0B1624]/85 p-4 shadow-2xl shadow-black/30 backdrop-blur-md sm:block lg:right-[8%] lg:top-[22%]">
        <div className="flex items-start gap-3">
          <div className="mt-1 flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-allim-blue/20 text-allim-blue">
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
          <div>
            <p className="text-sm font-semibold text-white">You arrived at Target</p>
            <p className="mt-1 text-sm leading-5 text-allim-muted">
              Milk, eggs, coffee, and 4 more items are nearby.
            </p>
          </div>
        </div>
      </div>

      <video
        className="absolute inset-0 h-full w-full object-cover opacity-90"
        autoPlay
        loop
        muted
        playsInline
        preload="auto"
      >
        <source src="/hero-map.mp4" type="video/mp4" />
        <source src="/hero-map.webm" type="video/webm" />
      </video>

      <div className="absolute inset-0 bg-[linear-gradient(90deg,rgba(8,18,31,0.92)_0%,rgba(8,18,31,0.62)_42%,rgba(8,18,31,0.36)_100%),linear-gradient(180deg,rgba(15,13,26,0.36)_0%,rgba(15,13,26,0.18)_45%,rgba(15,13,26,0.88)_100%)]" />
    </div>
  );
}
