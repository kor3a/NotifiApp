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
    <footer className="border-t border-allim-line bg-allim-dark py-16">
      <div className="mx-auto max-w-6xl px-6">
        <div className="grid gap-12 md:grid-cols-12">
          <div className="md:col-span-4">
            <div className="flex items-center gap-2.5">
              <img
                src="/allimIcon.svg"
                alt="Allim"
                className="h-9 w-9 rounded-xl"
              />
              <span className="text-lg font-semibold text-white">Allim</span>
            </div>
            <p className="mt-4 max-w-xs text-[15px] leading-relaxed text-allim-muted">
              From the Korean word for “alarm.” A shopping list that knows when
              you're near the store.
            </p>
          </div>

          {sections.map((section) => (
            <div key={section.title} className="md:col-span-2 lg:col-span-2">
              <h3 className="mb-4 text-[13px] font-medium uppercase tracking-[0.14em] text-allim-faint">
                {section.title}
              </h3>
              <ul className="space-y-2.5">
                {section.links.map((link) => (
                  <li key={link.label}>
                    <a
                      href={link.href}
                      {...(link.href.startsWith("http")
                        ? { target: "_blank", rel: "noopener noreferrer" }
                        : {})}
                      className="text-[15px] text-allim-muted transition-colors hover:text-white"
                    >
                      {link.label}
                    </a>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>

        <div className="mt-14 flex flex-col gap-3 border-t border-allim-line pt-8 sm:flex-row sm:items-center sm:justify-between">
          <p className="text-sm text-allim-faint">
            &copy; {new Date().getFullYear()} Allim. All rights reserved.
          </p>
          <p className="text-sm text-allim-faint">Made for iOS 17 and later.</p>
        </div>
      </div>
    </footer>
  );
}
