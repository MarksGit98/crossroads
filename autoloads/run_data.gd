## Single source of truth for everything that persists across duels in a run.
## Serialized to disk via SaveSystem on every meaningful state change.
extends Node

var player_class: String = ""
var current_hp: int = 20
var max_hp: int = 20
var gold: int = 0
var deck: Array = []
var graveyard: Array = []
var board_position: int = 0
var board_seed: int = 0
var turn_count: int = 0
var completed_bounties: Array[String] = []
var rival_position: int = 0
var evolution_tier: Dictionary = {}  # card_id -> tier (1/2/3)
var unlocked_secret_paths: Array[String] = []
var biome_modifiers: Array[String] = []


func reset_run() -> void:
	player_class = ""
	current_hp = 20
	max_hp = 20
	gold = 0
	deck.clear()
	graveyard.clear()
	board_position = 0
	board_seed = randi()
	turn_count = 0
	completed_bounties.clear()
	rival_position = 0
	evolution_tier.clear()
	unlocked_secret_paths.clear()
	biome_modifiers.clear()
