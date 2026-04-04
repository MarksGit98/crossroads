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

# --- Spawning ---

## Whether this enemy can spawn additional enemies during combat.
@export var can_spawn_enemies: bool = false

## Scene path for the enemy's visual representation.
@export var creature_scene_path: String = ""
