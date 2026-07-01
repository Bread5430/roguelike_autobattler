extends Control
@onready var post_ready_check = false

#### DEBUG VARS
@export var selector_rect_debug : bool = true
var selector_rect : Rect2

#### NODE REFERENCES
@export var battle_manager : Control
var inventory : Inventory
var unit_board : GridContainer
var gsm 
@onready var spell_bar : SpellBar = $SpellBar
@onready var end_prep : Button = $End_Prep
@onready var tactical_cursor = $TacticalCursor
@onready var item_details_card: ItemDetailsCard = $ItemDetailsCard
@onready var player_health_bar: PanelContainer = $PlayerHealthBar
@onready var run_resources_hud: RunResourcesHUD = $RunResourcesHUD
@onready var battle_rewards_ui: BattleRewardsUI = $BattleRewardsUI
@onready var shop_ui: ShopUI = $ShopUI
@onready var shop_toggle_button: Button = $ShopToggleButton
@onready var rest_ui: RestUI = $RestUI
@onready var rest_toggle_button: Button = $RestToggleButton
@onready var random_event_ui: RandomEventUI = $RandomEventUI
@onready var event_toggle_button: Button = $EventToggleButton
@onready var passthrough_helper: Node = $Passthough_Helper
var item_details_builder := ItemDetailsBuilder.new()

#### CASTING MODE (battle)
var casting_mode : bool = false
var casting_slot : SpellBarSlot

#### UNIT PLACEMENT VARS
var unit_board_height : int
var unit_board_width : int

var unit_board_space_map : Array[Array] = [] # Stores references to units on the board for removal

#### Store these state variables in globals since they are required by the input events

## Deployment-only: world-space centers and radii for placed router cards (logical exclusion, not grid-derived).
var _placed_router_exclusions: Array[Dictionary] = []

# Variables related to unit placement when in deployment stage
var deployment_mode : bool = false
var targetCell
var objectCells = []
var curr_unit : PackedScene
var curr_unit_inst : Item
var curr_inv_slot : InventorySlot
var curr_mouse_tile : Vector2
var isValid = false
var rotated_placement : bool = false

signal preperation_ended

const END_PREP_DEFAULT_TEXT := "End Preperation Phase"

## Dev: enemy formation CSV authoring during deployment (see Testing/dev_console.gd).
var enemy_formation_editor_mode: bool = false
var formation_editor_name: String = "formation_export"
var formation_editor_level: String = "light"

var enemy_spawner: Node

## Items committed for the current battle so we can refund them when battle ends.
## - Units are inferred from unit_board_space_map (one entry per placed unit).
## - Spells are tracked because they can be cast/removed during battle.
var _committed_spell_item_names: Array[String] = []

func post_ready():
	inventory = get_node("Inventory")
	unit_board = battle_manager.get_node("BoardUI")
	enemy_spawner = battle_manager.get_node("Enemy_Spawner")
	unit_board_height = unit_board.height
	unit_board_width = unit_board.width
	
	# Initialize empty grid
	for i in unit_board_width:
		unit_board_space_map.append([])
		#vector_size_map.append([])
		for j in unit_board_height:
			unit_board_space_map[i].append(null)

	# Needed to prevent process from running too soon
	post_ready_check = true

	spell_bar.battle_manager = battle_manager
	battle_manager.tactical_cursor = tactical_cursor
	gsm = get_parent().get_parent()
	if gsm != null and gsm.has_node("PlayerHealthManager"):
		var health_manager := gsm.get_node("PlayerHealthManager") as PlayerHealthManager
		player_health_bar.setup(health_manager)
		if battle_rewards_ui:
			battle_rewards_ui.setup(health_manager, passthrough_helper)
			battle_rewards_ui.instant_gold_claimed.connect(_on_battle_reward_gold_claimed)
			battle_rewards_ui.unit_picked.connect(_on_battle_reward_unit_picked)
		if shop_ui:
			shop_ui.setup(passthrough_helper)
			shop_ui.purchase_requested.connect(_on_shop_purchase_requested)
			shop_ui.refresh_requested.connect(_on_shop_refresh_requested)
			shop_ui.scrap_mode_entered.connect(_on_shop_scrap_mode_entered)
			shop_ui.scrap_mode_exited.connect(_on_shop_scrap_mode_exited)
			shop_ui.leave_requested.connect(_on_shop_leave_requested)
		if shop_toggle_button:
			shop_toggle_button.visible = false
			shop_toggle_button.disabled = true
			shop_toggle_button.pressed.connect(_on_shop_toggle_pressed)
		if rest_ui:
			rest_ui.setup(passthrough_helper)
			rest_ui.upgrade_requested.connect(_on_rest_upgrade_requested)
			rest_ui.repair_requested.connect(_on_rest_repair_requested)
			rest_ui.craft_mode_entered.connect(_on_rest_craft_mode_entered)
			rest_ui.craft_mode_exited.connect(_on_rest_craft_mode_exited)
			rest_ui.refresh_requested.connect(_on_rest_refresh_requested)
			rest_ui.leave_requested.connect(_on_rest_leave_requested)
		if rest_toggle_button:
			rest_toggle_button.visible = false
			rest_toggle_button.disabled = true
			rest_toggle_button.pressed.connect(_on_rest_toggle_pressed)
		if random_event_ui:
			random_event_ui.setup(passthrough_helper)
			random_event_ui.choice_selected.connect(_on_event_choice_selected)
		if event_toggle_button:
			event_toggle_button.visible = false
			event_toggle_button.disabled = true
			event_toggle_button.pressed.connect(_on_event_toggle_pressed)
		if inventory:
			inventory.scrap_item_requested.connect(_on_inventory_scrap_item_requested)
			inventory.craft_item_requested.connect(_on_inventory_craft_item_requested)
		if gsm.has_signal("run_currency_changed"):
			gsm.run_currency_changed.connect(_on_run_currency_changed)
	inventory.inspect_requested.connect(_on_inventory_inspect_requested)
	spell_bar.spell_slot_clicked.connect(_on_spell_slot_clicked)
	spell_bar.spell_slot_right_clicked.connect(_on_spell_slot_right_clicked)
	if battle_manager.has_signal("unit_selected"):
		battle_manager.unit_selected.connect(_on_unit_selected)
	if battle_manager.has_signal("battle_ended"):
		battle_manager.battle_ended.connect(_on_battle_ended)

	# Propagate downwards
	for i in get_children():
		if i.has_method("post_ready"):
			i.post_ready()

