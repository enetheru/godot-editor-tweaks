@tool

# TODO: re-bind CTRL-F to find the text that is highlighted
#		or open the find dialog. Requires unbinding existing filter command
# TODO: change the filter icon to the funnel.

const EditorLogHelper = preload('uid://bqnxqo33qkevi')

static var editor_log_helper : EditorLogHelper

static func toggle_search_bar( logref : BoxContainer, toggled_on : bool ) -> void:
	if toggled_on:
		if is_instance_valid(editor_log_helper): return
		print("Enable EditorLog Search Bar")
		editor_log_helper = EditorLogHelper.new()
		editor_log_helper.find_buildtin_editorlog_controls( logref )
		editor_log_helper.enable_search()
	else:
		if is_instance_valid(editor_log_helper):
			print("Disable EditorLog Search Bar")
			editor_log_helper.disable_search()
			editor_log_helper = null


# │ _____            _
# │|_   _| _ __ _ __(_)_ _  __ _
# │  | || '_/ _` / _| | ' \/ _` |
# │  |_||_| \__,_\__|_|_||_\__, |
# ╰────────────────────────|___/───
var trace_enabled : bool = false

func trace(args : Dictionary = {}) -> void:
	if not trace_enabled : return
	var stack := get_stack(); stack.pop_front()
	EneLog.trace(args, stack, self)


func trace_detail(content : Variant, object : Object = null) -> void:
	if not trace_enabled : return
	var stack := get_stack(); stack.pop_front()
	EneLog.printy(content, null, object, "", stack)


# ██████  ██████   ██████  ██████  ███████ ██████  ████████ ██ ███████ ███████ #
# ██   ██ ██   ██ ██    ██ ██   ██ ██      ██   ██    ██    ██ ██      ██      #
# ██████  ██████  ██    ██ ██████  █████   ██████     ██    ██ █████   ███████ #
# ██      ██   ██ ██    ██ ██      ██      ██   ██    ██    ██ ██           ██ #
# ██      ██   ██  ██████  ██      ███████ ██   ██    ██    ██ ███████ ███████ #
func                        ________PROPERTIES_______              ()->void:pass


# │ ___    _ _ _           _
# │| __|__| (_) |_ ___ _ _| |   ___  __ _
# │| _|/ _` | |  _/ _ \ '_| |__/ _ \/ _` |
# │|___\__,_|_|\__\___/_| |____\___/\__, |
# ╰─────────────────────────────────|___/─
# References to all of the main components.
var _editorlog : BoxContainer
var _el_l_vb : VBoxContainer
var _rtl : RichTextLabel
var _rtl_vsb : VScrollBar
var _el_filter_line : LineEdit

var _el_r_vb : VBoxContainer
var _el_r_hb1 : HBoxContainer
var _el_clear : Button
var _el_copy : Button

var _el_r_sep1 : HSeparator

var _el_r_hb2 : HBoxContainer
var _el_collapse : Button
var _el_filter : Button

var _el_r_sep2 : HSeparator

var _el_standard : Button
var _el_error : Button
var _el_warning : Button
var _el_editor : Button

# Editor Theme.
var editor_theme : Theme :
	get(): return EditorInterface.get_editor_theme()

# │ ___                  _      _    _
# │/ __| ___ __ _ _ _ __| |_   | |  (_)_ _  ___
# │\__ \/ -_) _` | '_/ _| ' \  | |__| | ' \/ -_)
# │|___/\___\__,_|_| \__|_||_| |____|_|_||_\___|
# ╰─────────────────────────────────────────────
var right_row3 : HBoxContainer
var search_toggle_b : Button
var right_sep3 : HSeparator

var search_hbox : HBoxContainer
# I want to replicate what clion has, and skip for now the innecessary.
# [> for show replace]
# [history | line_edit | insert special | match case | match word | enable regex]
# [num results | up arrow | down arrow | filter | options...]
var search_history_b : Button
var search_pattern_le : LineEdit
var pattern_insert_b : Button
var pattern_case_b : Button
var pattern_word_b : Button
var pattern_regex_b : Button
var match_count_lbl : Label
var match_prev_b : Button
var match_next_b : Button
#var search_filter_b : Button # for selection only searching
#var search_options_b : Button
var search_hide_b : Button

var debounce_timer : Timer
var _vsb_debounce_flag : bool = false


