@tool
extends EditorPlugin

const Self = preload('uid://setvleg6sni3')

# TODO make the plugin more bare bones that check for dependencies before
# loading, that way we might be able to devise a way to automatically clone
# and update plugins like the vim lazy codebase does.

const Print = preload("uid://babswmnh2kosn")

const SettingsHalpr = preload("uid://o5djwaewipdy")
var settings_hlp:SettingsHalpr

const Author:String = "Samuel Nicholas (Enetheru)"
const author:String = "enetheru"
const PluginName:String = "EditorTweaks"
const plugin_name:String = "editor_tweaks"

# ██████  ██████   ██████  ██████  ███████ ██████  ████████ ██ ███████ ███████ #
# ██   ██ ██   ██ ██    ██ ██   ██ ██      ██   ██    ██    ██ ██      ██      #
# ██████  ██████  ██    ██ ██████  █████   ██████     ██    ██ █████   ███████ #
# ██      ██   ██ ██    ██ ██      ██      ██   ██    ██    ██ ██           ██ #
# ██      ██   ██  ██████  ██      ███████ ██   ██    ██    ██ ███████ ███████ #
func                        ________PROPERTIES_______              ()->void:pass

static var _prime:Self
static var plugin_dir:String
static var plugin_path:String

var opts:TweakOptions

var editorlog_font_names : PackedStringArray = [
	'output_source',
	'output_source_bold',
	'output_source_italic',
	'output_source_bold_italic',
	'output_source_mono']

#             ███████ ██    ██ ███████ ███    ██ ████████ ███████              #
#             ██      ██    ██ ██      ████   ██    ██    ██                   #
#             █████   ██    ██ █████   ██ ██  ██    ██    ███████              #
#             ██       ██  ██  ██      ██  ██ ██    ██         ██              #
#             ███████   ████   ███████ ██   ████    ██    ███████              #
func                        __________EVENTS_________              ()->void:pass

func _on_editorlog_link_clicked( meta : Variant ) -> void:
	var url : String = meta
	if not url: return
	if not "://" in url:
		Print.plog(Print.LogLevel.DEFAULT, "url: %s" % url)
		return
	if url.begins_with("res://"):
		var parts : PackedStringArray = url.split(':')
		url = ":".join([parts[0], parts[1]])
		var line : int = 0
		var col : int = 0
		match url.get_extension():
			"gd":
				if parts.size() > 2: line = parts[2].to_int()
				if parts.size() > 3: col = parts[3].to_int()
				var script : Script = load(url)
				EditorInterface.edit_script(script, line, col)
			_:
				EditorInterface.edit_resource(load(url))
	else:
		Print.plog(Print.LogLevel.DEFAULT, "url: %s" % url)
		@warning_ignore('return_value_discarded')
		OS.shell_open( url )

#TODO  I want a setting path in here too so that if a setting fails, it can be reverted.
func _on_project_settings_changed(
			setting_name:String, setting_value:Variant ) -> void:
	Print.plog(Print.LogLevel.TRACE, ''.join([setting_name, ':', setting_value]))
	var b:bool
	match typeof(setting_value):
		TYPE_BOOL: b = setting_value
	match setting_name:
		"experimental" when setting_value == true: enable_experimental_features()
		"experimental": disable_experimental_features()
		"verbosity": Print._default_level = setting_value
		"enable_ligatures": editorlog_ligatures_toggle(b)
		"add_rotate_bbcode_effect": editorlog_rotate_toggle(b)
		"enable_output_search_bar": editorlog_search_toggle(b)
		"enable_clickable_url_links": editorlog_url_links_set(b)
		"use_monospace_glyphs": monospace_glyphs_toggle(b)
		"add_rich_paste": editorlog_rich_paste_toggle(b)
		"enable_linespacing_tweaks": linespacing_toggle(b)
		"adjust_linespacing_above" when opts.enable_linespacing_tweaks:
			linespacing_toggle(opts.enable_linespacing_tweaks)
		"adjust_linespacing_below" when opts.enable_linespacing_tweaks:
			linespacing_toggle(opts.enable_linespacing_tweaks)
		"make_method_trace_line": make_method_trace_line_toggle(b)


