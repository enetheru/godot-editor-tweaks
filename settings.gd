@tool
var editor_settings : EditorSettings

var _prefix : String
var _target : EditorPlugin

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

#             ███████ ██    ██ ███████ ███    ██ ████████ ███████              #
#             ██      ██    ██ ██      ████   ██    ██    ██                   #
#             █████   ██    ██ █████   ██ ██  ██    ██    ███████              #
#             ██       ██  ██  ██      ██  ██ ██    ██         ██              #
#             ███████   ████   ███████ ██   ████    ██    ███████              #
func                        __________EVENTS_________              ()->void:pass

func _on_editor_settings_changed() -> void:
	print("Changes Settings:", editor_settings.get_changed_settings())
	for setting_name in editor_settings.get_changed_settings():
		if not setting_name.begins_with(_prefix): continue
		var prop_name : StringName = setting_name.get_file()
		var prop_val : Variant = editor_settings.get(setting_name)
		_target.set( prop_name, prop_val )


func _on_target_tree_exiting() -> void:
	editor_settings.settings_changed.disconnect( _on_editor_settings_changed )


#      ██████  ██    ██ ███████ ██████  ██████  ██ ██████  ███████ ███████     #
#     ██    ██ ██    ██ ██      ██   ██ ██   ██ ██ ██   ██ ██      ██          #
#     ██    ██ ██    ██ █████   ██████  ██████  ██ ██   ██ █████   ███████     #
#     ██    ██  ██  ██  ██      ██   ██ ██   ██ ██ ██   ██ ██           ██     #
#      ██████    ████   ███████ ██   ██ ██   ██ ██ ██████  ███████ ███████     #
func                        ________OVERRIDES________              ()->void:pass

func _init( target : EditorPlugin, prefix : String = "" )-> void:
	print("Starting Settings Class")
	_prefix = prefix
	_target = target

	editor_settings = EditorInterface.get_editor_settings()

	@warning_ignore_start('return_value_discarded')
	_target.tree_exiting.connect( _on_target_tree_exiting, CONNECT_ONE_SHOT )
	editor_settings.settings_changed.connect( _on_editor_settings_changed )
	@warning_ignore_restore('return_value_discarded')

	for property : Dictionary in _target.get_property_list():
		if not (property.usage & PROPERTY_USAGE_EDITOR_BASIC_SETTING): continue

		var prop_name : StringName = property.get(&'name')
		var setting_name : StringName = _prefix

		# Split into groups
		if property.usage & (PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SUBGROUP):
			for segment : String in prop_name.split('_', false,
				2 if property.usage & PROPERTY_USAGE_SUBGROUP else 1):
				setting_name = setting_name.path_join(segment)
		else:
			setting_name = setting_name.path_join(prop_name)

		var setting : Dictionary = {
			&'name': setting_name,
			&'type': property.type,
			&'hint': property.hint,
			&'hint_string': property.hint_string
		}

		var initial_value : Variant = _target.get( prop_name )

		# update the settings.
		if not editor_settings.has_setting(setting_name):
			editor_settings.set_setting( setting_name, initial_value )
			#editor_settings.mark_setting_changed(setting_info.name)
		# Incase our plugin has changed, update the setting
		editor_settings.set_initial_value(setting_name, initial_value, false)
		editor_settings.add_property_info(setting)

		var prop_val : Variant = editor_settings.get(setting_name)
		_target.set( prop_name, prop_val )

#         ███    ███ ███████ ████████ ██   ██  ██████  ██████  ███████         #
#         ████  ████ ██         ██    ██   ██ ██    ██ ██   ██ ██              #
#         ██ ████ ██ █████      ██    ███████ ██    ██ ██   ██ ███████         #
#         ██  ██  ██ ██         ██    ██   ██ ██    ██ ██   ██      ██         #
#         ██      ██ ███████    ██    ██   ██  ██████  ██████  ███████         #
func                        _________METHODS_________              ()->void:pass

## Erase settings with _prefix
func scrub() -> void:
	print("Scrubbing '%s/*' from editor configuration." % _prefix )
	for property in editor_settings.get_property_list():
		var setting_name : String = property.get(&'name')
		if setting_name.begins_with(_prefix):
			editor_settings.erase(setting_name)
