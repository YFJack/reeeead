# Install on multiple Macs

Build once with `./scripts/build.sh release`, then run `python3 scripts/deploy.py`. With no configuration, it installs to `~/Applications/Reeeead.app` on this Mac only.

To add already-authorized SSH destinations, create the ignored `local/deploy.json`:

```json
{"ssh_hosts": ["your-macbook-ssh-alias"]}
```

The installer uses existing SSH authentication, checks architecture compatibility, verifies every bundled file by SHA-256 and verifies the code signature before installation. It keeps one prior bundle at `~/Applications/.Reeeead-previous.app`. An already running copy is stopped gracefully. It reports each destination separately and exits unsuccessfully if any destination fails. Re-run when an offline Mac returns; no background service or periodic network activity is installed.

Only the app is copied. Each Mac retains its own preferences, API keys and macOS permissions. The script does not launch the remote app or claim a visual test. Open Reeeead from Applications after installation. Accessibility authorization is required separately on each Mac.

The build defaults to ad-hoc signing; an existing identity may be supplied through `REEEEAD_SIGN_IDENTITY` or ignored `local/signing-identity.txt`. The two personal installs currently use the same Apple Development identity, giving future builds a consistent designated requirement. Each Mac still needs its own initial Accessibility authorization. If an old ad-hoc authorization is stale, remove only Reeeead from the system Accessibility list, add the installed copy again, then quit and reopen it. The installer does not bypass Gatekeeper or modify the permission database. Developer ID signing and notarization for broad distribution remain unfinished.
