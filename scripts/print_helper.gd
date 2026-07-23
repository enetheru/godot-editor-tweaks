@tool
## Lightweight static print helpers used by [code]settings.gd[/code].
##
##[br][color=tomato]FIXME[/color]: This is a second logger beside autoload
## [code]EneLog[/code] ([code]EneLog.gd[/code] / [code]_EneLog[/code]).
## [LogLevel] here is sequential (0..6); EneLog uses bitmasks; [TweakOptions]
## [member TweakOptions.verbosity] is [code]@export_flags[/code]. Those three
## disagree — consolidate before relying on level filtering.
##[br][color=goldenrod]TODO[/color]: Drop hand-rolled [HintEnum] /
## [UsageFlags] and use engine [enum PropertyHint] / [enum PropertyUsageFlags]
## names (or document why bit-position indices are required).
##[br][color=goldenrod]TODO[/color]: Move property-flag utilities out of a
## "print helper" into a small settings/reflection util.

# │ ___    _ _ _           _
# │| __|__| (_) |_ ___ _ _| |   ___  __ _
# │| _|/ _` | |  _/ _ \ '_| |__/ _ \/ _` |
# │|___\__,_|_|\__\___/_| |____\___/\__, |
# ╰─────────────────────────────────|___/──

# FIXME: sequential enum — does not match EneLog.LogLevel bitmasks.
enum LogLevel {
	SILENT = 0,
	CRITICAL = 1,
	ERROR = 2,
	WARNING = 3,
	NOTICE = 4,
	DEBUG = 5,
	TRACE = 6,
}


# TODO: Prefer engine PropertyHint constants; these mirror hint ints for debug.
enum HintEnum {
	PROPERTY_HINT_NONE = 0,
	PROPERTY_HINT_RANGE = 1,
	PROPERTY_HINT_ENUM = 2,
	PROPERTY_HINT_ENUM_SUGGESTION = 3,
	PROPERTY_HINT_EXP_EASING = 4,
	PROPERTY_HINT_LINK = 5,
	PROPERTY_HINT_FLAGS = 6,
	PROPERTY_HINT_LAYERS_2D_RENDER = 7,
	PROPERTY_HINT_LAYERS_2D_PHYSICS = 8,
	PROPERTY_HINT_LAYERS_2D_NAVIGATION = 9,
	PROPERTY_HINT_LAYERS_3D_RENDER = 10,
	PROPERTY_HINT_LAYERS_3D_PHYSICS = 11,
	PROPERTY_HINT_LAYERS_3D_NAVIGATION = 12,
	PROPERTY_HINT_LAYERS_AVOIDANCE = 37,
	PROPERTY_HINT_FILE = 13,
	PROPERTY_HINT_DIR = 14,
	PROPERTY_HINT_GLOBAL_FILE = 15,
	PROPERTY_HINT_GLOBAL_DIR = 16,
	PROPERTY_HINT_RESOURCE_TYPE = 17,
	PROPERTY_HINT_MULTILINE_TEXT = 18,
	PROPERTY_HINT_EXPRESSION = 19,
	PROPERTY_HINT_PLACEHOLDER_TEXT = 20,
	PROPERTY_HINT_COLOR_NO_ALPHA = 21,
	PROPERTY_HINT_OBJECT_ID = 22,
	PROPERTY_HINT_TYPE_STRING = 23,
	PROPERTY_HINT_NODE_PATH_TO_EDITED_NODE = 24,
	PROPERTY_HINT_OBJECT_TOO_BIG = 25,
	PROPERTY_HINT_NODE_PATH_VALID_TYPES = 26,
	PROPERTY_HINT_SAVE_FILE = 27,
	PROPERTY_HINT_GLOBAL_SAVE_FILE = 28,
	PROPERTY_HINT_INT_IS_OBJECTID = 29,
	PROPERTY_HINT_INT_IS_POINTER = 30,
	PROPERTY_HINT_ARRAY_TYPE = 31,
	PROPERTY_HINT_DICTIONARY_TYPE = 38,
	PROPERTY_HINT_LOCALE_ID = 32,
	PROPERTY_HINT_LOCALIZABLE_STRING = 33,
	PROPERTY_HINT_NODE_TYPE = 34,
	PROPERTY_HINT_HIDE_QUATERNION_EDIT = 35,
	PROPERTY_HINT_PASSWORD = 36,
	PROPERTY_HINT_TOOL_BUTTON = 39,
	PROPERTY_HINT_ONESHOT = 40,
	PROPERTY_HINT_GROUP_ENABLE = 42,
	PROPERTY_HINT_INPUT_NAME = 43,
	PROPERTY_HINT_FILE_PATH = 44,
	PROPERTY_HINT_MAX = 45
}


