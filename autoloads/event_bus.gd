## Global signal hub — all cross-system communication goes through here.
## No system directly references another. Emit into the bus, subscribe to what you need.
extends Node

# --- Duel signals ---
signal unit_died(unit: Node, side: String)
signal unit_moved(unit: Node, from: Vector2i, to: Vector2i)
signal attack_resolved(attacker: Node, target: Node, damage: int)
signal guard_intercepted(guard: Node, target: Node, attacker: Node)
signal card_played(card: Resource, player: String)
signal phase_changed(new_phase: String)

# --- Board signals ---
signal tile_landed(tile_type: String, position: int)

# --- Run signals ---
signal king_hp_changed(new_hp: int, delta: int)
signal terrain_event_triggered(event_id: String)
signal run_ended(victory: bool)
