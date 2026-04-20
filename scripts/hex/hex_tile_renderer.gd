## Manages visual Sprite2D nodes for each hex tile.
## Handles ground layer, middle layer, highlight overlays, and z-ordering.
## Owned by HexGrid — call build_visuals() after load_layout().
class_name HexTileRenderer
extends Node2D

## Pixel dimensions of a single tile image (120x136 at the largest size).
const TILE_WIDTH: int = 120
const TILE_HEIGHT: int = 136

## The hex face height (flat-top): sqrt(3) * hex_size.
## For hex_size 60: ~103.9 px. The remaining ~32px is the 2.5D depth.
const DEPTH_OFFSET: float = 16.0  # half of (TILE_HEIGHT - hex_face_height)

## Z-index band used for ground tiles. They sit in a low band so they can
## never overlap creatures, whose sprites often extend visually beyond their
## own hex (e.g. the Minotaur's weapon reaching into the row below).
## Ground tiles sort among themselves by row so back-row ground still draws
## before front-row ground.
##
## Middle/top tiles and creatures live in a separate upper band (see below).
##
## Both bands are kept well inside Godot's [-4096, 4096] z_index clamp so
## large values don't get silently capped and collapse into the same z.
## Ground band reserves room for up to 500 rows of row-sorted tiles; the
## objects band adds row*3 + sub_layer on top of its base, giving plenty of
## room for any reasonably-sized grid without overlap between bands.
const Z_BAND_GROUND: int = 0

## Z-index band for "vertical" objects that should participate in the 2.5D
## depth sort — middle tiles (trees, mountains, walls), top tiles, highlights,
## and creatures. Everything in this band sorts by row and sub-layer, so a
## wall in the row IN FRONT of a creature still draws over it.
const Z_BAND_OBJECTS: int = 1000

## Texture cache so we don't reload the same image per tile.
var _texture_cache: Dictionary = {}  # path -> Texture2D

## Per-tile visual nodes: coord -> {ground: Sprite2D, middle: Sprite2D or null}
var _tile_sprites: Dictionary = {}

## Spawn-zone overlay sprites added at runtime: coord -> Sprite2D
var _spawn_overlays: Dictionary = {}

## Highlight overlay sprites: coord -> Sprite2D
var _highlight_sprites: Dictionary = {}

## Hover overlay sprite (single, reused).
var _hover_sprite: Sprite2D = null

## Selection outline sprite.
var _selection_sprite: Sprite2D = null

## Reference to the highlight texture (white hex used for color modulation).
var _highlight_texture: Texture2D = null

## Hex border overlay node (toggle-able debug lines).
var _border_overlay: HexBorderOverlay = null

## Highlight border overlay — draws white outlines around highlighted hexes.
var _highlight_border: HexBorderOverlay = null

## Hex size used for positioning.
var hex_size: float = 60.0


func _ready() -> void:
	# Belt-and-suspenders for depth sorting: z_index is the primary key
	# (cross-band), y_sort_enabled handles ties within the same z (e.g.
	# two middle-tile sprites that happen to land on the same row). This
	# keeps rendering deterministic if we ever add overlapping sprites or
	# runtime-inserted tiles that don't perfectly partition by row.
	y_sort_enabled = true


