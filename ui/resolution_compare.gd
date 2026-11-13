extends Control
const World = preload("res://ui/resolution_world.gd")
func _ready() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left=16; root.offset_top=16; root.offset_right=-16; root.offset_bottom=-16
	add_child(root)
	var title := Label.new(); title.text="RESOLUTION TECHNICAL COMPARISON — GRAYBOX ONLY"; title.add_theme_font_size_override("font_size",24); root.add_child(title)
	var note := Label.new(); note.text="Same camera coverage; actual render targets, scaled to equal display size. Not an art approval benchmark."; note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; root.add_child(note)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation",16); row.size_flags_vertical=Control.SIZE_EXPAND_FILL; root.add_child(row)
	for v in [Vector2i(640,360),Vector2i(960,540)]:
		var col := VBoxContainer.new(); col.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(col)
		var label := Label.new(); label.text="%dpx tiles  /  %d×%d" % [32 if v.x==640 else 48,v.x,v.y]; col.add_child(label)
		var vp := SubViewport.new(); vp.size=v; vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS; add_child(vp); vp.add_child(World.new())
		var preview := TextureRect.new(); preview.texture=vp.get_texture(); preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; preview.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST; preview.size_flags_vertical=Control.SIZE_EXPAND_FILL; col.add_child(preview)
	var foot := Label.new(); foot.text="No approved sprite, portrait, item illustration, palette or typography. Compare spatial density only."; foot.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; root.add_child(foot)
