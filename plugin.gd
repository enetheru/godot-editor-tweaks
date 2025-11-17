@tool
extends EditorPlugin

const Self = preload('uid://setvleg6sni3')

# TODO make the plugin more bare bones that check for dependencies before
# loading, that way we might be able to devise a way to automatically clone
# and update plugins like the vim lazy codebase does.

const SettingsHelper = preload('uid://b0mfrmvvxnr01')
var settings_mgr : SettingsHelper

const EditorLog = preload('uid://bqnxqo33qkevi')


# ██████  ██████   ██████  ██████  ███████ ██████  ████████ ██ ███████ ███████ #
# ██   ██ ██   ██ ██    ██ ██   ██ ██      ██   ██    ██    ██ ██      ██      #
# ██████  ██████  ██    ██ ██████  █████   ██████     ██    ██ █████   ███████ #
# ██      ██   ██ ██    ██ ██      ██      ██   ██    ██    ██ ██           ██ #
# ██      ██   ██  ██████  ██      ███████ ██   ██    ██    ██ ███████ ███████ #
func                        ________PROPERTIES_______              ()->void:pass

static var editor_log : BoxContainer :
	get = get_editorlog
static var output_rtl : RichTextLabel :
	get = get_output_rtl
static var code_edit_font : FontVariation :
	get = get_code_font
static var editor_theme : Theme :
	get(): return EditorInterface.get_editor_theme()

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
		EneLog.printy("url: ", url)
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
		EneLog.printy("url: ", url)
		@warning_ignore('return_value_discarded')
		OS.shell_open( url )


#      ██████  ██    ██ ███████ ██████  ██████  ██ ██████  ███████ ███████     #
#     ██    ██ ██    ██ ██      ██   ██ ██   ██ ██ ██   ██ ██      ██          #
#     ██    ██ ██    ██ █████   ██████  ██████  ██ ██   ██ █████   ███████     #
#     ██    ██  ██  ██  ██      ██   ██ ██   ██ ██ ██   ██ ██           ██     #
#      ██████    ████   ███████ ██   ██ ██   ██ ██ ██████  ███████ ███████     #
func                        ________OVERRIDES________              ()->void:pass

func _init() -> void:
	EneLog.pfunc(self)
	icons_dump = Self.dump_icons
	colours_dump = Self.dump_colours
	settings_mgr = SettingsHelper.new(self, "plugin/enetheru-editor-tweaks")


#         ███    ███ ███████ ████████ ██   ██  ██████  ██████  ███████         #
#         ████  ████ ██         ██    ██   ██ ██    ██ ██   ██ ██              #
#         ██ ████ ██ █████      ██    ███████ ██    ██ ██   ██ ███████         #
#         ██  ██  ██ ██         ██    ██   ██ ██    ██ ██   ██      ██         #
#         ██      ██ ███████    ██    ██   ██  ██████  ██████  ███████         #
func                        _________METHODS_________              ()->void:pass

static func get_editorlog() -> BoxContainer:
	if is_instance_valid(editor_log): return editor_log
	var base_control : Control = EditorInterface.get_base_control()
	editor_log = base_control.find_child("*EditorLog*", true, false)
	if is_instance_valid(editor_log): return editor_log
	push_error("Unable to find EditorLog")
	return null


static func get_output_rtl() -> RichTextLabel:
	if is_instance_valid(output_rtl): return output_rtl
	if is_instance_valid(get_editorlog()):
		output_rtl = editor_log.find_child("*Rich*", true, false)
		if is_instance_valid(output_rtl):return output_rtl
		push_error("Unable to find RichTextLabel in EditorLog's children")
	return null


static func get_code_font() -> FontVariation:
	if is_instance_valid(code_edit_font): return code_edit_font
	if is_instance_valid(get_editorlog()):
		code_edit_font = editor_theme.get_font("font", "CodeEdit")
		if is_instance_valid(code_edit_font):return code_edit_font
		push_error("Unable to find CodeEdit font in editor theme")
	return null


# ███    ███  ██████  ███    ██  ██████  ███████ ██████   █████   █████ ██████ #
# ████  ████ ██    ██ ████   ██ ██    ██ ██      ██   ██ ██   ██ ██     ██     #
# ██ ████ ██ ██    ██ ██ ██  ██ ██    ██ ███████ ██████  ███████ ██     ████   #
# ██  ██  ██ ██    ██ ██  ██ ██ ██    ██      ██ ██      ██   ██ ██     ██     #
# ██      ██  ██████  ██   ████  ██████  ███████ ██      ██   ██  █████ ██████ #
func                        ________MONOSPACE________              ()->void:pass

