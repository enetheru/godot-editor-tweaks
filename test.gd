@tool
extends EditorScript
## Manual EditorScript scratch for Output-log features.
##
## Uses [code]editor-integration.gd[/code] for log discovery.
##[br][color=goldenrod]TODO[/color]: Move out of the shipped addon or gate
## behind [member TweakOptions.debug].

const EditorIntegration = preload("uid://cl0kj8qvnhfam")


func _run() -> void:
	var output:RichTextLabel = get_output_label()
	if not output:
		print("Unable to find output label")
		return

	output.clear()
	output.append_text("\n".join([
		"",
		"[b]--- Res:// url's ---[/b]",
		"[url=beans]beans[/url]",
		"[url=uid://setvleg6sni3]plugin script uid[/url]",
		"[url=https://godotengine.org]godot web url[/url]",
		"",
		"[b]--- Ligatures ---[/b]",
		"<===<< like this >>==<< <<==-------*** etc.",
		"",
		"[b]--- LineSpacing ---[/b]",
		"██      ██ ███    ██ ███████ ███████ ██████   █████   ██████ ██ ███    ██  ██████ ",
		"██      ██ ████   ██ ██      ██      ██   ██ ██   ██ ██      ██ ████   ██ ██      ",
		"██      ██ ██ ██  ██ █████   ███████ ██████  ███████ ██      ██ ██ ██  ██ ██   ███",
		"██      ██ ██  ██ ██ ██           ██ ██      ██   ██ ██      ██ ██  ██ ██ ██    ██",
		"███████ ██ ██   ████ ███████ ███████ ██      ██   ██  ██████ ██ ██   ████  ██████ ",
		"",
		"[b]Sideways Text Effect[/b]",
		"[sideways]sideways[/sideways]",
		"[b]Sideways Text Effect[/b]",
		"[sideways angle=90]" + "\n".join("Sideways".reverse().split()) + "[/sideways]",
	]))

	print_icons(output)


func erase_settings() -> void:
	var ed_settings:EditorSettings = EditorInterface.get_editor_settings()
	for property:Dictionary in ed_settings.get_property_list():
		var setting_name:String = property.get(&"name")
		if setting_name.begins_with("plugin/editor_tweaks") \
		or setting_name.begins_with("editor_tweaks"):
			ed_settings.erase(setting_name)


func get_output_label() -> RichTextLabel:
	return EditorIntegration.get_output_rtl()


func print_icons( output:RichTextLabel ) -> void:
	output.push_bold()
	output.push_font_size(output.get_theme_default_font_size() + 2)
	output.newline()
	output.append_text("--- Icons ---")
	output.pop_all()
	output.newline()
	output.append_text("in groups of icon_type")
	output.newline()

	var editor_theme:Theme = EditorInterface.get_editor_theme()
	for icon_type:String in editor_theme.get_icon_type_list():
		output.push_paragraph(HORIZONTAL_ALIGNMENT_CENTER)
		output.push_bold()
		output.push_font_size(output.get_theme_default_font_size() + 2)
		output.newline()
		output.append_text("--- %s ---" % icon_type)
		output.pop_all()
		output.newline()

		output.push_table(3)
		for icon_name:String in editor_theme.get_icon_list(icon_type):
			var editor_icon:Texture2D = editor_theme.get_icon(icon_name, icon_type)
			if editor_icon.get_width() == 0:
				continue

			output.push_cell()
			output.add_image(editor_icon, 32, 32)
			output.pop()

			output.push_cell()
			output.append_text(icon_name)
			output.pop()

			output.push_cell()
			output.append_text(str(editor_icon.get_rid()))
			output.pop()

		output.pop_all()
