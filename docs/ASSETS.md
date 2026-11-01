# Visual design — 0.3.1

Reeeead uses a compact 500 × 570 native window, warm-white surfaces, restrained controls and system fonts for interface copy. The upper-left pixel echo mark is paired with native Space Grotesk Medium lettering, 30.75 pt with -0.9 pt tracking. The same lockup stays on the left in settings. Chinese copy remains in the system font.

The visual reference is [Typeless's official desktop settings](https://www.typeless.com/help/quickstart/settings). No Typeless logo, screenshot, code or proprietary asset is included in the app.

## Pixel echo mark

- `docs/brand/pixel-echo-concept.png`: concept generated with the built-in imagegen tool on 2026-11-01. It is a design reference, not a runtime asset.
- `PixelMark` in `Sources/Reeeead/Brand.swift`: a precise geometric interpretation of the generated concept. Three pixel e glyphs, with two progressively lighter echoes, sit on an 8 × 7 grid. Native drawing keeps the small mark crisp and removes the generated image's edge noise.
- `scripts/make-icon.swift` and `packaging/Reeeead.icns`: matching app icon on a warm-white tile.
- Interface symbols: native SF Symbols.

Generation prompt: “Use case: logo-brand. Create a single minimal pixel logo for a quiet macOS reading utility called Reeeead. Symbol only, no text. An abstract compact square made of a small number of sharply aligned large pixels, with two subtle offset pixel afterimages trailing to the left, suggesting reading moving forward and attention coming into focus. Main rightmost pixel block dark charcoal; left echoes medium gray and light warm gray. Flat 2D, crisp hard square edges, strict pixel grid, elegant restrained design, recognizable at 24 pixels. No gradients, no blur, no 3D, no illustration, no glow, no outline, no app icon background tile. Center the single symbol with generous clear margins on a genuinely transparent background.”

Final edit prompt: “Simplify this logo into a genuinely flat tiny pixel mark. Remove ALL glow, shadow, fog, gradients, outlines, texture, and blur. Keep the compact rightward pixel-block motion idea. Use exactly three solid flat colors: charcoal #252523 for the front block, medium warm gray #A8A6A0 for the middle echo, light gray #DDDAD2 for the left echo. Strict 8 by 6 conceptual grid, a handful of large square pixels, no fine details. Transparent everywhere outside the solid pixel blocks. Tight square composition with modest margins. No text. This must look like a crisp 1980s bitmap glyph printed in three flat inks, not an illustration.”

## Previous generated wordmark

`Sources/Reeeead/Resources/Brand/wordmark.png` was generated with the built-in imagegen tool on 2026-11-01. It is retained as an earlier design asset; version 0.3.1 renders the brand as live text instead.

Final prompt: “Use case: logo-brand. Asset: a single professional compact typographic wordmark for a minimal macOS reading app. Exact text: \"Reeeead\" (capital R, FOUR lowercase e characters, then a, then d; seven letters total). One word on one horizontal baseline. Custom beautiful typography inspired by the bottom-weighted, asymmetrical friendly letterforms of OpenDyslexic, but drawn as a cohesive sophisticated logo. Very tight optical kerning, letters close together, no wide tracking. Thick-to-thin gentle weight, rounded bowls, slightly chunky bottom strokes. Restrained tiny pixel-square cuts in the R terminal and the final d terminal only, lending a subtle digital personality while the letters stay highly legible. All letters SOLID dark charcoal #252523, no fading, no additional standalone symbol. Quiet confident editorial identity suitable for an elegant tiny desktop utility. Transparent background, crisp flat artwork. Large horizontal wordmark fills most of the canvas width with modest margins. No mockup, no paper texture, no shadows, no gradient, no glow, no slogans, no extra text.”

## Earlier OpenDyslexic option

The unmodified `OpenDyslexic-Regular.otf` is bundled with its full copyright notice and SIL Open Font License 1.1 in `Sources/Reeeead/Resources/Fonts/OFL.txt`, which is also copied into the installed app. This font is separately licensed, not covered by the project's MIT license.

- Author: Abbie Gonzalez, with Reserved Font Name OpenDyslexic.
- Source: [official repository, pinned commit 1824da5](https://github.com/antijingoist/opendyslexic/tree/1824da5c0e41dc3e13ffc7f3a636dcaf695d61b7).
- The app registers the font only in its own process. It does not install or change the user's system fonts.
- Retained as an earlier font asset; no longer used for the current wordmark. No claim is made about clinical reading outcomes.

The older pixel landscape is absent from the current app; its provenance remains in Git history.

## Current Space Grotesk wordmark

- Typeface: Space Grotesk Medium by Florian Karsten, unmodified OTF.
- Source: [official repository pinned at 03507d0](https://github.com/floriankarsten/space-grotesk/tree/03507d024a01282884232081fc6011c09ff4e849).
- File: `Sources/Reeeead/Resources/Fonts/SpaceGrotesk-Medium.otf`.
- Full copyright and SIL Open Font License: `Sources/Reeeead/Resources/Fonts/SpaceGrotesk-OFL.txt`, also bundled in the app.
- Registered only inside the app process, without system font installation. Live text preserves crisp rendering at every display scale.