#      ██████  ██    ██ ███████ ██████  ██████  ██ ██████  ███████ ███████     #
#     ██    ██ ██    ██ ██      ██   ██ ██   ██ ██ ██   ██ ██      ██          #
#     ██    ██ ██    ██ █████   ██████  ██████  ██ ██   ██ █████   ███████     #
#     ██    ██  ██  ██  ██      ██   ██ ██   ██ ██ ██   ██ ██           ██     #
#      ██████    ████   ███████ ██   ██ ██   ██ ██ ██████  ███████ ███████     #
func                        ________OVERRIDES________              ()->void:pass

func _init() -> void:
	Print.ptrace()
	_prime = self
	name = PluginName
	plugin_path = get_script().resource_path
	plugin_dir = plugin_path.get_base_dir()

	opts = TweakOptions.new()
	settings_hlp = SettingsHalpr.new(opts, plugin_name)

	@warning_ignore("return_value_discarded")
	settings_hlp.settings_changed.connect(_on_project_settings_changed)

	icons_dump = Self.dump_icons
	colours_dump = Self.dump_colours

	Print.plog( Print.LogLevel.DEBUG, "%s._init() - Completed" % name )


func _enter_tree() -> void:
	Print._default_level = opts.verbosity
	Print.ptrace()
	if opts.enable_ligatures:           editorlog_ligatures_toggle(opts.enable_ligatures)
	if opts.add_rotate_bbcode_effect:   editorlog_rotate_toggle(opts.add_rotate_bbcode_effect)
	if opts.enable_output_search_bar:   editorlog_search_toggle(opts.enable_output_search_bar)
	if opts.enable_clickable_url_links: editorlog_url_links_set(opts.enable_clickable_url_links)
	if opts.use_monospace_glyphs:       monospace_glyphs_toggle(opts.use_monospace_glyphs)
	if opts.add_rich_paste:             editorlog_rich_paste_toggle(opts.add_rich_paste)
	if opts.enable_linespacing_tweaks:  linespacing_toggle(opts.enable_linespacing_tweaks)
	if opts.make_method_trace_line:     make_method_trace_line_toggle(opts.make_method_trace_line)
	if opts.experimental:               enable_experimental_features()


func _exit_tree() -> void:
	Print.ptrace()
	if opts.experimental:
		disable_experimental_features()

func _get_plugin_name() -> String:
	Print.ptrace()
	return plugin_name


#func _get_plugin_icon() -> Texture2D:
	#Print.plog( Print.LogLevel.TRACE, "%s._get_plugin_icon()" % name )
	#return ICON_BW_TINY


func _enable_plugin() -> void:
	Print.ptrace()


func _disable_plugin() -> void:
	Print.ptrace()


#         ███    ███ ███████ ████████ ██   ██  ██████  ██████  ███████         #
#         ████  ████ ██         ██    ██   ██ ██    ██ ██   ██ ██              #
#         ██ ████ ██ █████      ██    ███████ ██    ██ ██   ██ ███████         #
#         ██  ██  ██ ██         ██    ██   ██ ██    ██ ██   ██      ██         #
#         ██      ██ ███████    ██    ██   ██  ██████  ██████  ███████         #
func                        _________METHODS_________              ()->void:pass


func enable_experimental_features() -> void:
	Print.plog( Print.LogLevel.DEBUG, "enable_experimental_features" )


func disable_experimental_features() -> void:
	Print.plog( Print.LogLevel.DEBUG, "disable_experimental_features" )


static var editor_log:Control
static func get_editorlog_4_5() -> BoxContainer:
	Print.ptrace()
	if is_instance_valid(editor_log): return editor_log
	var base_control : Control = EditorInterface.get_base_control()
	editor_log = base_control.find_child("*EditorLog*", true, false)
	if is_instance_valid(editor_log): return editor_log
	push_error("Unable to find EditorLog")
	return null


