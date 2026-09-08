import { HomeBar, ScreenHeader } from "./parts";

const ingredients = [
  { name: "Chicken thighs", dot: "bg-meat" },
  { name: "Gochujang", dot: "bg-pantry" },
  { name: "Scallions", dot: "bg-produce" },
  { name: "Short-grain rice", dot: "bg-pantry" },
  { name: "Toasted sesame oil", dot: "bg-pantry" },
];

export default function SmartRecipeScreen() {
  return (
    <div className="flex flex-1 flex-col overflow-hidden bg-canvas">
      <ScreenHeader eyebrow="Smart Recipe" title="Dakgalbi" />

      <div className="flex-1 overflow-hidden px-3">
        <div className="rounded-[14px] bg-field px-3 py-2.5">
          <p className="text-[11.5px] leading-relaxed text-ink-2">
            &ldquo;Something spicy with the chicken in the fridge, 30 minutes&rdquo;
          </p>
        </div>

        <p className="mt-4 mb-2 px-1 text-[10px] font-semibold tracking-[0.12em] text-ink-3 uppercase">
          Ingredients
        </p>

        <div className="overflow-hidden rounded-[14px] bg-card ring-1 ring-line">
          {ingredients.map((item) => (
            <div
              key={item.name}
              className="flex items-center gap-2.5 border-b border-line px-3 py-2 last:border-b-0"
            >
              <span className={`h-[7px] w-[7px] shrink-0 rounded-full ${item.dot}`} aria-hidden="true" />
              <span className="flex-1 truncate text-[13px] text-ink">{item.name}</span>
            </div>
          ))}
        </div>

        <div className="mt-3 rounded-[10px] bg-teal py-2.5 text-center">
          <span className="text-[12.5px] font-semibold text-white">
            Add all 5 to a store list
          </span>
        </div>
      </div>

      <HomeBar />
    </div>
  );
}
