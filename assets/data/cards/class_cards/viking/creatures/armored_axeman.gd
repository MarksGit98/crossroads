## Armored Axeman — Viking heavy melee tank.
## High HP and armor, moderate attack. Holds the front line.
static func data() -> CardData:
	var card := CardData.new()

	# Identity
	card.id = "viking_armored_axeman"
	card.card_name = "Armored Axeman"
	card.card_type = CardTypes.CardType.CREATURE
	card.card_class = CardTypes.Class.VIKING
	card.rarity = CardTypes.Rarity.UNCOMMON
	card.flavor = "Steel and stubbornness — both in abundance."

	# Cost
	card.cost_type = CardTypes.CostType.MANA
	card.cost_value = 4

	# Stats
	card.role = CardTypes.CreatureRole.TANK
	card.atk = 3
	card.hp = 8
	card.armor = 2
	card.move_range = 1
	card.move_pattern = CardTypes.MovePattern.STANDARD
	card.attack_range = 1
	card.attack_pattern = CardTypes.AttackPattern.MELEE
	card.damage_type = CardTypes.DamageType.PHYSICAL

	# Keywords
	card.keywords = [CardTypes.Keyword.TAUNT, CardTypes.Keyword.HEAVY]

	# Creature scene
	card.creature_scene_path = "res://scenes/creatures/viking/armored_axeman.tscn"

	return card
