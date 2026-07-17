# MainGame.gd
extends Node

enum GameState {
	MAP_EXPLORATION,
	BATTLE_PREPARATION,
	BATTLE_ACTIVE,
	BATTLE_COMPLETE,
	CAMPAIGN_COMPLETE
}




@onready var battle_manager = $BattleManager
@onready var generic_worker_pool: GenericWorkerPool = $GenericWorkerPool
@onready var viewport = $Viewport
@onready var gui = $UICanvas/Gui
@onready var pause_menu = $UICanvas/PauseMenu
@onready var loss_screen = $UICanvas/LossScreen
@onready var map_generator = $MapManager
@onready var player_health: PlayerHealthManager = $PlayerHealthManager
@onready var scrap_buffer: ScrapBufferManager = $ScrapBufferManager
@onready var shop_control: ShopControl = $ShopControl
@onready var rest_control: RestControl = $RestControl
@onready var random_event_control: RandomEventControl = $RandomEventControl

var current_state: GameState = GameState.MAP_EXPLORATION
var current_battle_node: MapNode
var run_gold: int = 0
var run_components: int = 0
var shop_visit_active: bool = false
var rest_visit_active: bool = false
var event_visit_active: bool = false

const MAIN_MENU_SCENE := "res://UI/Menus/MainMenu.tscn"

signal run_currency_changed(gold: int, components: int)

# =============================================================================
# INITIALIZATION AND SETUP
# =============================================================================

func _ready():
	# Connect signals
	connect_systems()
	
	#Sync all children to post ready state
	post_ready()
	
func post_ready():
	if shop_control:
		shop_control.setup(self)
	if rest_control:
		rest_control.setup(self)
	if random_event_control:
		random_event_control.setup(self)
	for i in get_children():
		if i.has_method("post_ready"):
			i.post_ready()

	if pause_menu:
		pause_menu.setup(self, gui)
	if loss_screen:
		loss_screen.setup(self)

	if SaveManager.pending_load:
		SaveManager.pending_load = false
		load_campaign_progress(SaveManager.load_run())
	elif SaveManager.pending_new_run:
		SaveManager.pending_new_run = false
		start_new_campaign()

func connect_systems():
	gui.preperation_ended.connect(_end_prep_phase)
	battle_manager.battle_ended.connect(_on_battle_ended)
	battle_manager.factory_destroyed.connect(_on_factory_destroyed)
	battle_manager.friendly_unit_died.connect(_on_friendly_unit_died)
	map_generator.selected_node.connect(_on_map_node_selected)

func change_state(new_state: GameState):
	"""Change the current game state"""
	var old_state = current_state
	current_state = new_state
	
	print("State changed: %s -> %s" % [GameState.keys()[old_state], GameState.keys()[new_state]])
	
	# Handle state-specific logic
	match new_state:
		GameState.MAP_EXPLORATION:
			enable_map_interaction()
		GameState.BATTLE_PREPARATION:
			prepare_battle()
		GameState.BATTLE_ACTIVE:
			start_battle_sequence()
		GameState.BATTLE_COMPLETE:
			handle_battle_completion()
		GameState.CAMPAIGN_COMPLETE:
			handle_campaign_completion()

# =============================================================================
# MAP EXPLORATION STATE
# =============================================================================

func enable_map_interaction():
	"""Enable map interaction and disable battle systems"""

	gui.enter_map_exploration()

	map_generator.set_process_input(true)
	map_generator.show()
	
	battle_manager.set_process(false)
	battle_manager.hide()
	
	# Center camera on map (player/current node) and reset zoom so the view is correct after combat
	var center : Vector2 = map_generator.get_camera_center_position()
	viewport.center_on(center)
	viewport.reset_zoom()
	
	print("Map exploration enabled. Available nodes: %d" % map_generator.get_available_nodes().size())


func _notify_map_node_completed() -> void:
	map_generator.on_map_node_completed()

