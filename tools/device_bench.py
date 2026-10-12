"""Runs the measurement build on a phone and records what it costs.

Usage: python tools/device_bench.py <adb serial> <bench apk> <out.json> [package]
  package: com.mahiron.merge2048.bench (default), or com.mahiron.merge2048 for the in-place build

The bench build keeps its own save file, and under the default package the player's game is not
touched at all. For each phase the bench prints, this samples /proc for the game process, its GPU
driver threads and SurfaceFlinger, and computes their CPU time as a share of one core. The long
battery phases run with Android told the phone is unplugged (the cable stays in) and read the
power estimate batterystats keeps per app. Hint timings and memory are recorded too. Needs adb on
PATH or ADB set to its path.
"""

import json
import os
import re
import subprocess
import sys
import time

PACKAGE = sys.argv[4] if len(sys.argv) > 4 else "com.mahiron.merge2048.bench"
ACTIVITY = PACKAGE + "/com.godot.game.GodotAppLauncher"
ADB = os.environ.get("ADB", "adb")
HZ = 100  # USER_HZ on Android kernels


def adb(serial: str, *args: str, check: bool = True) -> str:
    done = subprocess.run([ADB, "-s", serial, *args], capture_output=True, text=True,
                          encoding="utf-8", errors="replace")
    if check and done.returncode != 0:
        sys.exit(f"adb {' '.join(args)} failed: {(done.stderr or done.stdout).strip()}")
    return done.stdout


def shell(serial: str, command: str) -> str:
    return adb(serial, "shell", command, check=False)


def pid_of(serial: str, name: str) -> str:
    return shell(serial, f"pidof {name}").strip().split(" ")[0]


def snapshot(serial: str, pid: str, sf: str) -> dict:
    out = shell(serial, f"cat /proc/uptime; cat /proc/{pid}/stat; for t in /proc/{pid}/task/*; do cat $t/stat; done; cat /proc/{sf}/stat")
    lines = [l for l in out.splitlines() if l.strip()]
    uptime = float(lines[0].split()[0])

    def ticks(line: str) -> tuple[str, int]:
        name = line[line.index("(") + 1:line.rindex(")")]
        fields = line[line.rindex(")") + 2:].split()
        return name, int(fields[11]) + int(fields[12])

    _, process = ticks(lines[1])
    gpu = sum(t for n, t in map(ticks, lines[2:-1]) if n.lower().startswith(("mali", "gpu", "kgsl", "pvr")))
    _, flinger = ticks(lines[-1])
    return {"uptime": uptime, "process": process, "gpu": gpu, "flinger": flinger}


def share(a: dict, b: dict, key: str) -> float:
    return round((b[key] - a[key]) / HZ / (b["uptime"] - a["uptime"]) * 100.0, 1)


def thermal(serial: str) -> list[str]:
    out = shell(serial, "dumpsys thermalservice")
    return re.findall(r"Temperature\{mValue=([\d.]+), mType=\d+, mName=([^,]+),", out)[:6]


def main() -> None:
    serial, apk, out_path = sys.argv[1:4]
    adb(serial, "install", "-r", apk)
    shell(serial, f"am force-stop {PACKAGE}")
    if PACKAGE.endswith(".bench"):
        shell(serial, "pm clear " + PACKAGE)
    adb(serial, "logcat", "-c")
    shell(serial, f"am start -n {ACTIVITY}")
    time.sleep(3)
    pid = pid_of(serial, PACKAGE)
    sf = pid_of(serial, "surfaceflinger")
    result = {"device": shell(serial, "getprop ro.product.model").strip(),
              "android": shell(serial, "getprop ro.build.version.release").strip(),
              "soc": shell(serial, "getprop ro.soc.model").strip(),
              "phases": {}, "hints": [], "info": "", "thermal_start": thermal(serial)}
    log = subprocess.Popen([ADB, "-s", serial, "logcat", "-v", "brief", "-s", "godot:*"],
                           stdout=subprocess.PIPE, text=True, encoding="utf-8", errors="replace")
    begins = {}
    for line in log.stdout:
        if "BENCH|" not in line:
            continue
        msg = line[line.index("BENCH|"):].strip()
        parts = msg.split("|")
        print(msg, flush=True)
        if parts[1] == "info":
            result["info"] = msg
        elif parts[1] == "begin":
            name = parts[2]
            if name.startswith("battery-"):
                shell(serial, "dumpsys battery unplug")
                shell(serial, "dumpsys batterystats --reset")
                result["thermal_" + name + "_start"] = thermal(serial)
            begins[name] = snapshot(serial, pid, sf)
        elif parts[1] == "end":
            name = parts[2]
            end = snapshot(serial, pid, sf)
            a = begins.pop(name)
            phase = {"seconds": round(end["uptime"] - a["uptime"], 1),
                     "game_cpu": share(a, end, "process"), "gpu_driver_cpu": share(a, end, "gpu"),
                     "surfaceflinger_cpu": share(a, end, "flinger"), "frames": parts[3] if len(parts) > 3 else ""}
            if name.startswith("battery-"):
                stats = shell(serial, f"dumpsys batterystats {PACKAGE}")
                uid_line = re.search(r"UID u0a\d+: ([\d.]+) .*", stats)
                phase["estimated_mah"] = float(uid_line.group(1)) if uid_line else None
                phase["estimate_line"] = uid_line.group(0).strip() if uid_line else ""
                screen = re.search(r"screen: ([\d.]+)", stats)
                phase["screen_mah"] = float(screen.group(1)) if screen else None
                phase["thermal_end"] = thermal(serial)
                shell(serial, "dumpsys battery reset")
            if name == "play-5-moves-per-s":
                mem = shell(serial, f"dumpsys meminfo {PACKAGE}")
                total = re.search(r"TOTAL PSS:\s+(\d+)", mem) or re.search(r"TOTAL\s+(\d+)", mem)
                result["memory_pss_kb"] = int(total.group(1)) if total else None
            result["phases"][name] = phase
        elif parts[1] == "hint":
            side, level, ms, depth, nodes, finish, answer = parts[2:9]
            result["hints"].append({"side": int(side), "level": int(level), "ms": float(ms), "depth": int(depth),
                                    "nodes": int(nodes), "finish": finish, "answer": int(answer)})
        elif parts[1] == "done":
            break
    log.terminate()
    shell(serial, "dumpsys battery reset")
    shell(serial, f"am force-stop {PACKAGE}")
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=1)
    print("wrote", out_path)


if __name__ == "__main__":
    main()
