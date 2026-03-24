## Top-level game state machine. Controls global game flow.
## Each state loads its scene, initializes subsystems, and yields back when complete.
extends Node

# Game states matching the architecture doc
enum GameState {
	MAIN_MENU,
	CLASS_SELECT,
	BOARD_TRAVEL,
	DUEL,
	CARD_DRAW,
	MERCHANT,
	EVOLUTION,
	GAME_OVER,
	VICTORY,
}

var current_state: GameState = GameState.MAIN_MENU


func _ready() -> void:
	pass
