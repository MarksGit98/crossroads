## Index of all DuelDeployable instances currently on the board. Queried by
## movement hooks ("what's on this hex?"), effect dispatch ("who owns this
## trap?"), UI ("how many axes does the player have deployed?"), and AI.
##
## Owned by DuelContext — one registry per duel. Subsystems should never
## track deployables in their own ad hoc structures; always go through this.
class_name DeployableRegistry
extends RefCounted


# =============================================================================
# Signals
# =============================================================================

signal deployable_added(d: DuelDeployable)
signal deployable_removed(d: DuelDeployable)


# =============================================================================
# Internal storage
# =============================================================================

## Master list of all deployables, in add order.
var _all: Array[DuelDeployable] = []

## Fast hex lookup: Vector2i -> Array[DuelDeployable] on that hex. Multiple
## deployables can share a hex (e.g. a trap + a terrain modifier).
var _by_hex: Dictionary = {}


# =============================================================================
# Mutation
# =============================================================================

## Register a deployable. Called by DuelDeployable.deploy() / throw_to()
## after the entity is already placed at its hex_position and parented in
## the scene. No-op if already registered.
func add(d: DuelDeployable) -> void:
	if d == null or d in _all:
		return
	_all.append(d)
	var bucket: Array = _by_hex.get(d.hex_position, [])
	bucket.append(d)
	_by_hex[d.hex_position] = bucket
	deployable_added.emit(d)


## Deregister a deployable. Called by DuelDeployable.pick_up() / destroy().
## No-op if not registered.
func remove(d: DuelDeployable) -> void:
	if d == null:
		return
	var idx: int = _all.find(d)
	if idx < 0:
		return
	_all.remove_at(idx)
	if _by_hex.has(d.hex_position):
		var bucket: Array = _by_hex[d.hex_position]
		bucket.erase(d)
		if bucket.is_empty():
			_by_hex.erase(d.hex_position)
	deployable_removed.emit(d)


## Move a deployable from its old hex to a new one, keeping indexes in sync.
## Used when a deployable gets pushed, pulled, or otherwise displaced. Does
## NOT animate or update world position — callers handle the visual side.
func relocate(d: DuelDeployable, new_hex: Vector2i) -> void:
	if d == null or not (d in _all):
		return
	if d.hex_position == new_hex:
		return
	# Remove from old bucket.
	if _by_hex.has(d.hex_position):
		var old_bucket: Array = _by_hex[d.hex_position]
		old_bucket.erase(d)
		if old_bucket.is_empty():
			_by_hex.erase(d.hex_position)
	# Add to new bucket.
	d.hex_position = new_hex
	var new_bucket: Array = _by_hex.get(new_hex, [])
	new_bucket.append(d)
	_by_hex[new_hex] = new_bucket


# =============================================================================
# Queries
# =============================================================================

## All deployables on the board, in add order.
func all() -> Array[DuelDeployable]:
	return _all.duplicate()


## Deployables currently resting on a specific hex.
func at_hex(coord: Vector2i) -> Array[DuelDeployable]:
	if not _by_hex.has(coord):
		return []
	var typed: Array[DuelDeployable] = []
	for d: DuelDeployable in _by_hex[coord]:
		typed.append(d)
	return typed


## All deployables owned by the given creature (axes the Axed Marauder
## threw, traps a creature set, etc).
func owned_by(creature: Creature) -> Array[DuelDeployable]:
	var result: Array[DuelDeployable] = []
	if creature == null:
		return result
	for d: DuelDeployable in _all:
		if d.owner_creature == creature:
			result.append(d)
	return result


## All deployables of a given type (deployable_id). Use for "how many axes
## exist on the board right now?" checks.
func of_type(type_id: String) -> Array[DuelDeployable]:
	var result: Array[DuelDeployable] = []
	for d: DuelDeployable in _all:
		if d.deployable_id == type_id:
			result.append(d)
	return result


## All deployables owned by a side (&"player" / &"enemy").
func owned_by_side(side: StringName) -> Array[DuelDeployable]:
	var result: Array[DuelDeployable] = []
	for d: DuelDeployable in _all:
		if d.owner_side == side:
			result.append(d)
	return result


## Count deployables of a given type owned by a specific creature. Used by
## creature.deployable_charges tracking: "how many axes has this marauder
## thrown that are still out there?"
func count_of_type_owned_by(type_id: String, creature: Creature) -> int:
	var n: int = 0
	for d: DuelDeployable in _all:
		if d.deployable_id == type_id and d.owner_creature == creature:
			n += 1
	return n
