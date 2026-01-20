extends Camera2D

@export_group("Camera Controls")
@export var camera_move_speed : int = 500
@export var camera_default_size : Vector2 = Vector2(1920, 1080)
@export var camera_max_zoom: float = 2.0  # Zoom out (smaller numbers = more zoomed out)
@export var camera_min_zoom: float = 0.5  # Zoom in (larger numbers = more zoomed in)
@export var camera_scroll_speed : float = 0.2
@export var camera_edge_margin : float = 5.0

@export_group("Mouse Controls")
@export var enable_mouse_pan : bool = true
@export var invert_pan_direction : bool = true  # Set true for inverted panning (drag down = camera up)

# Mouse panning state
var is_panning : bool = false
var pan_start_mouse_pos : Vector2 = Vector2.ZERO
var pan_start_camera_pos : Vector2 = Vector2.ZERO

@export_group("Camera Limits")
@export var enable_limits : bool = true

func _ready():
	zoom = Vector2.ONE
	
	# Set camera limits if enabled
	if enable_limits:
		self.limit_left = limit_left
		self.limit_right = limit_right
		self.limit_top = limit_top
		self.limit_bottom = limit_bottom

func _input(event):
	# Mouse wheel zoom 
	if event.is_action_pressed("scroll_up"):
		zoom_camera(-camera_scroll_speed)
	elif event.is_action_pressed("scroll_down"):
		zoom_camera(camera_scroll_speed)
			
	if enable_mouse_pan and event.is_action_pressed("middle_mouse"):
		start_pan()
	elif event.is_action_released("middle_mouse"): # Stop panning when button released
		stop_pan()
		
	# Handle mouse motion for panning
	if is_panning and event is InputEventMouseMotion:
		update_pan()


func start_pan():
	"""Start mouse panning"""
	if not is_panning:
		is_panning = true
		pan_start_mouse_pos = get_viewport().get_mouse_position()
		pan_start_camera_pos = position


func stop_pan():
	"""Stop mouse panning"""
	is_panning = false


func update_pan():
	"""Update camera position while panning"""
	var current_mouse_pos = get_viewport().get_mouse_position()
	var mouse_delta = current_mouse_pos - pan_start_mouse_pos
	
	# Apply inversion if needed
	var direction_multiplier = -1 if invert_pan_direction else 1
	
	# Move camera (mouse delta internally accounts for zoom level)
	position = pan_start_camera_pos + (mouse_delta * direction_multiplier)


func zoom_camera(zoom_change: float):
	"""Zoom the camera towards the mouse cursor"""
	# Get mouse position before zoom
	var mouse_pos := get_global_mouse_position()
	
	# Calculate and clamp new zoom
	var old_zoom = zoom.x
	var new_zoom = clampf(old_zoom - zoom_change, camera_min_zoom, camera_max_zoom)
	
	# If zoom didn't change, exit early
	if new_zoom == old_zoom:
		return
	
	# Apply new zoom
	zoom = Vector2(new_zoom, new_zoom)
	
	# Get mouse position after zoom
	var new_mouse_pos := get_global_mouse_position()
	
	# Adjust camera position to keep mouse point stationary
	position += mouse_pos - new_mouse_pos

func _process(delta: float) -> void:
	if is_panning:
		return
	# Viewport movement with WASD/Arrow keys
	var camera_move_dir := Vector2.ZERO
	if Input.is_action_pressed("move_up"):    camera_move_dir.y -= 1
	if Input.is_action_pressed("move_down"):  camera_move_dir.y += 1
	if Input.is_action_pressed("move_left"):  camera_move_dir.x -= 1
	if Input.is_action_pressed("move_right"): camera_move_dir.x += 1
	
	# Allow camer
	
	if camera_move_dir != Vector2.ZERO:
		camera_move_dir = camera_move_dir.normalized()
		# Adjust movement speed based on zoom (more zoomed in = slower feel)
		var adjusted_speed = camera_move_speed / zoom.x
		position += camera_move_dir * adjusted_speed * delta

func post_ready():
	for i in get_children():
		if i.has_method("post_ready"):
			i.post_ready()

func reset_zoom():
	pass
	
func enable_zoom():
	pass
