@tool

# │ ___      _   _   _                _  _     _
# │/ __| ___| |_| |_(_)_ _  __ _ ___ | || |___| |_ __  ___ _ _
# │\__ \/ -_)  _|  _| | ' \/ _` (_-< | __ / -_) | '_ \/ -_) '_|
# │|___/\___|\__|\__|_|_||_\__, /__/ |_||_\___|_| .__/\___|_|
# ╰────────────────────────|___/────────────────|_|──────────────
# - last edited: 11/11/2025 10:41am ACT+930 -

# This class saves me from writing so much boilerplate for creating editor
# settings for the editor plugins I wish to write.

# The class looks for custom exported properties with
# PROPERTY_USAGE_EDITOR_BASIC_SETTING and exposes them as editor_settings.

# It is intended to be used in EditorPlugin singletons to transform exported
# properties into editor settings.

# == Usage ==
# drop it into your plugin's folder and initialise it like so:

# func _enter_tree() -> void:
#	settings_mgr = SettingsHelper.new(self, "plugin/my_plugin_name")

# == Examples ==
#@export_custom( PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR_BASIC_SETTING)
#var example : bool

# To facilitate grouping of settings, add the PROPERTY_USAGE_GROUP
# and PROPERTY_USAGE_SUBGROUP bitflags to the export. Underscores will be
# replaced with forward slashes. Only two layers deep are supported.
# @export_custom( PROPERTY_HINT_NONE, "",
#	PROPERTY_USAGE_EDITOR_BASIC_SETTING | PROPERTY_USAGE_SUBGROUP)
# var group_subgroup_example : bool

# not all property hints work, as there is not a 1:1 relationship between the
# editor settings and the inspector.

# == More ==
# The goal of this script is to provided a friendly way to define editor or project properties based on an object.
# Is used primarily for singletons like editor plugins, but if i finish it, it can be extended to project singletons too.
# Rather than manually setting them up one by one, it also provides a mechanism such that selecting the node shows the properties

# The idea is that we walk the property list of an object, and translate its properties into editor settings.

# Object Property Dictionary.
#Returns the object's property list as an Array of dictionaries. Each Dictionary contains the following entries:
# - name is the property's name, as a String;
# - class_name is an empty StringName, unless the property is @GlobalScope.TYPE_OBJECT and it inherits from a class;
# - type is the property's type, as an int (see Variant.Type);
# - hint is how the property is meant to be edited (see PropertyHint);
# - hint_string depends on the hint (see PropertyHint);
# - usage is a combination of PropertyUsageFlags.
#Note: In GDScript, all class members are treated as properties. In C# and GDExtension, it may be necessary to explicitly mark class members as Godot properties using decorators or attributes.

# EditorSettings property.
#settings.set("category/property_name", 0)
#var property_info = {
	# - "name": "category/property_name",
	# - "type": TYPE_INT,
	# - "hint": PROPERTY_HINT_ENUM,
	# - "hint_string": "one,two,three"
#}
#settings.add_property_info(property_info)

# │ _____            _
# │|_   _| _ __ _ __(_)_ _  __ _
# │  | || '_/ _` / _| | ' \/ _` |
# │  |_||_| \__,_\__|_|_||_\__, |
# ╰────────────────────────|___/───
var trace_enabled : bool = true

func trace(args : Dictionary = {}) -> void:
	if not trace_enabled : return
	var stack := get_stack(); stack.pop_front()
	EneLog.trace(args, stack, self)


func trace_detail(content : Variant, object : Object = null) -> void:
	if not trace_enabled : return
	EneLog.printy(content, null, object, "", get_stack())

# ██████  ██████   ██████  ██████  ███████ ██████  ████████ ██ ███████ ███████ #
# ██   ██ ██   ██ ██    ██ ██   ██ ██      ██   ██    ██    ██ ██      ██      #
# ██████  ██████  ██    ██ ██████  █████   ██████     ██    ██ █████   ███████ #
# ██      ██   ██ ██    ██ ██      ██      ██   ██    ██    ██ ██           ██ #
# ██      ██   ██  ██████  ██      ███████ ██   ██    ██    ██ ███████ ███████ #
func                        ________PROPERTIES_______              ()->void:pass

static var editor_settings : EditorSettings :
	get(): return EditorInterface.get_editor_settings()

var helper_group : StringName = &"settings-helper/buttons"

var _prefix : String
var _target : EditorPlugin

# I'm getting a lot of signals which duplicate events for editor_settings.
# I cant tell where they are coming from, and they all have the correct instance ID.
var _dirty : bool = false