func _draw():
	if selector_rect_debug:
		draw_rect(selector_rect, Color.RED, false)

func _process(_delta):
	if post_ready_check:
		check_cell()
		_update_tactical_cursor()
		queue_redraw()

		if casting_mode:
			if casting_slot and is_instance_valid(casting_slot.spell_inst):
				casting_slot.spell_inst.preview(_get_world_mouse_position())
			queue_redraw()

## Casting mode only. Runs for every input so we always can confirm/cancel cast.
func _input(event: InputEvent):
	if not casting_mode:
		return
	var mouse_pos := get_viewport().get_mouse_position()
	if event.is_action_pressed("leftClick"):
		if not is_mouse_over_ui_element(mouse_pos) and casting_slot and is_instance_valid(casting_slot.spell_inst):
			var spell_inst: Base_Spell = casting_slot.spell_inst
			var world_pos := _get_world_mouse_position()
			if spell_inst.handles_casting_input():
				var r: Dictionary = spell_inst.on_casting_click(world_pos)
				if r.get("consume_spell", false):
					spell_bar.remove_spell_at(casting_slot)
				if r.get("exit_casting", true):
					_exit_casting_mode()
			else:
				spell_inst.cast(world_pos)
				spell_bar.remove_spell_at(casting_slot)
				_exit_casting_mode()
		else:
			_exit_casting_mode()
		return
	if event.is_action_pressed("rightClick") or event.is_action_pressed("ui_cancel"):
		_exit_casting_mode()
		return

## Only runs when no Control has accepted the event (e.g. keyboard when no button focused).
func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("rotatePlacement"):
		rotated_placement = !rotated_placement
		targetCell = null
		check_cell()
		accept_event()

## Placement and removal are handled by InputCoordinator via handle_game_area_click().
## This is no longer used for game-area clicks (root Gui uses MOUSE_FILTER_IGNORE).
func _gui_input(_event: InputEvent):
	pass

## Called by InputCoordinator for game-area clicks in BATTLE_PREPARATION.
## Uses transformed (camera) coordinates so placement works with pan/zoom.
func handle_game_area_click(event: InputEvent):
	if not deployment_mode or not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed:
		return
	var world_pos : Vector2 = get_viewport().get_canvas_transform().affine_inverse() * event.position
	# Left click on a placed unit: show unit stats panel (no placement).
	if mb.button_index == MOUSE_BUTTON_LEFT and battle_manager and tactical_cursor:
		var unit = battle_manager.get_unit_under_cursor(world_pos)
		if unit:
			tactical_cursor.set_selected_unit(unit)
			return
	var anchor_cell := _get_cell_at_world_position(world_pos)
	if not anchor_cell:
		_clear_preview_highlight()
		return
	if mb.button_index == MOUSE_BUTTON_LEFT:
		# Fast cursor movement + click can bypass the hover-frame update, leaving
		# previous preview colors behind. Clear old preview before recomputing.
		if objectCells.size() > 0:
			_reset_highlight(objectCells)
		targetCell = anchor_cell
		# If no unit is selected (or we just ran out), don't attempt placement math.
		if curr_unit_inst == null or curr_unit == null:
			objectCells = [anchor_cell]
			anchor_cell.change_color(Color.YELLOW)
			isValid = false
			return
		objectCells = _get_object_cells_for_anchor(anchor_cell)
		isValid = _check_and_highlight_cells(objectCells)
		if isValid:
			_place_unit()
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		var mouse_tile_int := Vector2i(anchor_cell.board_position)
		var removed_unit_info = get_unit_at_tile(mouse_tile_int)
		if removed_unit_info:
			var top_corner = removed_unit_info[1]
			var size = removed_unit_info[2]
			var top_i := Vector2i(int(top_corner.x), int(top_corner.y))
			var cells_to_reset := _get_cells_in_rect(top_i, size)
			var item_inst = removed_unit_info[0].instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
			item_inst.setup_unit()
			remove_from_board(top_i, size)
			inventory.add_item(item_inst.item_name, 1)
			curr_unit = removed_unit_info[0]
			curr_unit_inst = item_inst
			
			# Force a placement validity recalculation with this new unit
			_reset_highlight(cells_to_reset)
			isValid = _check_and_highlight_cells(objectCells)

func toggle_inventory(can_use_inventory : bool):
	if can_use_inventory == true:
		inventory.can_open_inventory = true
		
	else:
		inventory.can_open_inventory = false
		inventory.toggle_window(false)

func check_cell():
	# Use world position so hover works with camera pan/zoom.
	var world_mouse := _get_world_mouse_position()
	curr_mouse_tile = (world_mouse - unit_board.global_position) / Vector2(unit_board.cellWidth, unit_board.cellHeight)
	var new_target := _get_cell_at_world_position(world_mouse)
	if new_target == null:
		targetCell = null
		_clear_preview_highlight()
		return
	if new_target and new_target != targetCell:
		targetCell = new_target
		if objectCells.size() > 0:
			_reset_highlight(objectCells)
		if curr_unit_inst:
			curr_unit_inst.global_position = targetCell.global_position + curr_unit_inst.texture.get_size() * curr_unit_inst.scale / 2
			objectCells = _get_object_cells()
			isValid = _check_and_highlight_cells(objectCells)
		else:
			objectCells = [new_target]
			new_target.change_color(Color.YELLOW)


