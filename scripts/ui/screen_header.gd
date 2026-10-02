class_name ScreenHeader
extends HBoxContainer
## Top bar of a secondary screen: round back button and the screen title.

var back := PillButton.make_icon(Icons.Kind.BACK)


static func make(title_key: String, on_back: Callable) -> ScreenHeader:
	var h := ScreenHeader.new()
	h.add_theme_constant_override("separation", int(Design.SPACE_MD))
	h.back.pressed.connect(on_back)
	h.add_child(h.back)
	var title := SkinLabel.make(title_key, Design.TEXT_TITLE, Design.WEIGHT_HEAVY)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.custom_minimum_size.y = Design.CONTROL_MD
	h.add_child(title)
	return h
