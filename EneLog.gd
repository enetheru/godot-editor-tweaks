@tool
class_name _EneLog
extends Node
## │           _     _          [br]
## │  _ __ _ _(_)_ _| |_ _  _   [br]
## │ | '_ \ '_| | ' \  _| || |  [br]
## │ | .__/_| |_|_||_\__|\_, |  [br]
## ╰─|_|─────────────────|__/-<<[br]
## Logging utility for pretty printing to the output console.
##
## Autoload name is [code]EneLog[/code] ([code]project.godot[/code]); class_name
## is [code]_EneLog[/code] so the autoload can own the global identifier.
##[br][color=tomato]FIXME[/color]: Also lives as a dual of
## [code]print_helper.gd[/code] (sequential levels) and is registered via
## [code]Engine.register_singleton[/code] from the editor plugin — three entry
## points for one concern. Pick one API surface.
##[br][color=tomato]FIXME[/color]: [enum LogLevel] bitmasks vs sequential enums
## in [TweakOptions] / print_helper; [member _default_level] comparisons use
## integer [code]<[/code] which does not match flag-style verbosity.
##[br][color=goldenrod]TODO[/color]: [code]OS.delay_msec(4)[/code] in
## [method printy] is a blunt editor throttle — replace with rate limiting.
##[br][color=goldenrod]TODO[/color]: WorkerThreadPool.get_caller_task_id() for
## thread identity.
##[br][color=goldenrod]TODO[/color]: BBCode [code][hint][/code] tooltips on
## dense log fields.

func                        __Definitions____________              ()->void:pass
const TWEAK_OPTS = preload("uid://dhpivfj5v8omf")

const MAX_INT:int = 0x7FFF_FFFF_FFFF_FFFF
const MIN_INT:int = -0x8000_0000_0000_0000

const ESC: String            = "\u001B"                  # ESC character (safe in Godot)
const OSC_LINK_OPEN: String  = ESC + "]8;;"              # Start of OSC 8 hyperlink
const OSC_ST: String         = ESC + "\\"                # String Terminator
const OSC_LINK_CLOSE: String = ESC + "]8;;" + OSC_ST     # End of OSC 8 hyperlink

## Bitmask for tagging and discriminating messages.
enum LogLevel {
	SILENT   = 0x00, ##   0: Do not display anything.

	CRITICAL = 0x01, ##   1: Reserved for only the highest priority, adds prefix 'Critical:'
	ERROR    = 0x02, ##   3: An error has occurred, adds prefix 'Error:', prints stacktrace.
	WARNING  = 0x04, ##   7: Warning, adds prefix 'Warning:', prints stacktrace.
	NOTICE   = 0x08, ##  15: Sparse important information
	INFO     = 0x10, ##  31: More information
	DEBUG    = 0x20, ##  63: Debug Information
	TRACE    = 0x40, ##  64: Function Calls and process.

	MASK     = 0xFF,  ## 255: bitmask, or all levels.

	INCLUSIVE_CRITICAL = 0x01, ##   1: Reserved for only the highest priority, adds prefix 'Critical:'
	INCLUSIVE_ERROR    = 0x03, ##   2: An error has occurred, adds prefix 'Error:', prints stacktrace.
	INCLUSIVE_WARNING  = 0x07, ##   4: Warning, adds prefix 'Warning:', prints stacktrace.
	INCLUSIVE_NOTICE   = 0x0F, ##   8: Sparse important information
	INCLUSIVE_INFO     = 0x1F, ##  16: More information
	INCLUSIVE_DEBUG    = 0x3F, ##  32: Debug Information
	INCLUSIVE_TRACE    = 0x7F, ##  64: Function Calls and process.

	# Aliases
	DEFAULT = NOTICE,
	INCLUSIVE_DEFAULT = INCLUSIVE_NOTICE,
}

var _levels: Dictionary = {}  # path_prefix -> level
var levels_mutex := Mutex.new()
var _default_level: int = LogLevel.INCLUSIVE_NOTICE


# ─────────────────────────────────────────────────────────────────────────────
#  Per-call logging context
# ─────────────────────────────────────────────────────────────────────────────

class LogCtx:
	var content: Variant
	var args: Array[Variant] = []
	var object: Object = null
	var indent: String = ""
	var stack: Array[Dictionary] = []
	var stack_size: int = 0
	var distance: int = 0
	var newline: bool = false
	var is_error: bool = false
	var is_warning: bool = false

	# FD
	var before:String = ""
	var net:String = ""
	var rpc:String = ""
	var call_site:String = ""
	var flow:String = "│"
	var flow_return:String = ""
	var after:String = ""

	#time
	var time:String = ''
	var time_icon:String = ''

	#proc_fd
	var proc:String
	var proc_color:String = Color.WEB_GRAY.to_html()
	var proc_icon:String = " "
	var proc_id:int = OS.get_process_id()
	#thread
	var thread_id:int = OS.get_thread_caller_id()
	var thread_color:String = Color.WEB_GRAY.to_html()

	var left:String = ""

	# Header (object name part)
	var header: String = ""
	var header_icon: String = ""
	var header_color: String = ""
	var header_name: String = ""

	# Message part
	var msg: String = ""
	var msg_icon: String = ""
	var msg_color: String = ""
	var msg_pre: String = ""
	var msg_post: String = ""
	var msg_text: String = ""


## RAII guard
class StackPathLogScope:
	extends RefCounted
	var _path: String

	func _init(path: String) -> void:
		_path = path

	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE:
			EneLog._pop(_path)


