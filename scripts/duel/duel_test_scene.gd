## Test scene for the hex grid duel board.
## Generates a procedural map and prints hex info on click.
## Press R to regenerate the map with a new seed.
extends Node2D

@onready var hex_grid: HexGrid = $HexGrid
@onready var creatures_node: Node2D = $Creatures
@onready var info_label: Label = $CanvasLayer/InfoLabel
@onready var border_toggle: Button = $CanvasLayer/BorderToggle
@onready var camera: Camera2D = $Camera2D
@onready var player: Player = $Player
@onready var hand: Node2D = $HandLayer/Hand

var _generator: TerrainGenerator = TerrainGenerator.new()
var _current_seed: int = -1


func _ready() -> void:
	_generate_new_map()

	# Connect signals
	hex_grid.hex_clicked.connect(_on_hex_clicked)
	hex_grid.hex_hovered.connect(_on_hex_hovered)
	border_toggle.pressed.connect(_on_border_toggle_pressed)

	# Wire the hand to the hex grid for targeting mode
	hand.board = hex_grid

	# Tell the hex grid where to parent spawned creatures.
	hex_grid.creature_parent = creatures_node

	# Start the first turn so mana initializes
	player.start_turn()


func _generate_new_map() -> void:
	_current_seed = randi()
	var layout: Array = _generator.generate(_current_seed)
	hex_grid.load_layout(layout)
	_center_camera()
	info_label.text = "Seed: %d  |  Press R to regenerate" % _current_seed


func _center_camera() -> void:
	# Find the pixel center of the grid, offset slightly for 2.5D tile depth
	var center_col: float = (hex_grid.grid_cols - 1) / 2.0
	var center_row: float = (hex_grid.grid_rows - 1) / 2.0
	var center_coord: Vector2i = Vector2i(roundi(center_col), roundi(center_row))
	var grid_center: Vector2 = HexHelper.hex_to_world(center_coord, hex_grid.hex_size)
	camera.position = grid_center + Vector2(0, HexTileRenderer.DEPTH_OFFSET)


func _on_hex_clicked(coord: Vector2i) -> void:
	var tile: HexTileData = hex_grid.get_tile(coord)
	if not tile:
		return

	var props: Dictionary = tile.get_properties()
	var terrain_name: String = TerrainTypes.Terrain.keys()[tile.terrain]
	var passable_name: String = TerrainTypes.Passability.keys()[props.passability]
	var los_name: String = TerrainTypes.LOSType.keys()[props.los]
	var elevation_name: String = TerrainTypes.Elevation.keys()[props.elevation]

	var occupant_text: String = "Empty"
	if tile.is_occupied():
		occupant_text = "%s (ATK:%d HP:%d/%d)" % [
			tile.occupant.creature_name,
			tile.occupant.current_atk,
			tile.occupant.current_hp,
			tile.occupant.max_hp,
		]

	info_label.text = "Hex (%d, %d)  |  %s  |  %s  |  LOS: %s  |  Elev: %s  |  %s" % [
		coord.x, coord.y, terrain_name, passable_name, los_name, elevation_name, occupant_text
	]

	# Don't overwrite targeting highlights when the hand is picking a hex
	if not hand.is_targeting():
		var highlights: Dictionary = {}
		var neighbors: Array[Vector2i] = HexHelper.hex_neighbors(coord)
		for n: Vector2i in neighbors:
			if hex_grid.is_in_bounds(n):
				highlights[n] = Color(0.3, 0.5, 1.0, 0.25)

		# Highlight the selected hex itself in white
		highlights[coord] = Color(1.0, 1.0, 1.0, 0.2)

		hex_grid.set_highlights(highlights)


func _on_hex_hovered(coord: Vector2i) -> void:
	pass  # Could show a tooltip or preview — keeping simple for now


func _unhandled_input(event: InputEvent) -> void:
	# R to regenerate map
	if event is InputEventKey:
		var kb: InputEventKey = event as InputEventKey
		if kb.pressed and kb.keycode == KEY_R:
			_generate_new_map()
			return
		if kb.pressed and kb.keycode == KEY_B:
			_on_border_toggle_pressed()
			return

	# Scroll to zoom
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				camera.zoom *= 1.1
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				camera.zoom /= 1.1
			camera.zoom = camera.zoom.clamp(Vector2(0.3, 0.3), Vector2(3.0, 3.0))


func _on_border_toggle_pressed() -> void:
	var new_state: bool = not hex_grid.are_borders_visible()
	hex_grid.set_borders_visible(new_state)
	border_toggle.text = "Hide Hex Borders" if new_state else "Show Hex Borders"
