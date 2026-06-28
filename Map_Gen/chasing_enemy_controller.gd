extends Node2D
class_name ChasingEnemyController

var total_steps: int = 8
var current_step: int = 0
## Vertical half-extent of the capsule body and leading cap (full height = 2× this).
var map_half_height: float = 360.0
var capsule_length: float = 5000.0
var start_front_x: float = 0.0
var end_front_x: float = 1500.0
var map_center_y: float = 360.0
var fill_color: Color = Color(0.9, 0.15, 0.15, 0.35)


func reset(start_x: float, end_x: float, center_y: float, half_height: float) -> void:
	current_step = 0
	start_front_x = start_x
	end_front_x = end_x
	map_center_y = center_y
	map_half_height = half_height


func get_front_center() -> Vector2:
	var t := 0.0 if total_steps <= 0 else float(current_step) / float(total_steps)
	var x := lerpf(start_front_x, end_front_x, t)
	return Vector2(x, map_center_y)


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
		if node == end_node:
			node.chaser_blockaded = true
		else:
			node.content_type = MapNode.ContentType.BLOCKADE


func draw_capsule(canvas: CanvasItem) -> void:
	var front := get_front_center()
	var half_h := map_half_height
	var top := map_center_y - half_h
	var bottom := map_center_y + half_h
	var body_left := front.x - capsule_length

	var points := PackedVector2Array()
	points.append(Vector2(body_left, top))
	points.append(Vector2(front.x, top))

	var segments := maxi(16, int(half_h * 0.05))
	for i in range(segments + 1):
		var angle := -PI * 0.5 + PI * float(i) / float(segments)
		points.append(front + Vector2(cos(angle), sin(angle)) * half_h)

	points.append(Vector2(body_left, bottom))

	if points.size() >= 3:
		canvas.draw_colored_polygon(points, fill_color)


func get_ui_state() -> Dictionary:
	var front := get_front_center()
	return {
		"current_step": current_step,
		"total_steps": total_steps,
		"front_x": front.x,
		"end_front_x": end_front_x,
	}
