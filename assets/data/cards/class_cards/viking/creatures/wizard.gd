## Wizard — Viking spellcaster support/controller.
## Ranged magical damage with area denial. Fragile but powerful.
static func data() -> CardData:
	var card := CardData.new()

	# Identity
	card.id = "viking_wizard"
	card.card_name = "Wizard"
	card.card_type = CardTypes.CardType.CREATURE
	card.card_class = CardTypes.Class.VIKING
	card.rarity = CardTypes.Rarity.RARE
	card.flavor = "The runes speak, and reality bends."

	# Cost
	card.cost_type = CardTypes.CostType.MANA
	card.cost_value = 4

	# Stats
	card.role = CardTypes.CreatureRole.CONTROLLER
	card.atk = 2
	card.hp = 4
	card.armor = 0
	card.move_range = 1
	card.move_pattern = CardTypes.MovePattern.STANDARD
	card.attack_range = 3
	card.attack_pattern = CardTypes.AttackPattern.AOE_RADIUS
	card.damage_type = CardTypes.DamageType.MAGICAL

	# Keywords
	card.keywords = [CardTypes.Keyword.RANGED]

	# Actives — arcane blast: AoE damage on a targeted hex
	card.actives = [
		{
			"id": "arcane_blast",
			"name": "Arcane Blast",
			"cost": 2,
			"range": 3,
			"cooldown": 2,
			"target_rule": CardTypes.TargetRule.ANY_HEX,
			"effects": [
				{
					"type": CardTypes.EffectType.DEAL_DAMAGE,
					"target": CardTypes.EffectTarget.ALL_IN_AREA,
					"damage_type": CardTypes.DamageType.MAGICAL,
					"value": 3,
					"aoe_radius": 1,
				},
			],
		},
	]

	# Creature scene
	card.creature_scene_path = "res://scenes/creatures/viking/wizard.tscn"

	return card
