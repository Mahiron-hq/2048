class_name Design
extends RefCounted
## Design tokens: spacing, type, radii, control sizes, depth and motion. Screens and widgets take
## every measure from here; units are canvas units on the 720-wide base.

# Spacing: multiples of a 4-unit step.
const UNIT := 4.0
const SPACE_2XS := 4.0
const SPACE_XS := 8.0
const SPACE_SM := 12.0
const SPACE_MD := 16.0
const SPACE_LG := 24.0
const SPACE_XL := 32.0
const SPACE_2XL := 48.0
const SPACE_3XL := 64.0
## Side margin of every screen.
const GUTTER := SPACE_XL

# Type scale (Manrope). Six sizes, each with one job.
const TEXT_DISPLAY := 96   ## final score
const TEXT_TITLE := 48     ## screen titles
const TEXT_HEADLINE := 36  ## dialog titles, big values
const TEXT_BODY := 30      ## list labels, buttons
const TEXT_CALLOUT := 26   ## secondary lines, hints
const TEXT_CAPTION := 22   ## captions over numbers

const WEIGHT_REGULAR := 500
const WEIGHT_MEDIUM := 600
const WEIGHT_BOLD := 700
const WEIGHT_HEAVY := 800

## Captions in capitals get a little air between letters.
const CAPTION_TRACKING := 1

# Radii. Controls are full pills; containers use this scale, and nested shapes keep the
# outer radius = inner radius + inset, so their curves stay parallel.
const RADIUS_SM := 12.0
const RADIUS_MD := 20.0
const RADIUS_LG := 28.0
const RADIUS_XL := 36.0
## Tile corner as a share of the tile side; the board adds its padding on top.
const TILE_RADIUS := 0.14
## Visible bottom edge of a tile as a share of its side.
const TILE_DEPTH := 0.035
## Gap between tiles as a share of the board side, before the grid size adjusts it.
const BOARD_GAP := 0.15

# Control sizes. 88 units is about 48 dp on a phone, the comfortable touch target.
const CONTROL_LG := 104.0
const CONTROL_MD := 88.0
const CONTROL_SM := 72.0
const ROW_HEIGHT := 104.0
const ICON_MD := 36.0
const ICON_SM := 28.0
const SWITCH_SIZE := Vector2(88, 52)
## Readable column for lists and dialogs on wide screens.
const COLUMN_MAX := 720.0
const DIALOG_WIDTH := 600.0

# Depth. One soft shadow for raised surfaces, a stronger one for dialogs; hairlines instead of
# shadows where a shadow would not show (dark theme).
const HAIRLINE := 2
const SHADOW_RAISED := Vector3(0, 4, 12)   ## x offset, y offset, blur
const SHADOW_DIALOG := Vector3(0, 16, 40)

# Motion. Short and eased out, so nothing ever waits on an animation.
const DUR_INSTANT := 0.08
const DUR_FAST := 0.14
const DUR_BASE := 0.2
const DUR_SLOW := 0.32
const PRESS_SCALE := 0.04


## Rounded box with the theme's surface look. [param depth]: 0 flat, 1 raised, 2 dialog.
static func surface_box(color: Color, radius: float, depth := 0, padding := 0.0) -> StyleBoxFlat:
	var p := Palette.current
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(radius))
	box.corner_detail = 12
	box.anti_aliasing = true
	if padding > 0.0:
		box.set_content_margin_all(padding)
	if depth > 0:
		var s := SHADOW_DIALOG if depth >= 2 else SHADOW_RAISED
		box.shadow_color = Color(p.shadow, p.shadow.a * (1.6 if depth >= 2 else 1.0))
		box.shadow_offset = Vector2(s.x, s.y)
		box.shadow_size = int(s.z)
	if p.dark and depth > 0:
		box.border_color = p.outline
		box.set_border_width_all(HAIRLINE)
	return box


## Godot theme for the stock widgets still in use (labels, scroll bars), built from the tokens.
static func make_theme() -> Theme:
	var p := Palette.current
	var t := Theme.new()
	t.default_font = Fonts.sans(WEIGHT_REGULAR)
	t.default_font_size = TEXT_BODY
	t.set_color("font_color", "Label", p.text)
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(p.text_secondary, 0.35)
	grabber.set_corner_radius_all(3)
	grabber.content_margin_left = 3
	grabber.content_margin_right = 3
	var grabber_hot := grabber.duplicate()
	grabber_hot.bg_color = Color(p.text_secondary, 0.55)
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = 3
	empty.content_margin_right = 3
	t.set_stylebox("scroll", "VScrollBar", empty)
	t.set_stylebox("scroll_focus", "VScrollBar", empty)
	t.set_stylebox("grabber", "VScrollBar", grabber)
	t.set_stylebox("grabber_highlight", "VScrollBar", grabber_hot)
	t.set_stylebox("grabber_pressed", "VScrollBar", grabber_hot)
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	return t


## Ease-out curve shared by every enter and settle animation.
static func ease_out(tw: Tweener) -> Tweener:
	return (tw as PropertyTweener).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