func _clear_preview_highlight() -> void:
	if objectCells.size() > 0:
		_reset_highlight(objectCells)
	objectCells.clear()
	isValid = false


func remove_from_board(top_corner: Vector2i, size: Vector2) -> void:
	_remove_placed_router_exclusion_if_matches(top_corner, size)
	for x in size.x:
		for y in size.y:
			unit_board_space_map[top_corner.x + x][top_corner.y + y] = null

	var reset_cells := _get_cells_in_rect(top_corner, size)
	for cell in reset_cells:
		cell.full = false

	battle_manager.remove_unit_from_board(top_corner, size)


func _remove_placed_router_exclusion_if_matches(top_corner: Vector2i, size: Vector2) -> void:
	var i := _placed_router_exclusions.size() - 1
	while i >= 0:
		var z: Dictionary = _placed_router_exclusions[i]
		if z["top_corner"] == top_corner and z["size"] == size:
			_placed_router_exclusions.remove_at(i)
			return
		i -= 1


### Internode Communication Methods
func set_current_item(slot : InventorySlot):
	curr_inv_slot = slot
	
	if slot.item_inst is Unit_Card:
		curr_unit = slot.item
		curr_unit_inst = slot.item_inst
	elif slot.item_inst is Spell_Card:
		# In deployment mode only: add spell to spell bar and consume one from inventory
		if deployment_mode:
			var added := spell_bar.add_spell(slot.item_inst as Spell_Card, slot.item_name)
			if added:
				_committed_spell_item_names.append(slot.item_name)
				slot.remove_item(1)
		# In other modes: do nothing when clicking a spell

func start_prep_phase():
	enemy_formation_editor_mode = false
	end_prep.text = END_PREP_DEFAULT_TEXT
	_clear_placement_grid()
	_committed_spell_item_names.clear()
	deployment_mode = true
	toggle_inventory(true)
	end_prep.show()
	end_prep.disabled = false
	spell_bar.show()
	run_resources_hud.set_map_visible(false)


func enter_map_exploration() -> void:
	spell_bar.hide()
	run_resources_hud.set_map_visible(true)
	_refresh_run_resources_hud()
	end_prep.hide()
	end_prep.disabled = true
	deployment_mode = false
	toggle_inventory(true)


func open_shop(stock: Dictionary) -> void:
	if item_details_card:
		item_details_card.hide_details()
	toggle_inventory(true)
	if shop_toggle_button:
		shop_toggle_button.visible = true
		shop_toggle_button.disabled = false
		shop_toggle_button.text = "Hide Shop"
	
	var gold = gsm.run_gold if gsm else 0
	var components = gsm.run_components if gsm else 0
	if shop_ui:
		shop_ui.open(stock, gold, components)
	_sync_shop_map_input(shop_ui.is_panel_visible() if shop_ui else true)


func close_shop() -> void:
	if shop_ui:
		shop_ui.close()
	if shop_toggle_button:
		shop_toggle_button.visible = false
		shop_toggle_button.disabled = true
	if inventory:
		inventory.set_scrap_mode(false)
	toggle_inventory(true)
	passthrough_helper.unblock_input()
	gsm.map_generator.set_process_input(true)


func open_rest(offers: Dictionary) -> void:
	if item_details_card:
		item_details_card.hide_details()
	toggle_inventory(true)
	if rest_toggle_button:
		rest_toggle_button.visible = true
		rest_toggle_button.disabled = false
		rest_toggle_button.text = "Hide Rest"
	
	var components = gsm.run_components
	if rest_ui:
		rest_ui.repair_cost = gsm.rest_control.repair_cost
		rest_ui.craft_cost = gsm.rest_control.craft_cost
		rest_ui.refresh_cost = gsm.rest_control.refresh_cost
		rest_ui.open(offers, components)
	_sync_rest_map_input(rest_ui.is_panel_visible() if rest_ui else true)


func close_rest() -> void:
	if rest_ui:
		rest_ui.close()
	if rest_toggle_button:
		rest_toggle_button.visible = false
		rest_toggle_button.disabled = true
	if inventory:
		inventory.set_craft_mode(false)
	toggle_inventory(true)
	passthrough_helper.unblock_input()
	gsm.map_generator.set_process_input(true)


func open_random_event(payload: Dictionary) -> void:
	if item_details_card:
		item_details_card.hide_details()
	toggle_inventory(true)
	if event_toggle_button:
		event_toggle_button.visible = true
		event_toggle_button.disabled = false
		event_toggle_button.text = "Hide Event"
	if random_event_ui:
		random_event_ui.open(payload)
	_sync_event_map_input(random_event_ui.is_panel_visible() if random_event_ui else true)


func close_random_event() -> void:
	if random_event_ui:
		random_event_ui.close()
	if event_toggle_button:
		event_toggle_button.visible = false
		event_toggle_button.disabled = true
	toggle_inventory(true)
	passthrough_helper.unblock_input()
	
	if gsm and gsm.map_generator:
		gsm.map_generator.set_process_input(true)


func _on_event_toggle_pressed() -> void:
	if not random_event_ui or not random_event_ui.visible:
		return
	random_event_ui.toggle_panel_visibility()
	if random_event_ui.is_panel_visible():
		event_toggle_button.text = "Hide Event"
	else:
		event_toggle_button.text = "Show Event"
	_sync_event_map_input(random_event_ui.is_panel_visible())


func _sync_event_map_input(_event_panel_visible: bool) -> void:
	passthrough_helper.block_input()
	
	if gsm and gsm.map_generator:
		gsm.map_generator.set_process_input(false)


