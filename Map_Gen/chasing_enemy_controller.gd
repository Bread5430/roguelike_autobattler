extends Node2D
class_name ChasingEnemyController

@export var total_steps: int = 8
var current_step: int = 0
## Leading-edge X at step 0 (one grid cell behind the map).
var start_front_x: float = 0.0
## Horizontal distance the leading edge moves per step.
var step_size_x: float = 0.0
## Vertical half-extent of the capsule body and leading cap (full height = 2× this).
var map_half_height: float = 360.0
var capsule_length: float = 5000.0
var map_center_y: float = 360.0
@export var fill_color: Color = Color(0.9, 0.15, 0.15, 0.35)


func configure(
	p_total_steps: int,
	p_start_front_x: float,
	p_step_size_x: float,
	p_center_y: float,
	p_half_height: float,
	p_capsule_length: float,
	p_fill_color: Color
) -> void:
	total_steps = p_total_steps
	current_step = 0
	start_front_x = p_start_front_x
	step_size_x = p_step_size_x
	map_center_y = p_center_y
	map_half_height = p_half_height
	capsule_length = p_capsule_length
	fill_color = p_fill_color


func get_end_front_x() -> float:
	return start_front_x + float(total_steps) * step_size_x


func get_cap_rightmost_x_at_step(step: int) -> float:
	return get_front_center_at_step(step).x + map_half_height


func get_front_center_at_step(step: int) -> Vector2:
	var clamped := clampi(step, 0, total_steps)
	var x := start_front_x + float(clamped) * step_size_x
	return Vector2(x, map_center_y)


func get_front_center() -> Vector2:
	return get_front_center_at_step(current_step)


func is_node_covered(node: MapNode, node_radius: float) -> bool:
	var pos := node.global_position
	var front := get_front_center()
	var half_h := map_half_height + node_radius

	if absf(pos.y - map_center_y) > half_h:
		return false

	var body_left := front.x - capsule_length
	if pos.x < body_left:
		return false

	# Rectangular body (flat leading edge at front.x).
	if pos.x <= front.x:
		return true

	# Right semicircular cap.
	return pos.distance_to(front) <= half_h


func advance_step(nodes: Array, end_node: MapNode, node_radius: float) -> bool:
	if current_step >= total_steps:
		return false
	current_step += 1
	apply_blockade_to_covered_nodes(nodes, end_node, node_radius)
	return true


func apply_blockade_to_covered_nodes(nodes: Array, end_node: MapNode, node_radius: float) -> void:
	for node in nodes:
		if not is_node_covered(node, node_radius):
			continue
		if node.content_type == MapNode.ContentType.BLOCKADE or node.chaser_blockaded:
			continue
		# Quest special_mark is intentionally preserved: marked nodes may be
		# blockaded later and still resolve via after-battle encounter UI.
		if node == end_node:
			node.chaser_blockaded = true
		else:
			node.content_type = MapNode.ContentType.BLOCKADE


func _cap_arc_points(front: Vector2) -> PackedVector2Array:
	var half_h := map_half_height
	var segments := maxi(16, int(half_h * 0.05))
	var points := PackedVector2Array()
	for i in range(segments + 1):
		var angle := -PI * 0.5 + PI * float(i) / float(segments)
		points.append(front + Vector2(cos(angle), sin(angle)) * half_h)
	return points


func draw_capsule(canvas: CanvasItem) -> void:
	var front := get_front_center()
	var half_h := map_half_height
	var top := map_center_y - half_h
	var bottom := map_center_y + half_h
	var body_left := front.x - capsule_length

	var points := PackedVector2Array()
	points.append(Vector2(body_left, top))
	points.append(Vector2(front.x, top))
	points.append_array(_cap_arc_points(front))
	points.append(Vector2(body_left, bottom))

	if points.size() >= 3:
		canvas.draw_colored_polygon(points, fill_color)


func draw_step_preview_curves(
	canvas: CanvasItem,
	preview_color: Color,
	line_width: float,
	label_color: Color
) -> void:
	if current_step >= total_steps:
		return

	var font := ThemeDB.fallback_font
	var font_size := 14
	var label_offset := 12.0

	for step in range(current_step + 1, total_steps + 1):
		var front := get_front_center_at_step(step)
		var arc_pts := _cap_arc_points(front)
		if arc_pts.size() >= 2:
			canvas.draw_polyline(arc_pts, preview_color, line_width)

		var moves_left := step - current_step
		var label := str(moves_left)
		if step == total_steps:
			label += "!"

		var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var label_pos := Vector2(
			front.x - text_size.x * 0.5,
			map_center_y - map_half_height - label_offset - text_size.y
		)
		canvas.draw_string(
			font,
			label_pos,
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			label_color
		)


func get_ui_state() -> Dictionary:
	var front := get_front_center()
	return {
		"current_step": current_step,
		"total_steps": total_steps,
		"front_x": front.x,
		"end_front_x": get_end_front_x(),
		"step_size_x": step_size_x,
	}
