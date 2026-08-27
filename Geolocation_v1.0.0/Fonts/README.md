# Bundled fonts

## Commissioner

The display face behind the organic screens. Six static instances of the
variable family, pulled from Google Fonts (v24) and referenced by their
PostScript names in `OrganicPalette.commissioner(_:)`:

| File | Weight | PostScript name |
| --- | --- | --- |
| `Commissioner-Regular.ttf` | 400 | `Commissioner-Regular` |
| `Commissioner-Medium.ttf` | 500 | `Commissioner-Medium` |
| `Commissioner-SemiBold.ttf` | 600 | `Commissioner-SemiBold` |
| `Commissioner-Bold.ttf` | 700 | `Commissioner-Bold` |
| `Commissioner-ExtraBold.ttf` | 800 | `Commissioner-ExtraBold` |
| `Commissioner-Black.ttf` | 900 | `Commissioner-Black` |

Copyright 2019 The Commissioner Project Authors
(github.com/kosbarts/Commissioner), licensed under the SIL Open Font
License 1.1 — https://scripts.sil.org/OFL. The full `OFL.txt` still needs
to be dropped in beside these files and surfaced in the app's
acknowledgements.

Adding or swapping a weight means three steps: drop the `.ttf` here, add it
to `UIAppFonts` in `Info.plist`, and add it to the Allim target's Resources
build phase. A face missing from any of the three falls back to the system
font silently.

## SpecialElite-Regular.ttf

Registered in `Info.plist` but not referenced from any Swift code.
