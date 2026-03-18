export default function SmartRecipeScreen() {
  return (
    <div
      className="flex-1 flex flex-col overflow-hidden"
      style={{
        background:
          "linear-gradient(to bottom, rgb(242,245,250), rgb(224,235,245))",
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
          <span className="text-[13px] text-blue-500">Back</span>
        </div>
        <span className="text-[15px] font-semibold text-black">
          Smart Recipe
        </span>
        <div className="w-[40px]" />
      </div>

      {/* Chat area */}
      <div className="flex-1 px-3 overflow-hidden flex flex-col gap-2 py-2">
        {/* Welcome icon */}
        <div className="flex flex-col items-center pt-2 pb-1">
          <div
            className="w-[48px] h-[48px] rounded-full flex items-center justify-center mb-1.5"
            style={{
              background: "linear-gradient(135deg, #3B82F6, #8B5CF6)",
            }}
          >
            <span className="text-[22px]">🍳</span>
          </div>
          <p className="text-[14px] font-bold text-black">
            Smart Recipe Assistant
          </p>
          <p className="text-[10px] text-gray-500 text-center px-6 mt-0.5">
            Ask me for any recipe! I can help with meal ideas and more.
          </p>
        </div>

        {/* Suggestion chips */}
        <div className="flex flex-col gap-1.5 px-2">
          {[
            "Quick weeknight pasta dinner",
            "Healthy breakfast smoothie bowl",
            "Easy chocolate chip cookies",
          ].map((chip) => (
            <div
              key={chip}
              className="px-3 py-1.5 rounded-[16px] text-[11px] text-black/80"
              style={{
                background: "rgba(255,255,255,0.5)",
                backdropFilter: "blur(20px)",
                WebkitBackdropFilter: "blur(20px)",
                border: "1px solid rgba(59,130,246,0.25)",
              }}
            >
              {chip}
            </div>
          ))}
        </div>

        {/* User message bubble */}
        <div className="flex justify-end mt-1">
          <div className="max-w-[75%] px-3 py-2 rounded-2xl rounded-br-sm bg-blue-500 text-white text-[12px] leading-relaxed">
            Quick weeknight pasta dinner
          </div>
        </div>

        {/* Assistant reply */}
        <div className="flex justify-start">
          <div
            className="max-w-[80%] px-3 py-2 rounded-2xl rounded-bl-sm text-[12px] leading-relaxed text-black/85"
            style={{ background: "rgb(235,235,235)" }}
          >
            <p className="font-semibold mb-1">Garlic Butter Pasta</p>
            <p className="text-[10px] text-black/60 mb-1.5">
              Ready in 20 min — serves 4
            </p>
            <p className="text-[10.5px] leading-relaxed">
              1. Cook 400g spaghetti al dente
              <br />
              2. Saut&eacute; 4 minced garlic cloves in butter
              <br />
              3. Toss pasta with garlic butter
              <br />
              4. Add parmesan and fresh parsley
            </p>
          </div>
        </div>

        {/* Add ingredients button */}
        <div className="flex justify-start px-0">
          <div className="flex items-center gap-1 px-3 py-1.5 rounded-[16px] bg-blue-500 text-white">
            <svg
              viewBox="0 0 24 24"
              className="w-[11px] h-[11px]"
              fill="white"
            >
              <path d="M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z" />
            </svg>
            <span className="text-[10px] font-medium">
              Add 6 ingredients to store
            </span>
          </div>
        </div>
      </div>

      {/* Input bar */}
      <div
        className="flex items-center gap-2 px-3 py-2"
        style={{
          borderTop: "0.5px solid rgba(0,0,0,0.08)",
        }}
      >
        <div
          className="flex-1 flex items-center px-3 py-1.5 rounded-[16px]"
          style={{ background: "rgb(242,242,242)" }}
        >
          <span className="text-[12px] text-gray-400">
            Ask for a recipe...
          </span>
        </div>
        <svg viewBox="0 0 24 24" className="w-[26px] h-[26px]" fill="#D1D5DB">
          <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z" />
        </svg>
      </div>

      {/* Home indicator */}
      <div className="flex justify-center py-1.5">
        <div className="w-[100px] h-[4px] rounded-full bg-black/20" />
      </div>
    </div>
  );
}