# ██████  ██████   ██████  ██████  ███████ ██████  ████████ ██ ███████ ███████ #
# ██   ██ ██   ██ ██    ██ ██   ██ ██      ██   ██    ██    ██ ██      ██      #
# ██████  ██████  ██    ██ ██████  █████   ██████     ██    ██ █████   ███████ #
# ██      ██   ██ ██    ██ ██      ██      ██   ██    ██    ██ ██           ██ #
# ██      ██   ██  ██████  ██      ███████ ██   ██    ██    ██ ███████ ███████ #
func                        ________PROPERTIES_______              ()->void:pass

# ─────────────────────────────────────────────────────────────────────────────
#  Shared configuration (locked when modified at runtime)
# ─────────────────────────────────────────────────────────────────────────────

var disabled:bool = false
var max_level:int = LogLevel.MASK # aka all logging
var reset:bool = true
var top_level:bool = true

# Frequency adjustment
var get_time:Callable = Time.get_ticks_usec
var last_time:int
var threshold:int = 1000
var delay_amount:int = 100
var last_frame:int = 0
var last_pframe:int = 0

# Stack Flow (shared for continuity)
var prev_stack_mutex := Mutex.new()
var prev_stack:Array[Dictionary]
var prev_stack_size:int = 32
var prev_stack_dist:int = 0

# Filter
var ignore_filter:Array[String] = []
var thread_filter:Array = []

# Process / Network
var net_id:int
var net_string:String

var is_net_valid:Callable = net_is_not_valid
var get_net_id:Callable = get_zero_int
var get_net_string:Callable = get_empty_string


## Modifyable formatting
## Key is an all caps prefix using the following
## var prefix : String = str(content).left(10).to_upper()
## Value is a key value store used in the final formatting
## Complete Example:
##	styles[&'H1'] = {           # Name
##		&'before':" ",          # text to place before the content
##		&'color':"white",       # colour of the output
##		&'pre':'[b]>>====[ ',   # prefix to add to content
##		&'post':' ]====<<[/b]', # postfix to add to content
##		&'trim_prefix':true}    # remove the string match
## all the fields are optional. But if a 'regex' field is present, then
## the matcher will attempt to use a pre-compiled regex.
## Otherwise the first 10 characters of the message will be used to
## match against the style name

## Styles, Colours, and Matchers
var styles_mutex := Mutex.new()
var styles:Dictionary[StringName, Dictionary] = {
	&'NOTE': {&'icon':" ", &'color':"greenyellow", &'regex':"^#? ?[Nn][Oo][Tt][Ee]"},
	&'TODO': {&'icon':" ", &'color':"yellow", &'regex':"^#? ?[Tt][Oo][Dd][Oo]"},
	&'FIXME':{&'icon':" ", &'color':"tomato", &'regex':"^#? ?[Ff][Ii][Xx][Mm][Ee]"},
	&'HACK': {&'icon':" ", &'color':"tomato", &'regex':"^#? ?[Hh][Aa][Cc][Kk]"},
	&'STUB': {&'icon':" ", &'color':"tomato", &'regex':"^#? ?[Ss][Tt][Uu][Bb]"},
	&'ERR':  {&'icon':" ", &'color':"red", &'is_error':true},
	&'WARN': {&'icon':" ", &'color':"yellow"},
	&'HL':   {&'icon':"󱈸 ", &'color':"cyan"},
	&'MAX':  {&'icon':" ", &'color':"fuchsia"},
	&'RESUM':{&'icon':"󰜉 ", &'color':"medium_slate_blue"},
	&'WAIT': {&'icon':" ", &'color':"medium_slate_blue"},
	&'TRUE': {&'icon':" ", &'color':"lime_green"},
	&'FALSE':{&'icon':" ", &'color':"tomato"},
	&'SIG  ':{&'icon':" ", &'color':"orchid"},
}

var process_color_mutex := Mutex.new()
var process_color:Dictionary[int, Color] = {}

var thread_color_mutex := Mutex.new()
var thread_color:Dictionary[int, Color] = {}

var header_color_mutex := Mutex.new()
var header_color:Dictionary[String, Color] = {}

var type_match_mutex := Mutex.new()
var type_match:Array[Callable] = []

var color_dim_grey:String = Color(0.4, 0.4, 0.4).to_html()

#      ██████  ██    ██ ███████ ██████  ██████  ██ ██████  ███████ ███████     #
#     ██    ██ ██    ██ ██      ██   ██ ██   ██ ██ ██   ██ ██      ██          #
#     ██    ██ ██    ██ █████   ██████  ██████  ██ ██   ██ █████   ███████     #
#     ██    ██  ██  ██  ██      ██   ██ ██   ██ ██ ██   ██ ██           ██     #
#      ██████    ████   ███████ ██   ██ ██   ██ ██ ██████  ███████ ███████     #
func                        ________OVERRIDES________              ()->void:pass

func _ready() -> void:
	var want_enable:bool = false

	var user_args:PackedStringArray = OS.get_cmdline_user_args()
	for arg_idx:int in range( user_args.size() ):
		var arg:String = user_args[arg_idx]
		if arg == "--trace":
			want_enable = true
			var next_idx:int = arg_idx + 1
			if next_idx >= user_args.size(): continue
			var level:String = user_args[next_idx]
			if level.is_valid_int():
				max_level = level.hex_to_int()
				printy("printy log max set to: " + level)

	if want_enable: enable()
	else: disable()

	styles_mutex.lock()
	styles[&"[H1]"] = {
		&"before":" ",
		&"color":"white",
		&"pre":"[b]>>====[ ",  &"post":" ]====<<[/b]",
		&"trim_prefix":true
	}
	styles[&"[P1]"] = {
		&"color":"white",
		&"pre":"[b]",  &"post":"[/b]",
		&"trim_prefix":true
	}
	for key in styles:
		var stl:Dictionary = styles[key]
		if stl.has(&"regex"):
			var pattern:String = stl.regex
			stl[&"RegEx"] = RegEx.create_from_string(pattern)
	styles_mutex.unlock()


