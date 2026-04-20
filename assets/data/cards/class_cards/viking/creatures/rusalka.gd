## Rusalka — support caster drawn from Slavic mythology (water spirit).
## Fragile but high-impact: her active permanently upgrades a friendly
## creature for the rest of the run, and her passive slowly heals her so
## she can outlast multi-turn engagements if kept out of melee.
static func data() -> CardData:
	var card := CardData.new()

	# Identity
	card.id = "viking_rusalka"
	card.card_name = "Rusalka"
	card.card_type = CardTypes.CardType.CREATURE
	card.card_class = CardTypes.Class.VIKING
	card.rarity = CardTypes.Rarity.RARE
	card.flavor = "Her song bends the worthy to a greater fate."

	# Cost
	card.cost_type = CardTypes.CostType.MANA
	card.cost_value = 3

	# Stats
	card.role = CardTypes.CreatureRole.SUPPORT
	card.atk = 1
	card.hp = 4
	card.armor = 0
	card.move_range = 2
	card.move_pattern = CardTypes.MovePattern.STANDARD
	card.attack_range = 3
	card.attack_pattern = CardTypes.AttackPattern.SINGLE_TARGET
	card.damage_type = CardTypes.DamageType.MAGICAL

	# Keywords — attack_range > 1 already marks her as ranged behaviorally,
	# but the RANGED keyword makes it explicit for other systems (is_ranged_attacker
	# check, future card text referencing ranged status).
	card.keywords = [CardTypes.Keyword.RANGED]

	# Passive — end of turn, heal 1 HP. Uses the same ON_TRIGGER pattern as
	# Axed Marauder's armor-bracing passive.
	card.passives = [
		{
			"regular": {
				"id": "rusalka_rejuvenation",
				"name": "Rejuvenation",
				"description": "At the end of your turn, recover 1 HP.",
				"type": CardTypes.PassiveType.ON_TRIGGER,
				"trigger": CardTypes.TriggerType.END_OF_TURN,
				"effects": [
					{
						"type": CardTypes.EffectType.HEAL,
						"target": CardTypes.EffectTarget.CASTER,
						"value": 1,
					},
				],
			},
			# No upgraded variant yet — accessor falls back to regular.
		},
	]

	# Active — Blessing: upgrade a friendly creature, enhancing its
	# actives and passives for the rest of the run.
	card.actives = [
		{
			"regular": {
				"id": "rusalka_blessing",
				"name": "Blessing",
				"description": "Upgrade a friendly creature within 2 hexes, permanently enhancing its actives and passives for the rest of the run.",
				"cost": 2,
				"range": 2,
				"cooldown": 2,
				"target_rule": CardTypes.TargetRule.ANY_ALLY,
				"effects": [
					{
						"type": CardTypes.EffectType.UPGRADE_CREATURE,
						"target": CardTypes.EffectTarget.SELECTED,
					},
				],
			},
			# No upgraded variant yet.
		},
	]

	# Creature scene
	card.creature_scene_path = "res://scenes/creatures/viking/rusalka.tscn"

	return card
