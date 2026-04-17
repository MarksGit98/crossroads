## Iron Helm — Viking defensive equipment card.
## Grants +3 armor to the equipped creature.
static func data() -> CardData:
	var card := CardData.new()

	# Identity
	card.id = "viking_iron_helm"
	card.card_name = "Iron Helm"
	card.card_type = CardTypes.CardType.EQUIPMENT
	card.card_class = CardTypes.Class.VIKING
	card.rarity = CardTypes.Rarity.COMMON
	card.flavor = "Dented, bloodied, and still holding."

	# Cost
	card.cost_type = CardTypes.CostType.MANA
	card.cost_value = 1

	# Equipment targeting — attach to a friendly unit
	card.target_rule = CardTypes.TargetRule.ANY_ALLY
	card.spell_range = 1

	# Passives — +3 armor while equipped
	card.passives = [
		{
			"id": "iron_defense",
			"name": "Iron Defense",
			"type": CardTypes.PassiveType.STAT_AURA,
			"stat": CardTypes.Stat.ARMOR,
			"value": 3,
		},
	]

	return card
