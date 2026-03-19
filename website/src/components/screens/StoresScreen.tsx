const stores = [
  {
    name: "Whole Foods",
    letter: "W",
    gradientFrom: "#34D399",
    gradientTo: "#059669",
    reminders: 5,
    shared: true,
  },
  {
    name: "Target",
    letter: "T",
    gradientFrom: "#F87171",
    gradientTo: "#DC2626",
    reminders: 3,
    shared: false,
  },
  {
    name: "Costco",
    letter: "C",
    gradientFrom: "#60A5FA",
    gradientTo: "#2563EB",
    reminders: 8,
    shared: true,
  },
  {
    name: "Trader Joe's",
    letter: "T",
    gradientFrom: "#FBBF24",
    gradientTo: "#D97706",
    reminders: 0,
    shared: false,
  },
];

const tabs = [
  { icon: "storefront", label: "Stores", active: true },
  { icon: "message", label: "Messages", active: false, badge: 2 },
  { icon: "friends", label: "Friends", active: false },
  { icon: "map", label: "Search", active: false },
];

function StorefrontIcon() {
  return (
    <svg viewBox="0 0 24 24" className="w-[18px] h-[18px]" fill="currentColor">
      <path d="M4 7h16v2H4zm0 4h16v2H4zm2 4h12v4H6zm-2-2h16v8H4z" opacity="0" />
      <path d="M20 4H4v2h16V4zm1 10v-2l-1-5H4l-1 5v2h1v6h10v-6h4v6h2v-6h1zm-9 4H6v-4h6v4z" />
    </svg>
  );
}

function MessageIcon() {
  return (
    <svg viewBox="0 0 24 24" className="w-[18px] h-[18px]" fill="currentColor">
      <path d="M20 2H4c-1.1 0-2 .9-2 2v18l4-4h14c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2z" />
    </svg>
  );
}

function FriendsIcon() {
  return (
    <svg viewBox="0 0 24 24" className="w-[18px] h-[18px]" fill="currentColor">
      <path d="M16 11c1.66 0 2.99-1.34 2.99-3S17.66 5 16 5c-1.66 0-3 1.34-3 3s1.34 3 3 3zm-8 0c1.66 0 2.99-1.34 2.99-3S9.66 5 8 5C6.34 5 5 6.34 5 8s1.34 3 3 3zm0 2c-2.33 0-7 1.17-7 3.5V19h14v-2.5c0-2.33-4.67-3.5-7-3.5zm8 0c-.29 0-.62.02-.97.05 1.16.84 1.97 1.97 1.97 3.45V19h6v-2.5c0-2.33-4.67-3.5-7-3.5z" />
    </svg>
  );
}

function MapIcon() {
  return (
    <svg viewBox="0 0 24 24" className="w-[18px] h-[18px]" fill="currentColor">
      <path d="M20.5 3l-.16.03L15 5.1 9 3 3.36 4.9c-.21.07-.36.25-.36.48V20.5c0 .28.22.5.5.5l.16-.03L9 18.9l6 2.1 5.64-1.9c.21-.07.36-.25.36-.48V3.5c0-.28-.22-.5-.5-.5zM15 19l-6-2.11V5l6 2.11V19z" />
    </svg>
  );
}

