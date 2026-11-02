import { useEffect, useRef, useState } from "react";
import { APP_STORE_URL } from "../constants/links";
import { gsap, MOTION_OK, ScrollTrigger, useGSAP } from "../lib/gsap";

const links = [
  { label: "What it does", href: "#features" },
  { label: "How it works", href: "#how-it-works" },
  { label: "Details", href: "#capabilities" },
  { label: "FAQ", href: "#faq" },
];

export default function Navbar() {
  const [open, setOpen] = useState(false);
  const header = useRef<HTMLElement>(null);

  // Slides away while you read down the page and comes back the moment you
  // scroll up, so it's there when you're looking for it and gone otherwise.
  useGSAP(() => {
    const mm = gsap.matchMedia();
    mm.add(MOTION_OK, () => {
      const hide = gsap.to(header.current, {
        yPercent: -100,
        duration: 0.35,
        ease: "power2.out",
        paused: true,
      });
      const st = ScrollTrigger.create({
        start: 0,
        end: "max",
        onUpdate: (self) => {
          if (self.direction === 1 && self.scroll() > 240) hide.play();
          else if (self.direction === -1) hide.reverse();
        },
      });
      return () => st.kill();
    });
  });

  // Lock the page while the mobile sheet is up, or the sheet scrolls the
  // masthead off behind it.
  useEffect(() => {
    if (!open) return;
    const previous = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.body.style.overflow = previous;
    };
  }, [open]);

  return (
    <header ref={header} className="fixed inset-x-0 top-0 z-50">
      <nav className="border-b border-line/70 bg-canvas/85 backdrop-blur-md">
        <div className="mx-auto flex h-16 max-w-6xl items-center justify-between px-6">
          <a href="#top" className="flex items-center gap-2.5" aria-label="Allim, home">
            <img
              src="/allim-icon.svg"
              alt=""
              width="30"
              height="30"
              className="h-[30px] w-[30px] rounded-[7px]"
            />
            <span className="text-[21px] font-extrabold tracking-[-0.03em] text-ink">
              Allim
            </span>
          </a>

          <div className="hidden items-center gap-7 lg:flex">
            {links.map((link) => (
              <a
                key={link.href}
                href={link.href}
                className="text-[14px] font-medium text-ink-2 transition-colors hover:text-teal"
              >
                {link.label}
              </a>
            ))}
            {/* The web app (src/app) only exists under `npm run dev`. DEV is
                false in the client and SSR builds, so this never ships. */}
            {import.meta.env.DEV && (
              <a
                href="/app/"
                className="text-[14px] font-semibold text-teal transition-colors hover:text-teal-deep"
              >
                Sign in
              </a>
            )}
            <a
              href={APP_STORE_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="rounded-full bg-ink px-5 py-2 text-[14px] font-semibold text-canvas transition-colors hover:bg-teal"
            >
              Get Allim
            </a>
          </div>

          <button
            type="button"
            className="-mr-2 flex h-10 w-10 items-center justify-center text-ink lg:hidden"
            onClick={() => setOpen((v) => !v)}
            aria-expanded={open}
            aria-label={open ? "Close menu" : "Open menu"}
          >
            {/* Two rules that cross — the same hairline the layout is built from. */}
            <span className="relative block h-[14px] w-[20px]">
              <span
                className={`absolute left-0 block h-[1.5px] w-full bg-current transition-transform duration-200 ${
                  open ? "top-[6px] rotate-45" : "top-0"
                }`}
              />
              <span
                className={`absolute left-0 block h-[1.5px] w-full bg-current transition-transform duration-200 ${
                  open ? "top-[6px] -rotate-45" : "top-[12px]"
                }`}
              />
            </span>
          </button>
        </div>
      </nav>

      {open && (
        <div className="border-b border-line bg-canvas lg:hidden">
          <div className="mx-auto max-w-6xl px-6 py-2">
            {links.map((link) => (
              <a
                key={link.href}
                href={link.href}
                onClick={() => setOpen(false)}
                className="block border-b border-line py-4 text-[17px] font-medium text-ink last:border-b-0"
              >
                {link.label}
              </a>
            ))}
            {import.meta.env.DEV && (
              <a
                href="/app/"
                className="block border-b border-line py-4 text-[17px] font-semibold text-teal"
              >
                Sign in
              </a>
            )}
            <a
              href={APP_STORE_URL}
              target="_blank"
              rel="noopener noreferrer"
              onClick={() => setOpen(false)}
              className="my-4 block rounded-full bg-ink py-3.5 text-center text-[16px] font-semibold text-white"
            >
              Get Allim
            </a>
          </div>
        </div>
      )}
    </header>
  );
}
