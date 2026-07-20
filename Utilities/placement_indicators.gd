extends Node2D
class_name PlacementIndicators

## Prep-only overlay: pack-to-enemy targeting lines and ranged attack-range shapes
## while the player is placing a unit card.

const LINE_COLOR := Color(0.95, 0.85, 0.25, 0.85)
const LINE_WIDTH := 2.0
const RANGE_STROKE := Color(0.3, 0.7, 1.0, 0.85)
const RANGE_STROKE_WIDTH := 2.0
const ARC_POINTS := 48

## { "points": Array[Vector2], "center": Vector2 }
var enemy_packs: Array[Dictionary] = []

var _preview_active: bool = false
var _player_points: Array[Vector2] = []
var _player_center: Vector2 = Vector2.ZERO
var _unit_world_positions: Array[Vector2] = []
var _is_melee: bool = true
## World-pixel radius from unit center (attack_range + own collision radius).
var _attack_range: float = 0.0
## Cached line segments for _draw: each is [from, to] in world space.
var _line_segments: Array[PackedVector2Array] = []


func clear_all() -> void:
	enemy_packs.clear()
	clear_preview()


func clear_enemy_packs() -> void:
	enemy_packs.clear()
	_recompute_lines()
	queue_redraw()


func clear_preview() -> void:
	_preview_active = false
	_player_points.clear()
	_unit_world_positions.clear()
	_player_center = Vector2.ZERO
	_is_melee = true
	_attack_range = 0.0
	_line_segments.clear()
	queue_redraw()


func register_enemy_pack(anchor: Vector2, footprint_size: Vector2, cell: Vector2, is_multi: bool) -> void:
	var points: Array[Vector2] = compute_pack_points(anchor, footprint_size, cell, is_multi)
	var center: Vector2 = _footprint_center(anchor, footprint_size, cell)
	enemy_packs.append({
		"points": points,
		"center": center,
	})
	if _preview_active:
		_recompute_lines()
		queue_redraw()


## footprint_size is in board cells; cell is (cellWidth, cellHeight).
static func compute_pack_points(
	anchor: Vector2,
	footprint_size: Vector2,
	cell: Vector2,
	is_multi: bool
) -> Array[Vector2]:
	var rect: Rect2 = _footprint_rect(anchor, footprint_size, cell)
	var center: Vector2 = rect.get_center()
	var result: Array[Vector2] = []
	if not is_multi:
		result.append(center)
		return result
	if rect.size.x >= rect.size.y:
		result.append(Vector2(rect.position.x + rect.size.x / 3.0, center.y))
		result.append(Vector2(rect.position.x + 2.0 * rect.size.x / 3.0, center.y))
	else:
		result.append(Vector2(center.x, rect.position.y + rect.size.y / 3.0))
		result.append(Vector2(center.x, rect.position.y + 2.0 * rect.size.y / 3.0))
	return result


static func footprint_center(anchor: Vector2, footprint_size: Vector2, cell: Vector2) -> Vector2:
	return _footprint_center(anchor, footprint_size, cell)


static func _footprint_center(anchor: Vector2, footprint_size: Vector2, cell: Vector2) -> Vector2:
	return _footprint_rect(anchor, footprint_size, cell).get_center()


static func _footprint_rect(anchor: Vector2, footprint_size: Vector2, cell: Vector2) -> Rect2:
	return Rect2(anchor, Vector2(footprint_size.x * cell.x, footprint_size.y * cell.y))


func update_preview(
	player_points: Array[Vector2],
	player_center: Vector2,
	unit_world_positions: Array[Vector2],
	is_melee: bool,
	attack_range: float
) -> void:
	_preview_active = true
	_player_points = player_points.duplicate()
	_player_center = player_center
	_unit_world_positions = unit_world_positions.duplicate()
	_is_melee = is_melee
	_attack_range = attack_range
	_recompute_lines()
	queue_redraw()


