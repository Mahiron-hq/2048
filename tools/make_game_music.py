"""Builds the in-game music loop from the lossless master.

The master ends on a bar line while the bass is still sounding, and the next
bar starts from silence, so a raw end-to-start splice clicks. The loop stays
exactly the master's length; instead, a short tail is appended after the loop
point: the master's end continued by point reflection (continuous in value and
slope) and faded out. Godot's MP3 beat loop mixes the frames that follow the
loop point onto the restart with a 256-frame fade, so the bass rings smoothly
into the downbeat, and the encoder never sees an abrupt edge at the seam.

The MP3 is CBR without a Xing/LAME header, so every decoder yields the same
stream with a fixed encoder delay that the game skips (Sfx.MUSIC_DELAY_FRAMES).

Usage: python tools/make_game_music.py [path/to/ffmpeg]
"""

import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from scipy.io import wavfile

ROOT = Path(__file__).resolve().parent.parent
MASTER = ROOT / "assets/music/2048_Quiet_Tiles.flac"
OUTPUT = ROOT / "assets/music/2048_Quiet_Tiles.mp3"
RATE = 44100
MASTER_FRAMES = 5_880_000
TAIL_FRAMES = 384


def build_tail(master: np.ndarray) -> np.ndarray:
    """Frames following the loop point: the master continued by point reflection, faded out."""
    tail = 2.0 * master[-1] - master[-2:-TAIL_FRAMES - 2:-1]
    fade = 0.5 * (1.0 + np.cos(np.linspace(0.0, np.pi, TAIL_FRAMES, dtype=np.float32)))
    return (tail * fade[:, None]).astype(np.float32)


def main() -> None:
    ffmpeg = sys.argv[1] if len(sys.argv) > 1 else "ffmpeg"
    raw = subprocess.run(
        [ffmpeg, "-v", "error", "-i", str(MASTER), "-map", "0:a", "-f", "f32le", "-ac", "2", "-ar", str(RATE), "-"],
        check=True, capture_output=True,
    ).stdout
    master = np.frombuffer(raw, dtype="<f4").reshape(-1, 2)
    if len(master) != MASTER_FRAMES:
        sys.exit(f"master has {len(master)} frames, expected {MASTER_FRAMES}")
    audio = np.concatenate([master, build_tail(master)])

    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / "loop.wav"
        wavfile.write(wav, RATE, audio)
        subprocess.run(
            [ffmpeg, "-v", "error", "-y", "-i", str(wav),
             "-metadata", "title=2048 Quiet Tiles", "-metadata", "artist=mahiron-hq",
             "-c:a", "libmp3lame", "-b:a", "192k", "-write_xing", "0", "-id3v2_version", "3", str(OUTPUT)],
            check=True,
        )
    print(f"wrote {OUTPUT.relative_to(ROOT)}: {len(master)} loop frames + {TAIL_FRAMES} tail ({OUTPUT.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
