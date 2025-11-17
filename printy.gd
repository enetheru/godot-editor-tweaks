@tool
class_name EneLog
# │           _     _
# │  _ __ _ _(_)_ _| |_ _  _
# │ | '_ \ '_| | ' \  _| || |
# │ | .__/_| |_|_||_\__|\_, |
# ╰─|_|─────────────────|__/-<<
# Logging utility for pretty printing to output console

# TODO At the moment, a prefix of "error" will trigger the error report and backtrace
# I want to be configurable
# TODO Configuration is global, I wish to have override objects, or contexts
# which can alter the configuration per function, or per class or something.

# ██████  ██████   ██████  ██████  ███████ ██████  ████████ ██ ███████ ███████ #
# ██   ██ ██   ██ ██    ██ ██   ██ ██      ██   ██    ██    ██ ██      ██      #
# ██████  ██████  ██    ██ ██████  █████   ██████     ██    ██ █████   ███████ #
# ██      ██   ██ ██    ██ ██      ██      ██   ██    ██    ██ ██           ██ #
# ██      ██   ██  ██████  ██      ███████ ██   ██    ██    ██ ███████ ███████ #
func                        ________PROPERTIES_______              ()->void:pass

# Flags
static var disabled : bool = false
static var reset : bool = true
static var top_level : bool = true
static var is_error: bool = false
static var is_warning: bool = false

# Frequecy adjustment to prevent output errors
static var last_time : int
static var threshold : int = 1000
static var delay_amount : int = 100

# Stack Flow
static var prev_stack_size : int = 32
static var prev_stack : Array[Dictionary]

static func save_stack( used_stack : Array[Dictionary] ) -> void:
	prev_stack = used_stack

# Filter
static var ignore_filter : Array[String] = []
	#"_ready()",
	#"_enter_tree()"

# Process values
static var proc_id : int
static var proc_string : String

# we only call the get_net_string if the net_id changes.
# Otherwise we use the cached net string.
static var net_id : int
static var net_string : String

# Network related callables, to be assigned by consuming project
static var is_net_valid : Callable
static var get_net_id : Callable = get_zero_int
static var get_net_string : Callable = get_empty_string

## Modifyable formatting
## Key is an all caps prefix using the following
## var prefix : String = str(content).left(10).to_upper()
## Value is a key value store used in the final formatting
## Example:
##	&'NOTE':{'color':"greenyellow", 'icon':" "}
static var styles : Dictionary[StringName, Dictionary] = {
	&'NOTE': {&'icon':" ", &'color':"greenyellow"},
	&'TODO': {&'icon':" ", &'color':"yellow"},
	&'FIXME':{&'icon':" ", &'color':"tomato"},
	&'ERR':  {&'icon':" ", &'color':"red", &'is_error':true},
	&'WARN': {&'icon':" ", &'color':"yellow"},
	&'HL':   {&'icon':"󱈸 ", &'color':"cyan"},
	&'MAX':  {&'icon':" ", &'color':"fuchsia"},
	&'RESUM':{&'icon':"󰜉 ", &'color':"medium_slate_blue"},
	&'WAIT': {&'icon':" ", &'color':"medium_slate_blue"},
}

# cached header colurs
static var header_color : Dictionary[String, Color]

## Signature for callables
## All matchers will be called on the variant.
static var type_match : Array[Callable]


#      ██████  ██    ██ ███████ ██████  ██████  ██ ██████  ███████ ███████     #
#     ██    ██ ██    ██ ██      ██   ██ ██   ██ ██ ██   ██ ██      ██          #
#     ██    ██ ██    ██ █████   ██████  ██████  ██ ██   ██ █████   ███████     #
#     ██    ██  ██  ██  ██      ██   ██ ██   ██ ██ ██   ██ ██           ██     #
#      ██████    ████   ███████ ██   ██ ██   ██ ██ ██████  ███████ ███████     #
func                        ________OVERRIDES________              ()->void:pass

