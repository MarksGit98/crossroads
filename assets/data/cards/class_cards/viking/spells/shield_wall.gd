## Shield Wall — Viking defensive buff spell.
## Grants armor to all friendly creatures for the turn.
static func data() -> CardData:
	var card := CardData.new()

	# Identity
	card.id = "viking_shield_wall"
	card.card_name = "Shield Wall"
	card.card_type = CardTypes.CardType.SPELL
	card.card_class = CardTypes.Class.VIKING
	card.rarity = CardTypes.Rarity.UNCOMMON
	card.flavor = "Stand together. Break nothing."

	# Cost
	card.cost_type = CardTypes.CostType.MANA
	card.cost_value = 2

	# Spell targeting — all allies, no selection needed
	card.target_rule = CardTypes.TargetRule.ALL_ALLIES
	card.spell_range = 0
	card.attack_pattern = CardTypes.AttackPattern.GLOBAL

	# Effects — +2 armor to all allies until end of turn
	card.effects = [
		{
			"type": CardTypes.EffectType.MODIFY_STAT,
			"target": CardTypes.EffectTarget.ALL_IN_AREA,
			"stat": CardTypes.Stat.ARMOR,
			"value": 2,
			"duration": CardTypes.Duration.UNTIL_END_OF_TURN,
		},
	]

	return card
