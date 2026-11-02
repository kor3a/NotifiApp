export function cx(...parts: (string | false | null | undefined)[]) {
  return parts.filter(Boolean).join(" ");
}

/** The app's aisle hues (AllimColors.swift), keyed by the categories Smart Category assigns. */
const CATEGORY_HUES: Record<string, string> = {
  Produce: "var(--color-produce)",
  Dairy: "var(--color-dairy)",
  "Meat & Seafood": "var(--color-meat)",
  Bakery: "var(--color-bakery)",
  "Canned Goods": "var(--color-pantry)",
  "Grains & Pasta": "var(--color-pantry)",
  "Condiments & Sauces": "var(--color-pantry)",
  Frozen: "var(--color-frozen)",
  Beverages: "var(--color-beverages)",
  Snacks: "var(--color-snacks)",
  Household: "var(--color-household)",
};

export function categoryHue(category?: string) {
  return (category && CATEGORY_HUES[category]) || "var(--color-ink-3)";
}

export function timeAgo(seconds?: number): string {
  if (!seconds) return "";
  const diff = Date.now() / 1000 - seconds;
  if (diff < 60) return "just now";
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  if (diff < 86400 * 7) return `${Math.floor(diff / 86400)}d ago`;
  return new Date(seconds * 1000).toLocaleDateString(undefined, { month: "short", day: "numeric" });
}
