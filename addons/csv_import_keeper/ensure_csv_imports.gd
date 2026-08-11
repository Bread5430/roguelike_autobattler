@tool
extends EditorScript
## Ensures every CSV under res://Data/ has a sibling .csv.import with importer="keep".
## Run manually: File → Run, or rely on the csv_import_keeper editor plugin.

const DATA_DIR: String = "res://Data"
const IMPORT_CONTENTS: String = "[remap]\n\nimporter=\"keep\"\n"


static func ensure_imports() -> PackedStringArray:
	var created: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(DATA_DIR)
	if dir == null:
		push_warning("ensure_csv_imports: could not open %s" % DATA_DIR)
		return created

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".csv"):
			var csv_path: String = DATA_DIR.path_join(file_name)
			var import_path: String = csv_path + ".import"
			if not FileAccess.file_exists(import_path):
				var file: FileAccess = FileAccess.open(import_path, FileAccess.WRITE)
				if file == null:
					push_warning("ensure_csv_imports: failed to write %s" % import_path)
				else:
					file.store_string(IMPORT_CONTENTS)
					file.close()
					created.append(import_path)
		file_name = dir.get_next()
	dir.list_dir_end()
	return created


func _run() -> void:
	var created: PackedStringArray = ensure_imports()
	if created.is_empty():
		print("ensure_csv_imports: no missing .import files in Data/")
	else:
		print("ensure_csv_imports: created %d file(s):" % created.size())
		for path in created:
			print("  ", path)
