## Canonical type constants for all card data.
## Card .gd files import this class and reference enums directly.
class_name CardTypes
extends RefCounted


# --- Core Card Enums ---

enum CardType { CREATURE, SPELL, TRAP, EQUIPMENT, TERRAIN_MOD }

enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

enum Class { VIKING, ENEMY, NEUTRAL }

enum CreatureRole { TANK, STRIKER, SUPPORT, CONTROLLER, ASSASSIN, ARTILLERY }

enum Stat { ATK, HP, MAX_HP, MOVE_RANGE, ATTACK_RANGE, ARMOR, SPELL_POWER }

enum DamageType { PHYSICAL, MAGICAL, FIRE, ICE, LIGHTNING, POISON, TRUE }

enum CostType { MANA, HEALTH, SACRIFICE, DISCARD, EXHAUST }

enum CardState { IDLE, HOVERED, SELECTED, PLAYED, DISABLED, PREVIEWING }

enum CardEvent { HOVER_ON, HOVER_OFF, SELECT, DESELECT, PLAY, DISCARD }


# --- Movement ---

enum MovePattern {
	STANDARD,        ## Move up to move_range hexes along any path of adjacent tiles.
	ORTHOGONAL_ONLY, ## Move only along straight hex axes (no diagonal movement).
	DIAGONAL_ONLY,   ## Move only along diagonal hex axes (skips direct neighbors).
	LEAP,            ## Jump directly to destination, ignoring intervening tiles and units.
	TELEPORT,        ## Instantly move to any valid hex within range, ignoring all obstacles and LOS.
	CHARGE,          ## Move in a straight line only; must move the full distance if unblocked.
	BURROW,          ## Move through impassable terrain (except walls); emerge at destination.
	SWIM,            ## Can move through river/water tiles that are normally impassable.
	FLY,             ## Ignore terrain passability; still blocked by units on destination hex.
	PUSH_THROUGH,    ## Can move through hexes occupied by enemies, pushing them aside.
	FIXED,           ## Cannot move after being placed.
}


# --- Attack Patterns ---

enum AttackPattern {
	SINGLE_TARGET,   ## Hit one unit at the targeted hex.
	MELEE,           ## Hit one adjacent unit (attack_range 1 implied).
	LINE,            ## Hit all units in a straight line through target hex, up to attack_range.
	CONE,            ## Hit all units in a 60-degree cone (3 hexes wide at range 2).
	WIDE_CONE,       ## Hit all units in a 120-degree cone.
	RING,            ## Hit all hexes exactly N distance from a target hex (donut shape).
	AOE_RADIUS,      ## Hit all hexes within N distance of target hex (filled circle).
	CROSS,           ## Hit the target hex plus all 6 adjacent hexes.
	ARC,             ## Lobbed attack that ignores intervening units; hits target hex only.
	CHAIN,           ## Hit target, then bounce to nearest valid target up to chain_count times.
	CLEAVE,          ## Hit the target hex and both hexes adjacent to it on the attacker's side.
	NOVA,            ## Hit all hexes adjacent to the attacker (self-centered AoE).
	GLOBAL,          ## Hit all valid targets on the board regardless of range or LOS.
}


# --- Targeting ---

enum TargetRule {
	ANY_ENEMY,       ## Any enemy unit within range.
	ANY_ALLY,        ## Any friendly unit within range.
	ANY_UNIT,        ## Any unit regardless of allegiance.
	SELF,            ## The casting/owning unit only.
	EMPTY_HEX,       ## An unoccupied hex.
	ANY_HEX,         ## Any hex, occupied or not.
	SELECT_DIRECTION,## Player chooses one of the 6 hex directions; effect fires along that line.
	ADJACENT_ENEMY,  ## An enemy unit adjacent to the caster.
	ADJACENT_ALLY,   ## A friendly unit adjacent to the caster.
	RANDOM_ENEMY,    ## A randomly selected enemy unit within range.
	RANDOM_ALLY,     ## A randomly selected friendly unit within range.
	ALL_ENEMIES,     ## All enemy units (no selection needed).
	ALL_ALLIES,      ## All friendly units (no selection needed).
	ALL_UNITS,       ## All units on the board.
	HERO,            ## The player's hero unit only.
	NON_HERO,        ## Any unit that is not a hero.
}