# │  ___     _
# │ / __|___| |___ _  _ _ _ ___
# │| (__/ _ \ / _ \ || | '_(_-<
# │ \___\___/_\___/\_,_|_| /__/
# ╰──────────────────────────────

var paragraph_color := Color(Color.YELLOW, 0.3)
var current_paragraph_color := Color(Color.YELLOW, 0.3)
var line_color := Color(Color.YELLOW, 0.3)
var current_line_color := Color.YELLOW
var word_color := Color(Color.YELLOW, 0.3)
var current_word_color := Color(Color.YELLOW, 0.3)


# │ ___     _                     _
# │|_ _|_ _| |_ ___ _ _ _ _  __ _| |
# │ | || ' \  _/ -_) '_| ' \/ _` | |
# │|___|_||_\__\___|_| |_||_\__,_|_|
# ╰──────────────────────────────────
var _rtl_total_char_count : int = -1
var _rtl_p_cache : Array

# The scrollbar holds the value for how far through the document we are.
var _rtl_scroll_value : float

# the visible content rect is the bounding box of the rich text character elements.
var _rtl_visible_content_rect : Rect2

var pattern_history : Array
var search_pattern : String

# paragraph_num : [Vector2i pairs of absolute character start and end indexes]
var match_results : Dictionary
var match_indices  : Array[int]

var current_match_idx : int = 1
var at_first_match : bool = false
var at_last_match : bool = false

var debounce_delay : float = 0.7

# Cache
var _rtl_content_margin := Vector2(8,8) # TODO fetch this from the theme
var _rtl_font : Font
var _rtl_font_size : int = 16


# TODO delete the debug stuff.
var _debug : bool = true
var debug_info : Dictionary
var matching_paragraphs : Dictionary
var _debug_font : FontVariation
var _debug_font_size : int

#             ███████ ██    ██ ███████ ███    ██ ████████ ███████              #
#             ██      ██    ██ ██      ████   ██    ██    ██                   #
#             █████   ██    ██ █████   ██ ██  ██    ██    ███████              #
#             ██       ██  ██  ██      ██  ██ ██    ██         ██              #
#             ███████   ████   ███████ ██   ████    ██    ███████              #
func                        __________EVENTS_________              ()->void:pass

func _on_editorlog_clear_pressed() -> void:
	clear_matches()
	update_search_ui()


## VSB is VerticalScrollbar
func _on_vsb_changed( _value : float ) -> void:
	if _vsb_debounce_flag: return
	_vsb_debounce_flag = true
	_rtl_vsb.value_changed.disconnect(_on_vsb_changed)
	trace_detail("_on_vsb_changed(%s)"% [_value])
	await EditorInterface.get_base_control().get_tree().create_timer(1).timeout
	@warning_ignore('return_value_discarded')
	_rtl_vsb.value_changed.connect(_on_vsb_changed)
	_vsb_debounce_flag = false


func _on_editorlog_rtl_draw() -> void:
	if not _rtl.is_finished(): return
	if _rtl.get_total_character_count() == 0:
		_on_editorlog_clear_pressed()

	var current_v : float = _rtl_vsb.value
	if current_v != _rtl_scroll_value:
		# Trigger an update of the visual range?
		_rtl_scroll_value = current_v
		# find_extents()

	_rtl_visible_content_rect = _rtl.get_visible_content_rect()
	draw_search()
	if pattern_regex_b.button_pressed:
		if _debug: draw_debug()


func _on_search_toggled( toggled_on : bool ) -> void:
	if toggled_on:
		search_hbox.show()
		@warning_ignore_start('return_value_discarded')
		_rtl.draw.connect(_on_editorlog_rtl_draw)
		_rtl_vsb.value_changed.connect(_on_vsb_changed)
		_el_clear.pressed.connect( _on_editorlog_clear_pressed )
		@warning_ignore_restore('return_value_discarded')
	else:
		search_hbox.hide()
		_rtl.draw.disconnect(_on_editorlog_rtl_draw)
		_rtl_vsb.value_changed.disconnect(_on_vsb_changed)
		_el_clear.pressed.disconnect( _on_editorlog_clear_pressed )


func _on_pattern_changed( new_pattern : String ) -> void:
	trace_detail("_on_pattern_changed( %s )"% [new_pattern])
	search_pattern = new_pattern
	if not debounce_timer.is_stopped(): return
	debounce_timer.start(debounce_delay)
	await debounce_timer.timeout
	do_search()


