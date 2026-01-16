@tool
class_name EneLog
# │           _     _
# │  _ __ _ _(_)_ _| |_ _  _
# │ | '_ \ '_| | ' \  _| || |
# │ | .__/_| |_|_||_\__|\_, |
# ╰─|_|─────────────────|__/-<<
# Logging utility for pretty printing to output console

const MAX_INT:int = 0x7FFF_FFFF_FFFF_FFFF
const MIN_INT:int = -0x8000_0000_0000_0000

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

	#proc_fd
	var proc:String
	var proc_c:String = Color(0.4, 0.4, 0.4).to_html()
	var proc_i:String = " "
	var proc_p:String = "%05d" % OS.get_process_id()

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


# ██████  ██████   ██████  ██████  ███████ ██████  ████████ ██ ███████ ███████ #
# ██   ██ ██   ██ ██    ██ ██   ██ ██      ██   ██    ██    ██ ██      ██      #
# ██████  ██████  ██    ██ ██████  █████   ██████     ██    ██ █████   ███████ #
# ██      ██   ██ ██    ██ ██      ██      ██   ██    ██    ██ ██           ██ #
# ██      ██   ██  ██████  ██      ███████ ██   ██    ██    ██ ███████ ███████ #
func                        ________PROPERTIES_______              ()->void:pass

# ─────────────────────────────────────────────────────────────────────────────
#  Shared configuration (locked when modified at runtime)
# ─────────────────────────────────────────────────────────────────────────────

static var disabled:bool = false
static var reset:bool = true
static var top_level:bool = true

# Frequency adjustment
static var last_time:int
static var threshold:int = 1000
static var delay_amount:int = 100
static var last_frame:int = 0
static var last_pframe:int = 0

# Stack Flow (shared for continuity)
static var prev_stack_mutex := Mutex.new()
static var prev_stack:Array[Dictionary]
static var prev_stack_size:int = 32
static var prev_stack_dist:int = 0

# Filter
static var ignore_filter:Array[String] = []

# Process / Network
static var proc_id:int
static var net_id:int
static var net_string:String

static var is_net_valid:Callable
static var get_net_id:Callable = get_zero_int
static var get_net_string:Callable = get_empty_string


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
static var styles_mutex := Mutex.new()
static var styles:Dictionary[StringName, Dictionary] = {
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
}

static var header_color_mutex := Mutex.new()
static var header_color:Dictionary[String, Color] = {}

static var type_match_mutex := Mutex.new()
static var type_match:Array[Callable] = []


#      ██████  ██    ██ ███████ ██████  ██████  ██ ██████  ███████ ███████     #
#     ██    ██ ██    ██ ██      ██   ██ ██   ██ ██ ██   ██ ██      ██          #
#     ██    ██ ██    ██ █████   ██████  ██████  ██ ██   ██ █████   ███████     #
#     ██    ██  ██  ██  ██      ██   ██ ██   ██ ██ ██   ██ ██           ██     #
#      ██████    ████   ███████ ██   ██ ██   ██ ██ ██████  ███████ ███████     #
func                        ________OVERRIDES________              ()->void:pass

static func _static_init() -> void:
	is_net_valid = func() -> bool: return false
	get_net_id = get_zero_int
	get_net_string = get_empty_string
	proc_id = OS.get_process_id()

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
		var stl = styles[key]
		if stl.has(&"regex"):
			stl[&"RegEx"] = RegEx.create_from_string(stl.regex)
	styles_mutex.unlock()


#         ███    ███ ███████ ████████ ██   ██  ██████  ██████  ███████         #
#         ████  ████ ██         ██    ██   ██ ██    ██ ██   ██ ██              #
#         ██ ████ ██ █████      ██    ███████ ██    ██ ██   ██ ███████         #
#         ██  ██  ██ ██         ██    ██   ██ ██    ██ ██   ██      ██         #
#         ██      ██ ███████    ██    ██   ██  ██████  ██████  ███████         #
func                        _________METHODS_________              ()->void:pass

static func disable() -> void: disabled = true


