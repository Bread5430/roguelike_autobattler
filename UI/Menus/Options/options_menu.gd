extends Control

signal back_pressed

enum PANEL_NAME { HUB, GAME, AUDIO, VIDEO, CONTROLS }

@onready var _hub: Control = $PanelStack/Hub
@onready var _game_panel_container: Control = $PanelStack/GamePanel
@onready var _game_panel: Control = $PanelStack/GamePanel/Margin/VBox/GameOptions
@onready var _audio_panel_container: Control = $PanelStack/AudioPanel
@onready var _audio_panel: Control = $PanelStack/AudioPanel/Margin/VBox/AudioOptions
@onready var _video_panel_container: Control = $PanelStack/VideoPanel
@onready var _video_panel: Control = $PanelStack/VideoPanel/Margin/VBox/VideoOptions
@onready var _controls_panel_container: Control = $PanelStack/ControlsPanel
@onready var _controls_panel: Control = $PanelStack/ControlsPanel/Margin/VBox/ControlsOptions

@onready var _game_button: Button = $PanelStack/Hub/Margin/VBox/GameButton
@onready var _audio_button: Button = $PanelStack/Hub/Margin/VBox/AudioButton
@onready var _video_button: Button = $PanelStack/Hub/Margin/VBox/VideoButton
@onready var _controls_button: Button = $PanelStack/Hub/Margin/VBox/ControlsButton
@onready var _hub_back_button: Button = $PanelStack/Hub/Margin/VBox/HubBackButton

@onready var _game_back_button: Button = $PanelStack/GamePanel/Margin/VBox/GameBackButton
@onready var _audio_back_button: Button = $PanelStack/AudioPanel/Margin/VBox/AudioBackButton
@onready var _video_back_button: Button = $PanelStack/VideoPanel/Margin/VBox/VideoBackButton
@onready var _controls_back_button: Button = $PanelStack/ControlsPanel/Margin/VBox/ControlsBackButton


func _ready() -> void:
	_game_button.pressed.connect(func(): show_panel(PANEL_NAME.GAME))
	_audio_button.pressed.connect(func(): show_panel(PANEL_NAME.AUDIO))
	_video_button.pressed.connect(func(): show_panel(PANEL_NAME.VIDEO))
	_controls_button.pressed.connect(func(): show_panel(PANEL_NAME.CONTROLS))
	_hub_back_button.pressed.connect(_on_back_from_hub)
	_game_back_button.pressed.connect(func(): show_panel(PANEL_NAME.HUB))
	_audio_back_button.pressed.connect(func(): show_panel(PANEL_NAME.HUB))
	_video_back_button.pressed.connect(func(): show_panel(PANEL_NAME.HUB))
	_controls_back_button.pressed.connect(func(): show_panel(PANEL_NAME.HUB))
	show_panel(PANEL_NAME.HUB)


func show_panel(panel: PANEL_NAME) -> void:
	_hub.visible = panel == PANEL_NAME.HUB
	_game_panel_container.visible = panel == PANEL_NAME.GAME
	_audio_panel_container.visible = panel == PANEL_NAME.AUDIO
	_video_panel_container.visible = panel == PANEL_NAME.VIDEO
	_controls_panel_container.visible = panel == PANEL_NAME.CONTROLS
	if panel == PANEL_NAME.GAME and _game_panel.has_method("refresh_from_settings"):
		_game_panel.refresh_from_settings()
	if panel == PANEL_NAME.AUDIO and _audio_panel.has_method("refresh_from_settings"):
		_audio_panel.refresh_from_settings()
	if panel == PANEL_NAME.VIDEO and _video_panel.has_method("refresh_from_settings"):
		_video_panel.refresh_from_settings()


func show_hub_only() -> void:
	show_panel(PANEL_NAME.HUB)


func _on_back_from_hub() -> void:
	back_pressed.emit()
