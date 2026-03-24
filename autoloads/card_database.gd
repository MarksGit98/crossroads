## Loads and indexes all card JSON definitions at startup.
extends Node

var cards: Dictionary = {}  # card_id -> card data dict


func _ready() -> void:
	pass  # TODO: Load JSON card definitions from assets/data/cards/


func get_card(card_id: String) -> Dictionary:
	return cards.get(card_id, {})


func get_cards_by_class(card_class: String) -> Array:
	var result: Array = []
	for card: Dictionary in cards.values():
		if card.get("class", "") == card_class:
			result.append(card)
	return result
