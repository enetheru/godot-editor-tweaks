@tool
extends EditorPlugin
## Kitchen-sink editor tweaks: Output log, code editor, settings bridge, logging.
##
##[br][color=tomato]FIXME[/color]: Plugin has grown past one concern. Split into
## focused modules (log discovery, Output log search, code-editor menus,
## settings, logging) with this file as a thin orchestrator.
##[br][color=goldenrod]TODO[/color]: Dependency check before load (lazy plugin
## bootstrap, vim-lazy style).
##[br][color=goldenrod]TODO[/color]: monospace glyphs still stubbed.

#region trace
const Log = preload( "logging.gd" )
static var class_lvl:int = Log.Level.SILENT
@export_enum( "SILENT:0", "CRITICAL:1", "ERROR:3", "WARNING:7",
		"NOTICE:15", "INFO:31", "DEBUG:63", "TRACE:127", "MASK:255" )
var local_lvl:int = Log.Level.SILENT
func trace( args:Dictionary = {}, object:Object = self,
			stack:Array = Log.get_stack_popped( 1 ) ) -> void:
	Log.trace( args, object, stack )
#endregion

const Self = preload("uid://setvleg6sni3")

const Util = preload("uid://blodm3bymovpt")


const ExportPlugin = preload("uid://dbn53jnkd5w36")

const EditorIntegration = preload("uid://cl0kj8qvnhfam")

## Output-log search bar (no class_name — call statics on the script).
const EditorLogSearch = preload("uid://bqnxqo33qkevi")

const SettingsHalpr = preload("uid://o5djwaewipdy")
var settings_hlp:SettingsHalpr

const Author:String = "Samuel Nicholas (Enetheru)"
const author:String = "enetheru"           # snake_case tag
const PluginName:String = "EditorTweaks"   # Capitalised
const plugin_name:String = "editor_tweaks" # snake case

# ██████  ██████   ██████  ██████  ███████ ██████  ████████ ██ ███████ ███████ #
# ██   ██ ██   ██ ██    ██ ██   ██ ██      ██   ██    ██    ██ ██      ██      #
# ██████  ██████  ██    ██ ██████  █████   ██████     ██    ██ █████   ███████ #
# ██      ██   ██ ██    ██ ██      ██      ██   ██    ██    ██ ██           ██ #
# ██      ██   ██  ██████  ██      ███████ ██   ██    ██    ██ ███████ ███████ #
func                        ________PROPERTIES_______              ()->void:pass

static var _prime:Self
static var plugin_dir:String
static var plugin_path:String

var export_plugin:EditorExportPlugin

# TODO: should opts be static / shared via a single resource owner?
var opts:TweakOptions

var editorlog_font_names:PackedStringArray = [
	"output_source",
	"output_source_bold",
	"output_source_italic",
	"output_source_bold_italic",
	"output_source_mono"]

#             ███████ ██    ██ ███████ ███    ██ ████████ ███████              #
#             ██      ██    ██ ██      ████   ██    ██    ██                   #
#             █████   ██    ██ █████   ██ ██  ██    ██    ███████              #
#             ██       ██  ██  ██      ██  ██ ██    ██         ██              #
#             ███████   ████   ███████ ██   ████    ██    ███████              #
func                        __________EVENTS_________              ()->void:pass

func _on_editorlog_link_clicked( meta:Variant ) -> void:
	var url:String = str(meta)
	if url.is_empty():
		return
	if not "://" in url:
		Log.lvl(Log.Level.NOTICE, "url: %s" % url, self)
		return
	if url.begins_with("res://"):
		# res://path:line:col — path may contain ":" only after scheme.
		var parts:PackedStringArray = url.split(":")
		url = ":".join([parts[0], parts[1]])
		var line:int = 0
		var col:int = 0
		match url.get_extension():
			"gd":
				if parts.size() > 2:
					line = parts[2].to_int()
				if parts.size() > 3:
					col = parts[3].to_int()
				var script:Script = load(url)
				EditorInterface.edit_script(script, line, col)
			_:
				EditorInterface.edit_resource(load(url))
	else:
		Log.lvl(Log.Level.NOTICE, "url: %s" % url, self)
		@warning_ignore("return_value_discarded")
		OS.shell_open(url)


