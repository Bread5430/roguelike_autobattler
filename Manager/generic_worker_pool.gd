extends Node
class_name GenericWorkerPool
## Bounded wrapper around [WorkerThreadPool] for fire-and-wait parallel batches.
## Callables must not touch the scene tree or [Object] APIs; use only plain data.

@export var max_concurrent_tasks: int = 4

func _ready() -> void:
	add_to_group("GENERIC_WORKER_POOL")


## Run [param worker] as [code]worker.call(start, end)[/code] for [0, item_count).
## Splits into up to [param max_parallel] slices (capped by [member max_concurrent_tasks]),
## schedules at most [member max_concurrent_tasks] tasks at a time, and waits each wave.
func run_parallel_index_slices(
	item_count: int,
	min_items_for_parallel: int,
	max_parallel: int,
	worker: Callable
) -> void:
	if item_count <= 0:
		return
	var cap := clampi(max_parallel, 1, maxi(1, max_concurrent_tasks))
	if item_count < min_items_for_parallel or cap <= 1:
		worker.call(0, item_count)
		return

	var num_chunks: int = mini(cap, item_count)
	var base: int = item_count / num_chunks
	var rem: int = item_count % num_chunks
	var bounds: Array[Vector2i] = [] ## each: Vector2i(start, end_exclusive)
	var start := 0
	for c in num_chunks:
		var chunk_sz: int = base + (1 if c < rem else 0)
		var end: int = start + chunk_sz
		bounds.append(Vector2i(start, end))
		start = end

	var wave_start := 0
	while wave_start < bounds.size():
		var wave_end: int = mini(wave_start + max_concurrent_tasks, bounds.size())
		var task_ids: Array[int] = []
		for w in range(wave_start, wave_end):
			var b: Vector2i = bounds[w]
			var s := int(b.x)
			var e := int(b.y)
			task_ids.append(WorkerThreadPool.add_task(worker.bind(s, e)))
		for tid in task_ids:
			WorkerThreadPool.wait_for_task_completion(tid)
		wave_start = wave_end


## Run each callable on the engine worker pool, at most [member max_concurrent_tasks] at a time.
## Every task must be waited for (engine requirement). Callables must be thread-safe.
func run_callables_wave_bounded(tasks: Array[Callable]) -> void:
	var i := 0
	var n := tasks.size()
	while i < n:
		var wave_end: int = mini(i + max_concurrent_tasks, n)
		var task_ids: Array[int] = []
		for j in range(i, wave_end):
			task_ids.append(WorkerThreadPool.add_task(tasks[j]))
		for tid in task_ids:
			WorkerThreadPool.wait_for_task_completion(tid)
		i = wave_end
