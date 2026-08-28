# App Icons

The Profile screen has a **Settings → App Icons** row that lets people swap
Allim's Home Screen icon. This is what backs it, and where new artwork goes.

## Where the files live

Everything is in the app's asset catalog:

```
Geolocation_v1.0.0/Assets.xcassets/
├── AppIcon-Allim.appiconset/          ← the icon iOS installs
│   ├── AppIcon-Allim-1024.png
│   └── Contents.json
├── AppIcon-Route.appiconset/
├── AppIcon-Notifi.appiconset/
├── AppIconPreview-Allim.imageset/     ← the thumbnail the picker draws
│   ├── AppIconPreview-Allim.png
│   └── Contents.json
├── AppIconPreview-Route.imageset/
├── AppIconPreview-Notifi.imageset/
└── AppIconPreview-Default.imageset/
```

Two copies of the same PNG, on purpose. iOS does **not** let an app load its own
icon assets as ordinary images, so the picker needs a plain imageset alongside
the icon set to have something to show. (`AppIconPreview-Default` is the
thumbnail for the shipped icon, which is `Geolocation_v1.0.0/NotifiApp.icon`
— an Icon Composer file, not an asset catalog entry.)

## Adding another icon

1. **Drop the artwork in.** Make a 1024×1024 PNG, **no alpha channel** (App
   Store validation rejects transparent app icons), and no rounded corners —
   iOS masks it.

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
       "AppIcon-Allim",
       "AppIcon-Route",
       "AppIcon-Notifi",
       "AppIcon-Sunset",
   );
   ```

3. **Add it to the picker.** One entry in `AppIconManager.options`
   (`Geolocation_v1.0.0/Services/AppIconManager.swift`):

   ```swift
   AppIconOption(
       alternateName: "AppIcon-Sunset",       // must match the .appiconset name
       displayName: "Sunset",
       subtitle: "Warm",
       previewAssetName: "AppIconPreview-Sunset"
   )
   ```

Nothing else to touch: the grid, the selection state and the Info.plist entries
all follow from that list and the build setting.

## Notes

- iOS shows its own "You have changed the icon for Allim" alert on every
  successful change. That alert is the system's and can't be suppressed.
- The change is per-device and survives reinstalls of the same build; iOS
  reports the current one through `UIApplication.shared.alternateIconName`,
  which is what the picker reads on appear.
- `ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS = YES` is set so the icon
  artwork is also readable by name at runtime. The picker falls back to it if a
  preview imageset is missing, so a forgotten preview shows the real icon rather
  than a blank tile.