func _on_pattern_history_pressed() -> void:
	trace()


func _on_pattern_insert_pressed() -> void:
	trace()


func _on_pattern_case_pressed() -> void:
	trace()


func _on_pattern_word_pressed() -> void:
	trace()


func _on_pattern_regex_pressed() -> void:
	trace()
	EditorInterface.inspect_object(_rtl)



func _on_match_prev_pressed() -> void:
	if await cache_is_updated(): do_search()
	if match_indices .is_empty(): return
	if current_match_idx > 1:
		current_match_idx -= 1
	else:
		if at_first_match:
			current_match_idx = match_indices .size()
			at_first_match = false
		else:
			trace_detail("TODO: pop for being at the top")
			at_first_match = true
			return

	var p_num : int = match_indices [current_match_idx-1]
	_rtl.scroll_to_line(p_num)
	update_search_ui()


func _on_match_next_pressed() -> void:
	if await cache_is_updated(): do_search()
	if match_indices .is_empty(): return
	if current_match_idx < match_indices .size():
		current_match_idx += 1
	else:
		if at_last_match:
			current_match_idx = 1
			at_last_match = false
		else:
			trace_detail("TODO: pop for being at the bottom")
			at_last_match = true
			return

	var p_num : int = match_indices [current_match_idx-1]
	_rtl.scroll_to_line(p_num)
	update_search_ui()


#         ███    ███ ███████ ████████ ██   ██  ██████  ██████  ███████         #
#         ████  ████ ██         ██    ██   ██ ██    ██ ██   ██ ██              #
#         ██ ████ ██ █████      ██    ███████ ██    ██ ██   ██ ███████         #
#         ██  ██  ██ ██         ██    ██   ██ ██    ██ ██   ██      ██         #
#         ██      ██ ███████    ██    ██   ██  ██████  ██████  ███████         #
func                        _________METHODS_________              ()->void:pass

func find_buildtin_editorlog_controls( logref : BoxContainer ) -> void:
	trace()
	# Main Control and children
	_editorlog = logref
	var interest : int = 0
	for child in _editorlog.get_children():
		match interest:
			0 when child is VBoxContainer:
				_el_l_vb = child
				interest += 1
			1 when child is VBoxContainer:
				_el_r_vb = child

	# Left side children
	interest = 0
	for child in _el_l_vb.get_children():
		match interest:
			0 when child is RichTextLabel:
				_rtl = child
				_rtl_vsb = _rtl.get_v_scroll_bar()
				interest += 1
			1 when child is LineEdit:
				_el_filter_line = child

	# Right side children
	interest = 0
	for child in _el_r_vb.get_children():
		match interest:
			0 when child is HBoxContainer:
				var btn : Button = child.get_child(0)
				if btn.accessibility_name == "Clear Log":
					_el_r_hb1 = child
					interest += 1
			1 when child is HSeparator:
				_el_r_sep1 = child
				interest += 1
			2 when child is HBoxContainer:
				var btn : Button = child.get_child(1)
				if btn.accessibility_name == "Show Search":
					_el_r_hb2 = child
					interest += 1
			3 when child is HSeparator:
				_el_r_sep2 = child
				interest += 1
			4 when child is Button:
				var btn : Button = child
				if btn.accessibility_name == "Standard Messages":
					_el_standard = child
					interest += 1
			5 when child is Button:
				var btn : Button = child
				if btn.accessibility_name == "Errors":
					_el_error = child
					interest += 1
			6 when child is Button:
				var btn : Button = child
				if btn.accessibility_name == "Warnings":
					_el_warning = child
					interest += 1
			7 when child is Button:
				var btn : Button = child
				if btn.accessibility_name == "Editor Messages":
					_el_editor = child
					interest += 1

	# row1 children
	interest = 0
	for child in _el_r_hb1.get_children():
		match interest:
			0 when child is Button:
				_el_clear = child
				interest += 1
			1 when child is Button:
				_el_copy = child

	# row2 children
	interest = 0
	for child in _el_r_hb2.get_children():
		match interest:
			0 when child is Button:
				_el_collapse = child
				interest += 1
			1 when child is Button:
				_el_filter = child

	_rtl_font = _rtl.get_theme_default_font()
	_rtl_font_size = _rtl.get_theme_default_font_size()


	_debug_font = FontVariation.new()
	_debug_font_size = _rtl_font_size
	_debug_font.base_font = _rtl_font


