## Ragnarok's Echo — Viking AoE fire spell.
static func data() -> CardData:
	var card := CardData.new()

	# Identity
	card.id = "viking_ragnaroks_echo"
	card.card_name = "Ragnarok's Echo"
	card.card_type = CardTypes.CardType.SPELL
	card.card_class = CardTypes.Class.VIKING
	card.rarity = CardTypes.Rarity.EPIC
	card.flavor = "The old world ends in fire. So too shall the new."

	# Cost
	card.cost_type = CardTypes.CostType.MANA
	card.cost_value = 5

	# Spell targeting
	card.target_rule = CardTypes.TargetRule.ANY_HEX
	card.spell_range = 4
	card.attack_pattern = CardTypes.AttackPattern.AOE_RADIUS
	card.aoe_radius = 1
	card.damage_type = CardTypes.DamageType.FIRE

	# Keywords
	card.keywords = []

	# Effects
	card.effects = [
		{
			"type": CardTypes.EffectType.DEAL_DAMAGE,
			"target": CardTypes.EffectTarget.ALL_IN_AREA,
			"value": 3,
			"damage_type": CardTypes.DamageType.FIRE,
		},
		{
			"type": CardTypes.EffectType.APPLY_STATUS,
			"target": CardTypes.EffectTarget.ALL_IN_AREA,
			"status": CardTypes.StatusEffect.BURNING,
			"intensity": 1,
			"duration": CardTypes.Duration.N_TURNS,
			"duration_turns": 2,
		},
		{
			"type": CardTypes.EffectType.CREATE_TERRAIN,
			"target": CardTypes.EffectTarget.CENTER_HEX,
			"terrain": "LAVA",
			"duration": CardTypes.Duration.N_TURNS,
			"duration_turns": 3,
		},
	]

	return card
