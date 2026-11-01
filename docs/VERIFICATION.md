# Verification — 0.1.0 preview

Environment: Apple Silicon Mac mini, macOS 26.5.2, Swift 6.3.3. Validation date: 2026-11-01. Minimum target macOS 14; older supported versions have not been manually tested.

## Completed

- Release app builds with a single compiler job. Bundle is approximately 3 MB before adding any distribution archive.
- `codesign --verify --deep --strict dist/Luma.app` succeeds for the local ad-hoc signature.
- All 9 automated tests pass with the local HTTP fixture enabled: 6 core tests, 3 real HTTP/audio lifecycle tests.
- Ruler state tests cover the two clicks, fixed geometry, upward movement, minimum band height and screen-edge clamping.
- Request tests cover body fields, custom model/voice, speed, empty and oversized inputs, endpoint restrictions and absent API key.
- Local fixture integration covers actual audio decoding/playback completion, pause/resume, cancellation before a delayed response, 401 handling and refusal to follow a 307 redirect.
- Native UI: application launches; home, voice, ruler and shortcut pages render; bundled landscape displays after app packaging.
- Native UI: system speech enters playback and completes; local API fixture enters external playback and completes.
- Native UI: shortcut recording rejects a duplicate of the other action and saves the chosen shortcut.
- Native UI: when Accessibility is absent, the ruler refuses to open and explains the required permission instead of trapping the user in an overlay.

## Pending / not claimed

- Accessibility permission has not yet been granted for the app. Real cross-application selection, positioning click interception, locked-overlay scrolling/click-through, global Esc and global shortcut behavior still need live verification.
- Full-screen apps, Spaces and multiple monitors require live verification; implementation uses AppKit's full-screen auxiliary and all-Spaces behaviors, but API availability alone does not prove every app combination works.
- No real external provider credentials were used. The local fixture validates protocol handling, not a provider's live authentication, voice quality, latency, quotas or billing.
- Keychain read/write error handling is implemented. Actual user-secret storage has not been exercised with a real credential.
- Developer ID signing, Apple notarization and a broadly distributed binary release have not been completed.
- This is an initial product build, not a clinical evaluation of reading outcomes.

## Manual acceptance checklist

1. Move app to its stable install path and enable Accessibility for Luma.
2. In TextEdit, select only part of a sentence; invoke read shortcut. Check that only that selection is read and source app keeps focus.
3. Repeat in browser, PDF reader and frequently used chat app. Record which use direct AX selection and which require copy fallback.
4. Place a known string on the clipboard; use copy fallback and verify it is restored. Test no selection and unsupported content without reading old clipboard data.
5. Start ruler over a page containing clickable links. First click sets top, second click sets bottom; neither click should open a link.
6. After locking, click/select/scroll the page. Band must remain stationary, source interaction must work, Esc must dismiss the overlay without dismissing a source-app dialog.
7. Toggle with the shortcut in every state; try upward movement, bottom screen edge, full-screen app, another Space and a second display.
8. Configure a real compatible API locally and audition a non-sensitive sample. Test invalid key and cancellation on a slow connection.
