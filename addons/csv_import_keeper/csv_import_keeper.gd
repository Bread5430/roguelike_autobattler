@tool
extends EditorPlugin
## Calls ensure_csv_imports.gd whenever the editor filesystem changes.

const EnsureCsvImports = preload("res://addons/csv_import_keeper/ensure_csv_imports.gd")

var _pending_scan: bool = false


func _enter_tree() -> void:
	var fs: EditorFileSystem = get_editor_interface().get_resource_filesystem()
	fs.filesystem_changed.connect(_on_filesystem_changed)
	_queue_scan()


func _exit_tree() -> void:
	var fs: EditorFileSystem = get_editor_interface().get_resource_filesystem()
	if fs.filesystem_changed.is_connected(_on_filesystem_changed):
		fs.filesystem_changed.disconnect(_on_filesystem_changed)


func _on_filesystem_changed() -> void:
	_queue_scan()


func _queue_scan() -> void:
	if _pending_scan:
		return
	_pending_scan = true
	call_deferred("_run_scan")


func _run_scan() -> void:
	_pending_scan = false
	var created: PackedStringArray = EnsureCsvImports.ensure_imports()
	if not created.is_empty():
		print("csv_import_keeper: created %d .import file(s)" % created.size())
		for path in created:
			print("  ", path)
		get_editor_interface().get_resource_filesystem().scan()
