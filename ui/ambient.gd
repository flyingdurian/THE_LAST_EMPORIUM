extends Control
## Cosmetic dust motes only; no domain clock or negotiation effects.
var elapsed := 0.0
func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()
func _draw() -> void:
	for i in range(16):
		var x := fmod(float(i*173+47)+elapsed*(5.0+float(i%4)),maxf(size.x,1.0))
		var y := fmod(float(i*91+28)-elapsed*(3.0+float(i%3))+size.y*20.0,maxf(size.y,1.0))
		var alpha := 0.10+0.12*(sin(elapsed*1.4+float(i))+1.0)/2.0
		draw_circle(Vector2(x,y),1.2+float(i%2)*0.65,Color(1.0,0.76,0.40,alpha))
