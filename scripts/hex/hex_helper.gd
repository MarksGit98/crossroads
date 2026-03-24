## Pure static hex math utilities.
## Uses offset coordinates for storage/display, axial/cube for all math.
## Offset = "even-q" vertical layout (flat-top hexagons, even columns shifted down).
class_name HexHelper
extends RefCounted

# --- Coordinate Conversions ---

## Convert offset (col, row) to axial (q, r).
static func offset_to_axial(coord: Vector2i) -> Vector2i:
	var q: int = coord.x
	var r: int = coord.y - (coord.x + (coord.x & 1)) / 2
	return Vector2i(q, r)


## Convert axial (q, r) to offset (col, row).
static func axial_to_offset(axial: Vector2i) -> Vector2i:
	var col: int = axial.x
	var row: int = axial.y + (axial.x + (axial.x & 1)) / 2
	return Vector2i(col, row)


## Convert axial (q, r) to cube (q, r, s) as Vector3i.
static func axial_to_cube(axial: Vector2i) -> Vector3i:
	return Vector3i(axial.x, axial.y, -axial.x - axial.y)


## Convert cube (q, r, s) to axial (q, r).
static func cube_to_axial(cube: Vector3i) -> Vector2i:
	return Vector2i(cube.x, cube.y)


# --- Distance ---

## Hex distance between two offset coordinates.
static func hex_distance(a: Vector2i, b: Vector2i) -> int:
	var ac: Vector3i = axial_to_cube(offset_to_axial(a))
	var bc: Vector3i = axial_to_cube(offset_to_axial(b))
	return cube_distance(ac, bc)


## Distance between two cube coordinates.
static func cube_distance(a: Vector3i, b: Vector3i) -> int:
	return (absi(a.x - b.x) + absi(a.y - b.y) + absi(a.z - b.z)) / 2


# --- Neighbors ---

## Direction vectors for even and odd columns (offset coordinates, flat-top).
const EVEN_COL_DIRECTIONS: Array[Vector2i] = [
	Vector2i(+1,  0), Vector2i(+1, -1), Vector2i( 0, -1),
	Vector2i(-1, -1), Vector2i(-1,  0), Vector2i( 0, +1),
]

const ODD_COL_DIRECTIONS: Array[Vector2i] = [
	Vector2i(+1, +1), Vector2i(+1,  0), Vector2i( 0, -1),
	Vector2i(-1,  0), Vector2i(-1, +1), Vector2i( 0, +1),
]


## Return all 6 neighbor coordinates of a hex (offset coords).
static func hex_neighbors(coord: Vector2i) -> Array[Vector2i]:
	var dirs: Array[Vector2i]
	if coord.x & 1 == 0:
		dirs = EVEN_COL_DIRECTIONS
	else:
		dirs = ODD_COL_DIRECTIONS

	var neighbors: Array[Vector2i] = []
	for dir: Vector2i in dirs:
		neighbors.append(coord + dir)
	return neighbors


## Return all hexes at exactly `radius` distance from center (a ring).
static func hex_ring(center: Vector2i, radius: int) -> Array[Vector2i]:
	if radius == 0:
		return [center]

	var results: Array[Vector2i] = []
	var center_axial: Vector2i = offset_to_axial(center)
	var center_cube: Vector3i = axial_to_cube(center_axial)

	# All hexes at exactly this cube distance
	for q: int in range(-radius, radius + 1):
		for r: int in range(maxi(-radius, -q - radius), mini(radius, -q + radius) + 1):
			var s: int = -q - r
			var cube: Vector3i = center_cube + Vector3i(q, r, s)
			if cube_distance(center_cube, cube) == radius:
				results.append(axial_to_offset(cube_to_axial(cube)))
	return results


