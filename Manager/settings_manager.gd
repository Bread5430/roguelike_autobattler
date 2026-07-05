extends Node

const SETTINGS_PATH := "user://settings.cfg"

const DEFAULT_MASTER_VOLUME := 1.0
const DEFAULT_MUSIC_VOLUME := 1.0
const DEFAULT_SFX_VOLUME := 1.0
const DEFAULT_WINDOW_MODE := DisplayServer.WINDOW_MODE_WINDOWED
const DEFAULT_RESOLUTION := Vector2i(1280, 720)
const DEFAULT_MAX_FPS := 0
const DEFAULT_PARTICLES_ENABLED := true
const DEFAULT_CAMERA_PAN_SPEED := 200

const REBINDABLE_ACTIONS := [
	"inventory",
	"rotatePlacement",
	"move_up",
	"move_down",
	"move_left",
	"move_right",
	"middle_mouse",
	"rightClick",
	"scroll_up",
	"scroll_down",
]

const ACTION_DISPLAY_NAMES := {
	"inventory": "Inventory",
	"rotatePlacement": "Rotate Placement",
	"move_up": "Move Up",
	"move_down": "Move Down",
	"move_left": "Move Left",
	"move_right": "Move Right",
	"middle_mouse": "Pan Camera (Middle Mouse)",
	"rightClick": "Right Click",
	"scroll_up": "Scroll Up",
	"scroll_down": "Scroll Down",
}

const RESOLUTION_OPTIONS := [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

const FPS_OPTIONS := [0, 30, 60, 120, 144, 240]

var master_volume: float = DEFAULT_MASTER_VOLUME
var music_volume: float = DEFAULT_MUSIC_VOLUME
var sfx_volume: float = DEFAULT_SFX_VOLUME
var window_mode: DisplayServer.WindowMode = DEFAULT_WINDOW_MODE
var resolution: Vector2i = DEFAULT_RESOLUTION
var max_fps: int = DEFAULT_MAX_FPS
var particles_enabled: bool = DEFAULT_PARTICLES_ENABLED
var camera_pan_speed: int = DEFAULT_CAMERA_PAN_SPEED

var _config := ConfigFile.new()
var _default_input_events: Dictionary = {}


func _ready() -> void:
	_store_default_input_events()
	load_settings()
	apply_all()


func _store_default_input_events() -> void:
	for action in REBINDABLE_ACTIONS:
		if not InputMap.has_action(action):
			continue
		var events: Array = []
		for event in InputMap.action_get_events(action):
			events.append(event.duplicate())
		_default_input_events[action] = events


func load_settings() -> void:
	if _config.load(SETTINGS_PATH) != OK:
		return

	master_volume = _config.get_value("audio", "master_volume", DEFAULT_MASTER_VOLUME)
	music_volume = _config.get_value("audio", "music_volume", DEFAULT_MUSIC_VOLUME)
	sfx_volume = _config.get_value("audio", "sfx_volume", DEFAULT_SFX_VOLUME)
	window_mode = _config.get_value("video", "window_mode", DEFAULT_WINDOW_MODE)
	var res_x: int = _config.get_value("video", "resolution_x", DEFAULT_RESOLUTION.x)
	var res_y: int = _config.get_value("video", "resolution_y", DEFAULT_RESOLUTION.y)
	resolution = Vector2i(res_x, res_y)
	max_fps = _config.get_value("video", "max_fps", DEFAULT_MAX_FPS)
	particles_enabled = _config.get_value("game", "particles_enabled", DEFAULT_PARTICLES_ENABLED)
	camera_pan_speed = _config.get_value("game", "camera_pan_speed", DEFAULT_CAMERA_PAN_SPEED)
	_load_control_bindings()


func save_settings() -> void:
	_config.set_value("audio", "master_volume", master_volume)
	_config.set_value("audio", "music_volume", music_volume)
	_config.set_value("audio", "sfx_volume", sfx_volume)
	_config.set_value("video", "window_mode", window_mode)
	_config.set_value("video", "resolution_x", resolution.x)
	_config.set_value("video", "resolution_y", resolution.y)
	_config.set_value("video", "max_fps", max_fps)
	_config.set_value("game", "particles_enabled", particles_enabled)
	_config.set_value("game", "camera_pan_speed", camera_pan_speed)
	_save_control_bindings()
	_config.save(SETTINGS_PATH)


func apply_all() -> void:
	apply_audio()
	apply_video()
	apply_game()


func apply_audio() -> void:
	_set_bus_volume("Master", master_volume)
	_set_bus_volume("Music", music_volume)
	_set_bus_volume("SFX", sfx_volume)


func apply_video() -> void:
	DisplayServer.window_set_mode(window_mode)
	if window_mode == DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_size(resolution)
	Engine.max_fps = max_fps


func apply_game() -> void:
	apply_camera_pan_speed()


func apply_camera_pan_speed() -> void:
	for camera in get_tree().get_nodes_in_group("game_camera"):
		if camera.has_method("set") and "camera_move_speed" in camera:
			camera.camera_move_speed = camera_pan_speed


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_set_bus_volume("Master", master_volume)
	save_settings()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_set_bus_volume("Music", music_volume)
	save_settings()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_set_bus_volume("SFX", sfx_volume)
	save_settings()


func set_window_mode(mode: DisplayServer.WindowMode) -> void:
	window_mode = mode
	apply_video()
	save_settings()


func set_resolution(value: Vector2i) -> void:
	resolution = value
	apply_video()
	save_settings()


func set_max_fps(value: int) -> void:
	max_fps = value
	apply_video()
	save_settings()


func set_particles_enabled(enabled: bool) -> void:
	particles_enabled = enabled
	save_settings()


func set_camera_pan_speed(value: int) -> void:
	camera_pan_speed = maxi(50, value)
	apply_camera_pan_speed()
	save_settings()


func get_action_display_name(action: String) -> String:
	return ACTION_DISPLAY_NAMES.get(action, action)


func get_action_binding_label(action: String) -> String:
	if not InputMap.has_action(action):
		return "Unbound"
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return "Unbound"
	return _event_to_label(events[0])


func rebind_action(action: String, event: InputEvent) -> void:
	if not InputMap.has_action(action):
		return
	var stored := event.duplicate()
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, stored)
	save_settings()


