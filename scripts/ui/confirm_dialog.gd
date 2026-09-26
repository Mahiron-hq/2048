class_name ConfirmDialog
extends Modal
## Yes/cancel question. The confirm callback is supplied per [method ask] call.

var _title := SkinLabel.make("CONFIRM_NEW_TITLE", 40, Fonts.BOLD)
var _text := SkinLabel.make("CONFIRM_NEW_BODY", 28, Fonts.REGULAR, SkinLabel.Role.MUTED)
var _yes := PillButton.make("YES_NEW", PillButton.Look.PRIMARY)
var _no := PillButton.make("CANCEL", PillButton.Look.SECONDARY)
var _on_yes := Callable()


func _init() -> void:
	super._init()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_title)
	body.add_child(_text)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	body.add_child(spacer)
	body.add_child(Modal.button_row([_no, _yes]))
	_yes.pressed.connect(_confirm)
	_no.pressed.connect(close)
	_scrim.gui_input.connect(_on_scrim_input)


## Opens the dialog; [param on_yes] runs if the player confirms.
func ask(title_key: String, body_key: String, yes_key: String, on_yes: Callable) -> void:
	_title.set_key(title_key)
	_text.set_key(body_key)
	_yes.set_key(yes_key)
	_on_yes = on_yes
	open()


func _confirm() -> void:
	var cb := _on_yes
	_on_yes = Callable()
	close()
	if cb.is_valid():
		cb.call()


func _on_scrim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()
