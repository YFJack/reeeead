# Verification — 0.3.1

Validation date: 2026-11-01. Build host: Apple Silicon Mac mini, macOS 26.5.2, Swift 6.3.3. Second install: Apple Silicon MacBook, macOS 26.2. Minimum supported target is macOS 14; older supported OS versions have not been manually tested.

## Completed on this build

- Release build with one compiler job. Installed bundles were verified on both hosts.
- 23 automated tests pass with local HTTP fixtures enabled: 7 core/branding, 7 mouse-shortcut, 5 MiniMax and 4 HTTP/audio integration tests. MiniMax cases cover request structure, provider profile preservation, strict completed-audio decoding, malformed payloads and provider errors returned with HTTP 200.
- Mouse tests cover legacy keyboard decoding, side-button serialization, conflict detection, ignoring ordinary clicks and unmatched modifiers, complete down/up consumption, release after modifier changes, a single action per press, simultaneous buttons and recording on release.
- The unmodified Space Grotesk Medium font loads from the bundled resources without system installation, and its OFL license is included.
- Version 0.3.1 places the pixel echo icon at the upper-left and uses native Space Grotesk text for the wordmark. The installed Mac mini UI was visually checked and the home screenshot refreshed.
- Native UI: the side-button recorder can install its event tap on the Mac mini after Accessibility is enabled. The Mouse 4 preset saves, survives an app restart and displays correctly. Attempting to assign it to the other action is rejected. Cancel restores registrations. Keyboard recording still works; test changes were restored to the original keyboard bindings.
- Accessibility was rebound to the final installed Mac mini app and recognized after restart. On the earlier 0.2.1 build, the ruler successfully entered its active state after permission was granted; this alone does not verify positioning/click-through.
- Both Macs received the same 0.3.1 app. The installer checked SHA-256 for every bundled file, architecture compatibility and code signature. Installed executable hashes matched on both hosts.
- Both personal installations now use an existing Apple Development identity. The signing identity configuration remains local and ignored by Git. No private key or API key is copied by deployment.

## Previous unchanged-engine checks

- Ruler geometry tests cover two clicks, fixed bounds, upward movement, minimum band height and screen-edge clamping.
- Request validation covers model/voice fields, speed, empty/oversized input, endpoint restrictions and absent API key.
- Local fixture integration exercised real HTTP/audio decoding and playback completion, pause/resume, cancellation before a delayed response, 401 handling and refusal to follow a 307 redirect.
- System-speech and local-fixture playback were exercised through the native UI on the previous functional baseline.
- The earlier baseline passed [GitHub Actions run 41320288673](https://github.com/YFJack/reeeead/actions/runs/41320288673) on macOS 15. Current commits trigger a separate CI run.

## Pending / not claimed

- Physical side-button events have not yet been confirmed end-to-end with the user's mouse. Successful preset saving and pure routing tests are not hardware acceptance. Mouse software may remap side buttons into keyboard macros or consumer events.
- The MacBook system Accessibility toggle is ON (confirmed by the user screenshot), while the app previously reported permission missing. This mismatch remains under diagnosis; old signing identity records are a possibility, not a proven cause. Version 0.3.1 writes the actual GUI process permission state to a local support report.
- Real cross-app selected-text capture, global keyboard invocation, full-screen ruler positioning, locked-overlay scrolling/click-through and global Esc need complete live acceptance. The automation tool's app-targeted input cannot establish all global-event behavior.
- Full-screen apps, Spaces and multiple displays require live verification.
- A short non-sensitive real MiniMax request returned HTTP 200, provider status 0 and 36,852 bytes of valid MP3. The Mac mini native CLI stored the authorized credential in Keychain and read back keyPresent=true. MacBook remote Keychain write returned -25308 (interaction unavailable), so that host is not yet configured. The installed Mac mini GUI used MiniMax, transitioned to playback and then “朗读完成”; the native voice settings confirmed the intended provider/model/voice.
- Developer ID signing, Apple notarization and a broadly distributed binary release are not completed. Development signing is not notarization.
- This product has not undergone clinical evaluation of reading outcomes.

## Manual acceptance

1. On each Mac, enable Accessibility for the installed Reeeead copy, quit/reopen, and confirm “辅助功能已开启”.
2. Open shortcut recording and physically press/release each side button. Test a modifier plus side button, duplicate assignment, cancel and relaunch. Confirm the configured action runs once and browser navigation does not also happen.
3. In TextEdit, select part of a sentence and invoke reading. Check that only the selection is read and the source app retains focus. Repeat in the browser, PDF reader and usual chat app.
4. Test copy fallback with known clipboard content; confirm restoration, no stale-text reading and cancellation cleanup.
5. Place a ruler over clickable content. Neither placement click should reach the underlying page. After lock, click/select/scroll the page; the band must remain fixed. Esc should close the ruler without closing a source-app dialog.
6. Test keyboard/side-button toggling in every ruler state, screen edges, full-screen apps, another Space and a second display.
7. Configure a real API locally and audition a non-sensitive sample; test invalid authentication and slow-response cancellation.
