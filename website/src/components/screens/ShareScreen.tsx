import { HomeBar, ScreenHeader, StoreLogo } from "./parts";

const people = [
  { name: "Sarah", role: "Can edit", initial: "S", fill: "bg-snacks" },
  { name: "Dad", role: "Can edit", initial: "D", fill: "bg-dairy" },
  { name: "Grandma", role: "View only", initial: "G", fill: "bg-produce" },
];

export default function ShareScreen() {
  return (
    <div className="flex flex-1 flex-col overflow-hidden bg-canvas">
      <ScreenHeader eyebrow="Walmart" title="Sharing" />

      <div className="flex-1 overflow-hidden px-3">
        <div className="flex items-center gap-3 rounded-[14px] bg-wash px-3 py-2.5">
          <StoreLogo name="Walmart" size={34} />
          <div className="min-w-0">
            <p className="text-[13px] font-semibold text-on-wash">Walmart list</p>
            <p className="text-[10.5px] text-on-wash/70">Shared with 3 people</p>
          </div>
        </div>

        <p className="mt-4 mb-2 px-1 text-[10px] font-semibold tracking-[0.12em] text-ink-3 uppercase">
          People
        </p>

        <div className="overflow-hidden rounded-[14px] bg-card ring-1 ring-line">
          {people.map((person) => (
            <div
              key={person.name}
              className="flex items-center gap-3 border-b border-line px-3 py-2.5 last:border-b-0"
            >
              <span
                className={`flex h-[26px] w-[26px] shrink-0 items-center justify-center rounded-full text-[11px] font-bold text-white ${person.fill}`}
              >
                {person.initial}
              </span>
              <span className="flex-1 truncate text-[13.5px] text-ink">{person.name}</span>
              <span
                className={`rounded-full px-2 py-[3px] text-[10px] font-medium ${
                  person.role === "Can edit"
                    ? "bg-wash text-on-wash"
                    : "bg-field text-ink-2"
                }`}
              >
                {person.role}
              </span>
            </div>
          ))}
        </div>

        <div className="mt-3 rounded-[14px] border border-dashed border-line-strong px-3 py-2.5 text-center">
          <span className="text-[12px] font-medium text-teal">Invite someone else</span>
        </div>
      </div>

      <HomeBar />
    </div>
  );
}