# TODO: include setting path so a bad write can be reverted.
func _on_project_settings_changed(
			setting_name:String, setting_value:Variant ) -> void:
	Log.lvl(Log.Level.TRACE, "".join([setting_name, ":", setting_value]), self)
	match setting_name:
		"experimental" when setting_value == true:
			enable_experimental_features()
		"experimental":
			disable_experimental_features()
		"enable_ligatures" when setting_value is bool:
			var b:bool = setting_value
			editorlog_ligatures_toggle(b)
		"add_rotate_bbcode_effect" when setting_value is bool:
			var b:bool = setting_value
			editorlog_rotate_toggle(b)
		"enable_output_search_bar" when setting_value is bool:
			var b:bool = setting_value
			editorlog_search_toggle(b)
		"enable_clickable_url_links" when setting_value is bool:
			var b:bool = setting_value
			editorlog_url_links_set(b)
		"use_monospace_glyphs" when setting_value is bool:
			var b:bool = setting_value
			monospace_glyphs_toggle(b)
		"add_rich_paste" when setting_value is bool:
			var b:bool = setting_value
			editorlog_rich_paste_toggle(b)
		"enable_linespacing_tweaks" when setting_value is bool:
			var b:bool = setting_value
			linespacing_toggle(b)
		"adjust_linespacing_above" when opts.enable_linespacing_tweaks:
			linespacing_toggle(opts.enable_linespacing_tweaks)
		"adjust_linespacing_below" when opts.enable_linespacing_tweaks:
			linespacing_toggle(opts.enable_linespacing_tweaks)
		"make_method_trace_line" when setting_value is bool:
			var b:bool = setting_value
			make_method_trace_line_toggle(b)


#      ██████  ██    ██ ███████ ██████  ██████  ██ ██████  ███████ ███████     #
#     ██    ██ ██    ██ ██      ██   ██ ██   ██ ██ ██   ██ ██      ██          #
#     ██    ██ ██    ██ █████   ██████  ██████  ██ ██   ██ █████   ███████     #
#     ██    ██  ██  ██  ██      ██   ██ ██   ██ ██ ██   ██ ██           ██     #
#      ██████    ████   ███████ ██   ██ ██   ██ ██ ██████  ███████ ███████     #
func                        ________OVERRIDES________              ()->void:pass

func _init() -> void:
	_prime = self
	name = PluginName
	plugin_path = get_script().resource_path
	plugin_dir = plugin_path.get_base_dir()

	opts = load(plugin_dir.path_join("res/tweak_opts.tres"))
	default_tweak_options(opts)
	settings_hlp = SettingsHalpr.new(opts, plugin_name)

	@warning_ignore("return_value_discarded")
	settings_hlp.settings_changed.connect(_on_project_settings_changed)

	icons_dump = Self.dump_icons
	colours_dump = Self.dump_colours

	Log.lvl(Log.Level.DEBUG, "%s._init() - Completed" % name, self)


func _enter_tree() -> void:
	trace()
	if opts.enable_ligatures:           editorlog_ligatures_toggle(opts.enable_ligatures)
	if opts.add_rotate_bbcode_effect:   editorlog_rotate_toggle(opts.add_rotate_bbcode_effect)
	if opts.enable_output_search_bar:   editorlog_search_toggle(opts.enable_output_search_bar)
	if opts.enable_clickable_url_links: editorlog_url_links_set(opts.enable_clickable_url_links)
	if opts.use_monospace_glyphs:       monospace_glyphs_toggle(opts.use_monospace_glyphs)
	if opts.add_rich_paste:             editorlog_rich_paste_toggle(opts.add_rich_paste)
	if opts.enable_linespacing_tweaks:  linespacing_toggle(opts.enable_linespacing_tweaks)
	if opts.make_method_trace_line:     make_method_trace_line_toggle(opts.make_method_trace_line)
	if opts.experimental:               enable_experimental_features()

	# Export Plugin
	export_plugin = ExportPlugin.new()
	add_export_plugin(export_plugin)


func _exit_tree() -> void:
	trace()
	if opts.experimental:
		disable_experimental_features()

	if export_plugin:
		remove_export_plugin(export_plugin)

func _get_plugin_name() -> String:
	trace()
	return plugin_name


#func _get_plugin_icon() -> Texture2D:
	#Log.lvl( Log.Level.TRACE, "%s._get_plugin_icon()" % name, self )
	#return ICON_BW_TINY


func _enable_plugin() -> void:
	trace()


func _disable_plugin() -> void:
	trace()


