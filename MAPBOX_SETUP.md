# Mapbox Setup (Hybrid Map)

The map screen (`Search` tab) can render with **Mapbox** for a more detailed,
customizable, fully interactive map — while still using Apple's **MapKit**
(`MKLocalSearch` / `MKDirections`) for place search, store lookup, routing, and
geofencing. This is a **hybrid**: Mapbox draws the map, MapKit does the searching.

## How the fallback works (nothing breaks today)

`HomeView` now shows `MapboxMapView` instead of `MapView`. `MapboxMapView`:

1. If the **MapboxMaps SDK is not installed**, it compiles to a thin wrapper that
   renders the existing MapKit `MapView` (guarded by `#if canImport(MapboxMaps)`).
2. If the SDK **is** installed but **no `MAPBOX_ACCESS_TOKEN`** is configured, it
   still falls back to the MapKit `MapView` at runtime.
3. Only when **both the SDK and a valid `pk.` token are present** does it render
   with Mapbox.

So the app builds and runs exactly as before until you complete the steps below.

---

## Step 1 — Create a Mapbox account & tokens

1. Sign up at <https://account.mapbox.com/>.
2. You need **two** tokens:
   - **Public access token** (`pk.xxxx`) — used at runtime by the app.
     The "Default public token" on your account page works.
   - **Secret downloads token** (`sk.xxxx`) — used only to *install* the SDK via
     Swift Package Manager. Create one under **Account → Tokens → Create a token**
     with the **`Downloads:Read`** scope checked.

## Step 2 — Configure the secret downloads token for SPM

Xcode/SPM reads the downloads token from your `~/.netrc` file. Add:

```
machine api.mapbox.com
login mapbox
password sk.YOUR_SECRET_DOWNLOADS_TOKEN
```

Then `chmod 600 ~/.netrc`.
(See Mapbox's install docs: <https://docs.mapbox.com/ios/maps/guides/install/>.)

## Step 3 — Add the MapboxMaps Swift Package

In Xcode: **File → Add Package Dependencies…**

- URL: `https://github.com/mapbox/mapbox-maps-ios.git`
- Dependency rule: **Up to Next Major** starting from **`11.0.0`**
  (this code targets the v11 SwiftUI API — do **not** use v10).
- Add the **`MapboxMaps`** product to the **Allim** app target.

> The code references the Mapbox SwiftUI API (`Map`, `Puck2D`, `ViewAnnotation`,
> `.mapStyle`, `.onCameraChanged`, `Viewport`). If you pin a different major
> version these symbols may differ — stay on 11.x.

## Step 4 — Add your public token

1. Copy `Secrets.xcconfig.template` → `Secrets.xcconfig` (if you haven't already).
2. Set:

   ```
   MAPBOX_ACCESS_TOKEN = pk.YOUR_PUBLIC_ACCESS_TOKEN
   ```

`Info.plist` already exposes this as the `MBXAccessToken` key, which the Mapbox
SDK reads automatically — no extra code needed.

## Step 5 — Build & run

Open the **Search** tab. You should now see the Mapbox map with:

- the user-location puck,
- your saved-store pins (`StoreIconView`) found via `MKLocalSearch`,
- search-result pins (`SearchResultPinView`),
- the same bottom tab/search bar UX as before.

---

## What Mapbox replaces vs. what stays on MapKit

| Concern | Provider after this change |
| --- | --- |
| Map rendering, tiles, camera, annotations, 3D/pitch | **Mapbox** (`MapboxMapView`) |
| Place / store search (`MKLocalSearch`) | MapKit (unchanged) |
| Routing / travel time (`MKDirections`, `TravelTimeService`) | MapKit (unchanged) |
| Geofencing & location notifications (`LocationMonitoringManager`, Core Location) | MapKit / Core Location (unchanged) |

## Customizing the map style

Change `.mapStyle(.standard)` in `MapboxMapView.swift` to `.streets`, `.outdoors`,
`.satellite`, `.satelliteStreets`, etc. For fully custom styling, design a style
in **Mapbox Studio** and load it via `.mapStyle(MapStyle(uri: StyleURI(rawValue: "mapbox://styles/...")!))`.

## Reverting to Apple Maps

Either:
- Remove the `MapboxMaps` package (the `#if canImport` fallback takes over), **or**
- Change `MapboxMapView(...)` back to `MapView(...)` in `HomeView.swift`.

## Billing note

Mapbox pricing is **usage-based** (monthly map loads / MAU), unlike Apple Maps which
is free. Review <https://www.mapbox.com/pricing> before shipping to production and
keep an eye on your monthly free-tier allowance.