## Build all tile visuals from the grid's tile data.
## Call this once after HexGrid.load_layout().
func build_visuals(tiles: Dictionary, p_hex_size: float) -> void:
	hex_size = p_hex_size
	_clear_all()

	# Use the first ground texture as the highlight base (we modulate it).
	# Load it once for overlay use.
	_highlight_texture = _load_texture("res://assets/tiles/hexagon_realms/ground/grassland.png")

	# Sort tiles by row so we add children in draw order (top rows first).
	var sorted_coords: Array = tiles.keys()
	sorted_coords.sort_custom(_sort_by_row)

	for coord: Vector2i in sorted_coords:
		var tile: HexTileData = tiles[coord]
		var world_pos: Vector2 = HexHelper.hex_to_world(coord, hex_size)
		var tex_info: Dictionary = TerrainTypes.get_tile_textures(tile.terrain)

		# Ground layer sprite — lives in the low Z_BAND_GROUND so creatures
		# always draw above ground tiles regardless of row.
		var ground_sprite: Sprite2D = Sprite2D.new()
		ground_sprite.texture = _load_texture(tex_info.ground)
		ground_sprite.position = world_pos + Vector2(0, DEPTH_OFFSET)
		ground_sprite.z_index = Z_BAND_GROUND + coord.y
		add_child(ground_sprite)

		# Spawn zone tint overlay — layered just on top of its ground tile
		# and still below everything else.
		if tile.valid_spawn:
			var spawn_overlay: Sprite2D = Sprite2D.new()
			spawn_overlay.texture = ground_sprite.texture
			spawn_overlay.position = ground_sprite.position
			spawn_overlay.z_index = Z_BAND_GROUND + coord.y
			spawn_overlay.modulate = Color(1.0, 0.9, 0.2, 0.3)
			add_child(spawn_overlay)

		# Middle layer sprite (trees, mountains, walls). Lives in the upper
		# Z_BAND_OBJECTS band alongside creatures so the 2.5D depth sort
		# between walls and creatures still works correctly — a wall in a
		# row closer to the camera still draws over creatures behind it.
		var middle_sprite: Sprite2D = null
		if tex_info.middle != "":
			middle_sprite = Sprite2D.new()
			middle_sprite.texture = _load_texture(tex_info.middle)
			middle_sprite.position = world_pos + Vector2(0, DEPTH_OFFSET)
			middle_sprite.z_index = Z_BAND_OBJECTS + coord.y * 3 + 1
			add_child(middle_sprite)

		_tile_sprites[coord] = {ground = ground_sprite, middle = middle_sprite}

	# Create reusable hover sprite
	_hover_sprite = Sprite2D.new()
	_hover_sprite.texture = _highlight_texture
	_hover_sprite.modulate = Color(1.0, 1.0, 1.0, 0.15)
	_hover_sprite.visible = false
	_hover_sprite.z_index = 9998
	add_child(_hover_sprite)

	# Create reusable selection sprite
	_selection_sprite = Sprite2D.new()
	_selection_sprite.texture = _highlight_texture
	_selection_sprite.modulate = Color(1.0, 1.0, 1.0, 0.25)
	_selection_sprite.visible = false
	_selection_sprite.z_index = 9999
	add_child(_selection_sprite)

	# Create hex border overlay (hidden by default — toggled by debug UI).
	_border_overlay = HexBorderOverlay.new()
	_border_overlay.z_index = 9997
	_border_overlay.visible = false
	add_child(_border_overlay)
	var all_coords: Array[Vector2i] = []
	for coord: Vector2i in sorted_coords:
		all_coords.append(coord)
	_border_overlay.rebuild(all_coords, hex_size, DEPTH_OFFSET)

	# Create highlight border overlay (shown when hexes are highlighted).
	_highlight_border = HexBorderOverlay.new()
	_highlight_border.border_color = Color(1.0, 1.0, 1.0, 0.9)
	_highlight_border.border_width = 2.5
	_highlight_border.z_index = 9998
	_highlight_border.visible = false
	add_child(_highlight_border)


## Update highlight overlays. coords is Dictionary of coord -> Color.
func set_highlights(coords: Dictionary) -> void:
	_clear_highlights()
	for coord: Vector2i in coords:
		var color: Color = coords[coord]
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = _highlight_texture
		sprite.position = HexHelper.hex_to_world(coord, hex_size) + Vector2(0, DEPTH_OFFSET)
		sprite.modulate = color
		# Highlights ride with the objects band so they read as painted on
		# top of the tile but still underneath walls/creatures.
		sprite.z_index = Z_BAND_OBJECTS + coord.y * 3 + 2
		add_child(sprite)
		_highlight_sprites[coord] = sprite

	# Draw white borders around the highlighted hexes.
	if _highlight_border:
		var highlight_coords: Array[Vector2i] = []
		for coord: Vector2i in coords:
			highlight_coords.append(coord)
		if highlight_coords.is_empty():
			_highlight_border.visible = false
		else:
			_highlight_border.rebuild(highlight_coords, hex_size, DEPTH_OFFSET)
			_highlight_border.visible = true


