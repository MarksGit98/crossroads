## Frost Bolt — Viking single-target ice spell.
## Deals ice damage and chills the target, slowing movement.
static func data() -> CardData:
	var card := CardData.new()

	# Identity
	card.id = "viking_frost_bolt"
	card.card_name = "Frost Bolt"
	card.card_type = CardTypes.CardType.SPELL
	card.card_class = CardTypes.Class.VIKING
	card.rarity = CardTypes.Rarity.COMMON
	card.flavor = "Winter's bite finds its mark."

	# Cost
	card.cost_type = CardTypes.CostType.MANA
	card.cost_value = 1

	# Spell targeting — single enemy unit
	card.target_rule = CardTypes.TargetRule.ANY_ENEMY
	card.spell_range = 3
	card.attack_pattern = CardTypes.AttackPattern.SINGLE_TARGET
	card.damage_type = CardTypes.DamageType.ICE

	# Effects — 2 ice damage + apply CHILLED for 2 turns
	card.effects = [
		{
			"type": CardTypes.EffectType.DEAL_DAMAGE,
			"target": CardTypes.EffectTarget.SELECTED,
			"damage_type": CardTypes.DamageType.ICE,
			"value": 2,
		},
		{
			"type": CardTypes.EffectType.APPLY_STATUS,
			"target": CardTypes.EffectTarget.SELECTED,
			"status": CardTypes.StatusEffect.CHILLED,
			"duration": CardTypes.Duration.N_TURNS,
			"duration_turns": 2,
		},
	]

	return card