#         ███    ███ ███████ ████████ ██   ██  ██████  ██████  ███████         #
#         ████  ████ ██         ██    ██   ██ ██    ██ ██   ██ ██              #
#         ██ ████ ██ █████      ██    ███████ ██    ██ ██   ██ ███████         #
#         ██  ██  ██ ██         ██    ██   ██ ██    ██ ██   ██      ██         #
#         ██      ██ ███████    ██    ██   ██  ██████  ██████  ███████         #
func                        _________METHODS_________              ()->void:pass


func enable_experimental_features() -> void:
	Log.lvl( Log.Level.DEBUG, "enable_experimental_features", self )


func disable_experimental_features() -> void:
	Log.lvl( Log.Level.DEBUG, "disable_experimental_features", self )


# EditorLog discovery — prefer EditorIntegration; keep thin wrappers for
# existing call sites (dump_icons, url links, etc.).
# FIXME: drop local duplicates of editor_log once all callers use Integration.

func default_tweak_options(tweak_opts:TweakOptions ) -> void:
	if Engine.is_editor_hint():
		var _es := EditorInterface.get_editor_settings()
		if tweak_opts.color_notice_critical == Color.BLACK:
			tweak_opts.color_notice_critical = _es.get_setting("text_editor/theme/highlighting/comment_markers/critical_color")
		if tweak_opts.color_notice_error == Color.BLACK:
			tweak_opts.color_notice_error = _es.get_setting("text_editor/theme/highlighting/comment_markers/critical_color")
		if tweak_opts.color_notice_warning == Color.BLACK:
			tweak_opts.color_notice_warning = _es.get_setting("text_editor/theme/highlighting/comment_markers/warning_color")
		if tweak_opts.color_notice_notice == Color.BLACK:
			tweak_opts.color_notice_notice = _es.get_setting("text_editor/theme/highlighting/comment_markers/notice_color")
		if tweak_opts.color_notice_debug == Color.BLACK:
			tweak_opts.color_notice_debug = _es.get_setting("text_editor/theme/highlighting/doc_comment_color")
		if tweak_opts.color_notice_trace == Color.BLACK:
			tweak_opts.color_notice_trace = _es.get_setting("text_editor/theme/highlighting/comment_color")



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
	trace()
	if toggle_on == was_enabled: return
	was_enabled = toggle_on
	var code_font:FontVariation = EditorIntegration.get_code_font()
	if not code_font:
		Log.lvl(Log.Level.ERROR, "Unable to get font:CodeEdit from editor theme.", self)
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
	trace()
	if toggled_on:
		if not is_instance_valid(method_trace_args_factory):
			var script_path:String = plugin_dir.path_join("scripts/method_trace_args.gd")
			method_trace_args_factory = load(script_path)
		if not is_instance_valid(method_trace_args_factory):
			Log.lvl(Log.Level.ERROR, "Failure to create MethodTraceArgs factory script instance", self)
			return
		if is_instance_valid(method_trace_args_cm): return
		Log.lvl(Log.Level.NOTICE, "Creating MethodTraceArgs ContextMenuPlugin", self)
		method_trace_args_cm = method_trace_args_factory.call(&'create_method_trace_args_cm')
		if not is_instance_valid(method_trace_args_cm):
			Log.lvl(Log.Level.ERROR, "Creation of MethodTraceArgs ContextMenuPlugin Failed", self)
			return
		add_context_menu_plugin(
			EditorContextMenuPlugin.ContextMenuSlot.CONTEXT_SLOT_SCRIPT_EDITOR_CODE,
			method_trace_args_cm )
	else:
		if is_instance_valid(method_trace_args_cm):
			Log.lvl(Log.Level.NOTICE, "Remove MethodTraceArgs ContextMenuPlugin", self)
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
func editorlog_ligatures_toggle( toggled_on:bool ) -> void:
	trace()
	if toggled_on:
		Log.lvl(Log.Level.NOTICE, "Enable EditorLog Ligatures", self)
	else:
		Log.lvl(Log.Level.NOTICE, "Disable EditorLog Ligatures", self)
	var editor_theme:Theme = EditorInterface.get_editor_theme()
	# 1667329140 = 'calt' OpenType feature tag.
	for font_name:String in editorlog_font_names:
		var font:FontVariation = editor_theme.get_font(font_name, "EditorFonts")
		if not is_instance_valid(font):
			continue
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
var sideways_effect:RichTextEffect = preload("sideways_effect.tres")


