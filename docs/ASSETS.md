# Visual design — 0.2

Reeeead uses a compact 500 × 570 native window, warm-white surfaces, neutral typography, subtle separators and pill buttons. The home screen contains two modes; provider, ruler and shortcut configuration live in Settings.

The visual reference is [Typeless's official desktop settings](https://www.typeless.com/help/quickstart/settings): quiet neutral colors, restrained controls and generous spacing. No Typeless logo, screenshot, code or proprietary asset is included in the app.

- `packaging/Reeeead.icns`: original three-line reading mark, generated deterministically with AppKit by `scripts/make-icon.swift`.
- `ReaderMark`: matching original geometry in `Design.swift`.
- Interface symbols: system SF Symbols.
- Typography: system fonts.

The previous pixel-art landscape is removed from the current source tree and app bundle. Its original provenance remains in Git history. No image generation is used for this redesign.
