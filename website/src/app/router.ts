import { useEffect, useState } from "react";

/**
 * Hash routes (#/stores, #/stores/<userStoreId>, #/messages/<conversationId>, …).
 * Hash routing keeps every URL on /app/ so Vite's dev server never has to
 * resolve a deep path, and a reload lands on the same screen.
 */
export type Route =
  | { name: "stores" }
  | { name: "reminders"; userStoreId: string }
  | { name: "friends" }
  | { name: "messages"; conversationId?: string }
  | { name: "ai-recipe" }
  | { name: "recipes" }
  | { name: "profile" };

function parse(hash: string): Route {
  const [section, id] = hash.replace(/^#\/?/, "").split("/");
  switch (section) {
    case "stores":
      return id ? { name: "reminders", userStoreId: decodeURIComponent(id) } : { name: "stores" };
    case "friends":
      return { name: "friends" };
    case "messages":
      return { name: "messages", conversationId: id ? decodeURIComponent(id) : undefined };
    case "ai-recipe":
      return { name: "ai-recipe" };
    case "recipes":
      return { name: "recipes" };
    case "profile":
      return { name: "profile" };
    default:
      return { name: "stores" };
  }
}

export function useRoute(): Route {
  const [route, setRoute] = useState(() => parse(window.location.hash));
  useEffect(() => {
    const onChange = () => setRoute(parse(window.location.hash));
    window.addEventListener("hashchange", onChange);
    return () => window.removeEventListener("hashchange", onChange);
  }, []);
  return route;
}

export function href(route: Route): string {
  switch (route.name) {
    case "reminders":
      return `#/stores/${encodeURIComponent(route.userStoreId)}`;
    case "messages":
      return route.conversationId ? `#/messages/${encodeURIComponent(route.conversationId)}` : "#/messages";
    default:
      return `#/${route.name}`;
  }
}

export function navigate(route: Route) {
  window.location.hash = href(route);
}
