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
	card.flavor = "The runes speak, and reality bends. Can unleash Arcane Blast (2 mana: 3 MAGICAL AoE) or plant an Arcane Anchor to mark his hex as a summon point."

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

	# Actives — variant-grouped so upgraded Wizards use buffed versions.
	# Upgrade currently just adds +1 damage to Arcane Blast and cuts its
	# cooldown to 1; Arcane Anchor has no upgraded variant yet (falls back
	# to regular automatically).
	card.actives = [
		{
			"regular": {
				"id": "arcane_blast",
				"name": "Arcane Blast",
				"description": "Unleash a burst of arcane energy at a target hex, dealing 3 MAGICAL damage to all units within 1 hex.",
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
			"upgraded": {
				"id": "arcane_blast_plus",
				"name": "Arcane Blast+",
				"description": "Unleash a surge of arcane energy at a target hex, dealing 4 MAGICAL damage to all units within 1 hex.",
				"cost": 2,
				"range": 3,
				"cooldown": 1,
				"target_rule": CardTypes.TargetRule.ANY_HEX,
				"effects": [
					{
						"type": CardTypes.EffectType.DEAL_DAMAGE,
						"target": CardTypes.EffectTarget.ALL_IN_AREA,
						"damage_type": CardTypes.DamageType.MAGICAL,
						"value": 4,
						"aoe_radius": 1,
					},
				],
			},
		},
		{
			"regular": {
				"id": "arcane_anchor",
				"name": "Arcane Anchor",
				"description": "Mark the Wizard's hex as a valid summon location. Allies may be summoned here in future turns.",
				"cost": 0,
				"range": 0,
				"cooldown": 3,
				"target_rule": CardTypes.TargetRule.SELF,
				"effects": [
					{
						"type": CardTypes.EffectType.MARK_SPAWN,
						"target": CardTypes.EffectTarget.CASTER,
					},
				],
			},
			# No upgraded variant — accessor falls back to regular.
		},
	]

	# Creature scene
	card.creature_scene_path = "res://scenes/creatures/viking/wizard.tscn"

	return card
