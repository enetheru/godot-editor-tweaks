# In your export_plugin.gd
@tool
extends EditorExportPlugin

const Self:Resource = preload("export_plugin.gd")

var path_prefix:String = Self.resource_path.get_base_dir() + "/"

var ignore_patterns: Array[String] = []

func _get_name() -> String:
	return "EditorTweaksExportPlugin"

func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
	_load_ignore_file()


func _load_ignore_file() -> void:
	var path:String = path_prefix + ".exportignore"
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		while not file.eof_reached():
			var line:String = file.get_line().strip_edges()
			if line and not line.begins_with("#"):
				ignore_patterns.append(line)


func _export_file(path: String, _type: String, _features: PackedStringArray) -> void:
	for pattern in ignore_patterns:
		if pattern.begins_with("./"):
			pattern = pattern.trim_prefix('./')

		if path.match(pattern) or path.begins_with(path_prefix + pattern.trim_suffix("/")):
			#print("ignore_pattern: " + path_prefix + pattern)
			#print("skipping: " + path)
			skip()
			return