func _on_map_node_selected(node: MapNode):
	"""Handle when player selects a map node"""
	if current_state != GameState.MAP_EXPLORATION:
		return
	
	if node.completed:
		print("Node %d has already been visited." % node.id)
		return

	if shop_visit_active:
		if node == current_battle_node:
			return
		_leave_shop_visit_for_node(node)
		return

	if rest_visit_active:
		if node == current_battle_node:
			return
		_leave_rest_visit_for_node(node)
		return

	if event_visit_active:
		return

	current_battle_node = node
	_route_map_node(node)


func _leave_shop_visit_for_node(next_node: MapNode) -> void:
	gui.close_shop()
	end_shop_visit()
	current_battle_node = next_node
	_route_map_node(next_node)


func _leave_rest_visit_for_node(next_node: MapNode) -> void:
	gui.close_rest()
	end_rest_visit()
	current_battle_node = next_node
	_route_map_node(next_node)

func leave_shop_visit() -> void:
	gui.close_shop()
	end_shop_visit()
	current_battle_node = null

func leave_rest_visit() -> void:
	gui.close_rest()
	end_rest_visit()
	current_battle_node = null

func _route_map_node(node: MapNode) -> void:
	match node.content_type:
		MapNode.ContentType.BATTLE, MapNode.ContentType.BLOCKADE:
			change_state(GameState.BATTLE_PREPARATION)
		MapNode.ContentType.RANDOM_EVENT:
			_enter_random_event_node(node)
		MapNode.ContentType.REPAIR_SITE:
			_enter_repair_site_node(node)
		MapNode.ContentType.SHOP:
			_enter_shop_node(node)
		_:
			push_warning("Unknown map node content type at node %d" % node.id)
			change_state(GameState.BATTLE_PREPARATION)

func _enter_random_event_node(_node: MapNode) -> void:
	open_event_visit()


func open_event_visit() -> void:
	event_visit_active = true
	var payload := random_event_control.build_event_payload(current_battle_node)
	gui.open_random_event(payload)


func end_event_visit() -> void:
	if current_battle_node:
		map_generator.complete_map_node(current_battle_node)
		_notify_map_node_completed()
	event_visit_active = false
	current_battle_node = null
	gui.close_random_event()
	change_state(GameState.MAP_EXPLORATION)

func _enter_repair_site_node(_node: MapNode) -> void:
	open_rest_visit()


func open_rest_visit() -> void:
	rest_visit_active = true
	var offers := rest_control.generate_offers()
	gui.open_rest(offers)


func end_rest_visit() -> void:
	if current_battle_node:
		map_generator.complete_map_node(current_battle_node)
		_notify_map_node_completed()
	rest_visit_active = false

func _enter_shop_node(_node: MapNode) -> void:
	open_shop_visit()


func open_shop_visit() -> void:
	shop_visit_active = true
	var stock := shop_control.generate_stock()
	gui.open_shop(stock)


func end_shop_visit() -> void:
	if current_battle_node:
		map_generator.complete_map_node(current_battle_node)
		_notify_map_node_completed()
	shop_visit_active = false

func _complete_special_node_visit(node: MapNode) -> void:
	map_generator.complete_current_battle()
	current_battle_node = null
	change_state(GameState.MAP_EXPLORATION)

# =============================================================================
# BATTLE PREPARATION STATE
# =============================================================================

func prepare_battle():
	"""Prepare for battle at the selected node"""
	if not current_battle_node:
		push_error("No battle node selected")
		return
	
	print("Preparing battle at node %d (Stage: %d, Difficulty: %s)" % 
		  [current_battle_node.id, current_battle_node.stage, current_battle_node.difficulty])
	
	viewport.enable_zoom()
	
	# Setup battle environment
	setup_battle_environment()
	

