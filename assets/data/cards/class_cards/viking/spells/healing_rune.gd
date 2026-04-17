## Healing Rune — Viking targeted heal spell.
## Restores HP to a single friendly creature.
static func data() -> CardData:
	var card := CardData.new()

	# Identity
	card.id = "viking_healing_rune"
	card.card_name = "Healing Rune"
	card.card_type = CardTypes.CardType.SPELL
	card.card_class = CardTypes.Class.VIKING
	card.rarity = CardTypes.Rarity.COMMON
	card.flavor = "The old ways mend what steel has broken."

	# Cost
	card.cost_type = CardTypes.CostType.MANA
	card.cost_value = 2

	# Spell targeting — single friendly unit
	card.target_rule = CardTypes.TargetRule.ANY_ALLY
	card.spell_range = 0
	card.attack_pattern = CardTypes.AttackPattern.SINGLE_TARGET

	# Effects — heal 4 HP
	card.effects = [
		{
			"type": CardTypes.EffectType.HEAL,
			"target": CardTypes.EffectTarget.SELECTED,
			"value": 4,
		},
	]

	return card
