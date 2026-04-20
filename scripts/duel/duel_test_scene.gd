## Test scene for the hex grid duel board.
## Generates a procedural map and prints hex info on click.
## Press R to regenerate the map with a new seed.
extends Node2D

@onready var hex_grid: HexGrid = $HexGrid
@onready var creatures_node: Node2D = $Creatures
@onready var info_label: Label = $UILayer/InfoLabel
@onready var border_toggle: Button = $UILayer/BorderToggle
@onready var dev_mode_toggle: Button = $UILayer/DevModeToggle
@onready var end_turn_button: Button = $UILayer/EndTurnButton
@onready var turn_label: Label = $UILayer/TurnLabel
@onready var camera: Camera2D = $Camera2D
@onready var player: Player = $Player
@onready var hand: Node2D = $HandLayer/Hand
@onready var action_menu: CreatureActionMenu = $MenuLayer/CreatureActionMenu
@onready var deck_node: Deck = $DeckLayer/Deck
@onready var discard_pile_display: CardPileDisplay = $DeckLayer/DiscardPile
@onready var graveyard_pile_display: CardPileDisplay = $DeckLayer/GraveyardPile

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

## Background music track that starts playing when the duel begins. Swap
## this path to change the track for this specific scene without touching
## AudioManager. Later we'll drive this from gamemode / boss state.
const BG_MUSIC_PATH: String = "res://assets/sounds/bg_music/The Sky of our Ancestors.mp3"

## Audio mute toggle HUD, spawned at _ready and anchored to the top-right.
const AUDIO_CONTROLS_HUD_SCENE: PackedScene = preload("res://scenes/ui/audio_controls_hud.tscn")

## Developer-mode banner, shown while DevMode is toggled on (F9). Lives in
## its own CanvasLayer; hidden by default.
const DEV_MODE_HUD_SCENE: PackedScene = preload("res://scenes/ui/dev_mode_hud.tscn")

## Margins for anchoring the end-turn UI to the bottom-right corner.
const END_TURN_MARGIN_RIGHT: float = 20.0
const END_TURN_MARGIN_BOTTOM: float = 100.0
const END_TURN_WIDTH: float = 150.0
const END_TURN_HEIGHT: float = 50.0
const TURN_LABEL_HEIGHT: float = 30.0
const TURN_LABEL_GAP: float = 5.0


func _ready() -> void:
	_spawn_audio_controls_hud()
	_spawn_dev_mode_hud()
	_start_duel_music()
	_wire_pile_displays()
	_anchor_pile_displays()
	get_viewport().size_changed.connect(_anchor_pile_displays)
	print("Duel starting — Mode: %s (%s)" % [
		GamemodeTypes.mode_name(current_gamemode),
		GamemodeTypes.mode_description(current_gamemode),
	])
	# Enable y_sort_enabled on the creatures parent so same-z creature
	# sprites (e.g. two creatures at the same row during a movement
	# animation) sort deterministically by world y position. Secondary
	# precaution alongside our row-based z_index scheme.
	if creatures_node:
		creatures_node.y_sort_enabled = true
	_generate_new_map()
	_anchor_end_turn_ui()
	get_viewport().size_changed.connect(_anchor_end_turn_ui)

	# Connect signals
	hex_grid.hex_clicked.connect(_on_hex_clicked)
	hex_grid.hex_hovered.connect(_on_hex_hovered)
	border_toggle.pressed.connect(_on_border_toggle_pressed)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	# Dev mode toggle button — mirrors the global DevMode autoload flag so
	# the user can flip it with a click OR with F9. button_pressed.set syncs
	# the visual toggle state, and we listen to DevMode.changed so keyboard
	# toggles also update the button.
	dev_mode_toggle.toggled.connect(_on_dev_mode_toggle_changed)
	DevMode.changed.connect(_on_dev_mode_state_synced)
	_on_dev_mode_state_synced(DevMode.enabled)

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


## Register newly spawned creatures with the interaction manager and wire
## up graveyard routing for friendly units.
func _on_creature_child_added(node: Node) -> void:
	# Wait one frame so the creature is fully initialized.
	await get_tree().process_frame
	if node is Creature:
		var creature: Creature = node as Creature
		_interaction_manager.register_creature(creature)

		# Route friendly-creature deaths into the player's graveyard pile.
		# Enemies aren't from the player's deck, so their deaths don't
		# populate it — leave a hook open for future enemy-side graveyards.
		if not creature is EnemyCreature:
			if not creature.died.is_connected(_on_friendly_creature_died):
				creature.died.connect(_on_friendly_creature_died)


