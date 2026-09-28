# Changelog

All notable changes to 2048 Merge. Versions follow [Semantic Versioning](https://semver.org/).

## [1.2.1] - 2026-09-28

### 🇬🇧 English

- **Vibration fixed for real:** buzzes are now sent with the "media" usage that Android intends for games. Android 12+ used to file them under touch or notification feedback, which many phones mute, so they were dropped. With "Show FPS" on, the overlay also shows which haptics path is active.
- **Board size picker:** always exactly four rows (it sometimes measured stale rows and grew to twice the size) and stays on screen in landscape.
- **Statistics:** an undone move no longer counts towards total moves.
- **Landscape game layout:** scores, undo/new, then the logo and menu are stacked in a slim column, and the board sits in the middle of the screen.
- **Swipe hint:** the veil now covers the whole board and the arrows keep pulsing until the first move.
- **Header and side column ignore swipes,** so checking the time or pulling down the notification shade never moves tiles.
- **Smoother long games:** saving runs on a background thread and is batched, so a slow storage write can no longer freeze the game for seconds; a move now costs about half as much on the main thread.
- **Louder music and finer volume:** the soundtrack's top level is ~14% louder, and music and effects each have 7 volume steps (saved levels carry over).

### 🇷🇺 Русский

- **Вибрация исправлена по-настоящему:** теперь она отправляется с назначением «медиа», которое Android предусматривает для игр. Android 12+ относил её к отклику на касания или уведомлениям, а их на многих телефонах отключают, поэтому вибрация глушилась. При включённом «Показывать FPS» строка также показывает, каким способом работает вибрация.
- **Выбор размера поля:** всегда ровно четыре строки (иногда меню учитывало старые строки и становилось вдвое больше) и не выходит за экран в горизонтальном положении.
- **Статистика:** отменённый ход больше не засчитывается в общее число ходов.
- **Игра в горизонтальном положении:** счёт, «Отменить»/«Заново», затем логотип и меню — в узкой колонке, а поле стоит по центру экрана.
- **Подсказка свайпа:** затемнение закрывает всё поле, стрелки пульсируют до первого хода.
- **Шапка и боковая колонка не реагируют на свайпы** — можно посмотреть время или опустить шторку уведомлений, не сдвигая плитки.
- **Плавность в долгих партиях:** сохранение идёт в фоновом потоке и пакетами, поэтому медленная запись на диск больше не может «подвесить» игру на секунды; ход стал примерно вдвое дешевле для основного потока.
- **Музыка громче, громкость точнее:** максимальная громкость саундтрека выше примерно на 14%, у музыки и звуков по 7 делений (сохранённые уровни переносятся).

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
