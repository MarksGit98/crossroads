## Axed Marauder — Viking melee striker who throws a pair of axes in
## straight lines, piercing through enemies. Axes embed themselves in tiles
## and must be walked over to reclaim. Upgrade grants a third axe and
## extended throw range.
static func data() -> CardData:
	var card := CardData.new()

	# Identity
	card.id = "viking_axed_marauder"
	card.card_name = "Axed Marauder"
	card.card_type = CardTypes.CardType.CREATURE
	card.card_class = CardTypes.Class.VIKING
	card.rarity = CardTypes.Rarity.UNCOMMON
	card.flavor = "No one ever sees the second axe coming."

	# Cost
	card.cost_type = CardTypes.CostType.MANA
	card.cost_value = 3

	# Stats
	card.role = CardTypes.CreatureRole.STRIKER
	card.atk = 4
	card.hp = 4
	card.armor = 0
	card.move_range = 2
	card.move_pattern = CardTypes.MovePattern.STANDARD
	card.attack_range = 1
	card.attack_pattern = CardTypes.AttackPattern.MELEE
	card.damage_type = CardTypes.DamageType.PHYSICAL

	# Keywords
	card.keywords = []

	# Passives — at end of turn, gain 2 armor. Same regular and upgraded.
	card.passives = [
		{
			"regular": {
				"id": "marauder_brace",
				"name": "Brace",
				"description": "At end of your turn, gain 2 armor.",
				"type": CardTypes.PassiveType.ON_TRIGGER,
				"trigger": CardTypes.TriggerType.END_OF_TURN,
				"effects": [
					{
						"type": CardTypes.EffectType.MODIFY_STAT,
						"target": CardTypes.EffectTarget.CASTER,
						"stat": CardTypes.Stat.ARMOR,
						"value": 2,
					},
				],
			},
			# No upgraded variant — accessor falls back to regular.
		},
	]

	# Actives — axe throw with 2-axe capacity; upgrade bumps to 3 axes and
	# +1 range. Damage is always ceil(current_atk / 2) so it scales with
	# buffs. Throw pierces every enemy in the cardinal line until impassable
	# terrain, then the axe embeds in the landing tile for pickup.
	card.actives = [
		{
			"regular": {
				"id": "marauder_axe_throw",
				"name": "Axe Throw",
				"description": "Throw an axe up to 2 hexes in a straight line, dealing ceil(ATK/2) damage to every enemy it passes through. The axe embeds in the landing tile — step on it to reclaim.",
				"cost": 0,
				"range": 2,
				"cooldown": 0,
				"target_rule": CardTypes.TargetRule.LINE_HEX,
				"required_charge_id": "axed_marauder_axe",
				"starting_charges": 2,
				"effects": [
					{
						"type": CardTypes.EffectType.THROW_AXE,
						"range": 2,
						"damage_type": CardTypes.DamageType.PHYSICAL,
						"damage_source": "half_atk_ceil",
					},
				],
			},
			"upgraded": {
				"id": "marauder_axe_throw_plus",
				"name": "Axe Throw+",
				"description": "Throw an axe up to 3 hexes in a straight line, dealing ceil(ATK/2) damage to every enemy it passes through. Hold up to 3 axes at once.",
				"cost": 0,
				"range": 3,
				"cooldown": 0,
				"target_rule": CardTypes.TargetRule.LINE_HEX,
				"required_charge_id": "axed_marauder_axe",
				"starting_charges": 3,
				"effects": [
					{
						"type": CardTypes.EffectType.THROW_AXE,
						"range": 3,
						"damage_type": CardTypes.DamageType.PHYSICAL,
						"damage_source": "half_atk_ceil",
					},
				],
			},
		},
	]

	# Creature scene
	card.creature_scene_path = "res://scenes/creatures/viking/axed_marauder.tscn"

	return card
