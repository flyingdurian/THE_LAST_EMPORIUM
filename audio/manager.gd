extends Node
## Replaceable cue interface. Optional authored streams replace the quiet synthesized defaults.
var muted := false
var volume := 0.55
var streams: Dictionary = {}
const CUES = ["arrival","sale","click","text","tension"]
func _ready() -> void:
	var prefs := ConfigFile.new()
	if prefs.load("user://emporium_audio.cfg")==OK:
		muted=bool(prefs.get_value("audio","muted",false)); volume=clampf(float(prefs.get_value("audio","volume",0.55)),0.0,1.0)
func store() -> void:
	var prefs := ConfigFile.new(); prefs.set_value("audio","muted",muted); prefs.set_value("audio","volume",volume); prefs.save("user://emporium_audio.cfg")
func set_muted(value: bool) -> void:
	muted=value; store()
	for child in get_children():
		if child is AudioStreamPlayer: child.volume_db=-80.0 if muted else linear_to_db(maxf(volume,0.001))-13.0
func set_volume(value: float) -> void:
	volume=clampf(value,0.0,1.0); store()
	for child in get_children():
		if child is AudioStreamPlayer: child.volume_db=-80.0 if muted else linear_to_db(maxf(volume,0.001))-13.0
func cue(name: String) -> void:
	if muted or volume<=0.0 or OS.has_feature("headless") or DisplayServer.get_name()=="headless": return
	if not name in CUES: return
	if not streams.has(name):
		var path: String = "res://" + "audio/" + name + ".ogg"
		streams[name]=load(path) if ResourceLoader.exists(path) else synth(name)
	var player := AudioStreamPlayer.new(); player.stream=streams[name]; player.volume_db=linear_to_db(maxf(volume,0.001))-13.0
	add_child(player); player.finished.connect(player.queue_free); player.play()
func synth(name: String) -> AudioStreamWAV:
	var duration := 0.055
	var frequency := 320.0
	match name:
		"arrival": duration=0.32; frequency=659.0
		"sale": duration=0.23; frequency=880.0
		"tension": duration=0.13; frequency=115.0
		"text": duration=0.035; frequency=240.0
	var count := int(duration*22050.0)
	var samples := PackedByteArray(); samples.resize(count*2)
	for i in range(count):
		var t := float(i)/22050.0
		var env := minf(t/0.004,1.0)*exp(-t*18.0)*(1.0-t/duration)
		var wave := sin(TAU*frequency*t)+0.25*sin(TAU*frequency*1.49*t)
		samples.encode_s16(i*2,int(clampf(wave*env*12000.0,-32767.0,32767.0)))
	var stream := AudioStreamWAV.new(); stream.format=AudioStreamWAV.FORMAT_16_BITS; stream.mix_rate=22050; stream.stereo=false; stream.data=samples
	return stream
