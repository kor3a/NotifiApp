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

const SITE = "https://allimapp.com";

/**
 * Every route that gets its own HTML file. The CloudFront viewer-request
 * function rewrites an extensionless path to `<path>/index.html`, so anything
 * listed here has to exist at that key or the URL 404s at S3.
 */
const routes = [
  { pathname: "/", out: "index.html" },
  {
    pathname: "/support",
    out: "support/index.html",
    title: "Allim Support — alerts, permissions and shared lists",
    description:
      "Help with Allim: why nearby alerts need Always location access, fixing notifications that don't arrive, store pins, and shared lists that look out of sync.",
  },
];

// #root's children have to be exactly what the server rendered, so the whole
// element is replaced — splicing the app in around the template's indentation
// would leave whitespace-only text nodes on either side of it and fail
// hydration.
const rootBlock = /<div id="root">\s*<div id="app-splash">[\s\S]*?<\/div>\s*<\/div>/;

const template = fs.readFileSync(templatePath, "utf-8");

if (!rootBlock.test(template)) {
  throw new Error(
    "prerender: #root/#app-splash placeholder not found in out/index.html",
  );
}

for (const route of routes) {
  // React 19 hoists the <link rel="preload"> tags it generates for <img> to the
  // front of the rendered string. There is no document to hoist them into here,
  // so they would land inside #root — where the client never renders them,
  // which fails hydration. Lift them into <head>, which is both where they
  // belong and where they actually preload anything.
  const rendered = render(route.pathname);
  const hoisted =
    rendered.match(/<link[^>]*rel="(?:preload|preconnect|stylesheet)"[^>]*\/?>/g) ??
    [];
  const appHtml = hoisted.reduce((html, tag) => html.replace(tag, ""), rendered);

  let html = template.replace(
    rootBlock,
    () => `<div id="root" data-prerendered="true">${appHtml}</div>`,
  );

  if (hoisted.length) {
    html = html.replace("</head>", `  ${hoisted.join("\n    ")}\n  </head>`);
  }

  if (route.title) {
    html = html.replace(/<title>[\s\S]*?<\/title>/, `<title>${route.title}</title>`);
  }
  if (route.description) {
    html = html.replace(
      /(<meta\s+name="description"\s+content=")[\s\S]*?(")/,
      `$1${route.description}$2`,
    );
  }
  html = html.replace(
    /(<link rel="canonical" href=")[^"]*(")/,
    `$1${SITE}${route.pathname}$2`,
  );

  const target = path.join(outDir, route.out);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, html);
  console.log(`Prerendered out/${route.out}`);
}

fs.rmSync(path.join(dir, "out-server"), { recursive: true, force: true });
