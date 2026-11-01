# Architecture

Reeeead is a Swift Package executable wrapped in a normal `.app` by `scripts/build.sh`. SwiftUI handles settings; AppKit owns windows, menu-bar lifecycle and the screen overlay. It has no third-party runtime dependencies.

| Component | Responsibility |
| --- | --- |
| `AppModel` | Preferences, page state and shortcut changes |
| `HotKeyCenter` | Carbon keyboard hotkeys plus a narrowly filtered Quartz side-button tap; restore bindings on sheet dismissal |
| `MouseShortcutRouter` | Paired down/up consumption, exact modifier matching and one action on release |
| `SelectionReader` | Frontmost app's accessibility selection; UTF-16 range fallback; optional bounded clipboard copy |
| `SpeechEngine` | System synthesis, external audio, cancellation generations, pause/resume and errors |
| `KeyStore` | Keychain generic-password item per exact trimmed endpoint |
| `RulerController` | One transparent nonactivating panel on the initiating screen; temporary Esc event tap |
| `RulerGeometry` | Pure state machine: tracking → extending → locked |
| `RulerCanvas` | Draw lines and dim regions; swallow placement clicks; enable passthrough on second mouse-up |
| `AppDelegate` | Window/menu lifecycle, transient nonactivating status toasts |

## Ruler invariants

- The coordinate model uses a flipped, screen-local Y axis; the initial global mouse coordinate is converted from the screen's maximum Y.
- The first anchor is fixed. The second boundary cannot move above it; a band under 8 points cannot lock.
- Before locking, the overlay receives pointer input without activating or taking keyboard focus from the source application.
- The second mouse-up switches `ignoresMouseEvents` on; the click used to fix the band never becomes an accidental click in the source app.
- Locked geometry does not react to the pointer. Esc is consumed only while the ruler is active; the tap is destroyed on exit.
- Display changes and sleep close the overlay. Full-screen and multiple-display behavior require actual hardware/UI verification.

## Reading invariants

- A shortcut captures the frontmost application, never an arbitrary old clipboard value.
- Accessibility IPC has a short messaging timeout; copied text is read only after a pasteboard change.
- Every new playback/stop advances a generation token. Old network responses cannot resurrect canceled speech.
- System utterance and external-player completion callbacks check identity before updating state.
- External requests use ephemeral sessions, reject redirects, cap download size and delete temporary audio.
- API errors never surface response bodies that could contain echoed private text or credentials.

## Permissions and distribution

Global Carbon hotkeys do not require permission; reading another app's selected text, filtering side buttons and Esc require Accessibility. The ruler refuses to start when it cannot install the exit tap. Mouse recording reports unavailable access rather than claiming success. No screenshot permission or microphone permission is used.

The app is outside the App Sandbox because it integrates with other applications through accessibility. There is no privileged helper or background launch agent. Launch at login is not automatically enabled.

The build script accepts `REEEEAD_SIGN_IDENTITY` (legacy `LUMA_SIGN_IDENTITY` also works), or an ignored `local/signing-identity.txt`; without one it uses ad-hoc signing. Personal installs currently use an existing Apple Development identity. For public releases, validate TCC persistence across updates and add Developer ID signing and notarization.

## Mouse shortcut invariants

- Only `otherMouseDown`, `otherMouseUp`, and `otherMouseDragged` enter the side-button tap. Left, right and middle buttons are never accepted as shortcuts.
- Native zero-based button numbers 3...31 are displayed to the user as Mouse 4...32. Modifier matching ignores Caps Lock and Fn.
- A matched press is remembered until release, even if modifiers change. The complete matched pair and its drags are consumed. Unmatched presses pass through.
- Actions and recorder callbacks are dispatched after release. A generation token discards callbacks queued before reconfiguration.
- The mouse tap exists only when a side-button binding or recording session needs it. No mouse movement, text or click history is stored.
- The optional `mouseButton` field preserves decoding of existing keyboard preferences.
- Event types follow [Apple's Quartz documentation](https://developer.apple.com/documentation/coregraphics/cgeventtype).

## Naming compatibility

The product, executable and Swift package are named Reeeead as of 0.2. The existing bundle identifier `app.luma.reader`, preference key and Keychain service are retained so changing the visible name does not discard user settings or stored credentials.