func _on_event_choice_selected(choice_id: String) -> void:
	
	if gsm == null or gsm.random_event_control == null or random_event_ui == null:
		return
	var payload := random_event_ui.get_payload()
	if not gsm.random_event_control.try_resolve_choice(payload, choice_id, inventory):
		var refreshed = gsm.random_event_control.refresh_choice_enabled_flags(payload, inventory)
		random_event_ui.set_payload(refreshed)
		return
	gsm.end_event_visit()
	_refresh_run_resources_hud()


func _on_rest_toggle_pressed() -> void:
	if not rest_ui or not rest_ui.visible:
		return
	rest_ui.toggle_panel_visibility()
	if rest_ui.is_panel_visible():
		rest_toggle_button.text = "Hide Rest"
	else:
		rest_toggle_button.text = "Show Rest"
	_sync_rest_map_input(rest_ui.is_panel_visible())


func _sync_rest_map_input(rest_panel_visible: bool) -> void:
	
	if gsm and gsm.rest_visit_active and gsm.map_generator:
		gsm.map_generator.set_process_input(true)
	if rest_panel_visible:
		passthrough_helper.block_input()
	else:
		passthrough_helper.unblock_input()


func _on_rest_leave_requested() -> void:
	
	gsm.leave_rest_visit()


func _on_rest_repair_requested() -> void:
	
	if gsm == null or gsm.rest_control == null or rest_ui == null:
		return
	var offers := rest_ui.get_offers()
	if not gsm.rest_control.try_repair(offers):
		return
	rest_ui.set_offers(offers, gsm.run_components)


func _on_rest_craft_mode_entered() -> void:
	inventory.set_craft_mode(true)


func _on_rest_craft_mode_exited() -> void:
	inventory.set_craft_mode(false)


func _on_inventory_craft_item_requested(item_id: String) -> void:
	
	var offers := rest_ui.get_offers()
	if not gsm.rest_control.try_craft_unit(item_id, inventory, offers):
		return
	rest_ui.set_offers(offers, gsm.run_components)
	rest_ui.exit_craft_mode()


func _on_rest_refresh_requested() -> void:
	
	var offers := rest_ui.get_offers()
	var updated = gsm.rest_control.refresh_upgrades(offers)
	rest_ui.set_offers(updated, gsm.run_components)


func _on_rest_upgrade_requested(slot_data: Dictionary, slot_index: int) -> void:
	
	var offers := rest_ui.get_offers()
	if not gsm.rest_control.try_purchase_upgrade(slot_data, offers):
		return
	rest_ui.mark_upgrade_purchased(slot_index)
	rest_ui.set_offers(offers, gsm.run_components)


func _on_shop_toggle_pressed() -> void:
	if not shop_ui.visible:
		return
	shop_ui.toggle_panel_visibility()
	if shop_ui.is_panel_visible():
		shop_toggle_button.text = "Hide Shop"
	else:
		shop_toggle_button.text = "Show Shop"
	_sync_shop_map_input(shop_ui.is_panel_visible())


func _sync_shop_map_input(shop_panel_visible: bool) -> void:
	
	if gsm and gsm.shop_visit_active and gsm.map_generator:
		gsm.map_generator.set_process_input(true)
	if shop_panel_visible:
		passthrough_helper.block_input()
	else:
		passthrough_helper.unblock_input()


func _on_shop_leave_requested() -> void:
	
	gsm.leave_shop_visit()


func _on_shop_purchase_requested(slot_data: Dictionary, row_key: String, slot_index: int) -> void:
	
	if gsm == null or gsm.shop_control == null or inventory == null or shop_ui == null:
		return
	if not gsm.shop_control.try_purchase(slot_data, inventory):
		return
	shop_ui.mark_slot_sold(row_key, slot_index)
	shop_ui.refresh_currency(gsm.run_gold, gsm.run_components)


func _on_shop_refresh_requested() -> void:
	
	var updated = gsm.shop_control.refresh_stock(shop_ui.get_stock())
	shop_ui.set_stock(updated, gsm.run_gold)
	shop_ui.mark_refresh_used(gsm.run_gold)


func _on_shop_scrap_mode_entered() -> void:
	inventory.set_scrap_mode(true)


func _on_shop_scrap_mode_exited() -> void:
	inventory.set_scrap_mode(false)


func _on_inventory_scrap_item_requested(item_id: String) -> void:
	
	if gsm.shop_control.process_scrap(item_id, inventory) <= 0:
		return
	shop_ui.refresh_currency(gsm.run_gold, gsm.run_components)
	shop_ui.exit_scrap_mode()


func _on_run_currency_changed(gold: int, components: int) -> void:
	if run_resources_hud.visible:
		run_resources_hud.update_values(gold, components)
	if rest_ui and rest_ui.visible:
		rest_ui.refresh_display(components)


func _refresh_run_resources_hud() -> void:
	var gsm := _get_game_state_manager()
	run_resources_hud.update_values(gsm.run_gold, gsm.run_components)


func _get_game_state_manager() -> Node:
	return get_parent().get_parent()


func _is_shop_visit_active() -> bool:
	
	return gsm != null and gsm.shop_visit_active


func _is_rest_visit_active() -> bool:
	
	return gsm != null and gsm.rest_visit_active


func _is_event_visit_active() -> bool:
	
	return gsm != null and gsm.event_visit_active


func show_battle_rewards(payload: Dictionary) -> void:
	if item_details_card:
		item_details_card.hide_details()
	toggle_inventory(false)
	if battle_rewards_ui:
		await battle_rewards_ui.open(payload)


func _on_battle_reward_gold_claimed(amount: int) -> void:
	var gsm := get_parent().get_parent()
	if gsm and gsm.has_method("add_gold"):
		gsm.add_gold(amount)


