# Verification — 0.2.0 compact redesign

Environment: Apple Silicon Mac mini, macOS 26.5.2, Swift 6.3.3. Validation date: 2026-11-01. Minimum target macOS 14; older supported versions have not been manually tested.

## Completed

- Release app builds with a single compiler job. Bundle is approximately 1.3 MB before adding any distribution archive.
- `codesign --verify --deep --strict dist/Reeeead.app` succeeds for the local ad-hoc signature.
- All 9 automated tests pass with the local HTTP fixture enabled: 6 core tests, 3 real HTTP/audio lifecycle tests.
- Ruler state tests cover the two clicks, fixed geometry, upward movement, minimum band height and screen-edge clamping.
- Request tests cover body fields, custom model/voice, speed, empty and oversized inputs, endpoint restrictions and absent API key.
- Local fixture integration covers actual audio decoding/playback completion, pause/resume, cancellation before a delayed response, 401 handling and refusal to follow a 307 redirect.
- Native UI: the renamed app launches in a 500 × 570 window. The home screen uses a neutral palette, two modes and a settings button, with no sidebar or decorative image. The prior illustration is no longer bundled.
- Previous UI baseline (same speech engine): system speech enters playback and completes; local API fixture enters external playback and completes.
- Previous UI baseline (same recorder): shortcut recording rejects a duplicate of the other action and saves the chosen shortcut.
- Native UI: when Accessibility is absent, the ruler refuses to open and explains the required permission instead of trapping the user in an overlay.
- The compact app is installed at `~/Applications/Reeeead.app`; the previous installed app was moved to an ignored local backup.
- The previous functional baseline passed [GitHub Actions run 41320288673](https://github.com/YFJack/reeeead/actions/runs/41320288673) on macOS 15. The renamed build is checked separately; local-fixture tests remain opt-in in CI.

## Pending / not claimed

- The user authorized Accessibility access. macOS requested administrator authentication, which is pending completion in the system dialog. Real cross-application selection, positioning click interception, locked-overlay scrolling/click-through, global Esc and global shortcut behavior still need live verification.
- Full-screen apps, Spaces and multiple monitors require live verification; implementation uses AppKit's full-screen auxiliary and all-Spaces behaviors, but API availability alone does not prove every app combination works.
- No real external provider credentials were used. The local fixture validates protocol handling, not a provider's live authentication, voice quality, latency, quotas or billing.
- Keychain read/write error handling is implemented. Actual user-secret storage has not been exercised with a real credential.
- Developer ID signing, Apple notarization and a broadly distributed binary release have not been completed.
- This is an initial product build, not a clinical evaluation of reading outcomes.

## Manual acceptance checklist

1. Move app to its stable install path and enable Accessibility for Reeeead.
2. In TextEdit, select only part of a sentence; invoke read shortcut. Check that only that selection is read and source app keeps focus.
3. Repeat in browser, PDF reader and frequently used chat app. Record which use direct AX selection and which require copy fallback.
4. Place a known string on the clipboard; use copy fallback and verify it is restored. Test no selection and unsupported content without reading old clipboard data.
5. Start ruler over a page containing clickable links. First click sets top, second click sets bottom; neither click should open a link.
6. After locking, click/select/scroll the page. Band must remain stationary, source interaction must work, Esc must dismiss the overlay without dismissing a source-app dialog.
7. Toggle with the shortcut in every state; try upward movement, bottom screen edge, full-screen app, another Space and a second display.
8. Configure a real compatible API locally and audition a non-sensitive sample. Test invalid key and cancellation on a slow connection.