func enable_search() -> void:
	trace()
	create_search_toggle()
	create_search_control()


func disable_search() -> void:
	trace()
	for node : Node in [right_row3, right_sep3, search_hbox]:
		if is_instance_valid(node):
			node.queue_free()

	if _rtl.draw.is_connected(_on_editorlog_rtl_draw):
		_rtl.draw.disconnect(_on_editorlog_rtl_draw)

	if _rtl_vsb.value_changed.is_connected(_on_vsb_changed):
		_rtl_vsb.value_changed.disconnect(_on_vsb_changed)

	if _el_clear.pressed.is_connected( _on_editorlog_clear_pressed ):
		_el_clear.pressed.disconnect( _on_editorlog_clear_pressed )


func do_search() -> void:
	trace()
	if not _rtl.is_finished(): await _rtl.finished
	if search_pattern.is_empty():
		clear_matches()
		update_search_ui()
		return

	await cache_is_updated()

	var search_info : Dictionary = {
		&"p_num":0,
		&"p_max":_rtl_p_cache.size(),
		&"pattern":search_pattern
	}

	clear_matches()
	# TODO change the search function depending on the options.
	match_results = _rtl_p_cache.reduce( basic_search.bind(search_info), {} )

	trace_detail("line_cache.size: %s" % [_rtl_p_cache.size()])
	if not _rtl_p_cache.is_empty():
		trace_detail("first line: %s" % _rtl_p_cache[0])
	if not match_results.is_empty():
		match_indices .assign( match_results.keys() )
		if current_match_idx > match_indices .size():
			current_match_idx = match_indices .size()

	update_search_ui()


func cache_is_updated() -> bool:
	trace()
	if not _rtl.is_finished(): await _rtl.finished
	# Cache the output split into paragraphs, if changed.
	# NOTE: Could I use the clear action to invalidate the cache ?
	# And only add the new lines rather than rebuid the whole thing?
	var total_char_count : int = _rtl.get_total_character_count()
	if _rtl_total_char_count != total_char_count:
		# FIXME: character count is rudimentary, i should figure out
		# something more accurate.
		# NOTE: if I perform any text manipulation here,
		# it will cause a race condition and crash godot.
		# TODO investigate whether caching is even needed, the
		# strings might be available under the hood in a format
		# that is suitable already.
		_rtl_p_cache = _rtl.get_parsed_text().split('\n', true)
		# TODO search within selection _rtl.get_selected_text()
		_rtl_total_char_count = total_char_count
		return true
	return false


func update_search_ui() -> void:
	if match_indices .is_empty(): match_count_lbl.text = "0 results"
	else: match_count_lbl.text = "%d/%d" % [current_match_idx, match_indices .size()]
	_rtl.queue_redraw()


func clear_matches() -> void:
	match_results.clear()
	match_indices .clear()
	matching_paragraphs.clear()
	at_first_match = false
	at_last_match = false


# function assumes cached variables for draw are upto date.
func is_character_visible( c_num : int ) -> int:
	trace_detail("is_character_visible( %d )" % [c_num])
	var l_num : int = _rtl.get_character_line(c_num)
	trace_detail("char_line %s" % [l_num])
	var l_range : Vector2i = _rtl.get_line_range(l_num)
	trace_detail("line_range %s" % [l_range])

	var c_rect : Rect2 = _rtl_visible_content_rect
	trace_detail("visible_rect %s" % [c_rect])
	var c_pos : Vector2 = c_rect.position
	var c_scroll : float = _rtl_scroll_value

	var l_rect : Rect2 = get_line_rect(l_num)
	l_rect.position += c_pos
	l_rect.position.y -= c_scroll
	trace_detail("line_rect %s" % [l_rect])

	if l_rect.position.y == 0:
		trace_detail("line_rect is at zero.")
		return 0
	if l_rect.intersects(_rtl_visible_content_rect):
		trace_detail("line_rect is visible")
		return l_range.x - c_num
	trace_detail("line_rect is not visible")
	return  c_num - l_range.x


