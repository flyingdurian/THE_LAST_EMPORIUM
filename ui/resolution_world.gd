extends Node2D
## Geometry-only comparison. Both viewports have the same camera coverage.
func _draw() -> void:
	var ratio := get_viewport_rect().size.x/640.0
	draw_set_transform(Vector2.ZERO,0,Vector2(ratio,ratio))
	draw_rect(Rect2(0,0,640,360),Color("372f2d"))
	for x in range(0,640,32): draw_line(Vector2(x,0),Vector2(x,360),Color("51413b"),1)
	for y in range(0,360,32): draw_line(Vector2(0,y),Vector2(640,y),Color("51413b"),1)
	draw_rect(Rect2(32,32,576,32),Color("705239"))
	draw_rect(Rect2(80,96,192,48),Color("9b795a"))
	draw_rect(Rect2(80,208,64,96),Color("9b795a"))
	draw_rect(Rect2(496,96,64,128),Color("9b795a"))
	draw_rect(Rect2(560,272,48,64),Color("586e63"))
	draw_circle(Vector2(110,240),11,Color("b84545"))
	for pt in [Vector2(320,240),Vector2(192,80)]:
		draw_rect(Rect2(pt-Vector2(11,24),Vector2(22,36)),Color("73617b"))
		draw_circle(pt-Vector2(0,23),10,Color("ddc49d"))
