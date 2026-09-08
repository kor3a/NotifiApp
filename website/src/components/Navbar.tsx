import { useEffect, useState } from "react";
import { APP_STORE_URL } from "../constants/links";

const links = [
  { label: "Features", href: "#features" },
  { label: "How it works", href: "#how-it-works" },
  { label: "In practice", href: "#story" },
  { label: "Closer look", href: "#capabilities" },
  { label: "FAQ", href: "#faq" },
];

export default function Navbar() {
  const [open, setOpen] = useState(false);

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
    <header className="fixed inset-x-0 top-0 z-50">
      {/* The aisle rail runs the full width of the page, above everything. */}
      <div className="aisle-rail" aria-hidden="true" />

      <nav className="border-b border-line bg-canvas/92 backdrop-blur-md">
        <div className="mx-auto flex h-16 max-w-6xl items-center justify-between px-6">
          <a href="#top" className="flex items-center gap-2.5" aria-label="Allim, home">
            <img
              src="/allim-icon.svg"
              alt=""
              width="30"
              height="30"
              className="h-[30px] w-[30px] rounded-[7px]"
            />
            <span className="text-[19px] font-bold tracking-[-0.02em] text-ink">
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
            <a
              href={APP_STORE_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="rounded-[3px] bg-teal px-4 py-2 text-[14px] font-semibold text-white transition-colors hover:bg-teal-deep"
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
            <a
              href={APP_STORE_URL}
              target="_blank"
              rel="noopener noreferrer"
              onClick={() => setOpen(false)}
              className="my-4 block rounded-[3px] bg-teal py-3.5 text-center text-[16px] font-semibold text-white"
            >
              Get Allim
            </a>
          </div>
        </div>
      )}
    </header>
  );
}
