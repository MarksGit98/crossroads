## Defines the available duel game modes and their win/loss conditions.
## Used by the duel scene + AI to know what each side is trying to accomplish.
## Detailed implementation of each mode (objectives, AI behavior, scoring)
## will be built out per-mode later — for now this is the type registry.
class_name GamemodeTypes
extends RefCounted


# =============================================================================
# Mode Identifiers
# =============================================================================

## All supported duel game modes.
enum Mode {
	TEAM_DEATHMATCH,   ## Eliminate all enemy units before your HP hits zero.
	CAPTURE_THE_FLAG,  ## Steal the enemy flag and return it to your base.
	DESTROY_POINT,     ## Destroy the enemy's core structure (tower defense flavor).
	ESCORT_PAYLOAD,    ## Protect a payload moving toward the enemy base.
	DEFEND_PAYLOAD,    ## Stop an enemy payload from reaching your base in N turns.
}

## The default mode used when none is specified (e.g. test scene boot).
const DEFAULT_MODE: Mode = Mode.TEAM_DEATHMATCH


# =============================================================================
# Win / Loss Conditions
# =============================================================================

## Categorical win conditions a mode can satisfy.
## A mode may have one primary win condition; loss is typically the symmetrical
## enemy version, plus the universal "player HP reaches zero" backstop.
enum WinCondition {
	ELIMINATE_ALL_ENEMIES,    ## All enemy units are dead.
	CAPTURE_ENEMY_FLAG,       ## Player carries enemy flag to player base.
	DESTROY_ENEMY_POINT,      ## Enemy objective structure reaches 0 HP.
	DELIVER_PAYLOAD,          ## Player payload reaches the enemy base.
	SURVIVE_N_TURNS,          ## Enemy payload fails to reach player base in time.
}

enum LossCondition {
	PLAYER_HP_ZERO,           ## Player's life total reaches zero.
	ENEMY_CAPTURES_FLAG,      ## Enemy returns the player flag to enemy base.
	PLAYER_POINT_DESTROYED,   ## Player's objective structure reaches 0 HP.
	PAYLOAD_LOST,             ## Player payload is destroyed or stalled out.
	ENEMY_DELIVERS_PAYLOAD,   ## Enemy payload reaches the player base.
	TURN_LIMIT_EXCEEDED,      ## Player failed to complete objective in time.
}


# =============================================================================
# Per-Mode Metadata
# =============================================================================

## Static metadata for each game mode: display name, description, win/loss
## condition sets, and any mode-specific tuning knobs (e.g. turn limits).
## Keys are GamemodeTypes.Mode values.
const MODE_DATA: Dictionary = {
	Mode.TEAM_DEATHMATCH: {
		"name": "Team Deathmatch",
		"description": "Eliminate all enemy units before your HP reaches zero.",
		"win_conditions": [WinCondition.ELIMINATE_ALL_ENEMIES],
		"loss_conditions": [LossCondition.PLAYER_HP_ZERO],
		"turn_limit": 0,  # 0 = unlimited
	},
	Mode.CAPTURE_THE_FLAG: {
		"name": "Capture the Flag",
		"description": "Grab the enemy flag and return it to your base while defending your own.",
		"win_conditions": [WinCondition.CAPTURE_ENEMY_FLAG],
		"loss_conditions": [LossCondition.ENEMY_CAPTURES_FLAG, LossCondition.PLAYER_HP_ZERO],
		"turn_limit": 0,
	},
	Mode.DESTROY_POINT: {
		"name": "Destroy the Point",
		"description": "Tear down the enemy's core structure before they destroy yours.",
		"win_conditions": [WinCondition.DESTROY_ENEMY_POINT],
		"loss_conditions": [LossCondition.PLAYER_POINT_DESTROYED, LossCondition.PLAYER_HP_ZERO],
		"turn_limit": 0,
	},
	Mode.ESCORT_PAYLOAD: {
		"name": "Escort the Payload",
		"description": "Move the payload to the enemy base. Lose if it dies or stalls.",
		"win_conditions": [WinCondition.DELIVER_PAYLOAD],
		"loss_conditions": [LossCondition.PAYLOAD_LOST, LossCondition.PLAYER_HP_ZERO],
		"turn_limit": 15,
	},
	Mode.DEFEND_PAYLOAD: {
		"name": "Defend the Base",
		"description": "Stop the enemy payload from reaching your base in time.",
		"win_conditions": [WinCondition.SURVIVE_N_TURNS],
		"loss_conditions": [LossCondition.ENEMY_DELIVERS_PAYLOAD, LossCondition.PLAYER_HP_ZERO],
		"turn_limit": 12,
	},
}


# =============================================================================
# Lookup helpers
# =============================================================================

## Get the metadata dictionary for a given mode (or empty if unknown).
static func mode_data_for(mode: Mode) -> Dictionary:
	return MODE_DATA.get(mode, {})


## Get the human-readable display name for a mode.
static func mode_name(mode: Mode) -> String:
	return mode_data_for(mode).get("name", "Unknown")


## Get the player-facing description for a mode.
static func mode_description(mode: Mode) -> String:
	return mode_data_for(mode).get("description", "")


## Get the list of win conditions associated with a mode.
static func mode_win_conditions(mode: Mode) -> Array:
	return mode_data_for(mode).get("win_conditions", [])


## Get the list of loss conditions associated with a mode.
static func mode_loss_conditions(mode: Mode) -> Array:
	return mode_data_for(mode).get("loss_conditions", [])


## Get the turn limit for a mode (0 = unlimited).
static func mode_turn_limit(mode: Mode) -> int:
	return mode_data_for(mode).get("turn_limit", 0)
