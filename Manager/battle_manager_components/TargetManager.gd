extends Node

const DIRECTIONS = [
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(1, 1),
	Vector2i(-1, 0),
	Vector2i(0, -1),
	Vector2i(-1, -1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
]

## After a cache reset, refresh at most this many grid cells per battle-manager process tick.
@export var snapshot_cells_per_tick: int = 96
## When a BFS layer has at least this many cells, neighbor expansion uses the worker pool.
@export var bfs_parallel_layer_threshold: int = 16

@export var min_bfs_depth = 4

var cached_enemies = {}
var cached_allies = {}
var target_iter = 0
var perf_counters := {
	"queries": 0,
	"cache_hits": 0,
	"bfs_calls": 0,
	"closest_queries": 0,
	"closest_candidates_scanned": 0
}

var _snapshot_buffers_ready: bool = false
var _grid_w: int = 0
var _grid_h: int = 0
var _total_cells: int = 0
## Per flat cell: last [member _snapshot_wave_id] when [member _living_enemies]/[member _living_allies] were rebuilt.
var _cell_wave: PackedInt32Array = PackedInt32Array()
var _snapshot_wave_id: int = 0
var _snapshot_refresh_cursor: int = 0
var _snapshot_refresh_active: bool = false

## Mirrors board layout: [x][y] -> Array of living [Base_Unit].
var _living_enemies: Array = []
var _living_allies: Array = []

var _bfs_seen_stamp: PackedInt32Array = PackedInt32Array()
var _bfs_visit_serial: int = 0

var _worker_pool: GenericWorkerPool = null
# Battle manager reference
var bm 

func post_ready() -> void:
	_worker_pool = get_tree().get_first_node_in_group("GENERIC_WORKER_POOL") as GenericWorkerPool
	bm = get_parent()
	_ensure_snapshot_buffers()



func reset_cache() -> void:
	target_iter = (target_iter + 1) % 100
	cached_allies.clear()
	cached_enemies.clear()
	_ensure_snapshot_buffers()
	_snapshot_wave_id += 1
	_snapshot_refresh_cursor = 0
	_snapshot_refresh_active = true


func advance_snapshot_refresh(budget: int) -> void:
	if not _snapshot_refresh_active:
		return
	_ensure_snapshot_buffers()
	var n := mini(budget, snapshot_cells_per_tick)
	for _i in n:
		if _snapshot_refresh_cursor >= _total_cells:
			_snapshot_refresh_active = false
			return
		var idx := _snapshot_refresh_cursor
		_snapshot_refresh_cursor += 1
		var x := idx / _grid_h
		var y := idx % _grid_h
		_rebuild_living_cell(x, y)


func get_perf_counters() -> Dictionary:
	return perf_counters.duplicate()


func reset_perf_counters() -> void:
	for key in perf_counters.keys():
		perf_counters[key] = 0


func get_targets(faction: bool, location: Vector2, num_targets: int = 10, max_range: int = 500) -> Array:
	perf_counters["queries"] += 1
	var target_location: Vector2i = get_parent().world_to_grid(location)

	if target_location in cached_enemies and faction == false:
		perf_counters["cache_hits"] += 1
		if num_targets > cached_enemies[target_location].size():
			num_targets = cached_enemies[target_location].size()
		return cached_enemies[target_location].slice(0, num_targets)

	if target_location in cached_allies and faction == true:
		perf_counters["cache_hits"] += 1
		if num_targets > cached_allies[target_location].size():
			num_targets = cached_allies[target_location].size()
		return cached_allies[target_location].slice(0, num_targets)

	_ensure_snapshot_buffers()
	perf_counters["bfs_calls"] += 1

	var grid_w: int = int(bm.tile_map_size.x)
	var grid_h: int = int(bm.tile_map_size.y)
	var max_depth: int = maxi(int(max_range / bm.tile_size), min_bfs_depth)

	var visit_id := _alloc_bfs_visit_id()
	var result: Array = []
	var start_cell: Vector2i = bm.world_to_grid(location)
	var curr: Array[Vector2i] = [start_cell]
	_stamp_bfs_cell(start_cell.x, start_cell.y, visit_id, grid_w, grid_h)

	var curr_depth := 0
	while curr_depth < max_depth and not curr.is_empty():
		curr_depth += 1
		var next: Array[Vector2i] = []

		for cell in curr:
			for u in _living_units_for_bfs(faction, cell):
				if _is_living_target(u):
					result.append(u)

		if _should_expand_bfs_next_layer(curr_depth, max_depth):
			if curr.size() >= bfs_parallel_layer_threshold and _worker_pool != null:
				_append_bfs_neighbors_parallel(curr, visit_id, next, grid_w, grid_h)
			else:
				_append_bfs_neighbors_sequential(curr, visit_id, next, grid_w, grid_h)
			curr = next

	if faction:
		cached_allies[target_location] = result
	else:
		cached_enemies[target_location] = result

	if num_targets > result.size():
		num_targets = result.size()

	return result.slice(0, num_targets)


func get_closest_target(faction: bool, location: Vector2, max_range: int = 500) -> Base_Unit:
	var targets: Array = get_targets(faction, location, 3, max_range)
	perf_counters["closest_queries"] += 1
	var best: Base_Unit = null
	var best_dist_sq: float = INF
	for t in targets:
		if not _is_living_target(t):
			continue
		var d2: float = (t.position - location).length_squared()
		if d2 < best_dist_sq:
			best_dist_sq = d2
			best = t as Base_Unit
	perf_counters["closest_candidates_scanned"] += targets.size()
	return best


func get_closest_targets(faction: bool, location: Vector2, num_targets: int = 1, max_range: int = 500) -> Array:
	var targets: Array = get_targets(faction, location, num_targets, max_range)
	perf_counters["closest_queries"] += 1
	var scored: Array = []
	for t in targets:
		if not _is_living_target(t):
			continue
		scored.append({
			"target": t,
			"dist_sq": (t.position - location).length_squared()
		})
	perf_counters["closest_candidates_scanned"] += targets.size()
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["dist_sq"] < b["dist_sq"]
	)
	var out: Array = []
	var take_n := mini(num_targets, scored.size())
	for i in take_n:
		out.append(scored[i]["target"])
	return out


