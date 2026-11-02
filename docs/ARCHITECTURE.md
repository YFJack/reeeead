# Architecture

Reeeead is a Swift Package executable wrapped in a normal `.app` by `scripts/build.sh`. SwiftUI handles settings; AppKit owns windows, menu-bar lifecycle and the screen overlay. It has no third-party runtime dependencies.

| Component | Responsibility |
| --- | --- |
| `AppModel` | Preferences, page state and shortcut changes |
| `HotKeyCenter` | Carbon keyboard hotkeys plus a narrowly filtered Quartz side-button tap; restore bindings on sheet dismissal |
| `MouseShortcutRouter` | Paired down/up consumption, exact modifier matching and one action on release |
| `ClipboardSnapshot` | Preserve all clipboard items/formats; 1 MB in-memory budget, private temporary storage for larger data, 256 MB total cap, change-count guarded restore and scoped cleanup |
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

## Shortcut recording and dispatch

- Keyboard and mouse recording use a sheet-scoped local event monitor before responder/menu dispatch, so focus moving to a SwiftUI button does not break recording. It commits on key release, removes its monitor on dismissal and clears pending input when the sheet loses focus. Plain Escape cancels; modified Escape can be assigned.
- Keyboard bindings use Carbon global hotkey registration. Letters, function/navigation keys, arrows and numeric keypad keys can be used with or without modifiers. System-reserved combinations can fail registration.
- The mouse tap observes down/up/drag events for all mouse buttons. Middle/additional buttons are accepted directly; primary/secondary buttons require modifiers so ordinary clicking remains available. Recording only captures while the app and its sheet are active.
- Native zero-based button numbers 0...31 are displayed to the user as Mouse 1...32. Modifier matching ignores Caps Lock and Fn.
- A matched press is remembered until release, even if modifiers change. The complete matched pair and its drags are consumed. Unmatched presses pass through.
- Actions and recorder callbacks are dispatched after release. A generation token discards callbacks queued before reconfiguration.
- The global mouse tap exists only when a saved mouse binding needs it; recording uses the local monitor. No mouse movement, text or click history is stored.
- The optional `mouseButton` field preserves decoding of existing keyboard preferences.
- Local keyboard capture follows [Apple’s event monitor documentation](https://developer.apple.com/documentation/appkit/nsevent/addlocalmonitorforevents(matching:handler:)).
- Event types follow [Apple's Quartz documentation](https://developer.apple.com/documentation/coregraphics/cgeventtype).

## Naming compatibility

The product, executable and Swift package are named Reeeead as of 0.2. The existing bundle identifier `app.luma.reader`, preference key and Keychain service are retained so changing the visible name does not discard user settings or stored credentials.

### Screenshot clipboard regression (0.3.2)

The copy fallback no longer rejects PNG/TIFF/file URL types or the former 8 MB limit. It snapshots every representation before requesting copy, keeps up to 1 MB resident, and spills larger representations to a unique 0700 directory with 0600 files. No image decoding or recompression occurs. Snapshots must complete without a clipboard change; failure leaves the original board untouched. Restore checks the expected change count both before loading representations and immediately before writing. Snapshot files are removed on normal completion, cancellation and setup failure. A process crash can leave OS-temporary files until system cleanup.

The fallback still waits for fresh copy data, reads only text, and performs cleanup before propagating task cancellation. Clipboard-manager races, source-app changes and delayed copy remain explicit limitations; this does not add OCR or read the screenshot itself.