func find_smallest(
			size: int,  # Exclusive end of range (e.g., total_lines); search from 0 to size-1
			check_func: Callable,  # (index: int) -> direction and magnitude to head, or 0 for exact match.
			guess_start: int = (size >> 1),
			margin : int = 0
			) -> int:
	trace_detail("find_smallest( size: %d, func:%s, guess: %d, margin:%d)" % [
			size, check_func.get_method(), guess_start, margin ])
	assert( size > 0 )
	var current : int = clamp(guess_start, 0, size - 1)
	var largest : int = size
	var smallest : int = 0

	while current >= smallest and current < largest:
		trace_detail("closing_window: (%s, %s)" % [smallest, largest])
		trace_detail("current: %d" % current)
		var step : int = check_func.call(current)
		trace_detail("step: %d" % step)
		if abs(step) <= margin: return current # within margin

		# Shrink window based on sign (monotonic assumption)
		if step > 0: # Too low: target is higher
			smallest = current+1
		else: # Too high: target is lower
			largest = current

		current = clamp(current + step, smallest, largest - 1)

	push_error("No suitable index found within margin.")
	return -1
#               ███████ ███████  █████  ██████   ██████ ██   ██                #
#               ██      ██      ██   ██ ██   ██ ██      ██   ██                #
#               ███████ █████   ███████ ██████  ██      ███████                #
#                    ██ ██      ██   ██ ██   ██ ██      ██   ██                #
#               ███████ ███████ ██   ██ ██   ██  ██████ ██   ██                #
func                        __________SEARCH_________              ()->void:pass

func basic_search(
			results : Dictionary,
			paragraph : String,
			search_info : Dictionary ) -> Dictionary:
	var pattern : String = search_info.pattern
	if pattern in paragraph:
		# TODO capture the location of the word within the paragraph
		# TODO implement word, case, regex features
		var result_array := Array()
		var from : int = 0
		while from < paragraph.length():
			var match_start : int = paragraph.findn(pattern, from)
			if match_start < 0: break
			result_array.append(Vector2i(match_start, match_start + pattern.length()))
			from += match_start + pattern.length() + 1

		results[search_info.p_num] = result_array
	search_info.p_num += 1
	return results



#                ██████ ██████  ███████  █████  ████████ ███████               #
#               ██      ██   ██ ██      ██   ██    ██    ██                    #
#               ██      ██████  █████   ███████    ██    █████                 #
#               ██      ██   ██ ██      ██   ██    ██    ██                    #
#                ██████ ██   ██ ███████ ██   ██    ██    ███████               #
func                        __________CREATE_________              ()->void:pass

func create_search_toggle() -> void:
	# Create and add the button row and separator.
	right_row3 = HBoxContainer.new()
	right_sep3 = HSeparator.new()
	_el_r_sep2.add_sibling(right_sep3)
	_el_r_sep2.add_sibling(right_row3)

	# Create and add the new search button.
	search_toggle_b = Button.new()
	search_toggle_b.icon = _el_filter.icon
	search_toggle_b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	search_toggle_b.toggle_mode = true
	search_toggle_b.focus_mode = _el_filter.focus_mode
	search_toggle_b.accessibility_name = "Show Search Bar"
	search_toggle_b.theme_type_variation = &"FlatButton"
	search_toggle_b.grow_horizontal = Control.GROW_DIRECTION_END
	search_toggle_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	right_row3.add_child(search_toggle_b)

	@warning_ignore('return_value_discarded')
	search_toggle_b.toggled.connect( _on_search_toggled )


