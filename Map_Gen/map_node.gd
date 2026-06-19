extends Node2D
class_name MapNode

enum ContentType {
	BATTLE,
	RANDOM_EVENT,
	REPAIR_SITE,
	SHOP,
}

var id: int
## Grid cell index when using grid-based map generation; (-1, -1) if unused.
var grid_cell: Vector2i = Vector2i(-1, -1)
var connections: Array[MapNode] = []
## Path role on the campaign graph: normal, start, or end.
var node_type: String = "normal"
var content_type: ContentType = ContentType.BATTLE
var difficulty: String = "easy"
var stage: int = 1
var completed: bool = false
var available: bool = false

func _init(node_id: int, pos: Vector2):
	id = node_id
	position = pos
