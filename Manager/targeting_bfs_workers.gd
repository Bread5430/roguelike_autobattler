extends RefCounted
class_name TargetingBfsWorkers

## One holder per worker task; only that task writes [member packed].
class NeighborChunkHolder extends RefCounted:
	var packed = Array()


const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(1, 1),
	Vector2i(-1, 0),
	Vector2i(0, -1),
	Vector2i(-1, -1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
]


## Pure neighbor expansion for one slice of [param curr_cells]. Writes only [param holder].packed.
static func neighbor_slice(
	start: int,
	end_exclusive: int,
	curr_cells: Array,
	grid_w: int,
	grid_h: int,
	holder: NeighborChunkHolder
) -> void:
	var out := Array()
	for k in range(start, end_exclusive):
		var cell = curr_cells[k]
		for dir in DIRECTIONS:
			var nl = cell + dir
			if nl.x > 0 and nl.x < grid_w - 1 and nl.y > 0 and nl.y < grid_h - 1:
				out.append(nl)
	holder.packed = out
