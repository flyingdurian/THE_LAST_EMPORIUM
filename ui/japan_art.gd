extends RefCounted
## Replaceable character, item and environment assets. No game rules.
var registry: Dictionary = {}
var textures: Dictionary = {}
var frames: Dictionary = {}
var portraits: Dictionary = {}
func _init() -> void:
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/character_assets.json"))
	if parsed is Dictionary: registry=parsed
func tex(path: String) -> Texture2D:
	if path.is_empty(): return null
	if not textures.has(path):
		textures[path]=load(path) as Texture2D if ResourceLoader.exists(path) else null
	return textures[path]
func env(key: String) -> Texture2D:
	return tex(str(registry.get("environment",{}).get(key,"")))
func item(id: String,kind: String) -> Texture2D:
	return tex(str(registry.get("items",{}).get(id,{}).get(kind,"")))
func sprite(id: String, index: int) -> Texture2D:
	var key: String="%s:%d"%[id,index]
	if not frames.has(key):
		var c: Dictionary=registry.get("characters",{}).get(id,{})
		var atlas:=AtlasTexture.new()
		atlas.atlas=tex(str(c.get("pixel_sprite_sheet","")))
		atlas.region=Rect2(index*32,0,32,48)
		atlas.filter_clip=true
		frames[key]=atlas
	return frames[key]
func portrait(id: String, emotion: String) -> Texture2D:
	var key: String=id+":"+emotion
	if portraits.has(key): return portraits[key]
	var c: Dictionary=registry.get("characters",{}).get(id,{})
	var path: String=str(c.get("vn_portrait_set",{}).get(emotion,c.get("vn_portrait_set",{}).get("neutral","")))
	var master: Texture2D=tex(path)
	var overlay: Dictionary=c.get("expression_overlays",{}).get(emotion,{})
	if master!=null and not overlay.is_empty():
		var face: Texture2D=tex(str(overlay.texture))
		if face!=null:
			var image: Image=master.get_image()
			var patch: Image=face.get_image()
			image.convert(Image.FORMAT_RGBA8); patch.convert(Image.FORMAT_RGBA8)
			image.blit_rect(patch,Rect2i(Vector2i.ZERO,patch.get_size()),Vector2i(int(overlay.offset[0]),int(overlay.offset[1])))
			master=ImageTexture.create_from_image(image)
	portraits[key]=master
	return master
static func expression(emotion: String) -> String:
	if emotion in ["pleased","relieved","happy"]: return "happy"
	if emotion in ["fearful","frightened","surprised","distressed"]: return "surprised"
	if emotion in ["offended","guarded","departing","angry","impatient"]: return "impatient"
	return "neutral"
func frame_index(state: String, time: float) -> int:
	var a: Array=registry.get("animations",{}).get(state,[0])
	var fps: float=8.0 if state=="WALK" else (3.5 if state in ["BROWSE","PICK_ITEM","INTERACT","RESTOCK"] else 2.0)
	return int(a[posmod(int(floor(time*fps)),a.size())])
func world_rect(id: String,pos: Vector2, slot: int) -> Rect2:
	var size_data: Array=registry.get("items",{}).get(id,{}).get("world_size",[12,12])
	var size:=Vector2(float(size_data[0])*4,float(size_data[1])*4)
	var center:=pos+Vector2(72+slot*112,52)
	return Rect2(Vector2(round((center.x-size.x/2)/4)*4,round((center.y-size.y)/4)*4),size)
