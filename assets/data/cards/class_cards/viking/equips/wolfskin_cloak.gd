## Wolfskin Cloak — Viking equipment card.
static func data() -> CardData:
	var card := CardData.new()

	# Identity
	card.id = "viking_wolfskin_cloak"
	card.card_name = "Wolfskin Cloak"
	card.card_type = CardTypes.CardType.EQUIPMENT
	card.card_class = CardTypes.Class.VIKING
	card.rarity = CardTypes.Rarity.COMMON
	card.flavor = "Worn by scouts who walk between worlds."

	# Cost
	card.cost_type = CardTypes.CostType.MANA
	card.cost_value = 1

	# Equipment targeting — attach to a friendly unit
	card.target_rule = CardTypes.TargetRule.ANY_ALLY
	card.spell_range = 1

	# Keywords granted to equipped unit
	card.keywords = [CardTypes.Keyword.SCOUT]

	# Passives — +2 armor while equipped
	card.passives = [
		{
			"id": "wolfskin_defense",
			"name": "Wolfskin Defense",
			"type": CardTypes.PassiveType.MODIFY_STATS,
			"effects": [
				{
					"type": CardTypes.EffectType.MODIFY_STAT,
					"target": CardTypes.EffectTarget.SELECTED,
					"stat": CardTypes.Stat.ARMOR,
					"value": 2,
					"duration": CardTypes.Duration.WHILE_ALIVE,
				},
			],
		},
	]

	return card
