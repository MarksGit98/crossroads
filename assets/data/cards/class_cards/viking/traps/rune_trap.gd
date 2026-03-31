## Rune Trap — Viking trap card.
static func data() -> CardData:
	var card := CardData.new()

	# Identity
	card.id = "viking_rune_trap"
	card.card_name = "Rune Trap"
	card.card_type = CardTypes.CardType.TRAP
	card.card_class = CardTypes.Class.VIKING
	card.rarity = CardTypes.Rarity.UNCOMMON
	card.flavor = "The runes glow faintly, waiting."

	# Cost
	card.cost_type = CardTypes.CostType.MANA
	card.cost_value = 2

	# Trap targeting — placed on an empty hex
	card.target_rule = CardTypes.TargetRule.EMPTY_HEX
	card.spell_range = 2

	# Effects — stun the triggering enemy
	card.effects = [
		{
			"type": CardTypes.EffectType.STUN,
			"target": CardTypes.EffectTarget.SELECTED,
			"trigger": CardTypes.TriggerType.ON_TERRAIN_ENTER,
			"duration": CardTypes.Duration.N_TURNS,
			"duration_turns": 1,
		},
		{
			"type": CardTypes.EffectType.DEAL_DAMAGE,
			"target": CardTypes.EffectTarget.SELECTED,
			"value": 2,
			"damage_type": CardTypes.DamageType.MAGICAL,
		},
	]

	return card
