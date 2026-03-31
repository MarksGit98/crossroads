## Frost Archer — Viking ranged creature card.
static func data() -> CardData:
	var card := CardData.new()

	# Identity
	card.id = "viking_frost_archer"
	card.card_name = "Frost Archer"
	card.card_type = CardTypes.CardType.CREATURE
	card.card_class = CardTypes.Class.VIKING
	card.rarity = CardTypes.Rarity.RARE
	card.flavor = "Each arrow carries the bite of winter."

	# Cost
	card.cost_type = CardTypes.CostType.MANA
	card.cost_value = 3

	# Stats
	card.role = CardTypes.CreatureRole.ARTILLERY
	card.atk = 3
	card.hp = 5
	card.armor = 0
	card.move_range = 1
	card.move_pattern = CardTypes.MovePattern.STANDARD
	card.attack_range = 3
	card.attack_pattern = CardTypes.AttackPattern.SINGLE_TARGET
	card.damage_type = CardTypes.DamageType.ICE

	# Keywords
	card.keywords = [CardTypes.Keyword.RANGED]

	# Passives — chill on hit
	card.passives = [
		{
			"id": "freezing_arrows",
			"name": "Freezing Arrows",
			"type": CardTypes.PassiveType.ON_TRIGGER,
			"trigger": CardTypes.TriggerType.ON_HIT,
			"effects": [
				{
					"type": CardTypes.EffectType.APPLY_STATUS,
					"target": CardTypes.EffectTarget.SELECTED,
					"status": CardTypes.StatusEffect.CHILLED,
					"intensity": 1,
					"duration": CardTypes.Duration.N_TURNS,
					"duration_turns": 1,
				},
			],
		},
	]

	return card