static func enable() -> void: disabled = false


static func add_style(style_name: StringName, new_style: Dictionary) -> void:
	if styles.has(style_name):
		printy("Overwriting Style: ", style_name)

	if new_style.has(&"regex") and not new_style.has(&"RegEx"):
		var compiled = RegEx.create_from_string(new_style.regex)
		if compiled.is_valid():
			new_style[&"RegEx"] = compiled
		else:
			printy("style has an invalid regex pattern: '%s'", new_style.regex)
			return

	styles_mutex.lock()
	styles[style_name] = new_style
	styles_mutex.unlock()


static func get_script_name(script: Script) -> String:
	var name = script.get_global_name()
	if name.is_empty() and script.get_base_script():
		name = script.get_base_script().get_global_name()
	if name.is_empty():
		name = script.resource_path.get_file().get_basename()
	return name


static func strip_bbcode(s: String) -> String:
	var regex = RegEx.new()
	regex.compile("\\[.*?\\]")
	return regex.sub(s, "", true)


static func print_end_frame(physics: bool = false) -> void:
	print_end_frame_deferred.call_deferred(physics)


static func print_end_frame_deferred(physics: bool = false) -> void:
	if not reset: return
	top_level = true

	var line = ')('.join([
		str(Engine.get_process_frames()).lpad(5,'_'),
		("%0.1fms" % (EventBus.get_process_delta_time() * 1000)).lpad(5, '_'),
		str(Engine.get_physics_frames()).lpad(5, '_'),
		("%0.1fms" % (EventBus.get_physics_process_delta_time() * 1000)).lpad(5, '_'),
	]) + '\n'

	print(line.lpad(80, '- ' if physics else '^ '))
	reset = false


static func get_zero_int() -> int: return 0


static func get_empty_string() -> String: return ""


static func trace(args: Dictionary = {}, stack: Array = [], object: Object = null) -> void:
	if not OS.has_feature('trace'): return
	if stack.is_empty():
		stack = get_stack()
		stack.pop_front()
	var call_site = stack.front()
	var parts = [
		"[url='{source}:{line}']{function}[/url]".format(call_site),
		JSON.stringify(args, '', false)
	]
	printy("".join(parts), [], object, "", stack)


static func printy(
	content: Variant,
	args_in: Variant = null,
	object: Object = null,
	indent: String = "",
	custom_stack: Array[Dictionary] = []
) -> void:

	if not OS.has_feature('trace'): return

	last_time = Time.get_ticks_usec()
	last_frame = Engine.get_process_frames()
	last_pframe = Engine.get_physics_frames()

	if content is PackedByteArray:
		print(Enetheru.string.sbytes(content))
		return

	var ctx := _build_context(content, args_in, object, indent, custom_stack)

	if _is_ignored(ctx): return

	_apply_thread_and_proc_info(ctx)
	_apply_network_info(ctx)
	_apply_object_formatting(ctx)
	_apply_style(ctx)

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


#     ███████ ██   ██  █████  ███    ███ ██████  ██      ███████ ███████       #
#     ██       ██ ██  ██   ██ ████  ████ ██   ██ ██      ██      ██            #
#     █████     ███   ███████ ██ ████ ██ ██████  ██      █████   ███████       #
#     ██       ██ ██  ██   ██ ██  ██  ██ ██      ██      ██           ██       #
#     ███████ ██   ██ ██   ██ ██      ██ ██      ███████ ███████ ███████       #
func                        ________EXAMPLES_________              ()->void:pass

static func example_net_string() -> String:
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
static func null_matcher( v:Variant, ctx:LogCtx ) -> void:
	if v == null:
		ctx.header_icon = ' '
		ctx.header_color = "salmon"
		ctx.header_name = "<null>"


#             ██████  ██████  ██ ██    ██  █████  ████████ ███████             #
#             ██   ██ ██   ██ ██ ██    ██ ██   ██    ██    ██                  #
#             ██████  ██████  ██ ██    ██ ███████    ██    █████               #
#             ██      ██   ██ ██  ██  ██  ██   ██    ██    ██                  #
#             ██      ██   ██ ██   ████   ██   ██    ██    ███████             #
func                        _________PRIVATE_________              ()->void:pass