## Clear all highlight overlays.
func clear_highlights() -> void:
	_clear_highlights()


## Show hover effect on a hex.
func set_hover(coord: Vector2i) -> void:
	_hover_sprite.position = HexHelper.hex_to_world(coord, hex_size) + Vector2(0, DEPTH_OFFSET)
	_hover_sprite.visible = true


## Hide hover effect.
func clear_hover() -> void:
	_hover_sprite.visible = false


## Show selection on a hex.
func set_selection(coord: Vector2i) -> void:
	_selection_sprite.position = HexHelper.hex_to_world(coord, hex_size) + Vector2(0, DEPTH_OFFSET)
	_selection_sprite.visible = true


## Hide selection.
func clear_selection() -> void:
	_selection_sprite.visible = false


## Add a spawn-zone tint overlay to a tile at runtime (e.g. from Arcane Anchor).
func add_spawn_overlay(coord: Vector2i) -> void:
	if _spawn_overlays.has(coord):
		return  # Already has an overlay.
	if not _tile_sprites.has(coord):
		return  # No tile sprite to reference.
	var ground_sprite: Sprite2D = _tile_sprites[coord].ground
	var overlay: Sprite2D = Sprite2D.new()
	overlay.texture = ground_sprite.texture
	overlay.position = ground_sprite.position
	overlay.z_index = Z_BAND_GROUND + coord.y
	overlay.modulate = Color(1.0, 0.9, 0.2, 0.3)
	add_child(overlay)
	_spawn_overlays[coord] = overlay


## Toggle hex border lines on/off.
func set_borders_visible(visible_flag: bool) -> void:
	if _border_overlay:
		_border_overlay.visible = visible_flag


## Whether hex borders are currently visible.
func are_borders_visible() -> bool:
	if _border_overlay:
		return _border_overlay.visible
	return false


## Load and cache a texture by path.
func _load_texture(path: String) -> Texture2D:
	if _texture_cache.has(path):
		return _texture_cache[path]
	var tex: Texture2D = load(path) as Texture2D
	_texture_cache[path] = tex
	return tex


## Sort helper: tiles with lower row values draw first (behind).
func _sort_by_row(a: Vector2i, b: Vector2i) -> bool:
	if a.y != b.y:
		return a.y < b.y
	return a.x < b.x


## Remove all highlight overlay sprites.
func _clear_highlights() -> void:
	for coord: Vector2i in _highlight_sprites:
		var sprite: Sprite2D = _highlight_sprites[coord]
		sprite.queue_free()
	_highlight_sprites.clear()
	if _highlight_border:
		_highlight_border.visible = false


## Remove all visual nodes and reset caches.
func _clear_all() -> void:
	_clear_highlights()
	for coord: Vector2i in _spawn_overlays:
		_spawn_overlays[coord].queue_free()
	_spawn_overlays.clear()
	for coord: Vector2i in _tile_sprites:
		var entry: Dictionary = _tile_sprites[coord]
		entry.ground.queue_free()
		if entry.middle != null:
			entry.middle.queue_free()
	_tile_sprites.clear()

	if _hover_sprite:
		_hover_sprite.queue_free()
		_hover_sprite = null
	if _selection_sprite:
		_selection_sprite.queue_free()
		_selection_sprite = null
	if _border_overlay:
		_border_overlay.queue_free()
		_border_overlay = null
	if _highlight_border:
		_highlight_border.queue_free()
		_highlight_border = null
