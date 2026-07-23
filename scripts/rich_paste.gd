@tool

## │ ___ _    _    ___         _
## │| _ (_)__| |_ | _ \__ _ __| |_ ___
## │|   / / _| ' \|  _/ _` (_-<  _/ -_)
## │|_|_\_\__|_||_|_| \__,_/__/\__\___|
## ╰─────────────────────────────────────
## Context-menu paste of selected script text as rich console output.
##
## Slot: [code]CONTEXT_SLOT_SCRIPT_EDITOR_CODE[/code].
##[br][color=goldenrod]TODO[/color]: Rename to DocPaste — strip comment
## prefixes and reflow newlines for documentation dumps.
##[br][color=goldenrod]TODO[/color]: Use [EneLog] / project print helper
## instead of bare [code]print_rich[/code].


static func create_rich_paste_cm() -> EditorContextMenuPlugin:
	return RichPasteMenu.new()


class RichPasteMenu extends EditorContextMenuPlugin:
	## [param paths] are NodePaths to the focused [CodeEdit].
	func _popup_menu( paths:PackedStringArray ) -> void:
		if paths.is_empty():
			return
		var scene_tree:SceneTree = Engine.get_main_loop() as SceneTree
		if scene_tree == null:
			return
		var code_edit:CodeEdit = scene_tree.root.get_node(paths[0]) as CodeEdit
		if not is_instance_valid(code_edit):
			return
		add_context_menu_item("rich_paste",
			func(_thing:Variant) -> void:
				# FIXME: newlines → spaces loses structure; strip ## / # too.
				var selected_text:String = code_edit.get_selected_text()
				print_rich(selected_text.replace_char(ord("\n"), ord(" "))))