static func _build_context(
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


static func _is_ignored(ctx: LogCtx) -> bool:
	return str(ctx.content) in ignore_filter


static func _compute_stack_distance(ctx: LogCtx) -> void:
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
	var has_icon = ctx.header_icon or ctx.msg_icon

	if ctx.indent.is_empty():
		if has_icon: ssize -= 1
		if ctx.distance > 0:
			ssize -= ctx.distance
			ctx.flow = "└─" + "".rpad(ctx.distance-1, ' ') + "┐"
		else:
			ctx.flow = "│"
		ctx.indent = "  " + " ".repeat(maxi(0, ssize-1))

	if ctx.distance < 0:
		ctx.flow_return = "┌─" + "──".repeat(abs(ctx.distance+1)) + "┘"


static func _apply_thread_and_proc_info(ctx: LogCtx) -> void:
	var is_thread = OS.get_thread_caller_id() != OS.get_main_thread_id()
	ctx.proc_icon = " " if is_thread else " "


static func _apply_network_info(ctx: LogCtx) -> void:
	var rpc_string := ""
	if is_instance_valid(is_net_valid) and is_net_valid.call():
		var _net_id := get_net_id.call()
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
			rpc_string = '[color=cornflower_blue]󰏴 %s[/color]' % ("%016X"%sender_id).right(4)

	ctx.net = "      " if net_string.is_empty() else net_string
	ctx.rpc = "      " if rpc_string.is_empty() else rpc_string


static func _apply_object_formatting(ctx: LogCtx) -> void:
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
		var script := ctx.object.get_script()
		if script:
			ctx.header_name = get_script_name(script)

	if ctx.header_name.is_empty():
		ctx.header_name = type_string(typeof(ctx.object))
		ctx.header_icon = " "

	if ctx.header_color.is_empty():
		header_color_mutex.lock()
		var col = header_color.get_or_add(ctx.header_name, Enetheru.colour.random())
		header_color_mutex.unlock()
		ctx.header_color = col.to_html()


static func _apply_style(ctx: LogCtx) -> void:
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
			var rmatch = stl[&"RegEx"].search(raw_msg)
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


static func _finalize_formatting(ctx: LogCtx) -> void:
	# proc
	#ctx.proc = "[color={proc_c}]{proc_i}{proc_p}[/color]".format(ctx)
	ctx.proc = "[color=%s]%s%s[/color]" % [
		ctx.proc_color,
		ctx.proc_icon,
		ctx.proc_id,
		]


	ctx.left = "|".join([
		ctx.proc,
		ctx.rpc if ctx.rpc else "     ",
		ctx.net if ctx.net else "     ",
		ctx.indent
	])

	# Call site
	if ctx.stack.size() > 1:
		ctx.call_site = "[url='{source}:{line}'] [/url]".format(ctx.stack[1])
	else:
		ctx.call_site = "[url='{source}:{line}']󰘦 [/url]".format(ctx.stack[0] if ctx.stack else {})

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


## Wraps long argument blocks, indenting continuations right after the flow symbols
static func _wrap_long_args(raw_line: String, max_width: int = 100, continuation_offset: int = 1) -> Array[String]:
	var result: Array[String] = []

	# Find where the arguments start (after function name and {)
	var brace_pos = raw_line.find("{")
	if brace_pos == -1 or raw_line.length() <= max_width:
		result.append(raw_line)
		return result

	# Prefix = everything up to and including {
	var prefix = raw_line.substr(0, brace_pos + 1)

	# Arguments part
	var args = raw_line.substr(brace_pos + 1)

	# Estimate visible prefix length (strip BBCode for width calculation)
	var visible_prefix = strip_bbcode(prefix)
	var prefix_visible_len = visible_prefix.length()

	# If whole line fits, no wrap
	if prefix_visible_len + strip_bbcode(args).length() <= max_width:
		result.append(raw_line)
		return result

	# Build first line (prefix + as much args as fits)
	var current_visible = prefix_visible_len
	var current_raw = prefix
	var wrapped_args: Array[String] = []

	# Split args on ", " but respect nested {} and quotes
	var chunks = _split_args_respecting_structure(args)

	for chunk in chunks:
		var chunk_visible = strip_bbcode(chunk)
		var added_visible = chunk_visible.length() + (1 if wrapped_args.size() > 0 else 0)  # space or comma

		if current_visible + added_visible > max_width:
			# Flush current line
			result.append(current_raw)
			# Start continuation: indent to end of previous indent + flow + offset
			current_raw = " ".repeat(prefix_visible_len - visible_prefix.length() + continuation_offset) + chunk
			current_visible = continuation_offset + chunk_visible.length()
			wrapped_args.append(current_raw)
		else:
			if wrapped_args.size() > 0:
				current_raw += " "
			current_raw += chunk
			current_visible += added_visible

	# Last chunk
	if current_raw != prefix:
		result.append(current_raw)

	return result


## Helper: split ", " but don't break inside {} or quotes
static func _split_args_respecting_structure(s: String) -> PackedStringArray:
	var result: PackedStringArray = []
	var current = ""
	var depth = 0
	var in_quote = false
	var i = 0

	while i < s.length():
		var c = s[i]
		current += c

		if c == '"' and s[i-1] != "\\":
			in_quote = !in_quote
		elif not in_quote:
			if c == "{":
				depth += 1
			elif c == "}":
				depth -= 1
			elif c == "," and depth == 0:
				result.append(current.substr(0, current.length() - 1).strip_edges())
				current = ""

		i += 1

	if current.strip_edges():
		result.append(current.strip_edges())

	return result


static func _print_normal(ctx: LogCtx) -> void:
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
		ctx.header,
		ctx.msg ])
	var wrapped_lines = _wrap_long_args(mid, 100, 0)

	for i in wrapped_lines.size():
		if i == 0:
			print_rich(ctx.left, wrapped_lines[i])
			continue
		print_rich(ctx.left, " ".repeat(ctx.flow.length()-1), '|  →  ',  wrapped_lines[i])

	# Line After
	if not ctx.after.is_empty(): print_rich(ctx.after)


