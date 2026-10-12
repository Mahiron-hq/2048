"""Writes legal/rust-crates.txt: every crate compiled into the hint engine library, with its
version, license and source. The About screen shows the file.

Usage: python tools/rust_licenses.py   (needs cargo; reads native/Cargo.lock)
"""

import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "legal/rust-crates.txt"
ROOT_PACKAGE = "hint-engine"


def main() -> None:
    meta = json.loads(subprocess.run(
        ["cargo", "metadata", "--format-version", "1", "--locked"],
        cwd=ROOT / "native", check=True, capture_output=True, text=True,
    ).stdout)
    packages = {p["id"]: p for p in meta["packages"]}
    nodes = {n["id"]: n for n in meta["resolve"]["nodes"]}
    root = next(p["id"] for p in meta["packages"] if p["name"] == ROOT_PACKAGE)
    # Walk normal (not dev or build) dependencies: what ends up inside the library.
    seen, stack = set(), [root]
    while stack:
        pid = stack.pop()
        if pid in seen:
            continue
        seen.add(pid)
        for dep in nodes[pid]["deps"]:
            if any(k["kind"] is None for k in dep["dep_kinds"]):
                stack.append(dep["pkg"])
    lines = [
        "Rust libraries in the 2048 Merge hint engine",
        "",
        "The move hints come from a native library written in Rust. It is built from the game's own",
        "crates (Apache License 2.0) and these third-party crates, each under the license named here.",
        "godot-rust is under the Mozilla Public License 2.0; its source code is available at",
        "https://github.com/godot-rust/gdext and on https://crates.io/crates/godot.",
        "",
    ]
    for pid in sorted(seen, key=lambda i: packages[i]["name"]):
        p = packages[pid]
        if p.get("source") is None:
            continue
        source = p.get("repository") or "https://crates.io/crates/" + p["name"]
        lines.append(f"{p['name']} {p['version']} — {p.get('license') or 'see source'}")
        lines.append(f"  {source}")
    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    print(f"{OUT.relative_to(ROOT)}: {len(lines)} lines")


if __name__ == "__main__":
    main()
