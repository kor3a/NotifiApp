import { StrictMode } from "react";
import { createRoot, hydrateRoot } from "react-dom/client";
import "./index.css";
import App from "./App";

const rootEl = document.getElementById("root")!;
const app = (
  <StrictMode>
    <App />
  </StrictMode>
);

if (rootEl.dataset.prerendered) {
  hydrateRoot(rootEl, app);
} else {
  rootEl.innerHTML = "";
  createRoot(rootEl).render(app);
}
