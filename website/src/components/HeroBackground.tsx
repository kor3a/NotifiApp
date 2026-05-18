/**
 * Hero background: a looping <video> overlaid on top of an animated aurora
 * gradient fallback. Drop a file at `website/public/hero-map.mp4` and it
 * covers the animation. Until then (or if the video fails to load) the
 * animated gradient shows through.
 */
export default function HeroBackground() {
  return (
    <div className="absolute inset-0 z-0 overflow-hidden bg-allim-dark">
      {/* Animated aurora fallback */}
      <div className="absolute inset-0">
        <div className="animate-aurora-1 absolute -top-1/3 -left-1/4 h-[70vw] w-[70vw] rounded-full bg-allim-blue/30 blur-[120px]" />
        <div className="animate-aurora-2 absolute top-1/4 -right-1/4 h-[65vw] w-[65vw] rounded-full bg-allim-purple/30 blur-[130px]" />
        <div className="animate-aurora-3 absolute -bottom-1/3 left-1/4 h-[55vw] w-[55vw] rounded-full bg-allim-indigo/25 blur-[120px]" />

        {/* Subtle panning grid for depth */}
        <div
          className="animate-grid-pan absolute inset-0 opacity-[0.07]"
          style={{
            backgroundImage:
              "linear-gradient(rgba(255,255,255,0.6) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.6) 1px, transparent 1px)",
            backgroundSize: "56px 56px",
            maskImage:
              "radial-gradient(ellipse at center, black 30%, transparent 75%)",
            WebkitMaskImage:
              "radial-gradient(ellipse at center, black 30%, transparent 75%)",
          }}
        />
      </div>

      {/* Looping background video (covers the animation once provided) */}
      <video
        className="absolute inset-0 h-full w-full object-cover"
        autoPlay
        loop
        muted
        playsInline
        preload="auto"
      >
        <source src="/hero-map.mp4" type="video/mp4" />
        <source src="/hero-map.webm" type="video/webm" />
      </video>

      {/* Readability scrim */}
      <div className="absolute inset-0 bg-gradient-to-b from-allim-dark/60 via-allim-dark/40 to-allim-dark/80" />
    </div>
  );
}
