const categories = [
  {
    name: "Produce",
    icon: "🥬",
    items: [
      { name: "Bananas", checked: false, qty: 6 },
      { name: "Baby Spinach", checked: true, qty: 1 },
      { name: "Avocados", checked: false, qty: 3 },
    ],
  },
  {
    name: "Dairy",
    icon: "🥛",
    items: [
      { name: "Whole Milk", checked: false, qty: 1 },
      { name: "Greek Yogurt", checked: false, qty: 2 },
    ],
  },
  {
    name: "Bakery",
    icon: "🍞",
    items: [{ name: "Sourdough Bread", checked: true, qty: 1 }],
  },
];

export default function ReminderScreen() {
  return (
    <div
      className="flex-1 flex flex-col overflow-hidden"
      style={{
        background:
          "rgb(240,243,248)",
      }}
    >
      {/* Nav bar */}
      <div className="flex items-center justify-between px-4 pt-1 pb-2">
        <div className="flex items-center gap-1">
          <svg
            viewBox="0 0 24 24"
            className="w-[16px] h-[16px]"
            fill="#3B82F6"
          >
            <path d="M15.41 7.41L14 6l-6 6 6 6 1.41-1.41L10.83 12z" />
          </svg>
          <span className="text-[13px] text-blue-500">Stores</span>
        </div>
        <div className="flex items-center gap-3">
          <svg
            viewBox="0 0 24 24"
            className="w-[16px] h-[16px]"
            fill="#888"
          >
            <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-6h2v6zm0-8h-2V7h2v2z" />
          </svg>
          <svg viewBox="0 0 24 24" className="w-[16px] h-[16px]" fill="#888">
            <path d="M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z" />
          </svg>
        </div>
      </div>

      {/* Store title */}
      <div className="px-4 pb-2">
        <h2 className="text-[22px] font-bold text-black tracking-tight">
          Whole Foods
        </h2>
      </div>

      {/* Smart Category badge */}
      <div className="px-4 pb-2">
        <div className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-blue-500/10">
          <svg
            viewBox="0 0 24 24"
            className="w-[10px] h-[10px]"
            fill="#3B82F6"
          >
            <path d="M9.4 16.6L4.8 12l4.6-4.6L8 6l-6 6 6 6 1.4-1.4zm5.2 0l4.6-4.6-4.6-4.6L16 6l6 6-6 6-1.4-1.4z" />
          </svg>
          <span className="text-[9px] text-blue-500 font-medium">
            Smart Category On
          </span>
        </div>
      </div>

      {/* Category list */}
      <div className="flex-1 px-3 overflow-hidden space-y-1.5">
        {categories.map((cat) => (
          <div key={cat.name}>
            {/* Category header */}
            <div className="flex items-center gap-1.5 px-2 py-1">
              <span className="text-[10px]">{cat.icon}</span>
              <span className="text-[11px] font-semibold text-black/70 uppercase tracking-wider">
                {cat.name}
              </span>
              <div className="px-1.5 py-0 rounded-full bg-blue-500/70">
                <span className="text-[8px] font-medium text-white">
                  {cat.items.length}
                </span>
              </div>
              <svg
                viewBox="0 0 24 24"
                className="w-[10px] h-[10px] ml-auto"
                fill="#999"
              >
                <path d="M7.41 8.59L12 13.17l4.59-4.58L18 10l-6 6-6-6 1.41-1.41z" />
              </svg>
            </div>

            {/* Items */}
            {cat.items.map((item) => (
              <div
                key={item.name}
                className="flex items-center gap-2.5 px-3 py-2 rounded-2xl mb-1"
                style={{
                  background: "rgba(255,255,255,0.55)",
                  backdropFilter: "blur(20px)",
                  WebkitBackdropFilter: "blur(20px)",
                  border: "1.5px solid rgba(255,255,255,0.5)",
                  boxShadow:
                    "0 4px 8px rgba(0,0,0,0.08), 0 -2px 2px rgba(255,255,255,0.5)",
                }}
              >
                {/* Checkbox */}
                <svg
                  viewBox="0 0 24 24"
                  className="w-[18px] h-[18px] shrink-0"
                  fill={item.checked ? "#000" : "none"}
                  stroke={item.checked ? "none" : "#000"}
                  strokeWidth={item.checked ? 0 : 1.5}
                >
                  {item.checked ? (
                    <path d="M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm-9 14l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z" />
                  ) : (
                    <rect x="3" y="3" width="18" height="18" rx="2" />
                  )}
                </svg>

                {/* Item name */}
                <span
                  className={`text-[14px] flex-1 ${item.checked ? "line-through text-black/40" : "text-black/85"}`}
                >
                  {item.name}
                </span>

                {/* Quantity */}
                {item.qty > 1 && (
                  <span className="text-[10px] text-gray-400">
                    Qty: {item.qty}
                  </span>
                )}
              </div>
            ))}
          </div>
        ))}

        {/* Add item row */}
        <div
          className="flex items-center gap-2.5 px-3 py-2 rounded-2xl"
          style={{
            background: "rgba(255,255,255,0.3)",
            border: "1.5px dashed rgba(0,0,0,0.1)",
          }}
        >
          <svg
            viewBox="0 0 24 24"
            className="w-[18px] h-[18px]"
            fill="#9CA3AF"
          >
            <path d="M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z" />
          </svg>
          <span className="text-[14px] text-gray-400">Add item</span>
        </div>
      </div>

      {/* Home indicator */}
      <div className="flex justify-center py-2 bg-transparent">
        <div className="w-[100px] h-[4px] rounded-full bg-black/20" />
      </div>
    </div>
  );
}
