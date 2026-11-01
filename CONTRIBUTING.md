# Contributing

Keep the app small, native and predictable. Prefer one well-tested interaction over a new settings panel.

1. Open an issue describing the user-visible problem and reproduction steps.
2. Build with `./scripts/build.sh debug` and run `swift test -j 1`.
3. For input, window or shortcut changes, exercise the real UI: focus must stay with the source app, positioning clicks must not leak, and Esc must always exit the ruler.
4. For TTS changes, verify cancellation, authentication errors and redirect handling using the local fixture. Never commit live credentials, private selected text, logs or user preferences.
5. Include macOS version, tested apps and any remaining limits in your PR.

Accessibility matters: preserve readable text, keyboard access and descriptive control labels. Keep the window compact, with plain reading surfaces and minimal ornament. Avoid continuous screen capture, idle polling and large dependencies.

Source code and bundled artwork are covered by the repository's MIT license, subject to any rights that apply to generated material. Record provenance for any new assets. Do not add copyrighted font files without a compatible license.
