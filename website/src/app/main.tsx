import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import "../index.css";
import Root from "./App";
import { SessionProvider } from "./session";

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <SessionProvider>
      <Root />
    </SessionProvider>
  </StrictMode>,
);