func setup_battle_environment():
	"""Setup the battle environment for the current node"""
	battle_manager.show()
	battle_manager.set_process(true)
	
	# Clear any existing units
	battle_manager.clear_battlefield()
	
	# Setup battle-specific parameters based on node
	var is_blockade := current_battle_node.content_type == MapNode.ContentType.BLOCKADE
	var is_chaser_pressured_exit := (
		current_battle_node.node_type == "end"
		and current_battle_node.chaser_blockaded
	)
	battle_manager.setup_battle({
		"stage": current_battle_node.stage,
		"difficulty": _resolve_battle_difficulty(current_battle_node),
		"node_type": current_battle_node.node_type,
		"is_blockade": is_blockade,
		"is_chaser_pressured_exit": is_chaser_pressured_exit,
	})
	_init_scrap_buffer_from_enemies()
	
	print("stage " + str(current_battle_node.stage) + 
		" difficulty " + _resolve_battle_difficulty(current_battle_node) +
		" node_type "+ current_battle_node.node_type)
	
	gui.start_prep_phase()

	# Hide map during battle
	map_generator.hide()
	map_generator.set_process_input(false)

func _init_scrap_buffer_from_enemies() -> void:
	if scrap_buffer == null:
		return
	var enemy_total := _sum_enemy_scrap_on_board()
	scrap_buffer.begin_prep(enemy_total)
	gui.refresh_scrap_buffer()

func _sum_enemy_scrap_on_board() -> int:
	var total := 0
	var unit_parent := battle_manager.get_node("Unit_Parent")
	for child in unit_parent.get_children():
		if child is Base_Unit and not (child as Base_Unit).faction:
			total += (child as Base_Unit).scrap_cost
	return total

func _end_prep_phase():
	# Create breif countdown to 
	await get_tree().create_timer(1.0).timeout
	change_state(GameState.BATTLE_ACTIVE)


# =============================================================================
# BATTLE ACTIVE STATE
# =============================================================================

func start_battle_sequence():
	"""Start the actual battle"""
	print("Battle started at node %d" % current_battle_node.id)
	if player_health:
		player_health.snapshot_health_for_battle()
	if scrap_buffer:
		scrap_buffer.on_combat_start()
		gui.refresh_scrap_buffer()
	battle_manager.start_battle()
	if gui:
		gui.show_battle_speed_bar()
	# The battle will run until _on_battle_ended is called

func _settle_scrap_buffer() -> void:
	var settlement := scrap_buffer.settle_battle()
	if settlement.repair_damage > 0 and player_health:
		player_health.apply_damage_capped(settlement.repair_damage, 1)
	gui.refresh_scrap_buffer()


func _on_friendly_unit_died(unit: Base_Unit) -> void:
	if scrap_buffer and current_state == GameState.BATTLE_ACTIVE:
		scrap_buffer.on_friendly_unit_died(unit.scrap_cost)
		gui.refresh_scrap_buffer()

func _on_battle_ended(victory: bool):
	"""Handle battle completion from battle manager"""
	print("Battle ended. Victory: %s" % victory)
	
	_settle_scrap_buffer()
	
	# Store battle result
	current_battle_node.completed = victory
	
	if victory:
		change_state(GameState.BATTLE_COMPLETE)
	else:
		# Handle defeat - could retry, return to map, etc.
		handle_battle_defeat()
		
	battle_manager.clear_battlefield()

func handle_battle_defeat():
	"""Handle what happens when player loses a battle"""
	print("Battle defeat")
	
	# return to map
	change_state(GameState.MAP_EXPLORATION)


func _on_factory_destroyed() -> void:
	_settle_scrap_buffer()
	handle_game_over()


func handle_game_over() -> void:
	get_tree().paused = true
	if loss_screen:
		loss_screen.open()


func return_to_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func save_and_exit_to_menu() -> void:
	SaveManager.save_run(save_campaign_progress())
	return_to_main_menu()

# =============================================================================
# BATTLE COMPLETE STATE
# =============================================================================

