## Composition-based state machine for creature board behavior.
## Attached as a child of a Creature node. Drives AnimatedSprite2D playback
## and exposes reusable animation helper functions called by the creature.
##
## States: IDLE, WALKING, ATTACKING, HURT, DYING, DEAD
## Each state has an enter/exit pair and a process tick.
class_name CreatureStateMachine
extends Node

# =============================================================================
# State Enum
# =============================================================================

enum State {
	IDLE,
	WALKING,
	ATTACKING,
	HURT,
	DYING,
	DEAD,
}

## Emitted whenever the state changes. Useful for UI or debug readouts.
signal state_changed(old_state: int, new_state: int)

## Emitted when an attack animation reaches the "hit" frame (configure per creature).
signal attack_hit

## Emitted when a non-looping animation finishes (walk arrival, attack done, hurt done, death done).
signal animation_finished

# =============================================================================
# Configuration
# =============================================================================

## Map of State -> StringName animation to play on the AnimatedSprite2D.
## Populated by the creature scene or creature script during setup.
## Example: { State.IDLE: &"idle", State.WALKING: &"walk", State.ATTACKING: &"attack01" }
var anim_map: Dictionary = {
	State.IDLE: &"idle",
	State.WALKING: &"walk",
	State.ATTACKING: &"attack01",
	State.HURT: &"hurt",
	State.DYING: &"death",
}

## The frame index in the attack animation that counts as the "hit" moment.
## Set per-creature if attack timing varies.
var attack_hit_frame: int = 3

# =============================================================================
# State
# =============================================================================

## Current state. Typed as int to avoid GDScript parser issues with inner enums.
var current_state: int = State.IDLE

## Reference to the owning creature's AnimatedSprite2D.
var _sprite: AnimatedSprite2D = null

## Whether we've emitted the attack_hit signal for the current attack.
var _attack_hit_emitted: bool = false

## Callback for when walking finishes (called by _on_animation_finished or externally).
var _on_walk_complete: Callable = Callable()


# =============================================================================
# Setup
# =============================================================================

## Initialize the state machine with a reference to the creature's AnimatedSprite2D.
## Call this from creature._ready() or creature.initialize().
func setup(sprite: AnimatedSprite2D) -> void:
	_sprite = sprite
	_sprite.animation_finished.connect(_on_sprite_animation_finished)
	_sprite.frame_changed.connect(_on_sprite_frame_changed)
	_enter_state(State.IDLE)


# =============================================================================
# State Transitions
# =============================================================================

## Valid transitions. States not listed here cannot be transitioned to.
## Uses a var instead of const because GDScript doesn't allow inner enum
## values as keys in const Dictionary expressions.
var _TRANSITIONS: Dictionary = {
	State.IDLE: [State.WALKING, State.ATTACKING, State.HURT, State.DYING],
	State.WALKING: [State.IDLE, State.HURT, State.DYING],
	State.ATTACKING: [State.IDLE, State.HURT, State.DYING],
	State.HURT: [State.IDLE, State.DYING, State.DEAD],
	State.DYING: [State.DEAD],
	State.DEAD: [],
}


## Attempt a state transition. Returns true if successful.
func transition_to(new_state: int) -> bool:
	if new_state == current_state:
		return true
	var allowed: Array = _TRANSITIONS.get(current_state, [])
	if new_state not in allowed:
		push_warning("CreatureStateMachine: invalid transition %s -> %s" % [
			State.keys()[current_state], State.keys()[new_state],
		])
		return false
	var old: int = current_state
	_exit_state(current_state)
	current_state = new_state
	_enter_state(new_state)
	state_changed.emit(old, new_state)
	return true


func _exit_state(state: int) -> void:
	match state:
		State.ATTACKING:
			_attack_hit_emitted = false
		State.WALKING:
			_on_walk_complete = Callable()


func _enter_state(state: int) -> void:
	match state:
		State.IDLE:
			_play_sprite_anim(State.IDLE, true)
		State.WALKING:
			_play_sprite_anim(State.WALKING, true)
		State.ATTACKING:
			_attack_hit_emitted = false
			_play_sprite_anim(State.ATTACKING, false)
		State.HURT:
			_play_sprite_anim(State.HURT, false)
		State.DYING:
			_play_sprite_anim(State.DYING, false)
		State.DEAD:
			# Sprite stays on last death frame. Creature handles queue_free.
			pass


# =============================================================================
# Reusable Animation Functions
# =============================================================================
# These are the public API that creature.gd and subclasses call.

## Play the idle animation. Only valid from certain states.
func play_idle() -> void:
	transition_to(State.IDLE)


## Play the walk animation. Optionally provide a callback for when walking completes.
## Walking loops until stop_walking() is called or the creature transitions away.
func play_walk(on_complete: Callable = Callable()) -> void:
	_on_walk_complete = on_complete
	transition_to(State.WALKING)


## Stop walking and return to idle. Fires the walk-complete callback if set.
func stop_walking() -> void:
	if current_state != State.WALKING:
		return
	var callback: Callable = _on_walk_complete
	transition_to(State.IDLE)
	if callback.is_valid():
		callback.call()


## Play an attack animation. Optionally override which attack anim to use.
## The attack_hit signal fires when the hit frame is reached.
## Returns to IDLE automatically when the animation finishes.
func play_attack(attack_anim: StringName = &"") -> void:
	if attack_anim != &"":
		anim_map[State.ATTACKING] = attack_anim
	transition_to(State.ATTACKING)


## Play the hurt animation. Returns to IDLE when done.
func play_hurt() -> void:
	transition_to(State.HURT)


## Play the death animation. Transitions to DEAD when done.
func play_death() -> void:
	transition_to(State.DYING)


# =============================================================================
# Sprite Animation Playback
# =============================================================================

## Play the mapped animation for a state on the AnimatedSprite2D.
func _play_sprite_anim(state: int, looping: bool) -> void:
	if _sprite == null:
		return
	var anim_name: StringName = anim_map.get(state, &"")
	if anim_name == &"":
		return
	if _sprite.sprite_frames == null:
		return
	if not _sprite.sprite_frames.has_animation(anim_name):
		push_warning("CreatureStateMachine: missing animation '%s'" % anim_name)
		return
	# SpriteFrames loop setting is baked into the resource, but we can
	# control it at runtime if needed.
	_sprite.play(anim_name)


## Called when AnimatedSprite2D finishes a non-looping animation.
func _on_sprite_animation_finished() -> void:
	animation_finished.emit()
	match current_state:
		State.ATTACKING:
			transition_to(State.IDLE)
		State.HURT:
			transition_to(State.IDLE)
		State.DYING:
			transition_to(State.DEAD)


## Called every frame the sprite advances. Used to detect the attack "hit" frame.
func _on_sprite_frame_changed() -> void:
	if current_state == State.ATTACKING and not _attack_hit_emitted:
		if _sprite.frame >= attack_hit_frame:
			_attack_hit_emitted = true
			attack_hit.emit()


# =============================================================================
# Queries
# =============================================================================

## Whether the creature is in a state that allows interaction (movement, abilities).
func can_act() -> bool:
	return current_state == State.IDLE


## Whether the creature is currently animating (non-idle, non-dead).
func is_busy() -> bool:
	return current_state != State.IDLE and current_state != State.DEAD


## Whether the creature is dead.
func is_dead() -> bool:
	return current_state == State.DEAD
