"""Builds the Android packages exactly as the release workflow does, here or in CI.

Usage: python tools/export_android.py [preset ...]
  presets: arm64, armv7, universal, aab (default: all four)

Steps: builds the Rust hint engine for Android, installs the Gradle build template if missing,
exports each preset with Godot, re-signs the APKs with APK Signature Scheme v2 and v3 (v3 allows
a later key rotation), and checks every package carries the expected certificate, version and ABIs.

Environment:
  GODOT                                  Godot executable (default: godot)
  ANDROID_HOME                           Android SDK; build-tools 36.1.0 must be installed
  ANDROID_NDK_HOME                       NDK for the Rust build (29.0.14206865)
  GODOT_ANDROID_KEYSTORE_RELEASE_PATH    release keystore
  GODOT_ANDROID_KEYSTORE_RELEASE_USER    key alias
  GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD
  RELEASE_CERT_SHA256                    expected certificate fingerprint (optional)
Outputs go to build/ as 2048-Merge-v<version>-<abi>.apk and 2048-Merge-v<version>.aab.
"""

import os
import re
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / "build"
BUILD_TOOLS = "36.1.0"
# Gradle that the 4.7.2 build template downloads, and its published SHA-256: the wrapper refuses
# a distribution that does not match.
GRADLE_DIST = "gradle-8.11.1-bin.zip"
GRADLE_SHA256 = "f397b287023acdba1e9f6fc5ea72d22dd63669d59ed4a289a29b1a76eee151c6"
# Checksums of every Maven artifact the template resolves; Gradle stops on any other.
VERIFICATION = ROOT / "tools/gradle/verification-metadata.xml"
# Preset name, output name suffix, native-code ABIs it must contain.
PRESETS = {
    "arm64": ("Android", "arm64-v8a", "apk", ["arm64-v8a"]),
    "armv7": ("Android armeabi-v7a", "armeabi-v7a", "apk", ["armeabi-v7a"]),
    "universal": ("Android universal", "universal", "apk", ["arm64-v8a", "armeabi-v7a"]),
    "aab": ("Android AAB", "", "aab", ["arm64-v8a", "armeabi-v7a"]),
}


def run(args: list[str], **kw) -> subprocess.CompletedProcess:
    return subprocess.run(args, check=True, **kw)


def godot() -> str:
    return os.environ.get("GODOT", "godot")


def tool(name: str) -> str:
    sdk = Path(os.environ["ANDROID_HOME"]) / "build-tools" / BUILD_TOOLS
    for candidate in (name, name + ".exe", name + ".bat"):
        if (sdk / candidate).exists():
            return str(sdk / candidate)
    sys.exit(f"{name} not found in {sdk}")


def project_version() -> str:
    text = (ROOT / "project.godot").read_text(encoding="utf-8")
    return re.search(r'^config/version="([^"]+)"', text, re.M).group(1)


def godot_version() -> str:
    out = run([godot(), "--version"], capture_output=True, text=True).stdout.strip()
    # "4.7.2.stable.official.ed1daf0bf" -> "4.7.2.stable"
    return ".".join(out.split(".")[:4])


def install_template() -> None:
    version = godot_version()
    marker = ROOT / "android/.build_version"
    build = ROOT / "android/build"
    if marker.exists() and marker.read_text().strip() == version and build.is_dir():
        return
    templates = {
        "win32": Path(os.environ.get("APPDATA", "")) / "Godot/export_templates",
        "linux": Path.home() / ".local/share/godot/export_templates",
    }[sys.platform]
    source = templates / version / "android_source.zip"
    if not source.exists():
        sys.exit(f"export templates for {version} are not installed ({source})")
    shutil.rmtree(build, ignore_errors=True)
    build.mkdir(parents=True)
    with zipfile.ZipFile(source) as z:
        z.extractall(build)
    marker.write_text(version + "\n")
    (build / ".gdignore").touch()
    # A lingering Gradle daemon keeps Godot's export process from exiting.
    with open(build / "gradle.properties", "a", encoding="utf-8") as f:
        f.write("\norg.gradle.daemon=false\n")
    wrapper = build / "gradle/wrapper/gradle-wrapper.properties"
    if GRADLE_DIST not in wrapper.read_text(encoding="utf-8"):
        sys.exit(f"the build template no longer uses {GRADLE_DIST}: update GRADLE_SHA256 and {VERIFICATION.name}")
    with open(wrapper, "a", encoding="utf-8") as f:
        f.write(f"distributionSha256Sum={GRADLE_SHA256}\n")
    shutil.copy2(VERIFICATION, build / "gradle/verification-metadata.xml")
    print(f"installed the {version} Gradle build template")


