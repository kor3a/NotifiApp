import type { ReactNode } from "react";

/**
 * A store tile. Deliberately a monogram rather than a brand logo: the app talks
 * to whatever store you pin, so a real mark here would be both a trademark
 * problem and a lie about which four chains are supported. The fills are the
 * app's own avatar palette (AllimAvatarFill), every one of which carries white
 * type at 4.5:1.
 */
const STORE_FILLS: Record<string, string> = {
  Walmart: "bg-[#1F5490]",
  "Whole Foods": "bg-[#1C6640]",
  Costco: "bg-[#8A2F28]",
  Target: "bg-[#8A3660]",
  Kroger: "bg-[#075661]",
  Trader: "bg-[#7A5410]",
};

export function StoreLogo({
  name,
  size = 38,
}: {
  name: string;
  size?: number;
}) {
  const fill = STORE_FILLS[name] ?? STORE_FILLS[name.split(" ")[0]] ?? "bg-[#4A535B]";
  // Two initials for two-word names, so "Walmart" and "Whole Foods" don't both
  // come out as a bare W.
  const initials = name
    .split(" ")
    .slice(0, 2)
    .map((word) => word.charAt(0))
    .join("");

  return (
    <span
      className={`flex shrink-0 items-center justify-center rounded-[10px] font-bold tracking-[-0.02em] text-white ${fill}`}
      style={{
        width: size,
        height: size,
        fontSize: Math.round(size * (initials.length > 1 ? 0.34 : 0.42)),
      }}
      aria-hidden="true"
    >
      {initials}
    </span>
  );
}

/** The unread-count pill on a store row. Accent, as in the app. */
export function CountBadge({ n }: { n: number }) {
  return (
    <span className="flex h-[21px] min-w-[21px] items-center justify-center rounded-full bg-orange px-1.5 text-[11px] font-semibold text-white">
      {n}
    </span>
  );
}

/** An Allim push banner, drawn the way iOS stacks it over the screen. */
export function PushBanner({
  title,
  body,
  when = "now",
  className = "",
}: {
  title: string;
  body: string;
  when?: string;
  className?: string;
}) {
  return (
    <div
      className={`mx-2.5 flex items-start gap-2.5 rounded-[18px] bg-white p-2.5 shadow-[0_10px_28px_-8px_rgba(22,25,28,0.45)] ring-1 ring-black/5 backdrop-blur-xl ${className}`}
    >
      <img
        src="/allim-icon.svg"
        alt=""
        width="32"
        height="32"
        className="h-8 w-8 shrink-0 rounded-[8px]"
      />
      <div className="min-w-0 flex-1">
        <div className="flex items-baseline justify-between gap-2">
          <span className="text-[11px] font-semibold tracking-[0.02em] text-ink">Allim</span>
          <span className="text-[10px] text-ink-3">{when}</span>
        </div>
        <p className="mt-0.5 text-[12.5px] font-semibold leading-tight text-ink">{title}</p>
        <p className="mt-0.5 text-[11.5px] leading-snug text-ink-2">{body}</p>
      </div>
    </div>
  );
}

/** The screen's own title block — the large heading iOS puts above a list. */
export function ScreenHeader({
  eyebrow,
  title,
  trailing,
}: {
  eyebrow?: string;
  title: string;
  trailing?: ReactNode;
}) {
  return (
    <div className="flex items-end justify-between px-4 pb-3">
      <div>
        {eyebrow && <p className="text-[10.5px] text-ink-3">{eyebrow}</p>}
        <h3 className="text-[21px] font-bold tracking-[-0.02em] text-ink">{title}</h3>
      </div>
      {trailing}
    </div>
  );
}

/** iOS home indicator. */
export function HomeBar({ tone = "dark" }: { tone?: "dark" | "light" }) {
  return (
    <div className="flex justify-center py-2.5">
      <span
        className={`h-[4px] w-[96px] rounded-full ${
          tone === "light" ? "bg-white/45" : "bg-ink/20"
        }`}
      />
    </div>
  );
}

/** A grocery row, with the aisle dot the app files it under. */
export function GroceryRow({
  name,
  dot,
  by,
  checked = false,
}: {
  name: string;
  dot: string;
  by?: { initial: string; className: string };
  checked?: boolean;
}) {
  return (
    <div className="flex items-center gap-2.5 border-b border-line px-4 py-[9px] last:border-b-0">
      <span
        className={`h-[15px] w-[15px] shrink-0 rounded-full border-[1.5px] ${
          checked ? "border-teal bg-teal" : "border-line-strong"
        }`}
      />
      <span className={`h-[7px] w-[7px] shrink-0 rounded-full ${dot}`} aria-hidden="true" />
      <span
        className={`flex-1 truncate text-[13px] ${
          checked ? "text-ink-3 line-through" : "text-ink"
        }`}
      >
        {name}
      </span>
      {by && (
        <span
          className={`flex h-[18px] w-[18px] items-center justify-center rounded-full text-[9px] font-bold text-white ${by.className}`}
        >
          {by.initial}
        </span>
      )}
    </div>
  );
}
