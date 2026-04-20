## Global developer mode toggle. When enabled, various subsystems expose
## debug-only affordances (the deck viewer grows "+ Hand" buttons, future
## debug commands unlock, etc.). Toggled with a keyboard shortcut so it's
## always reachable regardless of which scene is active.
##
## Subsystems that expose dev-only features read DevMode.enabled and/or
## listen to the `changed` signal to refresh their UI when the flag flips.
##
## Autoload registration: project.godot's [autoload] section.
extends Node


# =============================================================================
# Signals
# =============================================================================

## Fires whenever the enabled flag changes. Listeners use this to refresh
## their visibility / available actions without polling every frame.
signal changed(enabled: bool)


# =============================================================================
# Keyboard shortcut
# =============================================================================

## Keycode that toggles dev mode. F9 is off the beaten path so it won't
## collide with gameplay keybinds. Override via set_toggle_key() if you
## want a different key (e.g. for playtesting builds).
@export var toggle_key: Key = KEY_F9


# =============================================================================
# State
# =============================================================================

## Whether dev mode is currently active. Defaults to false for real play —
## enable via the toggle key or by calling set_enabled() in code.
var enabled: bool = false


# =============================================================================
# Lifecycle
# =============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == toggle_key:
			toggle()
			get_viewport().set_input_as_handled()


# =============================================================================
# Public API
# =============================================================================

## Flip dev mode and emit `changed`. Returns the new state.
func toggle() -> bool:
	return set_enabled(not enabled)


## Explicitly set the flag. No-op (and no signal emit) if already in that state.
func set_enabled(new_state: bool) -> bool:
	if new_state == enabled:
		return enabled
	enabled = new_state
	print("[DevMode] ", "ENABLED" if enabled else "disabled")
	changed.emit(enabled)
	return enabled
