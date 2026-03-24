## Serializes RunData to disk. Saves on every tile resolution, loads on launch.
extends Node

const SAVE_PATH: String = "user://crossroads_save.json"


func save_run() -> void:
	pass  # TODO: Serialize RunData to JSON and write to SAVE_PATH


func load_run() -> bool:
	return false  # TODO: Deserialize from SAVE_PATH into RunData


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)
