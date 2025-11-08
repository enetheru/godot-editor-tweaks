@tool
extends EditorPlugin

const SettingsMgr = preload('settings.gd')
var settings_mgr : SettingsMgr

# ██████  ██████   ██████  ██████  ███████ ██████  ████████ ██ ███████ ███████ #
# ██   ██ ██   ██ ██    ██ ██   ██ ██      ██   ██    ██    ██ ██      ██      #
# ██████  ██████  ██    ██ ██████  █████   ██████     ██    ██ █████   ███████ #
# ██      ██   ██ ██    ██ ██      ██      ██   ██    ██    ██ ██           ██ #
# ██      ██   ██  ██████  ██      ███████ ██   ██    ██    ██ ███████ ███████ #
func                        ________PROPERTIES_______              ()->void:pass

var editor_log : HBoxContainer :
	get = get_editorlog
var output_rtl : RichTextLabel :
	get = get_output_rtl
var code_edit_font : FontVariation :
	get = get_code_font

var editorlog_font_names : PackedStringArray = [
	'output_source',
	'output_source_bold',
	'output_source_italic',
	'output_source_bold_italic',
	'output_source_mono']

@export_group("Individual")
## Clear all settings when unloading plugin
@export_custom( PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR_BASIC_SETTING)
var self_destruct : bool = false

#      ██████  ██    ██ ███████ ██████  ██████  ██ ██████  ███████ ███████     #
#     ██    ██ ██    ██ ██      ██   ██ ██   ██ ██ ██   ██ ██      ██          #
#     ██    ██ ██    ██ █████   ██████  ██████  ██ ██   ██ █████   ███████     #
#     ██    ██  ██  ██  ██      ██   ██ ██   ██ ██ ██   ██ ██           ██     #
#      ██████    ████   ███████ ██   ██ ██   ██ ██ ██████  ███████ ███████     #
func                        ________OVERRIDES________              ()->void:pass

func _enter_tree() -> void:
	print("Starting Enhancement Addon")
	settings_mgr = SettingsMgr.new(self, "plugin/enhancements")

	#editor_theme = EditorInterface.get_editor_theme()
	#var button_icon : Texture2D = editor_theme.get_icon("Button", "EditorIcons")
	#add_custom_type("RichIconButton", "Control", preload('ui/rich_icon_button.gd'), button_icon)


func _exit_tree() -> void:
	# Clean-up of the plugin goes here.
	if self_destruct: settings_mgr.scrub()

#         ███    ███ ███████ ████████ ██   ██  ██████  ██████  ███████         #
#         ████  ████ ██         ██    ██   ██ ██    ██ ██   ██ ██              #
#         ██ ████ ██ █████      ██    ███████ ██    ██ ██   ██ ███████         #
#         ██  ██  ██ ██         ██    ██   ██ ██    ██ ██   ██      ██         #
#         ██      ██ ███████    ██    ██   ██  ██████  ██████  ███████         #
func                        _________METHODS_________              ()->void:pass

func get_editorlog() -> HBoxContainer:
	if is_instance_valid(editor_log): return editor_log
	var base_control : Control = EditorInterface.get_base_control()
	editor_log = base_control.find_child("*EditorLog*", true, false)
	if is_instance_valid(editor_log): return editor_log
	push_error("Unable to find EditorLog")
	return null


func get_output_rtl() -> RichTextLabel:
	if is_instance_valid(output_rtl): return output_rtl
	if is_instance_valid(get_editorlog()):
		output_rtl = editor_log.find_child("*Rich*", true, false)
		if is_instance_valid(output_rtl):return output_rtl
		push_error("Unable to find RichTextLabel in EditorLog's children")
	return null

func get_code_font() -> FontVariation:
	if is_instance_valid(code_edit_font): return code_edit_font
	if is_instance_valid(get_editorlog()):
		var editor_theme : Theme = EditorInterface.get_editor_theme()
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
@export_group("Monospace Font Glyphs")

