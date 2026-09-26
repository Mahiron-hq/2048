<div align="center">

<img src="assets/icons/icon.png" width="96" alt="2048 Merge icon">

# 2048 Merge

**Числовая головоломка со слияниями для Android: без рекламы, без интернета, без трекинга**
<br>
**Offline number-merging puzzle for Android: no ads, no network, no tracking**

[![Release](https://img.shields.io/github/v/release/Mahiron-hq/2048?style=flat-square&color=f06a4a)](https://github.com/Mahiron-hq/2048/releases/latest)
[![License](https://img.shields.io/badge/license-Apache%202.0-green?style=flat-square)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Android%208.0%2B-3DDC84?style=flat-square&logo=android&logoColor=white)](#)
[![Godot](https://img.shields.io/badge/Godot-4.7-478CBF?style=flat-square&logo=godotengine&logoColor=white)](https://godotengine.org/)

### [⬇️ Скачать / Download](https://github.com/Mahiron-hq/2048/releases/latest)

**[Русский](#-русский)** · **[English](#-english)**

<br>

<img src="docs/preview.gif" width="270" alt="Gameplay preview">

<br><br>

<img src="docs/screenshots/menu_dark.png" width="200" alt="Menu"> <img src="docs/screenshots/game_tiles_dark.png" width="200" alt="Board"> <img src="docs/screenshots/game_over_dark.png" width="200" alt="Game over"> <img src="docs/screenshots/settings_light.png" width="200" alt="Settings">

</div>

---

## 🇷🇺 Русский

2048 Merge — классическая головоломка на сетке 4×4. Свайп сдвигает все плитки в одну сторону, одинаковые числа при столкновении складываются в одно. Жёсткого финиша нет: игра продолжается после 2048, а на 128, 256, 512, 1024, 2048 и дальше вас ждёт праздничный баннер с конфетти, не прерывающий партию. Партия заканчивается, только когда поле заполнено и ходов не осталось.

Вся графика и звук создаются кодом во время работы. В пакете нет ни одной картинки интерфейса и ни одного аудиофайла, поэтому APK весит около 27 МБ, и почти всё это — сам движок.

### Возможности

| | |
|---|---|
| 🎯 **Честная механика 2048** | Одно слияние на плитку за ход, спавн 2 (90%) или 4 (10%). Логика покрыта тестами, включая рандомизированные проверки инвариантов |
| ↩️ **Отмена хода** | Один последний ход можно откатить кнопкой |
| 🎉 **Milestone-события** | 128 / 256 / 512 / 1024 / 2048 / … — баннер, конфетти, звук и вибрация. Срабатывают один раз за партию |
| 🌗 **Светлая и тёмная темы** | При первом запуске берётся системная тема. Переключение идёт с плавным кроссфейдом |
| 🌐 **Русский и английский** | Язык определяется по системе, его можно сменить в настройках |
| 💾 **Автосохранение** | Рекорд, настройки и текущая партия (вместе с шагом отмены) сохраняются после каждого хода и при сворачивании. Запись атомарная, так что «убийство» процесса не портит файл |
| 📱 **90 / 120 / 144 Гц** | Кадр не ограничен 60 FPS, игра сама просит у Android максимальную частоту экрана |
| 🔋 **Бережёт батарею** | В простое движок переходит в режим низкого потребления и ничего не перерисовывает |
| 🔊 **Синтезированный звук** | Щелчки, свайпы, слияния (тон растёт с номиналом), фанфары и фоновая эмбиент-музыка. Всё генерируется на лету |
| 🔒 **Никаких лишних прав** | Единственное разрешение — вибрация. Нет `INTERNET`, рекламы, аналитики и покупок |

### Установка

1. Откройте [последний релиз](https://github.com/Mahiron-hq/2048/releases/latest) и скачайте APK:
   - **`…-arm64-v8a.apk`** — для практически всех телефонов последних лет. Если не уверены, берите его.
   - **`…-armeabi-v7a.apk`** — для старых 32-битных устройств, на которых первый вариант не ставится.
2. Откройте файл на телефоне и разрешите установку из этого источника, если Android спросит.

Или через компьютер: `adb install -r 2048-Merge-v1.0.0-arm64-v8a.apk`

> Нужен Android 8.0 (API 26) или новее. Если у вас стоит тестовая сборка, подписанная другим ключом, сначала удалите её.

### Как играть

- **Свайп** в любую сторону сдвигает все плитки. Одинаковые числа сливаются, и их сумма добавляется к счёту.
- **Отменить** возвращает поле к состоянию до последнего хода.
- **Заново** начинает новую партию (с подтверждением, если текущая не закончена).
- Кнопка **«Назад»** на Android ведёт в меню, а из меню закрывает игру. Партия при этом сохраняется.
- В настройках: звук, музыка, вибрация, тема, язык и счётчик FPS с текущей частотой экрана.

### Сборка из исходников

Понадобятся **Godot 4.7.2** (обычный или .NET), шаблоны экспорта 4.7.2, **JDK 17** и **Android SDK** (platform 36, build-tools 36.1.0). Пути к SDK и JDK задаются в настройках редактора Godot.

```bash
git clone https://github.com/Mahiron-hq/2048.git
cd 2048

# Ключ подписи передаётся через окружение, в репозитории секретов нет
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/path/to/release.jks
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=alias
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=secret
export GRADLE_OPTS=-Dorg.gradle.daemon=false   # чтобы headless-экспорт завершался сам

godot --headless --path . --install-android-build-template --export-release "Android" build/2048-merge.apk
godot --headless --path . --export-release "Android armeabi-v7a" build/2048-merge-armv7.apk
```

Играть и отлаживать можно прямо на ПК: `godot --path .` (перетаскивание мышью = свайп, стрелки/WASD, `Z` — отмена, `Esc` — назад).

Тесты запускаются без окна:

```bash
godot --headless --path . --script res://tests/run_tests.gd   # правила, сериализация, сохранение, аудио
godot --headless --path . --script res://tests/ui_smoke.gd    # весь UI-сценарий через реальные касания
```

### Как это устроено

- **`scripts/core/board.gd`** — чистая логика поля без UI и без привязки ко времени кадра. Ход — дискретная операция, которая возвращает список сдвигов, слияний и спавна. У каждой плитки стабильный id, поэтому вид анимирует именно её.
- **`scripts/ui/board_view.gd`** — анимация хода: скольжение, «поп» слияния, появление новой плитки. Плитки берутся из пула, так что во время игры ноды не создаются. Новый свайп посреди анимации мгновенно доматывает предыдущую, и ввод не теряется.
- **`scripts/audio/sfx.gd`** — синтез всех звуков в PCM при запуске. Музыкальный луп рендерится в фоновом потоке и собран так, чтобы стык цикла был бесшовным.
- **`scripts/platform/display_rate.gd`** — через JNI вызывает `Surface.setFrameRate` на поверхности рендера (Android 11+), чтобы система не держала игру на 60 Гц.
- **`scripts/app.gd`** — роутинг экранов и переходы, тема и язык, режим низкого потребления, сохранение при паузе.
- Рендерер Compatibility (OpenGL ES 3) — максимальная совместимость с бюджетными устройствами.

### Ограничения

- **iOS.** Проект кроссплатформенный (safe area, вибрация, ProMotion 120 Гц включён), и пресет экспорта настроен. Но собрать `.ipa` можно только на macOS с Xcode и аккаунтом Apple Developer.
- Явный запрос высокой частоты работает на Android 11+. На Android 8–10 частоту выбирает система.
- Отдельной раскладки для планшетов нет: интерфейс центрируется колонкой телефонной ширины.

### Лицензия

Apache License 2.0 — см. [LICENSE](LICENSE).

---

## 🇬🇧 English

2048 Merge is the classic 4×4 sliding puzzle. A swipe moves every tile one way, and equal numbers merge into one when they collide. There is no hard finish: play goes on past 2048, and hitting 128, 256, 512, 1024, 2048 and beyond triggers a celebratory banner with confetti that never interrupts the game. It ends only when the board is full with no merges left.

All graphics and audio are generated by code at runtime. The package holds no UI images and no audio files, so the APK is about 27 MB, almost all of it the engine itself.

### Features

| | |
|---|---|
| 🎯 **Faithful 2048 rules** | One merge per tile per move, spawns 2 (90%) or 4 (10%). The logic is unit tested, including randomized invariant checks |
| ↩️ **Undo** | Roll back the last move with one tap |
| 🎉 **Milestones** | 128 / 256 / 512 / 1024 / 2048 / … bring a banner, confetti, a chime and a buzz, once per game |
| 🌗 **Light and dark themes** | Follows the system theme on first launch; switching crossfades smoothly |
| 🌐 **English & Russian** | Picked from the system language, switchable in settings |
| 💾 **Autosave** | Best score, settings and the game in progress (with its undo step) are saved after every move and when the app is backgrounded. Writes are atomic, so killing the process never corrupts the file |
| 📱 **90 / 120 / 144 Hz** | Frame rate isn't capped at 60; the game asks Android for the panel's highest refresh rate |
| 🔋 **Battery friendly** | When idle, the engine drops to low-processor mode and redraws nothing |
| 🔊 **Synthesized audio** | Clicks, swipes, merges (pitch rises with value), fanfares and an ambient music loop, all generated on the fly |
| 🔒 **No extra permissions** | The only permission is vibration. No `INTERNET`, ads, analytics or purchases |

### Install

1. Open the [latest release](https://github.com/Mahiron-hq/2048/releases/latest) and download an APK:
   - **`…-arm64-v8a.apk`** — for virtually every phone from recent years. If unsure, take this one.
   - **`…-armeabi-v7a.apk`** — for older 32-bit devices where the first one won't install.
2. Open the file on your phone and allow installs from that source if Android asks.

Or from a computer: `adb install -r 2048-Merge-v1.0.0-arm64-v8a.apk`

> Requires Android 8.0 (API 26) or newer. If a test build signed with a different key is installed, uninstall it first.

### How to play

- **Swipe** in any direction to move all tiles. Equal numbers merge, and the sum is added to your score.
- **Undo** restores the board as it was before the last move.
- **New** starts over (asks first if the current game isn't finished).
- Android **Back** goes to the menu, and from the menu closes the game. Your game is saved either way.
- Settings: sound, music, vibration, theme, language, and an FPS counter showing the current refresh rate.

### Build from source

You need **Godot 4.7.2** (standard or .NET), the 4.7.2 export templates, **JDK 17** and the **Android SDK** (platform 36, build-tools 36.1.0). Point Godot's editor settings at the SDK and JDK.

```bash
git clone https://github.com/Mahiron-hq/2048.git
cd 2048

# The signing key comes from the environment; the repo holds no secrets
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/path/to/release.jks
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=alias
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=secret
export GRADLE_OPTS=-Dorg.gradle.daemon=false   # lets headless exports exit on their own

godot --headless --path . --install-android-build-template --export-release "Android" build/2048-merge.apk
godot --headless --path . --export-release "Android armeabi-v7a" build/2048-merge-armv7.apk
```

You can play and debug on a PC with `godot --path .` (mouse drag = swipe, arrows/WASD, `Z` to undo, `Esc` for back).

Tests run headless:

```bash
godot --headless --path . --script res://tests/run_tests.gd   # rules, serialization, persistence, audio
godot --headless --path . --script res://tests/ui_smoke.gd    # the whole UI flow through real touch events
```

### How it works

- **`scripts/core/board.gd`** — pure board logic with no UI and no frame-time dependency. A move is a discrete operation that reports slides, merges and the spawn. Tiles keep stable ids, so the view animates the right one.
- **`scripts/ui/board_view.gd`** — move animation: slide, merge pop, spawn. Tiles are pooled, so no nodes are created during play. A swipe that lands mid-animation fast-forwards the previous one, so input is never dropped.
- **`scripts/audio/sfx.gd`** — synthesizes every sound to PCM at startup. The music loop renders on a worker thread and is built so the loop seam is seamless.
- **`scripts/platform/display_rate.gd`** — calls `Surface.setFrameRate` on the render surface via JNI (Android 11+) so the OS doesn't hold the game at 60 Hz.
- **`scripts/app.gd`** — screen routing and transitions, theme and language, low-processor mode, saving on pause.
- The Compatibility renderer (OpenGL ES 3) keeps it running on budget devices.

### Limitations

- **iOS.** The project is cross-platform (safe area, haptics, ProMotion 120 Hz enabled) and the export preset is configured, but an `.ipa` can only be built on macOS with Xcode and an Apple Developer account.
- The explicit high-refresh request works on Android 11+. On Android 8–10 the OS picks the rate.
- There is no dedicated tablet layout; the UI is a centered, phone-width column.

### License

Apache License 2.0 — see [LICENSE](LICENSE).

---

<div align="center">
<sub>Copyright © 2026 Lev Burmistrov (Mahiron-hq)</sub>
</div>
