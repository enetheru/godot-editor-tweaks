extends Object

##[codeblock lang=text]
##│   _       _       _              _   ___             _
##│  /_\ _  _| |_ ___| |___  __ _ __| | | _ \___ __ _ __| |_  _
##│ / _ \ || |  _/ _ \ / _ \/ _` / _` | |   / -_) _` / _` | || |
##│/_/ \_\_,_|\__\___/_\___/\__,_\__,_| |_|_\___\__,_\__,_|\_, |
##╰────────────────────────────────────────────────────────|__/───
##[/codeblock] Await a project autoload from [code]_static_init[/code].
##
## Godot has no autoloads-ready signal. The handshake is a user-signal on
## [Engine], named per autoload. Autoloads expose a thin facade; this helper
## owns [method when_autoload_ready] and [method emit_autoload_ready].
## Pass the autoload being waited on, not a different singleton.


## Await until [param autoload_node] has run [method Node._ready].
##
## Safe from [code]_static_init[/code]: creates [param signal_name] on Engine
## if needed, returns immediately when the autoload node is already ready,
## otherwise waits for [method emit_autoload_ready].
static func when_autoload_ready( autoload_node:Node, signal_name:StringName ) -> void:
	_ensure_engine_signal(signal_name)
	if is_instance_valid(autoload_node) \
	and autoload_node.is_node_ready():
		return
	await Signal(Engine, signal_name)
	# TODO: What if I hand the signal back to the caller,
	# let them either await it, or connect to it?


## Create [param signal_name] on Engine if missing.
static func _ensure_engine_signal( signal_name:StringName ) -> void:
	if not Engine.has_user_signal( signal_name ):
		Engine.add_user_signal( signal_name )


## Announce that an autoload has run [method Node._ready].
## Returns the [enum @GlobalScope.Error] from [method Object.emit_signal].
static func emit_autoload_ready( signal_name:StringName ) -> Error:
	_ensure_engine_signal( signal_name )
	return Engine.emit_signal( signal_name )