export default function StoresScreen() {
  return (
    <div
      className="flex-1 flex flex-col relative overflow-hidden"
      style={{
        background:
          "linear-gradient(to bottom, rgb(242,245,250), rgb(224,235,245))",
      }}
    >
      {/* Navigation title */}
      <div className="px-4 pt-1 pb-2">
        <p className="text-[11px] text-black/40">Good morning</p>
        <div className="flex items-center justify-between">
          <h2 className="text-[22px] font-bold text-black tracking-tight">
            Hi, Sarah
          </h2>
          <div className="flex items-center gap-3">
            <svg viewBox="0 0 24 24" className="w-[18px] h-[18px]" fill="#888">
              <path d="M3 18h6v-2H3v2zM3 6v2h18V6H3zm0 7h12v-2H3v2z" />
            </svg>
            <svg viewBox="0 0 24 24" className="w-[18px] h-[18px]" fill="#888">
              <path d="M4 8h4V4H4v4zm6 12h4v-4h-4v4zm-6 0h4v-4H4v4zm0-6h4v-4H4v4zm6 0h4v-4h-4v4zm6-10v4h4V4h-4zm-6 4h4V4h-4v4zm6 6h4v-4h-4v4zm0 6h4v-4h-4v4z" />
            </svg>
          </div>
        </div>
      </div>

      {/* Store list */}
      <div className="flex-1 px-3 space-y-2 overflow-hidden">
        {stores.map((store) => (
          <div
            key={store.name}
            className="flex items-center gap-3 px-3 py-2.5 rounded-2xl relative"
            style={{
              background: "rgba(255,255,255,0.55)",
              backdropFilter: "blur(20px)",
              WebkitBackdropFilter: "blur(20px)",
              border: "1.5px solid rgba(255,255,255,0.5)",
              boxShadow:
                "0 4px 8px rgba(0,0,0,0.08), 0 -2px 2px rgba(255,255,255,0.5)",
            }}
          >
            {/* Store logo circle */}
            <div
              className="w-[42px] h-[42px] rounded-full flex items-center justify-center shrink-0"
              style={{
                background: `linear-gradient(135deg, ${store.gradientFrom}, ${store.gradientTo})`,
                border: "1px solid rgba(255,255,255,0.3)",
              }}
            >
              <span className="text-white text-[16px] font-bold">
                {store.letter}
              </span>
            </div>

            {/* Store name */}
            <span className="text-[15px] text-black/90 flex-1">
              {store.name}
            </span>

            {/* Shared icon */}
            {store.shared && (
              <svg
                viewBox="0 0 24 24"
                className="w-[13px] h-[13px]"
                fill="#3B82F6"
              >
                <path d="M16 11c1.66 0 2.99-1.34 2.99-3S17.66 5 16 5c-1.66 0-3 1.34-3 3s1.34 3 3 3zm-8 0c1.66 0 2.99-1.34 2.99-3S9.66 5 8 5C6.34 5 5 6.34 5 8s1.34 3 3 3zm0 2c-2.33 0-7 1.17-7 3.5V19h14v-2.5c0-2.33-4.67-3.5-7-3.5zm8 0c-.29 0-.62.02-.97.05 1.16.84 1.97 1.97 1.97 3.45V19h6v-2.5c0-2.33-4.67-3.5-7-3.5z" />
              </svg>
            )}

            {/* Reminder badge */}
            {store.reminders > 0 && (
              <div className="w-[22px] h-[22px] rounded-full bg-red-500 flex items-center justify-center">
                <span className="text-white text-[11px] font-semibold">
                  {store.reminders}
                </span>
              </div>
            )}
          </div>
        ))}
      </div>

      {/* FAB */}
      <div className="absolute bottom-14 right-4">
        <div className="w-[50px] h-[50px] rounded-full bg-blue-500 flex items-center justify-center shadow-[0_4px_8px_rgba(0,0,0,0.25)]">
          <svg viewBox="0 0 24 24" className="w-5 h-5" fill="white">
            <path d="M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z" />
          </svg>
        </div>
      </div>

      {/* Tab bar */}
      <div
        className="flex items-center justify-around px-2 py-1.5 mt-auto"
        style={{
          background: "rgba(255,255,255,0.65)",
          backdropFilter: "blur(20px)",
          WebkitBackdropFilter: "blur(20px)",
          borderTop: "0.5px solid rgba(0,0,0,0.1)",
        }}
      >
        {tabs.map((tab) => (
          <div
            key={tab.label}
            className="flex flex-col items-center gap-0.5 relative"
          >
            <div className="relative">
              <span className={tab.active ? "text-blue-500" : "text-gray-400"}>
                {tab.icon === "storefront" && <StorefrontIcon />}
                {tab.icon === "message" && <MessageIcon />}
                {tab.icon === "friends" && <FriendsIcon />}
                {tab.icon === "map" && <MapIcon />}
              </span>
              {tab.badge && (
                <div className="absolute -top-1.5 -right-2.5 w-[14px] h-[14px] rounded-full bg-red-500 flex items-center justify-center">
                  <span className="text-white text-[8px] font-bold">
                    {tab.badge}
                  </span>
                </div>
              )}
            </div>
            <span
              className={`text-[9px] ${tab.active ? "text-blue-500" : "text-gray-400"}`}
            >
              {tab.label}
            </span>
          </div>
        ))}
      </div>

      {/* Home indicator */}
      <div className="flex justify-center pb-1 bg-transparent">
        <div className="w-[100px] h-[4px] rounded-full bg-black/20" />
      </div>
    </div>
  );
}
