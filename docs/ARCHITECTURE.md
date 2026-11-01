# Architecture

Luma is a Swift Package executable wrapped in a normal `.app` by `scripts/build.sh`. SwiftUI handles settings; AppKit owns windows, menu-bar lifecycle and the screen overlay. It has no third-party runtime dependencies.

| Component | Responsibility |
| --- | --- |
| `AppModel` | Preferences, page state and shortcut changes |
| `HotKeyCenter` | Carbon hotkey registration; unregister during recording; restore on sheet dismissal |
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

Global Carbon hotkeys do not require permission; reading another app's selected text and filtering Esc require Accessibility. The ruler refuses to start when it cannot install the exit tap. No screenshot permission or microphone permission is used.

The app is outside the App Sandbox because it integrates with other applications through accessibility. There is no privileged helper or background launch agent. Launch at login is not automatically enabled.

For production releases, maintain a stable signing identity, validate TCC persistence across updates and add Developer ID notarization. The current build script produces a locally runnable ad-hoc-signed bundle.
