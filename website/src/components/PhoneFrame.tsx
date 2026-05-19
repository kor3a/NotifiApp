import type { ReactNode } from "react";

interface Props {
  children: ReactNode;
  className?: string;
  screenClassName?: string;
}

export default function PhoneFrame({
  children,
  className = "",
  screenClassName = "pt-9",
}: Props) {
  return (
    <div className={`relative w-[280px] h-[572px] mx-auto ${className}`}>
      {/* Outer bezel */}
      <div className="absolute inset-0 rounded-[44px] bg-[#1a1a1e] shadow-[0_25px_60px_rgba(0,0,0,0.5)]">
        {/* Inner screen */}
        <div className="absolute inset-[3px] rounded-[41px] overflow-hidden bg-slate-50">
          {/* Screen content */}
          <div className="w-full h-full flex flex-col relative">
            <div className={`absolute inset-0 flex flex-col ${screenClassName}`}>
              {children}
            </div>

            {/* Status bar */}
            <div className="flex justify-between items-center px-6 pt-3 pb-1 relative z-20 pointer-events-none">
              <span className="text-[11px] font-semibold text-black/80">
                9:41
              </span>
              <div className="w-[90px] h-[26px] bg-black rounded-full absolute left-1/2 -translate-x-1/2 top-2" />
              <div className="flex items-center gap-1">
                <svg className="w-[14px] h-[10px]" viewBox="0 0 16 12" fill="black" opacity="0.8">
                  <rect x="0" y="5" width="3" height="7" rx="0.5" />
                  <rect x="4.5" y="3" width="3" height="9" rx="0.5" />
                  <rect x="9" y="1" width="3" height="11" rx="0.5" />
                  <rect x="13" y="0" width="3" height="12" rx="0.5" />
                </svg>
                <svg className="w-[12px] h-[10px]" viewBox="0 0 16 12" fill="black" opacity="0.8">
                  <path d="M8 3C10.7 3 13.1 4.3 14.5 6.3L16 4.5C14.1 2 11.2 0.5 8 0.5S1.9 2 0 4.5L1.5 6.3C2.9 4.3 5.3 3 8 3z" />
                  <path d="M8 6.5C9.8 6.5 11.4 7.4 12.3 8.7L13.8 6.9C12.5 5.2 10.4 4 8 4S3.5 5.2 2.2 6.9L3.7 8.7C4.6 7.4 6.2 6.5 8 6.5z" />
                  <circle cx="8" cy="11" r="1.5" />
                </svg>
                <div className="w-[22px] h-[10px] rounded-[2px] border border-black/30 relative ml-0.5">
                  <div className="absolute inset-[1.5px] right-[2px] bg-black/80 rounded-[1px]" />
                  <div className="absolute right-[-3px] top-[2.5px] w-[1.5px] h-[5px] bg-black/30 rounded-r-sm" />
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
