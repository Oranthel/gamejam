@tool
extends Sprite2D

## 主角立绘：加载图片并等比缩放到目标高度。
## 替换立绘 = 直接换图片文件（或改 portrait_path），无需改代码。
## 位置：在 Godot 里拖这个节点即可；大小改 target_height。

@export var portrait_path: String = "res://art/人物/主角立绘.png":
	set(v):
		portrait_path = v
		_reload()

@export var fallback_path: String = "res://art/待定图.png"
@export var target_height: float = 300.0:
	set(v):
		target_height = v
		_rescale(v)


func _ready() -> void:
	_reload()


func _reload() -> void:
	var tex: Texture2D = _load_texture()
	if tex == null:
		return
	texture = tex
	_rescale(target_height)


func _rescale(h_target: float) -> void:
	if texture == null:
		return
	var h := texture.get_height()
	if h > 0.0:
		scale = Vector2.ONE * (h_target / h)


func _load_texture() -> Texture2D:
	if portrait_path != "":
		var base: String = portrait_path.get_basename()
		for ext in [".png", ".jpg", ".jpeg", ".webp"]:
			if ResourceLoader.exists(base + ext):
				return load(base + ext)
	if fallback_path != "" and ResourceLoader.exists(fallback_path):
		return load(fallback_path)
	return null
