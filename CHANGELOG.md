# Changelog

All notable changes to 2048 Merge. Versions follow [Semantic Versioning](https://semver.org/).

## [1.3.0] - 2026-10-02

### 🇬🇧 English

- **A new look on one design system.** Every size, gap, radius, color and animation now comes from one set of tokens: a 4-unit spacing grid, six text sizes, pill-shaped buttons and containers with parallel corners. Menu, game, settings, statistics, dialogs and pop-ups all speak the same language.
- **Manrope font** with equal-width digits, so the score no longer jumps while it counts up.
- **Calmer, richer tiles.** Three color families, warm 2–64, golden 128-2048 and deep 4096+, get heavier as the numbers grow, while neighbouring values stay easy to tell apart. Every number has at least 3:1 contrast with its tile in both themes. Instead of glows, a thin edge gives depth, with a light highlight from 128 up.
- **Game buttons under your thumb:** the score on top, the board in the middle, menu, hint, undo and new game at the bottom.
- **Auto theme:** follows the phone's light or dark mode, even while you play. Light and dark are new palettes on shared color roles: a warm "paper" light theme and a soft graphite dark one.
- **Graphics quality:** low (720p), medium (1080p) or high (up to 2K) in Settings. The picture renders at that resolution and never above the screen's own; the current resolution is shown next to the choice.
- **One line-icon set,** dialogs dim the screen beneath them, and a new app icon in the new palette.
- **Releases include the Google Play bundle (AAB)** with checksums and an attestation, like the APKs; any Godot export error now stops the release build.
- **Repository:** the full Apache 2.0 license text and a NOTICE file; credit to Gabriele Cirulli, the author of the original 2048; the lossless music master moved to a [release](https://github.com/Mahiron-hq/2048/releases/tag/soundtrack).
- Tested on two phones, Infinix Note 50 Pro (Android 16, XOS) and Xiaomi Redmi Note 10S (Android 13, MIUI): every screen in both themes and orientations, the quality levels, the Auto theme following the system, and a random-input stress run.

### 🇷🇺 Русский

- **Новый облик на единой дизайн-системе.** Все размеры, отступы, скругления, цвета и анимации теперь берутся из одного набора токенов: сетка отступов с шагом 4, шесть размеров текста, кнопки-«таблетки» и контейнеры с параллельными скруглениями. Меню, игра, настройки, статистика, диалоги и всплывающие окна говорят на одном языке.
- **Шрифт Manrope** с цифрами одинаковой ширины - счёт больше не «прыгает», пока растёт.
- **Спокойнее и богаче плитки.** Три цветовых семейства - тёплое 2–64, золотое 128-2048, глубокое 4096+ - «тяжелеют» с ростом числа, а соседние значения легко различить. Контраст каждого числа с плиткой не ниже 3:1 в обеих темах. Вместо свечений - тонкий край для объёма и лёгкий блик начиная со 128.
- **Кнопки игры под большим пальцем:** счёт сверху, поле в центре, меню, подсказка, отмена и новая игра внизу.
- **Тема «Авто»:** следует за светлой или тёмной темой телефона, даже во время игры. Светлая и тёмная - новые палитры на общих цветовых ролях: тёплая «бумажная» светлая и мягкая графитовая тёмная.
- **Качество графики:** низкое (720p), среднее (1080p) или высокое (до 2K) в настройках. Картинка рисуется в этом разрешении и никогда выше родного разрешения экрана; текущее разрешение показано рядом с выбором.
- **Единый набор линейных иконок,** диалоги затемняют экран под собой, новая иконка приложения в новой палитре.
- **В релизах есть пакет для Google Play (AAB)** с контрольными суммами и аттестацией, как у APK; любая ошибка экспорта Godot теперь останавливает сборку релиза.
- **Репозиторий:** полный текст лицензии Apache 2.0 и файл NOTICE; благодарность автору оригинальной 2048 Габриэле Чирулли; FLAC-мастер музыки перенесён в [релиз](https://github.com/Mahiron-hq/2048/releases/tag/soundtrack).
- Проверено на двух телефонах: Infinix Note 50 Pro (Android 16, XOS) и Xiaomi Redmi Note 10S (Android 13, MIUI) - все экраны в обеих темах и ориентациях, уровни качества, тема «Авто» вслед за системой и стресс-тест случайными действиями.

## [1.2.5] - 2026-09-30

### 🇬🇧 English

- **Move hints.** A round bulb button, right of the menu button in portrait and right of the best score in landscape, suggests one move. The tiles lean towards it twice while that edge of the board lights up softly; the move itself is yours. When you have not moved for 15 seconds, the bulb lights up by itself, inviting you to take a hint. Hints are switched off with one tap in Game settings (on by default), and the button goes away with them. There is no limit, and hints do not affect records or statistics.
- **The hints are strong:** an expectimax search goes through every move and every possible new tile and scores positions the way the best 2048 bots do (empty cells, pending merges, monotonic rows). It searches as deep as the phone manages in about a third of a second, in the background, so the game never stutters. Simply following the hints, even at 0.1 s per move, a game reaches the 4096 tile.
- **Vibration works whatever the phone's vibration settings.** On Android 13+ the system-wide "Vibration & haptics" switch (Accessibility; on Xiaomi, the Physical tab) silences every app while it is off. The game now notices this and sends its vibration on the one channel Android still lets through, so only the game's own Vibration switch decides. It re-checks whenever you return to the game.
- **Softer on simple vibration motors.** Most phones cannot vary vibration strength, and there the growing pulses turned into a harsh buzz. Merges now use the phone maker's own tuned effects, from the lightest tick to the heavy click as the tiles grow, and the game-over wave plays as short spaced pulses instead of a solid one-second buzz. Phones that can vary strength keep the smooth steps.
- **The game-over card no longer pops up over the menu:** leaving for the menu or settings right after the losing move made the "No moves left" card appear on top of them a moment later and block every tap. It now waits until you are back on the board.
- **Supply chain:** GitHub Actions updated to their current major versions (checkout 7, cache 6, setup-java 6, action-gh-release 3), still pinned to commit SHAs; Dependabot now sends one grouped update a week.
- Tested on two phones, Infinix Note 50 Pro (Android 16, XOS) and Xiaomi Redmi Note 10S (Android 13, MIUI): hints, vibration with the system switch on and off (checked in the phones' vibration logs), scrolling, landscape and a random-input stress run.

### 🇷🇺 Русский

- **Подсказка хода.** Круглая кнопка с лампочкой справа от кнопки меню в вертикальном положении и справа от рекорда в горизонтальном - предлагает один ход. Плитки дважды плавно подаются в нужную сторону, а этот край поля мягко подсвечивается; сам ход делаете вы. Если не ходить 15 секунд, лампочка загорается сама, предлагая воспользоваться подсказкой. Подсказки выключаются одним касанием в «Настройках игры» (по умолчанию включены), вместе с ними исчезает и кнопка. Ограничений нет, на рекорды и статистику подсказки не влияют.
- **Подсказки сильные:** поиск expectimax перебирает все ходы и все возможные новые плитки и оценивает позиции так же, как лучшие боты для 2048 (пустые клетки, будущие слияния, монотонность рядов). Он углубляется настолько, насколько телефон успевает примерно за треть секунды, в фоне, так что игра не подтормаживает. Если просто следовать подсказкам, даже при 0,1 с на ход партия доходит до плитки 4096.
- **Вибрация работает при любых настройках вибрации телефона.** В Android 13+ общий переключатель «Вибрация и виброотклик» («Специальные возможности»; на Xiaomi - вкладка «Физические») глушит вибрацию всех приложений, пока выключен. Теперь игра это замечает и отправляет вибрацию по единственному каналу, который Android всё равно пропускает, решает только переключатель «Вибрация» в самой игре. Проверка повторяется при каждом возвращении в игру.
- **Мягче на простых вибромоторах.** Большинство телефонов не умеют менять силу вибрации, и там нарастающие импульсы превращались в резкий гул. Теперь слияния используют собственные настроенные эффекты производителя - от самого лёгкого щелчка до тяжёлого по мере роста плиток, а волна проигрыша играется короткими импульсами с паузами вместо сплошного секундного гула. На телефонах, умеющих менять силу, остались плавные ступени.
- **Окно проигрыша больше не всплывает поверх меню:** если сразу после проигрышного хода уйти в меню или настройки, через мгновение поверх них появлялось окно «Ходов больше нет» и блокировало касания. Теперь оно ждёт, пока вы вернётесь к полю.
- **Цепочка поставки:** GitHub Actions обновлены до актуальных мажорных версий (checkout 7, cache 6, setup-java 6, action-gh-release 3) и по-прежнему закреплены на SHA коммитов; Dependabot теперь присылает одно сгруппированное обновление в неделю.
- Проверено на двух телефонах: Infinix Note 50 Pro (Android 16, XOS) и Xiaomi Redmi Note 10S (Android 13, MIUI) - подсказки, вибрация при включённом и выключенном системном переключателе (по журналу вибрации телефонов), прокрутка, горизонтальное положение и стресс-тест случайными действиями.

## [1.2.4] - 2026-09-29

### 🇬🇧 English

- **Scrolling fixed** in Settings and Statistics on phones and tablets, in any orientation. The page scrolled only when a swipe started in a gap between cards, so in portrait it seemed not to scroll at all. Now it scrolls from anywhere: text, cards, switches, selectors and sliders, and a swipe that turns into a scroll never flips the control it started on. A tap with a slightly shaky finger still counts as a tap.
- **What the FPS limit gives,** measured on an Infinix phone with continuous drawing: 60 FPS cuts the game's CPU time by 38%, 30 FPS by 59%, and the GPU draws half or a quarter of the frames. The full table is in the README.
- **Why not 144 Hz on some phones:** Infinix XOS gives 144 Hz only to apps on the maker's own list, and 60 or 120 Hz to every other app. The game asks the system for the screen's maximum and gets it wherever the phone allows.

### 🇷🇺 Русский

- **Исправлена прокрутка** в настройках и статистике на телефонах и планшетах, в любом положении экрана. Страница прокручивалась, только если свайп начинался в промежутке между карточками, поэтому в вертикальном положении казалось, что прокрутки нет вовсе. Теперь листать можно откуда угодно: с текста, карточек, тумблеров, переключателей и ползунков, и свайп, ставший прокруткой, не переключает то, с чего начался. Касание с лёгким дрожанием пальца по-прежнему считается касанием.
- **Что даёт ограничение FPS** - замер на телефоне Infinix при непрерывной отрисовке: 60 FPS снижает процессорное время игры на 38%, 30 FPS - на 59%, а видеочип рисует вдвое и вчетверо меньше кадров. Полная таблица в README.
- **Почему на некоторых телефонах не 144 Гц:** Infinix XOS даёт 144 Гц только приложениям из собственного списка производителя, остальным - 60 или 120 Гц. Игра просит у системы максимум экрана и получает его везде, где телефон это позволяет.

## [1.2.3] - 2026-09-29

### 🇬🇧 English

- **Frame rate limit** (new setting): 30, 60, 90, 120 or ∞ (no limit). Only values the screen can show evenly are offered: 90 only if the screen has a 90 or 180 Hz mode, 120 if it has 120 or 240 Hz. A phone with 60/120/144 Hz modes gets 30, 60, 120 and ∞. The cap applies at once; where the phone allows it, the screen also switches to a matching refresh rate, which saves more battery (some skins, such as Infinix XOS, keep every app at the system rate).
- **Refresh rate readout fixed:** the game now also takes into account the rate chosen in the phone's display settings, which no app can exceed. The FPS counter shows the ceiling that really applies and, if it is below what the screen can do, the panel's own maximum, e.g. "max 120, panel 144", plus the cap if one is set. The game rechecks this whenever you return to it.
- **Bundled font:** Roboto now ships with the game. Some phones (e.g. Infinix with XOS) substituted a serif face for bold system text in titles, scores and the FPS counter.
- **Huge tiles fixed:** tile values are now 64-bit. Merging two 1 073 741 824 tiles produced a negative number, and that game could no longer be loaded. Every tile a 6×6 board can reach (up to 2³⁷) now works.
- **Dialogs:** the "New game?" and "No moves left" cards could stay shrunken and off-centre if the phone was busy while they opened; they now re-fit as soon as their size settles. A very long final score shrinks to fit the card.
- **Smoother first game over:** the game-over card is drawn once, invisibly, at launch, so its first appearance no longer stalls.
- **Game-over vibration:** now two soft pulses, the second one and a half times longer than the first.
- **Scrolling the settings no longer changes them:** a swipe that started on a selector (theme, language, undo, FPS limit) switched it, and a vertical swipe on a volume slider moved the volume. Selectors now react to a tap, sliders to a tap or a sideways drag.
- **Security and supply chain:** a new [SECURITY.md](https://github.com/Mahiron-hq/2048/blob/main/SECURITY.md) with private vulnerability reporting through GitHub. The release build pins every action to a commit SHA, uses least-privilege tokens, checks Godot downloads against their SHA-512 sums and the APK signature against the release certificate, and every release now ships `SHA256SUMS.txt` and a signed build provenance attestation.
- **Music license:** the soundtrack "2048 Quiet Tiles" is now explicitly licensed under CC BY-NC-ND 4.0 ([LICENSE-MUSIC](https://github.com/Mahiron-hq/2048/blob/main/LICENSE-MUSIC)); the code stays under Apache 2.0.
- Stress test on a phone with a 144 Hz screen and Android 16: 6 000 random actions, hundreds of moves with undo, rotations mid-animation, frequent minimizing and restoring, killing the process right after a move, low-memory signals, screen size and density changes. No crashes, no memory growth, saves intact.

### 🇷🇺 Русский

- **Ограничение FPS** (новая настройка): 30, 60, 90, 120 или ∞ (без ограничений). Предлагаются только те значения, которые экран показывает ровно: 90 - только если у экрана есть режим 90 или 180 Гц, 120 - если есть 120 или 240 Гц. На телефоне с режимами 60/120/144 Гц будут 30, 60, 120 и ∞. Ограничение применяется сразу; если телефон позволяет, экран ещё и переключается на подходящую частоту, что экономит больше батареи (некоторые оболочки, например Infinix XOS, держат все приложения на системной частоте).
- **Исправлен показ частоты экрана:** игра теперь учитывает и частоту, выбранную в настройках экрана телефона, выше неё не работает ни одно приложение. Счётчик FPS показывает реально доступный потолок, а если он ниже возможностей экрана, то и максимум самой панели, например «max 120, panel 144», и включённое ограничение. Игра перепроверяет это при каждом возвращении на экран.
- **Встроенный шрифт:** Roboto теперь входит в игру. Некоторые телефоны (например, Infinix с XOS) подставляли вместо жирного системного шрифта шрифт с засечками в заголовках, счёте, счётчике FPS.
- **Исправлены огромные плитки:** значения плиток теперь 64-битные. Слияние двух плиток 1 073 741 824 давало отрицательное число, и такую партию потом нельзя было загрузить. Теперь работают все плитки, достижимые на поле 6×6 (до 2³⁷).
- **Диалоги:** окна «Начать новую игру?» и «Ходов больше нет» могли остаться уменьшенными и смещёнными, если телефон был занят в момент открытия; теперь они подстраиваются, как только их размер устоялся. Очень длинный итоговый счёт уменьшается, чтобы поместиться в карточку.
- **Плавный первый проигрыш:** окно проигрыша один раз невидимо отрисовывается при запуске, поэтому его первое появление больше не подтормаживает.
- **Вибрация при проигрыше:** теперь два мягких толчка, второй в полтора раза длиннее первого.
- **Прокрутка настроек больше их не меняет:** свайп, начатый на переключателе (тема, язык, отмена ходов, ограничение FPS), переключал его, а вертикальный свайп по ползунку громкости сдвигал громкость. Теперь переключатели реагируют на касание, а ползунки - на касание или движение вбок.
- **Безопасность и цепочка поставки:** новый [SECURITY.md](https://github.com/Mahiron-hq/2048/blob/main/SECURITY.md) с приватными сообщениями об уязвимостях через GitHub. Сборка релизов закрепляет все actions на SHA коммитов, использует токены с минимальными правами, сверяет загрузки Godot с суммами SHA-512 и подпись APK с сертификатом релизов, а к каждому релизу теперь прикладываются `SHA256SUMS.txt` и подписанная аттестация происхождения сборки.
- **Лицензия на музыку:** саундтрек «2048 Quiet Tiles» теперь явно распространяется по лицензии CC BY-NC-ND 4.0 ([LICENSE-MUSIC](https://github.com/Mahiron-hq/2048/blob/main/LICENSE-MUSIC)); код остаётся под Apache 2.0.
- Стресс-тест на телефоне с экраном 144 Гц и Android 16: 6 000 случайных действий, сотни ходов с отменами, повороты посреди анимации, частое сворачивание и разворачивание, закрытие процесса сразу после хода, сигналы нехватки памяти, смена размера и плотности экрана - без падений, без роста памяти, сохранения целы.

## [1.2.2] - 2026-09-28

### 🇬🇧 English

- **Haptics that grow with the tiles:** merging 2s is silent, merging 4s gives the lightest tap, and every step up to 65536 is a little stronger; beyond that, full strength. Both the strength and the length of the buzz grow, so the steps are felt on any vibration motor. A lost game ends with a soft, wavy one-second vibration.
- **FPS counter:** fixed a bug that made the FPS line also show which way the vibration works.
- **Theme switch fixed** (a bug since 1.0.0): the screen snapshot for the smooth transition was taken in physical pixels, so on high-density screens the interface briefly blew up past the screen edges, and rapid switching left trails. The snapshot now matches the screen exactly, and only one transition runs at a time.
- **Playing in landscape:** the board in the middle; the 2048 badge and the menu button in the top-left corner, the score against the board's left edge, the best score against its right edge, Undo/New in the bottom-left corner. On narrower screens (16:9, 4:3 tablets) these controls stack into a column, and the board does not shrink. In landscape the FPS counter moved to the bottom-right corner.

### 🇷🇺 Русский

- **Вибрация растёт вместе с плитками:** слияние двоек без вибрации, четвёрок - самый лёгкий толчок, и каждая ступень до 65536 немного сильнее; дальше максимальная сила. Растут и сила, и длительность толчка, поэтому ступени ощущаются на любом вибромоторе. Проигрыш завершается мягкой волнообразной вибрацией на секунду.
- **Счётчик FPS:** исправлен баг, из-за которого строка показа FPS также показывала, каким способом работает вибрация.
- **Исправлена смена темы** (баг с 1.0.0): снимок экрана для плавного перехода брался в физических пикселях, поэтому на экранах с высокой плотностью интерфейс на мгновение раздувался за края экрана, а при частых переключениях оставались шлейфы. Теперь снимок точно по размеру экрана, и одновременно идёт только один переход.
- **Игра в горизонтальном положении:** поле по центру; плашка 2048 и кнопка меню в левом верхнем углу, счёт прижат к левому краю поля, рекорд - к правому, «Отменить»/«Заново» в левом нижнем углу. На более узких экранах (16:9, планшеты 4:3) элементы складываются в столбик, а поле не уменьшается. Счётчик FPS в горизонтальном положении переехал в правый нижний угол.

## [1.2.1] - 2026-09-28

### 🇬🇧 English

- **Fixed a bug that left the game without vibration:** it is now sent with the "media" usage that Android intends for games. Android 12+ filed it under touch or notification feedback, which many phones turn off, so the vibration was muted.
- **Board size picker:** always exactly four rows (the menu sometimes counted old rows and doubled in size), and it stays on screen in landscape.
- **Statistics:** an undone move no longer counts towards total moves.
- **Playing in landscape:** score, Undo/New, then the logo and menu sit in a slim column, and the board stands in the middle of the screen.
- **Swipe hint:** the veil covers the whole board, and the arrows pulse until the first move.
- **The header and side column ignore swipes,** so you can now check the time or pull down the notification shade without moving tiles.
- **Smoother long games:** saving runs on a background thread and in batches, so a slow storage write can no longer freeze the game for seconds; a move is about half as costly for the main thread.
- **Louder music, finer volume:** the soundtrack's top level is about 14% higher, and music and effects now have 7 volume steps each (saved levels carry over).

### 🇷🇺 Русский

- **Исправлен баг, из-за которого отсутствовала вибрация:** теперь она отправляется с назначением «медиа», которое Android предусматривает для игр. Android 12+ относил её к отклику на касания или уведомлениям, а их на многих телефонах отключают, поэтому вибрация глушилась.
- **Выбор размера поля:** всегда ровно четыре строки (иногда меню учитывало старые строки и становилось вдвое больше) и не выходит за экран в горизонтальном положении.
- **Статистика:** отменённый ход больше не засчитывается в общее число ходов.
- **Игра в горизонтальном положении:** счёт, «Отменить»/«Заново», затем логотип и меню - в узкой колонке, а поле стоит по центру экрана.
- **Подсказка свайпа:** затемнение закрывает всё поле, стрелки пульсируют до первого хода.
- **Шапка и боковая колонка не реагируют на свайпы** — теперь можно посмотреть время или опустить шторку уведомлений, не сдвигая плитки.
- **Плавность в долгих партиях:** сохранение идёт в фоновом потоке и пакетами, поэтому медленная запись на диск больше не может «подвесить» игру на секунды; ход стал примерно вдвое дешевле для основного потока.
- **Музыка громче, громкость точнее:** максимальная громкость саундтрека выше примерно на 14%, у музыки и звуков стало по 7 делений (сохранённые уровни переносятся).

## [1.2.0] - 2026-09-28

### 🇬🇧 English

- **Board size:** 3×3, 4×4, 5×5 or 6×6. The button left of "New game" opens a small picker; 4×4 is the default. Records are kept per size.
- **Undo depth:** a new "Game settings" section with 0 to 5 undo steps (default 1). Undo can be turned off; it never goes past the start of the game. The button shows how many steps are left.
- **Statistics:** games played, average score, best tile, best score, total moves and time played, overall or per board size.
- **Any screen, any orientation:** landscape layouts for every screen and proper scaling on tablets; controls keep their physical size when the device turns.
- **Swipe hint:** each new game shows a translucent hint with arrows over the board that disappears after the first move.
- **Settings split** into "App settings" and "Game settings".
- **Automated builds:** every push and pull request runs all tests on GitHub Actions; a version tag builds signed APKs and attaches them to the release.

### 🇷🇺 Русский

- **Размер поля:** 3×3, 4×4, 5×5 или 6×6. Кнопка слева от «Новая игра» открывает небольшое меню выбора; по умолчанию 4×4. Рекорды хранятся отдельно для каждого размера.
- **Глубина отмены:** новый раздел «Настройки игры» - от 0 до 5 отмен хода (по умолчанию 1). Отмену можно выключить; дальше начала партии она не откатывает. На кнопке видно, сколько отмен осталось.
- **Статистика:** сыграно партий, средний счёт, лучшая плитка, рекорд, всего ходов и время в игре - в целом или по размеру поля.
- **Любой экран и ориентация:** горизонтальные раскладки всех экранов и корректное масштабирование на планшетах; при повороте элементы сохраняют физический размер.
- **Подсказка свайпа:** в начале каждой партии поверх поля полупрозрачная подсказка со стрелками, исчезает после первого хода.
- **Настройки разделены** на «Настройки приложения» и «Настройки игры».
- **Автоматические сборки:** каждый push и pull request прогоняет все тесты на GitHub Actions; тег версии собирает подписанные APK и прикладывает их к релизу.

## [1.1.1] - 2026-09-27

### 🇬🇧 English

- **Volume sliders** for music and sound effects, 5 steps each. A click plays at the new level as you change it, and the music volume changes smoothly. Settings are saved.
- **An even cleaner music loop.** The track plays whole and bar-exact, and the bass ringing at the end flows softly into the start of the next bar with no gap, dip or click.

Installs over 1.1.0 and 1.0.0, keeping your best score and settings. `arm64-v8a` for virtually all modern phones, `armeabi-v7a` for older 32-bit devices. Requires Android 8.0+.

### 🇷🇺 Русский

- **Ползунки громкости** для музыки и звуков - по 5 делений. При переключении звучит щелчок на новой громкости; громкость музыки меняется плавно. Настройки сохраняются.
- **Ещё более чистая склейка музыки.** Трек играет целиком, точно по тактам, а звучащий бас в конце мягко перетекает в начало следующего такта без паузы, провала или щелчка.

Ставится поверх 1.1.0 и 1.0.0, рекорд и настройки сохраняются. `arm64-v8a` — для почти всех современных телефонов, `armeabi-v7a` — для старых 32-битных. Нужен Android 8.0+.

## [1.1.0] - 2026-09-27

### 🇬🇧 English

- **Original soundtrack "2048 Quiet Tiles"** instead of the synthesized music. The track loops sample-accurately, with no gap or click at the seam.
- **Animated undo**: the move plays backwards, tiles glide home, merged tiles split apart, the new tile vanishes. Works after a restart too.

Installs over 1.0.0, keeping your best score and settings. `arm64-v8a` for virtually all modern phones, `armeabi-v7a` for older 32-bit devices. Requires Android 8.0+.

### 🇷🇺 Русский

- **Авторский саундтрек «2048 Quiet Tiles»** вместо синтезированной музыки. Трек зациклен с точностью до сэмпла - без паузы и щелчка на стыке.
- **Анимированная отмена хода**: ход проигрывается назад - плитки отъезжают на свои места, слитые разъединяются, новая плитка исчезает. Работает и после перезапуска игры.

Ставится поверх 1.0.0, рекорд и настройки сохраняются. `arm64-v8a` — для почти всех современных телефонов, `armeabi-v7a` — для старых 32-битных. Нужен Android 8.0+.

## [1.0.0] - 2026-09-26

### 🇬🇧 English

**First release.** The classic 2048 puzzle for Android: offline, no ads, no tracking.

- 4×4 board, undo, endless play with celebratory milestones at 128 / 256 / 512 / 1024 / 2048 / …
- Light and dark themes, English and Russian
- Synthesized sound effects and background music, haptics
- Autosave of the best score, settings and the game in progress
- 90 / 120 / 144 Hz display support
- The only permission is vibration; no network access

**Which file:** `arm64-v8a` for virtually all modern phones; `armeabi-v7a` for older 32-bit devices. Requires Android 8.0+.

### 🇷🇺 Русский

**Первый релиз.** Классическая головоломка 2048 для Android - офлайн, без рекламы и трекинга.

- Сетка 4×4, отмена хода, бесконечная игра с праздничными milestone на 128 / 256 / 512 / 1024 / 2048 / …
- Светлая и тёмная темы, русский и английский языки
- Синтезированные звуки и фоновая музыка, вибрация
- Автосохранение рекорда, настроек и текущей партии
- Поддержка экранов 90 / 120 / 144 Гц
- Единственное разрешение - вибрация; интернет не используется

**Какой файл скачать:** `arm64-v8a` — для почти всех современных телефонов; `armeabi-v7a` — для старых 32-битных устройств. Нужен Android 8.0+.