func create_search_control() -> void:
	if is_instance_valid(search_hbox): return
	search_hbox = HBoxContainer.new()
	search_hbox.hide()

	# History Button
	search_history_b = Button.new()
	search_history_b.icon = ImageTexture.create_from_image(
		Enetheru.image.overlay(
			editor_theme.get_icon("Search", "EditorIcons").get_image(),
			editor_theme.get_icon("GuiDropdown", "EditorIcons").get_image(),
			Vector2i(11,1)))

	#editor_theme.get_icon("RegExMatch", "EditorIcons")

	# Line Edit
	search_pattern_le = LineEdit.new()
	search_pattern_le.placeholder_text = "Search Messages"
	search_pattern_le.clear_button_enabled = true
	search_pattern_le.flat = true
	search_pattern_le.caret_blink = true
	search_pattern_le.caret_blink_interval = 0.5
	search_pattern_le.size_flags_horizontal = _el_filter_line.size_flags_horizontal
	search_pattern_le.accessibility_name = "Search Messages"

	debounce_timer = Timer.new()
	debounce_timer.one_shot = true
	debounce_timer.autostart = false

	# Add special characters to the search line
	pattern_insert_b = Button.new()
	pattern_insert_b.text = ""

	# make the search case sensitive
	pattern_case_b = Button.new()
	#pattern_case_b.icon = editor_theme.get_icon("MatchCase", "EditorIcons")
	pattern_case_b.text = "Aa"
	pattern_case_b.tooltip_text = "search is case sensitive"
	pattern_case_b.toggle_mode = true

	# search for whole words only
	pattern_word_b = Button.new()
	pattern_word_b.text = "W"
	pattern_word_b.tooltip_text = "match whole words only"
	pattern_word_b.toggle_mode = true

	# search using regex
	pattern_regex_b = Button.new()
	#pattern_regex_b.icon = editor_theme.get_icon("RegEx", "EditorIcons")
	pattern_regex_b.text = ".*"
	pattern_regex_b.tooltip_text = "interpret pattern as a regular expression"
	pattern_regex_b.toggle_mode = true

	# show the number of results
	match_count_lbl = Label.new()
	match_count_lbl.text = "0 results"
	# label should read as a ratio like "current/total"

	# Forward and back buttons.
	match_prev_b = Button.new()
	match_prev_b.icon = editor_theme.get_icon("ArrowUp", "EditorIcons")
	match_next_b = Button.new()
	match_next_b.icon = editor_theme.get_icon("ArrowDown", "EditorIcons")

	search_hide_b = Button.new()
	search_hide_b.icon = editor_theme.get_icon("clear", "LineEdit")

	for button : Button in [
				search_history_b, pattern_insert_b, pattern_case_b,
				pattern_word_b, pattern_regex_b, match_prev_b,
				match_next_b, search_hide_b,]:
		button.theme_type_variation = &"FlatButton"

	search_hbox.add_child(search_history_b)
	search_hbox.add_child(search_pattern_le)
	search_pattern_le.add_child(debounce_timer)
	search_hbox.add_child(pattern_insert_b)
	search_hbox.add_child(pattern_case_b)
	search_hbox.add_child(pattern_word_b)
	search_hbox.add_child(pattern_regex_b)
	search_hbox.add_child(VSeparator.new())
	search_hbox.add_child(match_count_lbl)
	search_hbox.add_child(match_prev_b)
	search_hbox.add_child(match_next_b)
	search_hbox.add_child(VSeparator.new())
	search_hbox.add_child(search_hide_b)

	# Add to the editor scene tree last.
	_el_l_vb.add_child(search_hbox)

	@warning_ignore_start('return_value_discarded')
	search_history_b.pressed.connect( _on_pattern_history_pressed )
	search_pattern_le.text_changed.connect(_on_pattern_changed)
	pattern_insert_b.pressed.connect( _on_pattern_insert_pressed )
	pattern_case_b.pressed.connect( _on_pattern_case_pressed )
	pattern_word_b.pressed.connect( _on_pattern_word_pressed )
	pattern_regex_b.pressed.connect( _on_pattern_regex_pressed )
	match_prev_b.pressed.connect( _on_match_prev_pressed )
	match_next_b.pressed.connect( _on_match_next_pressed )

	search_hide_b.pressed.connect( search_toggle_b.set_pressed.bind(false) )
	@warning_ignore_restore('return_value_discarded')


#                      ██████  ██████   █████  ██     ██                       #
#                      ██   ██ ██   ██ ██   ██ ██     ██                       #
#                      ██   ██ ██████  ███████ ██  █  ██                       #
#                      ██   ██ ██   ██ ██   ██ ██ ███ ██                       #
#                      ██████  ██   ██ ██   ██  ███ ███                        #
func                        __________DRAW___________              ()->void:pass

