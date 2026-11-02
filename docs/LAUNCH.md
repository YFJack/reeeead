# Launch delivery — 2026-11-02

## Published website

- English: https://reeeead.frosty-olive-3604.chatgpt.site/
- Chinese: https://reeeead.frosty-olive-3604.chatgpt.site/zh/
- Host returned `succeeded` for the public deployment.
- Independent localized titles/descriptions, canonical and language-alternate URLs, OG/Twitter image metadata, SoftwareApplication JSON-LD, robots.txt, and sitemap.xml are included. Search-engine indexing and search rank have not been confirmed.

## Film and assets

- Landscape: 1280 × 720, H.264/AAC, 24 fps, 33.58 seconds.
- Portrait: 720 × 1280, H.264/AAC, 24 fps, 33.58 seconds.
- Chinese MiniMax narration, bilingual burned-in captions, SRT and VTT, 1200 × 630 cover, original renderer and public script.
- Complete audio/video decode succeeded for both exports. Key scene frames were visually reviewed, including portrait captions. Subjective listening acceptance remains with the user.
- Short public narration and voice samples were sent to MiniMax with the authorized existing API key. No secret is in the website, scripts or generated assets.
- Exact prompts and provenance live under `marketing/` and `docs/ASSETS.md`.

## Website checks

- English and Chinese HTML, one H1 per page, local assets, internal anchors and JSON-LD validated.
- JavaScript syntax and Python scripts checked.
- Safari loaded the Chinese page. Reading-band range changed value; the sample audio button changed to its playing state and returned after playback.
- Full browser movie playback and mobile viewport visual acceptance remain unverified; the video files themselves fully decode and responsive CSS is included.
- Public-output scan found no embedded API keys or private host addresses.

## External publication boundary

X CLI `xurl` 1.3.4 is installed. X web login succeeded. The user explicitly accepted the developer agreement; onboarding has been submitted. Developer OAuth setup and CLI login are complete for @yfjack199017. The account was verified through `xurl whoami`; reading the existing English post returned HTTP 402 `credits depleted`, so paid API operations remain unavailable without credits. No credits were purchased. The primary text in `marketing/launch-copy.md` was published through the authenticated website as @yfjack199017, with the landscape film and SRT captions. The post was opened again to verify text, the repository link and attached video: https://x.com/yfjack199017/status/2116936600819290403 . No duplicate CLI post is needed.

The bilingual update installs native app 0.4.0 on both configured Macs. Previously reported physical shortcut, mouse-side-button and external-display acceptance gaps remain in `VERIFICATION.md`.

## Repository and MacBook delivery

- Public source and launch kit pushed in commit `f6edda58ee957c2d276ad09896452207503e7f25`.
- Repository About text, public website URL and relevant topics updated and read back.
- Source preview release: https://github.com/YFJack/reeeead/releases/tag/v0.3.2 . Both MP4s, the SRT and cover were uploaded and verified in the release asset list.
- The same four files were copied into the MacBook Downloads/Reeeead-launch folder; all SHA-256 hashes match the Mac mini. No application update was necessary.

## English edition and bilingual app — 0.4.0

- App interface, menus, permissions, shortcut recorder, ruler guidance and speech errors now support English and Simplified Chinese. Defaults to system language; manual choice is under Settings → Shortcuts → App language.
- 31 tests passed, including local HTTP/audio integration and localization resource/format checks. Release build succeeded. Both configured Macs received the same bundle; file hashes and code signatures verified. Local live UI switched to English and the genuine screenshot is `docs/screenshot-home-en.png`. MacBook live UI acceptance remains separate from installation verification.
- English film: 35.25 seconds, landscape 1280 × 720 and portrait 720 × 1280, H.264/AAC at 24 fps, English narration, on-screen copy and SRT/VTT captions. Both complete files decoded successfully; key frames reviewed. Voice generation succeeded; subjective voice-quality acceptance remains with the user.
- English website uses the English film and screenshot; Chinese edition remains available separately. Updated public deployment succeeded. Website link/asset/metadata validation passed.
- English MP4/subtitle delivery to the MacBook succeeded on retry after a transient SSH timeout. All four SHA-256 hashes match local originals in Downloads/Reeeead-launch.
- English X update published with the 35-second video and English SRT captions: https://x.com/yfjack199017/status/2116938900153454880 . Sent confirmation and independent post page verified. The original Chinese-narrated post is retained.
- Source preview release: https://github.com/YFJack/reeeead/releases/tag/v0.4.0 ; English landscape/portrait MP4, SRT, VTT and cover uploaded.


## X CLI authentication — 2026-11-02

- Official `xurl` 1.3.4, native public client with PKCE, localhost callback.
- Default app: `reeeead`; default OAuth2 user: `yfjack199017`.
- Granted scopes: `tweet.read users.read tweet.write media.write offline.access`. The CLI's broader default authorization URL was reduced before consent; no DM or email scope was requested.
- `xurl auth status` confirms the saved user token; `xurl whoami` returned the expected account.
- `xurl read 2116938900153454880` returned HTTP 402 `credits depleted`. Authentication works; credit-dependent post/media operations have not been verified. No duplicate post and no credit purchase.
- OAuth credentials stay in the CLI's local token store and are not part of the repository.