func _on_battle_reward_unit_picked(item_id: String) -> void:
	if inventory:
		inventory.add_item(item_id, 1)


func _on_end_prep_pressed() -> void:
	if enemy_formation_editor_mode:
		var save_err := _save_editor_formation_to_new_csv()
		if save_err.begins_with("OK:"):
			var msg := save_err.trim_prefix("OK:")
			DevConsole.log(msg, "green")
			print("[Formation] ", msg)
		else:
			DevConsole.log(save_err, "red")
			push_warning(save_err)
		return

	deployment_mode = false
	end_prep.hide()
	end_prep.disabled = true
	toggle_inventory(false)
	preperation_ended.emit()


func enter_enemy_formation_editor_mode(default_name: String = "", default_level: String = "") -> String:
	if not deployment_mode:
		return "Enter battle preparation (deployment) first."
	_clear_board_allied_units()
	_clear_placement_grid()
	inventory.clear_all_slots()
	_clear_spells_from_inventory_and_bar()
	_grant_all_unit_cards_to_inventory(999)
	enemy_formation_editor_mode = true
	formation_editor_name = default_name.strip_edges() if default_name.strip_edges() != "" else "formation_export"
	var lvl := default_level.strip_edges().to_lower() if default_level.strip_edges() != "" else "light"
	if not FORMATION_MAP.LEVELS.has(lvl):
		lvl = "light"
	formation_editor_level = lvl
	end_prep.text = "Confirm Position"
	curr_unit = null
	curr_unit_inst = null
	objectCells.clear()
	return ""


func exit_enemy_formation_editor_mode() -> void:
	enemy_formation_editor_mode = false
	end_prep.text = END_PREP_DEFAULT_TEXT


func dev_load_formation(formation_name: String) -> String:
	if not post_ready_check or battle_manager == null:
		return "GUI or battle not ready."
	if not deployment_mode:
		return "Open battle preparation (deployment) first."
	var rows := FORMATION_MAP.formation_lookup(formation_name)
	if rows.is_empty():
		return "Unknown formation: %s" % formation_name
	if enemy_formation_editor_mode:
		_clear_board_allied_units()
		_clear_placement_grid()
		var n := _load_formation_rows_on_player_board(rows)
		if n <= 0:
			return "Failed to place formation on board."
		return ""
	_clear_board_enemy_units()
	if enemy_spawner == null or not enemy_spawner.has_method("spawn_formation_rows"):
		return "Enemy spawner missing."
	var n2: int = enemy_spawner.spawn_formation_rows(rows)
	if n2 <= 0:
		return "Failed to spawn enemy units."
	return ""


func _clear_spells_from_inventory_and_bar() -> void:
	if spell_bar:
		for slot in spell_bar.slots:
			spell_bar.remove_spell_at(slot)
	if inventory == null:
		return
	for slot in inventory.slots:
		if slot.item_inst is Spell_Card:
			slot.set_item("", null, 0)


func _grant_all_unit_cards_to_inventory(qty: int) -> void:
	if inventory == null:
		return
	for item_id in ITEM_NAME.name_obj_map.keys():
		var sc: PackedScene = ITEM_NAME.item_lookup(item_id)
		if sc == null:
			continue
		var inst = sc.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
		if inst is Unit_Card:
			var card := inst as Unit_Card
			if card.enemy_formation_only:
				card.queue_free()
				continue
			card.setup_unit()
			inventory.add_item(item_id, qty)
		if inst:
			inst.queue_free()


func _clear_board_allied_units() -> void:
	if battle_manager == null:
		return
	var up := battle_manager.get_node_or_null("Unit_Parent")
	if up == null:
		return
	for child in up.get_children():
		if child is Base_Unit and (child as Base_Unit).faction:
			child.queue_free()


func _clear_board_enemy_units() -> void:
	if battle_manager == null:
		return
	var up := battle_manager.get_node_or_null("Unit_Parent")
	if up == null:
		return
	for child in up.get_children():
		if child is Base_Unit and not (child as Base_Unit).faction:
			child.queue_free()


func _get_board_slot_at_grid(grid_xy: Vector2i) -> BoardSlot:
	if grid_xy.x < 0 or grid_xy.x >= unit_board_width or grid_xy.y < 0 or grid_xy.y >= unit_board_height:
		return null
	var idx := grid_xy.x + grid_xy.y * unit_board_width
	var children := unit_board.get_children()
	if idx >= children.size():
		return null
	var cell = children[idx]
	return cell as BoardSlot if cell is BoardSlot else null


func _router_exclusion_radius_from_card_inst(inst: Item) -> float:
	if inst is Unit_Card:
		var uc := inst as Unit_Card
		if uc.is_router_card:
			return uc.router_exclusion_radius
	return 0.0


func _place_unit_card_programmatic(p_scene: PackedScene, top_left: Vector2i, rotated: bool) -> bool:
	var item_inst = p_scene.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
	if not item_inst is Unit_Card:
		item_inst.queue_free()
		return false
	item_inst.setup_unit()
	curr_unit_inst = item_inst
	curr_unit = p_scene
	rotated_placement = rotated
	var anchor := _get_board_slot_at_grid(top_left)
	if anchor == null:
		item_inst.queue_free()
		curr_unit_inst = null
		curr_unit = null
		return false
	targetCell = anchor
	objectCells = _get_object_cells_for_anchor(anchor)
	if not _check_and_highlight_cells(objectCells):
		_reset_highlight(objectCells)
		item_inst.queue_free()
		curr_unit_inst = null
		curr_unit = null
		return false

	for cell in objectCells:
		cell.full = true

	var grid_pos: Vector2 = objectCells[0].board_position
	var unit_size = item_inst.rotated_placement_size if rotated else item_inst.placement_size
	var unit_vec = item_inst.rotated_vectors if rotated else item_inst.placement_vectors

	place_on_board(grid_pos, unit_size, p_scene)

	var router_excl := _router_exclusion_radius_from_card_inst(item_inst)
	if router_excl > 0.0:
		var center := _placement_center_global_from_cells(objectCells, unit_size)
		var top_i := Vector2i(int(grid_pos.x), int(grid_pos.y))
		_placed_router_exclusions.append({
			"center": center,
			"radius": router_excl,
			"top_corner": top_i,
			"size": unit_size,
		})

	battle_manager.add_unit_to_board(item_inst, objectCells[0].position, unit_vec, true)
	_reset_highlight(objectCells)
	item_inst.queue_free()
	curr_unit_inst = null
	curr_unit = null
	isValid = false
	return true