func _recompute_lines() -> void:
	_line_segments.clear()
	if not _preview_active or _player_points.is_empty() or enemy_packs.is_empty():
		return

	var matches: Array[Dictionary] = []
	for p in _player_points:
		var best = _nearest_enemy_point(p)
		if best.is_empty():
			continue
		matches.append(best)

	if matches.is_empty():
		return

	if matches.size() == 1:
		_line_segments.append(PackedVector2Array([_player_points[0], matches[0]["point"]]))
		return

	# Two player points.
	var a: Dictionary = matches[0]
	var b: Dictionary = matches[1]
	var same_pack: bool = int(a["pack_index"]) == int(b["pack_index"])
	var same_point: bool = a["point"].distance_squared_to(b["point"]) < 0.01
	if same_pack or same_point:
		var target: Vector2 = a["point"]
		if same_pack and not same_point:
			target = enemy_packs[int(a["pack_index"])]["center"]
		_line_segments.append(PackedVector2Array([_player_center, target]))
	else:
		_line_segments.append(PackedVector2Array([_player_points[0], a["point"]]))
		_line_segments.append(PackedVector2Array([_player_points[1], b["point"]]))


func _nearest_enemy_point(from: Vector2) -> Dictionary:
	var best_dist_sq: float = INF
	var best: Dictionary = {}
	for pack_i in enemy_packs.size():
		var pack: Dictionary = enemy_packs[pack_i]
		var points: Array = pack["points"]
		for pt in points:
			var d: float = from.distance_squared_to(pt)
			if d < best_dist_sq:
				best_dist_sq = d
				best = {
					"point": pt,
					"pack_index": pack_i,
				}
	return best


func _draw() -> void:
	if not _preview_active:
		return
	_draw_range_shape()
	for seg in _line_segments:
		if seg.size() >= 2:
			draw_line(to_local(seg[0]), to_local(seg[1]), LINE_COLOR, LINE_WIDTH, true)


func _draw_range_shape() -> void:
	if _is_melee or _attack_range <= 0.0 or _unit_world_positions.is_empty():
		return
	if _unit_world_positions.size() == 1:
		_draw_range_circle(to_local(_unit_world_positions[0]), _attack_range)
		return
	var extremes: PackedVector2Array = _extreme_unit_centers()
	_draw_stadium(to_local(extremes[0]), to_local(extremes[1]), _attack_range)


func _extreme_unit_centers() -> PackedVector2Array:
	var positions: Array[Vector2] = _unit_world_positions
	# Prefer axis of max variance among unit positions (longer pack axis).
	var mean: Vector2 = Vector2.ZERO
	for p in positions:
		mean += p
	mean /= float(positions.size())
	var var_x: float = 0.0
	var var_y: float = 0.0
	for p in positions:
		var d: Vector2 = p - mean
		var_x += d.x * d.x
		var_y += d.y * d.y
	var use_x: bool = var_x >= var_y
	var min_p: Vector2 = positions[0]
	var max_p: Vector2 = positions[0]
	var min_proj: float = positions[0].x if use_x else positions[0].y
	var max_proj: float = min_proj
	for i in range(1, positions.size()):
		var proj: float = positions[i].x if use_x else positions[i].y
		if proj < min_proj:
			min_proj = proj
			min_p = positions[i]
		if proj > max_proj:
			max_proj = proj
			max_p = positions[i]
	return PackedVector2Array([min_p, max_p])


func _draw_range_circle(center: Vector2, radius: float) -> void:
	draw_arc(center, radius, 0.0, TAU, ARC_POINTS, RANGE_STROKE, RANGE_STROKE_WIDTH, true)


func _draw_stadium(a: Vector2, b: Vector2, radius: float) -> void:
	var diff: Vector2 = b - a
	var length: float = diff.length()
	if length < 0.5:
		_draw_range_circle(a, radius)
		return
	var dir: Vector2 = diff / length
	var perp: Vector2 = Vector2(-dir.y, dir.x) * radius
	# Outline only: long sides + semicircle caps.
	draw_line(a + perp, b + perp, RANGE_STROKE, RANGE_STROKE_WIDTH, true)
	draw_line(a - perp, b - perp, RANGE_STROKE, RANGE_STROKE_WIDTH, true)
	var angle: float = dir.angle()
	draw_arc(a, radius, angle + PI * 0.5, angle + PI * 1.5, ARC_POINTS / 2, RANGE_STROKE, RANGE_STROKE_WIDTH, true)
	draw_arc(b, radius, angle - PI * 0.5, angle + PI * 0.5, ARC_POINTS / 2, RANGE_STROKE, RANGE_STROKE_WIDTH, true)
