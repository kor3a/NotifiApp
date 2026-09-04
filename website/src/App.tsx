import CloserLook from "./components/CloserLook";
import Download from "./components/Download";
import FAQ from "./components/FAQ";
import Features from "./components/Features";
import Footer from "./components/Footer";
import Hero from "./components/Hero";
import HowItWorks from "./components/HowItWorks";
import Navbar from "./components/Navbar";
import SupportPage from "./components/SupportPage";
import UseCases from "./components/UseCases";

/**
 * `pathname` is passed by the prerenderer, which has no `window`. In the
 * browser it is left off and the current URL is read instead, so the client
 * resolves to the same page the server rendered and hydration matches.
 */
export default function App({ pathname }: { pathname?: string }) {
  const path =
    pathname ?? (typeof window !== "undefined" ? window.location.pathname : "/");

  if (path.replace(/\/+$/, "") === "/support") {
    return <SupportPage />;
  }

  return (
    <div className="min-h-screen bg-canvas">
      <Navbar />
      <main>
        <Hero />
        <Features />
        <HowItWorks />
        <UseCases />
        <CloserLook />
        <FAQ />
        <Download />
      </main>
      <Footer />
    </div>
  );
}