func _load_formation_rows_on_player_board(rows: Array) -> int:
	if enemy_spawner == null:
		return 0
	var seen_groups := {}
	var placed := 0
	for parsed in rows:
		if parsed.is_empty():
			continue
		var scene: PackedScene = enemy_spawner.pick_unit_scene_for_entry(parsed, seen_groups)
		if scene == null:
			continue
		var top := Vector2i(int(parsed["x"]), int(parsed["y"]))
		if _place_unit_card_programmatic(scene, top, false):
			placed += 1
	return placed


func _sanitize_formation_filename_part(s: String) -> String:
	var out := ""
	for i in s.length():
		var ch := s[i]
		if ch == "/" or ch == "\\" or ch == ":" or ch == "*" or ch == "?" or ch == "\"" or ch == "<" or ch == ">" or ch == "|":
			continue
		out += ch
	return out if out.length() > 0 else "formation"


func _save_editor_formation_to_new_csv() -> String:
	var row_dicts: Array = []
	for x in unit_board_width:
		for y in unit_board_height:
			var entry = unit_board_space_map[x][y]
			if entry == null:
				continue
			var top_corner: Vector2i = entry[1]
			if top_corner.x != x or top_corner.y != y:
				continue
			var packed: PackedScene = entry[0]
			var sz: Vector2 = entry[2]
			var card = packed.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
			if card == null or not card.has_method("setup_unit"):
				if card:
					card.queue_free()
				continue
			card.setup_unit()
			var exact := ""
			if "item_name" in card:
				exact = str(card.item_name)
			card.queue_free()
			row_dicts.append({
				"x": top_corner.x,
				"y": top_corner.y,
				"w": int(sz.x),
				"h": int(sz.y),
				"role": 1,
				"group": 1,
				"exact": exact,
			})

	if row_dicts.is_empty():
		return "Nothing placed on the board."

	var lines: PackedStringArray = []
	lines.append("Name,Level,X,Y,W,H,Role,Group,Exact_Unit")
	var first := true
	for r in row_dicts:
		var nc := formation_editor_name if first else ""
		var lc := formation_editor_level if first else ""
		first = false
		lines.append("%s,%s,%d,%d,%d,%d,%d,%d,%s" % [
			nc, lc, r["x"], r["y"], r["w"], r["h"], r["role"], r["group"], r["exact"]
		])
	var text := "\n".join(lines) + "\n"

	var name_part := _sanitize_formation_filename_part(formation_editor_name)
	var ts := str(Time.get_ticks_msec())
	var fname := "formations_%s_%s.csv" % [name_part, ts]
	var res_path := "res://Data/%s" % fname
	var user_path := "user://formation_exports/%s" % fname

	var f := FileAccess.open(res_path, FileAccess.WRITE)
	if f:
		f.store_string(text)
		f.close()
		return "OK:Saved %s" % ProjectSettings.globalize_path(res_path)

	DirAccess.make_dir_recursive_absolute("user://formation_exports")
	f = FileAccess.open(user_path, FileAccess.WRITE)
	if f:
		f.store_string(text)
		f.close()
		return "OK:Saved %s (res:// not writable; used user://)" % ProjectSettings.globalize_path(user_path)
	return "Could not write formation CSV."

func _on_spell_slot_clicked(slot: SpellBarSlot) -> void:
	# In battle mode: enter casting mode (only if slot has a spell)
	if not deployment_mode and not slot.is_empty() and slot.spell_inst:
		casting_mode = true
		casting_slot = slot

func _on_spell_slot_right_clicked(slot: SpellBarSlot) -> void:
	# In deployment mode: return spell to inventory
	if deployment_mode and not slot.is_empty():
		inventory.add_item(slot.item_name, 1)
		# Remove one committed instance (if present) since it was un-equipped.
		_committed_spell_item_names.erase(slot.item_name)
		spell_bar.remove_spell_at(slot)

func _on_inventory_inspect_requested(item_inst: Item, item_name: String, source_global_pos: Vector2) -> void:
	if item_inst == null:
		return
	if item_details_card.visible:
		item_details_card.hide_details()
		return
	var payload := item_details_builder.build_payload(item_inst, item_name)
	item_details_card.show_details(payload, source_global_pos)

func _exit_casting_mode() -> void:
	if casting_slot and is_instance_valid(casting_slot.spell_inst):
		var si: Base_Spell = casting_slot.spell_inst
		if si.handles_casting_input():
			si.on_casting_cancel()
		si.clear_preview()
	casting_mode = false
	casting_slot = null

## Convert viewport/screen mouse position to world position (accounts for camera pan and zoom).
func _get_world_mouse_position() -> Vector2:
	var vp := get_viewport()
	return vp.get_canvas_transform().affine_inverse() * vp.get_mouse_position()

## Clear the placement grid and BoardSlot state so the next deployment starts fresh.
func _clear_placement_grid() -> void:
	_placed_router_exclusions.clear()
	for i in unit_board_width:
		for j in unit_board_height:
			unit_board_space_map[i][j] = null
	var default_slot_color := Color(0.5, 0.5, 0.5, 0.5)
	for cell in unit_board.get_children():
		if cell is BoardSlot:
			cell.full = false
			cell.change_color(default_slot_color)
	
