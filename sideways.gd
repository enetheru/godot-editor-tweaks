@tool
extends RichTextEffect

var bbcode : String = "sideways"
static var font_size : int = 16

var origin_transform : Transform2D

# Color       color[default: Color(0, 0, 0, 1)]
# float       elapsed_time[default: 0.0]
# Dictionary  env[default: {}]
# RID         font[default: RID()]
# int         glyph_count[default: 0]
# int         glyph_flags[default: 0]
# int         glyph_index[default: 0]
# Vector2     offset[default: Vector2(0, 0)]
# bool        outline[default: false]
# Vector2i    range[default: Vector2i(0, 0)]
# int         relative_index[default: 0]
# Transform2D transform[default: Transform2D(1, 0, 0, 1, 0, 0)]
# bool        visible[default: true]

func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var dist : Vector2 = Vector2.ZERO
	if char_fx.relative_index == 0:
		origin_transform = char_fx.transform
	else:
		dist = (
			origin_transform.get_origin()
			- char_fx.transform.get_origin())

	var ts : TextServerAdvanced = TextServerManager.get_primary_interface()

	var rid : RID = char_fx.font

	var angle:float = char_fx.env.get('angle', 90)
	var scale: float = char_fx.env.get('scale', 1.2)
	var smush: float = char_fx.env.get('smush', 0.4)

	# REQUIRES CUSTOM GODOT
	# var x_height : float = ts.font_get_x_height(rid, font_size)
	# Make the best guess we can.
	var x_height : float = ts.font_get_ascent(rid, font_size) * 0.56

	## Transform2DTransform2D(rotation(in radians): float , position: Vector2)
	char_fx.transform *= Transform2D(deg_to_rad(-angle), Vector2(x_height * scale,0))
	char_fx.transform = char_fx.transform.translated(Vector2(0,dist.y * smush)).scaled_local(Vector2(scale, scale))
	return true


static func sideways(
			text : String,
			angle : float = 90,
			scale : float = 1.3,
			smush : float = 0.3
			) -> String:
	return ("[sideways angle=%f scale=%f smush=%f]" % [angle,scale, smush]
		+ "\n".join(text.reverse().split())
		+ "[/sideways]")
