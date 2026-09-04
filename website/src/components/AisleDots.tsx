/**
 * The nine aisle hues, as the app files groceries under them. This is the
 * site's signature mark: it belongs to Allim's data model and to nothing else,
 * which is exactly why it does the work a generic icon set would otherwise be
 * doing.
 */
const AISLES = [
  { name: "Produce", className: "bg-produce" },
  { name: "Dairy", className: "bg-dairy" },
  { name: "Meat", className: "bg-meat" },
  { name: "Bakery", className: "bg-bakery" },
  { name: "Pantry", className: "bg-pantry" },
  { name: "Frozen", className: "bg-frozen" },
  { name: "Beverages", className: "bg-beverages" },
  { name: "Snacks", className: "bg-snacks" },
  { name: "Household", className: "bg-household" },
] as const;

export function AisleLegend({ className = "" }: { className?: string }) {
  return (
    <ul className={`flex flex-wrap items-center gap-x-5 gap-y-2 ${className}`}>
      {AISLES.map((aisle) => (
        <li key={aisle.name} className="flex items-center gap-2">
          <span
            className={`h-2 w-2 shrink-0 rounded-full ${aisle.className}`}
            aria-hidden="true"
          />
          <span className="text-[12px] font-medium tracking-[0.02em] text-ink-2">
            {aisle.name}
          </span>
        </li>
      ))}
    </ul>
  );
}
