## Base resource for all card definitions.
## Card .gd files create and return instances of this resource.
class_name CardData
extends Resource

# --- Identity ---
@export var id: String
@export var card_name: String
@export var card_type: CardTypes.CardType
@export var card_class: CardTypes.Class
@export var rarity: CardTypes.Rarity
@export var flavor: String

# --- Cost ---
@export var cost_type: CardTypes.CostType = CardTypes.CostType.MANA
@export var cost_value: int

# --- Creature Stats (ignored for non-creatures) ---
@export var role: CardTypes.CreatureRole
@export var atk: int
@export var hp: int
@export var armor: int
@export var move_range: int
@export var move_pattern: CardTypes.MovePattern = CardTypes.MovePattern.STANDARD
@export var attack_range: int = 1
@export var attack_pattern: CardTypes.AttackPattern = CardTypes.AttackPattern.SINGLE_TARGET
@export var damage_type: CardTypes.DamageType = CardTypes.DamageType.PHYSICAL

# --- Spell targeting (used by spells, traps, terrain mods) ---
@export var target_rule: CardTypes.TargetRule
@export var spell_range: int
@export var aoe_radius: int

# --- Keywords ---
@export var keywords: Array[CardTypes.Keyword] = []

# --- Passives ---
@export var passives: Array[Dictionary] = []

# --- Actives ---
@export var actives: Array[Dictionary] = []

# --- Spell effects (top-level for spell cards) ---
@export var effects: Array[Dictionary] = []
