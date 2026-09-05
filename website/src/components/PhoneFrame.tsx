import type { CSSProperties, ReactNode } from "react";

interface Props {
  children: ReactNode;
  className?: string;
  screenClassName?: string;
  screenBackgroundClassName?: string;
  screenBackgroundStyle?: CSSProperties;
  statusBarTone?: "dark" | "light";
  /** Rendered above the screen, inside the bezel — notification banners and
   *  anything else that should overlap what's on screen. */
  overlay?: ReactNode;
  /**
   * Draw the status bar and Dynamic Island. Off when the screen is a real
   * device screenshot, which carries its own — two would be one too many.
   */
  chrome?: boolean;
  /** Outer bezel size. Defaults suit the hand-built screens; a real screenshot
   *  passes its own so the image isn't stretched to a different aspect. */
  width?: number;
  height?: number;
}

export default function PhoneFrame({
  children,
  className = "",
  screenClassName,
  screenBackgroundClassName = "bg-canvas",
  screenBackgroundStyle,
  statusBarTone = "dark",
  overlay,
  chrome = true,
  width = 274,
  height = 560,
}: Props) {
  const light = statusBarTone === "light";
  const tone = light ? "text-white/90" : "text-ink/80";
  const batteryEdge = light ? "border-white/45" : "border-ink/30";
  const batteryFill = light ? "bg-white/90" : "bg-ink/80";
  const batteryCap = light ? "bg-white/45" : "bg-ink/30";

  // Only the drawn status bar needs the screen inset below it.
  const inset = screenClassName ?? (chrome ? "pt-9" : "");

  return (
    <div className={`relative mx-auto ${className}`} style={{ width, height }}>
      <div className="absolute inset-0 rounded-[42px] bg-ink shadow-[0_18px_40px_-16px_rgba(22,25,28,0.35)]">
        <div
          className={`absolute inset-[3px] overflow-hidden rounded-[39px] ${screenBackgroundClassName}`}
          style={screenBackgroundStyle}
        >
          <div className="relative flex h-full w-full flex-col">
            <div className={`absolute inset-0 flex flex-col ${inset}`}>{children}</div>

            {chrome && (
              <div className="pointer-events-none relative z-20 flex items-center justify-between px-6 pt-3 pb-1">
                <span className={`text-[11px] font-semibold ${tone}`}>9:41</span>
                <div className="absolute left-1/2 top-2 h-[26px] w-[88px] -translate-x-1/2 rounded-full bg-ink" />
                <div className={`flex items-center gap-1 ${tone}`}>
                  <svg className="h-[10px] w-[14px]" viewBox="0 0 16 12" fill="currentColor" aria-hidden="true">
                    <rect x="0" y="5" width="3" height="7" rx="0.5" />
                    <rect x="4.5" y="3" width="3" height="9" rx="0.5" />
                    <rect x="9" y="1" width="3" height="11" rx="0.5" />
                    <rect x="13" y="0" width="3" height="12" rx="0.5" />
                  </svg>
                  <svg className="h-[10px] w-[12px]" viewBox="0 0 16 12" fill="currentColor" aria-hidden="true">
                    <path d="M8 3C10.7 3 13.1 4.3 14.5 6.3L16 4.5C14.1 2 11.2 0.5 8 0.5S1.9 2 0 4.5L1.5 6.3C2.9 4.3 5.3 3 8 3z" />
                    <path d="M8 6.5C9.8 6.5 11.4 7.4 12.3 8.7L13.8 6.9C12.5 5.2 10.4 4 8 4S3.5 5.2 2.2 6.9L3.7 8.7C4.6 7.4 6.2 6.5 8 6.5z" />
                    <circle cx="8" cy="11" r="1.5" />
                  </svg>
                  <div className={`relative ml-0.5 h-[10px] w-[22px] rounded-[2px] border ${batteryEdge}`}>
                    <div className={`absolute inset-[1.5px] right-[2px] rounded-[1px] ${batteryFill}`} />
                    <div className={`absolute right-[-3px] top-[2.5px] h-[5px] w-[1.5px] rounded-r-sm ${batteryCap}`} />
                  </div>
                </div>
              </div>
            )}

            {overlay && <div className="absolute inset-x-0 top-0 z-30">{overlay}</div>}
          </div>
        </div>
      </div>
    </div>
  );
}