#### Helper Methods
func _check_and_highlight_cells(cells: Array) -> bool:	
	if curr_unit_inst == null:
		# No selected unit (or ran out). Nothing to validate/place.
		return false
	var valid = true

	# cell count check - prevents placing units on the edges of the board
	var active_size: Vector2 = curr_unit_inst.rotated_placement_size if rotated_placement else curr_unit_inst.placement_size
	var expected_count = int(active_size.x) * int(active_size.y)
	if expected_count != cells.size():
		valid = false

	for cell in cells:
		if cell.full:
			cell.change_color(Color.RED)
			valid = false
		else:
			cell.change_color(Color.GREEN)
	if valid and _router_placement_overlaps_exclusion(cells, active_size):
		valid = false
		for cell in cells:
			cell.change_color(Color.RED)
	return valid

func _place_unit():
	for cell in objectCells:
		cell.full = true
	
	var grid_pos : Vector2 = objectCells[0].board_position
	var unit_size = curr_unit_inst.rotated_placement_size if rotated_placement else curr_unit_inst.placement_size
	var unit_vec = curr_unit_inst.rotated_vectors if rotated_placement else curr_unit_inst.placement_vectors

	place_on_board(grid_pos, unit_size, curr_unit)
	var router_excl := _router_exclusion_radius_for_current_unit()
	if router_excl > 0.0:
		var center := _placement_center_global_from_cells(objectCells, unit_size)
		var top_i := Vector2i(int(grid_pos.x), int(grid_pos.y))
		_placed_router_exclusions.append({
			"center": center,
			"radius": router_excl,
			"top_corner": top_i,
			"size": unit_size,
		})
	battle_manager.add_unit_to_board(curr_unit_inst, objectCells[0].position, unit_vec, true)
	_reset_highlight(objectCells)

	# Allow the player to keep placing this unit as long as there still are cards left
	if curr_inv_slot.remove_item(1) == false:
		curr_unit = null
		curr_unit_inst = null
		if selector_rect_debug:
			selector_rect = Rect2(0,0,0,0)
		
		objectCells.clear()
	else:
		# Visually mark that you cannot keep placing here
		_check_and_highlight_cells(objectCells)
		
	isValid = false

# Placement logic using logical grid
func check_unit_space_availability(top_corner: Vector2, size: Vector2) -> bool:
	for x in size.x:
		for y in size.y:
			if unit_board_space_map[top_corner.x + x][top_corner.y + y] != null:
				return false
	return true

func place_on_board(top_corner: Vector2, size: Vector2, unit_ref: PackedScene) -> void:
	for x in size.x:
		for y in size.y:
			unit_board_space_map[top_corner.x + x][top_corner.y + y] = [unit_ref, top_corner, size]


func _router_exclusion_radius_for_current_unit() -> float:
	if curr_unit_inst is Unit_Card:
		var uc := curr_unit_inst as Unit_Card
		if uc.is_router_card:
			return uc.router_exclusion_radius
	return 0.0


func _placement_center_global_from_cells(cells: Array, size: Vector2) -> Vector2:
	if cells.is_empty():
		return Vector2.ZERO
	var sorted: Array = cells.duplicate()
	sorted.sort_custom(func(a, b): return _cell_order(a, b) < 0)
	var tl := (sorted[0] as BoardSlot).global_position
	var cw := float(unit_board.cellWidth)
	var ch := float(unit_board.cellHeight)
	return tl + Vector2(size.x * cw, size.y * ch) * 0.5


func _router_placement_overlaps_exclusion(cells: Array, size: Vector2) -> bool:
	if curr_unit_inst == null or not curr_unit_inst is Unit_Card:
		return false
	var uc := curr_unit_inst as Unit_Card
	if not uc.is_router_card:
		return false
	var center := _placement_center_global_from_cells(cells, size)
	for z in _placed_router_exclusions:
		if center.distance_to(z["center"]) < float(z["radius"]):
			return true
	return false


## Returns the BoardSlot at the given world position (transformed coords; works with pan/zoom).
func _get_cell_at_world_position(world_pos: Vector2) -> BoardSlot:
	var local := world_pos - unit_board.global_position
	var tile_x := int(local.x / unit_board.cellWidth)
	var tile_y := int(local.y / unit_board.cellHeight)
	if tile_x < 0 or tile_x >= unit_board_width or tile_y < 0 or tile_y >= unit_board_height:
		return null
	var idx := tile_x + tile_y * unit_board_width
	var children := unit_board.get_children()
	if idx >= children.size():
		return null
	var cell = children[idx]
	return cell as BoardSlot if cell is BoardSlot else null

func _reset_highlight(cells : Array):
	for cell: Control in cells:
		cell.change_color(Color(0.5, 0.5, 0.5, 0.5))

func _get_object_cells() -> Array:
	if targetCell:
		return _get_object_cells_for_anchor(targetCell)
	return []

## Returns cells that would be covered by placing current unit with top-left at anchor_cell.
## Uses world-space rect so it works with camera pan/zoom.
func _get_object_cells_for_anchor(anchor_cell: BoardSlot) -> Array:
	var cells: Array = []
	var unit_rect: Rect2
	if curr_unit_inst == null:
		unit_rect = Rect2(Vector2.ZERO, Vector2.ZERO)
	else:
		var origin := anchor_cell.global_position
		var cell_size := Vector2(unit_board.cellWidth, unit_board.cellHeight)
		if rotated_placement:
			unit_rect = Rect2(origin, curr_unit_inst.rotated_placement_size * cell_size)
		else:
			unit_rect = Rect2(origin, curr_unit_inst.placement_size * cell_size)
	if selector_rect_debug:
		selector_rect = unit_rect
	for cell in unit_board.get_children():
		if cell is Control and cell.get_global_rect().intersects(unit_rect):
			cells.append(cell)
	# Top-left first (for _place_unit which uses objectCells[0] as origin).
	cells.sort_custom(func(a, b): return _cell_order(a, b) < 0)
	return cells


