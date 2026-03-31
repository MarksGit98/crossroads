## War Horn — Viking buff spell card.
static func data() -> CardData:
	var card := CardData.new()

	# Identity
	card.id = "viking_war_horn"
	card.card_name = "War Horn"
	card.card_type = CardTypes.CardType.SPELL
	card.card_class = CardTypes.Class.VIKING
	card.rarity = CardTypes.Rarity.COMMON
	card.flavor = "The call to battle echoes across the fjord."

	# Cost
	card.cost_type = CardTypes.CostType.MANA
	card.cost_value = 1

	# Spell targeting
	card.target_rule = CardTypes.TargetRule.ALL_ALLIES
	card.spell_range = 0
	card.attack_pattern = CardTypes.AttackPattern.GLOBAL

	# Effects — +2 ATK to all allies until end of turn
	card.effects = [
		{
			"type": CardTypes.EffectType.MODIFY_STAT,
			"target": CardTypes.EffectTarget.ALL_IN_AREA,
			"stat": CardTypes.Stat.ATK,
			"value": 2,
			"duration": CardTypes.Duration.UNTIL_END_OF_TURN,
		},
	]

	return card
