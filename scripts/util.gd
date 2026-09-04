@tool
extends Object

## Local copies of the handful of utils this addon used to pull from
## [code]enetheru.utils[/code]. Do not depend on that addon.


static func h1( text:String, font_size:int ) -> String:
	return "".join([
		"[font_size=%s]" % [font_size],
		"[br]",
		"[b]=== %s ===[/b]" % text,
		"[/font_size]",
	])


static func h2( text:String, font_size:int ) -> String:
	return "".join([
		"[font_size=%s]" % [font_size],
		"[br]",
		"[b]--- %s ---[/b]" % text,
		"[/font_size]",
	])


static func overlay(
		base_img:Image,
		overlay_img:Image,
		pos:Vector2i = Vector2i.ZERO,
		scale:float = 1.0 ) -> Image:
	var base_rect := Rect2i(Vector2i.ZERO, base_img.get_size())
	overlay_img.convert(base_img.get_format())
	var final_rect := base_rect.merge(Rect2i(pos, overlay_img.get_size()))
	var result_img := Image.create(
			final_rect.size.x, final_rect.size.y,
			false, base_img.get_format())
	result_img.fill(Color.TRANSPARENT)
	result_img.blend_rect(base_img, base_rect, Vector2i.ZERO)
	if scale != 1.0:
		var overlay_size:Vector2i = overlay_img.get_size()
		var scaled_size := Vector2i(Vector2(overlay_size) * scale)
		assert(scaled_size.x > 0 and scaled_size.y > 0)
		overlay_img.resize(scaled_size.x, scaled_size.y, Image.INTERPOLATE_BILINEAR)
	var overlay_rect := Rect2i(Vector2i.ZERO, overlay_img.get_size())
	result_img.blend_rect(overlay_img, overlay_rect, pos)
	return result_img
