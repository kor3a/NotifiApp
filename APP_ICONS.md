# App Icons

The Profile screen has a **Settings → App Icons** row that lets people swap
Allim's Home Screen icon. This is what backs it, and where new artwork goes.

All three icons are the same storefront mark in different colours, so they are
named for the colour rather than the shape: **Teal** (shipped), **Pink**,
**Wash**.

## Where the files live

The shipped icon is an Icon Composer bundle:

```
Geolocation_v1.0.0/Allim.icon/
├── icon.json                               ← fill + layer list
└── Assets/allim-icon-teal-1024.png
```

`ASSETCATALOG_COMPILER_APPICON_NAME = Allim` in the app target points at it.
The alternates are ordinary icon sets in the asset catalog:

```
Geolocation_v1.0.0/Assets.xcassets/
├── AppIcon-Storefront.appiconset/          ← Pink; the icon iOS installs
│   └── AppIcon-Storefront-1024.png
├── AppIcon-Wash.appiconset/                ← Wash
│   └── AppIcon-Wash-1024.png
├── AppIconPreview-Default.imageset/        ← the thumbnails the picker draws
├── AppIconPreview-Storefront.imageset/
└── AppIconPreview-Wash.imageset/
```

Every icon except the shipped one is two copies of the same PNG, on purpose:
iOS does **not** let an app load its own icon assets as ordinary images, so the
picker needs a plain imageset alongside the icon set to have something to show.
The shipped icon needs only its `AppIconPreview-Default` thumbnail — don't add
an alternate holding that same artwork, it shows up in the grid as a second,
identical tile.

### Why Pink's asset is called "Storefront"

Pink shipped first, as the app's only alternate, under the name
`AppIcon-Storefront`. That string is what iOS has recorded for everyone already
using it; renaming the asset would quietly reset them to the shipped icon on
their next launch. So the asset keeps the old name and only `displayName`
changed. Leave it alone unless you're willing to reset those users.

## The palette

The teal and wash variants are recolours of the original pink artwork, mapped
onto `AllimColor` tokens. Four flat colours, plus antialiased blends between
whichever two regions meet at an edge:

| Region     | Pink            | Teal                   | Wash                   |
|------------|-----------------|------------------------|------------------------|
| background | `#CE2178`       | `#0B7285` `primary`    | `#E0F1F4` `primaryWash`|
| storefront | `#FBD2E2`       | `#E0F1F4` `primaryWash`| `#0B7285` `primary`    |
| check disc | `#FB2D57`       | `#D94F16` `accent`     | `#D94F16` `accent`     |
| checkmark  | `#FFFFFF`       | `#FFFFFF`              | `#FFFFFF`              |

Pink now runs inverted from the artwork the other two were recoloured from: the
deep pink fills the canvas and the storefront is drawn in the pale one, the two
swapped. It predates the palette and is off it deliberately — Home Screen
artwork doesn't have to obey the in-app tokens.

## Adding another icon

1. **Drop the artwork in.** A 1024×1024 PNG, **no alpha channel** (App Store
   validation rejects transparent app icons), and no rounded corners — iOS
   masks it.

   ```
   Assets.xcassets/AppIcon-Sunset.appiconset/AppIcon-Sunset-1024.png
   Assets.xcassets/AppIconPreview-Sunset.imageset/AppIconPreview-Sunset.png
   ```

   Copy a `Contents.json` from a neighbouring folder and change the filename in
   it, or add both assets through Xcode (File → New → iOS App Icon / Image Set).

2. **Register the icon with the build.** In the app target's Build Settings, add
   the new name to **Alternate App Icon Sets** — or in
   `Geolocation_v1.0.0.xcodeproj/project.pbxproj`, to
   `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` in *both* the Debug and
   Release configurations of the `Allim` target:

   ```
   ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES = (
       "AppIcon-Storefront",
       "AppIcon-Wash",
       "AppIcon-Sunset",
   );
   ```

3. **Add it to the picker.** One entry in `AppIconManager.options`
   (`Geolocation_v1.0.0/Services/AppIconManager.swift`):

   ```swift
   AppIconOption(
       alternateName: "AppIcon-Sunset",       // must match the .appiconset name
       displayName: "Sunset",                 // not drawn; VoiceOver reads it
       previewAssetName: "AppIconPreview-Sunset"
   )
   ```

Nothing else to touch: the grid, the selection state and the Info.plist entries
all follow from that list and the build setting.

## Replacing an icon's artwork

For an alternate, drop the new 1024×1024 PNG over **both** copies, keeping the
filenames:

```
Assets.xcassets/AppIcon-Wash.appiconset/AppIcon-Wash-1024.png
Assets.xcassets/AppIconPreview-Wash.imageset/AppIconPreview-Wash.png
```

Then redraw the notification avatar to match — a 180×180 copy of the same
artwork, which is what push banners carry when that icon is the chosen one:

```
Assets.xcassets/AllimNotificationAvatar-Wash.imageset/AllimNotificationAvatar-Wash.png
```

For the shipped icon, that's the layer inside the bundle, its thumbnail and its
avatar:

```
Allim.icon/Assets/allim-icon-teal-1024.png
Assets.xcassets/AppIconPreview-Default.imageset/AppIconPreview-Default.png
Assets.xcassets/AllimNotificationAvatar.imageset/AllimNotificationAvatar.png
```

Nothing in the code refers to a filename, only to asset names, so there's
nothing else to change.

## Notes

- The shipped icon's layer is a full-bleed opaque PNG, so `icon.json` carries
  no `glass` or `translucency`: they do nothing behind artwork that already
  covers the canvas. To get the iOS 26 layered treatment instead, the layer has
  to become the storefront and badge on a **transparent** background, with the
  `fill` supplying the teal.
- iOS shows its own "You have changed the icon for Allim" alert on every
  successful change. That alert is the system's and can't be suppressed.
- The change is per-device and survives reinstalls of the same build; iOS
  reports the current one through `UIApplication.shared.alternateIconName`,
  which is what the picker reads on appear.
- `ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS = YES` is set so the icon
  artwork is also readable by name at runtime. The picker falls back to it if a
  preview imageset is missing, so a forgotten preview shows the real icon rather
  than a blank tile.