static func _static_init() -> void:
	# Assign default callables
	is_net_valid = func() -> bool : return false
	get_net_id = get_zero_int
	get_net_string = get_empty_string

	# Get the processor ID and cache the string
	proc_id = OS.get_process_id()
	proc_string = get_proc_string()

	styles[&'H1'] = {
		&'before':" ",
		&'color':"white",
		&'pre':'[b]>>====[ ',
		&'post':' ]====<<[/b]',
		&'trim_prefix':true}

#         ███    ███ ███████ ████████ ██   ██  ██████  ██████  ███████         #
#         ████  ████ ██         ██    ██   ██ ██    ██ ██   ██ ██              #
#         ██ ████ ██ █████      ██    ███████ ██    ██ ██   ██ ███████         #
#         ██  ██  ██ ██         ██    ██   ██ ██    ██ ██   ██      ██         #
#         ██      ██ ███████    ██    ██   ██  ██████  ██████  ███████         #
func                        _________METHODS_________              ()->void:pass

static func disable() -> void:
	disabled = true


static func enable() -> void:
	disabled = false

# FIXME stack usage is junk, calling through this function will cause
# printy to add another layer on error which is not necessary.
static func pfunc(object : Object = null, stack : Array[Dictionary] = []) -> void:
	if stack.is_empty():
		stack = get_stack()
		stack.pop_front() # Ditch the EneLog.pfunc entry from the top

	var call_site : Dictionary = stack.front()
	var call_from : Dictionary = stack[1] if stack.size() > 1 else stack.front()
	# A stack frame looks like this: {
	#	function:bar,
	#	line:12,
	#	source:res://script.gd
	#}
	var parts : Array[String] = [
		"[url='{source}:{line}']".format(call_from),
		"{function}()".format(call_site),
		"[/url]"
	]
	printy("".join(parts), [], object, "", stack)


