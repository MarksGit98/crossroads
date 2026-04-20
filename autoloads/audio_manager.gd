## Project-wide audio singleton. Owns the music stream, a pool of one-shot
## SFX players, and a per-category mute flag that toggles AudioServer buses.
##
## API:
##   play_music(stream_or_path) / stop_music()
##   play_sfx(event_id, opts)   — opts accepts overrides: {volume_db, pitch}
##   set_music_muted(bool) / set_sfx_muted(bool)
##   is_music_muted() / is_sfx_muted()
##
## Routing:
##   Music plays on the "Music" bus; SFX plays on the "SFX" bus. Both are
##   children of "Master". Buses are created programmatically at startup if
##   they don't already exist in the project's default audio bus layout, so
##   this code works on a fresh clone without editor bus setup.
extends Node


# =============================================================================
# Bus names
# =============================================================================

const BUS_MASTER: StringName = &"Master"
const BUS_MUSIC: StringName = &"Music"
const BUS_SFX: StringName = &"SFX"


# =============================================================================
# Pool sizing
# =============================================================================

## Number of parallel one-shot SFX players. Allocated in a ring buffer so
## rapid-fire effects (e.g. axe piercing multiple enemies) don't cut each
## other off. 12 covers most gameplay bursts without inflating memory.
const SFX_POOL_SIZE: int = 12

## Default crossfade duration when calling play_music() while a track is
## already playing. Half a second is fast enough to feel responsive without
## the abrupt cut of a hard swap.
const MUSIC_CROSSFADE_SEC: float = 0.5


# =============================================================================
# Signals
# =============================================================================

signal music_muted_changed(muted: bool)
signal sfx_muted_changed(muted: bool)


# =============================================================================
# State
# =============================================================================

## Ring buffer of SFX players and the next index to use.
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_cursor: int = 0

## Double-buffered music players for crossfade transitions.
var _music_a: AudioStreamPlayer = null
var _music_b: AudioStreamPlayer = null
## Which of the two players is currently the "active" one (the other sits
## idle or is fading out).
var _music_active: AudioStreamPlayer = null

## Current music stream path (or "" if none). Used by play_music() to
## skip restarting the same track.
var _current_music_path: String = ""


# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	_ensure_buses_exist()
	_build_sfx_pool()
	_build_music_players()


## Create the Music and SFX buses as children of Master if they don't
## already exist. Idempotent — safe to call on every boot regardless of
## what the project's default_bus_layout.tres has.
func _ensure_buses_exist() -> void:
	if AudioServer.get_bus_index(BUS_MUSIC) == -1:
		AudioServer.add_bus()
		var music_idx: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(music_idx, BUS_MUSIC)
		AudioServer.set_bus_send(music_idx, BUS_MASTER)

	if AudioServer.get_bus_index(BUS_SFX) == -1:
		AudioServer.add_bus()
		var sfx_idx: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(sfx_idx, BUS_SFX)
		AudioServer.set_bus_send(sfx_idx, BUS_MASTER)


func _build_sfx_pool() -> void:
	_sfx_pool.resize(SFX_POOL_SIZE)
	for i: int in range(SFX_POOL_SIZE):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = BUS_SFX
		add_child(p)
		_sfx_pool[i] = p


func _build_music_players() -> void:
	_music_a = AudioStreamPlayer.new()
	_music_a.bus = BUS_MUSIC
	add_child(_music_a)
	_music_b = AudioStreamPlayer.new()
	_music_b.bus = BUS_MUSIC
	add_child(_music_b)
	_music_active = _music_a


# =============================================================================
# Music API
# =============================================================================

## Play a music track. Accepts either an AudioStream resource or a res://
## path string that will be loaded. No-op if the requested track is already
## playing. Crossfades from the current track over MUSIC_CROSSFADE_SEC.
func play_music(stream_or_path: Variant, loop: bool = true) -> void:
	var stream: AudioStream = _resolve_stream(stream_or_path)
	if stream == null:
		push_warning("AudioManager.play_music: failed to resolve stream from %s" % stream_or_path)
		return

	# Skip if this exact track is already playing on the active player.
	var path_key: String = _stream_path_key(stream_or_path)
	if _current_music_path == path_key and _music_active and _music_active.playing:
		return
	_current_music_path = path_key

	# Some stream types support a "loop" property — set it if available.
	if loop and "loop" in stream:
		stream.set("loop", true)

	# Pick the inactive player as the new active, fade in. Fade out the
	# previously active player in parallel.
	var new_player: AudioStreamPlayer = _music_b if _music_active == _music_a else _music_a
	var old_player: AudioStreamPlayer = _music_active

	new_player.stream = stream
	new_player.volume_db = -80.0  # start silent, ramp up
	new_player.play()
	_music_active = new_player

	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(new_player, "volume_db", 0.0, MUSIC_CROSSFADE_SEC)
	if old_player and old_player.playing:
		tween.tween_property(old_player, "volume_db", -80.0, MUSIC_CROSSFADE_SEC)
		tween.chain().tween_callback(old_player.stop)


