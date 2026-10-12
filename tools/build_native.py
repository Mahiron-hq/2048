"""Builds the Rust hint engine (native/) and places the libraries where
addons/hint_engine/hint_engine.gdextension expects them.

Usage: python tools/build_native.py [host] [android] [android-x86_64]
  host            the library for this computer (Windows or Linux), used by the editor and the tests
  android         arm64-v8a and armeabi-v7a, for the APKs and the bundle
  android-x86_64  for the x86_64 emulator
With no arguments, builds host and android.

Android builds need cargo-ndk (cargo install cargo-ndk), the Rust targets aarch64-linux-android and
armv7-linux-androideabi, and ANDROID_NDK_HOME pointing at the NDK.
"""

import platform
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
NATIVE = ROOT / "native"
TARGET = NATIVE / "target"
BIN = ROOT / "addons/hint_engine/bin"
# The lowest Android API the game supports (gradle_build/min_sdk in export_presets.cfg).
ANDROID_API = "26"
ANDROID_ABIS = {
    "arm64-v8a": "aarch64-linux-android",
    "armeabi-v7a": "armv7-linux-androideabi",
    "x86_64": "x86_64-linux-android",
}


def cargo(*args: str) -> None:
    subprocess.run(["cargo", *args], cwd=NATIVE, check=True)


def build_host() -> None:
    cargo("build", "--release", "-p", "hint-engine")
    system = platform.system()
    if system == "Windows":
        src, dest = TARGET / "release/hint_engine.dll", BIN / "windows-x86_64/hint_engine.dll"
    elif system == "Linux":
        src, dest = TARGET / "release/libhint_engine.so", BIN / "linux-x86_64/libhint_engine.so"
    else:
        sys.exit(f"no host library defined for {system}")
    place(src, dest)


def build_android(abis: list[str]) -> None:
    args = ["ndk", "-P", ANDROID_API]
    for abi in abis:
        args += ["-t", abi]
    cargo(*args, "build", "--release", "-p", "hint-engine")
    for abi in abis:
        place(TARGET / ANDROID_ABIS[abi] / "release/libhint_engine.so", BIN / f"android-{abi}/libhint_engine.so")


def place(src: Path, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dest)
    print(f"{dest.relative_to(ROOT)}: {dest.stat().st_size / 1e6:.2f} MB")


def main() -> None:
    wanted = sys.argv[1:] or ["host", "android"]
    unknown = set(wanted) - {"host", "android", "android-x86_64"}
    if unknown:
        sys.exit(f"unknown target(s): {', '.join(sorted(unknown))}")
    if "host" in wanted:
        build_host()
    if "android" in wanted:
        build_android(["arm64-v8a", "armeabi-v7a"])
    if "android-x86_64" in wanted:
        build_android(["x86_64"])


if __name__ == "__main__":
    main()
