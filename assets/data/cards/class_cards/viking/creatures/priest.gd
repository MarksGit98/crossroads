## Priest — Viking support healer.
## Low attack, moderate HP. Heals adjacent allies.
static func data() -> CardData:
	var card := CardData.new()

	# Identity
	card.id = "viking_priest"
	card.card_name = "Priest"
	card.card_type = CardTypes.CardType.CREATURE
	card.card_class = CardTypes.Class.VIKING
	card.rarity = CardTypes.Rarity.UNCOMMON
	card.flavor = "Faith is the strongest shield."

	# Cost
	card.cost_type = CardTypes.CostType.MANA
	card.cost_value = 3

	# Stats
	card.role = CardTypes.CreatureRole.SUPPORT
	card.atk = 1
	card.hp = 5
	card.armor = 0
	card.move_range = 2
	card.move_pattern = CardTypes.MovePattern.STANDARD
	card.attack_range = 1
	card.attack_pattern = CardTypes.AttackPattern.MELEE
	card.damage_type = CardTypes.DamageType.MAGICAL

	# Keywords
	card.keywords = []

	# Active: Heal — restore 3 HP to an adjacent ally. No upgrade yet.
	card.actives = [{
		"regular": {
			"name": "Holy Light",
			"description": "Restore 3 HP to an adjacent ally.",
			"cooldown": 2,
			"cost_type": CardTypes.CostType.MANA,
			"cost_value": 1,
			"target_rule": CardTypes.TargetRule.ADJACENT_ALLY,
			"effects": [{
				"type": CardTypes.EffectType.HEAL,
				"value": 3,
				"target": CardTypes.EffectTarget.SELECTED,
			}],
		},
		# No upgraded variant yet — accessor falls back to regular.
	}]

	# Creature scene
	card.creature_scene_path = "res://scenes/creatures/viking/priest.tscn"

	return card
