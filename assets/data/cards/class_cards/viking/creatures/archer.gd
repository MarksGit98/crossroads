## Archer — Viking ranged artillery creature.
## Long range, low HP — a glass cannon that picks off targets from safety.
static func data() -> CardData:
	var card := CardData.new()

	# Identity
	card.id = "viking_archer"
	card.card_name = "Archer"
	card.card_type = CardTypes.CardType.CREATURE
	card.card_class = CardTypes.Class.VIKING
	card.rarity = CardTypes.Rarity.COMMON
	card.flavor = "An arrow loosed is a life spent."

	# Cost
	card.cost_type = CardTypes.CostType.MANA
	card.cost_value = 2

	# Stats
	card.role = CardTypes.CreatureRole.ARTILLERY
	card.atk = 3
	card.hp = 3
	card.armor = 0
	card.move_range = 2
	card.move_pattern = CardTypes.MovePattern.STANDARD
	card.attack_range = 3
	card.attack_pattern = CardTypes.AttackPattern.SINGLE_TARGET
	card.damage_type = CardTypes.DamageType.PHYSICAL

	# Keywords
	card.keywords = [CardTypes.Keyword.RANGED]

	# Creature scene
	card.creature_scene_path = "res://scenes/creatures/viking/archer.tscn"

	return card
