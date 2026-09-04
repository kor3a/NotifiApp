import { CountBadge, HomeBar, ScreenHeader, StoreLogo } from "./parts";

const nearby = { name: "Walmart", note: "Shared with family · 0.3 mi", n: 5 };

const rest = [
  { name: "Whole Foods", note: "1.2 mi away", n: 3 },
  { name: "Costco", note: "4.0 mi away", n: 8 },
  { name: "Target", note: "5.1 mi away", n: 2 },
  { name: "Kroger", note: "6.4 mi away", n: 1 },
];

function Row({
  name,
  note,
  n,
}: {
  name: string;
  note: string;
  n: number;
}) {
  return (
    <div className="flex items-center gap-3 border-b border-line px-3 py-2.5 last:border-b-0">
      <StoreLogo name={name} />
      <div className="min-w-0 flex-1">
        <p className="truncate text-[14px] font-medium text-ink">{name}</p>
        <p className="truncate text-[10.5px] text-ink-3">{note}</p>
      </div>
      <CountBadge n={n} />
    </div>
  );
}

/** The app's home: every store you shop at, and what's still on each list. */
export default function StoresScreen() {
  return (
    <div className="flex flex-1 flex-col overflow-hidden bg-canvas">
      <ScreenHeader eyebrow="Good afternoon" title="Your stores" />

      <div className="flex-1 overflow-hidden px-3">
        <p className="mb-1.5 flex items-center gap-1.5 px-1 text-[10px] font-semibold tracking-[0.12em] text-orange uppercase">
          <span className="h-[5px] w-[5px] rounded-full bg-orange" aria-hidden="true" />
          Nearby now
        </p>
        <div className="overflow-hidden rounded-[14px] bg-card ring-1 ring-orange/35">
          <Row {...nearby} />
        </div>

        <p className="mt-4 mb-1.5 px-1 text-[10px] font-semibold tracking-[0.12em] text-ink-3 uppercase">
          All stores
        </p>
        <div className="overflow-hidden rounded-[14px] bg-card ring-1 ring-line">
          {rest.map((store) => (
            <Row key={store.name} {...store} />
          ))}
        </div>

        <div className="mt-3 rounded-[14px] border border-dashed border-line-strong py-2.5 text-center">
          <span className="text-[12px] font-medium text-teal">Add a store</span>
        </div>
      </div>

      <HomeBar />
    </div>
  );
}
