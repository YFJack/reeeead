# Reeeead launch kit

A quiet product, with a deadpan sense of humor. The joke is rereading the same line; never the reader or a diagnosis.

- Product name: **Reeeead** (four e's).
- Website: English and Chinese; original pixel mark, warm paper, compact Space Grotesk lettering.
- Film: Chinese narration, bilingual burned-in captions; a clean caption file accompanies the export. Illustrative feature animations are labeled, and the native app screenshot is real.
- No fabricated testimonials, adoption counts, universal app compatibility or clinical benefit claims.
- The first public release is source-first. Do not imply the app is notarized or offer a nonexistent signed download.
- Voice: MiniMax speech-2.8-hd, presenter_male, calm. Only the public script is sent to the service; credentials must come from an environment variable.

## Build the film

Install `pillow` and `imageio-ffmpeg` in a local virtual environment. Run `python marketing/video/render.py`. This streams individual frames to a single-thread FFmpeg encoder instead of retaining a frame sequence. Output stays under ignored `local/launch-output/`.

Generated illustration: built-in imagegen, 2026-11-02. Full prompt is in `assets/reading-again.prompt.txt`. Illustration is an editorial asset, not an app screenshot. No third-party brand assets are used.