enum EffectTarget {
	SELECTED,            ## The player-selected target.
	CASTER,              ## The unit using the ability.
	FIRST_HIT,           ## The first unit hit along a line or direction.
	ALL_IN_AREA,         ## All units within the attack_pattern area.
	ALL_ENEMIES_IN_AREA, ## All enemy units within the attack_pattern area.
	ALL_ALLIES_IN_AREA,  ## All allied units within the attack_pattern area.
	CENTER_HEX,          ## The center hex of an AoE.
	RANDOM_IN_AREA,      ## A random unit within the attack_pattern area.
}


# --- Keywords ---

enum Keyword {
	GUARD,           ## Adjacent allies cannot be targeted by ranged attacks while this unit lives.
	FLYING,          ## Ignores terrain passability when moving; can be targeted by anti-air.
	STEALTH,         ## Cannot be targeted until this unit attacks or takes damage.
	TAUNT,           ## Adjacent enemies must attack this unit if they attack.
	PIERCE,          ## Attacks ignore armor.
	LIFESTEAL,       ## Attacker heals for damage dealt.
	RANGED,          ## Can attack without being adjacent; does not trigger melee retaliation.
	REACH,           ## Melee attacks can hit targets 2 hexes away in a straight line.
	SWIFT,           ## Can move and attack on the turn it is summoned.
	ROOTED,          ## Cannot move but can still attack.
	EPHEMERAL,       ## Destroyed at end of owner's turn.
	UNDYING,         ## The first time this unit would die each combat, survive with 1 HP.
	AURA,            ## Has a passive effect that applies to adjacent allies.
	WARD,            ## Cannot be targeted by spells.
	AMBUSH,          ## Deals double damage when attacking from stealth.
	VIGILANT,        ## Retaliates against all adjacent attackers, not just the first.
	REGENERATE,      ## Heals 1 HP at the start of each turn.
	FRENZY,          ## Gains +1 ATK each time this unit kills an enemy.
	BULWARK,         ## Takes 1 less damage from all sources (minimum 1).
	DEATH_RATTLE,    ## Triggers an effect when this unit dies.
	BATTLE_CRY,      ## Triggers an effect when this unit is summoned.
	OVERWATCH,       ## Automatically attacks the first enemy that moves into range.
	SIEGE,           ## Deals double damage to structures and terrain objects.
	ETHEREAL,        ## Can move through enemy units but cannot stop on occupied hexes.
	FROZEN_HEART,    ## Immune to freeze and ice effects.
	FLAME_CLOAK,     ## Immune to burn; deals 1 fire damage to melee attackers.
	HEAVY,           ## Cannot be pushed, pulled, or displaced.
	SCOUT,           ## Reveals fog tiles within move_range at start of turn.
}


# --- Status Effects ---

