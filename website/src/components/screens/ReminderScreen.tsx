import { GroceryRow, HomeBar, ScreenHeader } from "./parts";

const groups = [
  {
    label: "Produce",
    dot: "bg-produce",
    tint: "bg-[#E7F4EC]",
    ink: "text-[#1C6640]",
    items: ["Bananas", "Baby spinach"],
  },
  {
    label: "Dairy",
    dot: "bg-dairy",
    tint: "bg-[#E7F0FA]",
    ink: "text-[#1F5490]",
    items: ["Milk (2 gallons)", "Greek yogurt"],
  },
  {
    label: "Pantry",
    dot: "bg-pantry",
    tint: "bg-[#F8EFDD]",
    ink: "text-[#7A5410]",
    items: ["Olive oil"],
  },
];

export default function ReminderScreen() {
  return (
    <div className="flex flex-1 flex-col overflow-hidden bg-canvas">
      <ScreenHeader eyebrow="Whole Foods · 5 items" title="Grocery list" />

      <div className="flex-1 overflow-hidden px-3">
        {groups.map((group) => (
          <div key={group.label} className="mb-2.5">
            <div className="mb-1.5 flex items-center gap-2 px-1">
              <span className={`h-[7px] w-[7px] rounded-full ${group.dot}`} aria-hidden="true" />
              <span
                className={`rounded-full px-2 py-[2px] text-[10px] font-medium ${group.tint} ${group.ink}`}
              >
                {group.label}
              </span>
            </div>
            <div className="overflow-hidden rounded-[14px] bg-card ring-1 ring-line">
              {group.items.map((name) => (
                <GroceryRow key={name} name={name} dot={group.dot} />
              ))}
            </div>
          </div>
        ))}

        <p className="mt-3 px-1 text-[10.5px] text-ink-3">
          Filed as you type. Nothing to drag into order.
        </p>
      </div>

      <HomeBar />
    </div>
  );
}