#                    ██████  ██████  ██ ███    ██ ████████                     #
#                    ██   ██ ██   ██ ██ ████   ██    ██                        #
#                    ██████  ██████  ██ ██ ██  ██    ██                        #
#                    ██      ██   ██ ██ ██  ██ ██    ██                        #
#                    ██      ██   ██ ██ ██   ████    ██                        #
func                        __________PRINT__________              ()->void:pass


func trace(args: Dictionary = {}, stack: Array = [], object: Object = null) -> void:
	if disabled: return
	if OS.get_thread_caller_id() in thread_filter: return
	if stack.is_empty():
		stack = get_stack()
		stack.pop_front()
	var call_site:Dictionary = stack.front()

	var args3:Array = args.keys().map(
		func(key:Variant) -> String:
			return format_key_value(key, args.get(key)))

	var parts:Array = [
		link(
			'{source}:{line}'.format(call_site),
			'[color=57b3ff]{function}[/color]'.format(call_site)),
		"(", ', '.join(args3), ")"
	]
	printy("".join(parts), [], object, "", stack)


func printy(
			content:Variant,
			args_in:Variant = null,
			object:Object = null,
			indent:String = "",
			custom_stack:Array[Dictionary] = [] ) -> void:
	if disabled:
		return
	if OS.get_thread_caller_id() in thread_filter:
		return
	# FIXME: hard sleep on every log line — starves threads and slows the
	# editor under TRACE. Prefer coalesce / frame budget instead.
	OS.delay_msec(4)

	last_time = get_time.call()
	last_frame = Engine.get_process_frames()
	last_pframe = Engine.get_physics_frames()

	if content is PackedByteArray:
		var bytes:PackedByteArray = content
		print(Enetheru.string.sbytes(bytes))
		return

	var ctx := _build_context(content, args_in, object, indent, custom_stack)

	if _is_ignored(ctx): return

	_apply_thread_and_proc_info(ctx)
	_apply_network_info(ctx)
	_apply_object_formatting(ctx)
	_apply_style(ctx)
	# TODO put content formatting in here for things like arrays and dicts.

	_compute_stack_distance(ctx)
	_finalize_formatting(ctx)

	if ctx.is_error:
		_print_as_error(ctx)
	elif ctx.is_warning:
		_print_as_warning(ctx)
	else:
		_print_normal(ctx)

	# Save for next distance calculation
	_save_stack(ctx.stack)


func print_end_frame(physics: bool = false) -> void:
	print_end_frame_deferred.call_deferred(physics)


func print_end_frame_deferred(_physics:bool = false) -> void:
	if not reset: return
	top_level = true

# This relies on the main project and needs to be changed.
#STUB	var line = ')('.join([
#STUB		str(Engine.get_process_frames()).lpad(5,'_'),
#STUB		("%0.1fms" % (EventBus.get_process_delta_time() * 1000)).lpad(5, '_'),
#STUB		str(Engine.get_physics_frames()).lpad(5, '_'),
#STUB		("%0.1fms" % (EventBus.get_physics_process_delta_time() * 1000)).lpad(5, '_'),
#STUB	]) + '\n'
#STUB
#STUB	print(line.lpad(80, '- ' if physics else '^ '))
	reset = false


func ptrace() -> void:
	if _default_level < LogLevel.TRACE: return
	if OS.get_thread_caller_id() in thread_filter:return
	var colour:String = get_colour(LogLevel.TRACE).to_html()
	var call_site:Dictionary = get_stack()[1]
	var line:String = link('{source}:{line}'.format(call_site),
		"[color=57b3ff]{function}[/color]".format(call_site))
	print_rich( "[color=%s]%s[/color]" % [colour, line] )


func plog( level:int, ...message:Array ) -> void:
	if _default_level < level: return
	if OS.get_thread_caller_id() in thread_filter:return
	var colour:String = get_colour(level).to_html()
	var padding:String = "".lpad(get_stack().size()-1, '\t') if level == LogLevel.TRACE else ""
	print_rich( padding + "[color=%s]%s[/color]" % [colour, ' '.join(message)] )


func plog_check( level:int, ...message:Array ) -> bool:
	if _default_level < level: return false
	plog(level, message)
	return true


#         ███    ███ ███████ ████████ ██   ██  ██████  ██████  ███████         #
#         ████  ████ ██         ██    ██   ██ ██    ██ ██   ██ ██              #
#         ██ ████ ██ █████      ██    ███████ ██    ██ ██   ██ ███████         #
#         ██  ██  ██ ██         ██    ██   ██ ██    ██ ██   ██      ██         #
#         ██      ██ ███████    ██    ██   ██  ██████  ██████  ███████         #
func                        _________METHODS_________              ()->void:pass

func lvl( level:int ) -> bool:
	return _default_level >= level

func disable() -> void: disabled = true


func enable() -> void: disabled = false


func get_level() -> int:
	var path := _make_path()
	levels_mutex.lock()
	for prefix:String in _levels:
		if path.begins_with(prefix):
			var path_lvl:int = _levels[prefix]
			levels_mutex.unlock()
			return path_lvl
	levels_mutex.unlock()
	return _default_level


func _make_path() -> String:
	var stack: Array[Dictionary] = get_stack_popped(4)
	var parts: PackedStringArray = []
	# Build compact path from top frames (tune depth)
	var depth: int = mini(10, stack.size())
	for i in range(depth-1, 0, -1):
		var frame: Dictionary = stack[i]
		var f:String = frame.get("function", "<unknown>")
		@warning_ignore("return_value_discarded")
		parts.push_back(f)
	var path:String = "/".join(parts)
	return path