@export_custom( PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR_BASIC_SETTING)
var monospace_glyphs : bool :
	set = monospace_glyphs_toggle

func monospace_glyphs_toggle( toggled_on : bool ) -> void:
	if not is_instance_valid(output_rtl): return
	monospace_glyphs = toggled_on
	if toggled_on:
		print("Enable Monospace Font Glyphs Fixes")
		#var font : Font = code_edit_font.base_font
		#print( code_edit_font.get_supported_chars())
		#print(JSON.stringify(font.get_supported_feature_list(), "  ", false) )
		#print(JSON.stringify(font.get_supported_variation_list(), "  ", false) )
		#print( font.has_char("⣿".to_utf32_buffer()[0]))
		#print( font.has_char(" ".to_utf32_buffer()[0]))

		var editor_theme : Theme = EditorInterface.get_editor_theme()
		var ts := TextServerManager.get_primary_interface()

		for font_name in editorlog_font_names:
			var font_variation : FontVariation = editor_theme.get_font(font_name, "EditorFonts")
			var font : Font = font_variation.base_font

			var rid : RID
			for r : RID in font.get_rids():
				if ts.font_has_char(r, 0x28FF):
					rid=r
					print(ts.font_get_name(r))
					break
			if not rid.is_valid(): return
			print(ts.font_get_name(rid))

			ts.font_set_fixed_size(rid, 18)
			print( ts.font_get_fixed_size(rid))

			ts.font_set_fixed_size_scale_mode(rid, TextServer.FIXED_SIZE_SCALE_ENABLED)


			#print( ts.font_get_glyph_size(rid,Vector2i.ONE, 0x2800-0x28FF) )


			#print( "has ⣿:", font.has_char(ord("⣿")))
			#print( "has \u2800:", font.has_char(0x2800))


	else:
		print("Disable Monospace Font Glyphs Fixes")



#  ██      ██ ███   ██ ██████ ██████ █████   ████   █████ ██ ███   ██  █████   #
#  ██      ██ ████  ██ ██     ██     ██  ██ ██  ██ ██     ██ ████  ██ ██       #
#  ██      ██ ██ ██ ██ ████   ██████ █████  ██████ ██     ██ ██ ██ ██ ██  ███  #
#  ██      ██ ██  ████ ██         ██ ██     ██  ██ ██     ██ ██  ████ ██   ██  #
#  ███████ ██ ██   ███ ██████ ██████ ██     ██  ██  █████ ██ ██   ███  █████   #
func                            ______LINE_SPACING_______                    ()->void:pass
@export_custom( PROPERTY_HINT_NONE, "",
	PROPERTY_USAGE_EDITOR_BASIC_SETTING | PROPERTY_USAGE_SUBGROUP)
var codeedit_linespacing_toggle : bool :
	set(toggle_on):
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
		codeedit_linespacing_above = v
		fix_font_height_for_code_editor(codeedit_linespacing_above, codeedit_linespacing_below)


@export_custom( PROPERTY_HINT_NONE, "",
	PROPERTY_USAGE_EDITOR_BASIC_SETTING | PROPERTY_USAGE_SUBGROUP)
var codeedit_linespacing_below : int = 0:
	set(v):
		codeedit_linespacing_below = v
		fix_font_height_for_code_editor(codeedit_linespacing_above, codeedit_linespacing_below)


func fix_font_height_for_code_editor(top : int, bottom : int) -> void:
	var editor_theme : Theme = EditorInterface.get_editor_theme()
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
@export_group("EditorLog", "editorlog_")

@export_custom( PROPERTY_HINT_NONE, "",
	PROPERTY_USAGE_EDITOR_BASIC_SETTING | PROPERTY_USAGE_GROUP)
var editorlog_ligatures : bool :
	set = editorlog_ligatures_toggle

