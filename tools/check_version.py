"""Checks that the version is set consistently and moves forward.

- every Android preset in export_presets.cfg has the same version/name as config/version in
  project.godot, and the same version/code; the iOS preset matches both;
- the version code is higher than in the previous release tag (when there is one);
- with --tag vX.Y.Z, the tag matches the project version.

Usage: python tools/check_version.py [--tag vX.Y.Z]
"""

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def presets(text: str) -> list[dict[str, str]]:
    found = []
    for block in re.split(r"^\[preset\.\d+\]$", text, flags=re.M)[1:]:
        fields = dict(re.findall(r'^([\w/]+)=(.*)$', block, re.M))
        found.append({k: v.strip('"') for k, v in fields.items()})
    return found


def version_code(text: str) -> int:
    codes = {p["version/code"] for p in presets(text) if p.get("platform") == "Android"}
    if len(codes) != 1:
        sys.exit(f"Android presets disagree on version/code: {sorted(codes)}")
    return int(codes.pop())


def main() -> None:
    project = (ROOT / "project.godot").read_text(encoding="utf-8")
    version = re.search(r'^config/version="([^"]+)"', project, re.M).group(1)
    text = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
    code = version_code(text)
    for p in presets(text):
        if p.get("platform") == "Android" and p.get("version/name") != version:
            sys.exit(f"preset {p['name']}: version/name {p.get('version/name')} is not {version}")
        if p.get("platform") == "iOS" and (p.get("application/short_version") != version or p.get("application/version") != str(code)):
            sys.exit(f"iOS preset: version {p.get('application/short_version')} ({p.get('application/version')}), expected {version} ({code})")
    if "--tag" in sys.argv:
        tag = sys.argv[sys.argv.index("--tag") + 1]
        if tag != f"v{version}":
            sys.exit(f"tag {tag} does not match the project version {version}")
    previous = subprocess.run(["git", "describe", "--tags", "--abbrev=0", "--match", "v*", "HEAD^"],
                              cwd=ROOT, capture_output=True, text=True)
    if previous.returncode == 0:
        tag = previous.stdout.strip()
        old = subprocess.run(["git", "show", f"{tag}:export_presets.cfg"], cwd=ROOT,
                             capture_output=True, text=True, check=True).stdout
        if code <= version_code(old):
            sys.exit(f"version/code {code} is not higher than {version_code(old)} in {tag}")
        print(f"version {version} ({code}), previous release {tag}")
    else:
        print(f"version {version} ({code})")


if __name__ == "__main__":
    main()