## Push level for current stack path. Returns RAII guard.
## [br] FIXME: when a method is deferred, its stack begins again.
func push_level(new_level: int) -> StackPathLogScope:
	# TODO, print when the scope starts, and when from.
	# and then print when the scope finishes.
	var path := _make_path()
	levels_mutex.lock()
	_levels[path] = new_level
	levels_mutex.unlock()
	return StackPathLogScope.new(path)


func _pop(path: String) -> void:
	levels_mutex.lock()
	@warning_ignore("return_value_discarded")
	_levels.erase(path)
	levels_mutex.unlock()


func check_level( what_lvl:int = get_level(), object:Object = null ) -> bool:
	var class_lvl:int = _default_level
	var local_lvl:int = _default_level

	if is_instance_valid(object):
		var variant:Variant
		variant = object.get(&'trace_class_lvl')
		class_lvl = variant if variant is int else 0

		variant = object.get(&'trace_local_lvl')
		local_lvl = variant if variant is int else 0

	# Logging is additive
	return (get_level() | class_lvl | local_lvl) & what_lvl


## Get the stack and strip the top n stack frames
func get_stack_popped( n:int = 0 ) -> Array:
	var stack:Array = get_stack()
	for i in mini(n+1,stack.size()-1): stack.pop_front()
	return stack


func add_style(style_name: StringName, new_style: Dictionary) -> void:
	if styles.has(style_name):
		printy("Overwriting Style: ", style_name)

	if new_style.has(&"regex") and not new_style.has(&"RegEx"):
		var pattern:String = new_style.regex
		var compiled:RegEx = RegEx.create_from_string(pattern)
		if compiled.is_valid():
			new_style[&"RegEx"] = compiled
		else:
			printy("style has an invalid regex pattern: '%s'", new_style.regex)
			return

	styles_mutex.lock()
	styles[style_name] = new_style
	styles_mutex.unlock()


func net_is_not_valid() -> bool: return false


func get_zero_int() -> int: return 0


## Match the flag of most importance
func get_colour(type:int) -> Color:
	if type & LogLevel.TRACE:    return TWEAK_OPTS.color_notice_trace
	if type & LogLevel.DEBUG:    return TWEAK_OPTS.color_notice_debug
	if type & LogLevel.NOTICE:   return TWEAK_OPTS.color_notice_notice
	if type & LogLevel.DEFAULT:  return TWEAK_OPTS.color_notice_notice
	if type & LogLevel.WARNING:  return TWEAK_OPTS.color_notice_warning
	if type & LogLevel.ERROR:    return TWEAK_OPTS.color_notice_error
	if type & LogLevel.CRITICAL: return TWEAK_OPTS.color_notice_critical
	return Color.DEEP_PINK

#               ███████ ████████ ██████  ██ ███    ██  ██████                  #
#               ██         ██    ██   ██ ██ ████   ██ ██                       #
#               ███████    ██    ██████  ██ ██ ██  ██ ██   ███                 #
#                    ██    ██    ██   ██ ██ ██  ██ ██ ██    ██                 #
#               ███████    ██    ██   ██ ██ ██   ████  ██████                  #
func                        __________STRING_________              ()->void:pass

func get_empty_string() -> String: return ""


func get_script_name( script:Script ) -> String:
	var script_name:String = script.get_global_name()
	if script_name.is_empty() and script.get_base_script():
		script_name = script.get_base_script().get_global_name()
	if script_name.is_empty():
		script_name = script.resource_path.get_file().get_basename()
	return script_name


## Returns a BBCode URL link string.
func link( url:String, text:String = "" ) -> String:
	return "[u '{osco}{url}{osct}'][url={url}]{text}[/url][/u][u '{oscc}'][/u]".format({
		&'osco':OSC_LINK_OPEN, &'osct':OSC_ST, &'oscc':OSC_LINK_CLOSE,
		&'url':url, &'text':(url if text.is_empty() else text) })


func strip_bbcode(s: String) -> String:
	var regex := RegEx.new()
	if regex.compile("\\[.*?\\]") != OK:
		return "regex error"
	return regex.sub(s, "", true)


