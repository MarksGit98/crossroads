## Displays the player's current mana as a number overlaid on a crystal sprite.
## Listens to Player.mana_changed to update automatically.
class_name ManaDisplay
extends Node2D

## Reference to the Player node — set via @onready path or assigned externally.
var player: Player = null

@onready var crystal_sprite: Sprite2D = $CrystalSprite
@onready var mana_label: Label = $ManaLabel


func _ready() -> void:
	# Try to find the Player node in the scene tree.
	# The DuelTestScene wires this in _ready() via set_player().
	_update_label(0, 0)


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
