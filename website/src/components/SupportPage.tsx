import { SUPPORT_EMAIL } from "../constants/links";

const topics = [
  {
    n: "01",
    title: "Nearby alerts are not working",
    items: [
      "Location permission is set to Always (or allowed in the background)",
      "Precise Location is enabled — recommended",
      "Notifications are enabled for Allim",
      "Low Power Mode or a Focus is not suppressing notifications",
      "You are within a reasonable distance of the saved store location",
    ],
  },
  {
    n: "02",
    title: "I'm not receiving reminder notifications",
    items: [
      "Open iOS Settings → Notifications → Allim → Allow Notifications",
      "Restart the app after enabling permissions",
      "Make sure reminder details are saved correctly",
    ],
  },
  {
    n: "03",
    title: "A store location seems incorrect",
    items: [
      "Edit and re-save the store pin or address",
      "Confirm map and location access is enabled",
      "Move closer to the destination and try again",
    ],
  },
  {
    n: "04",
    title: "Shared lists are out of sync",
    items: [
      "Check the internet connection on all devices",
      "Close and reopen the app",
      "Make sure everyone is on the latest app version",
    ],
  },
];

function Section({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <section className="border-t border-line py-10">
      <h2 className="eyebrow mb-6 text-teal">{title}</h2>
      {children}
    </section>
  );
}

function Bullets({ items }: { items: string[] }) {
  return (
    <ul className="space-y-2.5">
      {items.map((item) => (
        <li key={item} className="flex gap-3 text-[15px] leading-relaxed text-ink-2">
          <span className="mt-[9px] h-[5px] w-[5px] shrink-0 rounded-full bg-line-strong" aria-hidden="true" />
          {item}
        </li>
      ))}
    </ul>
  );
}

export default function SupportPage() {
  return (
    <div className="min-h-screen bg-canvas">
      <div className="aisle-rail" aria-hidden="true" />

      <div className="border-b border-line">
        <div className="mx-auto flex h-16 max-w-3xl items-center px-6">
          <a href="/" className="flex items-center gap-2.5" aria-label="Allim, home">
            <img
              src="/allim-icon.svg"
              alt=""
              width="28"
              height="28"
              className="h-7 w-7 rounded-[6px]"
            />
            <span className="text-[18px] font-bold tracking-[-0.02em] text-ink">Allim</span>
          </a>
        </div>
      </div>

      <main className="mx-auto max-w-3xl px-6 pb-24">
        <header className="py-16">
          <p className="eyebrow text-ink-3">Support</p>
          <h1 className="display mt-5 text-[clamp(2.2rem,7vw,3.25rem)] text-ink">
            Something not firing?
          </h1>
          <p className="mt-6 max-w-xl text-[17px] leading-relaxed text-ink-2">
            Allim (Korean for &ldquo;to inform&rdquo;) saves your stores, keeps a
            grocery list for each, and alerts you when you&apos;re nearby. Almost
            every problem below comes down to a permission iOS never granted.
          </p>
        </header>

        <Section title="Contact">
          <dl className="grid gap-6 sm:grid-cols-2">
            <div>
              <dt className="text-[13px] text-ink-3">Email</dt>
              <dd className="mt-1">
                <a
                  href={`mailto:${SUPPORT_EMAIL}`}
                  className="text-[16px] font-medium text-teal underline underline-offset-4 hover:text-teal-deep"
                >
                  {SUPPORT_EMAIL}
                </a>
              </dd>
            </div>
            <div>
              <dt className="text-[13px] text-ink-3">Response time</dt>
              <dd className="mt-1 text-[16px] text-ink">Usually 24–72 hours</dd>
            </div>
          </dl>
        </Section>

        <Section title="Common topics">
          <div className="space-y-10">
            {topics.map((topic) => (
              <div key={topic.n}>
                <div className="mb-4 flex items-baseline gap-4">
                  <span className="figure text-[13px] text-ink-3">{topic.n}</span>
                  <h3 className="text-[18px] font-semibold text-ink">{topic.title}</h3>
                </div>
                <Bullets items={topic.items} />
              </div>
            ))}
          </div>
        </Section>

        <Section title="Before you write in">
          <Bullets
            items={[
              "Update Allim to the latest version",
              "Restart your device",
              "Reopen Allim and test again",
            ]}
          />
        </Section>

        <Section title="What to include">
          <Bullets
            items={[
              "Device model (e.g. iPhone 15)",
              "iOS version",
              "App version",
              "A short description of the issue",
              "Screenshots, if you have them",
            ]}
          />
          <p className="mt-5 text-[15px] text-ink-2">This gets it fixed faster.</p>
        </Section>

        <Section title="Privacy">
          <p className="text-[15px] leading-relaxed text-ink-2">
            For how Allim handles your data, see the{" "}
            <a
              href="https://github.com/kor3a/allim-privacy-policy"
              target="_blank"
              rel="noopener noreferrer"
              className="text-teal underline underline-offset-4 hover:text-teal-deep"
            >
              privacy policy
            </a>
            .
          </p>
        </Section>

        <p className="border-t border-line pt-10">
          <a href="/" className="text-[15px] text-ink-2 transition-colors hover:text-teal">
            ← Back to allim
          </a>
        </p>
      </main>
    </div>
  );
}