static func get_editorlog_4_6() -> Control:
	Print.ptrace()
	if is_instance_valid(editor_log): return editor_log
	var base_control : Control = EditorInterface.get_base_control()
	var maybe:Control = base_control.find_child("*Output*", true, false)
	if is_instance_valid(maybe):
		editor_log = maybe
		return maybe
	push_error("Unable to find EditorLog")
	return null


static func get_editorlog() -> Control:
	Print.ptrace()
	var version:Dictionary = Engine.get_version_info()
	if version.major >= 4:
		if version.minor >= 6:
			return get_editorlog_4_6()
		if version.minor < 6:
			return get_editorlog_4_5()
	return null


static func get_output_rtl() -> RichTextLabel:
	Print.ptrace()
	return null
	#if is_instance_valid(output_rtl): return output_rtl
	#if is_instance_valid(get_editorlog()):
		#output_rtl = editor_log.find_child("*Rich*", true, false)
		#if is_instance_valid(output_rtl):return output_rtl
		#push_error("Unable to find RichTextLabel in EditorLog's children")
	#return null

static func get_code_font() -> FontVariation:
	Print.ptrace()
	var editor_theme:Theme = EditorInterface.get_editor_theme()
	var code_edit_font:FontVariation = editor_theme.get_font("font", "CodeEdit")
	if is_instance_valid(code_edit_font): return code_edit_font
	Print.plog(Print.LogLevel.ERROR, "Unable to find CodeEdit font in editor theme")
	return null


#        ██████  ██████  ██████  ███████     ███████ ██████  ██ ████████       #
#       ██      ██    ██ ██   ██ ██          ██      ██   ██ ██    ██          #
#       ██      ██    ██ ██   ██ █████ █████ █████   ██   ██ ██    ██          #
#       ██      ██    ██ ██   ██ ██          ██      ██   ██ ██    ██          #
#        ██████  ██████  ██████  ███████     ███████ ██████  ██    ██          #
func                        ________CODE_EDIT________              ()->void:pass

func                        __Line_Spacing___________              ()->void:pass
#region Line Spacing
#MARK: Line Spacing
##                                                      [br]
## │ _    _            ___               _              [br]
## │| |  (_)_ _  ___  / __|_ __  __ _ __(_)_ _  __ _    [br]
## │| |__| | ' \/ -_) \__ \ '_ \/ _` / _| | ' \/ _` |   [br]
## │|____|_|_||_\___| |___/ .__/\__,_\__|_|_||_\__, |   [br]
## ╰──────────────────────|_|──────────────────|___/─── [br]
## Line Spacing By-Line
##
## Line Spacing Description
var was_enabled:bool = false
func linespacing_toggle( toggle_on:bool ) -> void:
	Print.ptrace()
	if toggle_on == was_enabled: return
	was_enabled = toggle_on
	var code_font:FontVariation = get_code_font()
	if not code_font:
		Print.plog(Print.LogLevel.ERROR, "Unable to get font:CodeEdit from editor theme.")
		return
	code_font.spacing_top = opts.adjust_linespacing_above if toggle_on else -1
	code_font.spacing_bottom = opts.adjust_linespacing_below if toggle_on else -1

#endregion Line Spacing

func                        __MethodTraceArgs________              ()->void:pass
#region MethodTraceArgs
#MARK: MethodTraceArgs
##                                                                           [br]
## │ __  __     _   _            _ _____                  _                  [br]
## │|  \/  |___| |_| |_  ___  __| |_   _| _ __ _ __ ___  /_\  _ _ __ _ ___   [br]
## │| |\/| / -_)  _| ' \/ _ \/ _` | | || '_/ _` / _/ -_)/ _ \| '_/ _` (_-<   [br]
## │|_|  |_\___|\__|_||_\___/\__,_| |_||_| \__,_\__\___/_/ \_\_| \__, /__/   [br]
## ╰─────────────────────────────────────────────────────────────|___/────── [br]
## MethodTraceArgs By-Line
##
## MethodTraceArgs Description

var method_trace_args_factory:Object
var method_trace_args_cm:EditorContextMenuPlugin

