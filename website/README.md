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

## Web app (development only)

`npm run dev` also serves a signed-in web version of Allim at
<http://localhost:5173/app/> (the masthead gets a **Sign in** link while in
dev). It signs in with the same email and password as the phone apps and
reads and writes the live `georeminder-pilot` Firestore, so anything you
change there shows up on your phone.

It lives in `app/index.html` and `src/app/`, and is never deployed:
`npm run build` only builds the root `index.html`, and the Sign in link is
behind `import.meta.env.DEV`. Firebase is a dev dependency for the same reason.

| Screen | What it does |
| --- | --- |
| Stores | Your pinned stores with open-item counts and logos; add a store (no map pin, so set one in the app for arrival reminders) |
| Store list | Items grouped by aisle; add, check off, rename (double-click), quantity, out of stock, delete. View-only shares are read-only |
| Friends | Requests, friends and sent requests; add by username; start a message |
| Messages | Conversations and threads; send text. Shared stores and items show as cards, but you accept them in the app |
| AI Recipe | Recipe chat through the `openAIChat` Cloud Function; send ingredients to a store or save the recipe |
| My Recipes | Create, edit, delete saved recipes and send their ingredients to a store |
| Profile | Name (editable), username, plan, stats, sign out |

Writes match the Swift code field for field (`src/app/lists.ts`,
`src/app/messaging.ts`), so the apps render web edits normally. The Firebase
config defaults to the iOS app's public client values; override them with
`VITE_FIREBASE_*` in `.env.development.local`.

## Design system

The page is built out of the things a grocery run is actually made of, not a
generic product-page kit: a handwritten list on a notepad, a yellow shelf-edge
price strip, hanging aisle signs, shelf tags, a map of the drive home, and a
till receipt. If a new section needs a visual, reach for the same shelf first.

**Colour.** Brand teal `#0B7285`, accent orange `#D94F16`, the ink tones and
the nine grocery-category hues (`--color-produce`, `--color-dairy`, …) are the
app's own, copied from `Geolocation_v1.0.0/Theme/AllimColors.swift` into the
`@theme` block at the top of `src/index.css`. **If one changes in Swift, change
it there too.** The paper tones (`canvas`, `paper`, `kraft`), shelf-tag yellow
(`tag`) and pen blue (`pen`) belong to the site alone.

**Type.** Three faces, loaded from Google Fonts in `index.html`:
Commissioner (the app's typeface) for everything by default, with `.display`
for the heavy, tightly tracked headlines; IBM Plex Mono (`.mono`) for shelf tags
and the receipt; and Nanum Pen Script (`.hand`), a Korean handwriting face, for
anything written by a person: the list, the timestamps, the section notes.

Deliberately absent: tracked-out uppercase "eyebrow" labels over every heading,
"01 / 02 / 03" section numbering, and icon-set icons. Those are what made the
previous version read as a template.

## Motion

Animation is [GSAP](https://gsap.com) with ScrollTrigger, SplitText, DrawSVG
and MotionPath, registered once in `src/lib/gsap.ts`. Each section runs its own
`useGSAP` hook, scoped to the section's ref, so everything is cleaned up on
unmount.

| Section | What moves |
| --- | --- |
| Hero | Headline plays in word by word, the highlighter stroke draws under "the store", the notepad drops in and items are crossed off in pen, then the push banner drops onto the phone on a loop. The note and phone part at different speeds as you scroll away. |
| Shelf strip | Marquee whose speed and direction follow your scroll velocity. |
| Walk the aisles | At `lg` the section pins and the aisles walk sideways as you scroll down; each sign swings on its wires as it comes into view. |
| How it works | Pinned at `md`+ and scrubbed: the pin drops, the list fills, the route draws and the car follows it (MotionPath) until it crosses the store's circle and the notification fires. |
| A real Tuesday | Timestamps, copy and phones play in per beat; a pen line connecting them draws with scroll. |
| The details | At `lg` one phone stays put and swaps screens as each block reaches the middle of the viewport. |
| Download | Headline lines rise, and the receipt feeds out of the printer slot in steps. |
| Navbar | Hides while scrolling down, comes back on scroll up. |

Rules the motion follows:

- **The prerendered HTML is always the finished page.** Every animation is a
  `gsap.from`/`fromTo` applied on the client, so with JavaScript off the page is
  complete and readable. The hero is the one exception: it's above the fold, so
  it is held back with `.pre-reveal` (only when the inline script has added
  `.js` to `<html>`) and a CSS fallback reveals it after 2.5s if the bundle
  never runs.
- **Reduced motion gets the static page.** Everything runs inside
  `gsap.matchMedia()` against `MOTION_OK`. The two places where a reduced-motion
  visitor still needs a result (the map's final frame, the sticky phone's screen
  swap) set it without tweening.
- **Pinned layouts degrade to normal ones.** Without the pin, the aisles are a
  swipeable scroller at `lg` and a stack below it, and every "details" block
  carries its own phone.

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

The three PNGs were captured while the app showed iOS's hidden system tab bar
peeking out under its own `OrganicTabBar`, so that ghost bar has been painted
out of them below the real one. Recapture them once the app no longer shows it.

All shots come out of the app at 920x2000, which `screens/shot.ts` turns into
the bezel size so no image is ever stretched.

The page never loads those originals directly. They're drawn only 268 CSS px
wide, and a browser shrinking 920px to that at paint time smudges the app's
smaller text on 1x screens, so `npm run shots` (`scripts/shots.mjs`) pre-shrinks
each one with Lanczos to 1x, 2x and 3x that width in `public/shots/`, and the
phones pick one through `srcset`. It runs at the start of every build; run it by
hand after replacing a screenshot to see the change under `npm run dev`. A new
screenshot also needs adding to its `SOURCES` list.