#             ███████ ██    ██ ███████ ███    ██ ████████ ███████              #
#             ██      ██    ██ ██      ████   ██    ██    ██                   #
#             █████   ██    ██ █████   ██ ██  ██    ██    ███████              #
#             ██       ██  ██  ██      ██  ██ ██    ██         ██              #
#             ███████   ████   ███████ ██   ████    ██    ███████              #
func                        __________EVENTS_________              ()->void:pass

func _on_editor_settings_changed() -> void:
	trace()
	if _dirty: return
	_dirty = true
	update_target.call_deferred()


func _on_target_ready() -> void:
	trace()
	@warning_ignore('return_value_discarded')
	editor_settings.settings_changed.connect( _on_editor_settings_changed )

	add_properties_to_settings()
	add_builtin_settings()


func _on_target_tree_exiting() -> void:
	trace()
	editor_settings.settings_changed.disconnect( _on_editor_settings_changed )


#      ██████  ██    ██ ███████ ██████  ██████  ██ ██████  ███████ ███████     #
#     ██    ██ ██    ██ ██      ██   ██ ██   ██ ██ ██   ██ ██      ██          #
#     ██    ██ ██    ██ █████   ██████  ██████  ██ ██   ██ █████   ███████     #
#     ██    ██  ██  ██  ██      ██   ██ ██   ██ ██ ██   ██ ██           ██     #
#      ██████    ████   ███████ ██   ██ ██   ██ ██ ██████  ███████ ███████     #
func                        ________OVERRIDES________              ()->void:pass

func _init( target : EditorPlugin,
			prefix : String = "plugin/un-named"
			)-> void:
	trace()
	_prefix = prefix
	_target = target

	# when plugins are disabled, they are deleted.
	@warning_ignore_start('return_value_discarded')
	#_target.tree_entered.connect(_on_target_tree_entered, CONNECT_ONE_SHOT)
	_target.ready.connect(_on_target_ready, CONNECT_ONE_SHOT)
	_target.tree_exiting.connect( _on_target_tree_exiting, CONNECT_ONE_SHOT )
	# _target.tree_exited
	@warning_ignore_restore('return_value_discarded')


#         ███    ███ ███████ ████████ ██   ██  ██████  ██████  ███████         #
#         ████  ████ ██         ██    ██   ██ ██    ██ ██   ██ ██              #
#         ██ ████ ██ █████      ██    ███████ ██    ██ ██   ██ ███████         #
#         ██  ██  ██ ██         ██    ██   ██ ██    ██ ██   ██      ██         #
#         ██      ██ ███████    ██    ██   ██  ██████  ██████  ███████         #
func                        _________METHODS_________              ()->void:pass

# Function to scan addons/ for plugins and return list of dicts
# Each dict: {"path": "res://addons/my_plugin/", "config": {"name": "...", "script": "...", ...}}
func get_all_plugins_info( only_loaded : bool = false) -> Array[Dictionary]:
	var enabled_plugins : PackedStringArray = ProjectSettings.get_setting("editor_plugins/enabled")
	var plugins_info: Array[Dictionary] = []

	# Open the addons directory
	var addons_path : String = "res://addons/"
	var dir: DirAccess = DirAccess.open(addons_path)
	if dir == null:
		push_error("Failed to open res://addons/ directory")
		return plugins_info

	# Get list of subdirectories (plugin folders)
	dir.list_dir_begin()
	var folder_name: String = dir.get_next()
	while folder_name != "":
		if dir.current_is_dir():
			var plugin_path: String = addons_path.path_join(folder_name)
			var cfg_path: String = plugin_path.path_join("plugin.cfg")

			if only_loaded and cfg_path not in enabled_plugins:
				folder_name = dir.get_next()
				continue

			if FileAccess.file_exists(cfg_path):
				var config: ConfigFile = ConfigFile.new()
				var err: int = config.load(cfg_path)
				if err == OK:
					var config_props: Dictionary = {}

					var keys: PackedStringArray = config.get_section_keys("plugin")
					for key in keys:
						config_props[key] = config.get_value("plugin", key)

					plugins_info.append({
						"path": plugin_path,
						"config": config_props,
						"enabled": plugin_path in enabled_plugins
					})
				else:
					push_warning("Failed to load " + cfg_path + " (error: " + str(err) + ")")

		folder_name = dir.get_next()
	dir.list_dir_end()
	return plugins_info