## Stop the currently-playing music track with a quick fade.
func stop_music(fade_out_sec: float = MUSIC_CROSSFADE_SEC) -> void:
	_current_music_path = ""
	if _music_active == null or not _music_active.playing:
		return
	var player: AudioStreamPlayer = _music_active
	var tween: Tween = create_tween()
	tween.tween_property(player, "volume_db", -80.0, fade_out_sec)
	tween.tween_callback(player.stop)


# =============================================================================
# SFX API
# =============================================================================

## Play a one-shot sound effect. For the scaffold phase this accepts a raw
## path or AudioStream directly — later the event registry will let callers
## say `play_sfx(&"axe_throw")` and the manager looks up the file. The
## opts dict supports:
##   "volume_db":    float — per-call trim (default 0.0)
##   "pitch":        float — playback pitch (default 1.0)
##   "pitch_jitter": float — random +/- range added to pitch each call
func play_sfx(stream_or_path: Variant, opts: Dictionary = {}) -> void:
	var stream: AudioStream = _resolve_stream(stream_or_path)
	if stream == null:
		return
	var player: AudioStreamPlayer = _sfx_pool[_sfx_cursor]
	_sfx_cursor = (_sfx_cursor + 1) % SFX_POOL_SIZE

	player.stream = stream
	player.volume_db = opts.get("volume_db", 0.0)
	var base_pitch: float = opts.get("pitch", 1.0)
	var jitter: float = opts.get("pitch_jitter", 0.0)
	if jitter > 0.0:
		base_pitch += randf_range(-jitter, jitter)
	player.pitch_scale = maxf(base_pitch, 0.01)
	player.play()


# =============================================================================
# Mute toggles
# =============================================================================

## Mute / unmute the music bus. Emits music_muted_changed so UI toggles can
## mirror state even if changed from elsewhere (e.g. settings menu).
func set_music_muted(muted: bool) -> void:
	var idx: int = AudioServer.get_bus_index(BUS_MUSIC)
	if idx >= 0:
		AudioServer.set_bus_mute(idx, muted)
	music_muted_changed.emit(muted)


func is_music_muted() -> bool:
	var idx: int = AudioServer.get_bus_index(BUS_MUSIC)
	return idx >= 0 and AudioServer.is_bus_mute(idx)


## Mute / unmute the SFX bus. Same pattern as music.
func set_sfx_muted(muted: bool) -> void:
	var idx: int = AudioServer.get_bus_index(BUS_SFX)
	if idx >= 0:
		AudioServer.set_bus_mute(idx, muted)
	sfx_muted_changed.emit(muted)


func is_sfx_muted() -> bool:
	var idx: int = AudioServer.get_bus_index(BUS_SFX)
	return idx >= 0 and AudioServer.is_bus_mute(idx)


## Convenience toggle: flip music mute state and return the new value.
func toggle_music_muted() -> bool:
	var new_state: bool = not is_music_muted()
	set_music_muted(new_state)
	return new_state


func toggle_sfx_muted() -> bool:
	var new_state: bool = not is_sfx_muted()
	set_sfx_muted(new_state)
	return new_state


# =============================================================================
# Volume (linear 0.0-1.0) — exposed for future settings sliders
# =============================================================================

func set_music_volume(linear_volume: float) -> void:
	var idx: int = AudioServer.get_bus_index(BUS_MUSIC)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear_volume, 0.0, 1.0)))


func set_sfx_volume(linear_volume: float) -> void:
	var idx: int = AudioServer.get_bus_index(BUS_SFX)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear_volume, 0.0, 1.0)))


# =============================================================================
# Internal helpers
# =============================================================================

## Accept either a pre-loaded AudioStream or a res:// path string and
## return the corresponding AudioStream resource (or null on failure).
func _resolve_stream(stream_or_path: Variant) -> AudioStream:
	if stream_or_path is AudioStream:
		return stream_or_path
	if stream_or_path is String:
		var path: String = stream_or_path
		if ResourceLoader.exists(path):
			return load(path) as AudioStream
	return null


## Stable key for "is this the same track as before?" checks. For file
## paths we use the path; for in-memory streams we use their resource path
## (or a numeric ID for generated streams without a path).
func _stream_path_key(stream_or_path: Variant) -> String:
	if stream_or_path is String:
		return stream_or_path
	if stream_or_path is AudioStream:
		var s: AudioStream = stream_or_path
		if s.resource_path != "":
			return s.resource_path
		return str(s.get_instance_id())
	return ""
