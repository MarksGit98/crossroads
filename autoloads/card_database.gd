## Loads and indexes all card .gd definitions at startup.
## Each card file exposes a static data() -> CardData method.
extends Node

const CARD_ROOT := "res://assets/data/cards/"

var cards: Dictionary = {}  # card_id -> CardData


func _ready() -> void:
	_scan_directory(CARD_ROOT)


func get_card(card_id: String) -> CardData:
	return cards.get(card_id, null)


func get_cards_by_class(card_class: CardTypes.Class) -> Array[CardData]:
	var result: Array[CardData] = []
	for card: CardData in cards.values():
		if card.card_class == card_class:
			result.append(card)
	return result


func get_cards_by_type(card_type: CardTypes.CardType) -> Array[CardData]:
	var result: Array[CardData] = []
	for card: CardData in cards.values():
		if card.card_type == card_type:
			result.append(card)
	return result


func get_cards_by_rarity(rarity: CardTypes.Rarity) -> Array[CardData]:
	var result: Array[CardData] = []
	for card: CardData in cards.values():
		if card.rarity == rarity:
			result.append(card)
	return result


## Recursively scan directories for .gd card files and load them.
func _scan_directory(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		push_warning("CardDatabase: Could not open directory: %s" % path)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		var full_path := path.path_join(file_name)
		if dir.current_is_dir():
			_scan_directory(full_path)
		elif file_name.ends_with(".gd"):
			_load_card(full_path)
		file_name = dir.get_next()
	dir.list_dir_end()


## Load a single card .gd file and register it.
func _load_card(path: String) -> void:
	var script := load(path) as GDScript
	if script == null:
		push_warning("CardDatabase: Failed to load script: %s" % path)
		return

	if not script.has_method("data"):
		push_warning("CardDatabase: Script missing data() method: %s" % path)
		return

	var card: CardData = script.data()
	if card == null:
		push_warning("CardDatabase: data() returned null: %s" % path)
		return

	if card.id.is_empty():
		push_warning("CardDatabase: Card has no id: %s" % path)
		return

	if cards.has(card.id):
		push_warning("CardDatabase: Duplicate card id '%s' in %s" % [card.id, path])

	cards[card.id] = card
