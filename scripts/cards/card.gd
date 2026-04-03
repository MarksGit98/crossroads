class_name Card
extends Node2D

signal card_event(card: Card, event: CardTypes.CardEvent)
signal state_changed(card: Card, old_state: CardTypes.CardState, new_state: CardTypes.CardState)

# =============================================================================
# Resources
# =============================================================================

## Preload the card hover shader so every card instance shares the same compiled shader.
var _shader: Shader = preload("res://assets/shaders/card_hover.gdshader")

## Card face layout scene — edit this in the Godot editor to visually adjust
## label positions, font sizes, and colors at the card's full texture resolution.
var _face_layout_scene: PackedScene = preload("res://scenes/card/card_face_layout.tscn")

# =============================================================================
# State
# =============================================================================

## The CardData resource backing this card instance.
var card_data: CardData

## Current interaction state — driven by the Hand, read by layout and visuals.
var state: CardTypes.CardState = CardTypes.CardState.IDLE

## Reference to the Sprite2D child that displays the card art.
@onready var card_image: Sprite2D = $CardImage

## Valid state transitions. Keys are the current state, values are the set of
## states that can be transitioned to from that state.
const _TRANSITIONS: Dictionary = {
	CardTypes.CardState.IDLE: [
		CardTypes.CardState.HOVERED,
		CardTypes.CardState.DISABLED,
		CardTypes.CardState.PREVIEWING,
	],
	CardTypes.CardState.HOVERED: [
		CardTypes.CardState.IDLE,
		CardTypes.CardState.SELECTED,
		CardTypes.CardState.DISABLED,
	],
	CardTypes.CardState.SELECTED: [
		CardTypes.CardState.IDLE,
		CardTypes.CardState.PLAYED,
	],
	CardTypes.CardState.PLAYED: [],
	CardTypes.CardState.DISABLED: [
		CardTypes.CardState.IDLE,
	],
	CardTypes.CardState.PREVIEWING: [
		CardTypes.CardState.IDLE,
		CardTypes.CardState.PLAYED,
	],
}


func _ready() -> void:
	# Create a unique ShaderMaterial for this card so each card's hovering param is independent
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	# Give each card a unique random seed so idle wobble animations don't sync up
	mat.set_shader_parameter("rand_seed", randf() * 1000.0)
	card_image.material = mat
	# Register this card's signals with the Hand
	get_parent().connect_card_signals(self)


# =============================================================================
# State Machine
# =============================================================================

## Attempt a state transition. Returns true if the transition was valid.
func set_state(new_state: CardTypes.CardState) -> bool:
	if new_state == state:
		return true
	var allowed: Array = _TRANSITIONS.get(state, [])
	if new_state not in allowed:
		push_warning("Card '%s': invalid transition %s -> %s" % [
			card_data.card_name if card_data else "??",
			CardTypes.CardState.keys()[state],
			CardTypes.CardState.keys()[new_state],
		])
		return false
	var old_state: CardTypes.CardState = state
	state = new_state
	_apply_state_visuals()
	state_changed.emit(self, old_state, new_state)
	return true


## Update shader and modulate based on current state.
func _apply_state_visuals() -> void:
	match state:
		CardTypes.CardState.IDLE:
			set_hover_shader(false)
			modulate.a = 1.0
		CardTypes.CardState.HOVERED:
			set_hover_shader(true)
			modulate.a = 1.0
		CardTypes.CardState.SELECTED:
			set_hover_shader(true)
			modulate.a = 1.0
		CardTypes.CardState.DISABLED:
			set_hover_shader(false)
			modulate.a = 0.5
		CardTypes.CardState.PREVIEWING:
			set_hover_shader(false)
			modulate.a = 1.0


## Enable or disable the shader's hover-reactive tilt effect.
func set_hover_shader(enabled: bool) -> void:
	var mat: ShaderMaterial = card_image.material
	if mat:
		mat.set_shader_parameter("hovering", 1.0 if enabled else 0.0)


# =============================================================================
# SubViewport Bake
# =============================================================================

## Populate the card from data and bake text into the sprite texture.
## Called via call_deferred after the card is in the scene tree.
func setup(data: CardData) -> void:
	card_data = data
	_bake_card_texture(data)


## Re-bake the card texture (e.g. after a buff changes ATK).
func rebake() -> void:
	if card_data:
		_bake_card_texture(card_data)


