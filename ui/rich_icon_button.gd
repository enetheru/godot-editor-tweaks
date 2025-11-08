@tool
extends Control

## Custom button with optional icon + rich-text label.
## Icon size = theme font size (or custom). Text can be on any SIDE_
## Shrinks to content. Emits `pressed`.

signal pressed()

var _default_props: Dictionary = {
	"focus_mode": Control.FOCUS_ALL,
	"mouse_default_cursor_shape": Control.CURSOR_POINTING_HAND,
	"mouse_filter": Control.MOUSE_FILTER_STOP,
	"size_flags_horizontal": Control.SIZE_SHRINK_CENTER,
	"size_flags_vertical": Control.SIZE_FILL,
	"text_alignment": HORIZONTAL_ALIGNMENT_LEFT,
	"text_position": SIDE_LEFT,
}

func _property_can_revert(property: StringName) -> bool:
	return _default_props.has(property)

func _property_get_revert(property: StringName) -> Variant:
	return _default_props.get(property, null)


@export var button_text: String = "":
	set(v):
		button_text = v
		if is_node_ready(): rebuild.call_deferred()

@export_multiline var bbcode_text: String = "":
	set(v):
		bbcode_text = v
		if is_node_ready(): rebuild.call_deferred()

@export var icon_texture: Texture2D = null:
	set(v):
		icon_texture = v
		if is_node_ready(): rebuild.call_deferred()

@export var text_position: Side:
	set(v):
		text_position = v
		if is_node_ready(): rebuild.call_deferred()

@export var text_alignment: HorizontalAlignment:
	set(v):
		text_alignment = v
		if is_node_ready(): rebuild.call_deferred()

@export var icon_custom_size: Vector2 = Vector2.ZERO:
	set(v):
		icon_custom_size = v
		if is_node_ready(): rebuild.call_deferred()

@export var disabled: bool = false:
	set(v):
		disabled = v
		if is_node_ready():
			rebuild.call_deferred()
			queue_redraw()

# --------------------------------------------------------------------- #
# Internal nodes
var _inner_cont: BoxContainer
var _icon_rect: TextureRect
var _text_label: RichTextLabel

# State
var _hovered: bool = false
var _pressed: bool = false


func _enter_tree() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	if not is_node_ready():
		rebuild()

func _ready() -> void:
	add_theme_stylebox_override("MyStyleOverride", StyleBox.new())
	begin_bulk_theme_override()
	end_bulk_theme_override()
	focus_entered.connect(update_state)
	focus_exited.connect(update_state)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	resized.connect( update_state )


func _on_mouse_entered() -> void:
	_hovered = true
	update_state()


func _on_mouse_exited() -> void:
	_hovered = false
	update_state()

func _gui_input(event: InputEvent) -> void:
	if disabled:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _hovered:
				_pressed = true
				update_state()
				get_viewport().set_input_as_handled()
				return
		else:
			if _pressed and _hovered:
				_pressed = false
				update_state()
				pressed.emit()
				get_viewport().set_input_as_handled()
				return

	if event is InputEventKey and event.pressed and has_focus():
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			pressed.emit()
			get_viewport().set_input_as_handled()
			return


func _draw() -> void:
	var style = get_current_stylebox()
	draw_style_box(style, Rect2(Vector2.ZERO, size))
	#draw_rect(Rect2(_inner_cont.position, _inner_cont.size), Color.RED, false, 1)


func _get_theme_font_size() -> float:
	if has_theme_font_size("font_size", "Button"):
		return get_theme_font_size("font_size", "Button")
	if has_theme_font("font", "Button"):
		var font: Font = get_theme_font("font", "Button")
		if font: return font.get_height()
	return 16


func _get_minimum_size() -> Vector2:
	if not _inner_cont or not is_inside_tree(): return Vector2.ZERO
	var content_size = _inner_cont.get_combined_minimum_size()
	var style_names = ["normal", "hover", "pressed", "disabled", "focus"]
	var min_w = content_size.x
	var min_h = content_size.y
	#for style_name in style_names:
		#var style: StyleBox = get_theme_stylebox(style_name, "Button")
		#if style:
			#var style_min = style.get_minimum_size()
			#min_w = max(min_w, style.content_margin_left + content_size.x + style.content_margin_right + style_min.x)
			#min_h = max(min_h, style.content_margin_top + content_size.y + style.content_margin_bottom + style_min.y)
	return Vector2(min_w, min_h)


