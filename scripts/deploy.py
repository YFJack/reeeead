#!/usr/bin/env python3
"""Install the same verified app locally and on explicitly configured SSH hosts."""
import hashlib
import json
import pathlib
import re
import shlex
import subprocess
import tarfile
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
APP = ROOT / "dist/Reeeead.app"


def run(args, **kwargs):
    return subprocess.run(args, check=True, text=True, **kwargs)


def install_script(stage):
    # Only application bundles are replaced; preferences and Keychain remain per Mac.
    return f'''set -eu
stage={shlex.quote(stage)}
dest="$HOME/Applications/Reeeead.app"
backup="$HOME/Applications/.Reeeead-previous.app"
cd "$stage"
shasum -a 256 -c SHA256SUMS >/dev/null
codesign --verify --deep --strict Reeeead.app
arch=$(uname -m)
lipo Reeeead.app/Contents/MacOS/Reeeead -verify_arch "$arch"
pids=$(pgrep -f "^$dest/Contents/MacOS/Reeeead$" || true)
if [ -n "$pids" ]; then
  kill -TERM $pids
  for n in 1 2 3 4 5; do
    if ! pgrep -f "^$dest/Contents/MacOS/Reeeead$" >/dev/null; then break; fi
    sleep 1
  done
  if pgrep -f "^$dest/Contents/MacOS/Reeeead$" >/dev/null; then
    echo 'App is still running; installation aborted.' >&2; exit 1
  fi
fi
if [ -d "$dest" ]; then
  rm -rf "$backup"
  mv "$dest" "$backup"
fi
if ! mv Reeeead.app "$dest"; then
  if [ -d "$backup" ]; then mv "$backup" "$dest"; fi
  exit 1
fi
codesign --verify --deep --strict "$dest"
/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$dest/Contents/Info.plist"
shasum -a 256 "$dest/Contents/MacOS/Reeeead"
rm "$stage/SHA256SUMS"
rmdir "$stage"
'''


def main():
    run(["codesign", "--verify", "--deep", "--strict", str(APP)])
    config = ROOT / "local/deploy.json"
    hosts = json.loads(config.read_text()).get("ssh_hosts", []) if config.exists() else []
    for host in hosts:
        if not isinstance(host, str) or not re.fullmatch(r"[A-Za-z0-9_][A-Za-z0-9_.@-]*", host):
            raise ValueError("Invalid SSH host")
    with tempfile.TemporaryDirectory(prefix="reeeead-deploy-") as tmp:
        archive = pathlib.Path(tmp) / "app.tar"
        sums = pathlib.Path(tmp) / "SHA256SUMS"
        sums.write_text("".join(
            f"{hashlib.sha256(p.read_bytes()).hexdigest()}  Reeeead.app/{p.relative_to(APP)}\n"
            for p in sorted(APP.rglob("*")) if p.is_file()
        ))
        with tarfile.open(archive, "w") as tar:
            tar.add(APP, arcname="Reeeead.app")
            tar.add(sums, arcname="SHA256SUMS")
        failures = []
        for host in [None, *hosts]:
            name = host or "local"
            stage = None
            try:
                ssh = ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=8", host] if host else []
                command = 'mkdir -p "$HOME/Applications"; mktemp -d "$HOME/Applications/.reeeead-stage.XXXXXX"'
                stage = run(ssh + [command] if host else ["sh", "-c", command], capture_output=True).stdout.strip()
                if not re.fullmatch(r"/[^\n]+/Applications/\.reeeead-stage\.[A-Za-z0-9]+", stage):
                    stage = None
                    raise ValueError("Unexpected staging path")
                with archive.open("rb") as stream:
                    unpack = "tar -xf - -C " + shlex.quote(stage)
                    run(ssh + [unpack] if host else ["sh", "-c", unpack], stdin=stream)
                script = install_script(stage)
                result = run(ssh + ["sh -s"] if host else ["sh"], input=script, capture_output=True)
                print(f"{name}: installed and verified\n{result.stdout}", flush=True)
            except (subprocess.CalledProcessError, ValueError) as error:
                failures.append(name)
                print(f"{name}: FAILED: {getattr(error, 'stderr', '') or error}", flush=True)
            finally:
                if stage:
                    cleanup = "rm -rf " + shlex.quote(stage)
                    subprocess.run(ssh + [cleanup] if host else ["sh", "-c", cleanup], capture_output=True)
        if failures:
            raise SystemExit("Not synchronized: " + ", ".join(failures))


if __name__ == "__main__":
    main()