static func printy(
			content : Variant,
			args_in : Variant = null,
			object : Object = null,
			indent : String = "",
			stack : Array[Dictionary] = []
			) -> void:
	# Only print if trace is specified in the debug features
	#if not OS.has_feature('trace'): return
	is_error = false
	is_warning = false

	if (Time.get_ticks_usec() - last_time) < threshold:
		OS.delay_usec(delay_amount)
	last_time = Time.get_ticks_usec()

	# Reset flag, other code relies on this value.
	var prefix : String = str(content).left(10).to_upper()
	is_error = is_error or prefix.begins_with("ERR")
	is_warning = is_warning or prefix.begins_with("WARN")

	if disabled and not (is_error or is_warning): return

	# Skip if the content is in the ignore filter.
	if str(content) in ignore_filter: return

	if content is PackedByteArray:
		var pba : PackedByteArray = content
		print(Enetheru.string.sbytes(pba))
		return

	# Sanitise inputs
	var args : Array[Variant]
	if args_in:
		if args_in is Array: args = args_in
		else: args.append(args_in)

	reset = true

	var newline : bool = false

	if stack.is_empty():
		stack = get_stack()
		stack.pop_front() # Ditch the EneLog.printy entry from the top

	# Create a scope guard to save the stack when we are done.
	var _save_stack := Enetheru.async.ScopeGuard.new(save_stack.bind(stack))

	var stack_size : int = stack.size()

	# Network ID
	var rpc_string : String
	if is_net_valid.call():
		var _net_id : int = get_net_id.call()
		rpc_string = '      '
		if net_id != _net_id:
			newline = true
			net_id = _net_id
			net_string = get_net_string.call()

		# testing rpc detection
		#@warning_ignore('unsafe_property_access', 'unsafe_method_access')
		#var sender_id : int = Engine.get_main_loop().root.multiplayer.get_remote_sender_id()
		var sender_id : int = -1
		if is_instance_valid(object) and object is Node:
			var node : Node = object
			if node.is_inside_tree():
				sender_id = node.multiplayer.get_remote_sender_id()
		if sender_id > 0:
			rpc_string = '[color=cornflower_blue]󰏴 %s[/color]' % Enetheru.string.id_str(sender_id)
	else:
		net_string = ""

	# newline after stack exhaustion
	if stack_size == 0 and top_level == false:
		top_level = true
		newline = true
	elif stack_size > 0: top_level = false

	# Create the dictionary used for formatting the output
	var fd : Dictionary = {
		&'before': '',
		&'proc': proc_string ,
		&'net': '' if net_string.is_empty() else '|' + net_string,
		&'rpc': '' if rpc_string.is_empty() else '|' + rpc_string,
		&'icon':'',
		&'object': '',
		&'msg': '',
		&'after': '',
	}

	# Get the object based format dictionary
	var object_fd : Dictionary
	if object:
		object_fd = get_object_fd(object)
		fd[&'object'] = "[color={color}]{icon}{name}[/color].".format(object_fd)
		fd[&'icon'] = ' 󰊕'
	else:
		fd[&'object'] = ''

	fd.merge( get_msg_fd( content, args ), true )

	# FIXME, I can inspect the stack to see whether the previous call follows
	# on to this call  to determine which icon i should use. Because awaiting
	# breaks up the control flow into chunks, and we could be looking at
	# a completely different call stack
	if indent.is_empty():
		var ssize : int = stack_size
		if fd[&'icon']: ssize -= 1
		var distance : int = stack_size - prev_stack_size
		if distance > 0:
			ssize -= distance
			fd[&'flow'] = "└─" + "".rpad(distance-1, ' ') + "┐"
		else:
			fd[&'flow'] = "│"
		fd[&'indent'] = "".lpad( ssize, '  ' )
		#fd['proc'] += "%x" % ssize # DEBUG, useful to check stack size.
	else:
		fd[&'indent'] = indent
		fd[&'flow'] = ""

	# Update Prev vars
	prev_stack_size = stack_size

	# Finished processing data, onto printing.
	if is_error:
		printy_error(fd, stack)
		return

	if is_warning:
		printy_warning(fd, stack)
		return


	var before : String = "{before}".format(fd)

	# The left column is made of columns of data.
	var left : String = "{proc}{net}{rpc}{indent} ".format( fd )
	var mid : String = "{icon}{flow}{object}{msg}".format( fd )
	#var right : String ? would assume a column width.
	# (left + mid).rpad( width - right.size, ' ') + right

	var after : String = "{after}".format(fd)

	# newline if we want to break the flow on purpose.
	if newline: print()

	if not before.is_empty(): print_rich( before )

	print_rich( left, mid )

	if not after.is_empty(): print_rich( after )


static func printy_error( fd : Dictionary, error_stack : Array ) -> void:
	var msg : String = fd[&'msg']
	var left : String = "{proc}{net}{rpc}{indent} ".format( fd )
	var mid : String = "{icon}{flow}{object}{msg}".format( fd )
	push_error(Enetheru.string.strip_bbcode(left), Enetheru.string.strip_bbcode(mid))
	print_rich( left, "".join([
		"{icon}{flow}{object}".format(fd),
		"[pulse freq=2 color=#FFFFFF70]",
		"[color=red]",
		Enetheru.string.strip_bbcode(msg),
		"[/color]",
		"[/pulse]"
	]))
	for frame : Dictionary in error_stack:
		print_rich( "".join([left,
			"\t[color=salmon]",
			"[url={source}:{line}]{source}:{line}[/url]:{function}".format( frame ),
			"[/color]"
		]))


static func printy_warning( fd : Dictionary, error_stack : Array ) -> void:
	var msg : String = fd[&'msg']
	var left : String = "{proc}{net}{rpc}{indent} ".format( fd )
	var mid : String = "{icon}{flow}{object}{msg}".format( fd )
	push_warning(Enetheru.string.strip_bbcode(left), Enetheru.string.strip_bbcode(mid))
	print_rich( left, "".join([
		"{icon}{flow}{object}".format(fd),
		"[pulse freq=2 color=gold]",
		"[color=yellow]",
		Enetheru.string.strip_bbcode(msg),
		"[/color]",
		"[/pulse]"
	]))
	for frame : Dictionary in error_stack:
		print_rich( "".join([left,
			"\t[url={source}:{line}]{source}:{line}[/url]:{function}".format( frame ) ]))


