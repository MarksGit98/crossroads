## Data resource for enemy creatures.
## Enemies are not summoned through cards — they spawn at battle start
## or are summoned by elite enemies / towers during combat.
class_name EnemyData
extends Resource

# --- Identity ---

@export var id: String
@export var display_name: String
@export var is_elite: bool = false

# --- Stats ---

@export var atk: int = 1
@export var hp: int = 3
@export var armor: int = 0
@export var move_range: int = 1
@export var move_pattern: CardTypes.MovePattern = CardTypes.MovePattern.STANDARD
@export var attack_range: int = 1
@export var attack_pattern: CardTypes.AttackPattern = CardTypes.AttackPattern.MELEE
@export var damage_type: CardTypes.DamageType = CardTypes.DamageType.PHYSICAL

# --- Role & Keywords ---

@export var role: CardTypes.CreatureRole = CardTypes.CreatureRole.STRIKER
@export var keywords: Array[CardTypes.Keyword] = []

# --- Abilities ---

@export var passives: Array[Dictionary] = []
@export var actives: Array[Dictionary] = []

## Heavy / special attack — a single high-impact ability with a cooldown that
## reuses the standard effect dispatcher. Empty Dictionary means this creature
## has no heavy attack (most regular enemies).
##
## Schema:
##   "id":                   String  — stable identifier (e.g. "werebear_savage_maul")
##   "name":                 String  — player-facing display name
##   "description":          String  — tooltip text
##   "animation":            StringName — defaults to &"heavy_attack"
##   "animation_sequence":   Array  — optional [start, loop, end] for multi-phase
##   "cooldown":             int    — turns between uses (fallback: HEAVY_ATTACK_COOLDOWN = 3)
##   "range":                int    — hex range from caster
##   "target_rule":          CardTypes.TargetRule
##   "max_targets":          int    — -1 = unlimited (AoE); N caps multi-target
##   "effects":              Array[Dictionary] — uses Card._apply_effect schema
##   "self_effects":         Array[Dictionary] — applied to the caster on cast
##   "telegraph_turns":      int    — 0 = instant; N = broadcast intent N turns ahead
@export var heavy_attack: Dictionary = {}

# --- Spawning ---

## Whether this enemy can spawn additional enemies during combat.
@export var can_spawn_enemies: bool = false

## Scene path for the enemy's visual representation.
@export var creature_scene_path: String = ""

## Whether the source sprite frames face left by default. Most enemy sprites
## face right and get flipped at init so they face the player (who sits on
## the left). Set true for creatures whose source art already faces left
## (e.g. Minotaur) so we DON'T flip and end up pointing away from the player.
@export var sprite_faces_left: bool = false
