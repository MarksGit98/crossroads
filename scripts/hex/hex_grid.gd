## Visual hex grid for the duel board.
## Owns the grid data (Dictionary of HexTileData) and draws all hexes using _draw().
## Click detection converts mouse position to hex coordinates.
class_name HexGrid
extends Node2D

## Emitted when a hex is clicked. Passes the offset coordinate.
signal hex_clicked(coord: Vector2i)
## Emitted when the mouse hovers over a new hex.
signal hex_hovered(coord: Vector2i)

## Size of each hex (center to vertex distance in pixels).
@export var hex_size: float = 40.0
## Width of the hex outline stroke.
@export var outline_width: float = 2.0
## Color of hex outlines.
@export var outline_color: Color = Color(0.2, 0.2, 0.2, 0.6)

## Grid dimensions (columns x rows).
var grid_cols: int = 0
var grid_rows: int = 0
## The actual grid data: offset coord -> HexTileData.
var tiles: Dictionary = {}
## Currently hovered hex (-1, -1 means none).
var hovered_hex: Vector2i = Vector2i(-1, -1)
## Currently selected hex (-1, -1 means none).
var selected_hex: Vector2i = Vector2i(-1, -1)
## Set of hex coords to highlight (e.g. movement range, attack range).
var highlight_tiles: Dictionary = {}  # coord -> Color

## Cached corner offsets — computed once, reused every draw.
var _corner_offsets: PackedVector2Array


func _ready() -> void:
	_corner_offsets = HexHelper.hex_corner_offsets(hex_size)


## Initialize the grid from a 2D array of terrain types.
## layout[row][col] = TerrainTypes.Terrain value.
func load_layout(layout: Array) -> void:
	tiles.clear()
	grid_rows = layout.size()
	grid_cols = layout[0].size() if grid_rows > 0 else 0

	for row: int in range(grid_rows):
		for col: int in range(grid_cols):
			var coord: Vector2i = Vector2i(col, row)
			var terrain: int = layout[row][col]
			tiles[coord] = HexTileData.new(coord, terrain as TerrainTypes.Terrain)

	_assign_spawn_tiles()
	queue_redraw()


## Mark which tiles are valid spawn zones for the player.
## Currently: bottom row, columns 1-6 (excludes corner columns).
func _assign_spawn_tiles() -> void:
	var spawn_row: int = grid_rows - 1
	for col: int in range(1, grid_cols - 1):
		var coord: Vector2i = Vector2i(col, spawn_row)
		var tile: HexTileData = tiles.get(coord)
		if tile:
			tile.valid_spawn = true


## Get the HexTileData at a coordinate, or null if out of bounds.
func get_tile(coord: Vector2i) -> HexTileData:
	return tiles.get(coord)


## Check if a coordinate is within the grid bounds.
func is_in_bounds(coord: Vector2i) -> bool:
	return tiles.has(coord)


## Set highlight tiles (e.g. for showing movement range).
func set_highlights(coords: Dictionary) -> void:
	highlight_tiles = coords
	queue_redraw()


## Clear all highlights.
func clear_highlights() -> void:
	highlight_tiles.clear()
	queue_redraw()


# --- Drawing ---

func _draw() -> void:
	for coord: Vector2i in tiles:
		var tile: HexTileData = tiles[coord]
		var center: Vector2 = HexHelper.hex_to_world(coord, hex_size)

		# Fill with terrain color
		var fill_color: Color = TerrainTypes.get_debug_color(tile.terrain)
		_draw_hex_filled(center, fill_color)

		# Spawn zone tint
		if tile.valid_spawn:
			_draw_hex_filled(center, Color(1.0, 0.9, 0.2, 0.25))

		# Draw highlight overlay if present
		if highlight_tiles.has(coord):
			var h_color: Color = highlight_tiles[coord]
			_draw_hex_filled(center, h_color)

		# Hover highlight
		if coord == hovered_hex:
			_draw_hex_filled(center, Color(1.0, 1.0, 1.0, 0.15))

		# Selection highlight
		if coord == selected_hex:
			_draw_hex_outline(center, Color.WHITE, 3.0)

		# Outline
		_draw_hex_outline(center, outline_color, outline_width)


## Draw a filled hexagon at center position.
func _draw_hex_filled(center: Vector2, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for offset: Vector2 in _corner_offsets:
		points.append(center + offset)
	draw_colored_polygon(points, color)


## Draw a hex outline at center position.
func _draw_hex_outline(center: Vector2, color: Color, width: float) -> void:
	for i: int in range(6):
		var from_pt: Vector2 = center + _corner_offsets[i]
		var to_pt: Vector2 = center + _corner_offsets[(i + 1) % 6]
		draw_line(from_pt, to_pt, color, width, true)


# --- Input ---

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var local_pos: Vector2 = get_local_mouse_position()
		var coord: Vector2i = HexHelper.world_to_hex(local_pos, hex_size)
		if is_in_bounds(coord) and coord != hovered_hex:
			hovered_hex = coord
			hex_hovered.emit(coord)
			queue_redraw()
		elif not is_in_bounds(coord) and hovered_hex != Vector2i(-1, -1):
			hovered_hex = Vector2i(-1, -1)
			queue_redraw()

	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var local_pos: Vector2 = get_local_mouse_position()
			var coord: Vector2i = HexHelper.world_to_hex(local_pos, hex_size)
			if is_in_bounds(coord):
				selected_hex = coord
				hex_clicked.emit(coord)
				queue_redraw()