func update_state() -> void:
	if not _inner_cont or not is_inside_tree(): return

	var style = get_current_stylebox()

	var available_w = size.x - style.content_margin_left - style.content_margin_right
	var available_h = size.y - style.content_margin_top - style.content_margin_bottom

	var inner_size = _inner_cont.get_combined_minimum_size()  # Use min for consistency

	var x_pos = style.content_margin_left + max(0, (available_w - inner_size.x) / 2.0)
	var y_pos = style.content_margin_top + max(0, (available_h - inner_size.y) / 2.0)

	var offset = Vector2(1, 1) if _pressed and not disabled else Vector2.ZERO
	_inner_cont.position = Vector2(x_pos, y_pos) + offset
	queue_redraw()


func get_current_stylebox() -> StyleBox:
	var style_name: String
	if disabled:
		style_name = "disabled"
	elif _pressed:
		style_name = "pressed"
	elif _hovered:
		style_name = "hover"
	elif has_focus():
		style_name = "focus"
	else:
		style_name = "normal"

	return get_theme_stylebox(style_name, "Button")


func rebuild() -> void:
	if not is_inside_tree(): return

	# --- Remove old content ---
	if _inner_cont and _inner_cont.get_parent() == self:
		_inner_cont.queue_free()
	_inner_cont = null
	_icon_rect = null
	_text_label = null

	# --- Create container ---
	if text_position in [SIDE_LEFT, SIDE_RIGHT]: _inner_cont = HBoxContainer.new()
	else: _inner_cont = VBoxContainer.new()
	_inner_cont.name = "LayoutContainer"
	_inner_cont.alignment = BoxContainer.ALIGNMENT_CENTER
	_inner_cont.size_flags_horizontal = SIZE_SHRINK_CENTER
	_inner_cont.size_flags_vertical   = SIZE_SHRINK_CENTER
	add_child(_inner_cont)

	# --- Icon ---
	var icon_color = get_theme_color("font_disabled_color", "Button") if disabled else get_theme_color("font_color", "Button")
	if icon_texture:
		_icon_rect = TextureRect.new()
		_icon_rect.name = "Icon"
		_icon_rect.texture = icon_texture
		_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE

		var sz = icon_custom_size
		if sz == Vector2.ZERO:
			sz = Vector2(_get_theme_font_size(), _get_theme_font_size())
		_icon_rect.custom_minimum_size = sz

		_icon_rect.size_flags_horizontal = SIZE_SHRINK_CENTER
		_icon_rect.size_flags_vertical   = SIZE_SHRINK_CENTER
		_icon_rect.modulate = icon_color
		_inner_cont.add_child(_icon_rect)

	# --- Label ---
	var has_text = not button_text.is_empty() or not bbcode_text.is_empty()
	var text_color = get_theme_color("font_disabled_color", "Button") if disabled else get_theme_color("font_color", "Button")
	if has_text:
		_text_label = RichTextLabel.new()
		_text_label.name = "Label"
		_text_label.bbcode_enabled = true
		_text_label.text = bbcode_text if not bbcode_text.is_empty() else button_text
		_text_label.fit_content = true
		_text_label.scroll_active = false
		_text_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		_text_label.size_flags_horizontal = SIZE_SHRINK_CENTER
		_text_label.size_flags_vertical   = SIZE_SHRINK_CENTER
		_text_label.horizontal_alignment = text_alignment
		_text_label.mouse_filter = MOUSE_FILTER_PASS
		_text_label.add_theme_font_override("font", get_theme_font("font", "Button"))
		_text_label.add_theme_color_override("default_color", text_color)
		_inner_cont.add_child(_text_label)

	# --- Order ---
	if has_text and icon_texture:
		match text_position:
			SIDE_LEFT:  _inner_cont.move_child(_text_label, 0)
			SIDE_RIGHT: _inner_cont.move_child(_icon_rect, 0)
			SIDE_TOP:   _inner_cont.move_child(_text_label, 0)
			SIDE_BOTTOM:_inner_cont.move_child(_icon_rect, 0)

	# --- Final layout ---
	update_minimum_size()
	update_state()
