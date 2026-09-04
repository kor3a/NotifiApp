import { APP_STORE_URL, SUPPORT_EMAIL } from "../constants/links";

const sections = [
  {
    title: "Product",
    links: [
      { label: "Features", href: "#features" },
      { label: "How it works", href: "#how-it-works" },
      { label: "In practice", href: "#story" },
      { label: "Closer look", href: "#capabilities" },
    ],
  },
  {
    title: "Help",
    links: [
      { label: "FAQ", href: "#faq" },
      { label: "Support", href: "/support" },
      { label: "Email us", href: `mailto:${SUPPORT_EMAIL}` },
      {
        label: "Privacy policy",
        href: "https://github.com/kor3a/allim-privacy-policy",
      },
    ],
  },
  {
    title: "Get the app",
    links: [{ label: "Download on iOS", href: APP_STORE_URL }],
  },
];

export default function Footer() {
  return (
    <footer className="bg-canvas">
      <div className="aisle-rail" aria-hidden="true" />
      <div className="mx-auto max-w-6xl px-6 py-16">
        <div className="grid gap-12 md:grid-cols-12">
          <div className="md:col-span-4">
            <div className="flex items-center gap-2.5">
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
            </div>
            <p className="mt-5 max-w-xs text-[15px] leading-relaxed text-ink-2">
              Allim is Korean for &ldquo;to inform.&rdquo; A grocery list that
              knows when you&apos;re near the store.
            </p>
          </div>

          {sections.map((section) => (
            <div key={section.title} className="md:col-span-2">
              <h3 className="eyebrow mb-5 text-ink-3">{section.title}</h3>
              <ul className="space-y-3">
                {section.links.map((link) => (
                  <li key={link.label}>
                    <a
                      href={link.href}
                      {...(link.href.startsWith("http")
                        ? { target: "_blank", rel: "noopener noreferrer" }
                        : {})}
                      className="text-[15px] text-ink-2 transition-colors hover:text-teal"
                    >
                      {link.label}
                    </a>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>

        <div className="mt-16 flex flex-col gap-3 border-t border-line pt-8 sm:flex-row sm:items-center sm:justify-between">
          <p className="text-[13px] text-ink-3">
            &copy; {new Date().getFullYear()} Allim. All rights reserved.
          </p>
          <p className="text-[13px] text-ink-3">Made for iOS 17 and later.</p>
        </div>
      </div>
    </footer>
  );
}
