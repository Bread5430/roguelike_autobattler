extends StatusEffectDef
class_name InfestedDef

## On death, host spawns crawlers (basic_chaff) equal to its bandwidth_cost for the infector's faction.

const CRAWLER_SCENE_PATH := "res://Units/unit_scenes/basic_chaff/basicChaff.tscn"


func _init() -> void:
	effect_id = &"infested"
	display_name = "Infested"
	default_duration = 999999.0
	max_stacks = 1
	StatusEffectTune.apply_csv(self, effect_id)


func get_polarity() -> Polarity:
	return Polarity.DEBUFF


func on_host_death(instance: StatusEffectInstance, host: Base_Unit, _source: Base_Unit) -> void:
	if host == null or not is_instance_valid(host):
		return
	var spawn_faction = bool(instance.custom_state.get("spawn_faction", false))
	var count = maxi(1, host.bandwidth_cost)
	var parent_node = host.get_parent()
	if parent_node == null:
		return
	if not ResourceLoader.exists(CRAWLER_SCENE_PATH):
		return
	var crawler_scene: PackedScene = load(CRAWLER_SCENE_PATH) as PackedScene
	if crawler_scene == null:
		return
	var spawn_origin = host.global_position
	var battle_manager = parent_node.get_parent()
	for i in count:
		var angle = TAU * float(i) / float(count)
		var world_pos = spawn_origin + Vector2(cos(angle), sin(angle)) * 12.0
		if battle_manager != null and battle_manager.has_method("spawn_runtime_unit"):
			battle_manager.spawn_runtime_unit(crawler_scene, world_pos, spawn_faction)
			continue
		var crawler = crawler_scene.instantiate()
		if crawler == null:
			continue
		crawler.faction = spawn_faction
		crawler.position = host.position + Vector2(cos(angle), sin(angle)) * 12.0
		parent_node.add_child(crawler)
		if crawler is Base_Unit:
			var bu: Base_Unit = crawler
			bu.post_ready()
			bu.set_start_stop(true)
