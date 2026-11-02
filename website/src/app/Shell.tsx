import type { ReactNode } from "react";
import { useConversations, useFriendships } from "./data";
import { href, type Route } from "./router";
import { logOut, useUser } from "./auth";
import { cx } from "./format";
import { Avatar } from "./ui";

type Tab = { route: Route; label: string; icon: ReactNode; badge?: number };

/** Simple line glyphs, drawn to sit with the app's OrganicTabBar rather than an icon set. */
const icon = (d: string) => (
  <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
    <path d={d} />
  </svg>
);
const ICONS = {
  stores: icon("M4 10h16l-1.2-5H5.2L4 10Zm1 0v9h14v-9M9 19v-5h6v5"),
  friends: icon("M9 11a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7Zm-6 9c.6-3.4 3-5 6-5s5.4 1.6 6 5m1-9a3 3 0 1 0 0-6m2 15c-.3-2-1.3-3.4-2.8-4.2"),
  messages: icon("M4 5h16v11H9l-5 4V5Z"),
  ai: icon("M12 3l1.8 4.7L18.5 9.5l-4.7 1.8L12 16l-1.8-4.7L5.5 9.5l4.7-1.8L12 3Zm6 11 .9 2.1L21 17l-2.1.9L18 20l-.9-2.1L15 17l2.1-.9L18 14Z"),
  recipes: icon("M6 3h11a1 1 0 0 1 1 1v17l-3-2-3 2-3-2-3 2V4a1 1 0 0 1 1-1Zm3 5h6M9 12h6"),
  profile: icon("M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8Zm-7 9c.8-4 3.6-6 7-6s6.2 2 7 6"),
};

function isActive(tab: Route, current: Route) {
  if (tab.name === "stores") return current.name === "stores" || current.name === "reminders";
  return tab.name === current.name;
}

export default function Shell({ route, children }: { route: Route; children: ReactNode }) {
  const user = useUser();
  const friends = useFriendships(user.userId);
  const conversations = useConversations(user.userId);

  const pendingRequests = friends.data.filter(
    (f) => f.status === "pending" && f.receiverId === user.userId,
  ).length;
  const unread = conversations.data.reduce((n, c) => n + (c.unreadCount?.[user.userId] ?? 0), 0);

  const tabs: Tab[] = [
    { route: { name: "stores" }, label: "Stores", icon: ICONS.stores },
    { route: { name: "friends" }, label: "Friends", icon: ICONS.friends, badge: pendingRequests },
    { route: { name: "messages" }, label: "Messages", icon: ICONS.messages, badge: unread },
    { route: { name: "ai-recipe" }, label: "AI Recipe", icon: ICONS.ai },
    { route: { name: "recipes" }, label: "My Recipes", icon: ICONS.recipes },
    { route: { name: "profile" }, label: "Profile", icon: ICONS.profile },
  ];

  return (
    <div className="min-h-screen lg:flex">
      {/* Sidebar at lg+, bottom tab bar below it — the phone app's layout, widened. */}
      <aside className="sticky top-0 hidden h-screen w-64 shrink-0 flex-col border-r border-line/80 bg-paper/80 px-4 py-6 lg:flex">
        <a href="/" className="mb-8 flex items-center gap-2.5 px-2" title="Back to allimapp.com">
          <img src="/allim-icon.svg" alt="" width="32" height="32" className="h-8 w-8 rounded-[7px]" />
          <span className="text-[22px] font-extrabold tracking-[-0.03em] text-ink">Allim</span>
          <span className="mono ml-auto rounded bg-tag px-1.5 py-0.5 text-[10px] font-semibold text-ink">DEV</span>
        </a>
        <nav className="flex flex-col gap-1">
          {tabs.map((t) => (
            <a
              key={t.label}
              href={href(t.route)}
              className={cx(
                "flex items-center gap-3 rounded-xl px-3 py-2.5 text-[15px] font-medium transition-colors",
                isActive(t.route, route) ? "bg-wash text-on-wash" : "text-ink-2 hover:bg-kraft/50 hover:text-ink",
              )}
            >
              {t.icon}
              {t.label}
              {!!t.badge && (
                <span className="ml-auto min-w-5 rounded-full bg-orange px-1.5 text-center text-[12px] font-bold leading-5 text-white">
                  {t.badge}
                </span>
              )}
            </a>
          ))}
        </nav>
        <div className="mt-auto flex items-center gap-3 rounded-xl border border-line/80 bg-card p-3">
          <Avatar name={user.name} url={user.profilePictureURL} size={36} />
          <div className="min-w-0 flex-1">
            <p className="truncate text-[14px] font-semibold text-ink">{user.name}</p>
            <p className="truncate text-[12px] text-ink-3">@{user.userId}</p>
          </div>
          <button type="button" onClick={logOut} className="text-[12px] font-semibold text-ink-3 hover:text-meat">
            Sign out
          </button>
        </div>
      </aside>

      <main className="min-w-0 flex-1 px-4 pb-28 pt-6 sm:px-8 lg:pb-12 lg:pt-10">
        <div className="mx-auto max-w-4xl">{children}</div>
      </main>

      <nav className="fixed inset-x-0 bottom-0 z-40 border-t border-line/80 bg-paper/95 backdrop-blur lg:hidden">
        <div className="mx-auto flex max-w-xl justify-between px-1 pb-[max(env(safe-area-inset-bottom),6px)] pt-1.5">
          {tabs.map((t) => (
            <a
              key={t.label}
              href={href(t.route)}
              className={cx(
                "relative flex flex-1 flex-col items-center gap-0.5 rounded-lg py-1 text-[10.5px] font-semibold",
                isActive(t.route, route) ? "text-teal" : "text-ink-3",
              )}
            >
              {t.icon}
              {t.label}
              {!!t.badge && (
                <span className="absolute right-[18%] top-0 min-w-4 rounded-full bg-orange px-1 text-center text-[10px] leading-4 text-white">
                  {t.badge}
                </span>
              )}
            </a>
          ))}
        </div>
      </nav>
    </div>
  );
}
