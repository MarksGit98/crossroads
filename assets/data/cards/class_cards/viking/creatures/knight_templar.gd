## Knight Templar — Viking elite guardian. Protects adjacent allies
## and gains strength from their presence.
static func data() -> CardData:
	var card := CardData.new()

	# Identity
	card.id = "viking_knight_templar"
	card.card_name = "Knight Templar"
	card.card_type = CardTypes.CardType.CREATURE
	card.card_class = CardTypes.Class.VIKING
	card.rarity = CardTypes.Rarity.RARE
	card.flavor = "Where faith stands, darkness dares not tread."

	# Cost
	card.cost_type = CardTypes.CostType.MANA
	card.cost_value = 5

	# Stats
	card.role = CardTypes.CreatureRole.TANK
	card.atk = 3
	card.hp = 9
	card.armor = 2
	card.move_range = 1
	card.move_pattern = CardTypes.MovePattern.STANDARD
	card.attack_range = 1
	card.attack_pattern = CardTypes.AttackPattern.MELEE
	card.damage_type = CardTypes.DamageType.PHYSICAL

	# Keywords
	card.keywords = [CardTypes.Keyword.GUARD, CardTypes.Keyword.TAUNT]

	# Passives — armor aura for adjacent allies
	card.passives = [
		{
			"id": "holy_bulwark",
			"name": "Holy Bulwark",
			"type": CardTypes.PassiveType.STAT_AURA,
			"stat": CardTypes.Stat.ARMOR,
			"value": 1,
			"range": 1,
			"target": "allies",
		},
	]

	# Creature scene
	card.creature_scene_path = "res://scenes/creatures/viking/knight_templar.tscn"

	return card
