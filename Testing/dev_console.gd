extends CanvasLayer
class_name DevConsole

# Developer Console
# Press ` (backtick/tilde key) to toggle

@export var toggle_key : Key = KEY_QUOTELEFT  # ` key (backtick/tilde)
@export var max_log_lines : int = 100
@export var console_height_ratio : float = 0.4  # 40% of screen height

# UI References
var console_panel: Panel
var output_label: RichTextLabel
var input_line: LineEdit
var is_visible: bool = false

# Command history
var command_history: Array[String] = []
var history_index: int = -1
var log_text: String = ""

# Reference to game nodes for commands
var map_manager: Node2D
var camera: Camera2D

func _ready():
	layer = 100
	# Build the console UI
	setup_console_ui()
	hide_console()
	
	# Find important game nodes
	find_game_nodes()
	
	# Print welcome message
	log_message("=== Developer Console ===")
	log_message("Type 'help' for available commands")
	log_message("Press ` to toggle console")

func setup_console_ui():
	"""Create the console UI elements"""
	# Main panel container
	console_panel = Panel.new()
	console_panel.name = "ConsolePanel"
	add_child(console_panel)
	
	# Set panel size and position
	console_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	console_panel.position = Vector2.ZERO
	console_panel.size = Vector2(
		get_viewport().get_visible_rect().size.x,
		get_viewport().get_visible_rect().size.y * console_height_ratio
	)
	
	# Create a VBoxContainer for layout
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
	console_panel.add_child(vbox)
	
	# Output area (RichTextLabel for colored text)
	output_label = RichTextLabel.new()
	output_label.bbcode_enabled = true
	output_label.scroll_following = true
	output_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output_label.add_theme_color_override("default_color", Color.WHITE)
	output_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	vbox.add_child(output_label)
	
	# Input area (HBoxContainer with label and line edit)
	var input_container = HBoxContainer.new()
	input_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(input_container)
	
	# Input prompt label
	var prompt_label = Label.new()
	prompt_label.text = " > "
	input_container.add_child(prompt_label)
	
	# Input line edit
	input_line = LineEdit.new()
	input_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_line.placeholder_text = "Enter command..."
	input_line.text_submitted.connect(_on_command_submitted)
	input_container.add_child(input_line)
	
	# Style the console (dark theme)
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	style_box.border_color = Color(0.3, 0.3, 0.3, 1.0)
	style_box.set_border_width_all(2)
	console_panel.add_theme_stylebox_override("panel", style_box)

func find_game_nodes():
	"""Find references to important game nodes"""
	# Find map manager
	map_manager = get_tree().root.find_child("MapManager", true, false)
	if not map_manager:
		map_manager = get_tree().root.find_child("Map", true, false)
	
	# Find camera
	camera = get_viewport().get_camera_2d()

func _input(event: InputEvent):
	# Toggle console with backtick key
	if event is InputEventKey and event.pressed and event.keycode == toggle_key:
		toggle_console()
		get_viewport().set_input_as_handled()
	
	# Command history navigation (up/down arrows)
	if is_visible and event is InputEventKey and event.pressed:
		if event.keycode == KEY_UP:
			navigate_history(-1)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_DOWN:
			navigate_history(1)
			get_viewport().set_input_as_handled()

func toggle_console():
	"""Toggle console visibility"""
	if is_visible:
		hide_console()
	else:
		show_console()

func show_console():
	"""Show the console"""
	is_visible = true
	console_panel.show()
	input_line.grab_focus()
	# Pause game input but not rendering
	get_tree().paused = false

func hide_console():
	"""Hide the console"""
	is_visible = false
	console_panel.hide()
	input_line.release_focus()

func log_message(message: String, color: String = "white"):
	"""Add a message to the console output"""
	var timestamp = Time.get_time_string_from_system()
	var formatted_message = "[color=%s][%s] %s[/color]\n" % [color, timestamp, message]
	log_text += formatted_message
	
	# Trim log if too long
	var lines = log_text.split("\n")
	if lines.size() > max_log_lines:
		lines = lines.slice(lines.size() - max_log_lines, lines.size())
		log_text = "\n".join(lines)
	
	output_label.text = log_text

func _on_command_submitted(command_text: String):
	"""Handle command submission"""
	if command_text.strip_edges().is_empty():
		return
	
	# Log the command
	log_message("> " + command_text, "yellow")
	
	# Add to history
	command_history.append(command_text)
	history_index = command_history.size()
	
	# Execute command
	execute_command(command_text.strip_edges())
	
	# Clear input
	input_line.clear()