func _is_living_target(u: Variant) -> bool:
	if u == null or not is_instance_valid(u):
		return false
	if not u is Base_Unit:
		return false
	return u.curr_hp > 0


func _ensure_snapshot_buffers() -> void:
	if _snapshot_buffers_ready:
		return
	var ts: Variant = bm.get("tile_map_size")
	_grid_w = int((ts as Vector2i).x)
	_grid_h = int((ts as Vector2i).y)
	_total_cells = _grid_w * _grid_h

	_living_enemies.clear()
	_living_allies.clear()
	for x in range(_grid_w):
		var col_e: Array = []
		var col_a: Array = []
		for y in range(_grid_h):
			col_e.append([])
			col_a.append([])
		_living_enemies.append(col_e)
		_living_allies.append(col_a)

	_cell_wave.resize(_total_cells)
	_cell_wave.fill(-1)
	_bfs_seen_stamp.resize(_total_cells)
	_bfs_seen_stamp.fill(0)
	_snapshot_buffers_ready = true


func _cell_flat(x: int, y: int) -> int:
	return x * _grid_h + y


func _ensure_cell_current(x: int, y: int) -> void:
	var f := _cell_flat(x, y)
	if _cell_wave[f] != _snapshot_wave_id:
		_rebuild_living_cell(x, y)


func _rebuild_living_cell(x: int, y: int) -> void:
	var allies_cell: Array = bm.allies_tiles[x][y]
	var enemies_cell: Array = bm.enemies_tiles[x][y]
	var la: Array = _living_allies[x][y]
	var le: Array = _living_enemies[x][y]
	la.clear()
	le.clear()
	for u in allies_cell:
		if _is_living_target(u):
			la.append(u)
	for u in enemies_cell:
		if _is_living_target(u):
			le.append(u)
	_cell_wave[_cell_flat(x, y)] = _snapshot_wave_id


