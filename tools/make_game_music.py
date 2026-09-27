"""Builds the in-game music loop from the lossless master.

The master ends on a bar line while the bass is at a waveform peak, so a raw
end-to-start splice clicks. This applies a 256-sample raised-cosine declick
fade right before the bar line (timing stays sample-exact) and encodes a CBR
MP3 without a Xing/LAME header, so every decoder yields the same stream with a
fixed encoder delay that the game skips (see Sfx.MUSIC_DELAY_FRAMES).

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
LOOP_FRAMES = 5_880_000
DECLICK_FRAMES = 256


def main() -> None:
    ffmpeg = sys.argv[1] if len(sys.argv) > 1 else "ffmpeg"
    raw = subprocess.run(
        [ffmpeg, "-v", "error", "-i", str(MASTER), "-map", "0:a", "-f", "f32le", "-ac", "2", "-ar", str(RATE), "-"],
        check=True, capture_output=True,
    ).stdout
    pcm = np.frombuffer(raw, dtype="<f4").reshape(-1, 2).copy()
    if len(pcm) != LOOP_FRAMES:
        sys.exit(f"master has {len(pcm)} frames, expected {LOOP_FRAMES}")

    ramp = 0.5 * (1.0 + np.cos(np.linspace(0.0, np.pi, DECLICK_FRAMES, dtype=np.float32)))
    pcm[-DECLICK_FRAMES:] *= ramp[:, None]

    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / "loop.wav"
        wavfile.write(wav, RATE, pcm)
        subprocess.run(
            [ffmpeg, "-v", "error", "-y", "-i", str(wav),
             "-metadata", "title=2048 Quiet Tiles", "-metadata", "artist=mahiron-hq",
             "-c:a", "libmp3lame", "-b:a", "192k", "-write_xing", "0", "-id3v2_version", "3", str(OUTPUT)],
            check=True,
        )
    print(f"wrote {OUTPUT.relative_to(ROOT)} ({OUTPUT.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
