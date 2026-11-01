# Verification — 0.3.0

Validation date: 2026-11-01. Build host: Apple Silicon Mac mini, macOS 26.5.2, Swift 6.3.3. Second install: Apple Silicon MacBook, macOS 26.2. Minimum supported target is macOS 14; older supported OS versions have not been manually tested.

## Completed on this build

- Release build with one compiler job. Installed bundle is approximately 2.1 MB.
- 14 automated tests pass: 7 core/branding tests and 7 mouse-shortcut tests. The 3 opt-in HTTP/audio integration tests are skipped in the default invocation. These 3 integration tests passed on the preceding build; the speech engine was not changed in this update.
- Mouse tests cover legacy keyboard decoding, side-button serialization, conflict detection, ignoring ordinary clicks and unmatched modifiers, complete down/up consumption, release after modifier changes, a single action per press, simultaneous buttons and recording on release.
- The unmodified OpenDyslexic font loads from the bundled resources without system installation, and its OFL license is included.
- Native UI: the new generated wordmark renders in the compact window. Home and shortcut-recorder screenshots are saved in this directory.
- Native UI: the side-button recorder can install its event tap on the Mac mini after Accessibility is enabled. The Mouse 4 preset saves, survives an app restart and displays correctly. Attempting to assign it to the other action is rejected. Cancel restores registrations. Keyboard recording still works; test changes were restored to the original keyboard bindings.
- Accessibility was rebound to the final installed Mac mini app and recognized after restart. On the earlier 0.2.1 build, the ruler successfully entered its active state after permission was granted; this alone does not verify positioning/click-through.
- Both Macs received the same 0.3.0 app. The installer checked SHA-256 for every bundled file, architecture compatibility and code signature. Installed executable hashes matched on both hosts.
- Both personal installations now use an existing Apple Development identity. The signing identity configuration remains local and ignored by Git. No private key or API key is copied by deployment.

## Previous unchanged-engine checks

- Ruler geometry tests cover two clicks, fixed bounds, upward movement, minimum band height and screen-edge clamping.
- Request validation covers model/voice fields, speed, empty/oversized input, endpoint restrictions and absent API key.
- Local fixture integration exercised real HTTP/audio decoding and playback completion, pause/resume, cancellation before a delayed response, 401 handling and refusal to follow a 307 redirect.
- System-speech and local-fixture playback were exercised through the native UI on the previous functional baseline.
- The earlier baseline passed [GitHub Actions run 41320288673](https://github.com/YFJack/reeeead/actions/runs/41320288673) on macOS 15. Current commits trigger a separate CI run.

## Pending / not claimed

- Physical side-button events have not yet been confirmed end-to-end with the user's mouse. Successful preset saving and pure routing tests are not hardware acceptance. Mouse software may remap side buttons into keyboard macros or consumer events.
- The MacBook app is installed and running; its user reported Accessibility as not enabled. Local permissions cannot be copied between Macs. Follow-up authorization and physical input testing are in progress.
- Real cross-app selected-text capture, global keyboard invocation, full-screen ruler positioning, locked-overlay scrolling/click-through and global Esc need complete live acceptance. The automation tool's app-targeted input cannot establish all global-event behavior.
- Full-screen apps, Spaces and multiple displays require live verification.
- No real external-provider credentials were used. Fixture tests do not prove a provider's authentication, voice quality, quotas, latency or billing. Actual user-secret Keychain storage has not been exercised with a real credential.
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