func _living_units_for_bfs(faction: bool, coord: Vector2i) -> Array:
	_ensure_cell_current(coord.x, coord.y)
	if faction:
		return _living_allies[coord.x][coord.y]
	return _living_enemies[coord.x][coord.y]


func _alloc_bfs_visit_id() -> int:
	_bfs_visit_serial += 1
	if _bfs_visit_serial > 2000000000:
		_bfs_visit_serial = 1
		_bfs_seen_stamp.fill(0)
	return _bfs_visit_serial


func _stamp_bfs_cell(x: int, y: int, visit_id: int, grid_w: int, grid_h: int) -> void:
	if x <= 0 or x >= grid_w - 1 or y <= 0 or y >= grid_h - 1:
		return
	var f := _cell_flat(x, y)
	_bfs_seen_stamp[f] = visit_id


func _bfs_stamp_at(x: int, y: int) -> int:
	var f := _cell_flat(x, y)
	return _bfs_seen_stamp[f]


func _should_expand_bfs_next_layer(curr_depth: int, max_depth: int) -> bool:
	return curr_depth < max_depth


func _append_bfs_neighbors_sequential(
	curr: Array[Vector2i],
	visit_id: int,
	next: Array[Vector2i],
	grid_w: int,
	grid_h: int
) -> void:
	for iv in curr:
		for dir in DIRECTIONS:
			var nl = iv + dir
			if nl.x <= 0 or nl.x >= grid_w - 1 or nl.y <= 0 or nl.y >= grid_h - 1:
				continue
			var f := _cell_flat(nl.x, nl.y)
			if _bfs_seen_stamp[f] == visit_id:
				continue
			_bfs_seen_stamp[f] = visit_id
			next.append(nl)


func _append_bfs_neighbors_parallel(
	curr: Array[Vector2i],
	visit_id: int,
	next: Array[Vector2i],
	grid_w: int,
	grid_h: int
) -> void:
	var curr_packed = Array()
	for c in curr:
		curr_packed.append(c)
	var n = curr_packed.size()
	var max_par: int = maxi(1, _worker_pool.max_concurrent_tasks)
	var num_chunks: int = mini(max_par, maxi(2, n / 4))
	if num_chunks < 2:
		_append_bfs_neighbors_sequential(curr, visit_id, next, grid_w, grid_h)
		return

	# Divide the array into chunks
	var bounds: Array[Vector2i] = []
	var base: int = n / num_chunks
	var rem: int = n % num_chunks
	var start_idx := 0
	for chunk in num_chunks:
		var chunk_sz: int = base + (1 if chunk < rem else 0)
		var end: int = start_idx + chunk_sz
		bounds.append(Vector2i(start_idx, end))
		start_idx = end

	# Bind chunks to threads and push start to workerpool
	var holders: Array[TargetingBfsWorkers.NeighborChunkHolder] = []
	var tasks: Array[Callable] = []
	for chunk_idx in range(num_chunks):
		var chunk_boundry: Vector2i = bounds[chunk_idx]
		var holder := TargetingBfsWorkers.NeighborChunkHolder.new()
		holders.append(holder)
		tasks.append(
			Callable(TargetingBfsWorkers, "neighbor_slice").bind(
				int(chunk_boundry.x), int(chunk_boundry.y), curr_packed, grid_w, grid_h, holder
			)
		)
	# This run wave internally has a wait to ensure synchronization
	_worker_pool.run_callables_wave_bounded(tasks)

	# Fetch outputs from threads
	var merged = Array()
	for chunk_idx in range(num_chunks):
		var h: TargetingBfsWorkers.NeighborChunkHolder = holders[chunk_idx]
		for j in h.packed.size():
			merged.append(h.packed[j])

	# From the outputs, update if the bfs has seen marked cells
	for j in merged.size():
		var nl = merged[j]
		var f := _cell_flat(nl.x, nl.y)
		if _bfs_seen_stamp[f] == visit_id:
			continue
		_bfs_seen_stamp[f] = visit_id
		next.append(nl)
