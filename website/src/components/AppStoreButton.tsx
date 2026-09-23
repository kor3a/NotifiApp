import { APP_STORE_URL } from "../constants/links";

/**
 * Black like Apple's own badge, with a hard offset shadow it lifts off on
 * hover, the way a sticker peels up at the corner. No gradient, no glow.
 */
export default function AppStoreButton({
  children = "Download on the App Store",
  tone = "teal",
  className = "",
}: {
  children?: React.ReactNode;
  tone?: "teal" | "wash";
  className?: string;
}) {
  const tones = {
    teal: "bg-ink text-white shadow-[0_4px_0_var(--color-teal)] hover:shadow-[0_7px_0_var(--color-teal)]",
    wash: "bg-white text-ink shadow-[0_4px_0_var(--color-teal-night)] hover:shadow-[0_7px_0_var(--color-teal-night)]",
  } as const;

  return (
    <a
      href={APP_STORE_URL}
      target="_blank"
      rel="noopener noreferrer"
      className={`inline-flex items-center gap-2.5 rounded-full px-7 py-4 text-[15px] font-semibold transition-[transform,box-shadow] duration-200 hover:-translate-y-[3px] active:translate-y-[2px] active:shadow-none ${tones[tone]} ${className}`}
    >
      <svg className="h-[18px] w-[18px]" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
        <path d="M18.71 19.5C17.88 20.74 17 21.95 15.66 21.97C14.32 21.99 13.89 21.18 12.37 21.18C10.84 21.18 10.37 21.95 9.09997 21.99C7.78997 22.03 6.79997 20.68 5.95997 19.47C4.24997 17 2.93997 12.45 4.69997 9.39C5.56997 7.87 7.12997 6.91 8.81997 6.88C10.1 6.86 11.32 7.75 12.11 7.75C12.89 7.75 14.37 6.68 15.92 6.84C16.57 6.87 18.39 7.1 19.56 8.82C19.47 8.88 17.39 10.1 17.41 12.63C17.44 15.65 20.06 16.66 20.09 16.67C20.06 16.74 19.67 18.11 18.71 19.5ZM13 3.5C13.73 2.67 14.94 2.04 15.94 2C16.07 3.17 15.6 4.35 14.9 5.19C14.21 6.04 13.07 6.7 11.95 6.61C11.8 5.46 12.36 4.26 13 3.5Z" />
      </svg>
      {children}
    </a>
  );
}
