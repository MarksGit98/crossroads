## Shieldmaiden — Viking tank creature card.
static func data() -> CardData:
	var card := CardData.new()

	# Identity
	card.id = "viking_shieldmaiden"
	card.card_name = "Shieldmaiden"
	card.card_type = CardTypes.CardType.CREATURE
	card.card_class = CardTypes.Class.VIKING
	card.rarity = CardTypes.Rarity.COMMON
	card.flavor = "Her shield has never been breached."

	# Cost
	card.cost_type = CardTypes.CostType.MANA
	card.cost_value = 2

	# Stats
	card.role = CardTypes.CreatureRole.TANK
	card.atk = 2
	card.hp = 8
	card.armor = 1
	card.move_range = 1
	card.move_pattern = CardTypes.MovePattern.STANDARD
	card.attack_range = 1
	card.attack_pattern = CardTypes.AttackPattern.MELEE
	card.damage_type = CardTypes.DamageType.PHYSICAL

	# Keywords
	card.keywords = [CardTypes.Keyword.GUARD]

	return card