static func get_msg_fd( content : Variant, args : Array ) -> Dictionary:
	var fd : Dictionary = {
			&'icon':'',&'color':'', &'pre':'', &'msg':'', &'post':''}

	if content is String:
		var msg : String = str(content) % args
		var front : String = str(content).left(10).to_upper()
		for key : StringName in styles.keys():
			if front.begins_with(key):
				var style : Dictionary = styles.get(key)
				fd.merge( style, true )
				if fd.has(&'trim_prefix'): msg = msg.trim_prefix(key)
				break
		fd[&'msg'] = msg
	else:
		# TODO I wonder if there is an automated way to pull the editor icons for a type?
		fd[&'icon'] = ' '
		fd[&'msg'] = "\n".join( [str(content)] + args )
		if content is Control: fd[&'color'] ='yellowgreen'
		elif content is Node2D: fd[&'color'] ='dodger_blue'
		elif content is Node3D: fd[&'color'] ='salmon'

	is_error = is_error or fd.get(&'is_error', false)

	if fd[&'color']: fd[&'msg'] = "[color={color}]{pre}{msg}{post}[/color]".format(fd)
	if fd[&'icon']: fd[&'icon'] = "[color={color}]{icon}[/color]".format(fd)
	return fd


# TODO, I want to make these type identification and formatting to be
# registered so that I can separate the printy script from my game.
# that way I can include it in sub projects, register the needed and roll.
static func get_object_fd( object : Object ) -> Dictionary:
	var fd : Dictionary[StringName, String] = {
		&'name':'', &'color':'', &'icon': '' }
	# Default to the variant type.
	# TODO, I could make this a function and return icons and types
	# based on the type, but cbf right now.

	# Call all type matchers to modify the format dictionary
	for matcher : Callable in type_match:
		matcher.call( object, fd )

	# Try to get the name from properties.
	if fd[&"name"].is_empty():
		if &"name" in object:
			fd[&"name"] = str(object.get(&"name"))

	# Try to use script name
	if fd[&"name"].is_empty():
		var script : Script = object.get_script()
		if script: fd[&'name'] = get_script_name(script)

	# Otherwise default to its variant type.
	if fd[&"name"].is_empty():
		fd[&"name"] = type_string(typeof(object))
		fd[&"icon"] = " "

	var color : Color = header_color.get_or_add( fd[&"name"], Enetheru.colour.random() )
	fd[&'color'] = color.to_html()
	return fd


static func get_proc_string() -> String:
	var fd : Dictionary = {
		'p':"%05d" % proc_id,
		'c':Color(0.4,0.4,0.4).to_html() }
	return "[color={c}] {p}[/color]".format(fd);


static func get_script_name(script : Script) -> String:
	var script_name : String = script.get_global_name()

	if script_name.is_empty():
		var base_script : Script = script.get_base_script()
		if base_script:
			script_name = base_script.get_global_name()

	if script_name.is_empty():
		script_name = script.resource_path.get_file()
		script_name = script_name.rstrip("." + script_name.get_extension())

	return script_name


#       ██████  ███████ ███████  █████  ██    ██ ██   ████████ ███████         #
#       ██   ██ ██      ██      ██   ██ ██    ██ ██      ██    ██              #
#       ██   ██ █████   █████   ███████ ██    ██ ██      ██    ███████         #
#       ██   ██ ██      ██      ██   ██ ██    ██ ██      ██         ██         #
#       ██████  ███████ ██      ██   ██  ██████  ███████ ██    ███████         #
func                        ________DEFAULTS_________              ()->void:pass

static func get_zero_int() -> int: return 0

static func get_empty_string() -> String: return ""


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
#static func null_matcher( v : Variant, style : Dictionary ) -> void:
	#if v == null:
		#style[&'icon'] = ' '
		#style[&'name'] = "<null>"
