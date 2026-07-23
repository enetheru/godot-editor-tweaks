@tool
extends EditorExportPlugin
## Skip paths listed in this addon's [code].exportignore[/code] during export.
##
## Patterns are simple [method String.match] globs relative to the addon, or
## path prefixes when they end with [code]/[/code].
##[br][color=goldenrod]TODO[/color]: Support gitignore-style rules if this
## grows beyond a few lines.

const Self:Resource = preload("export_plugin.gd")

var path_prefix:String = Self.resource_path.get_base_dir() + "/"
var ignore_patterns:Array[String] = []


func _get_name() -> String:
	return "EditorTweaksExportPlugin"


func _export_begin(
			_features:PackedStringArray,
			_is_debug:bool,
			_path:String,
			_flags:int ) -> void:
	# Clear so re-exports do not accumulate patterns.
	ignore_patterns.clear()
	_load_ignore_file()


func _load_ignore_file() -> void:
	var path:String = path_prefix + ".exportignore"
	if not FileAccess.file_exists(path):
		return
	var file:FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("EditorTweaksExportPlugin._load_ignore_file:",
			" failed to open %s" % path)
		return
	while not file.eof_reached():
		var line:String = file.get_line().strip_edges()
		if line and not line.begins_with("#"):
			ignore_patterns.append(line)


func _export_file(
			path:String,
			_type:String,
			_features:PackedStringArray ) -> void:
	for pattern:String in ignore_patterns:
		if pattern.begins_with("./"):
			pattern = pattern.trim_prefix("./")
		if path.match(pattern) \
		or path.begins_with(path_prefix + pattern.trim_suffix("/")):
			skip()
			return
