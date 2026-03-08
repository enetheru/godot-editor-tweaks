@tool

## │ ___ _    _    ___         _          [br]
## │| _ (_)__| |_ | _ \__ _ __| |_ ___    [br]
## │|   / / _| ' \|  _/ _` (_-<  _/ -_)   [br]
## │|_|_\_\__|_||_|_| \__,_/__/\__\___|   [br]
## ╰───────────────────────────────────── [br]
## subtitle
##
## TODO Change this to DocPaste[br]
## Because i have to remove newlines and comment strings[br]
## CONTEXT_SLOT_SCRIPT_EDITOR_CODE[br]
## Context menu of Script editor's code editor[br]


static func create_rich_paste_cm() -> EditorContextMenuPlugin:
	return MyCodeEditMenu.new()


class MyCodeEditMenu extends EditorContextMenuPlugin:
	# _popup_menu() will be called with the path to the CodeEdit node.
	# The option callback will receive reference to that node.
	func _popup_menu( paths:PackedStringArray ) -> void:
		var scene_tree:SceneTree = Engine.get_main_loop()
		var code_edit:CodeEdit = scene_tree.root.get_node(paths[0]);
		add_context_menu_item("rich_paste",
			func(_thing:Variant) -> void:
				## how to manage the newline business?
				var selected_text:String = code_edit.get_selected_text()
				print_rich(selected_text.replace_char(ord('\n'), ord(' '))))
