import Navbar from "./components/Navbar";
import Hero from "./components/Hero";
import Features from "./components/Features";
import HowItWorks from "./components/HowItWorks";
import UseCases from "./components/UseCases";
import CloserLook from "./components/CloserLook";
import FAQ from "./components/FAQ";
import Download from "./components/Download";
import Footer from "./components/Footer";
import SupportPage from "./components/SupportPage";

export default function App() {
  if (typeof window !== "undefined" && window.location.pathname === "/support") {
    return <SupportPage />;
  }

  return (
    <div className="min-h-screen bg-allim-dark">
      <Navbar />
      <Hero />
      <Features />
      <HowItWorks />
      <UseCases />
      <CloserLook />
      <FAQ />
      <Download />
      <Footer />
    </div>
  );
}
