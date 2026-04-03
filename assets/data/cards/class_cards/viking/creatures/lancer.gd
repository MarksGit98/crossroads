## Lancer — Viking mounted charge striker.
## High mobility, charges in a straight line for bonus damage.
static func data() -> CardData:
	var card := CardData.new()

	# Identity
	card.id = "viking_lancer"
	card.card_name = "Lancer"
	card.card_type = CardTypes.CardType.CREATURE
	card.card_class = CardTypes.Class.VIKING
	card.rarity = CardTypes.Rarity.UNCOMMON
	card.flavor = "The thunder of hooves heralds the end."

	# Cost
	card.cost_type = CardTypes.CostType.MANA
	card.cost_value = 4

	# Stats
	card.role = CardTypes.CreatureRole.STRIKER
	card.atk = 5
	card.hp = 5
	card.armor = 1
	card.move_range = 3
	card.move_pattern = CardTypes.MovePattern.CHARGE
	card.attack_range = 2
	card.attack_pattern = CardTypes.AttackPattern.SINGLE_TARGET
	card.damage_type = CardTypes.DamageType.PHYSICAL

	# Keywords
	card.keywords = [CardTypes.Keyword.REACH, CardTypes.Keyword.SWIFT]

	# Creature scene
	card.creature_scene_path = "res://scenes/creatures/viking/lancer.tscn"

	return card