enum StatusEffect {
	BURNING,         ## Takes fire damage at start of each turn. Stacks intensity.
	FROZEN,          ## Cannot move for 1 turn. Taking fire damage removes this.
	CHILLED,         ## Move range reduced by 1. Stacks with multiple applications.
	POISONED,        ## Takes poison damage at end of each turn. Stacks intensity.
	BLEEDING,        ## Takes physical damage when moving. Stacks intensity.
	STUNNED,         ## Skips next turn entirely. Cannot stack.
	SILENCED,        ## Cannot use active abilities for duration. Can still attack.
	SHIELDED,        ## Absorbs next N damage, then expires. Does not stack, refreshes.
	INSPIRED,        ## +1 ATK for duration.
	WEAKENED,        ## -1 ATK for duration (minimum 0).
	ARMORED,         ## +1 armor for duration.
	VULNERABLE,      ## -1 armor for duration (can go negative).
	HASTED,          ## +1 move range for duration.
	SLOWED,          ## -1 move range for duration (minimum 0).
	MARKED,          ## Next attack against this unit deals +2 bonus damage, then expires.
	INVISIBLE,       ## Cannot be targeted. Broken by attacking or taking damage.
	TETHERED,        ## Linked to source unit; takes damage when source takes damage.
	CURSED,          ## Healing received is halved.
	BLESSED,         ## Healing received is doubled.
	ENRAGED,         ## +2 ATK but cannot be directly controlled (attacks nearest enemy).
	FORTIFIED,       ## Cannot be moved by push/pull effects.
	DOOMED,          ## Dies at end of next turn unless cleansed.
	PHASED,          ## Cannot attack or be attacked for 1 turn. Can still move.
	REGENERATING,    ## Heals HP at start of each turn for duration.
	THORNS,          ## Deals damage back to melee attackers for duration.
}


# --- Triggers ---

enum TriggerType {
	ON_SUMMON,        ## When this unit is placed on the board.
	ON_DEATH,         ## When this unit is destroyed.
	ON_ATTACK,        ## When this unit declares an attack.
	ON_HIT,           ## When this unit's attack deals damage.
	ON_KILL,          ## When this unit's attack destroys a target.
	ON_DAMAGED,       ## When this unit takes damage from any source.
	ON_HEALED,        ## When this unit is healed.
	ON_MOVE,          ## When this unit moves (per hex entered).
	ON_MOVE_COMPLETE, ## When this unit finishes its movement.
	ON_SPELL_RESOLVE, ## When a spell finishes resolving (for reaction passives).
	START_OF_TURN,    ## At the start of the owning player's turn.
	END_OF_TURN,      ## At the end of the owning player's turn.
	ON_ALLY_SUMMON,   ## When another friendly unit is summoned.
	ON_ALLY_DEATH,    ## When another friendly unit dies.
	ON_ENEMY_SUMMON,  ## When an enemy unit is summoned.
	ON_ENEMY_DEATH,   ## When an enemy unit dies.
	ON_SPELL_CAST,    ## When the owner plays a spell card.
	ON_CARD_DRAWN,    ## When the owner draws a card.
	ON_DISCARD,       ## When this card is discarded from hand.
	ON_TERRAIN_ENTER, ## When this unit enters a specific terrain type.
	ON_ADJACENT,      ## When a unit moves to a hex adjacent to this unit.
	ON_STATUS_GAIN,   ## When this unit gains a status effect.
	ON_STATUS_LOSE,   ## When a status effect expires or is cleansed from this unit.
}


# --- Effect Types ---

enum EffectType {
	DEAL_DAMAGE,     ## Deal N damage of a specified damage_type to target.
	HEAL,            ## Restore N HP to target (cannot exceed max_hp).
	MODIFY_STAT,     ## Change a stat by +/- N for a duration or permanently.
	APPLY_STATUS,    ## Apply a status_effect to target for N turns.
	REMOVE_STATUS,   ## Remove a specific status_effect from target.
	CLEANSE,         ## Remove all negative status effects from target.
	PURGE,           ## Remove all positive status effects from target.
	PUSH,            ## Move target N hexes away from source.
	PULL,            ## Move target N hexes toward source.
	TELEPORT_TARGET, ## Move target to a specified hex.
	SWAP_POSITIONS,  ## Swap positions of two units.
	SUMMON,          ## Place a new unit on a target hex.
	DESTROY,         ## Immediately destroy target unit (ignores HP).
	TRANSFORM,       ## Replace target unit with a different unit.
	DRAW_CARD,       ## Owner draws N cards.
	DISCARD_CARD,    ## Owner discards N cards (random or chosen).
	GAIN_MANA,       ## Owner gains N mana/energy this turn.
	DRAIN_MANA,      ## Target owner loses N mana/energy.
	CREATE_TERRAIN,  ## Change target hex's terrain type.
	COPY_UNIT,       ## Create a copy of target unit on an adjacent hex.
	STEAL_STAT,      ## Reduce target's stat by N, increase self's stat by N.
	BOUNCE,          ## Return target unit to its owner's hand as a card.
	SILENCE,         ## Apply silenced status — shorthand for apply_status:silenced.
	STUN,            ## Apply stunned status — shorthand for apply_status:stunned.
	SHIELD,          ## Apply shielded with N absorption.
	EXECUTE,         ## Destroy target if its HP is below N% of max_hp.
	MARK_SPAWN,      ## Mark the target hex as a valid spawn location.
}


