## Displays the player's current mana as a number overlaid on a crystal sprite.
## Listens to Player.mana_changed to update automatically.
class_name ManaDisplay
extends Node2D

## Reference to the Player node — set via @onready path or assigned externally.
var player: Player = null

@onready var crystal_sprite: Sprite2D = $CrystalSprite
@onready var mana_label: Label = $ManaLabel


## Margin from the bottom-left corner of the viewport.
const MARGIN_LEFT: float = 60.0
const MARGIN_BOTTOM: float = 70.0


func _ready() -> void:
	# Anchor to bottom-left corner regardless of viewport size.
	_anchor_to_corner()
	get_viewport().size_changed.connect(_anchor_to_corner)
	_update_label(0, 0)


## Position at bottom-left corner of the viewport.
func _anchor_to_corner() -> void:
	var screen: Vector2 = get_viewport_rect().size
	position = Vector2(MARGIN_LEFT, screen.y - MARGIN_BOTTOM)


## Connect to a Player node and listen for mana changes.
func set_player(p: Player) -> void:
	# Disconnect from old player if any.
	if player and player.mana_changed.is_connected(_on_mana_changed):
		player.mana_changed.disconnect(_on_mana_changed)
	player = p
	player.mana_changed.connect(_on_mana_changed)
	# Sync to current values immediately.
	_update_label(player.current_mana, player.max_mana)


func _on_mana_changed(current: int, max_mana: int) -> void:
	_update_label(current, max_mana)


func _update_label(current: int, _max_mana: int) -> void:
	if mana_label:
		mana_label.text = str(current)