## Override in subclasses to provide a different card face layout scene per type.
func _get_face_layout() -> PackedScene:
	return _face_layout_scene


## Override in subclasses to provide a different card template texture per type.
func _get_template_texture() -> Texture2D:
	return card_image.texture


## Render the card face layout into a SubViewport, capture as ImageTexture,
## and assign to CardImage. The layout scene is edited visually in the Godot
## editor at the card template's native resolution (e.g. 1342x1846), then the
## sprite's existing scale (e.g. 0.22) shrinks it to the correct on-screen size.
func _bake_card_texture(data: CardData) -> void:
	var template_tex: Texture2D = _get_template_texture()
	if template_tex == null:
		push_warning("Card '%s': no template texture for bake" % data.card_name)
		return
	var tex_size: Vector2i = template_tex.get_size()

	# -- Create the offscreen viewport --
	var viewport := SubViewport.new()
	viewport.size = tex_size
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.gui_disable_input = true

	# -- Instance the face layout scene --
	var layout: Control = _get_face_layout().instantiate()
	viewport.add_child(layout)

	# -- Populate labels from card data --
	_populate_layout(layout, data)

	# -- Render and capture --
	add_child(viewport)
	await RenderingServer.frame_post_draw

	var img: Image = viewport.get_texture().get_image()
	var baked_tex: ImageTexture = ImageTexture.create_from_image(img)
	card_image.texture = baked_tex

	viewport.queue_free()


## Fill the layout scene's labels with data from a CardData resource.
## Override in subclasses to populate type-specific labels.
func _populate_layout(layout: Control, data: CardData) -> void:
	var name_label: Label = layout.get_node_or_null("NameLabel")
	var cost_label: Label = layout.get_node_or_null("CostLabel")
	var desc_label: Label = layout.get_node_or_null("DescriptionLabel")

	if name_label:
		name_label.text = data.card_name
	if cost_label:
		cost_label.text = str(data.cost_value)
	if desc_label:
		desc_label.text = data.flavor

	# Hide stat labels by default — creature subclass shows them.
	var atk_label: Label = layout.get_node_or_null("AtkLabel")
	var hp_label: Label = layout.get_node_or_null("HpLabel")
	if atk_label:
		atk_label.visible = false
	if hp_label:
		hp_label.visible = false


# =============================================================================
# Play System (virtual — subclasses override for type-specific behavior)
# =============================================================================
# Context dictionary keys:
#   "player":       Player — the owning player
#   "board":        HexGrid — the game board
#   "target_hexes": Array[Vector2i] — selected hex target(s)
#   "target_units": Array — selected unit target(s)

## Whether this card can be played given the current context.
## Base implementation validates mana cost. Subclasses call super and add checks.
func can_play(context: Dictionary) -> bool:
	if card_data == null:
		return false
	var player: Player = context.get("player")
	if player == null:
		return false
	if card_data.cost_type == CardTypes.CostType.MANA:
		if not player.can_afford(card_data.cost_value):
			return false
	return true


## Execute the card's play logic. Called after can_play() succeeds.
## Base implementation spends mana and resolves effects.
func play(context: Dictionary) -> void:
	var player: Player = context.get("player")
	if player and card_data.cost_type == CardTypes.CostType.MANA:
		player.spend_mana(card_data.cost_value)
	resolve_effects(context)


## Resolve ALL effects on this card. Every card type can carry effects.
func resolve_effects(context: Dictionary) -> void:
	for effect: Dictionary in card_data.effects:
		_apply_effect(effect, context)


## Apply a single effect dictionary. Override for custom dispatch.
func _apply_effect(_effect: Dictionary, _context: Dictionary) -> void:
	# TODO: Dispatch to the effect system based on effect["type"].
	pass


## Return valid target hexes/units for this card given the board.
## Override per card type. Returns Array[Vector2i] for hex targets.
func get_valid_targets(_board: HexGrid) -> Array[Vector2i]:
	return []


## Whether this card requires the player to select targets before playing.
func needs_targeting() -> bool:
	return false


# =============================================================================
# Area2D signals (kept for compatibility — hover handled by Hand polling)
# =============================================================================

func _on_area_2d_mouse_entered() -> void:
	card_event.emit(self, CardTypes.CardEvent.HOVER_ON)


func _on_area_2d_mouse_exited() -> void:
	card_event.emit(self, CardTypes.CardEvent.HOVER_OFF)