func navigate_history(direction: int):
	"""Navigate command history with up/down arrows"""
	if command_history.is_empty():
		return
	
	history_index += direction
	history_index = clampi(history_index, 0, command_history.size())
	
	if history_index < command_history.size():
		input_line.text = command_history[history_index]
		input_line.caret_column = input_line.text.length()
	else:
		input_line.clear()


#### COMMAND LIST AND IMPL ######

func execute_command(command: String):
	"""Parse and execute a command"""
	var parts = command.split(" ", false)
	if parts.is_empty():
		return
	
	var cmd = parts[0].to_lower()
	var args = parts.slice(1)
	
	match cmd:
		"help":
			show_help()
		
		"clear":
			log_text = ""
			output_label.clear()
			log_message("Console cleared")
		
		"quit", "exit":
			log_message("Quitting game...", "red")
			get_tree().quit()
		
		"fps":
			log_message("FPS: %.1f" % Engine.get_frames_per_second(), "cyan")
		
		"regen_map", "regenerate":
			if map_manager and map_manager.has_method("regenerate_map"):
				map_manager.regenerate_map()
				log_message("Map regenerated", "green")
			else:
				log_message("MapManager not found", "red")
		
		"teleport", "tp":
			if args.size() >= 2:
				teleport_camera(float(args[0]), float(args[1]))
			else:
				log_message("Usage: teleport <x> <y>", "orange")
		
		"zoom":
			if args.size() >= 1:
				set_zoom(float(args[0]))
			else:
				log_message("Usage: zoom <level>", "orange")
		
		"node_info":
			show_node_info()
		
		"complete_node":
			if map_manager and map_manager.has_method("complete_node"):
				map_manager.complete_node()
				log_message("Current node completed", "green")
			else:
				log_message("MapManager not found", "red")
		
		"goto_node", "go_node":
			if map_manager and map_manager.has_method("enable_debug_teleport_on_click"):
				map_manager.enable_debug_teleport_on_click()
				log_message("Click a map node to move the player there (ignores availability)", "green")
			else:
				log_message("MapManager not found", "red")
		
		"god_mode", "godmode":
			log_message("God mode not implemented yet", "orange")
		
		"timescale":
			if args.size() >= 1:
				Engine.time_scale = float(args[0])
				log_message("Time scale set to %.2f" % Engine.time_scale, "cyan")
			else:
				log_message("Current time scale: %.2f" % Engine.time_scale, "cyan")
		
		"save":
			if map_manager and map_manager.has_method("save_map_state"):
				var state = map_manager.save_map_state()
				log_message("Map state: %s" % str(state), "cyan")
			else:
				log_message("MapManager not found", "red")

		"formation_editor":
			_cmd_formation_editor(args)

		"formation_load":
			_cmd_formation_load(args)

		"add_card":
			_cmd_add_card(args)

		"add_gold":
			_cmd_add_gold(args)

		"add_components":
			_cmd_add_components(args)

		_:
			log_message("Unknown command: '%s'. Type 'help' for commands." % cmd, "red")

func show_help():
	"""Display available commands"""
	log_message("=== Available Commands ===", "cyan")
	log_message("help - Show this help message")
	log_message("clear - Clear console output")
	log_message("quit/exit - Quit the game")
	log_message("fps - Show current FPS")
	log_message("regen_map - Regenerate the map")
	log_message("teleport <x> <y> - Teleport camera to position")
	log_message("zoom <level> - Set camera zoom level")
	log_message("node_info - Show current node information")
	log_message("complete_node - Complete current node")
	log_message("goto_node - Click next map node to move the player there (debug)")
	log_message("timescale <value> - Set game speed (1.0 = normal)")
	log_message("save - Show current save state")
	log_message("formation_editor on [name [level]] | formation_editor off — enemy formation CSV editor (deployment)")
	log_message("formation_load <name> — load formation (editor: player board; normal prep: enemy side)")
	log_message("add_card <cardId> <count> — add unit/spell cards to inventory")
	log_message("add_gold <amount> — add run gold")
	log_message("add_components <amount> — add run components")

func _cmd_formation_editor(args: Array) -> void:
	if args.is_empty():
		log_message("Usage: formation_editor on [name [level]] | formation_editor off", "orange")
		return
	var sub := str(args[0]).to_lower()
	var g := get_tree().root.find_child("Gui", true, false) as Control
	if g == null or not g.has_method("enter_enemy_formation_editor_mode"):
		log_message("Gui not found", "red")
		return
	if sub == "on":
		var fname := str(args[1]) if args.size() > 1 else ""
		var flevel := str(args[2]) if args.size() > 2 else ""
		var err: Variant = g.call("enter_enemy_formation_editor_mode", fname, flevel)
		if str(err) != "":
			log_message(str(err), "red")
		else:
			log_message("Enemy formation editor on.", "green")
	elif sub == "off":
		if g.has_method("exit_enemy_formation_editor_mode"):
			g.call("exit_enemy_formation_editor_mode")
		log_message("Enemy formation editor off.", "green")
	else:
		log_message("Usage: formation_editor on [name [level]] | formation_editor off", "orange")