@export_custom( PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR_BASIC_SETTING)
var monospace_glyphs : bool = false :
	set = monospace_glyphs_toggle

func monospace_glyphs_toggle( toggled_on : bool ) -> void:
	EneLog.pfunc(self)
	if not is_instance_valid(output_rtl): return
	monospace_glyphs = toggled_on
	if toggled_on:
		EneLog.printy("Enable Monospace Font Glyphs Fixes")
		EneLog.printy("object instance ID: ", get_instance_id() )
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
		EneLog.printy("Disable Monospace Font Glyphs Fixes")



#  ██      ██ ███   ██ ██████ ██████ █████   ████   █████ ██ ███   ██  █████   #
#  ██      ██ ████  ██ ██     ██     ██  ██ ██  ██ ██     ██ ████  ██ ██       #
#  ██      ██ ██ ██ ██ ████   ██████ █████  ██████ ██     ██ ██ ██ ██ ██  ███  #
#  ██      ██ ██  ████ ██         ██ ██     ██  ██ ██     ██ ██  ████ ██   ██  #
#  ███████ ██ ██   ███ ██████ ██████ ██     ██  ██  █████ ██ ██   ███  █████   #
func                            ______LINE_SPACING_______                    ()->void:pass
@export_custom( PROPERTY_HINT_NONE, "",
	PROPERTY_USAGE_EDITOR_BASIC_SETTING | PROPERTY_USAGE_SUBGROUP)
var codeedit_linespacing_toggle : bool = false :
	set(toggle_on):
		EneLog.pfunc(self)
		codeedit_linespacing_toggle = toggle_on
		if toggle_on:
			fix_font_height_for_code_editor(codeedit_linespacing_above, codeedit_linespacing_below)
		else:
			code_edit_font.spacing_top = -1
			code_edit_font.spacing_top = -1


@export_custom( PROPERTY_HINT_NONE, "",
	PROPERTY_USAGE_EDITOR_BASIC_SETTING | PROPERTY_USAGE_SUBGROUP)
var codeedit_linespacing_above : int = 0:
	set(v):
		EneLog.pfunc(self)
		codeedit_linespacing_above = v
		fix_font_height_for_code_editor(codeedit_linespacing_above, codeedit_linespacing_below)


@export_custom( PROPERTY_HINT_NONE, "",
	PROPERTY_USAGE_EDITOR_BASIC_SETTING | PROPERTY_USAGE_SUBGROUP)
var codeedit_linespacing_below : int = 0:
	set(v):
		EneLog.pfunc(self)
		codeedit_linespacing_below = v
		fix_font_height_for_code_editor(codeedit_linespacing_above, codeedit_linespacing_below)


func fix_font_height_for_code_editor(top : int, bottom : int) -> void:
	if not code_edit_font:
		code_edit_font = editor_theme.get_font("font", "CodeEdit")
	if top: 	code_edit_font.spacing_top = top # Original is -1
	else:		code_edit_font.spacing_top = -1
	if bottom: 	code_edit_font.spacing_bottom = bottom # Original is -1
	else: 		code_edit_font.spacing_bottom = -1


# ███████ ██████  ██ ████████  ██████  ██████        ██       ██████   ██████  #
# ██      ██   ██ ██    ██    ██    ██ ██   ██       ██      ██    ██ ██       #
# █████   ██   ██ ██    ██    ██    ██ ██████  █████ ██      ██    ██ ██   ███ #
# ██      ██   ██ ██    ██    ██    ██ ██   ██       ██      ██    ██ ██    ██ #
# ███████ ██████  ██    ██     ██████  ██   ██       ███████  ██████   ██████  #
func                        ________EDITOR_LOG_______              ()->void:pass

# │ _    _           _
# │| |  (_)__ _ __ _| |_ _  _ _ _ ___ ___
# │| |__| / _` / _` |  _| || | '_/ -_|_-<
# │|____|_\__, \__,_|\__|\_,_|_| \___/__/
# ╰───────|___/───────────────────────────
@export_custom( PROPERTY_HINT_NONE, "",
	PROPERTY_USAGE_EDITOR_BASIC_SETTING | PROPERTY_USAGE_GROUP)
var editorlog_ligatures : bool = false :
	set = editorlog_ligatures_toggle

func editorlog_ligatures_toggle( toggled_on : bool ) -> void:
	EneLog.pfunc(self)
	editorlog_ligatures = toggled_on
	if toggled_on: EneLog.printy("Enable EditorLog Ligatures")
	else: EneLog.printy("Disable EditorLog Ligatures")
	for font_name in editorlog_font_names:
		var font : FontVariation = editor_theme.get_font(font_name, "EditorFonts")
		font.opentype_features = {1667329140: 1 if toggled_on else 0}

