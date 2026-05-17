import { lazy, Suspense } from "react";
import Navbar from "./components/Navbar";
import Hero from "./components/Hero";

const Features = lazy(() => import("./components/Features"));
const HowItWorks = lazy(() => import("./components/HowItWorks"));
const UseCases = lazy(() => import("./components/UseCases"));
const Collaboration = lazy(() => import("./components/Collaboration"));
const SmartTools = lazy(() => import("./components/SmartTools"));
const Testimonials = lazy(() => import("./components/Testimonials"));
const Download = lazy(() => import("./components/Download"));
const Footer = lazy(() => import("./components/Footer"));
const SupportPage = lazy(() => import("./components/SupportPage"));

export default function App() {
  if (typeof window !== "undefined" && window.location.pathname === "/support") {
    return (
      <Suspense fallback={null}>
        <SupportPage />
      </Suspense>
    );
  }

  return (
    <div className="min-h-screen bg-allim-dark">
      <Navbar />
      <Hero />
      <Suspense fallback={null}>
        <Features />
        <HowItWorks />
        <UseCases />
        <Collaboration />
        <SmartTools />
        <Testimonials />
        <Download />
        <Footer />
      </Suspense>
    </div>
  );
}