# args dictionary values depending on their type.
func format_key_value(key:Variant, value:Variant) -> String:
	var type_val:int = typeof(value)
	match type_val:
		TYPE_NIL, TYPE_BOOL:
			return "%s=[color=ff7085]%s[/color]" % [key, value]
		TYPE_INT, TYPE_FLOAT:
			return "%s=[color=a1ffe0]%s[/color]" % [key, value]
		TYPE_STRING:
			# TODO truncate and ellipsis
			return "%s=[color=ffeda1]\"%s\"[/color]" % [key, value]
		#TYPE_VECTOR2: pass # = 5
		#TYPE_VECTOR2I: pass # = 6
		#TYPE_RECT2: pass # = 7
		#TYPE_RECT2I: pass # = 8
		#TYPE_VECTOR3: pass # = 9
		#TYPE_VECTOR3I: pass # = 10
		#TYPE_TRANSFORM2D: pass # = 11
		#TYPE_VECTOR4: pass # = 12
		#TYPE_VECTOR4I: pass # = 13
		#TYPE_PLANE: pass # = 14
		#TYPE_QUATERNION: pass # = 15
		#TYPE_AABB: pass # = 16
		#TYPE_BASIS: pass # = 17
		#TYPE_TRANSFORM3D: pass # = 18
		#TYPE_PROJECTION: pass # = 19
		#TYPE_COLOR: pass # = 20
		TYPE_STRING_NAME:
			return "%s=[color=ffc2a6]%s[/color]" % [key, value]
		TYPE_NODE_PATH:
			return "%s=[color=b8c47d]%s[/color]" % [key, value]
		#TYPE_RID: pass # = 23
		TYPE_OBJECT: pass # = 24
		TYPE_CALLABLE:
			var c:Callable = value
			return "%s=%s" % [key, c.get_method()]
		#TYPE_SIGNAL: pass # = 26
		TYPE_DICTIONARY:
			var d:Dictionary = value
			if not d.is_typed():
				return "%s=dict{%s}" % [key, "" if d.is_empty() else str(d.size())]
			var kt:String = d.get_typed_key_class_name()
			if kt.is_empty(): kt = type_string(d.get_typed_key_builtin())
			var vt:String = d.get_typed_value_class_name()
			if vt.is_empty(): vt = type_string(d.get_typed_value_builtin())
			return "%s=dict<%s,%s>{%s}" % [key,kt,vt, d.size()]
		TYPE_ARRAY:
			var a:Array = value
			if not a.is_typed():
				return "%s=Array[%s]" % [key, "" if a.is_empty() else str(a.size())]
			var tn:StringName = a.get_typed_class_name()
			if tn.is_empty(): tn = type_string(a.get_typed_builtin())
			return "%s=Array<%s>[%s]" % [key, tn , a.size()]
		TYPE_PACKED_BYTE_ARRAY:
			var p:PackedByteArray = value
			return "%s=bytes[%s]" % [key, "" if p.is_empty() else str(p.size())]
		TYPE_PACKED_INT32_ARRAY:
			var p:PackedInt32Array = value
			return "%s=int[%s]" % [key, "" if p.is_empty() else str(p.size())]
		TYPE_PACKED_INT64_ARRAY:
			var p:PackedInt64Array = value
			return "%s=int64[%s]" % [key, "" if p.is_empty() else str(p.size())]
		TYPE_PACKED_FLOAT32_ARRAY:
			var p:PackedFloat32Array = value
			return "%s=float[%s]" % [key, "" if p.is_empty() else str(p.size())]
		TYPE_PACKED_FLOAT64_ARRAY:
			var p:PackedFloat64Array = value
			return "%s=double[%s]" % [key, "" if p.is_empty() else str(p.size())]
		TYPE_PACKED_STRING_ARRAY:
			var p:PackedStringArray = value
			return "%s=string[%s]" % [key, "" if p.is_empty() else str(p.size())]
		TYPE_PACKED_VECTOR2_ARRAY:
			var p:PackedVector2Array = value
			return "%s=vec2[%s]" % [key, "" if p.is_empty() else str(p.size())]
		TYPE_PACKED_VECTOR3_ARRAY:
			var p:PackedVector3Array = value
			return "%s=vec3[%s]" % [key, "" if p.is_empty() else str(p.size())]
		TYPE_PACKED_COLOR_ARRAY:
			var p:PackedColorArray = value
			return "%s=color[%s]" % [key, "" if p.is_empty() else str(p.size())]
		TYPE_PACKED_VECTOR4_ARRAY:
			var p:PackedVector4Array = value
			return "%s=vec4[%s]" % [key, "" if p.is_empty() else str(p.size())]
		_:
			return str(key) + "= %s(%s)" % [str(value), type_string(type_val)]


	# Only Object falls through.
	if value is Resource:
		var r:Resource = value
		if not r.resource_path.is_empty():
			var link_string:String = link( r.resource_path, r.resource_path.get_file())
			return "%s=%s" % [key, link_string]

		var r_script:Script = r.get_script()
		if r_script:
			var script_name:String = get_script_name(r_script)
			var link_string:String = link( r_script.resource_path, script_name)
			return "%s=%s" % [key, link_string]
		return "%s=%s" % [key, r]

	if value is Node:
		return str(key) + "=" + value.name

	if value is Object:
		var o:Object = value
		var obj_name:Variant = o.get(&"name")
		if obj_name != null:
			return str(key) + "=" + str(obj_name)
		return str(key) + "=" + o.get_class()
	return str(key) + "=" + str(value)


#             ██████  ██████  ██ ██    ██  █████  ████████ ███████             #
#             ██   ██ ██   ██ ██ ██    ██ ██   ██    ██    ██                  #
#             ██████  ██████  ██ ██    ██ ███████    ██    █████               #
#             ██      ██   ██ ██  ██  ██  ██   ██    ██    ██                  #
#             ██      ██   ██ ██   ████   ██   ██    ██    ███████             #
func                        _________PRIVATE_________              ()->void:pass

func _build_context(
	content: Variant,
	args_in: Variant,
	object: Object,
	indent: String,
	custom_stack: Array[Dictionary]
) -> LogCtx:

	var ctx := LogCtx.new()
	ctx.content = content
	ctx.object = object
	ctx.indent = indent

	if args_in:
		if args_in is Array: ctx.args = args_in
		else: ctx.args = [args_in]

	if custom_stack.is_empty():
		ctx.stack = get_stack()
		if not ctx.stack.is_empty():
			ctx.stack.pop_front()  # remove printy call itself
	else:
		ctx.stack = custom_stack

	ctx.stack_size = ctx.stack.size()

	# Initial error/warning guess from prefix
	var prefix := str(content).left(10).to_upper()
	ctx.is_error = prefix.begins_with("ERR")
	ctx.is_warning = prefix.begins_with("WARN")

	if disabled and not (ctx.is_error or ctx.is_warning):
		ctx.is_error = false
		ctx.is_warning = false

	return ctx


func _is_ignored(ctx: LogCtx) -> bool:
	return str(ctx.content) in ignore_filter


