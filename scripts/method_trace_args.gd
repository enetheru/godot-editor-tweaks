@tool

## │ __  __     _   _            _ _____                  _                  [br]
## │|  \/  |___| |_| |_  ___  __| |_   _| _ __ _ __ ___  /_\  _ _ __ _ ___   [br]
## │| |\/| / -_)  _| ' \/ _ \/ _` | | || '_/ _` / _/ -_)/ _ \| '_/ _` (_-<   [br]
## │|_|  |_\___|\__|_||_\___/\__,_| |_||_| \__,_\__\___/_/ \_\_| \__, /__/   [br]
## ╰─────────────────────────────────────────────────────────────|___/────── [br]
## MethodTraceArgs subtitle
##
## Adds a context menu item (right-click and Tools menu in the script editor)
## that inserts a `trace(...)` line just after the `func` definition on the
## current line. If the function has arguments, they are added in a Dictionary
## of the form `trace({&'arg_name': arg_name, ...})`.


static func create_method_trace_args_cm() -> EditorContextMenuPlugin:
	return MethodTraceArgsMenu.new()


class MethodTraceArgsMenu extends EditorContextMenuPlugin:

	func _popup_menu( paths:PackedStringArray ) -> void:
		if paths.is_empty(): return
		var scene_tree:SceneTree = Engine.get_main_loop()
		var code_edit:CodeEdit = scene_tree.root.get_node(paths[0]) as CodeEdit
		if not is_instance_valid(code_edit): return
		add_context_menu_item("Insert trace(args)",
			func(_thing:Variant) -> void:
				_insert_trace(code_edit) )
		add_context_menu_item("Insert trace_lvl snippet",
			func(_thing:Variant) -> void:
				_insert_trace_lvl(code_edit) )

	static func _insert_trace_lvl( code_edit:CodeEdit ) -> void:
		var snippet:String = "trace_lvl(Core.LogLevel.DEFAULT, [''])"
		var line_idx:int = code_edit.get_caret_line()
		var line_text:String = code_edit.get_line(line_idx)

		# Match indentation of the current line.
		var indent:String = ""
		for c in line_text:
			if c == '\t' or c == ' ': indent += c
			else: break

		var new_line:String = indent + snippet
		var insert_at:int = line_idx + 1
		if insert_at >= code_edit.get_line_count():
			code_edit.set_line(line_idx, line_text + "\n" + new_line)
		else:
			var existing:String = code_edit.get_line(insert_at)
			code_edit.set_line(insert_at, new_line + "\n" + existing)
		code_edit.set_caret_line(insert_at)
		code_edit.set_caret_column(new_line.length()-3)

	static func _insert_trace( code_edit:CodeEdit ) -> void:
		var line_idx:int = code_edit.get_caret_line()
		var line_count:int = code_edit.get_line_count()

		# Walk up looking for a `func ...(...)` definition (handles multi-line signatures).
		var func_start:int = -1
		var is_static:bool = false
		var i:int = line_idx
		while i >= 0:
			var stripped:String = code_edit.get_line(i).strip_edges()
			if stripped.begins_with("func "):
				func_start = i
				break
			if stripped.begins_with("static func "):
				func_start = i
				is_static = true
				break
			i -= 1
		if func_start == -1:
			push_warning("MethodTraceArgs: no `func` found at or above caret.")
			return

		# Find the line where the signature ends with `:` (closing paren may span lines).
		var sig_end:int = func_start
		var paren_depth:int = 0
		var found_end:bool = false
		var combined:String = ""
		for j in range(func_start, line_count):
			var line_text:String = code_edit.get_line(j)
			combined += line_text + "\n"
			for c in line_text:
				if c == '(': paren_depth += 1
				elif c == ')': paren_depth -= 1
			if paren_depth <= 0 and line_text.strip_edges().ends_with(":"):
				sig_end = j
				found_end = true
				break
		if not found_end:
			push_warning("MethodTraceArgs: malformed function signature.")
			return

		# Extract argument names from inside the outermost parentheses.
		var open_idx:int = combined.find("(")
		var close_idx:int = combined.rfind(")")
		var args_src:String = ""
		if open_idx != -1 and close_idx != -1 and close_idx > open_idx:
			args_src = combined.substr(open_idx + 1, close_idx - open_idx - 1)

		var arg_names:PackedStringArray = _parse_arg_names(args_src)

		# Determine indentation: signature indent + one level.
		var sig_line:String = code_edit.get_line(func_start)
		var base_indent:String = ""
		for c in sig_line:
			if c == '\t' or c == ' ': base_indent += c
			else: break
		var body_indent:String = base_indent + "\t"

		var trace_line:String
		var core:String = "Core." if is_static else ''
		if arg_names.is_empty():
			trace_line = "%s%strace()" % [body_indent, core]
		else:
			var pairs:PackedStringArray = []
			for name in arg_names:
				pairs.append("&'%s': %s" % [name, name])
			trace_line = "%s%strace({%s})" % [body_indent, core, ", ".join(pairs)]

		# Insert immediately after the signature end line.
		var insert_at:int = sig_end + 1
		if insert_at >= code_edit.get_line_count():
			code_edit.set_line(code_edit.get_line_count() - 1,
				code_edit.get_line(code_edit.get_line_count() - 1) + "\n" + trace_line)
		else:
			var existing:String = code_edit.get_line(insert_at)
			code_edit.set_line(insert_at, trace_line + "\n" + existing)

	## Parse a raw arg list source like `a:int, b:=1, c, d:String = "x,y"` -> ["a","b","c","d"].
	static func _parse_arg_names( src:String ) -> PackedStringArray:
		var out:PackedStringArray = []
		var depth:int = 0
		var buf:String = ""
		var in_str:int = 0 # 0=no, 1=single, 2=double
		for c in src:
			if in_str == 1:
				buf += c
				if c == "'": in_str = 0
				continue
			if in_str == 2:
				buf += c
				if c == '"': in_str = 0
				continue
			if c == "'": in_str = 1; buf += c; continue
			if c == '"': in_str = 2; buf += c; continue
			if c == '(' or c == '[' or c == '{': depth += 1; buf += c; continue
			if c == ')' or c == ']' or c == '}': depth -= 1; buf += c; continue
			if c == ',' and depth == 0:
				_append_name(out, buf)
				buf = ""
				continue
			buf += c
		_append_name(out, buf)
		return out

	static func _append_name( out:PackedStringArray, raw:String ) -> void:
		var s:String = raw.strip_edges()
		if s.is_empty(): return
		# Strip default value.
		var eq:int = s.find("=")
		if eq != -1: s = s.substr(0, eq).strip_edges()
		# Strip type annotation.
		var colon:int = s.find(":")
		if colon != -1: s = s.substr(0, colon).strip_edges()
		if s.is_empty(): return
		out.append(s)
