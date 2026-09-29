# Changelog

All notable changes to 2048 Merge. Versions follow [Semantic Versioning](https://semver.org/).

## [1.2.3] - 2026-09-29

### 🇬🇧 English

- **Frame rate limit** (new setting): 30, 60, 90, 120 or ∞ (no limit). Only caps your screen can show evenly are offered — 90 appears only on screens with a 90 or 180 Hz mode, 120 only with a 120 or 240 Hz mode, so a 60/120/144 Hz phone gets 30, 60, 120 and ∞. The cap applies instantly; where the phone allows it, the display also drops to a matching refresh rate, which saves more battery (some skins, such as Infinix XOS, keep every app at the system rate).
- **Refresh rate readout fixed:** the game now also reads the refresh rate chosen in the phone's display settings, which caps every app. The FPS counter shows the ceiling that really applies and, when it is lower, the panel's own maximum — e.g. "max 120, panel 144" — plus the cap if one is set. The game rechecks it whenever it returns to the foreground.
- **Bundled font:** Roboto now ships with the game. Some phones (e.g. Infinix with XOS) substituted a serif face for bold system text — titles, scores, the FPS counter.
- **Huge tiles fixed:** tile values are now 64-bit. Merging two 1 073 741 824 tiles produced a negative number, and that game could no longer be loaded. Every tile a 6×6 board can reach (up to 2³⁷) now works.
- **Dialogs:** the "New game?" and game-over cards could stay shrunken and off-centre when the phone was busy while they opened; they now re-fit whenever their size settles. A very long final score shrinks to fit the card.
- **Smoother first game over:** the game-over card is drawn once, invisibly, during launch, so its first appearance no longer stalls for a few frames.
- **Game over vibration:** two soft pulses, the second one and a half times longer than the first.
- **Scrolling the settings no longer changes them:** a swipe that started on a selector (theme, language, undo, FPS limit) switched it, and a vertical swipe that started on a volume slider moved the volume. Selectors now react to a tap, sliders to a tap or a sideways drag.
- **Security and supply chain:** new [SECURITY.md](https://github.com/Mahiron-hq/2048/blob/main/SECURITY.md) with private reporting through GitHub. The release workflow pins every action to a commit SHA, uses least-privilege tokens, verifies Godot downloads against their SHA-512 sums and the APKs against the release certificate, and each release now ships `SHA256SUMS.txt` and a signed build provenance attestation.
- **Music license:** the soundtrack "2048 Quiet Tiles" is now explicitly licensed under CC BY-NC-ND 4.0 ([LICENSE-MUSIC](https://github.com/Mahiron-hq/2048/blob/main/LICENSE-MUSIC)); the code stays under Apache 2.0.
- Stress-tested on a 144 Hz Android 16 phone: 6 000 random input events, hundreds of moves with undo, rotations mid-animation, background/foreground cycling, kills right after moves, low-memory signals and screen size/density changes — no crashes, no memory growth, saves intact.

### 🇷🇺 Русский

- **Ограничение FPS** (новая настройка): 30, 60, 90, 120 или ∞ (без ограничений). Предлагаются только те значения, которые экран показывает ровно: 90 — только если у экрана есть режим 90 или 180 Гц, 120 — если есть 120 или 240 Гц. На телефоне с режимами 60/120/144 Гц будут 30, 60, 120 и ∞. Ограничение применяется сразу; если телефон позволяет, экран ещё и переключается на подходящую частоту, что экономит больше батареи (некоторые оболочки, например Infinix XOS, держат все приложения на системной частоте).
- **Исправлен показ частоты экрана:** игра теперь учитывает и частоту, выбранную в настройках экрана телефона, — выше неё не работает ни одно приложение. Счётчик FPS показывает реально доступный потолок, а если он ниже возможностей экрана, то и максимум самой панели, например «max 120, panel 144», и включённое ограничение. Игра перепроверяет это при каждом возвращении на экран.
- **Встроенный шрифт:** Roboto теперь входит в игру. Некоторые телефоны (например, Infinix с XOS) подставляли вместо жирного системного шрифта шрифт с засечками — в заголовках, счёте, счётчике FPS.
- **Исправлены огромные плитки:** значения плиток теперь 64-битные. Слияние двух плиток 1 073 741 824 давало отрицательное число, и такую партию потом нельзя было загрузить. Теперь работают все плитки, достижимые на поле 6×6 (до 2³⁷).
- **Диалоги:** окна «Начать новую игру?» и «Ходов больше нет» могли остаться уменьшенными и смещёнными, если телефон был занят в момент открытия; теперь они подстраиваются, как только их размер устоялся. Очень длинный итоговый счёт уменьшается, чтобы поместиться в карточку.
- **Плавный первый проигрыш:** окно проигрыша один раз невидимо отрисовывается при запуске, поэтому его первое появление больше не подтормаживает.
- **Вибрация при проигрыше:** два мягких толчка, второй в полтора раза длиннее первого.
- **Прокрутка настроек больше их не меняет:** свайп, начатый на переключателе (тема, язык, отмена ходов, ограничение FPS), переключал его, а вертикальный свайп по ползунку громкости сдвигал громкость. Теперь переключатели реагируют на касание, а ползунки — на касание или движение вбок.
- **Безопасность и цепочка поставки:** новый [SECURITY.md](https://github.com/Mahiron-hq/2048/blob/main/SECURITY.md) с приватными сообщениями об уязвимостях через GitHub. Сборка релизов закрепляет все actions на SHA коммитов, использует токены с минимальными правами, сверяет загрузки Godot с суммами SHA-512 и подпись APK с сертификатом релизов, а к каждому релизу теперь прикладываются `SHA256SUMS.txt` и подписанная аттестация происхождения сборки.
- **Лицензия на музыку:** саундтрек «2048 Quiet Tiles» теперь явно распространяется по лицензии CC BY-NC-ND 4.0 ([LICENSE-MUSIC](https://github.com/Mahiron-hq/2048/blob/main/LICENSE-MUSIC)); код остаётся под Apache 2.0.
- Стресс-тест на телефоне с экраном 144 Гц и Android 16: 6 000 случайных действий, сотни ходов с отменами, повороты посреди анимации, частое сворачивание и разворачивание, закрытие процесса сразу после хода, сигналы нехватки памяти, смена размера и плотности экрана — без падений, без роста памяти, сохранения целы.

## [1.2.2] - 2026-09-28

### 🇬🇧 English

- **Haptics that grow with the tiles:** merging 2s is silent, merging 4s gives the lightest tap, and every step up to 65536 is a little stronger; bigger merges stay at the maximum. Both the strength and the length of the buzz grow, so the steps are felt on any vibration motor. A lost game ends with a soft, wavy one-second vibration.
- **FPS counter** no longer shows the vibration diagnostics line.
- **Theme switch fixed** (present since 1.0.0): the crossfade snapshot was sized in physical pixels, so on high-density screens the interface briefly blew up past the screen edges, and rapid switching left trails. It now matches the screen and only one crossfade runs at a time.
- **Landscape game layout:** the board sits in the middle; the 2048 badge and menu button are in the top-left corner, the score is against the board's left edge and the best score against its right edge, and undo/new game are in the bottom-left corner. Narrower screens (16:9, 4:3 tablets) stack these controls instead of shrinking the board. The FPS counter moves to the bottom-right corner in landscape.

### 🇷🇺 Русский

- **Вибрация растёт вместе с плитками:** слияние двоек без вибрации, четвёрок — самый лёгкий толчок, и каждая ступень до 65536 немного сильнее; дальше максимальная сила. Растут и сила, и длительность толчка, поэтому ступени ощущаются на любом вибромоторе. Проигрыш завершается мягкой волнообразной вибрацией на секунду.
- **Счётчик FPS** больше не показывает строку диагностики вибрации.
- **Исправлена смена темы** (баг с 1.0.0): снимок экрана для плавного перехода брался в физических пикселях, поэтому на экранах с высокой плотностью интерфейс на мгновение раздувался за края экрана, а при частых переключениях оставались шлейфы. Теперь снимок точно по размеру экрана, и одновременно идёт только один переход.
- **Игра в горизонтальном положении:** поле по центру; плашка 2048 и кнопка меню в левом верхнем углу, счёт прижат к левому краю поля, рекорд — к правому, «Отменить»/«Заново» в левом нижнем углу. На более узких экранах (16:9, планшеты 4:3) элементы складываются в столбик, а поле не уменьшается. Счётчик FPS в горизонтальном положении переехал в правый нижний угол.

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
- **Settings reorganized** into "App settings" and "Game settings".
- **Automated builds:** every push and pull request runs the full test suite on GitHub Actions; tagging a version builds signed APKs and attaches them to the release.

### 🇷🇺 Русский

- **Размер поля:** 3×3, 4×4, 5×5 или 6×6. Кнопка слева от «Новая игра» открывает небольшое меню выбора; по умолчанию 4×4. Рекорды хранятся отдельно для каждого размера.
- **Глубина отмены:** новый раздел «Настройки игры» — от 0 до 5 отмен хода (по умолчанию 1). Отмену можно выключить; дальше начала партии она не откатывает. На кнопке видно, сколько отмен осталось.
- **Статистика:** сыграно партий, средний счёт, лучшая плитка, рекорд, всего ходов и время в игре — в целом или по размеру поля.
- **Любой экран и ориентация:** горизонтальные раскладки всех экранов и корректное масштабирование на планшетах; при повороте элементы сохраняют физический размер.
- **Подсказка свайпа:** в начале каждой партии поверх поля полупрозрачная подсказка со стрелками, исчезает после первого хода.
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