func _compute_stack_distance(ctx: LogCtx) -> void:
	prev_stack_mutex.lock()
	ctx.distance = ctx.stack_size - prev_stack_size
	prev_stack_dist = ctx.distance
	prev_stack_size = ctx.stack_size
	prev_stack = ctx.stack
	prev_stack_mutex.unlock()

	if ctx.stack_size == 0 and top_level == false:
		top_level = true
		ctx.newline = true
	elif ctx.stack_size > 0:
		top_level = false

	var ssize := ctx.stack_size

	# Apply icon penalty consistently (header or msg icon counts)
	var has_icon:bool = ctx.header_icon or ctx.msg_icon

	if ctx.indent.is_empty():
		if has_icon: ssize -= 1
		if ctx.distance > 0:
			ssize -= ctx.distance
			ctx.flow = "└─" + "".rpad(ctx.distance-1, ' ') + "┐"
		else:
			ctx.flow = "│"
		ctx.indent = "  " + " ".repeat(maxi(0, ssize-1))

	if ctx.distance < 0:
		ctx.flow_return = "┌─" + "──".repeat(absi(ctx.distance+1)) + "┘"


func _apply_thread_and_proc_info(ctx: LogCtx) -> void:
	if ctx.thread_id == OS.get_main_thread_id():
		# Main Thread
		ctx.proc_icon = ""
		ctx.thread_color = Color.WEB_GRAY.to_html()
	else:
		thread_color_mutex.lock()
		var col:Color = thread_color.get_or_add(ctx.thread_id, Enetheru.colour.random())
		thread_color_mutex.unlock()
		ctx.thread_color = col.to_html()
		ctx.proc_icon = ""


func _apply_network_info(ctx: LogCtx) -> void:
	var rpc_string := ""
	if (
		Thread.is_main_thread()
		and is_instance_valid( is_net_valid.get_object())
		and is_net_valid.call()
		):
		var _net_id:int = get_net_id.call()
		if net_id != _net_id:
			ctx.newline = true
			net_id = _net_id
			net_string = get_net_string.call()

		var sender_id := -1
		if is_instance_valid(ctx.object) and ctx.object is Node:
			var node: Node = ctx.object
			if node.is_inside_tree():
				sender_id = node.multiplayer.get_remote_sender_id()
		if sender_id > 0:
			rpc_string = '[color=cornflower_blue]󰏴 %s[/color]' % [("%016X" % sender_id).right(4)]

	ctx.net = "      " if net_string.is_empty() else net_string
	ctx.rpc = "      " if rpc_string.is_empty() else rpc_string


func _apply_object_formatting(ctx: LogCtx) -> void:
	if not ctx.object is Object:
		if ctx.object != null:
			ctx.header_name = type_string(typeof(ctx.object))
			ctx.header_icon = " "
		return

	type_match_mutex.lock()
	for matcher in type_match:
		matcher.call(ctx.object, ctx)
	type_match_mutex.unlock()

	if ctx.header_name.is_empty():
		if "name" in ctx.object:
			ctx.header_name = str(ctx.object.get("name"))

	if ctx.header_name.is_empty():
		var script:Script = ctx.object.get_script()
		if script:
			ctx.header_name = get_script_name(script)

	if ctx.header_name.is_empty():
		ctx.header_name = type_string(typeof(ctx.object))
		ctx.header_icon = " "

	if ctx.header_color.is_empty():
		header_color_mutex.lock()
		var col:Color = header_color.get_or_add(ctx.header_name, Enetheru.colour.random())
		header_color_mutex.unlock()
		ctx.header_color = col.to_html()


func _apply_style(ctx: LogCtx) -> void:
	if not ctx.content is String:
		ctx.msg_icon = " "
		ctx.msg_text = "\n".join([str(ctx.content)] + ctx.args)
		if ctx.content is Control:      ctx.msg_color = "yellowgreen"
		elif ctx.content is Node2D:     ctx.msg_color = "dodger_blue"
		elif ctx.content is Node3D:     ctx.msg_color = "salmon"
		return

	var raw_msg := str(ctx.content) % ctx.args
	var prefix := ""

	styles_mutex.lock()
	for key in styles:
		var stl := styles[key]
		var matched := false

		if stl.has(&"RegEx"):
			var r:RegEx = stl[&"RegEx"]
			var rmatch:RegExMatch = r.search(raw_msg)
			if rmatch and rmatch.get_end() >= 0:
				matched = true
				if stl.get(&"trim_prefix", false):
					prefix = rmatch.get_string()
		elif raw_msg.begins_with(key):
			matched = true
			if stl.get(&"trim_prefix", false):
				prefix = key

		if matched:
			ctx.msg_pre   = stl.get(&"pre",   "")
			ctx.msg_post  = stl.get(&"post",  "")
			ctx.msg_icon  = stl.get(&"icon",  "")
			ctx.msg_color = stl.get(&"color", "")
			ctx.is_error  = ctx.is_error or stl.get(&"is_error", false)
			break
	styles_mutex.unlock()

	ctx.msg_text = raw_msg.trim_prefix(prefix)


