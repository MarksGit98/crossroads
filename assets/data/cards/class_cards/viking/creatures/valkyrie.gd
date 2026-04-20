## Valkyrie — Viking creature card.
static func data() -> CardData:
	var card := CardData.new()

	# Identity
	card.id = "viking_valkyrie"
	card.card_name = "Valkyrie"
	card.card_type = CardTypes.CardType.CREATURE
	card.card_class = CardTypes.Class.VIKING
	card.rarity = CardTypes.Rarity.COMMON
	card.flavor = "The runes speak through her."

	# Cost
	card.cost_type = CardTypes.CostType.MANA
	card.cost_value = 2

	# Stats
	card.role = CardTypes.CreatureRole.SUPPORT
	card.atk = 3
	card.hp = 6
	card.armor = 0
	card.move_range = 1
	card.move_pattern = CardTypes.MovePattern.ORTHOGONAL_ONLY
	card.attack_range = 1
	card.attack_pattern = CardTypes.AttackPattern.MELEE
	card.damage_type = CardTypes.DamageType.PHYSICAL

	# Keywords
	card.keywords = []

	# Passives — adjacent allies get +1 ATK and +1 HP while Valkyrie is alive.
	# No upgrade yet.
	card.passives = [
		{
			"regular": {
				"id": "inspiring_presence",
				"name": "Inspiring Presence",
				"type": CardTypes.PassiveType.STAT_AURA,
				"aura_range": 1,
				"target_rule": CardTypes.TargetRule.ADJACENT_ALLY,
				"effects": [
					{
						"type": CardTypes.EffectType.MODIFY_STAT,
						"stat": CardTypes.Stat.ATK,
						"value": 1,
					},
					{
						"type": CardTypes.EffectType.MODIFY_STAT,
						"stat": CardTypes.Stat.HP,
						"value": 1,
					},
				],
			},
		},
	]

	# Actives — Spear of Justice: line shot dealing 4 damage to first hit.
	# No upgrade yet.
	card.actives = [
		{
			"regular": {
				"id": "spear_of_justice",
				"name": "Spear of Justice",
				"cooldown": 2,
				"cost_type": CardTypes.CostType.MANA,
				"cost_value": 1,
				"target_rule": CardTypes.TargetRule.SELECT_DIRECTION,
				"range": 3,
				"effects": [
					{
						"type": CardTypes.EffectType.DEAL_DAMAGE,
						"target": CardTypes.EffectTarget.FIRST_HIT,
						"value": 4,
						"damage_type": CardTypes.DamageType.PHYSICAL,
					},
				],
			},
		},
	]

	return card
