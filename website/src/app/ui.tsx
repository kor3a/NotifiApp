import { useEffect, type ButtonHTMLAttributes, type ReactNode } from "react";
import { cx } from "./format";

export function PageHeader({
  title,
  subtitle,
  actions,
  back,
}: {
  title: ReactNode;
  subtitle?: ReactNode;
  actions?: ReactNode;
  back?: { href: string; label: string };
}) {
  return (
    <header className="mb-6 flex flex-wrap items-end justify-between gap-4">
      <div className="min-w-0">
        {back && (
          <a
            href={back.href}
            className="mb-2 inline-flex items-center gap-1 text-[14px] font-medium text-teal hover:text-teal-deep"
          >
            <span aria-hidden>‹</span> {back.label}
          </a>
        )}
        <h1 className="display truncate text-[30px] leading-tight text-ink sm:text-[34px]">{title}</h1>
        {subtitle && <p className="mt-1 text-[15px] text-ink-2">{subtitle}</p>}
      </div>
      {actions && <div className="flex flex-wrap items-center gap-2">{actions}</div>}
    </header>
  );
}

type Variant = "primary" | "secondary" | "ghost" | "danger";

export function Button({
  variant = "primary",
  className,
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & { variant?: Variant }) {
  return (
    <button
      type="button"
      {...props}
      className={cx(
        "inline-flex items-center justify-center gap-1.5 rounded-full px-4 py-2 text-[14px] font-semibold transition-colors disabled:cursor-not-allowed disabled:opacity-50",
        variant === "primary" && "bg-teal text-white hover:bg-teal-deep",
        variant === "secondary" && "border border-line-strong bg-card text-ink hover:border-teal hover:text-teal",
        variant === "ghost" && "text-ink-2 hover:bg-kraft/60 hover:text-ink",
        variant === "danger" && "text-meat hover:bg-orange-wash",
        className,
      )}
    />
  );
}

export function Card({ className, children }: { className?: string; children: ReactNode }) {
  return (
    <div className={cx("rounded-2xl border border-line/80 bg-card shadow-[0_1px_0_rgba(22,25,28,0.04)]", className)}>
      {children}
    </div>
  );
}

export function TextInput(props: React.InputHTMLAttributes<HTMLInputElement>) {
  return (
    <input
      {...props}
      className={cx(
        "w-full rounded-xl border border-line bg-field/70 px-3.5 py-2.5 text-[15px] text-ink outline-none transition-colors placeholder:text-ink-3 focus:border-teal focus:bg-card",
        props.className,
      )}
    />
  );
}

export function Spinner({ label = "Loading…" }: { label?: string }) {
  return (
    <div className="flex items-center gap-3 py-10 text-[15px] text-ink-3" role="status">
      <span className="h-4 w-4 animate-spin rounded-full border-2 border-line-strong border-t-teal" />
      {label}
    </div>
  );
}

export function Empty({ title, children }: { title: string; children?: ReactNode }) {
  return (
    <div className="rounded-2xl border border-dashed border-line-strong bg-paper/60 px-6 py-12 text-center">
      <p className="hand text-[30px] leading-none text-pen">{title}</p>
      {children && <div className="mx-auto mt-3 max-w-sm text-[15px] text-ink-2">{children}</div>}
    </div>
  );
}

export function ErrorNote({ children }: { children: ReactNode }) {
  return (
    <p className="rounded-xl bg-orange-wash px-3.5 py-2.5 text-[14px] text-orange" role="alert">
      {children}
    </p>
  );
}

export function Modal({
  title,
  onClose,
  children,
}: {
  title: string;
  onClose: () => void;
  children: ReactNode;
}) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && onClose();
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);
  return (
    <div
      className="fixed inset-0 z-50 flex items-end justify-center bg-ink/30 p-4 backdrop-blur-[2px] sm:items-center"
      onMouseDown={(e) => e.target === e.currentTarget && onClose()}
    >
      <div role="dialog" aria-modal="true" aria-label={title} className="w-full max-w-md rounded-2xl bg-card p-5 shadow-xl">
        <div className="mb-4 flex items-center justify-between">
          <h2 className="text-[19px] font-bold text-ink">{title}</h2>
          <button type="button" onClick={onClose} className="-mr-1 h-8 w-8 rounded-full text-[20px] text-ink-3 hover:bg-field" aria-label="Close">
            ×
          </button>
        </div>
        {children}
      </div>
    </div>
  );
}

const AVATAR_HUES = ["#0b7285", "#3fa96b", "#4c8dd6", "#c4574f", "#b98a5a", "#c08a22", "#c96a93", "#8a7bc8"];

/** Profile photo if there is one, else initials on a hue picked from the name so it's stable. */
export function Avatar({ name, url, size = 40 }: { name: string; url?: string; size?: number }) {
  const initials = name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((w) => w[0]!.toUpperCase())
    .join("");
  const hue = AVATAR_HUES[[...name].reduce((h, c) => h + c.charCodeAt(0), 0) % AVATAR_HUES.length];
  if (url) {
    return (
      <img
        src={url}
        alt=""
        width={size}
        height={size}
        className="shrink-0 rounded-full object-cover"
        style={{ width: size, height: size }}
      />
    );
  }
  return (
    <span
      aria-hidden
      className="flex shrink-0 items-center justify-center rounded-full font-bold text-white"
      style={{ width: size, height: size, background: hue, fontSize: size * 0.38 }}
    >
      {initials || "?"}
    </span>
  );
}

/** Logo from stores_logos when one exists; otherwise a monogram tile, like the marketing site. */
export function StoreLogo({ name, url, size = 48 }: { name: string; url?: string; size?: number }) {
  if (url) {
    return (
      <span
        className="flex shrink-0 items-center justify-center overflow-hidden rounded-xl border border-line/70 bg-white"
        style={{ width: size, height: size }}
      >
        <img src={url} alt="" className="h-full w-full object-contain p-1" />
      </span>
    );
  }
  return (
    <span
      aria-hidden
      className="flex shrink-0 items-center justify-center rounded-xl bg-wash font-extrabold text-on-wash"
      style={{ width: size, height: size, fontSize: size * 0.4 }}
    >
      {name.trim()[0]?.toUpperCase() ?? "?"}
    </span>
  );
}
