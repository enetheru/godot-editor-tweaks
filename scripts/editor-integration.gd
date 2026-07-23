@tool
## Locate the editor Output log and its [RichTextLabel].
##
## Godot's EditorLog is not a stable public API; discovery is version-sensitive
## ([method get_editorlog_4_5] vs [method get_editorlog_4_6]).
##[br][color=goldenrod]FIXME[/color]: [code]plugin.gd[/code] still owns a
## second copy of these helpers. Prefer this module as the single source of
## truth and thin-delegate from the plugin.
##[br][color=goldenrod]TODO[/color]: Cache invalidation when the editor UI is
## rebuilt (dock layout changes can leave stale node refs).


static var editor_log:Control
static var output_rtl:RichTextLabel = null


static func get_output_rtl() -> RichTextLabel:
	if is_instance_valid(output_rtl):
		return output_rtl
	if is_instance_valid(get_editorlog()):
		output_rtl = editor_log.find_child("*Rich*", true, false)
		if is_instance_valid(output_rtl):
			return output_rtl
		push_error("EditorIntegration.get_output_rtl:",
			" Unable to find RichTextLabel in EditorLog's children")
	return null


static func get_editorlog() -> Control:
	var version:Dictionary = Engine.get_version_info()
	if version.major >= 4:
		if version.minor >= 6:
			return get_editorlog_4_6()
		return get_editorlog_4_5()
	return null


static func get_editorlog_4_5() -> BoxContainer:
	if is_instance_valid(editor_log):
		return editor_log
	var base_control:Control = EditorInterface.get_base_control()
	editor_log = base_control.find_child("*EditorLog*", true, false)
	if is_instance_valid(editor_log):
		return editor_log
	push_error("EditorIntegration.get_editorlog_4_5:",
		" Unable to find EditorLog")
	return null


static func get_editorlog_4_6() -> Control:
	if is_instance_valid(editor_log):
		return editor_log
	var base_control:Control = EditorInterface.get_base_control()
	var maybe:Control = base_control.find_child("*Output*", true, false)
	if is_instance_valid(maybe):
		editor_log = maybe
		return maybe
	push_error("EditorIntegration.get_editorlog_4_6:",
		" Unable to find EditorLog")
	return null
