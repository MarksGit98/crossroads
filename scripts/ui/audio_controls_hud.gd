## Two-button audio toggle HUD, anchored to the top-right of the viewport.
## One button toggles music mute, the other toggles SFX mute. Labels use
## unicode glyphs so no icon assets are required — swap for proper icons
## later by replacing the text with TextureRect children if desired.
##
## Stays synced with AudioManager: if any other system (future settings
## menu, keyboard shortcut) toggles a bus, the buttons update via signals.
class_name AudioControlsHUD
extends Control


# =============================================================================
# Layout constants
# =============================================================================

## Distance from the top-right corner of the viewport (pixels).
const MARGIN_RIGHT: float = 20.0
const MARGIN_TOP: float = 20.0

## Size of each button (square). Buttons sit next to each other.
const BUTTON_SIZE: float = 44.0

## Horizontal gap between the two buttons.
const BUTTON_SPACING: float = 8.0

## Font size for the glyph labels.
const GLYPH_FONT_SIZE: int = 22


# =============================================================================
# Glyphs (unicode characters usable without custom icon textures)
# =============================================================================

const GLYPH_MUSIC_ON: String = "♪"
const GLYPH_MUSIC_OFF: String = "♪̸"   # struck-through — signals muted state
const GLYPH_SFX_ON: String = "♫"
const GLYPH_SFX_OFF: String = "♫̸"


# =============================================================================
# Colors
# =============================================================================

const COLOR_ACTIVE: Color = Color(1.0, 1.0, 1.0)       # full white when unmuted
const COLOR_MUTED: Color = Color(0.55, 0.55, 0.55)     # dimmed when muted


# =============================================================================
# State
# =============================================================================

var _music_button: Button = null
var _sfx_button: Button = null


# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	# Full-screen Control — we position children manually.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # only buttons intercept clicks

	_build_buttons()
	_position_buttons()
	get_viewport().size_changed.connect(_position_buttons)

	# Sync initial labels with current AudioManager state (they may have
	# been toggled by a settings menu before this HUD was created).
	_refresh_music_button(AudioManager.is_music_muted())
	_refresh_sfx_button(AudioManager.is_sfx_muted())

	# Keep labels in lockstep if other code paths flip the mute state.
	AudioManager.music_muted_changed.connect(_refresh_music_button)
	AudioManager.sfx_muted_changed.connect(_refresh_sfx_button)


# =============================================================================
# Construction
# =============================================================================

func _build_buttons() -> void:
	_music_button = _make_toggle_button(_on_music_pressed)
	_sfx_button = _make_toggle_button(_on_sfx_pressed)
	add_child(_music_button)
	add_child(_sfx_button)


func _make_toggle_button(on_pressed: Callable) -> Button:
	var btn: Button = Button.new()
	btn.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	btn.size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	btn.add_theme_font_size_override("font_size", GLYPH_FONT_SIZE)
	btn.focus_mode = Control.FOCUS_NONE  # no outline when clicked
	btn.pressed.connect(on_pressed)
	return btn


# =============================================================================
# Layout
# =============================================================================

## Anchor both buttons to the top-right, re-running when the viewport resizes.
## SFX button sits further left than Music button so the music icon is the
## rightmost (nearest the corner).
func _position_buttons() -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	var y: float = MARGIN_TOP
	var music_x: float = vp_size.x - MARGIN_RIGHT - BUTTON_SIZE
	var sfx_x: float = music_x - BUTTON_SPACING - BUTTON_SIZE
	if _music_button:
		_music_button.position = Vector2(music_x, y)
	if _sfx_button:
		_sfx_button.position = Vector2(sfx_x, y)


# =============================================================================
# Handlers
# =============================================================================

func _on_music_pressed() -> void:
	AudioManager.toggle_music_muted()
	# music_muted_changed signal fires inside AudioManager, which updates
	# our label via _refresh_music_button. No direct update needed here.


func _on_sfx_pressed() -> void:
	AudioManager.toggle_sfx_muted()


func _refresh_music_button(muted: bool) -> void:
	if _music_button == null:
		return
	_music_button.text = GLYPH_MUSIC_OFF if muted else GLYPH_MUSIC_ON
	_music_button.add_theme_color_override(
		"font_color", COLOR_MUTED if muted else COLOR_ACTIVE
	)
	_music_button.tooltip_text = "Unmute music" if muted else "Mute music"


func _refresh_sfx_button(muted: bool) -> void:
	if _sfx_button == null:
		return
	_sfx_button.text = GLYPH_SFX_OFF if muted else GLYPH_SFX_ON
	_sfx_button.add_theme_color_override(
		"font_color", COLOR_MUTED if muted else COLOR_ACTIVE
	)
	_sfx_button.tooltip_text = "Unmute sound effects" if muted else "Mute sound effects"
