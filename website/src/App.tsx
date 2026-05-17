import Navbar from "./components/Navbar";
import Hero from "./components/Hero";
import Features from "./components/Features";
import HowItWorks from "./components/HowItWorks";
import UseCases from "./components/UseCases";
import Collaboration from "./components/Collaboration";
import SmartTools from "./components/SmartTools";
import Testimonials from "./components/Testimonials";
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
      <Collaboration />
      <SmartTools />
      <Testimonials />
      <Download />
      <Footer />
    </div>
  );
}
