## Berserker — Viking striker creature card.
static func data() -> CardData:
	var card := CardData.new()

	# Identity
	card.id = "viking_berserker"
	card.card_name = "Berserker"
	card.card_type = CardTypes.CardType.CREATURE
	card.card_class = CardTypes.Class.VIKING
	card.rarity = CardTypes.Rarity.UNCOMMON
	card.flavor = "Rage is the only armor he needs."

	# Cost
	card.cost_type = CardTypes.CostType.MANA
	card.cost_value = 3

	# Stats
	card.role = CardTypes.CreatureRole.STRIKER
	card.atk = 5
	card.hp = 4
	card.armor = 0
	card.move_range = 2
	card.move_pattern = CardTypes.MovePattern.STANDARD
	card.attack_range = 1
	card.attack_pattern = CardTypes.AttackPattern.MELEE
	card.damage_type = CardTypes.DamageType.PHYSICAL

	# Keywords
	card.keywords = [CardTypes.Keyword.FRENZY]

	return card