# flag_name = bit position (1-based index into PackedByteArray bits).
# FIXME: PROPERTY_USAGE_EDITOR_BASIC_SETTING and READ_ONLY both map to 28.
enum UsageFlags {
	INVALID = 1,
	PROPERTY_USAGE_STORAGE = 2,
	PROPERTY_USAGE_EDITOR = 3,
	PROPERTY_USAGE_INTERNAL = 4,
	PROPERTY_USAGE_CHECKABLE = 5,
	PROPERTY_USAGE_CHECKED = 6,
	PROPERTY_USAGE_GROUP = 7,
	PROPERTY_USAGE_CATEGORY = 8,
	PROPERTY_USAGE_SUBGROUP = 9,
	PROPERTY_USAGE_CLASS_IS_BITFIELD = 10,
	PROPERTY_USAGE_NO_INSTANCE_STATE = 11,
	PROPERTY_USAGE_RESTART_IF_CHANGED = 12,
	PROPERTY_USAGE_SCRIPT_VARIABLE = 13,
	PROPERTY_USAGE_STORE_IF_NULL = 14,
	PROPERTY_USAGE_UPDATE_ALL_IF_MODIFIED = 15,
	PROPERTY_USAGE_SCRIPT_DEFAULT_VALUE = 16,
	PROPERTY_USAGE_CLASS_IS_ENUM = 17,
	PROPERTY_USAGE_NIL_IS_VARIANT = 18,
	PROPERTY_USAGE_ARRAY = 19,
	PROPERTY_USAGE_ALWAYS_DUPLICATE = 20,
	PROPERTY_USAGE_NEVER_DUPLICATE = 21,
	PROPERTY_USAGE_HIGH_END_GFX = 22,
	PROPERTY_USAGE_NODE_PATH_FROM_SCENE_ROOT = 23,
	PROPERTY_USAGE_RESOURCE_NOT_PERSISTENT = 24,
	PROPERTY_USAGE_KEYING_INCREMENTS = 25,
	PROPERTY_USAGE_DEFERRED_SET_RESOURCE = 26,
	PROPERTY_USAGE_EDITOR_INSTANTIATE_OBJECT = 27,
	PROPERTY_USAGE_EDITOR_BASIC_SETTING = 28,
	PROPERTY_USAGE_READ_ONLY = 28,
	PROPERTY_USAGE_SECRET = 30,
}

const Plugin = preload("uid://setvleg6sni3")

static var _opts:TweakOptions:
	get():
		if Plugin._prime:
			var opts:TweakOptions = Plugin._prime.opts
			if opts:
				_opts = opts
		return _opts
	set(v):
		_opts = v


# NOTE: compared with sequential LogLevel below, but opts.verbosity is flags.
static var _verbosity:int:
	get():
		if _opts:
			return _opts.verbosity
		return LogLevel.CRITICAL
	set(_v):
		pass


static func bitmask_array( value:int, max_width:int ) -> PackedByteArray:
	var result:PackedByteArray
	if result.resize(max_width) != OK: return []
	for i:int in max_width:
		result[i] = (value >> i) & 1
	return result


static func get_usage_flags( bits:PackedByteArray ) -> PackedStringArray:
	var result:PackedStringArray
	for i:int in bits.size():
		var value:String = str(UsageFlags.find_key(i+1))
		if bits[i]:
			if not result.push_back(value): break
	return result


## returns a bbcode string url to the source location at [param depth].
static func get_call_site(depth:int = 1) -> String:
	var stack:Array = get_stack()
	var frame:Dictionary = stack[mini(stack.size(), depth)]
	return "[url='{source}:{line}']{source}:{line}:{function}()[/url]".format(frame)


## Sparse/simple print to the output console when level is allowed.
##[br]FIXME: null-deref if [member _opts] is not ready; guard or require init.
static func slog( level:LogLevel, ...message:Array ) -> void:
	if _verbosity < level:
		return
	if _opts == null:
		return
	var colour:String = _opts.get_colour(level).to_html()
	print_rich("[color=%s]%s[/color]" % [colour, " ".join(message)])


## Print the current source location when TRACE is allowed.
static func ptrace() -> void:
	if _verbosity < LogLevel.TRACE:
		return
	if _opts == null:
		return
	var colour:String = _opts.get_colour(LogLevel.TRACE).to_html()
	var call_site:Dictionary = get_stack()[-1]
	var line:String = (
		"[url='{source}:{line}'][color=57b3ff]{function}[/color][/url]"
		.format(call_site))
	print_rich("[color=%s]%s[/color]" % [colour, line])


## Print [param message] with optional TRACE stack-depth padding.
static func plog( level:LogLevel, ...message:Array ) -> void:
	if _verbosity < level:
		return
	if _opts == null:
		return
	var colour:String = _opts.get_colour(level).to_html()
	var padding:String = (
		"".lpad(get_stack().size() - 1, "\t")
		if level == LogLevel.TRACE else "")
	print_rich(padding + "[color=%s]%s[/color]" % [colour, " ".join(message)])


## Same as [method plog], returning whether the level check passed.
static func plog_check( level:LogLevel, ...message:Array ) -> bool:
	if _verbosity < level:
		return false
	plog(level, message)
	return true


static func lvl( level:LogLevel ) -> bool:
	return _verbosity >= level
