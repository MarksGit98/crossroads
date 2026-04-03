## Soldier — Viking basic infantry. Cheap, reliable, no frills.
## The backbone of any warband.
static func data() -> CardData:
	var card := CardData.new()

	# Identity
	card.id = "viking_soldier"
	card.card_name = "Soldier"
	card.card_type = CardTypes.CardType.CREATURE
	card.card_class = CardTypes.Class.VIKING
	card.rarity = CardTypes.Rarity.COMMON
	card.flavor = "A blade, a shield, and the will to use both."

	# Cost
	card.cost_type = CardTypes.CostType.MANA
	card.cost_value = 1

	# Stats
	card.role = CardTypes.CreatureRole.STRIKER
	card.atk = 2
	card.hp = 3
	card.armor = 1
	card.move_range = 2
	card.move_pattern = CardTypes.MovePattern.STANDARD
	card.attack_range = 1
	card.attack_pattern = CardTypes.AttackPattern.MELEE
	card.damage_type = CardTypes.DamageType.PHYSICAL

	# Keywords
	card.keywords = []

	# Creature scene
	card.creature_scene_path = "res://scenes/creatures/viking/soldier.tscn"

	return card
