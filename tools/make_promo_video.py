"""Encodes the promo video frames into store videos and the README preview.

Render the frames first, once per language:
    godot --path . --fixed-fps 30 --script res://tools/make_promo_video.gd -- ru
Then:
    python tools/make_promo_video.py [path/to/ffmpeg]
Writes store/video/2048-merge-promo-<lang>.mp4 (with the soundtrack) and docs/preview.gif.
"""

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FRAMES = ROOT / "build/promo"
MUSIC = ROOT / "assets/music/2048_Quiet_Tiles.mp3"
LENGTH = 30.0
# README preview: the gameplay part, from the first swipes to the hint.
GIF_START, GIF_LENGTH, GIF_WIDTH, GIF_FPS = 4.0, 15.5, 320, 12


def run(*args: str) -> None:
    subprocess.run(args, check=True, capture_output=True)


def main() -> None:
    ffmpeg = sys.argv[1] if len(sys.argv) > 1 else "ffmpeg"
    out = ROOT / "store/video"
    out.mkdir(parents=True, exist_ok=True)
    for lang in ("ru", "en"):
        frames = FRAMES / lang
        if not (frames / "0000.jpg").exists():
            sys.exit(f"no frames in {frames}; render them with tools/make_promo_video.gd first")
        target = out / f"2048-merge-promo-{lang}.mp4"
        run(ffmpeg, "-y", "-framerate", "30", "-i", str(frames / "%04d.jpg"), "-i", str(MUSIC),
            "-filter_complex", f"[1:a]atrim=0:{LENGTH},afade=t=in:d=1.2,afade=t=out:st={LENGTH - 3}:d=3[a]",
            "-map", "0:v", "-map", "[a]", "-c:v", "libx264", "-preset", "slow", "-crf", "17",
            "-profile:v", "high", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k",
            "-t", str(LENGTH), "-movflags", "+faststart", str(target))
        print(target.relative_to(ROOT), f"{target.stat().st_size / 1e6:.1f} MB")

    gif = ROOT / "docs/preview.gif"
    scale = f"fps={GIF_FPS},scale={GIF_WIDTH}:-1:flags=lanczos"
    run(ffmpeg, "-y", "-ss", str(GIF_START), "-t", str(GIF_LENGTH), "-framerate", "30",
        "-i", str(FRAMES / "ru/%04d.jpg"), "-vf",
        f"{scale},split[a][b];[a]palettegen=max_colors=128:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle",
        str(gif))
    print(gif.relative_to(ROOT), f"{gif.stat().st_size / 1e6:.1f} MB")


if __name__ == "__main__":
    main()
