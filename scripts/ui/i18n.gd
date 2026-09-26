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
		"THEME": "Theme",
		"THEME_LIGHT": "Light",
		"THEME_DARK": "Dark",
		"LANGUAGE": "Language",
		"SHOW_FPS": "Show FPS",
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
		"THEME": "Тема",
		"THEME_LIGHT": "Светлая",
		"THEME_DARK": "Тёмная",
		"LANGUAGE": "Язык",
		"SHOW_FPS": "Показывать FPS",
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
	},
}

const LANGUAGE_NAMES := {"ru": "Русский", "en": "English"}

static var current := "en"


static func t(key: String) -> String:
	var table: Dictionary = STRINGS.get(current, STRINGS.en)
	if table.has(key):
		return table[key]
	return STRINGS.en.get(key, key)


## Language to use when the player has not chosen one: the OS language if supported.
static func detect() -> String:
	var lang := OS.get_locale_language()
	return lang if LANGUAGES.has(lang) else "en"
