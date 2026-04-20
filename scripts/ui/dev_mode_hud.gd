## Screen-space banner shown while DevMode is active. Gives the tester an
## unmistakable visual cue that debug affordances (deck card tutor, future
## debug commands) are live. Hidden otherwise.
##
## Lives in its own CanvasLayer so it renders on top of everything and isn't
## affected by camera transforms.
class_name DevModeHUD
extends Control


# =============================================================================
# Layout
# =============================================================================

const MARGIN_LEFT: float = 20.0
const MARGIN_TOP: float = 20.0
const FONT_SIZE: int = 18

## Banner background color (high-contrast magenta so it can't be confused
## with gameplay UI). Text renders white on top.
const BG_COLOR: Color = Color(0.85, 0.1, 0.55, 0.85)
const TEXT_COLOR: Color = Color(1.0, 1.0, 1.0)

## Which keycode the banner displays as the "press to toggle" hint.
## Should match DevMode.toggle_key.
const DISPLAY_TOGGLE_KEY: String = "F9"


# =============================================================================
# State
# =============================================================================

var _panel: PanelContainer = null
var _label: Label = null


# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_banner()
	_refresh_visibility()
	DevMode.changed.connect(_on_dev_mode_changed)


# =============================================================================
# Construction
# =============================================================================

func _build_banner() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(MARGIN_LEFT, MARGIN_TOP)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Panel background — a flat colored rect via StyleBoxFlat.
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = BG_COLOR
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	_panel.add_theme_stylebox_override("panel", style)

	_label = Label.new()
	_label.text = "◉  DEV MODE  (%s to toggle)" % DISPLAY_TOGGLE_KEY
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", TEXT_COLOR)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", 2)
	_panel.add_child(_label)
	add_child(_panel)


# =============================================================================
# Handlers
# =============================================================================

func _on_dev_mode_changed(_enabled: bool) -> void:
	_refresh_visibility()


func _refresh_visibility() -> void:
	if _panel:
		_panel.visible = DevMode.enabled
