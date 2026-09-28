# Changelog

All notable changes to 2048 Merge. Versions follow [Semantic Versioning](https://semver.org/).

## [1.2.0] - 2026-09-28

### 🇬🇧 English

- **Board sizes:** play on 3×3, 4×4, 5×5 or 6×6. A size button next to "New game" in the menu opens a small picker; 4×4 stays the default. Records are kept per size.
- **Undo depth:** new "Game settings" section with 0–5 undo steps (default 1). Undo can be turned off entirely, and it never goes past the start of the game. The undo button shows how many steps are left.
- **Statistics:** games played, average score, best tile, best score, total moves and time played — overall or per board size.
- **Any screen, any orientation:** landscape layouts for every screen and proper scaling on tablets; controls keep the same physical size when the device turns.
- **Swipe hint:** each new game shows a translucent four-arrow hint over the board that fades away with the first move.
- **Vibration fixed:** haptics now use the system's tuned haptic effects (Android 10+) or pulses long enough to feel. Previously the pulses were too short and weak to be noticed.
- **Settings reorganized** into "App settings" and "Game settings".
- **Automated builds:** every push and pull request runs the full test suite on GitHub Actions; tagging a version builds signed APKs and attaches them to the release.

### 🇷🇺 Русский

- **Размер поля:** 3×3, 4×4, 5×5 или 6×6. Кнопка слева от «Новая игра» открывает небольшое меню выбора; по умолчанию 4×4. Рекорды хранятся отдельно для каждого размера.
- **Глубина отмены:** новый раздел «Настройки игры» — от 0 до 5 отмен хода (по умолчанию 1). Отмену можно выключить; дальше начала партии она не откатывает. На кнопке видно, сколько отмен осталось.
- **Статистика:** сыграно партий, средний счёт, лучшая плитка, рекорд, всего ходов и время в игре — в целом или по размеру поля.
- **Любой экран и ориентация:** горизонтальные раскладки всех экранов и корректное масштабирование на планшетах; при повороте элементы сохраняют физический размер.
- **Подсказка свайпа:** в начале каждой партии поверх поля полупрозрачная подсказка со стрелками, исчезает после первого хода.
- **Исправлена вибрация:** теперь используются системные тактильные эффекты (Android 10+) или импульсы достаточной длительности. Раньше импульсы были слишком короткими и слабыми, чтобы их почувствовать.
- **Настройки разделены** на «Настройки приложения» и «Настройки игры».
- **Автоматические сборки:** каждый push и pull request прогоняет все тесты на GitHub Actions; тег версии собирает подписанные APK и прикладывает их к релизу.

## [1.1.1] - 2026-09-27

- Volume sliders (5 steps) for music and sound effects.
- Cleaner music loop: the track stays bar-exact and its ringing tail overlaps the next bar instead of fading to silence.

## [1.1.0] - 2026-09-27

- Original soundtrack "2048 Quiet Tiles" with a sample-accurate loop and smooth fade in/out.
- Undo plays the move backwards (tiles glide home, merged tiles split) instead of rebuilding the board.

## [1.0.0] - 2026-09-26

- First release: 4×4 board, undo, milestones, light and dark themes, English and Russian, autosave, 90/120/144 Hz support.
