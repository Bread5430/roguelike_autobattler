extends TimedSpellZone
class_name CrawlerSwarmZone

const CRAWLER_SCENE := preload("res://Units/unit_scenes/basic_chaff/basicChaff.tscn")

@export var initial_count : int = 10
@export var wave_count : int = 2
@export var wave_interval : float = 2.0
@export var total_waves : int = 5

var _waves_spawned : int = 0
var _total_spawned : int = 0


func _ready() -> void:
	fill_color = Color(0.45, 0.8, 0.3, 0.2)
	outline_color = Color(0.35, 0.7, 0.2, 0.85)
	super._ready()
	_spawn_crawlers(initial_count)


func _process(delta: float) -> void:
	var next_elapsed = elapsed + delta
	while _waves_spawned < total_waves and next_elapsed >= float(_waves_spawned + 1) * wave_interval:
		_spawn_crawlers(wave_count)
		_waves_spawned += 1
	super._process(delta)


func _spawn_crawlers(count: int) -> void:
	if battle_manager == null:
		return
	for index in count:
		var angle = TAU * float(_total_spawned + index) / float(maxi(count, 1))
		var ring = 24.0 + 10.0 * float((_total_spawned + index) % 3)
		var spawn_position = global_position + Vector2.from_angle(angle) * ring
		battle_manager.spawn_runtime_unit(CRAWLER_SCENE, spawn_position, true)
	_total_spawned += count