func make_method_trace_line_toggle( toggled_on:bool ) -> void:
	Print.ptrace()
	if toggled_on:
		if not is_instance_valid(method_trace_args_factory):
			var script_path:String = plugin_dir.path_join("scripts/method_trace_args.gd")
			method_trace_args_factory = load(script_path)
		if not is_instance_valid(method_trace_args_factory):
			Print.plog(Print.LogLevel.ERROR, "Failure to create MethodTraceArgs factory script instance")
			return
		if is_instance_valid(method_trace_args_cm): return
		Print.plog(Print.LogLevel.DEFAULT, "Creating MethodTraceArgs ContextMenuPlugin")
		method_trace_args_cm = method_trace_args_factory.call(&'create_method_trace_args_cm')
		if not is_instance_valid(method_trace_args_cm):
			Print.plog(Print.LogLevel.ERROR, "Creation of MethodTraceArgs ContextMenuPlugin Failed")
			return
		add_context_menu_plugin(
			EditorContextMenuPlugin.ContextMenuSlot.CONTEXT_SLOT_SCRIPT_EDITOR_CODE,
			method_trace_args_cm )
	else:
		if is_instance_valid(method_trace_args_cm):
			Print.plog(Print.LogLevel.DEFAULT, "Remove MethodTraceArgs ContextMenuPlugin")
			remove_context_menu_plugin( method_trace_args_cm )
			method_trace_args_cm = null

#endregion MethodTraceArgs


# ███████ ██████  ██ ████████  ██████  ██████        ██       ██████   ██████  #
# ██      ██   ██ ██    ██    ██    ██ ██   ██       ██      ██    ██ ██       #
# █████   ██   ██ ██    ██    ██    ██ ██████  █████ ██      ██    ██ ██   ███ #
# ██      ██   ██ ██    ██    ██    ██ ██   ██       ██      ██    ██ ██    ██ #
# ███████ ██████  ██    ██     ██████  ██   ██       ███████  ██████   ██████  #
func                        ________EDITOR_LOG_______              ()->void:pass

func                        __Ligatures______________              ()->void:pass
#region Ligatures
#MARK: Ligatures
##                                           [br]
## │ _    _           _                      [br]
## │| |  (_)__ _ __ _| |_ _  _ _ _ ___ ___   [br]
## │| |__| / _` / _` |  _| || | '_/ -_|_-<   [br]
## │|____|_\__, \__,_|\__|\_,_|_| \___/__/   [br]
## ╰───────|___/──────────────────────────── [br]
## Ligatures By-Line
##
## Ligatures Description
func editorlog_ligatures_toggle( toggled_on : bool ) -> void:
	Print.ptrace()
	if toggled_on: Print.plog(Print.LogLevel.DEFAULT, "Enable EditorLog Ligatures")
	else: Print.plog(Print.LogLevel.DEFAULT, "Disable EditorLog Ligatures")
	var editor_theme:Theme = EditorInterface.get_editor_theme()
	for font_name in editorlog_font_names:
		var font : FontVariation = editor_theme.get_font(font_name, "EditorFonts")
		font.opentype_features = {1667329140: 1 if toggled_on else 0}

#endregion Ligatures


func                        __BBCode_Rotate__________              ()->void:pass
#region BBCode Rotate
#MARK: BBCode Rotate
## │ ___ ___  ___         _       ___     _        _          [br]
## │| _ ) _ )/ __|___  __| |___  | _ \___| |_ __ _| |_ ___    [br]
## │| _ \ _ \ (__/ _ \/ _` / -_) |   / _ \  _/ _` |  _/ -_)   [br]
## │|___/___/\___\___/\__,_\___| |_|_\___/\__\__,_|\__\___|   [br]
## ╰───────────────────────────────────────────────────────── [br]
## BBCode Rotate By-Line
##
## BBCode Rotate Description
# var sideways_effect : RichTextEffect = preload('sideways_effect.tres')