func _cmd_formation_load(args: Array) -> void:
	if args.is_empty():
		log_message("Usage: formation_load <formation_name>", "orange")
		return
	var formation_name := str(args[0])
	var g := get_tree().root.find_child("Gui", true, false) as Control
	if g == null or not g.has_method("dev_load_formation"):
		log_message("Gui not found", "red")
		return
	var err: Variant = g.call("dev_load_formation", formation_name)
	if str(err) != "":
		log_message(str(err), "red")
	else:
		log_message("Loaded formation: %s" % formation_name, "green")


func _get_game_state_manager() -> Node:
	var gsm := get_parent()
	if gsm and gsm.has_method("add_gold"):
		return gsm
	return get_tree().root.find_child("GameStateManager", true, false)


func _get_inventory() -> Inventory:
	var gui := get_tree().root.find_child("Gui", true, false) as Control
	if gui == null:
		return null
	return gui.get_node_or_null("Inventory") as Inventory


func _cmd_add_card(args: Array) -> void:
	if args.size() < 2:
		log_message("Usage: add_card <cardId> <count>", "orange")
		return
	var card_id := str(args[0])
	var count := int(args[1])
	if count <= 0:
		log_message("Count must be greater than 0", "red")
		return
	if ITEM_NAME.item_lookup(card_id) == null:
		log_message("Unknown card id: '%s'" % card_id, "red")
		return
	var inventory := _get_inventory()
	if inventory == null:
		log_message("Inventory not found", "red")
		return
	var before := inventory.get_number_of_item(card_id)
	inventory.add_item(card_id, count)
	var added := inventory.get_number_of_item(card_id) - before
	if added <= 0:
		log_message("Could not add '%s' (inventory may be full)" % card_id, "red")
		return
	log_message("Added %d x %s (inventory total: %d)" % [added, card_id, inventory.get_number_of_item(card_id)], "green")


func _cmd_add_gold(args: Array) -> void:
	if args.is_empty():
		log_message("Usage: add_gold <amount>", "orange")
		return
	var amount := int(args[0])
	if amount <= 0:
		log_message("Amount must be greater than 0", "red")
		return
	var gsm := _get_game_state_manager()
	if gsm == null:
		log_message("GameStateManager not found", "red")
		return
	gsm.add_gold(amount)
	log_message("Added %d gold (total: %d)" % [amount, gsm.run_gold], "green")


func _cmd_add_components(args: Array) -> void:
	if args.is_empty():
		log_message("Usage: add_components <amount>", "orange")
		return
	var amount := int(args[0])
	if amount <= 0:
		log_message("Amount must be greater than 0", "red")
		return
	var gsm := _get_game_state_manager()
	if gsm == null:
		log_message("GameStateManager not found", "red")
		return
	gsm.add_components(amount)
	log_message("Added %d components (total: %d)" % [amount, gsm.run_components], "green")


func teleport_camera(x: float, y: float):
	"""Teleport camera to position"""
	if camera:
		camera.position = Vector2(x, y)
		log_message("Camera teleported to (%.1f, %.1f)" % [x, y], "green")
	else:
		log_message("Camera not found", "red")

func set_zoom(zoom_level: float):
	"""Set camera zoom level"""
	if camera:
		camera.zoom = Vector2(zoom_level, zoom_level)
		log_message("Zoom set to %.2f" % zoom_level, "green")
	else:
		log_message("Camera not found", "red")

func show_node_info():
	"""Display information about current node"""
	if map_manager and map_manager.has_method("get_map_progress"):
		var progress = map_manager.get_map_progress()
		log_message("=== Node Info ===", "cyan")
		log_message("Total Nodes: %d" % progress.total_nodes)
		log_message("Completed: %d" % progress.completed_nodes)
		log_message("Available: %d" % progress.available_nodes)
		log_message("Current Stage: %d" % progress.current_stage)
		log_message("Campaign Complete: %s" % str(progress.campaign_complete))
	else:
		log_message("MapManager not found", "red")

# Public API for logging from other scripts
static func log(message: String, color: String = "white"):
	"""Static method to log from anywhere in the game"""
	var root = Engine.get_main_loop().root
	var console = root.find_child("DevConsole", true, false)
	if console and console.has_method("log_message"):
		console.log_message(message, color)
