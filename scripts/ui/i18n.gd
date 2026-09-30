class_name I18n
extends RefCounted
## UI strings for the two supported languages. Missing keys fall back to English, then to the key.

const LANGUAGES := ["ru", "en"]

const STRINGS := {
	"en": {
		"TITLE": "2048",
		"SUBTITLE": "merge puzzle",
		"PLAY": "New game",
		"CONTINUE": "Continue",
		"SETTINGS": "Settings",
		"BEST": "Best",
		"SCORE": "Score",
		"BEST_SCORE": "Best score",
		"MENU": "Menu",
		"UNDO": "Undo",
		"NEW": "New",
		"SOUND": "Sound",
		"MUSIC": "Music",
		"HAPTICS": "Vibration",
		"HINTS": "Move hints",
		"HINTS_HINT": "The bulb on the game screen suggests the best move. It lights up by itself when you pause for a while.",
		"HAPTICS_BLOCKED": "Vibration is turned off in your phone's settings, so no app can vibrate. Turn on \"Vibration & haptics\" under Accessibility (on Xiaomi: the Physical tab).",
		"OPEN_PHONE_SETTINGS": "Open phone settings",
		"THEME": "Theme",
		"THEME_LIGHT": "Light",
		"THEME_DARK": "Dark",
		"LANGUAGE": "Language",
		"SHOW_FPS": "Show FPS",
		"FPS_LIMIT": "Frame rate limit",
		"FPS_LIMIT_HINT": "∞ — no limit, as fast as the screen refreshes. A lower limit saves battery.",
		"BACK": "Back",
		"ON": "On",
		"OFF": "Off",
		"GAME_OVER": "No moves left",
		"FINAL_SCORE": "Score",
		"BEST_TILE": "Best tile",
		"MOVES": "Moves",
		"NEW_RECORD": "New record!",
		"TRY_AGAIN": "Play again",
		"CONFIRM_NEW_TITLE": "Start a new game?",
		"CONFIRM_NEW_BODY": "Current progress will be lost.",
		"YES_NEW": "Start over",
		"CANCEL": "Cancel",
		"MILESTONE": "Tile %d reached!",
		"HINT": "Swipe to move the tiles",
		"STATS": "Statistics",
		"STATS_ALL": "All",
		"GAMES_PLAYED": "Games played",
		"AVERAGE_SCORE": "Average score",
		"TOTAL_MOVES": "Total moves",
		"PLAY_TIME": "Time played",
		"BOARD_SIZE": "Board size",
		"APP_SETTINGS": "App settings",
		"GAME_SETTINGS": "Game settings",
		"UNDO_LIMIT": "Undo moves",
		"UNDO_LIMIT_HINT": "How many moves in a row you can take back",
		"UNDO_OFF": "Off",
		"SWIPE_TO_PLAY": "Swipe to move the tiles",
		"TIME_HM": "%d h %d min",
		"TIME_MS": "%d min %d s",
		"TIME_S": "%d s",
		"NO_GAMES": "Finish a game to see your stats",
	},
	"ru": {
		"TITLE": "2048",
		"SUBTITLE": "головоломка слияний",
		"PLAY": "Новая игра",
		"CONTINUE": "Продолжить",
		"SETTINGS": "Настройки",
		"BEST": "Рекорд",
		"SCORE": "Счёт",
		"BEST_SCORE": "Лучший результат",
		"MENU": "Меню",
		"UNDO": "Отменить",
		"NEW": "Заново",
		"SOUND": "Звук",
		"MUSIC": "Музыка",
		"HAPTICS": "Вибрация",
		"HINTS": "Подсказки хода",
		"HINTS_HINT": "Лампочка на экране игры подсказывает лучший ход. Если долго не ходить, она загорается сама.",
		"HAPTICS_BLOCKED": "Вибрация выключена в настройках телефона, поэтому не может вибрировать ни одно приложение. Включите «Вибрация и виброотклик» в разделе «Специальные возможности» (на Xiaomi — вкладка «Физические»).",
		"OPEN_PHONE_SETTINGS": "Открыть настройки телефона",
		"THEME": "Тема",
		"THEME_LIGHT": "Светлая",
		"THEME_DARK": "Тёмная",
		"LANGUAGE": "Язык",
		"SHOW_FPS": "Показывать FPS",
		"FPS_LIMIT": "Ограничение FPS",
		"FPS_LIMIT_HINT": "∞ — без ограничений, с частотой обновления экрана. Меньше кадров — меньше расход батареи.",
		"BACK": "Назад",
		"ON": "Вкл",
		"OFF": "Выкл",
		"GAME_OVER": "Ходов больше нет",
		"FINAL_SCORE": "Счёт",
		"BEST_TILE": "Лучшая плитка",
		"MOVES": "Ходов",
		"NEW_RECORD": "Новый рекорд!",
		"TRY_AGAIN": "Заново",
		"CONFIRM_NEW_TITLE": "Начать новую игру?",
		"CONFIRM_NEW_BODY": "Текущий прогресс будет потерян.",
		"YES_NEW": "Начать заново",
		"CANCEL": "Отмена",
		"MILESTONE": "Плитка %d собрана!",
		"HINT": "Проведите пальцем, чтобы сдвинуть плитки",
		"STATS": "Статистика",
		"STATS_ALL": "Все",
		"GAMES_PLAYED": "Сыграно партий",
		"AVERAGE_SCORE": "Средний счёт",
		"TOTAL_MOVES": "Всего ходов",
		"PLAY_TIME": "Время в игре",
		"BOARD_SIZE": "Размер поля",
		"APP_SETTINGS": "Настройки приложения",
		"GAME_SETTINGS": "Настройки игры",
		"UNDO_LIMIT": "Отмена ходов",
		"UNDO_LIMIT_HINT": "Сколько ходов подряд можно вернуть назад",
		"UNDO_OFF": "Выкл",
		"SWIPE_TO_PLAY": "Проведите пальцем, чтобы сдвинуть плитки",
		"TIME_HM": "%d ч %d мин",
		"TIME_MS": "%d мин %d с",
		"TIME_S": "%d с",
		"NO_GAMES": "Завершите партию, чтобы увидеть статистику",
	},
}

const LANGUAGE_NAMES := {"ru": "Русский", "en": "English"}

static var current := "en"


static func t(key: String) -> String:
	var table: Dictionary = STRINGS.get(current, STRINGS.en)
	if table.has(key):
		return table[key]
	return STRINGS.en.get(key, key)


## Formats a duration in whole seconds, e.g. "2 h 15 min" / "2 ч 15 мин".
static func duration(seconds: float) -> String:
	var total := int(seconds)
	var h := total / 3600
	var m := (total % 3600) / 60
	if h > 0:
		return t("TIME_HM") % [h, m]
	if m > 0:
		return t("TIME_MS") % [m, total % 60]
	return t("TIME_S") % total


## Groups thousands with a thin space: 12480 -> "12 480".
static func number(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	while digits.length() > 3:
		out = " " + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return ("-" if n < 0 else "") + digits + out


## Board size label such as "4×4".
static func grid(n: int) -> String:
	return "%d×%d" % [n, n]


## Language to use when the player has not chosen one: the OS language if supported.
static func detect() -> String:
	var lang := OS.get_locale_language()
	return lang if LANGUAGES.has(lang) else "en"