func editorlog_rotate_toggle( _toggled_on : bool ) -> void:
	Print.ptrace()
	# if not is_instance_valid(output_rtl): return
	# if not is_instance_valid(sideways_effect): return

	# if toggled_on:
		# Print.plog(Print.LogLevel.DEFAULT, "Enable EditorLog Sideways Text Effect")
		# output_rtl.install_effect(sideways_effect)
	# else:
		# Print.plog(Print.LogLevel.DEFAULT, "Disable EditorLog Sideways Text Effect")
		# if sideways_effect in output_rtl.custom_effects:
			# output_rtl.custom_effects.erase(sideways_effect)
#endregion BBCode Rotate


func                        __Search_Bar_____________              ()->void:pass
#region Search Bar
#MARK: Search Bar
## │ ___                  _      ___              [br]
## │/ __| ___ __ _ _ _ __| |_   | _ ) __ _ _ _    [br]
## │\__ \/ -_) _` | '_/ _| ' \  | _ \/ _` | '_|   [br]
## │|___/\___\__,_|_| \__|_||_| |___/\__,_|_|     [br]
## ╰───────────────────────────────────────────── [br]
## Search Bar By-Line
##
## Search Bar Description
func editorlog_search_toggle( _toggled_on : bool ) -> void:
	Print.ptrace()
	# if not is_instance_valid(editor_log): return
	# EditorLog.toggle_search_bar(editor_log, toggled_on)

#endregion Search Bar

func                        __Clickable_Links________              ()->void:pass
#region Clickable Links
#MARK: Clickable Links
## │  ___ _ _    _        _    _       _    _      _          [br]
## │ / __| (_)__| |____ _| |__| |___  | |  (_)_ _ | |__ ___   [br]
## │| (__| | / _| / / _` | '_ \ / -_) | |__| | ' \| / /(_-<   [br]
## │ \___|_|_\__|_\_\__,_|_.__/_\___| |____|_|_||_|_\_\/__/   [br]
## ╰───────────────────────────────────────────────────────── [br]
## Clickable Links By-Line
##
## Clickable Links Description
# TODO Move code to editorlog helper class
# TODO create a registry for URL handlers that can be updated in the settings.
var output_rtl_og_conn : Array

func editorlog_url_links_set( _toggle_on:bool ) -> void:
	Print.ptrace()
	#if toggle_on: editorlog_url_links_enabled()
	#else: editorlog_url_links_disabled()


func editorlog_url_links_enabled() -> void:
	Print.ptrace()
	var output_rtl:RichTextLabel = get_output_rtl()
	if not is_instance_valid( output_rtl ): return

	# output_rtl.autowrap_mode = TextServer.AUTOWRAP_OFF
	# output_rtl.autowrap_trim_flags = TextServer.BREAK_NONE

	# Remove default annoying URL handling.
	output_rtl_og_conn = output_rtl.meta_clicked.get_connections()
	for c : Dictionary  in output_rtl.meta_clicked.get_connections():
		@warning_ignore('unsafe_call_argument')
		output_rtl.meta_clicked.disconnect( c.get('callable') )

	@warning_ignore_start('return_value_discarded')
	output_rtl.meta_clicked.connect(_on_editorlog_link_clicked, CONNECT_DEFERRED)
	@warning_ignore_restore('return_value_discarded')


func editorlog_url_links_disabled() -> void:
	var output_rtl:RichTextLabel = get_output_rtl()
	if not is_instance_valid( output_rtl ): return
	Print.ptrace()
	if output_rtl.meta_clicked.is_connected(_on_editorlog_link_clicked):
		output_rtl.meta_clicked.disconnect(_on_editorlog_link_clicked)
	for c : Dictionary in output_rtl_og_conn:
		@warning_ignore('unsafe_call_argument', 'return_value_discarded')
		output_rtl.meta_clicked.connect( c.get('callable') )

#endregion Clickable Links


func                        __RichPaste______________              ()->void:pass
#region RichPaste
#MARK: RichPaste

## │ ___ _    _    ___         _          [br]
## │| _ (_)__| |_ | _ \__ _ __| |_ ___    [br]
## │|   / / _| ' \|  _/ _` (_-<  _/ -_)   [br]
## │|_|_\_\__|_||_|_| \__,_/__/\__\___|   [br]
## ╰───────────────────────────────────── [br]
##
## TODO Change this to DocPaste
## Because i have to remove newlines and comment strings
## CONTEXT_SLOT_SCRIPT_EDITOR_CODE[br]
## Context menu of Script editor's code editor.