## Return all hexes within `radius` of center (filled circle).
static func hex_range(center: Vector2i, radius: int) -> Array[Vector2i]:
	var results: Array[Vector2i] = []
	var center_axial: Vector2i = offset_to_axial(center)
	var center_cube: Vector3i = axial_to_cube(center_axial)

	for q: int in range(-radius, radius + 1):
		for r: int in range(maxi(-radius, -q - radius), mini(radius, -q + radius) + 1):
			var s: int = -q - r
			var axial: Vector2i = cube_to_axial(center_cube + Vector3i(q, r, s))
			results.append(axial_to_offset(axial))
	return results


# --- Line Drawing (for LOS) ---

## Linearly interpolate between two cube coordinates, returning each hex along the line.
static func cube_linedraw(a_cube: Vector3i, b_cube: Vector3i) -> Array[Vector3i]:
	var n: int = cube_distance(a_cube, b_cube)
	if n == 0:
		return [a_cube]

	var results: Array[Vector3i] = []
	for i: int in range(n + 1):
		var t: float = float(i) / float(n)
		var q: float = lerpf(float(a_cube.x), float(b_cube.x), t)
		var r: float = lerpf(float(a_cube.y), float(b_cube.y), t)
		var s: float = lerpf(float(a_cube.z), float(b_cube.z), t)
		results.append(_cube_round(q, r, s))
	return results


## Round fractional cube coordinates to the nearest hex.
static func _cube_round(q: float, r: float, s: float) -> Vector3i:
	var rq: int = roundi(q)
	var rr: int = roundi(r)
	var rs: int = roundi(s)

	var q_diff: float = absf(float(rq) - q)
	var r_diff: float = absf(float(rr) - r)
	var s_diff: float = absf(float(rs) - s)

	if q_diff > r_diff and q_diff > s_diff:
		rq = -rr - rs
	elif r_diff > s_diff:
		rr = -rq - rs
	else:
		rs = -rq - rr

	return Vector3i(rq, rr, rs)


## Draw a line between two offset coordinates, return all hexes along the path.
static func hex_linedraw(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var a_cube: Vector3i = axial_to_cube(offset_to_axial(a))
	var b_cube: Vector3i = axial_to_cube(offset_to_axial(b))
	var cubes: Array[Vector3i] = cube_linedraw(a_cube, b_cube)

	var result: Array[Vector2i] = []
	for c: Vector3i in cubes:
		result.append(axial_to_offset(cube_to_axial(c)))
	return result


# --- Pixel Coordinate Conversions (flat-top hex, even-q offset) ---

## Convert offset hex coordinate to pixel center position.
## hex_size = distance from center to any vertex (outer radius).
static func hex_to_world(coord: Vector2i, hex_size: float) -> Vector2:
	var x: float = hex_size * 1.5 * coord.x
	var y: float = hex_size * sqrt(3.0) * (coord.y + 0.5 * (coord.x & 1))
	return Vector2(x, y)


## Convert pixel position to the nearest offset hex coordinate.
static func world_to_hex(world_pos: Vector2, hex_size: float) -> Vector2i:
	# Convert pixel to fractional axial coordinates (flat-top)
	var q: float = (2.0 / 3.0 * world_pos.x) / hex_size
	var r: float = (-1.0 / 3.0 * world_pos.x + sqrt(3.0) / 3.0 * world_pos.y) / hex_size
	var s: float = -q - r
	# Round to nearest hex in cube space, then convert to offset
	var cube: Vector3i = _cube_round(q, r, s)
	return axial_to_offset(cube_to_axial(cube))


## Return the 6 vertex positions of a flat-top hex centered at the origin.
static func hex_corner_offsets(hex_size: float) -> PackedVector2Array:
	var corners: PackedVector2Array = PackedVector2Array()
	for i: int in range(6):
		var angle_deg: float = 60.0 * i
		var angle_rad: float = deg_to_rad(angle_deg)
		corners.append(Vector2(hex_size * cos(angle_rad), hex_size * sin(angle_rad)))
	return corners
