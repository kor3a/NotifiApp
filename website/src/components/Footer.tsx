import { APP_STORE_URL, SUPPORT_EMAIL } from "../constants/links";

const links = [
  { label: "Support", href: "/support" },
  { label: "Email us", href: `mailto:${SUPPORT_EMAIL}` },
  { label: "Privacy policy", href: "https://github.com/kor3a/allim-privacy-policy" },
  { label: "App Store", href: APP_STORE_URL },
];

export default function Footer() {
  return (
    <footer className="bg-teal-night text-white">
      <div className="mx-auto max-w-6xl px-6 pt-20 pb-10">
        <p className="hand -rotate-1 text-[clamp(2.6rem,7vw,4.5rem)] leading-none text-tag">
          see you at the store.
        </p>

        <div className="mt-16 flex flex-col gap-10 border-t border-white/15 pt-8 md:flex-row md:items-start md:justify-between">
          <div className="flex items-start gap-3">
            <img
              src="/allim-icon.svg"
              alt=""
              width="36"
              height="36"
              className="h-9 w-9 rounded-[8px]"
            />
            <p className="max-w-xs text-[14px] leading-relaxed text-white/65">
              <span className="font-bold text-white">Allim</span> is Korean for
              &ldquo;to inform.&rdquo; A grocery list that knows when you&apos;re
              near the store.
            </p>
          </div>

          <ul className="flex flex-wrap gap-x-8 gap-y-3">
            {links.map((link) => (
              <li key={link.label}>
                <a
                  href={link.href}
                  {...(link.href.startsWith("http")
                    ? { target: "_blank", rel: "noopener noreferrer" }
                    : {})}
                  className="text-[15px] font-medium text-white/85 underline-offset-4 transition-colors hover:text-tag hover:underline"
                >
                  {link.label}
                </a>
              </li>
            ))}
          </ul>
        </div>

        <p className="mt-12 text-[13px] text-white/45">
          &copy; {new Date().getFullYear()} Allim &middot; for iPhone, iOS 17 and later
        </p>
      </div>
    </footer>
  );
}
