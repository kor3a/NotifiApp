# Allim — marketing site

React + TypeScript + Vite, Tailwind v4, prerendered to static HTML for S3.

```bash
npm install
npm run dev      # local dev server
npm run build    # → out/ (client bundle, then SSR render, then prerender)
npm run lint
```

`npm run build` runs three steps: the client bundle, an SSR bundle, and
`prerender.js`, which renders the app to HTML and splices it into
`out/index.html` so the page is readable with JavaScript off and paints before
hydration. `prerender.js` replaces the whole `#root` element rather than just
its contents — leaving the template's indentation inside `#root` puts
whitespace-only text nodes where React expects the server's markup, which fails
hydration.

## Design system

The site takes its colour and type from the app rather than inventing its own,
so the two don't drift apart.

**Colour** is the app's aisle palette, copied from
`Geolocation_v1.0.0/Theme/AllimColors.swift` (light values) into the `@theme`
block at the top of `src/index.css`. Teal `#0B7285` is the brand; orange
`#D94F16` is the accent and, as in the app, is used sparingly — reminders,
"you're near <store>", unread counts. The nine grocery-category hues
(`--color-produce`, `--color-dairy`, …) are the site's signature: they come
from `GroceryCategory.palette` and appear as the aisle rail under the masthead,
as the legend in the hero, and as the dot next to every feature. **If a colour
changes in Swift, change it here and nowhere else.**

**Type** is Commissioner, the face the app sets everything in
(`OrganicTheme.swift`), loaded from Google Fonts in `index.html`. Three helper
classes in `index.css` carry the hierarchy: `.display` for tight, heavy
headlines, `.eyebrow` for the small tracked-out labels, `.figure` for the
tabular numerals that index each section.

There are deliberately **no icon-set icons**. Category dots, numerals and
hairline rules do that work instead.

## Assets

`public/allim-icon.svg` is the shipped app icon redrawn as vector — traced from
`Geolocation_v1.0.0/Allim.icon/Assets/allim-icon-teal-1024.png` and checked
against it pixel for pixel. `favicon.svg` is the same mark inside the rounded
square iOS masks it to, and `apple-touch-icon.png` is that rendered at 180×180.
`og-image.png` is the social card referenced from `index.html`.

If the app icon changes, redraw these from the new artwork — they are the same
mark and should never disagree.

Store tiles in the phone mockups are monograms, not brand logos: Allim works
with whatever store you pin, so real marks would be both a trademark problem
and a claim the app doesn't make.

Three phones on the page are real device screenshots rather than rebuilt
facsimiles — the hero, and the first two beats of **In practice** — so the
retailer marks and the app's own chrome are the genuine article:

| File | What it shows |
| --- | --- |
| `public/allim-stores-screen.webp` | the hero: the stores list |
| `public/allim-reminderview.png` | a shared Walmart list, sorted into aisles |
| `public/allim-swipe-rest.png` | the stores list, untouched |
| `public/allim-swipe-action.png` | the same list with a row swiped and its "On My Way" action showing |

The last two are a matched pair: `src/components/screens/SwipePhone.tsx` plays
the swipe out of them, clipping both to the swiped row's band and sliding the
resting row off the action underneath, so every frame is pixels the app drew.
Its two calibration constants — where the row sits, and how far it moved — were
measured by diffing the pair, and are stored as shares of the image, so
re-exporting the screenshots at another resolution leaves them correct as long
as the aspect holds. Replace the pair with a differently cropped one and they
need re-measuring; the file says how they were derived.

All shots come out of the app at 920x2000, which `screens/shot.ts` turns into
the bezel size so no image is ever stretched.
