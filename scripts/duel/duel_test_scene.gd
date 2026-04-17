## Test scene for the hex grid duel board.
## Generates a procedural map and prints hex info on click.
## Press R to regenerate the map with a new seed.
extends Node2D

@onready var hex_grid: HexGrid = $HexGrid
@onready var creatures_node: Node2D = $Creatures
@onready var info_label: Label = $UILayer/InfoLabel
@onready var border_toggle: Button = $UILayer/BorderToggle
@onready var end_turn_button: Button = $UILayer/EndTurnButton
@onready var turn_label: Label = $UILayer/TurnLabel
@onready var camera: Camera2D = $Camera2D
@onready var player: Player = $Player
@onready var hand: Node2D = $HandLayer/Hand
@onready var action_menu: CreatureActionMenu = $MenuLayer/CreatureActionMenu

## Active gamemode for this duel. Defaults to Team Deathmatch — other modes
## (capture-the-flag, destroy-point, escort/defend payload) will plug in later
## once their objectives and AI behaviors are designed.
var current_gamemode: GamemodeTypes.Mode = GamemodeTypes.DEFAULT_MODE

var _generator: TerrainGenerator = TerrainGenerator.new()
var _current_seed: int = -1
var _interaction_manager: BoardInteractionManager = null
var _turn_manager: TurnManager = null
var _enemy_spawner: EnemySpawner = EnemySpawner.new()
var _combat_count: int = 0

## The duel-wide single source of truth. Built once here and injected into
## every subsystem (Hand, BoardInteractionManager, TurnManager, …). Cards and
## creatures receive it per-action via setup / use_active / can_play calls.
var duel_ctx: DuelContext = DuelContext.new()

## Margins for anchoring the end-turn UI to the bottom-right corner.
const END_TURN_MARGIN_RIGHT: float = 20.0
const END_TURN_MARGIN_BOTTOM: float = 100.0
const END_TURN_WIDTH: float = 150.0
const END_TURN_HEIGHT: float = 50.0
const TURN_LABEL_HEIGHT: float = 30.0
const TURN_LABEL_GAP: float = 5.0


func _ready() -> void:
	print("Duel starting — Mode: %s (%s)" % [
		GamemodeTypes.mode_name(current_gamemode),
		GamemodeTypes.mode_description(current_gamemode),
	])
	_generate_new_map()
	_anchor_end_turn_ui()
	get_viewport().size_changed.connect(_anchor_end_turn_ui)

	# Connect signals
	hex_grid.hex_clicked.connect(_on_hex_clicked)
	hex_grid.hex_hovered.connect(_on_hex_hovered)
	border_toggle.pressed.connect(_on_border_toggle_pressed)
	end_turn_button.pressed.connect(_on_end_turn_pressed)

	# Tell the hex grid where to parent spawned creatures.
	hex_grid.creature_parent = creatures_node

	# Set up the turn manager instance first so we can include it in the context.
	_turn_manager = TurnManager.new()
	add_child(_turn_manager)

	# Build the duel-wide context and inject it into every subsystem.
	duel_ctx.configure(
		player,
		hex_grid,
		_turn_manager,
		hand,
		creatures_node,
		current_gamemode,
	)
	hand.set_duel_context(duel_ctx)

	# Set up the board interaction manager for creature selection and movement.
	_interaction_manager = BoardInteractionManager.new()
	add_child(_interaction_manager)
	_interaction_manager.setup(duel_ctx, action_menu, camera)
	# Start disabled — TurnManager will enable during action phase.
	_interaction_manager.set_enabled(false)

	# Auto-register any creature added to the Creatures node.
	creatures_node.child_entered_tree.connect(_on_creature_child_added)

	# Spawn enemies on the right side of the grid.
	_enemy_spawner.spawn_enemies(_combat_count, hex_grid, creatures_node)

	# Finish wiring the turn manager now that the interaction manager exists.
	_turn_manager.setup(duel_ctx, _interaction_manager)
	_turn_manager.phase_changed.connect(_on_phase_changed)

	# Disable hand auto-draw — TurnManager controls draws now.
	# The hand's _on_deck_ready auto-draw needs to be skipped.
	# We do this by starting combat after a frame (so deck is ready).
	await get_tree().process_frame
	_turn_manager.begin_combat()


## Register newly spawned creatures with the interaction manager.
func _on_creature_child_added(node: Node) -> void:
	# Wait one frame so the creature is fully initialized.
	await get_tree().process_frame
	if node is Creature:
		_interaction_manager.register_creature(node as Creature)


## Anchor the End Turn button and turn label to the bottom-right, above the deck.
func _anchor_end_turn_ui() -> void:
	var screen: Vector2 = get_viewport_rect().size
	var btn_right: float = screen.x - END_TURN_MARGIN_RIGHT
	var btn_left: float = btn_right - END_TURN_WIDTH
	var btn_bottom: float = screen.y - END_TURN_MARGIN_BOTTOM
	var btn_top: float = btn_bottom - END_TURN_HEIGHT

	end_turn_button.position = Vector2(btn_left, btn_top)
	end_turn_button.size = Vector2(END_TURN_WIDTH, END_TURN_HEIGHT)

	var label_bottom: float = btn_top - TURN_LABEL_GAP
	var label_top: float = label_bottom - TURN_LABEL_HEIGHT
	turn_label.position = Vector2(btn_left, label_top)
	turn_label.size = Vector2(END_TURN_WIDTH, TURN_LABEL_HEIGHT)


## Handle End Turn button press.
func _on_end_turn_pressed() -> void:
	_turn_manager.on_end_turn_pressed()


## Update UI when the turn phase changes.
func _on_phase_changed(new_phase: TurnManager.Phase) -> void:
	turn_label.text = _turn_manager.get_phase_name()

	# Show/hide end turn button based on phase.
	match new_phase:
		TurnManager.Phase.ACTION_PHASE:
			end_turn_button.disabled = false
			# Enable hand interaction during action phase.
			hand.set_process_input(true)
			hand.set_process_unhandled_input(true)
		TurnManager.Phase.ENEMY_TURN:
			end_turn_button.disabled = true
			turn_label.text = "Enemy Turn"
		_:
			end_turn_button.disabled = true
			hand.set_process_input(false)
			hand.set_process_unhandled_input(false)


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

	# Don't overwrite highlights when the hand or interaction manager owns them.
	if not hand.is_targeting() and not _interaction_manager.is_busy():
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

	# Scroll to zoom toward mouse cursor
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			# World position under the mouse before zoom.
			var mouse_world_before: Vector2 = camera.get_global_mouse_position()

			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				camera.zoom *= 1.1
			else:
				camera.zoom /= 1.1
			camera.zoom = camera.zoom.clamp(Vector2(0.3, 0.3), Vector2(3.0, 3.0))

			# World position under the mouse after zoom changed.
			var mouse_world_after: Vector2 = camera.get_global_mouse_position()

			# Shift camera so the same world point stays under the cursor.
			camera.position += mouse_world_before - mouse_world_after


func _on_border_toggle_pressed() -> void:
	var new_state: bool = not hex_grid.are_borders_visible()
	hex_grid.set_borders_visible(new_state)
	border_toggle.text = "Hide Hex Borders" if new_state else "Show Hex Borders"
