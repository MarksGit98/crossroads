## Runic Axe — Viking offensive equipment card.
## Grants +2 ATK to the equipped creature.
static func data() -> CardData:
	var card := CardData.new()

	# Identity
	card.id = "viking_runic_axe"
	card.card_name = "Runic Axe"
	card.card_type = CardTypes.CardType.EQUIPMENT
	card.card_class = CardTypes.Class.VIKING
	card.rarity = CardTypes.Rarity.UNCOMMON
	card.flavor = "Each rune carved is a promise of violence."

	# Cost
	card.cost_type = CardTypes.CostType.MANA
	card.cost_value = 2

	# Equipment targeting — attach to a friendly unit
	card.target_rule = CardTypes.TargetRule.ANY_ALLY
	card.spell_range = 1

	# Passives — +2 ATK while equipped
	card.passives = [
		{
			"id": "runic_might",
			"name": "Runic Might",
			"type": CardTypes.PassiveType.STAT_AURA,
			"stat": CardTypes.Stat.ATK,
			"value": 2,
		},
	]

	return card