func _finalize_formatting(ctx: LogCtx) -> void:
	# time
	ctx.time = ''.join([
		ctx.time_icon,
		"%08X" % last_time])
	# proc
	#ctx.proc = "[color={proc_c}]{proc_i}{proc_p}[/color]".format(ctx)
	ctx.proc = ''.join([
		ctx.proc_icon,
		"[color=%s]%05X[/color]" % [ctx.proc_color, ctx.proc_id],
		".[color=%s]%02d[/color]" % [ctx.thread_color, ctx.thread_id],
		])

	ctx.left = "|".join([
		ctx.time,
		ctx.proc,
		ctx.rpc if ctx.rpc else "     ",
		ctx.net if ctx.net else "     ",
		ctx.indent
	])

	# Call site
	if ctx.stack.size() > 1:
		ctx.call_site = link('{source}:{line}'.format(ctx.stack[1]), ' ')
	else:
		ctx.call_site = link('{source}:{line}'.format(ctx.stack[0] if ctx.stack else {}), '󰘦 ')

	# Header line (object part)

	ctx.header = ctx.header_icon + ctx.header_name
	if ctx.header:
		if ctx.header_color:
			#ctx.header = "[color={header_color}]{header}[/color]".format(ctx)
			ctx.header = "[color=%s]%s[/color]" % [
					ctx.header_color, ctx.header]
		ctx.header += "."

	# Message line
	ctx.msg = ctx.msg_pre + ctx.msg_text + ctx.msg_post
	if ctx.msg_color:
		ctx.msg = "[color={msg_color}]{msg}[/color]".format(ctx)
		if ctx.msg_icon:
			ctx.msg_icon = "[color={msg_color}]{msg_icon}[/color]".format(ctx)



## Reflows documentation text according to specified rules.
##[br]
##[br] - Preserves the first line exactly, where first line ends at the first top-level \n (not inside BBCode).
##[br] - Treats BBCode blocks (with nesting) as atomic: does not modify them or their content.
##[br] - Preserves top-level newlines (treats them as paragraph breaks).
##[br] - Reflows only top-level plain text segments longer than max_width (visible length), splitting on spaces/commas etc.
##[br] - Continuation lines indented by continuation_indent spaces.
##[br]
##[br]Returns array of lines (without trailing \n).
##[br][color=goldenrod]TODO[/color]: make this a formatting option.
func _reflow_text(
			text: String,
			max_width: int = 88,
			continuation_indent: int = 4) -> Array[String]:
	var result: Array[String] = []

	# Find end of first line: first top-level \n
	var first_line_end := _find_first_top_level_newline(text)
	if first_line_end == -1:
		# No \n at all: whole text is first line, preserve
		result.append(text)
		return result

	var first_line := text.substr(0, first_line_end)
	result.append(first_line)

	# Remaining text after first \n
	var remaining := text.substr(first_line_end + 1)
	if remaining.is_empty():
		return result

	# Parse remaining into top-level elements and reflow plain text
	var i: int = 0
	var n: int = remaining.length()

	while i < n:
		# Skip whitespace if not preserving exactly, but since top-level, keep for indent?
		# For now, process as-is

		if remaining[i] == '[':
			# Possible BBCode start
			var block_end := _find_bbcode_block_end(remaining, i)
			if block_end > i:
				# Valid block: copy whole untouched
				var block := remaining.substr(i, block_end - i + 1)
				# Since blocks can have \n, split and append each line
				var block_lines := block.split("\n")
				for line in block_lines:
					result.append(line)
				i = block_end + 1
				continue

		# Start of plain text paragraph
		# Collect until next top-level [ or end
		var para_start := i
		var para_end := n
		while i < n:
			if remaining[i] == '\n':
				# Top-level \n: end of paragraph
				para_end = i
				break
			elif remaining[i] == '[':
				var block_end:int = _find_bbcode_block_end(remaining, i)
				if block_end > i:
					para_end = i
					break
				else:
					i += 1
					continue
			i += 1

		if para_start < para_end:
			var paragraph := remaining.substr(para_start, para_end - para_start)
			var reflowed := _reflow_plain_paragraph(paragraph, max_width, continuation_indent)
			for rline in reflowed:
				result.append(rline)

		# If \n, append empty line? No: split("\n") would handle, but since we stopped at \n
		if i < n and remaining[i] == '\n':
			#result.append("")  # preserve the blank line / paragraph break
			i += 1

	return result


## Finds position of first top-level \n (not inside BBCode).
## Returns -1 if none.
func _find_first_top_level_newline(s: String) -> int:
	var i: int = 0
	var n: int = s.length()
	var depth: int = 0  # BBCode nesting depth

	while i < n:
		if s[i] == '\n' and depth == 0:
			return i
		elif s[i] == '[':
			# Check if opening or closing
			if i + 1 < n and s[i+1] == '/':
				# Closing: decrease depth if matching
				var close_end := s.find(']', i + 2)
				if close_end != -1:
					depth = max(0, depth - 1)
					i = close_end + 1
					continue
			else:
				# Opening: increase depth
				var open_end := s.find(']', i + 1)
				if open_end != -1:
					depth += 1
					i = open_end + 1
					continue
			# Malformed: skip [
			i += 1
		else:
			i += 1

	return -1


## Given start at [, finds the end ] of the matching [/tag], handling nesting.
## Returns -1 if invalid or unmatched.
func _find_bbcode_block_end(s: String, start: int) -> int:
	if s[start] != '[' or start + 1 >= s.length():
		return -1

	# Find end of opening tag
	var open_close := s.find(']', start + 1)
	if open_close == -1:
		return -1

	var tag_content := s.substr(start + 1, open_close - start - 1).strip_edges()
	if tag_content.begins_with('/'):
		return -1  # not opening

	var tag_name := tag_content.split(' ')[0].split('=')[0]  # rough
	var close_tag := "[/" + tag_name + "]"

	var i := open_close + 1
	var depth := 1  # start with 1 for the outer

	while i < s.length():
		if s[i] == '[':
			if i + 1 < s.length() and s[i+1] == '/':
				# Possible close
				var maybe_close_end := s.find(']', i + 2)
				if maybe_close_end != -1:
					var maybe_close := s.substr(i, maybe_close_end - i + 1)
					if maybe_close == close_tag:
						depth -= 1
						if depth == 0:
							return maybe_close_end
					i = maybe_close_end + 1
					continue
			else:
				# Possible nested open
				var nested_open_end := s.find(']', i + 1)
				if nested_open_end != -1:
					var nested_tag := s.substr(i + 1, nested_open_end - i - 1).strip_edges().split(' ')[0].split('=')[0]
					if nested_tag == tag_name:
						depth += 1
					i = nested_open_end + 1
					continue
			i += 1
		else:
			i += 1

	return -1  # unmatched