var rich_paste_factory:Object
var rich_paste_cm:EditorContextMenuPlugin

func editorlog_rich_paste_toggle( toggled_on : bool ) -> void:
	Print.ptrace()
	if toggled_on:
		if not is_instance_valid(rich_paste_factory):
			var rich_paste_script_path:String = plugin_dir.path_join("scripts/rich_paste.gd")
			rich_paste_factory = load(rich_paste_script_path)
		# if still not
		if not is_instance_valid(rich_paste_factory):
			Print.plog(Print.LogLevel.ERROR, "Failure to create rich paste factory script instance")
			return
		Print.plog(Print.LogLevel.DEFAULT, "Creating Rich Paste ContextMenuPlugin")
		rich_paste_cm = rich_paste_factory.call(&'create_rich_paste_cm')
		if not is_instance_valid(rich_paste_cm):
			Print.plog(Print.LogLevel.ERROR, "Creation of Rich Paste ContextMenuPlugin Failed")
			return
		add_context_menu_plugin(
			EditorContextMenuPlugin.ContextMenuSlot.CONTEXT_SLOT_SCRIPT_EDITOR_CODE,
			rich_paste_cm )
	else:
		if is_instance_valid(rich_paste_cm):
			Print.plog(Print.LogLevel.DEFAULT, "Remve Rich Paste ContextMenuPlugin")
			remove_context_menu_plugin( rich_paste_cm )
			rich_paste_cm = null

#endregion RichPaste


func                        __Monospaced_Font________              ()->void:pass
#region Monospaced Font
#MARK: Monospaced Font
##                                                                     [br]
## │ __  __                                      _   ___        _      [br]
## │|  \/  |___ _ _  ___ ____ __  __ _ __ ___ __| | | __|__ _ _| |_    [br]
## │| |\/| / _ \ ' \/ _ (_-< '_ \/ _` / _/ -_) _` | | _/ _ \ ' \  _|   [br]
## │|_|  |_\___/_||_\___/__/ .__/\__,_\__\___\__,_| |_|\___/_||_\__|   [br]
## ╰───────────────────────|_|──────────────────────────────────────── [br]
## Monospaced Font By-Line
##
## Monospaced Font Description
func monospace_glyphs_toggle( toggled_on : bool ) -> void:
	Print.ptrace()
	var output_rtl:RichTextLabel = get_output_rtl()
	if not is_instance_valid(output_rtl): return
	if toggled_on:
		Print.plog(Print.LogLevel.DEFAULT, "Enable Monospace Font Glyphs Fixes")
		Print.plog(Print.LogLevel.DEFAULT, "object instance ID: %X" % get_instance_id() )
		#var font : Font = code_edit_font.base_font
		#print( code_edit_font.get_supported_chars())
		#print(JSON.stringify(font.get_supported_feature_list(), "  ", false) )
		#print(JSON.stringify(font.get_supported_variation_list(), "  ", false) )
		#print( font.has_char("⣿".to_utf32_buffer()[0]))
		#print( font.has_char(" ".to_utf32_buffer()[0]))
#
		#var ts := TextServerManager.get_primary_interface()
#
		#for font_name in editorlog_font_names:
			#var font_variation : FontVariation = editor_theme.get_font(font_name, "EditorFonts")
			#var font : Font = font_variation.base_font
#
			#var rid : RID
			#for r : RID in font.get_rids():
				#if ts.font_has_char(r, 0x28FF):
					#rid=r
					#print(ts.font_get_name(r))
					#break
			#if not rid.is_valid(): return
			#print(ts.font_get_name(rid))
#
			#ts.font_set_fixed_size(rid, 18)
			#print( ts.font_get_fixed_size(rid))