func editorlog_ligatures_toggle( toggled_on : bool ) -> void:
	editorlog_ligatures = toggled_on
	var editor_theme : Theme = EditorInterface.get_editor_theme()
	if toggled_on: print("Enable EditorLog Ligatures")
	else: print("Disable EditorLog Ligatures")
	for font_name in editorlog_font_names:
		var font : FontVariation = editor_theme.get_font(font_name, "EditorFonts")
		font.opentype_features = {1667329140: 1 if toggled_on else 0}


@export_custom( PROPERTY_HINT_NONE, "",
	PROPERTY_USAGE_EDITOR_BASIC_SETTING | PROPERTY_USAGE_GROUP)
var editorlog_rotate_effect : bool :
	set = editorlog_rotate_toggle

var sideways_effect : RichTextEffect = preload('sideways_effect.tres')

func editorlog_rotate_toggle( toggled_on : bool ) -> void:
	if not is_instance_valid(output_rtl): return
	if not is_instance_valid(sideways_effect): return
	editorlog_rotate_effect = toggled_on

	if toggled_on:
		print("Enable EditorLog Sideways Text Effect")
		output_rtl.install_effect(sideways_effect)
	else:
		print("Disable EditorLog Sideways Text Effect")
		if sideways_effect in output_rtl.custom_effects:
			output_rtl.custom_effects.erase(sideways_effect)


# ██████  ███████ ███████        ██  ██ ██      ██ ███    ██ ██   ██ ███████   #
# ██   ██ ██      ██      ██    ██  ██  ██      ██ ████   ██ ██  ██  ██        #
# ██████  █████   ███████      ██  ██   ██      ██ ██ ██  ██ █████   ███████   #
# ██   ██ ██           ██ ██  ██  ██    ██      ██ ██  ██ ██ ██  ██       ██   #
# ██   ██ ███████ ███████    ██  ██     ███████ ██ ██   ████ ██   ██ ███████   #
func                        ________RES_LINKS________              ()->void:pass

@export_custom( PROPERTY_HINT_NONE, "",
	PROPERTY_USAGE_EDITOR_BASIC_SETTING | PROPERTY_USAGE_GROUP)
var editorlog_url_links : bool :
	set = editorlog_url_links_set

var output_rtl_og_conn : Array

func editorlog_url_links_set( toggle_on:bool ) -> void:
	editorlog_url_links = toggle_on
	if toggle_on: editorlog_url_links_enabled()
	else: editorlog_url_links_disabled()


func editorlog_url_links_enabled() -> void:
	print("editorlog_url_links_enabled")
	if not is_instance_valid( output_rtl ): return

	# Remove default annoying URL handling.
	output_rtl_og_conn = output_rtl.meta_clicked.get_connections()
	for c : Dictionary  in output_rtl.meta_clicked.get_connections():
		@warning_ignore('unsafe_call_argument')
		output_rtl.meta_clicked.disconnect( c.get('callable') )

	@warning_ignore_start('return_value_discarded')
	output_rtl.meta_clicked.connect(_on_link_clicked, CONNECT_DEFERRED)
	@warning_ignore_restore('return_value_discarded')


func editorlog_url_links_disabled() -> void:
	if not is_instance_valid( output_rtl ): return
	print("editorlog_url_links_disabled")
	if output_rtl.meta_clicked.is_connected(_on_link_clicked):
		output_rtl.meta_clicked.disconnect(_on_link_clicked)
	for c : Dictionary in output_rtl_og_conn:
		@warning_ignore('unsafe_call_argument', 'return_value_discarded')
		output_rtl.meta_clicked.connect( c.get('callable') )


func _on_link_clicked( meta : Variant ) -> void:
	var url : String = meta
	if not url: return
	if not "://" in url:
		print("url: ", url)
		return
	if url.begins_with("res://"):
		var parts : PackedStringArray = url.split(':')
		print( parts )
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
		print("url: ", url)
		@warning_ignore('return_value_discarded')
		OS.shell_open( url )