func editorlog_rotate_toggle( toggled_on:bool ) -> void:
	trace()
	var output_rtl:RichTextLabel = EditorIntegration.get_output_rtl()
	if not is_instance_valid(output_rtl):
		Log.lvl(Log.Level.ERROR,
			"editorlog_rotate_toggle: Output RichTextLabel not found", self)
		return
	if not is_instance_valid(sideways_effect):
		Log.lvl(Log.Level.ERROR,
			"editorlog_rotate_toggle: sideways_effect missing", self)
		return
	if toggled_on:
		Log.lvl(Log.Level.NOTICE, "Enable EditorLog Sideways Text Effect", self)
		output_rtl.install_effect(sideways_effect)
	else:
		Log.lvl(Log.Level.NOTICE, "Disable EditorLog Sideways Text Effect", self)
		if sideways_effect in output_rtl.custom_effects:
			output_rtl.custom_effects.erase(sideways_effect)
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
func editorlog_search_toggle( toggled_on:bool ) -> void:
	trace()
	var logref:Control = EditorIntegration.get_editorlog()
	if not is_instance_valid(logref):
		Log.lvl(Log.Level.ERROR,
			"editorlog_search_toggle: EditorLog not found", self)
		return
	if not logref is BoxContainer:
		Log.lvl(Log.Level.ERROR,
			"editorlog_search_toggle: EditorLog is %s, need BoxContainer"
			% logref.get_class(), self)
		return
	EditorLogSearch.toggle_search_bar(logref as BoxContainer, toggled_on, opts)

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
# TODO: Move URL handling into editorlog helper class.
# TODO: Registry for URL handlers configurable from settings.
var output_rtl_og_conn:Array

func editorlog_url_links_set( toggle_on:bool ) -> void:
	trace()
	if toggle_on:
		editorlog_url_links_enabled()
	else:
		editorlog_url_links_disabled()


func editorlog_url_links_enabled() -> void:
	trace()
	var output_rtl:RichTextLabel = EditorIntegration.get_output_rtl()
	if not is_instance_valid(output_rtl):
		Log.lvl(Log.Level.ERROR,
			"editorlog_url_links_enabled: Output RichTextLabel not found", self)
		return

	# output_rtl.autowrap_mode = TextServer.AUTOWRAP_OFF
	# output_rtl.autowrap_trim_flags = TextServer.BREAK_NONE

	# Remove default annoying URL handling.
	output_rtl_og_conn = output_rtl.meta_clicked.get_connections()
	for c:Dictionary in output_rtl.meta_clicked.get_connections():
		@warning_ignore("unsafe_call_argument")
		output_rtl.meta_clicked.disconnect(c.get(&"callable"))

	@warning_ignore_start("return_value_discarded")
	output_rtl.meta_clicked.connect(_on_editorlog_link_clicked, CONNECT_DEFERRED)
	@warning_ignore_restore("return_value_discarded")


func editorlog_url_links_disabled() -> void:
	var output_rtl:RichTextLabel = EditorIntegration.get_output_rtl()
	if not is_instance_valid(output_rtl):
		return
	trace()
	if output_rtl.meta_clicked.is_connected(_on_editorlog_link_clicked):
		output_rtl.meta_clicked.disconnect(_on_editorlog_link_clicked)
	for c:Dictionary in output_rtl_og_conn:
		@warning_ignore("unsafe_call_argument", "return_value_discarded")
		output_rtl.meta_clicked.connect(c.get(&"callable"))

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

func editorlog_rich_paste_toggle( toggled_on:bool ) -> void:
	trace()
	if toggled_on:
		if is_instance_valid(rich_paste_cm):
			return
		if not is_instance_valid(rich_paste_factory):
			var rich_paste_script_path:String = plugin_dir.path_join(
				"scripts/rich_paste.gd")
			rich_paste_factory = load(rich_paste_script_path)
		if not is_instance_valid(rich_paste_factory):
			Log.lvl(Log.Level.ERROR,
				"Failure to create rich paste factory script instance", self)
			return
		Log.lvl(Log.Level.NOTICE, "Creating Rich Paste ContextMenuPlugin", self)
		rich_paste_cm = rich_paste_factory.call(&"create_rich_paste_cm")
		if not is_instance_valid(rich_paste_cm):
			Log.lvl(Log.Level.ERROR,
				"Creation of Rich Paste ContextMenuPlugin Failed", self)
			return
		add_context_menu_plugin(
			EditorContextMenuPlugin.ContextMenuSlot.CONTEXT_SLOT_SCRIPT_EDITOR_CODE,
			rich_paste_cm)
	else:
		if is_instance_valid(rich_paste_cm):
			Log.lvl(Log.Level.NOTICE, "Remove Rich Paste ContextMenuPlugin", self)
			remove_context_menu_plugin(rich_paste_cm)
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
func monospace_glyphs_toggle( toggled_on:bool ) -> void:
	trace()
	var output_rtl:RichTextLabel = EditorIntegration.get_output_rtl()
	if not is_instance_valid(output_rtl):
		return
	# FIXME: implementation stripped — only logs enable/disable.
	# Prior experiment used TextServer font fixed-size for braille glyphs.
	if toggled_on:
		Log.lvl(Log.Level.NOTICE, "Enable Monospace Font Glyphs Fixes", self)
	else:
		Log.lvl(Log.Level.NOTICE, "Disable Monospace Font Glyphs Fixes", self)