## When a friendly creature dies, add its source CardData to the deck's
## graveyard pile. The card may also already be in the discard pile (it
## was played earlier to summon the creature) — both are valid; discard
## tracks "was played" and graveyard tracks "creature died".
func _on_friendly_creature_died(creature: Creature) -> void:
	if creature == null or creature.card_data == null:
		return
	var deck: Deck = _find_player_deck()
	if deck:
		deck.add_to_graveyard(creature.card_data)


## Scene-tree lookup for the Deck node. Separate helper because the deck
## sits in a CanvasLayer and isn't on a direct @onready path in this file.
func _find_player_deck() -> Deck:
	var deck_layer: Node = get_node_or_null("DeckLayer")
	if deck_layer == null:
		return null
	return deck_layer.get_node_or_null("Deck") as Deck


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

	# Only paint inspect-highlights on EMPTY hexes and only when nothing
	# else owns the highlight layer (hand targeting, move/attack targeting,
	# selected-creature outline). For creature-occupied hexes the board
	# interaction manager handles its own "selected creature" highlight
	# so we don't stomp over it here.
	if hand.is_targeting() or _interaction_manager.is_busy():
		return
	if tile.is_occupied():
		return

	var highlights: Dictionary = {}
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


## Called when the user clicks the dev-mode toggle button. Routes through
## the global DevMode autoload so the F9 shortcut and the in-scene button
## share the same source of truth.
func _on_dev_mode_toggle_changed(pressed: bool) -> void:
	DevMode.set_enabled(pressed)


## Called when DevMode.changed fires (e.g. F9 flipped the state). Updates
## the button's visual toggle state + label so the UI always mirrors the
## real flag, regardless of who changed it.
func _on_dev_mode_state_synced(enabled: bool) -> void:
	if dev_mode_toggle:
		# Use button_pressed (not call pressed()) so we don't re-emit toggled.
		if dev_mode_toggle.button_pressed != enabled:
			dev_mode_toggle.set_pressed_no_signal(enabled)
		dev_mode_toggle.text = "Dev Mode: ON" if enabled else "Dev Mode: OFF"


# =============================================================================
# Audio
# =============================================================================

## Instantiate the music / SFX toggle HUD and park it in a dedicated
## CanvasLayer so it renders on top of everything and isn't affected by
## the camera transform.
func _spawn_audio_controls_hud() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 110  # above gameplay UI layers but below full-screen modals
	add_child(layer)
	var hud: AudioControlsHUD = AUDIO_CONTROLS_HUD_SCENE.instantiate()
	layer.add_child(hud)


## Instantiate the dev-mode banner. Stays hidden unless DevMode.enabled
## is true; DevMode is toggled with F9 anywhere in the game.
func _spawn_dev_mode_hud() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 111  # one notch above audio HUD so it can't be covered
	add_child(layer)
	var hud: DevModeHUD = DEV_MODE_HUD_SCENE.instantiate()
	layer.add_child(hud)


# =============================================================================
# Card piles — deck + discard + graveyard anchored to the bottom-right
# =============================================================================

## Each CardPileDisplay (discard, graveyard) needs:
##   1. A deck reference so its count label observes the right pile signals.
##   2. A texture for its icon (assigned declaratively in the tscn, but
##      we fallback-assign here in case a scene instance forgot).
func _wire_pile_displays() -> void:
	if discard_pile_display:
		if discard_pile_display.icon_texture == null:
			discard_pile_display.icon_texture = load("res://assets/ui/piles/discard_pile.png")
		discard_pile_display.set_deck(deck_node)
	if graveyard_pile_display:
		if graveyard_pile_display.icon_texture == null:
			graveyard_pile_display.icon_texture = load("res://assets/ui/piles/graveyard.png")
		graveyard_pile_display.set_deck(deck_node)


## Anchor the discard + graveyard displays to the left of the deck, stacked
## horizontally along the bottom-right. Deck anchors itself; we stack the
## other two at ~120px intervals moving leftward.
const PILE_SPACING: float = 120.0

func _anchor_pile_displays() -> void:
	var screen: Vector2 = get_viewport_rect().size
	# Match Deck.MARGIN_RIGHT = 60, MARGIN_BOTTOM = 70 (those are consts
	# inside Deck itself — we duplicate the numbers here to stack relative
	# to the deck's position).
	var deck_x: float = screen.x - 60.0
	var y: float = screen.y - 70.0
	if discard_pile_display:
		discard_pile_display.position = Vector2(deck_x - PILE_SPACING, y)
	if graveyard_pile_display:
		graveyard_pile_display.position = Vector2(deck_x - 2.0 * PILE_SPACING, y)


## Kick off the duel background track. AudioManager crossfades automatically
## and skips the call if the same track is already playing (so resuming from
## a paused duel doesn't restart from frame 0).
func _start_duel_music() -> void:
	AudioManager.play_music(BG_MUSIC_PATH)
