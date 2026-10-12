class_name I18n
extends RefCounted
## UI strings for the two supported languages, from locale/*.po through the TranslationServer.
## Keys missing in a language fall back to English, then to the key itself.

const LANGUAGES := ["ru", "en"]
const LANGUAGE_NAMES := {"ru": "Русский", "en": "English"}
## System languages that get Russian on first launch: neighbouring countries where Russian is
## widely read, while this game speaks only Russian and English.
const RUSSIAN_READERS := ["ru", "uk", "be", "kk", "ky", "uz", "tg", "hy", "az", "ka", "tk", "mo"]

## Current UI language, one of LANGUAGES.
static var current := "en":
	set(v):
		current = v
		TranslationServer.set_locale(v)


static func t(key: String) -> String:
	return String(TranslationServer.translate(key))


## The plural form of [param key] for [param n], with n filled in, e.g. "5 партий".
static func tn(key: String, n: int) -> String:
	return String(TranslationServer.translate_plural(key, key + "_PLURAL", n)) % number(n)


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


## Groups thousands with a no-break space (the font has no thin one): 12480 -> "12 480".
static func number(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	while digits.length() > 3:
		out = " " + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return ("-" if n < 0 else "") + digits + out


## Board size label such as "4×4".
static func grid(n: int) -> String:
	return "%d×%d" % [n, n]


## Language to use when the player has not chosen one: Russian for the system languages in
## RUSSIAN_READERS, otherwise English.
static func detect() -> String:
	return for_locale(OS.get_locale())


static func for_locale(locale: String) -> String:
	var lang := locale.get_slice("_", 0).get_slice("-", 0).to_lower()
	if lang in RUSSIAN_READERS or locale.replace("-", "_") in RUSSIAN_READERS:
		return "ru"
	return "en"
