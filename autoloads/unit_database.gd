## Loads and indexes all unit JSON definitions at startup.
extends Node

var units: Dictionary = {}  # unit_id -> unit data dict


func _ready() -> void:
	pass  # TODO: Load JSON unit definitions from assets/data/units/


func get_unit(unit_id: String) -> Dictionary:
	return units.get(unit_id, {})
