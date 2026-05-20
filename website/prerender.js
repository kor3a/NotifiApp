import fs from "node:fs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const dir = path.dirname(fileURLToPath(import.meta.url));
const outDir = path.join(dir, "out");
const templatePath = path.join(outDir, "index.html");

const entryServerUrl = pathToFileURL(
  path.join(dir, "out-server/entry-server.js"),
).href;
const { render } = await import(entryServerUrl);
const appHtml = render();

const splash = '<div id="app-splash"><div class="spinner"></div></div>';
let html = fs.readFileSync(templatePath, "utf-8");

if (!html.includes(splash)) {
  throw new Error("prerender: splash placeholder not found in out/index.html");
}

html = html
  .replace('<div id="root">', '<div id="root" data-prerendered="true">')
  .replace(splash, appHtml);

fs.writeFileSync(templatePath, html);
fs.rmSync(path.join(dir, "out-server"), { recursive: true, force: true });
console.log("Prerendered out/index.html");
