## Tracks restrictions from creatures, hex tiles, and persistent card effects
## that limit which cards the player can play. Queried by Card.can_play()
## and updated as cards resolve / as sources enter or leave the board.
##
## Restrictions are keyed by a unique source id so the originator can remove
## them cleanly on death / expiration. Per-turn caps are enforced by counting
## matching cards played since the last on_turn_ended() call.
class_name PlayRestrictionRegistry
extends RefCounted


# =============================================================================
# Signals
# =============================================================================

## Emitted whenever a restriction is added or removed, so any UI listening
## (e.g. greying out unplayable cards) can refresh.
signal restrictions_changed


# =============================================================================
# State
# =============================================================================

## Active restrictions keyed by source id. Each value is a filter/limit dict
## matching the schema documented on add_restriction().
var _restrictions: Dictionary = {}

## CardData instances played this turn. Cleared at on_turn_ended().
var _cards_played_this_turn: Array[CardData] = []


# =============================================================================
# Public API — registration
# =============================================================================

## Register a restriction that affects future can_play checks.
##
## id: unique identifier used for later removal (e.g. "silence_aura#42",
##     "terrain_ward_(3,4)", "card_echoing_pulse").
##
## restriction: a Dictionary with any of the following optional fields:
##     "card_type_filter":  CardTypes.CardType  — restriction only applies to
##                          cards of this type; omit / -1 = all card types
##     "card_class_filter": CardTypes.Class     — restricts by class; -1 = all
##     "card_id_filter":    String              — restrict only a specific card
##                          by its CardData.id; "" = all
##     "max_per_turn":      int                 — cap on matching plays per turn
##                          (-1 = no cap, 0 = fully forbidden while active)
##     "expires_at_turn_end": bool              — if true, removed automatically
##                          at end of the player's turn (default true)
##     "description":       String              — human-readable label for UI
##                          tooltips (optional)
##
## If an id already exists it is overwritten — this lets a source refresh
## its own restriction without duplicating entries.
func add_restriction(id: String, restriction: Dictionary) -> void:
	_restrictions[id] = restriction
	restrictions_changed.emit()


## Remove a restriction by its source id. No-op if not present.
func remove_restriction(id: String) -> void:
	if _restrictions.erase(id):
		restrictions_changed.emit()


## Remove every restriction whose id starts with the given prefix — convenient
## for bulk-clearing effects from a single source (e.g. a creature dying might
## remove every "creature#<uid>:*" restriction it registered).
func remove_restrictions_with_prefix(prefix: String) -> void:
	var to_erase: Array[String] = []
	for id: String in _restrictions.keys():
		if id.begins_with(prefix):
			to_erase.append(id)
	for id: String in to_erase:
		_restrictions.erase(id)
	if not to_erase.is_empty():
		restrictions_changed.emit()


## Whether a restriction with the given id currently exists.
func has_restriction(id: String) -> bool:
	return _restrictions.has(id)


## Read-only snapshot of the active restriction list (for UI / debugging).
func get_active_restrictions() -> Array:
	return _restrictions.values().duplicate()


# =============================================================================
# Public API — gameplay hooks
# =============================================================================

## Record that the given card was played this turn. Called by Card.play()
## after the card is successfully committed.
func record_card_played(data: CardData) -> void:
	if data:
		_cards_played_this_turn.append(data)


## Check whether a card can be played under the currently active restrictions.
## Returns true if no restriction vetoes the play.
func can_play_card(data: CardData) -> bool:
	if data == null:
		return false
	for id: String in _restrictions.keys():
		var r: Dictionary = _restrictions[id]
		if not _matches(r, data):
			continue
		var cap: int = r.get("max_per_turn", -1)
		if cap == 0:
			# Flat ban while this restriction is active.
			return false
		if cap > 0 and _count_matching_played(r) >= cap:
			# Per-turn cap reached.
			return false
	return true


## Number of cards played this turn that match the given restriction filters.
func count_played_this_turn(data: CardData = null) -> int:
	if data == null:
		return _cards_played_this_turn.size()
	var n: int = 0
	for played: CardData in _cards_played_this_turn:
		if played == data:
			n += 1
	return n


## Called by TurnManager / Player at end of turn. Clears per-turn counters
## and removes any restrictions flagged as expiring at turn end.
func on_turn_ended() -> void:
	_cards_played_this_turn.clear()
	var expired: Array[String] = []
	for id: String in _restrictions.keys():
		if _restrictions[id].get("expires_at_turn_end", true):
			expired.append(id)
	for id: String in expired:
		_restrictions.erase(id)
	if not expired.is_empty():
		restrictions_changed.emit()


# =============================================================================
# Internal helpers
# =============================================================================

## Whether a given restriction's filters match a card.
func _matches(r: Dictionary, data: CardData) -> bool:
	var type_filter: int = r.get("card_type_filter", -1)
	if type_filter >= 0 and data.card_type != type_filter:
		return false
	var class_filter: int = r.get("card_class_filter", -1)
	if class_filter >= 0 and data.card_class != class_filter:
		return false
	var id_filter: String = r.get("card_id_filter", "")
	if id_filter != "" and data.id != id_filter:
		return false
	return true


## Count of cards played this turn that match the given restriction.
func _count_matching_played(r: Dictionary) -> int:
	var n: int = 0
	for played: CardData in _cards_played_this_turn:
		if _matches(r, played):
			n += 1
	return n
