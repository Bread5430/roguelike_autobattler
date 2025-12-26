extends Node
# Attach this as a child of your GUI node or as a sibling
# It will manage mouse filter setup for the target GUI node

@export var target_gui_node: Control  # Drag your GUI node here in the Inspector
@export var auto_setup_on_ready := true
@export var debug_print := false

# Control types that should remain interactive (STOP)
var interactive_control_types := [
	"Button",
	"TextureButton", 
	"CheckBox",
	"CheckButton",
	"LineEdit",
	"TextEdit",
	"SpinBox",
	"Slider",
	"HSlider",
	"VSlider",
	"OptionButton",
	"MenuButton",
	"ColorPickerButton",
	"ItemList",
	"Tree",
	"TabContainer",
	"Tabs"
]

# Control types that should always ignore input (IGNORE)
var non_interactive_control_types := [
	"Label",
	"RichTextLabel",
	"TextureRect",
	"ColorRect",
	"NinePatchRect",
	"ReferenceRect",
	"Separator",
	"HSeparator",
	"VSeparator"
]

# Container types - usually should be IGNORE unless you want them to block input
var container_types := [
	"Container",
	"BoxContainer",
	"HBoxContainer",
	"VBoxContainer",
	"GridContainer",
	"MarginContainer",
	"CenterContainer",
	"PanelContainer",
	"ScrollContainer",
	"SplitContainer",
	"HSplitContainer",
	"VSplitContainer",
	"FlowContainer",
	"HFlowContainer",
	"VFlowContainer",
	"AspectRatioContainer"
]

func _ready():
	# If no target specified, try to find GUI automatically
	if not target_gui_node:
		auto_find_target()
	
	if not target_gui_node:
		push_error("GUIPassthroughManager: No target GUI node specified or found!")
		return
	
	if auto_setup_on_ready:
		setup_mouse_filters()

func auto_find_target():
	"""Automatically find the target GUI node"""
	# Strategy 1: Check if we're a child of a Control node
	if get_parent() is Control:
		target_gui_node = get_parent()
		if debug_print:
			print("Found target GUI as parent: %s" % target_gui_node.name)
		return
	
	# Strategy 2: Look for sibling Control nodes
	if get_parent():
		for sibling in get_parent().get_children():
			if sibling is Control and sibling != self:
				target_gui_node = sibling
				if debug_print:
					print("Found target GUI as sibling: %s" % target_gui_node.name)
				return
	
	# Strategy 3: Look for child Control nodes
	for child in get_children():
		if child is Control:
			target_gui_node = child
			if debug_print:
				print("Found target GUI as child: %s" % target_gui_node.name)
			return

func setup_mouse_filters():
	"""Automatically configure mouse filters for target GUI and all children"""
	if not target_gui_node:
		push_warning("Cannot setup mouse filters: target_gui_node is null")
		return
	
	if debug_print:
		print("=== Setting up mouse filters for: %s ===" % target_gui_node.name)
	
	configure_node_recursive(target_gui_node)
	
	if debug_print:
		print("=== Mouse filter setup complete ===")

func configure_node_recursive(node: Node):
	"""Recursively configure mouse filters for all Control nodes"""
	if node is Control:
		var original_filter = node.mouse_filter
		var new_filter = determine_mouse_filter(node)
		
		if original_filter != new_filter:
			node.mouse_filter = new_filter
			if debug_print:
				print("Changed %s (%s): %s -> %s" % [
					node.name, 
					node.get_class(),
					filter_to_string(original_filter),
					filter_to_string(new_filter)
				])
	
	# Process all children
	for child in node.get_children():
		configure_node_recursive(child)

func determine_mouse_filter(control: Control) -> Control.MouseFilter:
	"""Determine appropriate mouse filter for a control node"""
	#var class_name = control.get_class()
	
	# Check if it's an interactive control
	for interactive_type in interactive_control_types:
		if control.is_class(interactive_type):
			return Control.MOUSE_FILTER_STOP
	
	# Check if it's explicitly non-interactive
	for non_interactive_type in non_interactive_control_types:
		if control.is_class(non_interactive_type):
			return Control.MOUSE_FILTER_IGNORE
	
	# Check if it's a container
	for container_type in container_types:
		if control.is_class(container_type):
			# Containers default to IGNORE unless they're Panels
			if control is Panel or control is PanelContainer:
				# Check if panel has any interactive children
				if has_interactive_children(control):
					return Control.MOUSE_FILTER_IGNORE
				else:
					return Control.MOUSE_FILTER_IGNORE
			return Control.MOUSE_FILTER_IGNORE
	
	# For Panel - check if it should block input
	if control is Panel:
		# Panels are tricky - they might be backgrounds that should pass through
		# or modal dialogs that should block
		# Default to IGNORE for pass-through, but you can customize this
		return Control.MOUSE_FILTER_IGNORE
	
	# Generic Control node - default to IGNORE
	return Control.MOUSE_FILTER_IGNORE

func has_interactive_children(node: Node) -> bool:
	"""Check if a node has any interactive children"""
	for child in node.get_children():
		if child is Control:
			for interactive_type in interactive_control_types:
				if child.is_class(interactive_type):
					return true
		
		# Recursively check children
		if has_interactive_children(child):
			return true
	
	return false

func filter_to_string(filter: Control.MouseFilter) -> String:
	"""Convert MouseFilter enum to readable string"""
	match filter:
		Control.MOUSE_FILTER_STOP:
			return "STOP"
		Control.MOUSE_FILTER_PASS:
			return "PASS"
		Control.MOUSE_FILTER_IGNORE:
			return "IGNORE"
		_:
			return "UNKNOWN"

# Manual control functions you can call from code

func set_all_to_ignore():
	"""Force all controls to IGNORE (useful for debugging)"""
	if target_gui_node:
		set_all_filters_recursive(target_gui_node, Control.MOUSE_FILTER_IGNORE)

func set_all_to_stop():
	"""Force all controls to STOP (useful for modal dialogs)"""
	if target_gui_node:
		set_all_filters_recursive(target_gui_node, Control.MOUSE_FILTER_STOP)

func set_all_filters_recursive(node: Node, filter: Control.MouseFilter):
	"""Recursively set all controls to a specific filter mode"""
	if node is Control:
		node.mouse_filter = filter
	
	for child in node.get_children():
		set_all_filters_recursive(child, filter)

# Utility functions to temporarily block all input (for modals)
func block_input():
	"""Temporarily block all input to underlying layers"""
	if target_gui_node:
		target_gui_node.mouse_filter = Control.MOUSE_FILTER_STOP

func unblock_input():
	"""Re-enable pass-through"""
	if target_gui_node:
		target_gui_node.mouse_filter = Control.MOUSE_FILTER_IGNORE

# Refresh function if you add nodes dynamically
func refresh_filters():
	"""Re-run filter setup (useful after adding new UI elements)"""
	setup_mouse_filters()