# --- Passive Types ---

enum PassiveType {
	STAT_AURA,        ## Modifies stats of nearby units continuously.
	DAMAGE_AURA,      ## Deals damage to nearby enemies each turn.
	HEAL_AURA,        ## Heals nearby allies each turn.
	MODIFY_STATS,     ## Modifies values of resolving effects (e.g., buff spell values).
	ON_TRIGGER,       ## Executes an effect when a trigger_type fires.
	CONDITIONAL_BUFF, ## Grants a buff when a condition is met (e.g., below 50% HP).
	DAMAGE_MODIFIER,  ## Modifies incoming or outgoing damage by a formula.
	IMMUNITY,         ## Prevents specific status_effects or damage_types.
	COST_REDUCTION,   ## Reduces the cost of cards played by owner.
	TERRAIN_AFFINITY, ## Gains bonuses when standing on specific terrain types.
}


# --- Conditions ---

enum Condition {
	HP_BELOW_PCT,    ## Unit's HP is below N% of max_hp.
	HP_ABOVE_PCT,    ## Unit's HP is above N% of max_hp.
	HP_FULL,         ## Unit is at max HP.
	IS_ADJACENT_TO,  ## Unit is adjacent to a unit matching a filter.
	HAS_STATUS,      ## Unit has a specific status_effect.
	LACKS_STATUS,    ## Unit does not have a specific status_effect.
	ON_TERRAIN,      ## Unit is standing on a specific terrain type.
	ALLY_COUNT_GTE,  ## Number of friendly units on board >= N.
	ALLY_COUNT_LTE,  ## Number of friendly units on board <= N.
	ENEMY_COUNT_GTE, ## Number of enemy units on board >= N.
	ENEMY_COUNT_LTE, ## Number of enemy units on board <= N.
	HAND_SIZE_GTE,   ## Owner's hand has >= N cards.
	HAND_SIZE_LTE,   ## Owner's hand has <= N cards.
	TURN_NUMBER_GTE, ## Current turn number >= N.
	HAS_KEYWORD,     ## Unit has a specific keyword.
	IS_ROLE,         ## Unit has a specific creature_role.
	TARGET_IS_TYPE,  ## Target matches a specific card_type.
}


# --- Zones ---

enum Zone {
	FRIENDLY_TERRITORY, ## Hexes in the owner's half of the board.
	ENEMY_TERRITORY,    ## Hexes in the opponent's half of the board.
	CONTESTED,          ## Hexes in the center rows.
	SPAWN_ZONE,         ## Hexes marked as valid spawn points.
	ANY,                ## Any hex on the board.
	ADJACENT_TO_SELF,   ## Hexes adjacent to the casting unit.
	SAME_ROW,           ## Hexes in the same row as a reference point.
	SAME_COLUMN,        ## Hexes in the same column as a reference point.
}


# --- Duration ---

enum Duration {
	INSTANT,           ## Applied and resolved immediately.
	UNTIL_END_OF_TURN, ## Expires at end of current turn.
	N_TURNS,           ## Lasts for N turns (specify integer in effect data).
	PERMANENT,         ## Lasts until explicitly removed.
	WHILE_ALIVE,       ## Active as long as the source unit is alive.
	UNTIL_TRIGGERED,   ## Active until its trigger condition fires once.
}
