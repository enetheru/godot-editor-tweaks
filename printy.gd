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

# TODO use this snippet to detect if we are inside a thread and report appropriately.
#if OS.get_thread_caller_id() == OS.get_main_thread_id():
	#print("Running on the main thread")
#else:
	#print("Running on a background thread (likely a worker thread)")

const MAX_INT : int = 0x7FFF_FFFF_FFFF_FFFF
const MIN_INT : int = -0x8000_0000_0000_0000

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
static var last_frame:int = 0
static var last_pframe:int = 0

# Stack Flow
static var prev_stack : Array[Dictionary]
static var prev_stack_size : int = 32
static var prev_stack_dist : int = 0

static func save_stack( stack : Array ) -> void:
	prev_stack_dist = stack.size() - prev_stack_size
	prev_stack_size = stack.size()
	prev_stack = stack

# Filter
static var ignore_filter : Array[String] = []
	#"_ready()",
	#"_enter_tree()"

# Process values
static var proc_id:int
static var proc_fd:Dictionary

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

static var styles : Dictionary[StringName, Dictionary] = {
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
	proc_fd = get_proc_fd()

	styles[&'[H1]'] = {
		&'before':" ",
		&'color':"white",
		&'pre':'[b]>>====[ ',
		&'post':' ]====<<[/b]',
		&'trim_prefix':true}

	styles[&'[P1]'] = {
		&'color':"white",
		&'pre':'[b]',
		&'post':'[/b]',
		&'trim_prefix':true}

	# compile regex's for the known styles
	for key : StringName in styles.keys():
		var stl : Dictionary = styles[key]
		if stl.has(&'regex'):
			stl[&'RegEx'] = RegEx.create_from_string(stl.regex)


static func add_style( style_name:StringName, new_style:Dictionary ) -> void:
	if styles.has(style_name): printy("Overwriting Style: ", style_name)

	if new_style.has(&'regex') and not new_style.has(&'RegEx'):
		var compiled := RegEx.create_from_string(new_style.regex)
		if compiled.is_valid():
			new_style[&'RegEx'] = compiled
		else:
			printy("style has an invalid regex pattern: '%s'", new_style.regex)
			return

	styles[style_name] = new_style


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


static func trace(args : Dictionary = {}, stack : Array[Dictionary] = [], object : Object = null) -> void:
	# Only print if trace is specified in the debug features
	if not OS.has_feature('trace'): return

	if stack.is_empty():
		stack = get_stack()
		stack.pop_front() # this stackframe

	var call_site : Dictionary = stack.front()
	# A stack frame: { function:bar, line:12, source:res://script.gd }
	var parts : Array[String] = [
		"[url='{source}:{line}']{function}[/url]".format(call_site),
		JSON.stringify(args, '', false)
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
	if not OS.has_feature('trace'): return
	is_error = false
	is_warning = false

	last_time = Time.get_ticks_usec()

	var frame_dif:int = Engine.get_process_frames() - last_frame
	last_frame = Engine.get_process_frames()

	var pframe_dif:int = Engine.get_physics_frames() - last_pframe
	last_pframe = Engine.get_physics_frames()

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

	var stack_size : int = stack.size()
	var distance : int = stack_size - prev_stack_size

	# Create a scope guard to save the stack when we are done.
	var _save_stack := Enetheru.async.ScopeGuard.new(save_stack.bind(stack))

	# newline after stack exhaustion
	if stack_size == 0 and top_level == false:
		top_level = true
		newline = true
	elif stack_size > 0:
		top_level = false

	# Network ID
	var rpc_string : String
	if is_instance_valid(is_net_valid) and is_net_valid.call():
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
			rpc_string = '[color=cornflower_blue]󰏴 %s[/color]' % ("%016X"%sender_id).right(4)

	var thread:bool = OS.get_thread_caller_id() != OS.get_main_thread_id()
	if thread: proc_fd[&'i'] = ' '
	else: proc_fd[&'i'] = ' '


	# Create the dictionary used for formatting the output
	var fd : Dictionary = {
		&'content':content,
		&'args':args,
		&'before': '',
		&'net': '      ' if net_string.is_empty() else net_string,
		&'rpc': '      ' if rpc_string.is_empty() else rpc_string,
		&'indent':indent,
		#&'icon':'',
		&'object': '',
		&'pre': '',
		&'msg': '',
		&'post': '',
		&'after': '',
	}


	if stack.size() > 1:
		fd[&'call_site'] = "[url='{source}:{line}'] [/url]".format(stack[1])
	else:
		# it would be nice to have the trigger in here.
		# like a signal, or an engine virtual etc.
		fd[&'call_site'] = "[url='{source}:{line}']󰘦 [/url]".format(stack[0])

	# Get the object based format dictionary

	if typeof(object) == TYPE_OBJECT:
		get_object_fd(object, fd)
	elif typeof(object) != TYPE_NIL:
		fd[&"name"] = type_string(typeof(object))
		fd[&"icon"] = " "
	#else:
		#fd[&"name"] = ''
		#fd[&"icon"] = ''


	fd[&'object'] = "[color={color}]{icon}{name}[/color].".format(fd)
	fd[&'object'] = ''.join([
		"[color={color}]".format(fd) if fd.has(&'color') else '',
		fd.get(&"icon", '  '),
		fd.get(&"name", ''),
		"[/color]" if fd.has(&'color') else '',
		"." if fd.has(&'icon') or fd.has(&'name') else '',
	].filter(Enetheru.lambda.not_method.bind(&'is_empty')))
	#fd[&'icon'] = '󰊕 '
	#fd[&'icon'] = ' '
	#fd[&'icon'] = '󰹤 '
	#fd[&'icon'] = '  '
	fd.erase(&'color')
	fd.erase(&'icon')

	get_msg_fd( fd )

	if fd.has(&'color'):
		fd[&'msg'] = "[color={color}]{pre}{msg}{post}[/color]".format(fd)
		if fd.has(&'icon'):
			fd[&'icon'] = "[color={color}]{icon}[/color]".format(fd)
	else:
		fd[&'msg'] = "{pre}{msg}{post}".format(fd)

	# FIXME, I can inspect the stack to see whether the previous call follows
	# on to this call  to determine which icon i should use. Because awaiting
	# breaks up the control flow into chunks, and we could be looking at
	# a completely different call stack
	var ssize : int = stack_size
	if indent.is_empty():
		if fd.has(&'icon'): ssize -= 1
		if distance > 0:
			ssize -= distance
			fd[&'flow'] = "└─" + "".rpad(distance-1, ' ') + "┐"
		else:
			fd[&'flow'] = "│"
		fd[&'indent'] = "  " + " ".repeat(maxi(0,ssize-1))
		#proc_fd['s'] = "%x" % ssize # DEBUG, useful to check stack size.

	if distance < 0:
		fd[&'flow_return'] = "┌─"+"──".repeat(abs(distance+1))+"┘"

	# Finished processing data, onto printing.
	if is_error:
		printy_error(fd, stack)
		return

	if is_warning:
		printy_warning(fd, stack)
		return


	var before : String = "{before}".format(fd)
	if not fd.has(&'icon'): fd.set(&'icon', '')

	# The left column is made of columns of data.
	var left:String# = "{proc}|{rpc}|{net}|".format( fd )
	left = '|'.join([
		"[color={c}]{i}{p}[/color]".format(proc_fd),
		fd.get(&'rpc', '     '),
		fd.get(&'net', '     '),
		fd.get(&'indent', ''),
	])
	var mid:String = "{indent}{icon}{flow}{call_site}{object}{msg}".format( fd )
	#var right : String ? would assume a column width.
	# (left + mid).rpad( width - right.size, ' ') + right

	var after : String = "{after}".format(fd)

	if distance < 0:
		print_rich(left + "{indent}{icon}{flow_return}".format(fd))

	# newline if we want to break the flow on purpose.
	if newline: print()

	if not before.is_empty(): print_rich( before )

	print_rich( left, mid )

	if not after.is_empty(): print_rich( after )


static func printy_error( fd : Dictionary, error_stack : Array ) -> void:
	var msg : String = fd[&'msg']
	var left : String# = "{proc}|{rpc}|{net}|{indent}".format( fd )
	left = '|'.join([
		"[color={c}]{i}{p}[/color]".format(proc_fd),
		fd.get(&'rpc', '     '),
		fd.get(&'net', '     '),
		fd.get(&'indent', ''),
	])
	var mid : String = "{icon}{flow}{object}{msg}".format( fd )
	printerr(Enetheru.string.strip_bbcode(left), Enetheru.string.strip_bbcode(mid))
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
	var left : String# = "{proc}|{rpc}|{net}|{indent}".format( fd )
	left = '|'.join([
		"[color={c}]{i}{p}[/color]".format(proc_fd),
		fd.get(&'rpc', '     '),
		fd.get(&'net', '     '),
		fd.get(&'indent', ''),
	])
	var mid : String = "{icon}{flow}{object}{msg}".format( fd )
	print_debug(Enetheru.string.strip_bbcode(left), Enetheru.string.strip_bbcode(mid))
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


static func print_end_frame( physics : bool = false ) -> void:
	print_end_frame_deferred.call_deferred( physics )

static func print_end_frame_deferred( physics : bool = false ) -> void:
	if reset == false: return # guard against every frame
	top_level = true # prevent a newline

	var line:String = ')('.join([
		str(Engine.get_process_frames()).lpad(5,'_'),
		("%0.1fms" % (EventBus.get_process_delta_time() * 1000)).lpad(5, '_'),
		str(Engine.get_physics_frames()).lpad(5, '_'),
		("%0.1fms" % (EventBus.get_physics_process_delta_time() * 1000)).lpad(5, '_'),
	]) + '\n'

	print( line.lpad(80, '- ' if physics else '^ ') )
	reset = false


static func get_msg_fd( fd:Dictionary ) -> void:
	var content:Variant = fd.get(&'content', null)
	var args:Array = fd.get(&'args', [])

	if not (content is String):
		# TODO I wonder if there is an automated way to pull the editor icons for a type?
		fd[&'icon'] = ' '
		fd[&'msg'] = "\n".join( [str(content)] + args )
		if content is Control: fd[&'color'] ='yellowgreen'
		elif content is Node2D: fd[&'color'] ='dodger_blue'
		elif content is Node3D: fd[&'color'] ='salmon'
		return

	# Format the string
	var msg : String = str(content) % args

	var style_key : StringName
	var prefix:String
	# Loop through the styles to try to find a match.
	for key : StringName in styles.keys():
		var stl:Dictionary = styles[key]
		if stl.has(&'RegEx'):
			var regex:RegEx = stl[&'RegEx']
			var rmatch : RegExMatch = regex.search(msg)
			if not is_instance_valid(rmatch): continue
			if rmatch.get_end() < 0: continue
			style_key = key
			if stl.has(&'trim_prefix'):
				prefix = rmatch.get_string()
		# prefix match
		elif msg.begins_with(key):
			style_key = key
			prefix = key if stl.has(&'trim_prefix') else ""
			break


	if style_key:
		fd.merge( styles.get(style_key), true )

	fd[&'msg'] = msg.trim_prefix(prefix) if prefix else msg

	is_error = is_error or fd.get(&'is_error', false)


# TODO, I want to make these type identification and formatting to be
# registered so that I can separate the printy script from my game.
# that way I can include it in sub projects, register the needed and roll.
static func get_object_fd( object:Object, fd:Dictionary ) -> void:
	# Default to the variant type.
	# TODO, I could make this a function and return icons and types
	# based on the type, but cbf right now.

	# Call all type matchers to modify the format dictionary
	for matcher : Callable in type_match:
		matcher.call( object, fd )

	if fd.get(&"name", "").is_empty():
		# Try to get the name from properties.
		if &"name" in object:
			fd[&"name"] = str(object.get(&"name"))

	if fd.get(&"name", "").is_empty():
		# Try to use script name
		var script : Script = object.get_script()
		if script: fd[&'name'] = get_script_name(script)

	# Otherwise default to its variant type.
	if fd.get(&"name", "").is_empty():
		fd[&"name"] = type_string(typeof(object))
		fd[&"icon"] = " "

	if fd.get(&"color", "").is_empty():
		var color : Color = header_color.get_or_add( fd[&"name"], Enetheru.colour.random() )
		fd[&'color'] = color.to_html()


static func get_proc_fd() -> Dictionary:
	return {
		&'c':Color(0.4,0.4,0.4).to_html(),
		&'i':' ',
		&'p':"%05d" % proc_id }


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