func reset_action_binding(action: String) -> void:
	if not _default_input_events.has(action):
		return
	InputMap.action_erase_events(action)
	for event in _default_input_events[action]:
		InputMap.action_add_event(action, event.duplicate())
	save_settings()


func _set_bus_volume(bus_name: String, linear_volume: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_linear(idx, linear_volume)


func _save_control_bindings() -> void:
	for action in REBINDABLE_ACTIONS:
		if not InputMap.has_action(action):
			continue
		var events := InputMap.action_get_events(action)
		if events.is_empty():
			continue
		var serialized: Array = []
		for event in events:
			serialized.append(_serialize_input_event(event))
		_config.set_value("controls", action, serialized)


func _load_control_bindings() -> void:
	for action in REBINDABLE_ACTIONS:
		if not InputMap.has_action(action):
			continue
		if not _config.has_section_key("controls", action):
			continue
		var serialized: Array = _config.get_value("controls", action, [])
		if serialized.is_empty():
			continue
		InputMap.action_erase_events(action)
		for item in serialized:
			if item is Dictionary:
				var event := _deserialize_input_event(item)
				if event:
					InputMap.action_add_event(action, event)


func _serialize_input_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		return {
			"type": "key",
			"physical_keycode": key_event.physical_keycode,
			"keycode": key_event.keycode,
		}
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		return {
			"type": "mouse",
			"button_index": mouse_event.button_index,
		}
	return {}


func _deserialize_input_event(data: Dictionary) -> InputEvent:
	match data.get("type", ""):
		"key":
			var event := InputEventKey.new()
			event.physical_keycode = int(data.get("physical_keycode", 0))
			event.keycode = int(data.get("keycode", 0))
			return event
		"mouse":
			var event := InputEventMouseButton.new()
			event.button_index = int(data.get("button_index", MOUSE_BUTTON_LEFT))
			return event
	return null


func _event_to_label(event: InputEvent) -> String:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		var keycode := key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
		return OS.get_keycode_string(keycode)
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		match mouse_event.button_index:
			MOUSE_BUTTON_LEFT:
				return "Left Mouse"
			MOUSE_BUTTON_RIGHT:
				return "Right Mouse"
			MOUSE_BUTTON_MIDDLE:
				return "Middle Mouse"
			MOUSE_BUTTON_WHEEL_UP:
				return "Wheel Up"
			MOUSE_BUTTON_WHEEL_DOWN:
				return "Wheel Down"
			_:
				return "Mouse %d" % mouse_event.button_index
	return "Unknown"
