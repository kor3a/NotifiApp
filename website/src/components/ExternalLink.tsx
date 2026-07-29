import type { MouseEvent, ReactNode } from "react";

// Social apps open links inside their own embedded web view (WKWebView on iOS,
// Android WebView) rather than Safari/Chrome. Those views have no concept of a
// second tab, so they drop `target="_blank"` silently: the user taps the App
// Store button and absolutely nothing happens.
const IN_APP_BROWSER =
  /Instagram|FBAN|FBAV|FB_IAB|FBIOS|Messenger|Threads|TikTok|BytedanceWebview|Snapchat|Pinterest|LinkedInApp|Line\/|KAKAOTALK|NAVER|WhatsApp/i;

function isInAppBrowser() {
  return (
    typeof navigator !== "undefined" && IN_APP_BROWSER.test(navigator.userAgent)
  );
}

type ExternalLinkProps = {
  href: string;
  className?: string;
  onClick?: () => void;
  children: ReactNode;
};

// An outbound link that also works inside social in-app browsers, where it
// navigates the current view instead of trying to open a tab that can't exist.
export default function ExternalLink({
  href,
  className,
  onClick,
  children,
}: ExternalLinkProps) {
  function handleClick(event: MouseEvent<HTMLAnchorElement>) {
    onClick?.();

    if (isInAppBrowser()) {
      event.preventDefault();
      window.location.href = href;
    }
  }

  return (
    <a
      href={href}
      target="_blank"
      rel="noopener noreferrer"
      className={className}
      onClick={handleClick}
    >
      {children}
    </a>
  );
}
