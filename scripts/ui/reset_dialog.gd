class_name ResetDialog
extends Modal
## Two-step confirmation for clearing statistics or records, or for replacing them with an
## imported file. The first step picks the board sizes (for a reset), the second asks again with a
## button that only wakes up after ARM_SECONDS, so a stray tap can never wipe anything.

## What a confirmed reset clears.
enum Scope { STATS, RECORDS, ALL }

signal confirmed(scope: Scope, size: int)

const ARM_SECONDS := 3
## Board size filter: 0 means every size.
const SIZES := [0, 3, 4, 5, 6]
const TITLES := ["RESET_STATS_TITLE", "RESET_RECORDS_TITLE", "RESET_ALL_TITLE"]
const BODIES := ["RESET_STATS_BODY", "RESET_RECORDS_BODY", "RESET_ALL_BODY"]

var _scope := Scope.STATS
var _second_step := false
## Set for an import: runs instead of emitting [signal confirmed].
var _on_import := Callable()
var _import_summary := ""
var _left := 0
var _title := SkinLabel.make("", Design.TEXT_HEADLINE, Design.WEIGHT_HEAVY)
var _text := SkinLabel.make("", Design.TEXT_CALLOUT, Design.WEIGHT_REGULAR, SkinLabel.Role.MUTED)
var _sizes := Segmented.new()
var _go := PillButton.make("CONTINUE_STEP", PillButton.Look.PRIMARY)
var _no := PillButton.make("CANCEL", PillButton.Look.SECONDARY)
var _timer := Timer.new()


func _init() -> void:
	super._init()
	for l in [_title, _text]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var labels := PackedStringArray(["STATS_ALL"])
	for n in SIZES.slice(1):
		labels.append(I18n.grid(n))
	_sizes.options = labels
	_sizes.custom_minimum_size = Vector2(0, Design.CONTROL_SM)
	body.add_child(_title)
	body.add_child(_text)
	body.add_child(Modal.gap(Design.SPACE_XS))
	body.add_child(_sizes)
	body.add_child(Modal.gap(Design.SPACE_MD))
	body.add_child(Modal.button_row([_no, _go]))
	_timer.wait_time = 1.0
	_timer.timeout.connect(_tick)
	add_child(_timer)
	_go.pressed.connect(_on_go)
	_no.pressed.connect(close)
	_scrim.gui_input.connect(_on_scrim_input)


## Opens the first step for [param scope].
func ask(scope: Scope) -> void:
	_scope = scope
	_on_import = Callable()
	_second_step = false
	_timer.stop()
	_sizes.set_index_silently(0)
	_sizes.visible = true
	_title.set_key(TITLES[scope])
	_text.set_key(BODIES[scope])
	_go.disabled = false
	_go.text_override = ""
	_go.set_key("CONTINUE_STEP")
	open()


## Opens the first step of replacing everything with an imported file described by
## [param summary]; [param on_yes] runs once both steps are confirmed.
func ask_import(summary: String, on_yes: Callable) -> void:
	_on_import = on_yes
	_import_summary = summary
	_second_step = false
	_timer.stop()
	_sizes.visible = false
	_title.set_key("IMPORT_TITLE")
	_text.set_key("IMPORT_BODY")
	_go.disabled = false
	_go.text_override = ""
	_go.set_key("CONTINUE_STEP")
	open()


func close() -> void:
	_timer.stop()
	super.close()


func selected_size() -> int:
	return SIZES[_sizes.index]


func is_armed() -> bool:
	return _second_step and not _go.disabled


func _on_go() -> void:
	if not _second_step:
		_second_step = true
		_sizes.visible = false
		_title.set_key("IMPORT_SURE_TITLE" if _on_import.is_valid() else "RESET_SURE_TITLE")
		if _on_import.is_valid():
			_text.set_key("")
			_text.text = _import_summary
			_go.set_key("IMPORT_DO")
		else:
			var what := I18n.t("RESET_SCOPE_ALL") if selected_size() == 0 else I18n.t("RESET_SCOPE_ONE") % I18n.grid(selected_size())
			_text.set_key("RESET_SURE_BODY", what)
			_go.set_key("RESET_DO")
		_left = ARM_SECONDS
		_go.disabled = true
		_show_countdown()
		_timer.start()
		return
	if _go.disabled:
		return
	var size := selected_size()
	var on_import := _on_import
	close()
	if on_import.is_valid():
		on_import.call()
	else:
		confirmed.emit(_scope, size)


func _tick() -> void:
	_left -= 1
	if _left <= 0:
		_timer.stop()
		_go.disabled = false
		_go.text_override = ""
	else:
		_show_countdown()


func _show_countdown() -> void:
	_go.text_override = "%s (%d)" % [I18n.t("IMPORT_DO" if _on_import.is_valid() else "RESET_DO"), _left]


func _on_scrim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()
