extends TimedSpellZone
class_name RebootZone

@export var revive_cap : int = 5

var _revive_count : int = 0


func _ready() -> void:
	fill_color = Color(0.25, 0.8, 1.0, 0.22)
	outline_color = Color(0.2, 0.7, 1.0, 0.9)
	super._ready()
	var unit_parent = get_unit_parent()
	if unit_parent == null:
		return
	if not unit_parent.child_entered_tree.is_connected(_on_child_entered):
		unit_parent.child_entered_tree.connect(_on_child_entered)
	for child in unit_parent.get_children():
		_on_child_entered(child)


func _exit_tree() -> void:
	var unit_parent = get_unit_parent()
	if unit_parent != null and unit_parent.child_entered_tree.is_connected(_on_child_entered):
		unit_parent.child_entered_tree.disconnect(_on_child_entered)


func _on_child_entered(child: Node) -> void:
	if not child is Base_Unit:
		return
	var unit: Base_Unit = child
	if not unit.died.is_connected(_on_unit_died):
		unit.died.connect(_on_unit_died)


func _on_unit_died(unit: Base_Unit) -> void:
	if _revive_count >= revive_cap or unit == null or not is_instance_valid(unit):
		return
	if unit.is_spell_immune():
		return
	if global_position.distance_to(unit.global_position) > radius:
		return
	var scene_path = unit.scene_file_path
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		return
	var unit_scene = load(scene_path) as PackedScene
	if unit_scene == null:
		return
	var death_position = unit.global_position
	var saved_upgrade_path = unit.upgrade_path
	_revive_count += 1
	battle_manager.spawn_runtime_unit(unit_scene, death_position, true, saved_upgrade_path)
	if _revive_count >= revive_cap:
		queue_free()
