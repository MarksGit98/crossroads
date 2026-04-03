## Viking class creature — extends base Creature with Viking-specific hooks.
## Individual Viking creature scenes (archer, knight, etc.) use this script
## or extend it further for unique visual behavior.
##
## Class-specific logic (Viking rage mechanic, berserker frenzy, etc.)
## will be added here as the class identity develops. For now this serves
## as the organizational layer between creature.gd and per-unit scenes.
class_name VikingCreature
extends Creature


# =============================================================================
# Viking Class Hooks (expand as design evolves)
# =============================================================================

## Viking creatures could gain bonus ATK when below 50% HP (berserker rage).
## This is a placeholder — actual implementation depends on design decisions.
# func _check_viking_rage() -> void:
#     if float(current_hp) / float(max_hp) < 0.5:
#         ...


## Override initialize to add Viking-specific setup after base init.
func initialize(data: CardData, hex: Vector2i, hex_size: float) -> void:
	super.initialize(data, hex, hex_size)
	# Future: apply Viking-specific passive buffs, visual effects, etc.
