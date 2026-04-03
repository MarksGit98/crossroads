## Swordsman — Viking aggressive melee striker.
## Higher ATK than the Knight, but less durable. Rewards kills with frenzy.
static func data() -> CardData:
	var card := CardData.new()

	# Identity
	card.id = "viking_swordsman"
	card.card_name = "Swordsman"
	card.card_type = CardTypes.CardType.CREATURE
	card.card_class = CardTypes.Class.VIKING
	card.rarity = CardTypes.Rarity.COMMON
	card.flavor = "Every swing is a conversation he intends to win."

	# Cost
	card.cost_type = CardTypes.CostType.MANA
	card.cost_value = 2

	# Stats
	card.role = CardTypes.CreatureRole.STRIKER
	card.atk = 4
	card.hp = 3
	card.armor = 0
	card.move_range = 2
	card.move_pattern = CardTypes.MovePattern.STANDARD
	card.attack_range = 1
	card.attack_pattern = CardTypes.AttackPattern.MELEE
	card.damage_type = CardTypes.DamageType.PHYSICAL

	# Keywords
	card.keywords = [CardTypes.Keyword.FRENZY]

	# Creature scene
	card.creature_scene_path = "res://scenes/creatures/viking/swordsman.tscn"

	return card