func handle_battle_completion():
	"""Handle successful battle completion"""
	if not current_battle_node:
		return
	
	print("Battle completed successfully at node %d" % current_battle_node.id)
	
	# Mark node as completed
	map_generator.complete_current_battle()
	_notify_map_node_completed()
	
	var is_campaign_end := current_battle_node.node_type == "end"
	var reward_payload := calculate_battle_rewards()
	print("Battle rewards: %s" % str(reward_payload))
	await gui.show_battle_rewards(reward_payload)
	
	current_battle_node = null
	
	if is_campaign_end:
		change_state(GameState.CAMPAIGN_COMPLETE)
	else:
		change_state(GameState.MAP_EXPLORATION)

func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	run_gold += amount
	print("Gold gained: +%d (total: %d)" % [amount, run_gold])
	_emit_run_currency_changed()


func spend_gold(amount: int) -> bool:
	if amount <= 0:
		return true
	if run_gold < amount:
		return false
	run_gold -= amount
	print("Gold spent: -%d (total: %d)" % [amount, run_gold])
	_emit_run_currency_changed()
	return true


func add_components(amount: int) -> void:
	if amount <= 0:
		return
	run_components += amount
	print("Components gained: +%d (total: %d)" % [amount, run_components])
	_emit_run_currency_changed()


func spend_components(amount: int) -> bool:
	if amount <= 0:
		return true
	if run_components < amount:
		return false
	run_components -= amount
	print("Components spent: -%d (total: %d)" % [amount, run_components])
	_emit_run_currency_changed()
	return true


func _emit_run_currency_changed() -> void:
	run_currency_changed.emit(run_gold, run_components)

func award_battle_rewards():
	"""Deprecated: rewards are applied interactively via battle rewards UI."""
	pass

func calculate_battle_rewards() -> Dictionary:
	"""Calculate rewards based on node difficulty and performance."""
	var is_blockade := current_battle_node.content_type == MapNode.ContentType.BLOCKADE
	var gold_amount := 100
	
	match _resolve_battle_difficulty(current_battle_node):
		"light":
			gold_amount = int(gold_amount * 1)
		"medium":
			gold_amount = int(gold_amount * 1.5)
		"heavy":
			gold_amount = int(gold_amount * 2)
	
	gold_amount += current_battle_node.stage * 10
	if is_blockade:
		gold_amount = int(gold_amount * 1.5)
	
	var entries: Array = [
		{
			"id": "gold",
			"kind": "instant",
			"label": "Collect gold (+%d)" % gold_amount,
			"gold": gold_amount,
			"claimed": false
		},
	]
	if not is_blockade:
		var unit_options := _pick_random_unit_reward_options(3)
		entries.append({
			"id": "unit_pick",
			"kind": "unit_choice",
			"label": "Recruit a unit",
			"options": unit_options,
			"claimed": false
		})
	
	if scrap_buffer:
		var bonus := scrap_buffer.get_bonus_gold()
		if bonus > 0:
			entries.append({
				"id": "scrap_bonus",
				"kind": "instant",
				"label": "Collect scrap surplus (+%d)" % bonus,
				"gold": bonus,
				"claimed": false
			})
	
	return {"entries": entries}


func _resolve_battle_difficulty(node: MapNode) -> String:
	var base := node.difficulty
	if node.content_type == MapNode.ContentType.BLOCKADE:
		match base:
			"light":
				return "medium"
			"medium", "heavy":
				return "heavy"
	if node.node_type == "end" and node.chaser_blockaded:
		# TODO: Replace exit with a dedicated boss fight; make boss harder when blockaded.
		return "heavy"
	return base


func _get_unit_reward_pool() -> Array[String]:
	var pool: Array[String] = []
	for map_item in ITEM_NAME.unit_role_map:
		var item_id: String = map_item[1]
		var scene: PackedScene = ITEM_NAME.item_lookup(item_id)
		if scene == null:
			continue
		var path := scene.resource_path
		if "Spells/" in path:
			continue
		var probe = scene.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
		if probe is Unit_Card and (probe as Unit_Card).enemy_formation_only:
			probe.queue_free()
			continue
		if probe:
			probe.queue_free()
		pool.append(item_id)
	return pool

