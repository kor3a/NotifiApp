export default function Footer() {
  return (
    <footer className="bg-allim-dark border-t border-white/5 py-12">
      <div className="max-w-7xl mx-auto px-6">
        <div className="flex flex-col md:flex-row items-center justify-between gap-6">
          <div className="flex items-center gap-2">
            <img
              src="/allimIcon.png"
              alt="Allim"
              className="w-8 h-8 rounded-xl"
            />
            <span className="text-white font-semibold text-lg">Allim</span>
          </div>

          <div className="flex items-center gap-8">
            <a
              href="#features"
              className="text-sm text-allim-muted hover:text-white transition-colors"
            >
              Features
            </a>
            <a
              href="#how-it-works"
              className="text-sm text-allim-muted hover:text-white transition-colors"
            >
              How It Works
            </a>
            <a
              href="#smart"
              className="text-sm text-allim-muted hover:text-white transition-colors"
            >
              Smart Tools
            </a>
            <a
              href="#download"
              className="text-sm text-allim-muted hover:text-white transition-colors"
            >
              Download
            </a>
            <a
              href="/support"
              className="text-sm text-allim-muted hover:text-white transition-colors"
            >
              Support
            </a>
          </div>

          <p className="text-sm text-allim-muted">
            &copy; {new Date().getFullYear()} Allim. All rights reserved.
          </p>
        </div>
      </div>
    </footer>
  );
}
