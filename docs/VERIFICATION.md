# Verification — 0.3.2

## Screenshot clipboard fix — 2026-11-02

- Removed the type-based screenshot/file rejection in the real selection-copy fallback and replaced its 8 MB in-memory-only snapshot with bounded private temporary storage.
- 25 tests passed, 4 opt-in HTTP tests skipped (29 total). The unchanged HTTP/audio paths passed all four integration tests in 0.3.1.
- Six new tests use isolated native NSPasteboard instances: a 10 MB screenshot representation plus PNG/metadata restored byte-for-byte; multiple file URLs; protection of a later user copy; empty clipboard; private temporary-file permissions/cleanup; and budget failure with the original clipboard untouched.
- Release 0.3.2 built with one compiler job and installed on both Macs; per-file/signature checks passed and executable SHA-256 matched (`86570cb24331b28e694612a9b695afbab39540ccac11c6179dca5c7e3bf3cfe7`). The installed Mac mini app launched successfully.
- Physical shortcut selection capture after a real screenshot still needs user acceptance. These tests establish preservation using the native pasteboard, not physical input dispatch.

## Previous 0.3.1 evidence

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

## Additional live acceptance on 0.3.1

- Closed the main window while the ruler was active so the automation tool could target the actual full-screen overlay instead of the app's main window.
- Clicked at screen-relative y=300, then y=520 on the 1920×1080 display. The first click entered boundary selection; the second produced a fixed clear band between the two green lines with dimming above and below. The placement hint disappeared after lock. See [locked overlay screenshot](screenshot-ruler-locked.png); the screenshot captures the transparent overlay alone, so its clear region appears white.
- While the ruler remained locked, created a synthetic TextEdit document and scrolled it from bottom (scroll value 1) to top (0) using app-targeted automation. A subsequent overlay screenshot retained both boundaries at y=300 and y=520. This establishes stationary overlay geometry during another app's scroll; it does not independently prove physical mouse hit-testing through the overlay.
- Restored the app to its reading page and closed the ruler. The synthetic document is saved under ignored `local/` for future acceptance.
- The source build, tests and signature verification passed [GitHub Actions run 41323636760](https://github.com/YFJack/reeeead/actions/runs/41323636760) for code commit `1bf6b53`.

## Previous unchanged-engine checks

- Ruler geometry tests cover two clicks, fixed bounds, upward movement, minimum band height and screen-edge clamping.
- Request validation covers model/voice fields, speed, empty/oversized input, endpoint restrictions and absent API key.
- Local fixture integration exercised real HTTP/audio decoding and playback completion, pause/resume, cancellation before a delayed response, 401 handling and refusal to follow a 307 redirect.
- System-speech and local-fixture playback were exercised through the native UI on the previous functional baseline.
- The earlier baseline passed [GitHub Actions run 41320288673](https://github.com/YFJack/reeeead/actions/runs/41320288673) on macOS 15. Current commits trigger a separate CI run.

## Pending / not claimed

- Physical side-button events have not yet been confirmed end-to-end with the user's mouse. Successful preset saving and pure routing tests are not hardware acceptance. Mouse software may remap side buttons into keyboard macros or consumer events.
- The MacBook 0.3.1 GUI process now reports accessibilityTrusted=true and mouseTapReady=true at the installed path. This resolves the earlier app/system toggle mismatch for that running instance; the exact original cause is unproven. eventPostingAllowed remains false, so simulated-copy fallback still needs verification there. Physical ATK side-button recognition is awaiting the user's test.
- Real cross-app selected-text capture, global keyboard invocation and physical input through the locked overlay need complete live acceptance. App-targeted automation does not prove physical event dispatch. An app-targeted Escape in TextEdit did not dismiss the ruler; physical Esc remains unverified, and this observation alone cannot separate input injection behavior from an app defect. The in-app “收起” action did close it.
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


## 0.4.0 bilingual interface

- 31 XCTest cases passed with the local HTTP fixture enabled; no skips or failures.
- Language tests cover Chinese/English system resolution, explicit override, packaged resource parity, interpolation count and English messages.
- Live Mac mini UI: Chinese → English updates labels and menu names immediately; the default sample follows the language. Existing MiniMax provider, endpoint, voice and keyboard shortcuts remained visible. English screenshot captured from installed release.
- Release 0.4.0 installed on both configured Macs with matching per-file hashes and verified signatures. MacBook live language switching has not been exercised remotely.
- This update does not resolve the previously reported external-display/hardware acceptance gaps.


## 0.4.1 shortcut recording fix

- Replaced first-responder-dependent keyboard capture and separate global mouse recording with one sheet-scoped local event monitor. The sheet can record while a SwiftUI control has focus. Both input paths commit on release; dismissal removes the monitor, and losing key-window status clears pending input.
- Expanded keyboard mapping to function keys, arrows, navigation keys, numeric keypad and printable keys, including unmodified keys. Mouse recording supports middle/additional buttons and modified primary/secondary clicks. Plain left/right clicks still operate controls.
- 39 XCTest cases passed with the local HTTP fixture enabled, no failures or skips. Added regressions for previously rejected keys, local NSEvent mouse capture, modifier release before button release, repeated key events, Escape, teardown and legacy preferences. Synthetic events were constructed in tests, not posted to other applications.
- Mac mini native UI automation saved Control-Option-Up and F6, verified Escape cancellation, rejected duplicate Control-Option-L, then successfully saved Control-Option-R again. A CUA middle-click request arrived as Command + Mouse 1; that combination saved successfully. This verifies the local mouse recording path, not a physical middle click. Original Control-Option-R was restored after testing.
- Built 0.4.1 (8) with `-j 1`; deployed through `scripts/deploy.py` to both configured Macs. Per-file hashes and code signatures verified; installed executable SHA-256 on both: `3565ef0331a9b661e1e62bca750016ca1845f1bc3852d91a2eb8b266d0826b51`.
- MacBook was relaunched. Its new 0.4.1 GUI process reported Accessibility trusted, event posting allowed and mouse tap ready at the installed path. Before the fix, its 0.4.0 report also showed all three true; this session found no missing permission to explain the recording issue.
- Physical ATK button recording, global invocation from another app and MacBook visual interaction remain pending user/hardware acceptance. Local UI automation and deployment do not establish those results.


## 0.4.2 ruler placement input

- On the reported MacBook, both actions were bound to keyboard keys and the GUI permission report showed no mouse tap active. A mouse-shortcut event tap was therefore not intercepting left clicks in that configuration.
- Disabled panel movement and the transparent canvas's default mouse-down window-drag behavior. Added a 1% alpha placement surface, kept through the second mouse-up; the locked reading band becomes fully transparent and the panel explicitly ignores mouse events.
- Added a real WindowServer hit-test regression using the production panel configuration. It checks points away from the visible line/hint, the undimmed band after the first click, the held second click, passthrough after release, and unchanged locked geometry. A brief main-run-loop turn is required to commit window drawing before querying hit tests. The earlier canvas permits window dragging; the original MacBook physical-click failure itself was not remotely reproduced.
- All 40 XCTest cases passed with the local HTTP fixture enabled; zero failures/skips.
- Mac mini installed-app UI automation: first left click at y=300 changed the hint to bottom-edge placement; second left click at y=520 produced a clear fixed band with dimming above/below, and the app reported “Reading band locked.” Closed the test ruler afterward. App-targeted automation does not substitute for physical MacBook mouse acceptance.
- Release 0.4.2 (9) installed on both configured Macs with per-file hashes and signatures verified. Executable SHA-256: `4978368414daba3430b9e14168d6e60ddb4e1e85c443f63ade5d4e7aaf58d50d`. MacBook relaunched separately; physical mouse and external-display validation remain separate from deployment.


## 0.4.3 left/right Shift combinations

- Recording keeps device-specific Shift flags for keyboard and mouse combinations. Left, right and both Shift keys display distinctly. Existing bindings without `shiftSide` remain compatible with either side; re-recording with a physical keyboard opts into the distinction.
- Side-specific keyboard combinations use a temporary key event tap while configured. Left/right versions of the same base key can invoke different actions. Repeats are consumed without repeating the action; release uses the original down state even if Shift was released first. Unmatched events pass through. Generic old keyboard bindings still use Carbon.
- All 47 XCTest cases passed with the local HTTP fixture enabled, zero skips/failures. Added seven cases for raw device flags, localized labels and JSON round trips, legacy wildcard conflicts, opposite-side rejection, exact keyboard and mouse dispatch, autorepeat and release ordering, and recorder propagation. Tests construct input events without posting them to user applications.
- Live Mac mini UI accepts recording and restores the original Control-Option-R setting. CUA's `Shift_R+grave` injection produced only generic Shift in the delivered event, so it cannot verify a physical right Shift; the app intentionally preserves the generic binding when the event has no side information. Physical left/right recording and cross-app dispatch remain hardware acceptance items.
- Built 0.4.3 (10) with `-j 1`; installed both configured Macs through `scripts/deploy.py`. Per-file hashes and code signatures verified; executable SHA-256 on both: `b88a106a1cc3f8440bcc46a85d639ae64eb6e6a790ded818638603ca56709c3b`. MacBook was relaunched separately.

## 0.5.0 Window Focus

- Added a third configurable action, defaulting to physical Left Shift + Esc. It reads the frontmost application's focused window through Accessibility, leaves that rectangle clear, and dims the rest of every display. The mask follows window changes while enabled, passes mouse input through, and hides if the current window cannot be read. Screen changes/sleep stop it. It is mutually exclusive with the reading band.
- Existing preferences decode without the new optional shortcut field; voice settings and existing bindings are retained. A conflicting default does not replace an existing shortcut. Modified Escape is no longer swallowed by the ruler's plain-Escape exit handler.
- Full suite: 51 cases, zero failures, four unchanged opt-in HTTP/audio fixture tests skipped. After adding a raster regression, all five WindowFocusTests passed. Coverage includes left-only default routing and early Shift release, legacy/custom preference round trips, displays above/left of the primary display, spanning windows, invalid rectangles, and actual rendered alpha inside/outside the cutout and after it moves away.
- Built 0.5.0 (11) with `-j 1`. Both configured Macs installed through `scripts/deploy.py` with per-file hashes and code signatures verified. Installed executable SHA-256: `1033bec1a084dc71d5ffa3fe710659f8184ed85d9cc1e935de01dc96ad0bad89`.
- Mac mini installed UI shows the Window Focus control and Left Shift + Esc default; activation and deactivation updated state successfully. Local permission report confirms Accessibility trusted and keyboard tap ready. App-scoped screenshots do not establish the composited appearance of the whole desktop. CUA's app-targeted Escape did not reach the global handler; the overlay was stopped through its UI afterward. Physical shortcut/Escape, live movement tracking, Spaces/full-screen and external-display acceptance remain pending.
- MacBook launch request was accepted after installation; no MacBook visual/hardware acceptance is claimed.