# │ ___     _        _       ___  __  __        _
# │| _ \___| |_ __ _| |_ ___| __|/ _|/ _|___ __| |_
# │|   / _ \  _/ _` |  _/ -_) _||  _|  _/ -_) _|  _|
# │|_|_\___/\__\__,_|\__\___|___|_| |_| \___\__|\__|
# ╰───────────────────────────────────────────────────
@export_custom( PROPERTY_HINT_NONE, "",
	PROPERTY_USAGE_EDITOR_BASIC_SETTING | PROPERTY_USAGE_GROUP)
var editorlog_rotate_effect : bool = false :
	set = editorlog_rotate_toggle

var sideways_effect : RichTextEffect = preload('sideways_effect.tres')

func editorlog_rotate_toggle( toggled_on : bool ) -> void:
	EneLog.pfunc(self)
	if not is_instance_valid(output_rtl): return
	if not is_instance_valid(sideways_effect): return
	editorlog_rotate_effect = toggled_on

	if toggled_on:
		EneLog.printy("Enable EditorLog Sideways Text Effect")
		output_rtl.install_effect(sideways_effect)
	else:
		EneLog.printy("Disable EditorLog Sideways Text Effect")
		if sideways_effect in output_rtl.custom_effects:
			output_rtl.custom_effects.erase(sideways_effect)

# │ ___                  _    ___
# │/ __| ___ __ _ _ _ __| |_ | _ ) __ _ _ _
# │\__ \/ -_) _` | '_/ _| ' \| _ \/ _` | '_|
# │|___/\___\__,_|_| \__|_||_|___/\__,_|_|
# ╰──────────────────────────────────────────
@export_custom( PROPERTY_HINT_NONE, "",
	PROPERTY_USAGE_EDITOR_BASIC_SETTING | PROPERTY_USAGE_GROUP)
var editorlog_search : bool = false :
	set = editorlog_search_toggle

func editorlog_search_toggle( toggled_on : bool ) -> void:
	EneLog.pfunc(self)
	if not is_instance_valid(editor_log): return
	editorlog_search = toggled_on
	EditorLog.toggle_search_bar(editor_log, toggled_on)

# │ _    _      _      _      _   _          _                _     ____
# │| |  (_)_ _ | |__  /_\  __| |_(_)___ _ _ | |  _ _ ___ ___ (_)   / / /
# │| |__| | ' \| / / / _ \/ _|  _| / _ \ ' \| | | '_/ -_|_-<  _   / / /
# │|____|_|_||_|_\_\/_/ \_\__|\__|_\___/_||_| | |_| \___/__/ (_) /_/_/
# │                                         |_|
# ╰───────────────────────────────────────────────────────────────────────
# TODO Move code to editorlog helper class
# TODO create a registry for URL handlers that can be updated in the settings.

@export_custom( PROPERTY_HINT_NONE, "editorlog",
	PROPERTY_USAGE_EDITOR_BASIC_SETTING | PROPERTY_USAGE_GROUP)
var editorlog_url_links : bool = false :
	set = editorlog_url_links_set

var output_rtl_og_conn : Array

func editorlog_url_links_set( toggle_on:bool ) -> void:
	EneLog.pfunc(self)
	editorlog_url_links = toggle_on
	if toggle_on: editorlog_url_links_enabled()
	else: editorlog_url_links_disabled()


func editorlog_url_links_enabled() -> void:
	EneLog.pfunc(self)
	if not is_instance_valid( output_rtl ): return

	# Remove default annoying URL handling.
	output_rtl_og_conn = output_rtl.meta_clicked.get_connections()
	for c : Dictionary  in output_rtl.meta_clicked.get_connections():
		@warning_ignore('unsafe_call_argument')
		output_rtl.meta_clicked.disconnect( c.get('callable') )

	@warning_ignore_start('return_value_discarded')
	output_rtl.meta_clicked.connect(_on_editorlog_link_clicked, CONNECT_DEFERRED)
	@warning_ignore_restore('return_value_discarded')


func editorlog_url_links_disabled() -> void:
	if not is_instance_valid( output_rtl ): return
	EneLog.pfunc(self)
	if output_rtl.meta_clicked.is_connected(_on_editorlog_link_clicked):
		output_rtl.meta_clicked.disconnect(_on_editorlog_link_clicked)
	for c : Dictionary in output_rtl_og_conn:
		@warning_ignore('unsafe_call_argument', 'return_value_discarded')
		output_rtl.meta_clicked.connect( c.get('callable') )


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
	var output : RichTextLabel = output_rtl
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

			output.add_image(editor_icon, 32, 32 )
			output.append_text(" (%d) %s %s" % [
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