func draw_highlight_word(
			word_range : Vector2i,
			_color : Color,
			_filled : bool = true,
			_width : int = -1 ) -> void:
	var p_num : int = _rtl.get_character_paragraph(word_range.x)
	var l_num : int = _rtl.get_character_line(word_range.x)
	var l_range : Vector2i = _rtl.get_line_range(l_num)
	var l_rect : Rect2= get_line_rect(l_num)

	var line_text : String = _rtl_p_cache[p_num]

	# make word range relative to the paragraph.
	word_range.x -= l_range.x
	word_range.y -= l_range.x

	var pre_text : String = line_text.substr(0,word_range.x)

	var w_text : String = line_text.substr(word_range.x, word_range.y - word_range.x)

	var pre_size : Vector2 = _rtl_font.get_multiline_string_size(pre_text)
	var w_size : Vector2 = _rtl_font.get_multiline_string_size(w_text)

	var w_rect := Rect2(_rtl_content_margin, w_size)
	w_rect.position += l_rect.position
	w_rect.position.x += pre_size.x
	w_rect.position.y -= _rtl_scroll_value

	if l_rect.intersects(_rtl_visible_content_rect):
		_rtl.draw_rect(w_rect, word_color)


func draw_highlight_line(
			l_num : int,
			color : Color,
			filled : bool = true,
			width : int = -1
			) -> void:
	var l_rect : Rect2 = get_line_rect(l_num)
	l_rect.position += _rtl_content_margin
	l_rect.position.y -= _rtl_scroll_value

	if l_rect.intersects(_rtl_visible_content_rect):
		_rtl.draw_rect(l_rect, color, filled, width )


func draw_highlight_paragraph(
			p_num : int,
			color : Color,
			filled : bool = true,
			width : int = -1
			) -> void:
	var p_range : Vector2i = get_paragraph_range(p_num)
	var l_range := Vector2i(
		_rtl.get_character_line(p_range.x),
		_rtl.get_character_line(p_range.y))

	for l_num in range(l_range.x, l_range.y):
		draw_highlight_line(l_num, color, filled, width)

	for word_range : Vector2i in match_results[p_num]:
		var abs_word : Vector2i = word_range + Vector2i(p_range.x, p_range.x)
		draw_highlight_word( abs_word , word_color )


# TODO: highlight word segments
# NOTE:  might it be more efficient to figure out the minimum line, and maximum line that is in view?
func draw_search() -> void:
	if match_indices .is_empty(): return
	if not _rtl.is_finished(): return

	var current_paragraph_idx : int = match_indices [current_match_idx-1]
	draw_highlight_paragraph( current_paragraph_idx, current_paragraph_color, false )

	for p_num : int in match_indices :
		draw_highlight_paragraph( p_num, paragraph_color, true )



#                           ██████  ████████ ██                                #
#                           ██   ██    ██    ██                                #
#                           ██████     ██    ██                                #
#                           ██   ██    ██    ██                                #
#                           ██   ██    ██    ███████                           #
func                        ___________RTL___________              ()->void:pass
# There is no builtin method to get the character index for the start of the
# paragraph.
func get_paragraph_range( p_num : int ) -> Vector2i:
	assert( p_num >= 0)
	var p_max : int = _rtl.get_paragraph_count()
	assert( p_num <= p_max, "%d <= %d" % [p_num, p_max])

	var p_range := Vector2i(-1,-1)
	for line_num : int in _rtl.get_line_count():
		var line_range : Vector2i = _rtl.get_line_range(line_num)

		# Match the start first.
		if p_range.x == -1:
			var char_p : int = _rtl.get_character_paragraph(line_range.x)
			if char_p == p_num:
				p_range.x = line_range.x

		# Then match the end.
		if p_range.x != -1:
			var char_p : int = _rtl.get_character_paragraph(line_range.y-1)
			if char_p != p_num: break
			p_range.y = line_range.y

	return p_range


func get_line_rect( l_num : int ) -> Rect2:
	if l_num >= _rtl.get_line_count(): return Rect2()
	var l_offset : float = _rtl.get_line_offset(l_num)
	return Rect2(
		Vector2(0, l_offset),
		Vector2(_rtl.get_line_width(l_num), _rtl.get_line_height(l_num))
	)

#                  ██████  ███████ ██████  ██    ██  ██████                    #
#                  ██   ██ ██      ██   ██ ██    ██ ██                         #
#                  ██   ██ █████   ██████  ██    ██ ██   ███                   #
#                  ██   ██ ██      ██   ██ ██    ██ ██    ██                   #
#                  ██████  ███████ ██████   ██████   ██████                    #
func                        __________DEBUG__________              ()->void:pass

