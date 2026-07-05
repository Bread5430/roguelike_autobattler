extends Control

@onready var _resolution_option: OptionButton = $Margin/VBox/ResolutionRow/ResolutionOption
@onready var _fps_option: OptionButton = $Margin/VBox/FpsRow/FpsOption
@onready var _fullscreen_toggle: CheckButton = $Margin/VBox/FullscreenToggle


func _ready() -> void:
	_build_resolution_options()
	_build_fps_options()
	_resolution_option.item_selected.connect(_on_resolution_selected)
	_fps_option.item_selected.connect(_on_fps_selected)
	_fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	refresh_from_settings()


func refresh_from_settings() -> void:
	_select_resolution(SettingsManager.resolution)
	_select_fps(SettingsManager.max_fps)
	_fullscreen_toggle.button_pressed = SettingsManager.window_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


func _build_resolution_options() -> void:
	_resolution_option.clear()
	for res in SettingsManager.RESOLUTION_OPTIONS:
		_resolution_option.add_item("%dx%d" % [res.x, res.y])


func _build_fps_options() -> void:
	_fps_option.clear()
	for fps in SettingsManager.FPS_OPTIONS:
		if fps == 0:
			_fps_option.add_item("Uncapped")
		else:
			_fps_option.add_item("%d FPS" % fps)


func _select_resolution(resolution: Vector2i) -> void:
	for i in SettingsManager.RESOLUTION_OPTIONS.size():
		if SettingsManager.RESOLUTION_OPTIONS[i] == resolution:
			_resolution_option.select(i)
			return
	_resolution_option.select(0)


func _select_fps(fps: int) -> void:
	for i in SettingsManager.FPS_OPTIONS.size():
		if SettingsManager.FPS_OPTIONS[i] == fps:
			_fps_option.select(i)
			return
	_fps_option.select(0)


func _on_resolution_selected(index: int) -> void:
	if index < 0 or index >= SettingsManager.RESOLUTION_OPTIONS.size():
		return
	SettingsManager.set_resolution(SettingsManager.RESOLUTION_OPTIONS[index])


func _on_fps_selected(index: int) -> void:
	if index < 0 or index >= SettingsManager.FPS_OPTIONS.size():
		return
	SettingsManager.set_max_fps(SettingsManager.FPS_OPTIONS[index])


func _on_fullscreen_toggled(enabled: bool) -> void:
	if enabled:
		SettingsManager.set_window_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		SettingsManager.set_window_mode(DisplayServer.WINDOW_MODE_WINDOWED)