#endregion Monospaced Font

#                    ██  ██████  ██████  ███    ██ ███████                     #
#                    ██ ██      ██    ██ ████   ██ ██                          #
#                    ██ ██      ██    ██ ██ ██  ██ ███████                     #
#                    ██ ██      ██    ██ ██  ██ ██      ██                     #
#                    ██  ██████  ██████  ██   ████ ███████                     #
func                        __________ICONS__________              ()->void:pass

@export_custom(PROPERTY_HINT_TOOL_BUTTON, "Dump Editor Icons",
	PROPERTY_USAGE_EDITOR_BASIC_SETTING
	| PROPERTY_USAGE_GROUP)
var icons_dump:Callable = dump_icons


static func dump_icons() -> void:
	var editor_theme:Theme = EditorInterface.get_editor_theme()
	var output_rtl:RichTextLabel = EditorIntegration.get_output_rtl()
	if not is_instance_valid(output_rtl):
		push_error("EditorTweaks.dump_icons: no Output RichTextLabel")
		return
	var lines:Array[String] = [
		"",
		Util.h1("Icons", editor_theme.default_font_size + 2),
		"Grouped by icon_type"]

	print_rich("\n".join(lines))
	lines = []
	for icon_type:String in editor_theme.get_icon_type_list():
		lines.append(Util.h2(icon_type,
			editor_theme.default_font_size + 2))
		lines.append(
			'var icon:Texture2D = editor_theme.get_icon(<icon_name>, "%s")'
			% icon_type)
		lines.append("")
		print_rich("\n".join(lines))
		lines = []
		for icon_name:String in editor_theme.get_icon_list(icon_type):
			var editor_icon:Texture2D = editor_theme.get_icon(icon_name, icon_type)
			if editor_icon.get_width() == 0:
				continue
			output_rtl.add_image(editor_icon, 32, 32)
			output_rtl.append_text(" (%d) %s %s" % [
				editor_icon.get_reference_count(),
				icon_name,
				editor_icon.get_size()])
			print_rich("")


#          ██████  ██████  ██       ██████  ██    ██ ██████  ███████           #
#         ██      ██    ██ ██      ██    ██ ██    ██ ██   ██ ██                #
#         ██      ██    ██ ██      ██    ██ ██    ██ ██████  ███████           #
#         ██      ██    ██ ██      ██    ██ ██    ██ ██   ██      ██           #
#          ██████  ██████  ███████  ██████   ██████  ██   ██ ███████           #
func                        _________COLOURS_________              ()->void:pass

# TODO: also dump named Color constants (Color.RED, etc.).

@export_custom(PROPERTY_HINT_TOOL_BUTTON, "Dump Editor Colours",
	PROPERTY_USAGE_EDITOR_BASIC_SETTING
	| PROPERTY_USAGE_GROUP)
var colours_dump:Callable = dump_colours


static func dump_colours() -> void:
	var editor_theme:Theme = EditorInterface.get_editor_theme()
	var lines:Array[String] = [
		"",
		Util.h1("Colours", editor_theme.default_font_size + 2),
		"Grouped by color_type"]

	print_rich("\n".join(lines))
	lines = [""]

	for color_type:String in editor_theme.get_color_type_list():
		lines = [
			Util.h2(color_type, editor_theme.default_font_size + 2),
			'var color:Color = editor_theme.get_color(<color_name>, "%s")'
			% color_type,
			""]
		for color_name:String in editor_theme.get_color_list(color_type):
			var editor_color:Color = editor_theme.get_color(color_name, color_type)
			lines.append("".join([
				"[font_size=26] ",
				"[bgcolor=%s]" % editor_color.to_html(),
				editor_color.to_html(),
				"[/bgcolor]",
				"[/font_size] ",
				color_name]))
		print_rich("\n".join(lines))
		lines = []
