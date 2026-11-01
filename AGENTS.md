# Project working agreements

- This Mac mini has limited memory and disk space. Build with `-j 1`; avoid parallel builds and unnecessary large copies.
- Keep the native window compact and visually quiet. Brand uses a pixel echo icon and a compact generated wordmark inspired by OpenDyslexic; body copy uses system fonts.
- The user requested installation on both their Mac mini and MacBook after every update. After building and validating a user-facing update, run `python3 scripts/deploy.py`. Targets are in ignored `local/deploy.json`; do not publish host addresses or credentials. If a configured host is unavailable, report that host as pending, never claim synchronization.
- Deployment verifies every bundled file and code signature, keeps one previous app bundle per host, and does not copy preferences or API keys. Launch and visual verification are separate from installation verification. Keep these evidence boundaries explicit.
