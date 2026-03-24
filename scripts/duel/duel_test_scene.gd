## Test scene for the hex grid duel board.
## Loads a hardcoded layout, centers the camera, and prints hex info on click.
extends Node2D

@onready var hex_grid: HexGrid = $HexGrid
@onready var info_label: Label = $CanvasLayer/InfoLabel
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	# Load the Tundra test layout
	hex_grid.load_layout(TestLayouts.tundra_standard())

	# Center camera on the grid
	_center_camera()

	# Connect signals
	hex_grid.hex_clicked.connect(_on_hex_clicked)
	hex_grid.hex_hovered.connect(_on_hex_hovered)

	info_label.text = "Click a hex to inspect it"


func _center_camera() -> void:
	# Find the pixel center of the grid
	var center_col: float = (hex_grid.grid_cols - 1) / 2.0
	var center_row: float = (hex_grid.grid_rows - 1) / 2.0
	var center_coord: Vector2i = Vector2i(roundi(center_col), roundi(center_row))
	camera.position = HexHelper.hex_to_world(center_coord, hex_grid.hex_size)


func _on_hex_clicked(coord: Vector2i) -> void:
	var tile: HexTileData = hex_grid.get_tile(coord)
	if not tile:
		return

	var props: Dictionary = tile.get_properties()
	var terrain_name: String = TerrainTypes.Terrain.keys()[tile.terrain]
	var passable_name: String = TerrainTypes.Passability.keys()[props.passability]
	var los_name: String = TerrainTypes.LOSType.keys()[props.los]
	var elevation_name: String = TerrainTypes.Elevation.keys()[props.elevation]

	info_label.text = "Hex (%d, %d)  |  %s  |  %s  |  LOS: %s  |  Elev: %s" % [
		coord.x, coord.y, terrain_name, passable_name, los_name, elevation_name
	]

	# Show neighbors highlighted in blue
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
	# Scroll to zoom
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				camera.zoom *= 1.1
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				camera.zoom /= 1.1
				camera.zoom = camera.zoom.clamp(Vector2(0.3, 0.3), Vector2(3.0, 3.0))