# Buttons for callables that point to scripts
# I dont think are serialisable as a setting properly.
# so they always set. I should check the settings resource.
static func add_settings_button(
			path : String,
			callable : Callable,
			label : String = callable.get_method().capitalize(),
			) -> void:
	editor_settings.set_setting( path, callable )

	var min_width : int = 16

	# The label could be a multiline string.
	# get the largest line index.
	var lines : PackedStringArray = label.split('\n')
	var l_idx : int = 0
	for i in lines.size():
		if lines[l_idx].length() < lines[i].length():
			l_idx = i

	label = lines[l_idx]

	# Calculate the padding from the largest
	var pad_size : int = clamp(min_width - label.length(), 0, min_width)
	var pad : String = "".lpad(pad_size >> 1)

	# Replace largest line.
	lines[l_idx] = "".join([pad, label, pad])

	# Update the property
	editor_settings.add_property_info({
		&'name': path,
		&'type': TYPE_CALLABLE,
		&'hint': PROPERTY_HINT_TOOL_BUTTON,
		&'hint_string': "\n".join(lines)
	})


## Add all the properties as settings
func add_properties_to_settings() -> void:
	for property : Dictionary in _target.get_property_list():
		# NOTE: could I use my own custom bitflag here?
		if not (property.usage & PROPERTY_USAGE_EDITOR_BASIC_SETTING): continue

		var prop_name : StringName = property.get(&'name')
		var current_value : Variant = _target.get( prop_name )
		var setting_name : StringName = _prefix.path_join(prop_name)

		# Split name into groups if wanted.
		if property.usage & (PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SUBGROUP):
			setting_name = _prefix
			var num_segments : int = 2 if property.usage & PROPERTY_USAGE_SUBGROUP else 1
			for segment : String in prop_name.split('_', false, num_segments):
				setting_name = setting_name.path_join(segment)

		if property.hint & PROPERTY_HINT_TOOL_BUTTON:
			var button_func : Callable = current_value
			var hint_string : String = property.hint_string
			add_settings_button(setting_name, button_func, hint_string )
			continue

		var prop_info : Dictionary = {
			&'name': setting_name,
			&'type': property.type,
			&'hint': property.hint,
			&'hint_string': property.hint_string
		}

		if editor_settings.has_setting(setting_name):
			# apply the saved value
			var setting_value : Variant = editor_settings.get_setting( setting_name )
			if setting_value == current_value: continue
			else: _target.set(prop_name, setting_value)
		else:
			# add the settings.
			editor_settings.set_setting( setting_name, current_value )
			editor_settings.add_property_info(prop_info)
			editor_settings.set_initial_value(setting_name, current_value, false)


## Add some boilerplate settings.
func add_builtin_settings() -> void:
	add_settings_button(
		_prefix.path_join(helper_group).path_join(&"inspect"),
		EditorInterface.inspect_object.bind(_target),
		"Inspect EditorPlugin" )

	add_settings_button(
		_prefix.path_join(helper_group).path_join(&"rebuild"),
		rebuild_settings,
		"Rebuild Settings" )

	add_settings_button(
		_prefix.path_join(helper_group).path_join(&"erase_unload"),
		erase_unload,
		"Erase Settings\nand\nUnload Extension." )


func erase_unload() -> void:
	#erase_prefix( _prefix )
	print( ProjectSettings.get_setting("editor_plugins/enabled") )
	print( JSON.stringify(get_all_plugins_info(true), "  ", false) )


func rebuild_settings() -> void:
	erase_prefix( _prefix )
	add_properties_to_settings()
	add_builtin_settings()


func update_target() -> void:
	if not editor_settings.check_changed_settings_in_group(_prefix):
		_dirty = false; return

	for setting_name in editor_settings.get_changed_settings():
		if not setting_name.begins_with(_prefix): continue
		if setting_name.begins_with(_prefix.path_join(helper_group)): continue
		var prop_val : Variant = editor_settings.get(setting_name)
		var prop_name : StringName = setting_name.trim_prefix(_prefix+ "/").replace('/', '_')
		# try to set the target object property value.
		if prop_name in _target.get_property_list().reduce(
			func( prop_names : Array, prop_dict : Dictionary ) -> Array:
				prop_names.append(prop_dict.name); return prop_names, [] ):
					_target.set( prop_name, prop_val )
		else:
			printerr("property(%s) invalid for target(%s)" % [
				prop_name, _target.name])

	_dirty = false


## Erase all editor settings using a prefix
static func erase_prefix( prefix : String ) -> void:
	for property in editor_settings.get_property_list():
		var setting_name : String = property.get(&'name')
		if setting_name.begins_with(prefix):
			editor_settings.erase(setting_name)
