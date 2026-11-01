# Security

Do not put API keys, selected document contents, clipboard captures or personal diagnostics in public issues.

For a suspected vulnerability, use GitHub's private vulnerability reporting on this repository when available. If unavailable, open a minimal issue asking for a private reporting channel without publishing exploitation details or sensitive data.

The app uses the macOS Keychain for API keys, rejects remote non-HTTPS speech endpoints and redirects, and does not provide its own cloud backend. The optional copy fallback temporarily handles clipboard data; turn it off if your workflow cannot tolerate clipboard replacement or backup.

Please include the app version, macOS version, affected component and a minimal reproduction with dummy data. No response time or security audit is implied.
