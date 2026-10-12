# Performance and battery

Measured on 2026-10-12 with version 1.3.1 on two phones:

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
| Menu, untouched | 0.0 | 8% | 0% | 2% | 0.0 | 9% | 0% | 1% |
| Board, untouched (the idle hint pulses once) | 24.3 | 29% | 6% | 16% | 12.3 | 25% | 3% | 5% |
| Playing, 2 moves a second | 107.3 | 88% | 17% | 50% | 55.0 | 75% | 10% | 18% |
| Playing, 5 moves a second | 120.0 | 102% | 19% | 52% | 60.2 | 83% | 11% | 19% |
| FPS counter on, no cap | 120.2 | 83% | 19% | 59% | 60.2 | 73% | 12% | 19% |
| FPS counter on, cap 120 | 120.0 | 83% | 19% | 60% | 60.2 | 73% | 12% | 19% |
| FPS counter on, cap 90 | 90.0 | 71% | 16% | 53% | 60.2 | 73% | 12% | 19% |
| FPS counter on, cap 60 | 60.0 | 52% | 12% | 41% | 60.0 | 74% | 12% | 19% |
| FPS counter on, cap 30 | 30.0 | 42% | 9% | 26% | 30.0 | 50% | 10% | 12% |
| FPS counter on, medium quality (1080p) | 120.2 | 83% | 18% | 60% | 60.2 | 74% | 12% | 19% |
| FPS counter on, low quality (720p) | 120.2 | 83% | 18% | 56% | 60.2 | 74% | 11% | 18% |
| 10 minutes of play, a move every 1.8 s | 36.4 | 42% | 6% | 20% | 18.6 | 34% | 4% | 7% |
| 10 minutes on an untouched board | 0.8 | 9% | 0% | 1% | 0.4 | 10% | 0% | 0% |

- A still screen draws nothing. Two seconds after the last touch, with nothing animating, the game also withdraws its refresh rate request, so the Infinix panel drops from 120 to 60 Hz (checked in `dumpsys SurfaceFlinger`; Settings and the launcher idle at 60 Hz too), and its main loop wakes every 33 ms instead of 8 ms. Before this change the untouched menu cost 15% of a core on the Infinix and the display stayed at 120 Hz.
- What a still menu still costs is mostly the music: on the Infinix, 6 of its 9% are the `AudioTrack` mixer thread and 3% the engine's main thread.
- The untouched board shows the idle hint once in 20 s (the bulb pulses for about four seconds), hence its frames.
- Graphics quality hardly changes CPU time: the board is simple 2D, and the phones expose no GPU load. The frame cap does: at 60 the Infinix spends 37% less game CPU and 31% less compositor time than without a cap.
- Memory after playing: 274 MB (Infinix) and 272 MB (Redmi) PSS, of which about 107 MB is graphics memory and 57 MB the engine's code.

## Battery

For the two ten-minute phases Android was told the phone is unplugged (`dumpsys battery unplug`) and its per-app estimate was read from `dumpsys batterystats` (a model built from the phone's power profile, not a meter).

| 10 minutes | Redmi: whole estimate | screen | game CPU | Infinix |
|---|---|---|---|---|
| Playing | 15.1 mAh | 13.1 mAh | 1.95 mAh | no per-app estimate; game CPU 42% of a core |
| Untouched board | 13.5 mAh | 13.1 mAh | 0.37 mAh | no per-app estimate; game CPU 9% of a core |

- On the Redmi an hour of play costs about 90 mAh at minimum brightness, 1.8% of its 5000 mAh battery; the screen takes 87% of it, the game's own CPU about 12 mAh. Brighter screens raise the screen's share.
- The Infinix firmware's power profile gives the game an estimate near zero, so only its CPU time is reported.
- Temperatures: the phones' thermal service reported the same values before and after each ten-minute phase, so no heating could be measured.

## Hints

Time from asking to the answer, on positions from seeded games of each board size (8 per size, 3 for Smart; the 3×3 game is short, so fewer there). Median, with the maximum in brackets, and the search depth reached. These come from a run of the same engine just before the still-screen pacing was added; the bench now wakes the loop before each hint, as the tap that asks for one does.

| Board | Level | Infinix | depth | Redmi | depth |
|---|---|---|---|---|---|
| 3×3 | Simple | 8 ms (12 ms) | 1 | 8 ms (12 ms) | 1 |
| 3×3 | Medium | 239 ms (265 ms) | 8–11 | 244 ms (338 ms) | 6–9 |
| 3×3 | Smart | 82 ms (12.1 s) | 4–17 | 10.8 s (12.8 s) | 4–21 |
| 4×4 | Simple | 6 ms (9 ms) | 1 | 6 ms (9 ms) | 1 |
| 4×4 | Medium | 165 ms (301 ms) | 4–8 | 78 ms (166 ms) | 3–4 |
| 4×4 | Smart | 6.8 s (8.2 s) | 4–7 | 8.2 s (12.5 s) | 7–11 |
| 5×5 | Simple | 6 ms (9 ms) | 1 | 6 ms (9 ms) | 1 |
| 5×5 | Medium | 256 ms (358 ms) | 3–4 | 142 ms (238 ms) | 3 |
| 5×5 | Smart | 4.3 s (10.5 s) | 5 | 15.0 s (15.0 s) | 5–6 |
| 6×6 | Simple | 6 ms (9 ms) | 1 | 6 ms (9 ms) | 1 |
| 6×6 | Medium | 200 ms (246 ms) | 3 | 38 ms (294 ms) | 2–3 |
| 6×6 | Smart | 4.2 s (5.1 s) | 4 | 4.4 s (5.6 s) | 4 |

- **Simple** searches one level on one thread. **Medium** has 0.35 s on two threads and stops early when the next level would not fit. **Smart** has 15 s on every core but one (7 threads here); it stops when its answer has held for three rounds from depth 4 on with a lead of at least 1%, or when the next level cannot finish in time, and when chance has cut every line short of the depth limit it lowers that cut-off tenfold and searches again.
- Speed against 1.3.0's GDScript solver, same positions, same search, one desktop core, medians over 10 positions: depth 3 took 17 ms instead of 0.71 s, depth 4 0.12 s instead of 5.4 s, depth 5 0.50 s instead of 19 s, so about 40 times faster.
- Strength (desktop, `native/core/src/bin/autoplay.rs`, 4×4): Medium reached 16384 in all 3 games, mean score 350 567; Simple reached 2048 in 12 of 20 games, mean 29 242.

## Size and start-up

| arm64 APK | download | installed | cold start, Infinix | cold start, Redmi |
|---|---|---|---|---|
| native libraries compressed (shipped) | 29.0 MB | 99.3 MB (APK + unpacked libraries) | 378–425 ms | 544–882 ms |
| native libraries stored uncompressed | 75.4 MB | 75.4 MB | 364–445 ms | 598–821 ms |

Cold start is `am start -W -S` (until Android shows the first frame), six runs each. Uncompressed libraries would save 24 MB on the phone but cost 46 MB more to download, with no difference in start-up, so the libraries stay compressed. The universal APK for RuStore is 56.7 MB.

## Reproducing

```bash
python tools/export_android.py bench-in-place      # or 'bench' for a separate package
python tools/device_bench.py <serial> build/2048-Merge-vX.Y.Z-bench-in-place.apk out.json com.mahiron.merge2048
```

Do not run a Godot export while a bench runs: Godot stops the adb server when it exits, which ends the log the script follows. Reinstall the real build afterwards; the bench build never touches the player's save.
