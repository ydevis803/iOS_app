# Custom Fonts

The design system ([Theme.swift](../../App/Theme.swift) → `FTFonts`) references the
**Manrope** (headlines) and **Inter** (body/labels) families. These are licensed
binaries and are **not** committed to the repo — drop the `.ttf` files into this
folder before building.

## Required files

Place these exact filenames here (they are registered in [project.yml](../../project.yml)
under `UIAppFonts`, and bundled via the `Resources` group):

| File | PostScript name used in code |
|---|---|
| `Manrope-ExtraBold.ttf` | `Manrope-ExtraBold` |
| `Manrope-Bold.ttf` | `Manrope-Bold` |
| `Manrope-SemiBold.ttf` | `Manrope-SemiBold` |
| `Inter_18pt-Regular.ttf` | `Inter18pt-Regular` |
| `Inter_18pt-Medium.ttf` | `Inter18pt-Medium` |
| `Inter_18pt-SemiBold.ttf` | `Inter18pt-SemiBold` |
| `Inter_18pt-Bold.ttf` | `Inter18pt-Bold` |

> The current Google Fonts Inter download ships optical-size variants (`Inter_18pt-*`,
> `_24pt`, `_28pt`). We register the **18pt** set for UI text; the 24pt/28pt files are
> not used and can be removed to keep the bundle lean.

## Verifying PostScript names

`Font.custom(_:size:)` matches on **PostScript name**, not filename. If text still
renders in the system font after adding the files, open the font in **Font Book →
Cmd-I** and confirm the *PostScript name* matches the right-hand column above. If a
font ships under a different PostScript name, update the matching `FTFonts` helper.

## Where to get them

- Manrope: https://fonts.google.com/specimen/Manrope (OFL)
- Inter: https://fonts.google.com/specimen/Inter (OFL)

After adding files, re-run `xcodegen generate` so they are picked up by the project.
