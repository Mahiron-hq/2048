# Performance and battery

Measured on 2026-10-12 and 13 with version 1.3.1 on two phones:

| | Infinix NOTE 50 Pro (X6855) | Redmi Note 10S (M2101K7BNY) |
|---|---|---|
| Android | 16 (XOS) | 13 (MIUI) |
| SoC, GPU | MediaTek MT6789, Mali-G57 MC2 | MediaTek MT6785, Mali-G76 MC4 |
| Display | 1080×2436, 60/120/144 Hz (120 Hz chosen in its settings) | 1080×2400, 60 Hz |

The bench build (`python tools/export_android.py bench-in-place`) is the release build plus [`tests/bench/driver.gd`](../tests/bench/driver.gd), which steps through the phases below and keeps its own save file. [`tools/device_bench.py`](../tools/device_bench.py) installs it, follows its log and samples `/proc` between the start and end of each phase. Screens stayed on at minimum brightness, phones on the cable.

## Drawing and CPU

CPU time as a share of one core over 20 s (10 min for the last two rows): the game process, its GPU driver threads, and SurfaceFlinger (the system compositor). Graphics quality is high unless stated.

| Phase | Infinix: frames/s | game | GPU driver | compositor | Redmi: frames/s | game | GPU driver | compositor |
|---|---|---|---|---|---|---|---|---|
| Menu, untouched | 0.0 | 7% | 1% | 2% | 0.0 | 8% | 0% | 1% |
| New board, untouched (the swipe hint pulses until the first move) | 30.0 | 52% | 18% | 26% | 30.0 | 63% | 9% | 11% |
| Playing, 2 moves a second | 102.6 | 86% | 16% | 48% | 54.8 | 75% | 10% | 18% |
| Playing, 5 moves a second | 118.9 | 103% | 19% | 53% | 60.1 | 85% | 10% | 19% |
| FPS counter on, no cap | 120.2 | 100% | 23% | 49% | 60.2 | 87% | 10% | 17% |
| FPS counter on, cap 120 | 120.0 | 97% | 22% | 51% | 60.2 | 89% | 10% | 17% |
| FPS counter on, cap 90 | 90.0 | 98% | 21% | 46% | 60.2 | 89% | 10% | 17% |
| FPS counter on, cap 60 | 60.0 | 77% | 22% | 36% | 60.0 | 88% | 10% | 17% |
| FPS counter on, cap 30 | 30.0 | 50% | 17% | 26% | 30.0 | 62% | 9% | 11% |
| FPS counter on, medium quality (1080p) | 120.2 | 102% | 23% | 52% | 60.2 | 89% | 11% | 17% |
| FPS counter on, low quality (720p) | 120.2 | 102% | 23% | 51% | 60.2 | 89% | 10% | 16% |
| 10 minutes of play, a move every 1.8 s | 35.6 | 41% | 6% | 20% | 18.6 | 34% | 4% | 7% |
| 10 minutes on a board left mid-game | 0.2 | 8% | 0% | 0% | 0.2 | 10% | 0% | 0% |

- A still screen draws nothing. Two seconds after the last touch, with nothing animating, the game also withdraws its refresh rate request, so the Infinix panel drops from 120 to 60 Hz (checked in `dumpsys SurfaceFlinger`; Settings and the launcher idle at 60 Hz too), and its main loop wakes every 33 ms instead of 8 ms. Before this change the untouched menu cost 15% of a core on the Infinix and the display stayed at 120 Hz.
- What a still menu still costs is mostly the music: on the Infinix about two thirds of it is the `AudioTrack` mixer thread, the rest the engine's main thread.
- A new board keeps the swipe hint breathing until the first move. While only such slow loops run (the breathing arrows, the idle bulb) the game draws at 30 fps and lets the display rest: on the Redmi that is 63% of a core instead of 89% at 60 fps, and on the Infinix about half of what drawing at 120 fps costs. A board left mid-game is still and costs about as much as the menu.
- Graphics quality hardly changes CPU time: the board is simple 2D, and the phones expose no GPU load. The frame cap does: at 60 the Infinix spends 22% less game CPU and 28% less compositor time than without a cap.
- Memory after playing: 271 MB (Infinix) and 243 MB (Redmi) PSS, of which about 107 MB is graphics memory and 57 MB the engine's code.

## Battery

