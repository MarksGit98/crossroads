## Draws hex grid border lines as an overlay.
## Added as a child of HexTileRenderer. Toggle visibility to show/hide borders.
## Uses _draw() for efficient batch rendering of all hex outlines.
class_name HexBorderOverlay
extends Node2D

## Line color for hex borders.
var border_color: Color = Color(1.0, 1.0, 1.0, 0.25)

## Line width in pixels.
var border_width: float = 1.0

## Hex size (center to vertex).
var hex_size: float = 60.0

## Depth offset to match tile sprite positioning.
var depth_offset: float = 16.0

## Coordinates to draw borders for.
var hex_coords: Array[Vector2i] = []

## Cached corner offsets (computed once).
var _corners: PackedVector2Array = PackedVector2Array()


## Call after setting hex_size to rebuild corner cache and trigger redraw.
func rebuild(coords: Array[Vector2i], p_hex_size: float, p_depth_offset: float) -> void:
	hex_coords = coords
	hex_size = p_hex_size
	depth_offset = p_depth_offset
	_corners = HexHelper.hex_corner_offsets(hex_size)
	queue_redraw()


func _draw() -> void:
	if _corners.is_empty() or hex_coords.is_empty():
		return

	for coord: Vector2i in hex_coords:
		var center: Vector2 = HexHelper.hex_to_world(coord, hex_size) + Vector2(0, depth_offset)
		# Draw the 6 edges of the hex.
		for i: int in range(6):
			var from: Vector2 = center + _corners[i]
			var to: Vector2 = center + _corners[(i + 1) % 6]
			draw_line(from, to, border_color, border_width, true)
