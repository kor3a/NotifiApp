import { useState } from "react";
import { Menu, X } from "lucide-react";

export default function Navbar() {
  const [open, setOpen] = useState(false);

  return (
    <nav className="fixed top-0 left-0 right-0 z-50 bg-allim-dark/80 backdrop-blur-xl border-b border-white/5">
      <div className="max-w-7xl mx-auto px-6 h-16 flex items-center justify-between">
        <a href="#" className="flex items-center gap-2">
          <img
            src="/allimIcon.svg"
            alt="Allim"
            className="w-9 h-9 rounded-xl"
          />
          <span className="text-white font-semibold text-xl tracking-tight">
            Allim
          </span>
        </a>

        <div className="hidden md:flex items-center gap-8">
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
            href="#use-cases"
            className="text-sm text-allim-muted hover:text-white transition-colors"
          >
            Use Cases
          </a>
          <a
            href="#smart"
            className="text-sm text-allim-muted hover:text-white transition-colors"
          >
            Smart Tools
          </a>
          <a
            href="#download"
            className="inline-flex items-center px-5 py-2 rounded-full bg-gradient-to-r from-allim-blue to-allim-purple text-white text-sm font-medium hover:opacity-90 transition-opacity"
          >
            Download
          </a>
        </div>

        <button
          className="md:hidden text-white"
          onClick={() => setOpen(!open)}
          aria-label="Toggle menu"
        >
          {open ? <X size={24} /> : <Menu size={24} />}
        </button>
      </div>

      {open && (
        <div className="md:hidden bg-allim-dark/95 backdrop-blur-xl border-t border-white/5 px-6 py-4 flex flex-col gap-4">
          <a
            href="#features"
            onClick={() => setOpen(false)}
            className="text-allim-muted hover:text-white transition-colors"
          >
            Features
          </a>
          <a
            href="#how-it-works"
            onClick={() => setOpen(false)}
            className="text-allim-muted hover:text-white transition-colors"
          >
            How It Works
          </a>
          <a
            href="#use-cases"
            onClick={() => setOpen(false)}
            className="text-allim-muted hover:text-white transition-colors"
          >
            Use Cases
          </a>
          <a
            href="#smart"
            onClick={() => setOpen(false)}
            className="text-allim-muted hover:text-white transition-colors"
          >
            Smart Tools
          </a>
          <a
            href="#download"
            onClick={() => setOpen(false)}
            className="inline-flex items-center justify-center px-5 py-2.5 rounded-full bg-gradient-to-r from-allim-blue to-allim-purple text-white font-medium"
          >
            Download
          </a>
        </div>
      )}
    </nav>
  );
}