def export(key: str, version: str) -> Path:
    preset, suffix, ext, abis = PRESETS[key]
    name = f"2048-Merge-v{version}-{suffix}.{ext}" if suffix else f"2048-Merge-v{version}.{ext}"
    out = BUILD / name
    out.unlink(missing_ok=True)
    # Fresh Gradle intermediates per preset: switching ABIs must not reuse old outputs.
    shutil.rmtree(ROOT / "android/build/build", ignore_errors=True)
    run([godot(), "--headless", "--path", str(ROOT), "--export-release", preset, str(out)], timeout=1800)
    if not out.exists() or out.stat().st_size == 0:
        sys.exit(f"export of {preset} produced no file")
    if ext == "apk":
        resign(out)
    verify(out, version, abis)
    return out


def resign(apk: Path) -> None:
    signed = apk.with_suffix(".signed.apk")
    run([tool("apksigner"), "sign",
         "--ks", os.environ["GODOT_ANDROID_KEYSTORE_RELEASE_PATH"],
         "--ks-key-alias", os.environ["GODOT_ANDROID_KEYSTORE_RELEASE_USER"],
         "--ks-pass", "env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD",
         "--key-pass", "env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD",
         "--v1-signing-enabled", "false", "--v2-signing-enabled", "true", "--v3-signing-enabled", "true",
         "--out", str(signed), str(apk)])
    signed.replace(apk)
    apk.with_suffix(".apk.idsig").unlink(missing_ok=True)


def verify(package: Path, version: str, abis: list[str]) -> None:
    want = os.environ.get("RELEASE_CERT_SHA256", "").lower()
    with zipfile.ZipFile(package) as z:
        names = z.namelist()
    prefix = "base/lib/" if package.suffix == ".aab" else "lib/"
    for abi in abis:
        if not any(n.startswith(f"{prefix}{abi}/") and n.endswith("libhint_engine.so") for n in names):
            sys.exit(f"{package.name}: the hint engine for {abi} is missing")
    if package.suffix == ".apk":
        certs = run([tool("apksigner"), "verify", "-v", "--print-certs", str(package)],
                    capture_output=True, text=True).stdout
        if "Verified using v3 scheme (APK Signature Scheme v3): true" not in certs:
            sys.exit(f"{package.name}: not signed with scheme v3")
        if want and f"certificate SHA-256 digest: {want}" not in certs:
            sys.exit(f"{package.name}: not signed with the release certificate")
        badging = run([tool("aapt2"), "dump", "badging", str(package)], capture_output=True, text=True).stdout
        if f"versionName='{version}'" not in badging:
            sys.exit(f"{package.name}: versionName is not {version}")
        native = re.search(r"native-code: (.*)", badging).group(1)
        if sorted(re.findall(r"'([^']+)'", native)) != sorted(abis):
            sys.exit(f"{package.name}: native code {native}, expected {abis}")
    elif want:
        out = run(["keytool", "-printcert", "-jarfile", str(package)], capture_output=True, text=True).stdout
        colons = ":".join(want[i:i + 2] for i in range(0, len(want), 2)).upper()
        if f"SHA256: {colons}" not in out:
            sys.exit(f"{package.name}: not signed with the release certificate")
    print(f"{package.relative_to(ROOT)}: {package.stat().st_size / 1e6:.1f} MB, verified")


def main() -> None:
    keys = sys.argv[1:] or list(PRESETS)
    unknown = set(keys) - set(PRESETS)
    if unknown:
        sys.exit(f"unknown preset(s): {', '.join(sorted(unknown))}")
    for var in ("GODOT_ANDROID_KEYSTORE_RELEASE_PATH", "GODOT_ANDROID_KEYSTORE_RELEASE_USER",
                "GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD", "ANDROID_HOME"):
        if not os.environ.get(var):
            sys.exit(f"{var} is not set")
    BUILD.mkdir(exist_ok=True)
    run([sys.executable, str(ROOT / "tools/build_native.py"), "android"])
    install_template()
    run([godot(), "--headless", "--path", str(ROOT), "--import"], timeout=1800)
    version = project_version()
    for key in keys:
        export(key, version)


if __name__ == "__main__":
    main()