For the two ten-minute phases Android was told the phone is unplugged (`dumpsys battery unplug`) and its per-app estimate was read from `dumpsys batterystats` (a model built from the phone's power profile, not a meter).

| 10 minutes | Redmi: whole estimate | screen | game CPU | Infinix |
|---|---|---|---|---|
| Playing | 15.1 mAh | 13.1 mAh | 1.94 mAh | no per-app estimate; game CPU 41% of a core |
| Board left mid-game | 13.5 mAh | 13.1 mAh | 0.34 mAh | no per-app estimate; game CPU 8% of a core |

- On the Redmi an hour of play costs about 90 mAh at minimum brightness, 1.8% of its 5000 mAh battery; the screen takes 87% of it, the game's own CPU about 12 mAh. Brighter screens raise the screen's share.
- The Infinix firmware's power profile gives the game an estimate near zero, so only its CPU time is reported.
- Temperatures: the phones' thermal service reported the same values before and after each ten-minute phase, so no heating could be measured.

## Hints

Time from asking to the answer, on positions from seeded games of each board size (8 per size, 3 for Smart; the 3×3 game is short, so fewer there). Median, with the maximum in brackets, and the search depth reached. The bench wakes the main loop before each hint, as the tap that asks for one does.

| Board | Level | Infinix | depth | Redmi | depth |
|---|---|---|---|---|---|
| 3×3 | Simple | 8 ms (13 ms) | 1 | 8 ms (10 ms) | 1 |
| 3×3 | Medium | 841 ms (876 ms) | 10–13 | 709 ms (769 ms) | 8–10 |
| 3×3 | Smart | 12.5 s (14.1 s) | 16–22 | 13.1 s (13.7 s) | 18–23 |
| 4×4 | Simple | 6 ms (10 ms) | 1 | 6 ms (7 ms) | 1 |
| 4×4 | Medium | 504 ms (733 ms) | 5–7 | 677 ms (885 ms) | 4–6 |
| 4×4 | Smart | 7.6 s (13.4 s) | 6–8 | 6.5 s (13.0 s) | 6–12 |
| 5×5 | Simple | 5 ms (9 ms) | 1 | 6 ms (9 ms) | 1 |
| 5×5 | Medium | 321 ms (493 ms) | 4–5 | 118 ms (262 ms) | 3–4 |
| 5×5 | Smart | 9.5 s (15.0 s) | 5–6 | 11.4 s (13.9 s) | 5 |
| 6×6 | Simple | 6 ms (10 ms) | 1 | 6 ms (9 ms) | 1 |
| 6×6 | Medium | 197 ms (453 ms) | 3–4 | 327 ms (343 ms) | 3 |
| 6×6 | Smart | 4.2 s (4.5 s) | 4 | 4.4 s (5.7 s) | 4 |

- **Simple** searches one level on one thread. **Medium** has up to a second on up to four threads, always leaving two cores to the game, and stops early when the next level would not fit. **Smart** has 15 s on every core but one (7 threads here); it stops when its answer has held for three rounds from depth 4 on with a lead of at least 1%, or when the next level cannot finish in time, and when chance has cut every line short of the depth limit it lowers that cut-off tenfold and searches again.
- Speed against 1.3.0's GDScript solver, same positions, same search, one desktop core, medians over 10 positions: depth 3 took 17 ms instead of 0.71 s, depth 4 0.12 s instead of 5.4 s, depth 5 0.50 s instead of 19 s, so about 40 times faster.
- Strength (desktop, `native/core/src/bin/autoplay.rs`, 4×4): at its earlier budget of 0.35 s on two threads Medium reached 16384 in all 3 games, mean score 350 567; with a full second it looks further still. Simple reached 2048 in 12 of 20 games, mean 29 242.

## Switching theme, language or text size

Measured on the Infinix with a timing build. A switch used to restyle and lay out all five screens, build a new Theme and read the frame back from the GPU for the crossfade: about 65 ms each, so quick taps queued up. Hidden screens now catch up when they are shown, the Theme is built once per palette and a switch during a running crossfade keeps the snapshot that is already fading: about 50 ms for the first switch (half of it the frame readback) and 25 ms for each quick one after it.

## Size and start-up

| arm64 APK | download | installed | cold start, Infinix | cold start, Redmi |
|---|---|---|---|---|
| native libraries compressed (shipped) | 29.0 MB | 99.3 MB (APK + unpacked libraries) | 378–425 ms | 544–882 ms |
| native libraries stored uncompressed | 75.4 MB | 75.4 MB | 364–445 ms | 598–821 ms |

Cold start is `am start -W -S` (until Android shows the first frame), six runs each. Uncompressed libraries would save 24 MB on the phone but cost 46 MB more to download, with no difference in start-up, so the libraries stay compressed. The universal APK for RuStore is 56.8 MB.

## Reproducing

```bash
python tools/export_android.py bench-in-place      # or 'bench' for a separate package
BENCH_RESTORE_APK=build/2048-Merge-vX.Y.Z-arm64-v8a.apk \
  python tools/device_bench.py <serial> build/2048-Merge-vX.Y.Z-bench-in-place.apk out.json com.mahiron.merge2048
```

Do not run a Godot export while a bench runs: Godot stops the adb server when it exits, which ends the log the script follows. BENCH_RESTORE_APK puts the real build back afterwards, also when a run fails; the bench build never touches the player's save.
