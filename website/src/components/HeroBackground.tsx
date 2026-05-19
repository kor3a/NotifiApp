const heroRoute =
  "M156 674 L252 674 Q284 674 306 650 L370 580 Q392 556 424 556 L542 556 Q574 556 596 532 L666 456 Q686 434 718 434 L824 434 Q856 434 878 410 L956 326 Q980 300 1018 300 L1100 300";

const phoneRoute =
  "M46 616 L94 616 Q114 616 128 600 L164 558 Q178 542 200 542 L240 542 Q260 542 272 526 L296 494 Q308 478 308 456 L308 188";

export default function HeroBackground() {
  return (
    <div
      className="absolute inset-0 z-0 overflow-hidden bg-[#eef1ed]"
      aria-hidden="true"
    >
      <div className="absolute inset-0 bg-[#eef1ed]" />

      <div className="hero-map-drift absolute left-1/2 top-[58%] h-[760px] w-[1120px] max-w-none -translate-x-1/2 -translate-y-1/2 opacity-95 sm:h-[900px] sm:w-[1340px] lg:left-[57%] lg:top-[57%]">
        <svg
          className="h-full w-full"
          viewBox="0 0 1280 860"
          role="img"
          aria-label="Apple Maps style navigation route to a pinned store"
        >
          <defs>
            <filter id="mapPinShadow" x="-60%" y="-60%" width="220%" height="220%">
              <feDropShadow
                dx="0"
                dy="9"
                floodColor="#2b3440"
                floodOpacity="0.25"
                stdDeviation="8"
              />
            </filter>
            <filter id="routeShadow" x="-20%" y="-20%" width="140%" height="140%">
              <feDropShadow
                dx="0"
                dy="2"
                floodColor="#0b4f9f"
                floodOpacity="0.22"
                stdDeviation="3"
              />
            </filter>
          </defs>

          <rect width="1280" height="860" fill="#eef1ed" />
          <path
            d="M-40 82 C174 8 296 68 420 40 S684 0 814 78 1056 120 1320 50 L1320 -40 L-40 -40Z"
            fill="#dbead8"
          />
          <path
            d="M-40 708 C144 650 314 748 470 704 S734 626 896 690 1124 794 1320 724 L1320 900 L-40 900Z"
            fill="#d8ead6"
          />
          <path
            d="M904 -20 C878 88 922 158 1014 204 S1156 314 1124 424 1138 606 1294 670 L1320 682 L1320 -20Z"
            fill="#cde7f5"
          />

          <g strokeLinecap="round" strokeLinejoin="round">
            <g stroke="#d5d9d0" strokeWidth="5">
              <path d="M-20 168 L188 168 Q238 168 274 202 L348 274 Q380 306 430 306 L620 306 Q672 306 710 270 L812 174 Q844 144 890 144 L1300 144" />
              <path d="M-10 392 L146 392 Q194 392 226 426 L304 508 Q334 540 382 540 L520 540 Q572 540 608 502 L688 416 Q724 378 778 378 L1294 378" />
              <path d="M-20 650 L126 650 Q168 650 198 620 L302 514 Q334 482 380 482 L532 482 Q584 482 618 444 L690 366 Q724 328 778 328 L1290 328" />
              <path d="M118 -20 L118 136 Q118 188 154 226 L218 292 Q250 326 250 374 L250 880" />
              <path d="M438 -20 L438 164 Q438 218 474 256 L532 318 Q562 352 562 398 L562 880" />
              <path d="M802 -20 L802 148 Q802 204 764 244 L690 322 Q656 358 656 408 L656 880" />
              <path d="M1066 -20 L1066 190 Q1066 238 1032 274 L958 354 Q926 388 926 436 L926 880" />
            </g>

            <g stroke="#ffffff" strokeWidth="18">
              <path d="M-20 168 L188 168 Q238 168 274 202 L348 274 Q380 306 430 306 L620 306 Q672 306 710 270 L812 174 Q844 144 890 144 L1300 144" />
              <path d="M-10 392 L146 392 Q194 392 226 426 L304 508 Q334 540 382 540 L520 540 Q572 540 608 502 L688 416 Q724 378 778 378 L1294 378" />
              <path d="M118 -20 L118 136 Q118 188 154 226 L218 292 Q250 326 250 374 L250 880" />
              <path d="M438 -20 L438 164 Q438 218 474 256 L532 318 Q562 352 562 398 L562 880" />
              <path d="M1066 -20 L1066 190 Q1066 238 1032 274 L958 354 Q926 388 926 436 L926 880" />
            </g>

            <g stroke="#f6f4ee" strokeWidth="26">
              <path d={heroRoute} />
            </g>
            <g stroke="#ffffff" strokeWidth="18">
              <path d={heroRoute} />
            </g>

            <g stroke="#f5c35b" strokeWidth="10">
              <path d="M-20 650 L126 650 Q168 650 198 620 L302 514 Q334 482 380 482 L532 482 Q584 482 618 444 L690 366 Q724 328 778 328 L1290 328" />
            </g>
            <g stroke="#ffffff" strokeWidth="5" opacity="0.55">
              <path d="M-20 650 L126 650 Q168 650 198 620 L302 514 Q334 482 380 482 L532 482 Q584 482 618 444 L690 366 Q724 328 778 328 L1290 328" />
            </g>

            <path
              className="hero-route-line"
              d={heroRoute}
              fill="none"
              filter="url(#routeShadow)"
              stroke="#147EFB"
              strokeWidth="13"
            />
          </g>

          <g fill="#9da69c" fontFamily="system-ui, -apple-system, sans-serif" fontSize="20">
            <text x="174" y="146">Market St</text>
            <text x="828" y="130">Cedar Ave</text>
            <text x="768" y="356">Main St</text>
            <text x="298" y="634">Oak Blvd</text>
            <text x="1028" y="270" transform="rotate(-48 1028 270)">
              Pine Rd
            </text>
          </g>

          <g fill="#8c968c" fontFamily="system-ui, -apple-system, sans-serif" fontSize="18">
            <text x="278" y="256">Coffee</text>
            <text x="506" y="520">Pharmacy</text>
            <text x="816" y="424">Grocery</text>
            <text x="1016" y="350">Target</text>
          </g>

          <g className="hero-driver-dot">
            <circle r="24" fill="#147EFB" opacity="0.2" />
            <circle r="12" fill="#ffffff" />
            <circle r="7" fill="#147EFB" />
          </g>

          <g
            className="hero-destination-pin"
            filter="url(#mapPinShadow)"
            transform="translate(1100 300)"
          >
            <path
              d="M0 -72 C-35 -72 -62 -45 -62 -11 C-62 34 0 88 0 88 C0 88 62 34 62 -11 C62 -45 35 -72 0 -72Z"
              fill="#FF3B30"
            />
            <circle cx="0" cy="-10" r="24" fill="#FFFFFF" />
            <circle cx="0" cy="-10" r="11" fill="#FF3B30" />
          </g>
        </svg>
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

      <div className="absolute inset-0 z-20 bg-[linear-gradient(90deg,rgba(8,18,31,0.96)_0%,rgba(8,18,31,0.72)_38%,rgba(8,18,31,0.30)_72%,rgba(8,18,31,0.10)_100%),linear-gradient(180deg,rgba(15,13,26,0.10)_0%,rgba(15,13,26,0.04)_45%,rgba(15,13,26,0.62)_100%)]" />

      <div className="absolute bottom-[-84px] right-[-34px] z-30 hidden w-[330px] rotate-[-7deg] opacity-95 drop-shadow-[0_34px_70px_rgba(0,0,0,0.48)] sm:block md:right-[4%] md:w-[370px] lg:bottom-[-64px] lg:right-[9%] lg:w-[410px] xl:right-[12%]">
        <div className="rounded-[46px] border border-white/18 bg-[#050812] p-3 shadow-2xl shadow-black/50">
          <div className="relative aspect-[9/19.5] overflow-hidden rounded-[36px] bg-[#eef1ed]">
            <div className="absolute left-1/2 top-2 z-20 h-6 w-28 -translate-x-1/2 rounded-full bg-[#050812]" />

            <svg
              className="absolute inset-0 h-full w-full"
              viewBox="0 0 360 780"
              aria-hidden="true"
            >
              <rect width="360" height="780" fill="#eef1ed" />
              <path
                d="M250 -20 C230 64 256 118 316 158 S384 278 338 360 310 506 382 574 L382 -20Z"
                fill="#cde7f5"
              />
              <path
                d="M-30 96 C48 56 124 92 178 70 S292 36 386 78 L386 -30 L-30 -30Z"
                fill="#dbead8"
              />
              <path
                d="M-28 664 C54 620 128 680 214 642 S306 610 390 656 L390 820 L-28 820Z"
                fill="#d8ead6"
              />

              <g strokeLinecap="round" strokeLinejoin="round">
                <g stroke="#d5d9d0" strokeWidth="4">
                  <path d="M-28 172 L88 172 Q116 172 136 194 L186 246 Q206 268 238 268 L392 268" />
                  <path d="M-30 384 L96 384 Q126 384 146 406 L190 452 Q210 474 242 474 L390 474" />
                  <path d="M70 -20 L70 150 Q70 180 90 202 L126 242 Q146 264 146 294 L146 820" />
                  <path d="M246 -20 L246 146 Q246 178 224 202 L178 252 Q158 274 158 306 L158 820" />
                </g>
                <g stroke="#ffffff" strokeWidth="14">
                  <path d="M-28 172 L88 172 Q116 172 136 194 L186 246 Q206 268 238 268 L392 268" />
                  <path d="M-30 384 L96 384 Q126 384 146 406 L190 452 Q210 474 242 474 L390 474" />
                  <path d="M70 -20 L70 150 Q70 180 90 202 L126 242 Q146 264 146 294 L146 820" />
                  <path d="M246 -20 L246 146 Q246 178 224 202 L178 252 Q158 274 158 306 L158 820" />
                </g>
                <g stroke="#f6f4ee" strokeWidth="20">
                  <path d={phoneRoute} />
                </g>
                <g stroke="#ffffff" strokeWidth="14">
                  <path d={phoneRoute} />
                </g>
                <path
                  className="hero-phone-route"
                  d={phoneRoute}
                  fill="none"
                  stroke="#147EFB"
                  strokeWidth="8"
                />
              </g>

              <g fill="#8c968c" fontFamily="system-ui, -apple-system, sans-serif" fontSize="14">
                <text x="96" y="154">Market St</text>
                <text x="200" y="456">Main St</text>
                <text x="250" y="524">Target</text>
              </g>

              <circle className="hero-phone-dot" cx="46" cy="616" r="11" fill="#147EFB" />
              <path
                d="M308 140 C286 140 268 158 268 180 C268 210 308 244 308 244 C308 244 348 210 348 180 C348 158 330 140 308 140Z"
                fill="#FF3B30"
              />
              <circle cx="308" cy="180" r="14" fill="#FFFFFF" />
              <circle cx="308" cy="180" r="6" fill="#FF3B30" />
            </svg>

            <div className="absolute inset-x-0 top-0 h-36 bg-gradient-to-b from-black/12 to-transparent" />

            <div className="hero-phone-notification absolute left-4 right-4 top-16 rounded-2xl border border-black/10 bg-white/90 p-3 shadow-2xl shadow-black/18 backdrop-blur-md">
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

            <div className="absolute bottom-6 left-1/2 h-1 w-24 -translate-x-1/2 rounded-full bg-black/22" />
          </div>
        </div>
      </div>
    </div>
  );
}
