# Design system

The whole interface is drawn from one set of tokens in [`scripts/ui/design.gd`](../scripts/ui/design.gd) and one set of color roles in [`scripts/ui/palette.gd`](../scripts/ui/palette.gd). Screens and widgets never use raw sizes or colors. Units are canvas units on a 720-unit short side, so 88 units are about 48 dp on a phone.

## Tokens

| Group | Values | Used for |
|---|---|---|
| Spacing (4-unit steps) | 4 · 8 · 12 · 16 · 24 · 32 · 48 · 64 | gaps, padding; screen side margin 32 |
| Type (Manrope) | display 96 · title 48 · headline 36 · body 30 · callout 26 · caption 22 | final score · screen titles · dialog titles and big values · labels and buttons · secondary lines · captions over numbers |
| Weights | 500 · 600 · 700 · 800 | text · labels · captions and buttons · numbers and titles |
| Radii | pill (controls) · 28 (cards, panels, popovers) · 36 (dialogs, menu card) · tile 14% of its side | nested shapes keep outer = inner + inset, so corners run parallel (board = tile radius + gap) |
| Control sizes | 104 · 88 · 72; rows 104; icons 36 / 28; switch 88×52 | 88 is the standard touch target |
| Depth | flat · raised (soft shadow 0/4/12) · dialog (0/16/40) | in the dark theme raised surfaces get a 2-unit hairline instead, since shadows do not show |
| Motion | 0.08 · 0.14 · 0.2 · 0.32 s, cubic ease-out; press scale 0.96 | tiles: slide 0.1, merge 0.16 (swell to 1.12), spawn 0.18 |

Digits are tabular wherever numbers change (scores, statistics), so counters never jitter. A tile's number size depends on its digit count and always leaves at least 10% margin on each side.

## Color roles

Both themes fill the same roles and differ only in their values. The dark theme is a separate palette, not an inversion: warm graphite instead of black, softer accent, lower saturation.

| Role | Light | Dark | Used for |
|---|---|---|---|
| `bg` / `bg_deep` | `#f5efe7` / `#efe7dc` | `#1b1816` / `#161412` | screen background, fading slightly downward |
| `surface` | `#fffcf8` | `#242120` | cards, score panels, list groups |
| `surface_raised` | `#ffffff` | `#2e2a28` | buttons, dialogs, popovers |
| `board` / `cell` | `#e3d9cc` / `#d8ccbe` | `#262220` / `#2f2a27` | the board and its empty cells, kept quiet |
| `track` | `#e6ddd2` | `#3b3532` | switch, slider and selector tracks |
| `outline` | `#e4dace` | `#38322f` | dividers and hairlines |
| `text` | `#2c241e` | `#f1ebe5` | primary text (13:1 and more on the background) |
| `text_secondary` | `#76685c` | `#aba096` | captions, hints (at least 4.5:1) |
| `text_tertiary` | `#b2a598` | `#70675f` | disabled labels |
| `accent` / `on_accent` | `#be512d` / `#ffffff` | `#e2794f` / `#1d1410` | the one main action per screen, switches, the record badge (labels at least 4.5:1) |
| `accent_soft` | accent at 11% | accent at 16% | selected rows, the record badge, the lit hint button |
| `scrim` | warm black at 42% | black at 62% | backdrop behind dialogs |

## Tiles

Three families, each getting darker as the value grows, so a bigger tile always reads heavier and each family change marks a milestone tier:

| Family | Values | Light theme |
|---|---|---|
| Warm climb | 2 · 4 · 8 · 16 · 32 · 64 | `#f6efe1` `#f3e0c4` `#f5c093` `#f7a171` `#ed835e` `#ca5747` |
| Golden tier | 128 · 256 · 512 · 1024 · 2048 | `#eccf75` `#ecba4f` `#eba536` `#e38b28` `#da7224` |
| Deep tier | 4096 · 8192 · 16384 · 32768 · 65536 · 131072+ | `#9e4048` `#84395a` `#663d70` `#4a467d` `#2d557d` `#216573` |

The dark theme keeps the hues with slightly lower lightness and chroma, and turns 2 and 4 into warm taupes that do not glare on a dark board. Numbers use a dark ink (`#3a2c22`) or a light one (`#f8f3ec`), whichever contrasts more; every tile meets WCAG's 3:1 for large text in both themes, and most reach 4.5:1 (checked by `tests/run_tests.gd`). Tiles have a thin darker bottom edge instead of shadows; from 128 up a fine top highlight marks milestone tiles. Nothing glows.

## Layout

- The board is the visual center. In portrait the scores sit on top and the actions (menu, hint, undo, new game) at the bottom, under the thumb; when labels do not fit, the action bar steps down to tighter buttons, then labels only, then icons.
- Lists and dialogs keep a readable column (at most 720 and 600 units) on tablets and in landscape.
- Safe areas (cutouts, gesture bars) are respected on every screen; layouts are checked on six screen shapes in both themes by `tests/layout_shots.gd`.