func _cell_order(a: Control, b: Control) -> int:
	var pa := (a as BoardSlot).board_position
	var pb := (b as BoardSlot).board_position
	if pa.y != pb.y:
		return int(pa.y - pb.y)
	return int(pa.x - pb.x)

## Returns BoardSlots in the grid rect [top_corner, top_corner+size) (for reset after removal).
func _get_cells_in_rect(top_corner: Vector2i, size: Vector2) -> Array:
	var cells: Array = []
	for dx in int(size.x):
		for dy in int(size.y):
			var tx := top_corner.x + dx
			var ty := top_corner.y + dy
			if tx >= 0 and tx < unit_board_width and ty >= 0 and ty < unit_board_height:
				var idx := tx + ty * unit_board_width
				var children := unit_board.get_children()
				if idx < children.size():
					var c = children[idx]
					if c is BoardSlot:
						cells.append(c)
	return cells


func get_unit_at_tile(tile: Vector2i): # Returns PackedScene unit ref, left corner position, and placement vector
	if tile.x >= 0 and tile.x < unit_board_width and tile.y >= 0 and tile.y < unit_board_height:
		return unit_board_space_map[tile.x][tile.y]
	return null

func _update_tactical_cursor() -> void:
	if not battle_manager or not tactical_cursor:
		return
	# Selected unit panel only visible during battle; clear when on map.
	if not battle_manager.visible:
		tactical_cursor.set_selected_unit(null)


func _on_unit_selected(unit: Base_Unit) -> void:
	tactical_cursor.set_selected_unit(unit)


func _on_battle_ended_clear_selection(_victory: bool) -> void:
	tactical_cursor.set_selected_unit(null)

func _on_battle_ended(victory: bool) -> void:
	_refund_items_after_battle()
	_on_battle_ended_clear_selection(victory)

func _refund_items_after_battle() -> void:
	# Refund spells that were equipped for this battle (even if they were cast/removed during battle).
	if inventory and spell_bar:
		for item_name in _committed_spell_item_names:
			inventory.add_item(item_name, 1)
		_committed_spell_item_names.clear()
		for slot in spell_bar.slots:
			if slot and not slot.is_empty():
				spell_bar.remove_spell_at(slot)

	# Refund deployed units back to inventory and reset the placement grid.
	if inventory:
		var counts_by_scene: Dictionary = {} # PackedScene -> int
		for x in unit_board_width:
			for y in unit_board_height:
				var entry = unit_board_space_map[x][y]
				if entry == null:
					continue
				# entry = [unit_ref, top_corner, size]
				var unit_ref: PackedScene = entry[0]
				var top_corner: Vector2i = entry[1]
				if top_corner.x != x or top_corner.y != y:
					continue # only count once per placed unit
				counts_by_scene[unit_ref] = int(counts_by_scene.get(unit_ref, 0)) + 1

		for unit_ref in counts_by_scene.keys():
			var count := int(counts_by_scene[unit_ref])
			if count <= 0:
				continue
			var item_inst = (unit_ref as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
			if item_inst and item_inst.has_method("setup_unit"):
				item_inst.setup_unit()
			if item_inst and "item_name" in item_inst:
				inventory.add_item(item_inst.item_name, count)
			if item_inst:
				item_inst.queue_free()

	_clear_placement_grid()
	deployment_mode = false
	_exit_casting_mode()

func is_mouse_over_ui_element(mouse_pos: Vector2) -> bool:
	"""
	This is needed because input will trigger before the "pressed" signal is preocessed
	Check if mouse is over interactive UI elements (not the board).
	Returns true if over UI, false if over board/game area.
	"""
	# Check inventory window
	if inventory and inventory.visible:
		var inv_rect = inventory.get_global_rect()
		if inv_rect.has_point(mouse_pos):
			return true
	
	# Check spell bar
	if spell_bar and spell_bar.visible:
		var spell_rect = spell_bar.get_global_rect()
		if spell_rect.has_point(mouse_pos):
			return true
	
	# Check end prep button
	if end_prep and end_prep.visible:
		var button_rect = end_prep.get_global_rect()
		if button_rect.has_point(mouse_pos):
			return true
	
	if battle_rewards_ui and battle_rewards_ui.visible:
		var rewards_rect = battle_rewards_ui.get_global_rect()
		if rewards_rect.has_point(mouse_pos):
			return true

	if shop_ui and shop_ui.visible:
		var shop_rect = shop_ui.get_global_rect()
		if shop_rect.has_point(mouse_pos):
			return true

	if shop_toggle_button and shop_toggle_button.visible and not shop_toggle_button.disabled:
		var toggle_rect = shop_toggle_button.get_global_rect()
		if toggle_rect.has_point(mouse_pos):
			return true

	if rest_ui and rest_ui.visible:
		var rest_rect = rest_ui.get_global_rect()
		if rest_rect.has_point(mouse_pos):
			return true

	if rest_toggle_button and rest_toggle_button.visible and not rest_toggle_button.disabled:
		var rest_toggle_rect = rest_toggle_button.get_global_rect()
		if rest_toggle_rect.has_point(mouse_pos):
			return true

	if random_event_ui and random_event_ui.visible:
		var event_rect = random_event_ui.get_global_rect()
		if event_rect.has_point(mouse_pos):
			return true

	if event_toggle_button and event_toggle_button.visible and not event_toggle_button.disabled:
		var event_toggle_rect = event_toggle_button.get_global_rect()
		if event_toggle_rect.has_point(mouse_pos):
			return true
	
	return false
