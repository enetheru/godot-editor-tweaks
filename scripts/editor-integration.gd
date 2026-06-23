

static var editor_log:Control
static var output_rtl:RichTextLabel = null


static func get_output_rtl() -> RichTextLabel:
	if is_instance_valid(output_rtl): return output_rtl
	if is_instance_valid(get_editorlog()):
		output_rtl = editor_log.find_child("*Rich*", true, false)
		if is_instance_valid(output_rtl):return output_rtl
		push_error("Unable to find RichTextLabel in EditorLog's children")
	return null


static func get_editorlog() -> Control:
	var version:Dictionary = Engine.get_version_info()
	if version.major >= 4:
		if version.minor >= 6:
			return get_editorlog_4_6()
		if version.minor < 6:
			return get_editorlog_4_5()
	return null


static func get_editorlog_4_5() -> BoxContainer:
	if is_instance_valid(editor_log): return editor_log
	var base_control : Control = EditorInterface.get_base_control()
	editor_log = base_control.find_child("*EditorLog*", true, false)
	if is_instance_valid(editor_log): return editor_log
	push_error("Unable to find EditorLog")
	return null


static func get_editorlog_4_6() -> Control:
	if is_instance_valid(editor_log): return editor_log
	var base_control : Control = EditorInterface.get_base_control()
	var maybe:Control = base_control.find_child("*Output*", true, false)
	if is_instance_valid(maybe):
		editor_log = maybe
		return maybe
	push_error("Unable to find EditorLog")
	return null