func draw_debug() -> void:
	draw_debug2()
	draw_debug_info()


func draw_debug_info() -> void:
	# Print the debug text so i can figure out what the hell it is that I am doing.
	var font := FontVariation.new()
	font.base_font = ThemeDB.fallback_font
	#font.variation_embolden = 1.0
	var font_size : int = 20

	var debug_position := Vector2(_rtl.size.x / 3,font.get_height(font_size))

	var debug_parts : Array[String] = []

	if not debug_info.is_empty():
		debug_parts.append("debug = " + JSON.stringify(debug_info, ' ', false))

	if match_indices .size():
		debug_parts.append("cur_line = %d" % match_indices [current_match_idx-1])

	debug_parts.append_array([
		"pattern = " + search_pattern,
		"results = " + JSON.stringify(match_results, '  ', false),
	])

	debug_position = _editorlog.size / 2
	debug_position.y = 0


	# merge the parts into one string.
	var debug_text : String = "\n".join(debug_parts)
	draw_debug_text(debug_position, debug_text)


func draw_debug2() -> void:
	var position : Vector2
	#var size : Vector2
	var v_offset : float = 0

	var h_color := Color(1,0,1,0.4)
	var h_color_ol := Color(1,0,1,1)

	var p_color := Color(0,1,1,0.5)
	var p_color_ol := Color(0,1,1,1)

	var l_color := Color(0,1,0,0.5)
	var l_color_ol := Color(0,1,0,1)

	var font := _rtl.get_theme_default_font()
	var font_size : int = _rtl.get_theme_default_font_size()
	var f_size : Vector2 = font.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)

	# the visible content rect is the bounding box of the rich text character elements.
	var c_rect : Rect2 = _rtl_visible_content_rect
	var c_pos : Vector2 = c_rect.position
	#var c_size : Vector2 = c_rect.size

	position = Vector2(
			c_pos.x,
			c_pos.y + v_offset - _rtl_scroll_value)

	var highlight_rect := Rect2( position, f_size )

	_rtl.draw_rect(highlight_rect, h_color)
	_rtl.draw_rect(highlight_rect, h_color_ol, false)

	for p in _rtl.get_paragraph_count():
		var p_offset : float = _rtl.get_paragraph_offset(p)
		position = Vector2(
			c_pos.x,
			c_pos.y + p_offset - _rtl_scroll_value)
		var p_rect := Rect2(position, f_size)
		if p_rect.intersects(c_rect):
			_rtl.draw_rect(p_rect, p_color)
			_rtl.draw_rect(p_rect, p_color_ol, false)

	for l in _rtl.get_line_count():
		var l_offset : float = _rtl.get_line_offset(l)
		position = Vector2(
			c_pos.x + (2 * f_size.x),
			c_pos.y + l_offset - _rtl_scroll_value )

		var l_rect := Rect2(position, f_size)
		if l_rect.intersects(c_rect):
			_rtl.draw_rect(l_rect, l_color)
			_rtl.draw_rect(l_rect, l_color_ol, false)


func draw_debug_text( position : Vector2, msg : String )-> void:
	#font.variation_embolden = 1.0
	var ascent : float = _debug_font.get_ascent(_debug_font_size)
	var descent : float = _debug_font.get_descent(_debug_font_size)
	var margin := Vector2(descent, 0) + Vector2.ONE * 2

	position += _rtl_content_margin

	var bg_color := Color.DARK_SLATE_GRAY
	var fg_color := Color.BEIGE
	var ol_color := Color.BLACK

	var bg_size : Vector2 = _debug_font.get_multiline_string_size(
		msg, HORIZONTAL_ALIGNMENT_LEFT, -1, _debug_font_size, -1)
	bg_size += margin * 2

	_rtl.draw_rect(Rect2(position, bg_size), bg_color)
	_rtl.draw_rect(Rect2(position, bg_size), bg_color.darkened(0.2), false, 2)

	position += margin
	position.y += ascent

	_rtl.draw_multiline_string_outline(
		_debug_font, position, msg,
		HORIZONTAL_ALIGNMENT_LEFT, -1, _debug_font_size, -1, 3, ol_color)

	_rtl.draw_multiline_string(
		_debug_font, position, msg,
		HORIZONTAL_ALIGNMENT_LEFT, -1, _debug_font_size, -1, fg_color)