static func _print_as_error(ctx: LogCtx) -> void:
	var mid:String = ''.join([
		ctx.msg_icon,
		ctx.flow,
		ctx.header,
		ctx.msg ])

	printerr(strip_bbcode(ctx.left), strip_bbcode(mid))

	print_rich(ctx.left, "".join([
		ctx.msg_icon, ctx.flow, ctx.header,
		"[pulse freq=2 color=#FFFFFF70]",
		"[color=red]", strip_bbcode(ctx.msg), "[/color]",
        "[/pulse]"
	]))

	for frame in ctx.stack:
		print_rich("".join([ctx.left, "\t[color=salmon][url={source}:{line}]{source}:{line}[/url]:{function}[/color]".format(frame)]))


static func _print_as_warning(ctx: LogCtx) -> void:
	var mid:String = ''.join([
		ctx.msg_icon,
		ctx.flow,
		ctx.header,
		ctx.msg ])

	print_debug(strip_bbcode(ctx.left), strip_bbcode(mid))

	print_rich(ctx.left, "".join([
		ctx.msg_icon,
		ctx.flow,
		ctx.header,
		"[pulse freq=2 color=gold]",
		"[color=yellow]", strip_bbcode(ctx.msg), "[/color]",
		"[/pulse]"]))

	for frame in ctx.stack:
		print_rich("".join([ctx.left, "\t[url={source}:{line}]{source}:{line}[/url]:{function}".format(frame)]))


static func _save_stack(stack: Array) -> void:
	prev_stack_mutex.lock()
	prev_stack_dist = stack.size() - prev_stack_size
	prev_stack_size = stack.size()
	prev_stack = stack
	prev_stack_mutex.unlock()
