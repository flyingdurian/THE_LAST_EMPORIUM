extends RefCounted
const Shop = preload("res://domain/shop.gd")
static func content() -> Dictionary:
	var c := Shop.read_content()
	var extra: Variant = Shop.parse_save(FileAccess.get_file_as_string("res://data/d1_items.json"))
	if extra is Array: c["extra_items"] = extra
	c.item["display_kind"] = "shelf"
	return c
static func config() -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/d1_assets.json"))
	return data if data is Dictionary else {}
static func texture(path: String) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path) else null
static func item_texture(item: Dictionary) -> Texture2D:
	return texture(str(config().get("items",{}).get(item.get("id",""),"")))