## Reflows a plain text paragraph (no [ ] assumed).
## Splits on spaces, commas, etc.
func _reflow_plain_paragraph(text: String, max_width: int, continuation_indent: int) -> Array[String]:
	var lines: Array[String] = []
	var current_line := ""
	var current_len := 0

	var words := _split_plain_text(text)  # split on spaces/commas etc., keeping delimiters?

	for word in words:
		var word_len := word.length()  # since plain, visible = len
		if current_len + word_len > max_width and not current_line.is_empty():
			lines.append(current_line)
			current_line = " ".repeat(continuation_indent) + word
			current_len = continuation_indent + word_len
		else:
			if not current_line.is_empty() and word != "," and word != "." :  # rough
				current_line += " "
				current_len += 1
			current_line += word
			current_len += word_len

	if not current_line.is_empty():
		lines.append(current_line)

	return lines


## Splits plain text on delimiters for wrapping (spaces, commas, etc.).
## Returns array of tokens (words + delimiters?).
func _split_plain_text(s: String) -> Array[String]:
	var result: Array[String] = []
	var current := ""
	var i := 0
	while i < s.length():
		var c := s[i]
		if c in " \t,;\n":  # delimiters to break on
			if not current.is_empty():
				result.append(current)
			if c != " " and c != "\t":  # keep non-ws delimiters?
				result.append(c)
			current = ""
		else:
			current += c
		i += 1
	if not current.is_empty():
		result.append(current)
	return result


func _print_normal(ctx: LogCtx) -> void:
	# Return Flow
	if ctx.distance < 0:
		print_rich( ctx.left,
			"" if ctx.msg_icon.is_empty() else ' ',
			ctx.flow_return)

	# Newline
	if ctx.newline: print()

	# Line Before
	if not ctx.before.is_empty(): print_rich(ctx.before)

	var mid:String = ''.join([
		ctx.msg_icon,
		ctx.flow,
		ctx.call_site,
		ctx.header])
	# TODO I need to figure out how i can get the width of the output console.

	var wrapped_lines:Array = _reflow_text(ctx.msg, 80, 0)
	var reflow_left:String = " ".repeat(strip_bbcode(ctx.left).length())

	for i in wrapped_lines.size():
		if i == 0:
			print_rich(ctx.left, mid, wrapped_lines[i])
			continue

		print_rich(reflow_left, " ".repeat(ctx.flow.length()-1), '    ',  wrapped_lines[i])

	# Line After
	if not ctx.after.is_empty(): print_rich(ctx.after)


func _print_as_error(ctx: LogCtx) -> void:
	print_rich("".join([
		"[pulse freq=2 color=#FFFFFF70]",
		ctx.left, ctx.msg_icon, ctx.flow, ctx.call_site, ctx.header,
		"[color=red]", strip_bbcode(ctx.msg), "[/color]",
		"[/pulse]"
	]))
	var stack:Array = ctx.stack
	for idx:int in range(1,stack.size()):
		var frame:Dictionary = stack[idx]
		print_rich("[color=salmon]" + link("{source}:{line}".format(frame)) + ":{function}[/color]".format(frame))


func _print_as_warning(ctx: LogCtx) -> void:
	print_rich("".join([
		"[pulse freq=2 color=gold]",
		ctx.left, ctx.msg_icon, ctx.flow, ctx.call_site, ctx.header,
		"[color=yellow]", strip_bbcode(ctx.msg), "[/color]",
		"[/pulse]"
	]))
	var stack:Array = ctx.stack
	for idx:int in range(1,stack.size()):
		var frame:Dictionary = stack[idx]
		print_rich(link("{source}:{line}".format(frame)) + ":{function}".format(frame))


func _save_stack(stack: Array[Dictionary]) -> void:
	prev_stack_mutex.lock()
	prev_stack_dist = stack.size() - prev_stack_size
	prev_stack_size = stack.size()
	prev_stack = stack
	prev_stack_mutex.unlock()


#     ███████ ██   ██  █████  ███    ███ ██████  ██      ███████ ███████       #
#     ██       ██ ██  ██   ██ ████  ████ ██   ██ ██      ██      ██            #
#     █████     ███   ███████ ██ ████ ██ ██████  ██      █████   ███████       #
#     ██       ██ ██  ██   ██ ██  ██  ██ ██      ██      ██           ██       #
#     ███████ ██   ██ ██   ██ ██      ██ ██      ███████ ███████ ███████       #
func                        ________EXAMPLES_________              ()->void:pass

func example_net_string() -> String:
	var server : bool = false
	var main_loop :SceneTree = Engine.get_main_loop()
	if main_loop \
		and main_loop.current_scene \
		and	main_loop.current_scene.multiplayer:
			server = main_loop.current_scene.multiplayer.is_server()

	var fd : Dictionary = {
		'icon': "󰒍 " if server else "󰀑 ",
		'iconc': 'yellow' if server else 'greenyellow',
		'id': Enetheru.string.id_str( net_id ),
		'idc': 'goldenrod' if server else Enetheru.colour.random().to_html() }
	return "[color={iconc}]{icon}[/color][color={idc}]{id}[/color]".format(fd)


# Example type matcher for an object:
func null_matcher( v:Variant, ctx:LogCtx ) -> void:
	if v == null:
		ctx.header_icon = ' '
		ctx.header_color = "salmon"
		ctx.header_name = "<null>"
