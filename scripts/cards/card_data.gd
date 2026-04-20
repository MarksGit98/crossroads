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
## Path to the creature's .tscn scene (e.g. "res://scenes/creatures/viking/soldier.tscn").
## Used by CreatureCard._spawn_creature() to instantiate the correct creature.
@export var creature_scene_path: String = ""
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

## Legacy range field. Convention: spells and equipment IGNORE this — they
## can target any hex on the board subject to card-text conditions (which
## live separately in play_conditions / effect validators). Only creature
## actives enforce a range, via the "range" field in each active's dict.
## Kept exported for back-compat with data files that set it.
@export var spell_range: int
@export var aoe_radius: int

## How many distinct hexes the player must select before the card resolves.
## Default 1 (single-target). Values >= 2 force multi-target targeting:
## the Hand keeps the player in targeting mode until N valid hexes have
## been clicked; the Nth click commits the play. Duplicate clicks on the
## same hex are ignored. Use AoE for "one click hits many" — target_count
## is specifically for "pick N different hexes" (e.g. "deal 2 damage to
## any 3 enemies").
@export var target_count: int = 1

# --- Keywords ---
@export var keywords: Array[CardTypes.Keyword] = []

# --- Upgrade state ---
##
## Whether this card has been upgraded during the current run. Cards start
## un-upgraded at boot; upgrading is triggered by shop purchases, card
## rewards, in-duel effects that target the card, etc. When true, creatures
## spawned from this card use the "upgraded" variant of each active/passive
## (see resolve_variant below), and other systems (card art tinting, card
## description text, shop "already upgraded" filters) can branch on this flag.
##
## CardDatabase caches one CardData per card_id and all deck references
## point at that shared instance, so setting this flag during a run applies
## to every copy of the card in the player's deck for the rest of the run.
@export var is_upgraded: bool = false

# --- Passives ---
##
## Each entry is either:
##   A) Variant-grouped (preferred for cards that support upgrades):
##        { "regular":  { ...full passive dict... },
##          "upgraded": { ...full passive dict... } }
##      Leave "upgraded" out if the passive doesn't change when upgraded.
##
##   B) Flat (legacy / no-upgrade cards): the dict IS the passive directly.
##
## Callers go through CardData.resolve_variants() (or Creature.get_passives())
## to materialize the correct set based on the creature's upgraded state.
@export var passives: Array[Dictionary] = []

# --- Actives ---
##
## Same variant-grouped schema as passives. Each entry is either
## { "regular": {...}, "upgraded": {...} } OR a flat active dict.
@export var actives: Array[Dictionary] = []

# --- Spell effects (top-level for spell cards) ---
@export var effects: Array[Dictionary] = []

# --- Equipment modifiers (only meaningful on EQUIPMENT cards) ---
##
## What the equip DOES to the creature it attaches to. Parsed by
## EquipCard._apply_modifiers() on attach (direction = BUFF) and detach
## (direction = DEBUFF, values flipped).
##
## Each entry is either:
##   A) Variant-grouped — { "regular": {...}, "upgraded": {...} } — so an
##      upgraded equip can specify bigger / different bonuses.
##   B) Flat — the dict IS the modifier directly.
##
## Modifier schema (every entry is one of these shapes):
##
##   Stat bonus — additive delta applied while equipped:
##     { "type": CardTypes.EquipModifierType.MODIFY_STAT,
##       "stat": CardTypes.Stat.ATK / HP / ARMOR / MOVE_RANGE / ATTACK_RANGE,
##       "value": int }
##
##   Status applied on equip, removed on unequip:
##     { "type": CardTypes.EquipModifierType.APPLY_STATUS,
##       "status": CardTypes.StatusEffect.HASTED / SHIELDED / ...,
##       "duration": int (optional; -1 = permanent while equipped, default -1) }
##
##   Status cleansed on equip (one-shot, not re-applied on unequip):
##     { "type": CardTypes.EquipModifierType.REMOVE_STATUS,
##       "status": CardTypes.StatusEffect.CHILLED / STUNNED / ... }
##
## Positive values for stat modifiers = buffs; negative = debuffs. Equipment
## can mix both in a single card (e.g. "+3 ATK, -1 MOVE_RANGE" for a heavy
## weapon that slows the wielder).
@export var equip_modifiers: Array[Dictionary] = []

# --- Equipment rules (only meaningful on EQUIPMENT cards) ---
##
## Optional restrictions on which creatures this equip card is allowed to
## attach to. Left empty = the default "valid for all friendly creatures".
##
## Schema (all fields optional — present-and-nonempty means "enforce"):
##   "allowed_classes":    Array[CardTypes.Class]        — creature's card_class must be one of these
##   "allowed_roles":      Array[CardTypes.CreatureRole] — creature's role must be one of these
##   "required_keywords":  Array[CardTypes.Keyword]      — creature must have EVERY listed keyword
##   "forbidden_keywords": Array[CardTypes.Keyword]      — creature must have NONE of these keywords
##   "min_atk":            int                           — creature's base ATK at least N
##   "max_atk":            int                           — creature's base ATK at most N
##
## Example (a sword that only Viking strikers can wield):
##   card.equip_rules = {
##       "allowed_classes": [CardTypes.Class.VIKING],
##       "allowed_roles":   [CardTypes.CreatureRole.STRIKER],
##   }
##
## Example (armor not wearable by ethereal units):
##   card.equip_rules = {
##       "forbidden_keywords": [CardTypes.Keyword.ETHEREAL],
##   }
@export var equip_rules: Dictionary = {}


# =============================================================================
# Variant resolution
# =============================================================================

## Pick the correct variant of a single active/passive entry.
##  - If entry has "regular"/"upgraded" keys, pick based on `upgraded`.
##  - If only one of the two is defined, prefer the defined one.
##  - If entry is in the flat (legacy) format, return it unchanged.
static func resolve_variant(entry: Dictionary, upgraded: bool) -> Dictionary:
	var has_regular: bool = entry.has("regular")
	var has_upgraded: bool = entry.has("upgraded")
	if not has_regular and not has_upgraded:
		# Legacy flat dict — already the ability itself.
		return entry
	if upgraded and has_upgraded:
		return entry["upgraded"]
	if has_regular:
		return entry["regular"]
	# upgraded=false but only upgraded was defined — fall back.
	return entry["upgraded"]


## Apply resolve_variant() across a whole list. Always safe to call on any
## actives/passives array regardless of whether it uses the variant or flat
## format — flat entries pass through unchanged.
static func resolve_variants(entries: Array, upgraded: bool) -> Array:
	var result: Array = []
	for entry: Dictionary in entries:
		result.append(resolve_variant(entry, upgraded))
	return result