func _pick_random_unit_reward_options(count: int) -> Array[String]:
	var pool := _get_unit_reward_pool()
	if pool.is_empty():
		return []
	var shuffled := pool.duplicate()
	shuffled.shuffle()
	var options: Array[String] = []
	for i in mini(count, shuffled.size()):
		options.append(shuffled[i])
	while options.size() < count and not pool.is_empty():
		options.append(pool[options.size() % pool.size()])
	return options

# =============================================================================
# CAMPAIGN COMPLETE STATE
# =============================================================================

func handle_campaign_completion():
	"""Handle campaign completion"""
	print("=== CAMPAIGN COMPLETED ===")
	
	# Show victory screen, unlock new campaigns, etc.
	show_campaign_victory()

func show_campaign_victory():
	"""Show campaign victory screen"""
	print("Showing campaign victory screen")
	# TODO: Implement your victory screen UI here


# =============================================================================
# PUBLIC INTERFACE
# =============================================================================

func start_new_campaign():
	"""Start a new campaign"""
	print("Starting new campaign")
	
	# Reset systems
	current_battle_node = null
	run_gold = 0
	run_components = 0
	shop_visit_active = false
	rest_visit_active = false
	event_visit_active = false
	_emit_run_currency_changed()
	if gui:
		gui.close_shop()
		gui.close_rest()
		gui.close_random_event()
	if player_health:
		player_health.reset_for_new_campaign()
	if scrap_buffer:
		scrap_buffer.reset()
	UnitUpgradeRegistry.reset_for_new_campaign()
	
	# Generate new map
	if map_generator:
		map_generator.regenerate_map()
	
	change_state(GameState.MAP_EXPLORATION)

func save_campaign_progress() -> Dictionary:
	"""Save current campaign progress"""
	var save_data = {
		"current_state": int(current_state),
		"current_battle_node_id": current_battle_node.id if current_battle_node else -1,
		"run_gold": run_gold,
		"run_components": run_components,
	}
	
	# Add map state
	if map_generator:
		save_data.map_state = map_generator.save_map_state()
	
	return save_data

func load_campaign_progress(save_data: Dictionary):
	"""Load campaign progress from save data"""
	# Load map state first (regenerates topology from saved seed, then applies progress)
	if map_generator and save_data.has("map_state"):
		map_generator.restore_map_from_save(save_data.map_state)
	
	# Restore current state
	var saved_state = int(save_data.get("current_state", GameState.MAP_EXPLORATION))
	change_state(saved_state as GameState)
	
	# Restore current battle node if applicable
	var battle_node_id = save_data.get("current_battle_node_id", -1)
	if battle_node_id >= 0:
		for node in map_generator.nodes:
			if node.id == battle_node_id:
				current_battle_node = node
				break

	run_gold = int(save_data.get("run_gold", 0))
	run_components = int(save_data.get("run_components", 0))
	_emit_run_currency_changed()

func get_campaign_progress() -> Dictionary:
	"""Get current campaign progress for UI display"""
	var progress = {
		"state": GameState.keys()[current_state],
		"current_node": current_battle_node.id if current_battle_node else -1
	}
	
	if map_generator:
		progress.merge(map_generator.get_map_progress())
	
	return progress
	


# =============================================================================
# DEBUG INTERFACE
# =============================================================================

func force_battle_victory():
	"""Debug: Force current battle to end in victory"""
	if current_state == GameState.BATTLE_ACTIVE:
		_on_battle_ended(true)

func force_battle_defeat():
	"""Debug: Force current battle to end in defeat"""
	if current_state == GameState.BATTLE_ACTIVE:
		_on_battle_ended(false)

func skip_to_end():
	"""Debug: Skip to campaign end"""
	if map_generator and map_generator.end_node:
		current_battle_node = map_generator.end_node
		change_state(GameState.CAMPAIGN_COMPLETE)