#
			#ts.font_set_fixed_size_scale_mode(rid, TextServer.FIXED_SIZE_SCALE_ENABLED)


			#print( ts.font_get_glyph_size(rid,Vector2i.ONE, 0x2800-0x28FF) )


			#print( "has ⣿:", font.has_char(ord("⣿")))
			#print( "has \u2800:", font.has_char(0x2800))


	else:
		Print.plog(Print.LogLevel.DEFAULT, "Disable Monospace Font Glyphs Fixes")

#endregion Monospaced Font

#                    ██  ██████  ██████  ███    ██ ███████                     #
#                    ██ ██      ██    ██ ████   ██ ██                          #
#                    ██ ██      ██    ██ ██ ██  ██ ███████                     #
#                    ██ ██      ██    ██ ██  ██ ██      ██                     #
#                    ██  ██████  ██████  ██   ████ ███████                     #
func                        __________ICONS__________              ()->void:pass

#@export_tool_button("Dump Icons to EditorLog")
@export_custom( PROPERTY_HINT_TOOL_BUTTON, "Dump Editor Icons",
	PROPERTY_USAGE_EDITOR_BASIC_SETTING
	| PROPERTY_USAGE_GROUP)
var icons_dump : Callable = dump_icons

static func dump_icons() -> void:
	var editor_theme:Theme = EditorInterface.get_editor_theme()
	var output_rtl:RichTextLabel = get_output_rtl()
	var lines : Array[String] = [
		"",
		Enetheru.bbcode.h1("Icons", editor_theme.default_font_size + 2),
		"Grouped by icon_type" ]

	print_rich("\n".join(lines)); lines = []
	for icon_type : String in editor_theme.get_icon_type_list():
		lines.append(Enetheru.bbcode.h2(icon_type, editor_theme.default_font_size + 2))
		lines.append("var icon : Texture2D = editor_theme.get_icon( <icon_name>, \"%s\" )" % icon_type)
		lines.append("")
		print_rich("\n".join(lines)); lines = []
		for icon_name : String in editor_theme.get_icon_list( icon_type ):
			var editor_icon : Texture2D = editor_theme.get_icon( icon_name, icon_type )
			if editor_icon.get_width() == 0: continue

			output_rtl.add_image(editor_icon, 32, 32 )
			output_rtl.append_text(" (%d) %s %s" % [
				editor_icon.get_reference_count(), icon_name, editor_icon.get_size()])
			print_rich("")


#          ██████  ██████  ██       ██████  ██    ██ ██████  ███████           #
#         ██      ██    ██ ██      ██    ██ ██    ██ ██   ██ ██                #
#         ██      ██    ██ ██      ██    ██ ██    ██ ██████  ███████           #
#         ██      ██    ██ ██      ██    ██ ██    ██ ██   ██      ██           #
#          ██████  ██████  ███████  ██████   ██████  ██   ██ ███████           #
func                        _________COLOURS_________              ()->void:pass

# TODO dump named colours too.

#@export_tool_button("Dump Icons to EditorLog")
@export_custom( PROPERTY_HINT_TOOL_BUTTON, "Dump Editor Colours",
	PROPERTY_USAGE_EDITOR_BASIC_SETTING
	| PROPERTY_USAGE_GROUP)
var colours_dump : Callable = dump_colours


static func dump_colours() -> void:
	var editor_theme:Theme = EditorInterface.get_editor_theme()
	var lines : Array[String] = [
		"",
		Enetheru.bbcode.h1("Colours", editor_theme.default_font_size + 2),
		"Grouped by color_type" ]

	print_rich("\n".join(lines)); lines = [""]

	for color_type : String in editor_theme.get_color_type_list():
		lines = [
			Enetheru.bbcode.h2(color_type, editor_theme.default_font_size + 2),
			"var color : Color = editor_theme.get_color( <color_name>, \"%s\" )" % color_type,
			"",]
		for color_name : String in editor_theme.get_color_list( color_type ):
			var editor_color : Color = editor_theme.get_color( color_name, color_type )
			lines.append("".join([
				"[font_size=26] ",
				"[bgcolor=%s]" % editor_color.to_html(),
				editor_color.to_html(),
				"[/bgcolor]",
				"[/font_size] ",
				color_name
				]))
		print_rich("\n".join(lines)); lines = []
